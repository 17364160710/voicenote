import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var transcript: String
    var createdAt: Date
    var duration: TimeInterval
    var audioFileName: String?

    init(
        id: UUID = UUID(),
        title: String,
        transcript: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
    }

    var preview: String {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "（无文字转写）" : text
    }

    /// 用转写内容的前若干字自动生成标题
    static func autoTitle(from transcript: String, date: Date) -> String {
        let cleaned = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !cleaned.isEmpty else {
            return "语音备忘 " + TimeFormat.day(date)
        }
        let limit = 18
        if cleaned.count <= limit { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: limit)
        return String(cleaned[cleaned.startIndex..<end]) + "…"
    }
}
