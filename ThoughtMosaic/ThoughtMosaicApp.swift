import SwiftUI

@main
struct ThoughtMosaicApp: App {
    @StateObject private var store = MosaicStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .tint(MosaicTheme.action)
                .preferredColorScheme(.light)
        }
    }
}

enum CaptureEntry: String { case direct, camera, screenshot, sample }

struct CaptureSession: Identifiable {
    var id = UUID()
    var note: MosaicNote
    var entry: CaptureEntry = .direct
}

struct RootView: View {
    @EnvironmentObject private var store: MosaicStore
    @State private var session: CaptureSession?
    @State private var launched = false
    var body: some View {
        NavigationStack {
            LibraryView { note, entry in open(note: note, entry: entry) }
        }
        .fullScreenCover(item: $session, onDismiss: resumePendingEntry) { value in
            CaptureView(note: value.note, entry: value.entry)
        }
        .task {
            guard !launched else { return }
            launched = true
            open(note: store.archive.draft ?? MosaicNote(), entry: .direct)
        }
        .onOpenURL { url in
            guard url.scheme == "thoughtmosaic" else { return }
            let entry = CaptureEntry(rawValue: url.host ?? "") ?? .direct
            if session != nil {
                // Do not replace an active editor and lose its unsaved content.
                store.requestedEntry = entry
            } else { open(note: store.archive.draft ?? MosaicNote(), entry: entry) }
        }
    }

    private func open(note: MosaicNote, entry: CaptureEntry) {
        session = CaptureSession(note: note, entry: entry)
    }
    private func resumePendingEntry() {
        guard let entry = store.requestedEntry else { return }
        store.requestedEntry = nil
        open(note: store.archive.draft ?? MosaicNote(), entry: entry)
    }
}
