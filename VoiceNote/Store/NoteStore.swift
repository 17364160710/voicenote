import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let fileManager = FileManager.default
    private let indexFileName = "notes.json"

    /// 索引是否成功读取。读失败时绝不做孤儿文件清理，
    /// 否则会把用户所有录音当垃圾删掉。
    private var indexLoaded = false

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var indexURL: URL {
        documentsURL.appendingPathComponent(indexFileName)
    }

    /// 所有录音都放在这个目录里，别处不写任何文件
    var audioDirectory: URL {
        let url = documentsURL.appendingPathComponent("Audio", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    init() {
        load()
        cleanupOrphans()
    }

    // MARK: - 读写

    func load() {
        guard let data = try? Data(contentsOf: indexURL) else {
            // 还没有索引文件，属于首次启动
            indexLoaded = true
            notes = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Note].self, from: data) else {
            // 索引损坏：保留现场，不清理任何音频，等用户处理
            indexLoaded = false
            return
        }
        notes = decoded.sorted { $0.createdAt > $1.createdAt }
        indexLoaded = true
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - 增删改

    @discardableResult
    func add(_ note: Note) -> Note {
        notes.insert(note, at: 0)
        persist()
        return note
    }

    func update(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        persist()
    }

    /// 删除备忘：先删索引里的记录，再删录音文件。两者都不残留。
    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        persist()

        if let name = note.audioFileName {
            let url = audioDirectory.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
        }
    }

    func delete(at offsets: IndexSet, from list: [Note]) {
        offsets.map { list[$0] }.forEach { delete($0) }
    }

    // MARK: - 清理

    /// 删掉没有被任何备忘引用的音频文件。
    /// 典型场景：录音过程中 App 被杀进程，.caf 留在磁盘上但没有对应的备忘。
    @discardableResult
    func cleanupOrphans() -> Int {
        guard indexLoaded else { return 0 }

        let referenced = Set(notes.compactMap { $0.audioFileName })
        guard let files = try? fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var removed = 0
        for file in files where !referenced.contains(file.lastPathComponent) {
            if (try? fileManager.removeItem(at: file)) != nil {
                removed += 1
            }
        }
        return removed
    }

    /// 清空全部数据：录音 + 索引。用于「清空所有备忘」以及验证卸载无残留。
    func resetAll() {
        notes = []
        indexLoaded = true

        if let files = try? fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        try? fileManager.removeItem(at: indexURL)
        persist()
    }

    // MARK: - 音频文件

    func newAudioURL() -> URL {
        audioDirectory.appendingPathComponent("\(UUID().uuidString).caf")
    }

    func audioURL(for note: Note) -> URL? {
        guard let name = note.audioFileName else { return nil }
        let url = audioDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func discardAudio(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    // MARK: - 统计

    var totalDuration: TimeInterval {
        notes.reduce(0) { $0 + $1.duration }
    }

    /// 磁盘占用：索引 + 全部录音
    var storageBytes: Int {
        var total = 0
        if let attrs = try? fileManager.attributesOfItem(atPath: indexURL.path),
           let size = attrs[.size] as? Int {
            total += size
        }
        if let files = try? fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in files {
                if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = values.fileSize {
                    total += size
                }
            }
        }
        return total
    }
}
