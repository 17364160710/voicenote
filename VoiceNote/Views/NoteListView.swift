import SwiftUI

struct NoteListView: View {
    @EnvironmentObject private var store: NoteStore
    @State private var query = ""
    @State private var showRecorder = false

    private var filteredNotes: [Note] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.title.lowercased().contains(keyword) || $0.transcript.lowercased().contains(keyword)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                if store.notes.isEmpty {
                    emptyState
                } else {
                    noteList
                }
            }
            .navigationTitle("语音速记")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) { recordBar }
            .fullScreenCover(isPresented: $showRecorder) {
                RecordingView().environmentObject(store)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 列表

    private var noteList: some View {
        List {
            Section {
                ForEach(filteredNotes) { note in
                    NavigationLink(destination: NoteDetailView(note: note).environmentObject(store)) {
                        NoteRow(note: note)
                    }
                }
                .onDelete { offsets in
                    offsets.map { filteredNotes[$0] }.forEach { store.delete($0) }
                }
            } header: {
                Text("\(filteredNotes.count) 条备忘 · 共 \(TimeFormat.friendly(store.totalDuration))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 66, weight: .ultraLight))
                .foregroundColor(AppTheme.accent.opacity(0.55))
            Text("还没有备忘")
                .font(.system(size: 19, weight: .semibold))
            Text("点下面的按钮开始说话，\n文字会跟着你的声音实时出现。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.bottom, 60)
    }

    private var recordBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            Button {
                showRecorder = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("开始语音速记")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.recordGradient)
                )
                .shadow(color: AppTheme.accent.opacity(0.28), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
            Text(note.preview)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(TimeFormat.day(note.createdAt), systemImage: "clock")
                Label(TimeFormat.friendly(note.duration), systemImage: "waveform")
            }
            .font(.system(size: 11.5))
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
