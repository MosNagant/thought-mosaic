import SwiftUI
import UIKit

enum EntryPlan: String, CaseIterable, Identifiable {
    case a1 = "A1", a2 = "A2", b = "B", c = "C"
    var id: String { rawValue }
    var title: String {
        switch self { case .a1: return "截图后记录"; case .a2: return "拍照快捷组件"; case .b: return "三指上滑"; case .c: return "直接打开 App" }
    }
    var explanation: String {
        switch self {
        case .a1: return "这里模拟 Figma 的截图浮窗。真实使用：截图 → 分享 → Thought Mosaic，可以带图写想法并保存。"
        case .a2: return "这里演示桌面组件。你也可以在 iPhone 主屏幕添加真实的 Thought Mosaic 拍照记录组件。"
        case .b: return "三指在下面的灰色区域向上滑动，或点击模拟按钮。这个手势只在演示区域生效；跨 App 可改用轻点背面或操作按钮。"
        case .c: return "点击下方 App 图标，进入一张空白记录。真实 App 冷启动也会直接进入记录，有草稿则恢复。"
        }
    }
}

struct EntryLabView: View {
    @EnvironmentObject private var store: MosaicStore
    @Environment(\.dismiss) private var dismiss
    @State private var plan = EntryPlan.a1
    @State private var screenshot: UIImage?
    @State private var cameraStep = false
    @State private var error: String?
    @State private var opened = false
    let capture: (MosaicNote, CaptureEntry) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("快捷唤醒方案", selection: $plan) {
                        ForEach(EntryPlan.allCases) { item in Text(item.rawValue).tag(item) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("entryPlanPicker")
                    Text("方案 \(plan.rawValue) · \(plan.title)").font(.title3.bold())
                    Text("原型场景 · 可交互演示").font(.caption).foregroundStyle(.secondary)
                    Text(plan.explanation).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    scene.padding(16).frame(maxWidth: 390, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MosaicTheme.line))
                        .frame(maxWidth: .infinity)
                }.padding(20)
            }
            .background(MosaicTheme.subtle)
            .navigationTitle("快捷唤醒体验").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
            .onChange(of: plan) { _, _ in screenshot = nil; cameraStep = false; opened = false }
            .alert("提示", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("知道了") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    @ViewBuilder private var scene: some View {
        switch plan {
        case .a1:
            VStack(alignment: .leading, spacing: 12) {
                BrowsingPrototype()
                Text("用户在这里看到想保存的灵感内容。").font(.subheadline)
                if let screenshot {
                    Image(uiImage: screenshot).resizable().scaledToFill().frame(width: 155, height: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                    Button("记录灵感") { launchScreenshot(screenshot) }
                        .buttonStyle(MosaicButtonStyle(primary: true)).frame(width: 155).accessibilityIdentifier("entryA1Record")
                } else {
                    Button("模拟截图") {
                        let renderer = ImageRenderer(content: BrowsingPrototype().padding(12).frame(width: 350).background(.white))
                        renderer.scale = 2
                        screenshot = renderer.uiImage
                        if screenshot == nil { error = "截图生成失败，请重试。" }
                    }.buttonStyle(MosaicButtonStyle(primary: true)).accessibilityIdentifier("entryA1Screenshot")
                }
            }
        case .a2:
            VStack(alignment: .leading, spacing: 18) {
                if cameraStep {
                    Text("拍照 · 演示素材").font(.headline)
                    SampleMaterialView().frame(height: 220).background(MosaicTheme.material, in: RoundedRectangle(cornerRadius: 14))
                    Button("拍下示例画面") {
                        launch(MosaicNote(attachments: [.init(kind: .sample, filename: "")]), .sample)
                    }.buttonStyle(MosaicButtonStyle(primary: true)).accessibilityIdentifier("entryA2Shutter")
                    Button("使用真实相机") { launch(MosaicNote(), .camera) }.buttonStyle(MosaicButtonStyle())
                    Button("返回桌面") { cameraStep = false }.frame(minHeight: 44)
                } else {
                    Text("手机桌面").font(.subheadline).foregroundStyle(.secondary)
                    Button { cameraStep = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "camera").font(.title).foregroundStyle(MosaicTheme.ink)
                                .frame(width: 56, height: 56).background(.white, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Thought Mosaic").font(.subheadline)
                                Text("拍照记录").font(.headline)
                            }
                            Spacer()
                        }.padding(14).frame(minHeight: 108).foregroundStyle(.white)
                            .background(MosaicTheme.action, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityIdentifier("entryA2Widget")
                    appIcons
                }
            }
        case .b:
            VStack(alignment: .leading, spacing: 12) {
                Text("正在使用手机").font(.headline)
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 16).fill(Color(white: 216 / 255)).frame(height: 170)
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 12).fill(Color(white: 225 / 255))
                        RoundedRectangle(cornerRadius: 12).fill(Color(white: 204 / 255))
                    }.frame(height: 85)
                }.overlay(ThreeFingerSwipe { launch(MosaicNote(), .direct) }.accessibilityHidden(true))
                Button("模拟三指上滑 ↑") { launch(MosaicNote(), .direct) }
                    .buttonStyle(MosaicButtonStyle(primary: true)).accessibilityIdentifier("entryBSwipe")
            }
        case .c:
            VStack(alignment: .leading, spacing: 18) {
                Text("手机桌面").font(.subheadline).foregroundStyle(.secondary)
                appIcons
                Spacer(minLength: 190)
            }
        }
    }
    private var appIcons: some View {
        HStack(alignment: .top, spacing: 22) {
            Button { launch(MosaicNote(), .direct) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TM").font(.headline.bold()).foregroundStyle(.white).frame(width: 64, height: 64)
                        .background(MosaicTheme.action, in: RoundedRectangle(cornerRadius: 16))
                    Text("Thought Mosaic").font(.system(size: 11)).foregroundStyle(MosaicTheme.ink)
                }.frame(width: 80, alignment: .leading)
            }.buttonStyle(.plain).accessibilityIdentifier("entryCApp")
            ForEach(0..<2) { _ in
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 16).fill(MosaicTheme.material).frame(width: 64, height: 64)
                    Text("其他 App").font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: 80, alignment: .leading)
            }
        }
    }
    private func launchScreenshot(_ image: UIImage) {
        do { launch(MosaicNote(attachments: [try store.importImage(image, kind: .screenshot)]), .direct) }
        catch { self.error = error.localizedDescription }
    }
    private func launch(_ note: MosaicNote, _ entry: CaptureEntry) {
        guard !opened else { return }
        opened = true
        capture(note, entry)
    }
}

private struct BrowsingPrototype: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) { Text("⌕"); Text("正在浏览内容").font(.subheadline).foregroundStyle(.secondary); Spacer() }
                .padding(10).frame(height: 46).background(MosaicTheme.material, in: RoundedRectangle(cornerRadius: 14))
            RoundedRectangle(cornerRadius: 14).fill(MosaicTheme.material).frame(height: 150)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12).fill(Color(white: 216 / 255))
                RoundedRectangle(cornerRadius: 12).fill(Color(white: 227 / 255))
            }.frame(height: 105)
        }
    }
}

private struct ThreeFingerSwipe: UIViewRepresentable {
    let action: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView(); view.backgroundColor = .clear
        let gesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipe))
        gesture.direction = .up; gesture.numberOfTouchesRequired = 3
        gesture.delegate = context.coordinator
        view.addGestureRecognizer(gesture)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.action = action }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func swipe() { action() }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
