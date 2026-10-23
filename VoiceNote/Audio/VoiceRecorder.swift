import Foundation
import AVFoundation
import Speech
import Combine

/// 录音 + 实时语音转写。两者共用同一路音频：麦克风 tap 出来的 buffer
/// 同时写进 AVAudioFile（存档）和 SFSpeechAudioBufferRecognitionRequest（转写）。
final class VoiceRecorder: ObservableObject {

    enum RecorderError: LocalizedError {
        case permissionDenied
        case recognizerUnavailable
        case audioUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "需要麦克风与语音识别权限"
            case .recognizerUnavailable:
                return "当前语音识别服务不可用，请检查网络或系统设置中的「听写与语音」"
            case .audioUnavailable:
                return "麦克风被占用或不可用，请稍后再试"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var transcript = ""
    @Published private(set) var levels: [Double] = Array(repeating: 0.06, count: 40)
    @Published var errorMessage: String?
    @Published private(set) var needsPermission = false
    @Published private(set) var isOnDevice = false

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var startedAt: Date?
    private var timer: Timer?

    private static let barCount = 40

    // MARK: - 开始

    func start(store: NoteStore) {
        guard !isRecording else { return }
        errorMessage = nil
        needsPermission = false

        requestPermissions { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard granted else {
                    self.needsPermission = true
                    self.errorMessage = "没有「麦克风」或「语音识别」权限。请到 设置 → 语音速记 中开启后重试。"
                    return
                }
                do {
                    try self.beginRecording(store: store)
                } catch {
                    self.teardown()
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var speechGranted = false
        var micGranted = false

        group.enter()
        SFSpeechRecognizer.requestAuthorization { status in
            speechGranted = (status == .authorized)
            group.leave()
        }

        group.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            micGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            completion(speechGranted && micGranted)
        }
    }

    private func beginRecording(store: NoteStore) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            throw RecorderError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
            isOnDevice = true
        }
        request = req

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw RecorderError.audioUnavailable
        }

        let url = store.newAudioURL()
        outputURL = url
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            if let file = self?.audioFile {
                try? file.write(from: buffer)
            }
            let level = VoiceRecorder.normalizedLevel(buffer)
            DispatchQueue.main.async {
                self?.pushLevel(level)
            }
        }

        engine.prepare()
        try engine.start()

        transcript = ""
        elapsed = 0
        levels = Array(repeating: 0.06, count: Self.barCount)
        startedAt = Date()
        isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error = error, self.isRecording {
                    self.errorMessage = "语音识别中断：\(error.localizedDescription)"
                }
            }
        }

        startTimer()
    }

    // MARK: - 结束 / 取消

    @discardableResult
    func finish(store: NoteStore) -> Note? {
        guard isRecording, let url = outputURL else { return nil }
        let duration = Date().timeIntervalSince(startedAt ?? Date())
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        teardown()
        transcript = ""
        elapsed = 0

        guard duration >= 0.5 else {
            store.discardAudio(at: url)
            return nil
        }

        let note = Note(
            title: Note.autoTitle(from: text, date: Date()),
            transcript: text,
            createdAt: Date(),
            duration: duration,
            audioFileName: url.lastPathComponent
        )
        store.add(note)
        return note
    }

    func cancel(store: NoteStore) {
        if let url = outputURL {
            store.discardAudio(at: url)
        }
        teardown()
        transcript = ""
        elapsed = 0
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil

        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        recognizer = nil
        audioFile = nil
        outputURL = nil
        startedAt = nil
        isRecording = false
        isOnDevice = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 计时与波形

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startedAt else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func pushLevel(_ level: Double) {
        var next = levels
        if next.count >= Self.barCount {
            next.removeFirst(next.count - Self.barCount + 1)
        }
        next.append(max(0.06, min(1.0, level)))
        levels = next
    }

    /// 把音频缓冲区换算成 0~1 的响度，用于画波形
    private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0.06 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0.06 }

        var sum: Double = 0
        for index in 0..<frames {
            let sample = Double(channel[index])
            sum += sample * sample
        }
        let rms = (sum / Double(frames)).squareRoot()
        let db = 20 * log10(max(rms, 0.000_001))
        let normalized = (db + 50.0) / 50.0
        return min(1.0, max(0.05, normalized))
    }
}
