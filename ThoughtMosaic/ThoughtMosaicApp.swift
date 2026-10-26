import SwiftUI

@main
struct ThoughtMosaicApp: App {
    @StateObject private var store = MosaicStore()
    init() { MosaicAppShortcuts.updateAppShortcutParameters() }
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var launchRouter = MosaicLaunchRouter.shared
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
            let imported = store.importSharedCaptures()
            if let entry = launchRouter.pending {
                launchRouter.pending = nil
                route(entry)
            } else if !imported && store.sharedImportCount == 0 { open(note: store.archive.draft ?? MosaicNote(), entry: .direct) }
        }
        .onOpenURL { url in
            guard url.scheme == "thoughtmosaic" else { return }
            let entry = CaptureEntry(rawValue: url.host ?? "") ?? .direct
            route(entry)
        }
        .onReceive(launchRouter.$pending) { entry in
            guard let entry else { return }
            launchRouter.pending = nil
            route(entry)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.importSharedCaptures() } }
    }

    private func route(_ entry: CaptureEntry) {
        launched = true
        if session != nil { store.requestedEntry = entry }
        else { open(note: store.archive.draft ?? MosaicNote(), entry: entry) }
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
