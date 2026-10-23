import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let fileManager = FileManager.default
    private let indexFileName = "notes.json"

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var indexURL: URL {
        documentsURL.appendingPathComponent(indexFileName)
    }

    var audioDirectory: URL {
        let url = documentsURL.appendingPathComponent("Audio", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    init() {
        load()
    }

    // MARK: - 读写

    func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Note].self, from: data) {
            notes = decoded.sorted { $0.createdAt > $1.createdAt }
        }
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

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        if let name = note.audioFileName {
            let url = audioDirectory.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        let targets = offsets.map { notes[$0] }
        targets.forEach { delete($0) }
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
}
