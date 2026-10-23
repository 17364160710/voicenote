import SwiftUI

/// 实时波形：把录音响度按条画成胶囊柱
struct WaveformView: View {
    var levels: [Double]
    var tint: LinearGradient = AppTheme.waveformGradient

    private let spacing: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let totalSpacing = spacing * CGFloat(count - 1)
            let barWidth = max(1.5, (geo.size.width - totalSpacing) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(
                            width: barWidth,
                            height: max(3, geo.size.height * CGFloat(levels[index]))
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }
}

/// 录音主按钮：中间一个圆，外圈随录音状态呼吸
struct RecordButton: View {
    var isRecording: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.recordGradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, x: 0, y: 8)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: isRecording ? 26 : 30, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isRecording ? "结束录音" : "开始录音")
    }
}
