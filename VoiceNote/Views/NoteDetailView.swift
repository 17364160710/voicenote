import SwiftUI
import UIKit

struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var playback = AudioPlayback()

    private let original: Note
    @State private var draft: Note
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var didCopy = false

    init(note: Note) {
        self.original = note
        _draft = State(initialValue: note)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleCard
                playerCard
                transcriptCard
            }
            .padding(16)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("备忘详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.danger)
                }
            }
        }
        .onAppear {
            playback.prepare(with: store.audioURL(for: original))
        }
        .onDisappear {
            playback.stop()
            saveIfNeeded()
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareText])
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("删除这条备忘？"),
                message: Text("录音文件和转写文字会一起删除，无法恢复。"),
                primaryButton: .destructive(Text("删除")) {
                    playback.stop()
                    store.delete(original)
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - 卡片

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("给这条备忘起个名字", text: $draft.title)
                .font(.system(size: 18, weight: .semibold))
                .textFieldStyle(PlainTextFieldStyle())
        }
        .card()
    }

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(TimeFormat.day(draft.createdAt))
                Spacer()
                Text(TimeFormat.friendly(draft.duration))
            }
            .font(.system(size: 12.5))
            .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button {
                    playback.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.recordGradient)
                            .frame(width: 54, height: 54)
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!playback.isAvailable)
                .opacity(playback.isAvailable ? 1 : 0.35)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: playback.progress)
                        .accentColor(AppTheme.accent)
                    HStack {
                        Text(TimeFormat.clock(playback.currentTime))
                        Spacer()
                        Text(playback.isAvailable ? TimeFormat.clock(playback.duration) : "无录音文件")
                    }
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(.secondary)
                }
            }
        }
        .card()
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("转写文字")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = draft.transcript
                    didCopy = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        didCopy = false
                    }
                } label: {
                    Label(didCopy ? "已复制" : "复制", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
            }

            TextEditor(text: $draft.transcript)
                .font(.system(size: 16))
                .frame(height: 260)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )

            Text("可以直接修改上面的文字，返回列表时自动保存。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .card()
    }

    // MARK: - 数据

    private var shareText: String {
        var lines: [String] = []
        lines.append(draft.title)
        lines.append(TimeFormat.day(draft.createdAt) + " · " + TimeFormat.friendly(draft.duration))
        lines.append("")
        lines.append(draft.transcript.isEmpty ? "（无文字转写）" : draft.transcript)
        return lines.joined(separator: "\n")
    }

    private func saveIfNeeded() {
        guard draft != original else { return }
        var updated = draft
        if updated.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.title = Note.autoTitle(from: updated.transcript, date: updated.createdAt)
        }
        store.update(updated)
    }
}
