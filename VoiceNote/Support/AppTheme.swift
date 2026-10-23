import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.38, green: 0.45, blue: 0.98)
    static let accentSoft = Color(red: 0.55, green: 0.42, blue: 0.95)
    static let danger = Color(red: 0.94, green: 0.33, blue: 0.33)

    static var recordGradient: LinearGradient {
        LinearGradient(
            colors: [accentSoft, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var waveformGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSoft],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum TimeFormat {    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func friendly(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        if total < 60 { return "\(total) 秒" }
        let minutes = total / 60
        let seconds = total % 60
        if minutes < 60 {
            return seconds == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(seconds) 秒"
        }
        let hours = minutes / 60
        return "\(hours) 小时 \(minutes % 60) 分"
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date()) {
            formatter.dateFormat = "M月d日 HH:mm"
        } else {
            formatter.dateFormat = "yyyy年M月d日"
        }
        return formatter.string(from: date)
    }
}

enum ByteFormat {
    static func string(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024.0)
    }
}
