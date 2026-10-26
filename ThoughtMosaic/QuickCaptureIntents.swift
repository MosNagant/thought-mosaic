import AppIntents
import SwiftUI

@MainActor
final class MosaicLaunchRouter: ObservableObject {
    static let shared = MosaicLaunchRouter()
    @Published var pending: CaptureEntry?
}

struct OpenMosaicCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "记录灵感"
    static var description = IntentDescription("打开空白记录页，可绑定轻点背面和操作按钮。")
    static var openAppWhenRun: Bool { true }
    #if compiler(>=6.2)
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .foreground }
    #endif
    @MainActor func perform() async throws -> some IntentResult {
        MosaicLaunchRouter.shared.pending = .direct
        return .result()
    }
}

struct OpenMosaicCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "拍照记录"
    static var description = IntentDescription("打开 Thought Mosaic 相机，拍照后记录灵感。")
    static var openAppWhenRun: Bool { true }
    #if compiler(>=6.2)
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .foreground }
    #endif
    @MainActor func perform() async throws -> some IntentResult {
        MosaicLaunchRouter.shared.pending = .camera
        return .result()
    }
}

struct OpenMosaicScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "导入截图"
    static var description = IntentDescription("打开图片选择器，选择截图并记录灵感。")
    static var openAppWhenRun: Bool { true }
    #if compiler(>=6.2)
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .foreground }
    #endif
    @MainActor func perform() async throws -> some IntentResult {
        MosaicLaunchRouter.shared.pending = .screenshot
        return .result()
    }
}

struct MosaicAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenMosaicCaptureIntent(),
                    phrases: ["用 \(.applicationName) 记录灵感"], shortTitle: "记录灵感", systemImageName: "square.and.pencil")
        AppShortcut(intent: OpenMosaicCameraIntent(),
                    phrases: ["用 \(.applicationName) 拍照记录"], shortTitle: "拍照记录", systemImageName: "camera")
        AppShortcut(intent: OpenMosaicScreenshotIntent(),
                    phrases: ["用 \(.applicationName) 导入截图"], shortTitle: "导入截图", systemImageName: "photo")
    }
}
