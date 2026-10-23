import SwiftUI

@main
struct VoiceNoteApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            NoteListView()
                .environmentObject(store)
                .accentColor(AppTheme.accent)
        }
    }
}
