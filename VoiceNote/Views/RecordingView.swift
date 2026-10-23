import SwiftUI
import UIKit

struct RecordingView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var recorder = VoiceRecorder()
    @State private var alert: RecorderAlert?

    private enum RecorderAlert: Identifiable {
        case error(String)
        case permission
        case discard

        var id: String {
            switch self {
            case .error: return "error"
            case .permission: return "permission"
            case .discard: return "discard"
            }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor.systemBackground), AppTheme.accent.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 10)
                timerBlock
                WaveformView(levels: recorder.levels)
                    .frame(height: 88)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                transcriptBox
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                Spacer(minLength: 10)
                controls
                    .padding(.bottom, 26)
            }
        }
        .onAppear {
            recorder.start(store: store)
        }
        .onChange(of: recorder.errorMessage) { value in
            guard let value = value, !value.isEmpty else { return }
            alert = recorder.needsPermission ? .permission : .error(value)
        }
        .alert(item: $alert) { kind -> Alert in
            switch kind {
            case .error(let message):
                return Alert(
                    title: Text("提示"),
                    message: Text(message),
                    dismissButton: .default(Text("知道了"))
                )
            case .permission:
                return Alert(
                    title: Text("需要权限"),
                    message: Text("请到「设置 → 语音速记」中开启麦克风与语音识别权限，然后重新进入本页。"),
                    primaryButton: .default(Text("去设置")) { openSettings() },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .discard:
                return Alert(
                    title: Text("放弃这段录音？"),
                    message: Text("当前录音和已经转写的文字都会丢失。"),
                    primaryButton: .destructive(Text("放弃")) { discardAndDismiss() },
                    secondaryButton: .cancel(Text("继续录音"))
                )
            }
        }
    }

    // MARK: - 子视图

    private var header: some View {
        HStack {
            Button {
                requestDiscard()
            } label: {
                Text("取消").font(.system(size: 16))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.danger)
                    .frame(width: 8, height: 8)
                    .opacity(recorder.isRecording ? 1 : 0.3)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                saveAndDismiss()
            } label: {
                Text("保存")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(!recorder.isRecording)
            .opacity(recorder.isRecording ? 1 : 0.35)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var statusText: String {
        guard recorder.isRecording else { return "未开始" }
        return recorder.isOnDevice ? "离线识别中" : "识别中"
    }

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(TimeFormat.clock(recorder.elapsed))
                .font(.system(size: 58, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
            Text(recorder.transcript.isEmpty ? "请对着手机说话" : "已转写 \(recorder.transcript.count) 字")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var transcriptBox: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if recorder.transcript.isEmpty {
                        Text("开始说话吧，转写的文字会实时出现在这里…")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(recorder.transcript)
                            .font(.system(size: 17))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .onChange(of: recorder.transcript) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            RecordButton(isRecording: true) {
                saveAndDismiss()
            }
            .opacity(recorder.isRecording ? 1 : 0.35)
            .disabled(!recorder.isRecording)

            Text("点一下结束并保存")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 动作

    private func saveAndDismiss() {
        recorder.finish(store: store)
        presentationMode.wrappedValue.dismiss()
    }

    private func requestDiscard() {
        if recorder.elapsed > 1 {
            alert = .discard
        } else {
            discardAndDismiss()
        }
    }

    private func discardAndDismiss() {
        recorder.cancel(store: store)
        presentationMode.wrappedValue.dismiss()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
