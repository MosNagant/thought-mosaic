import SwiftUI
import AppIntents

struct LibraryView: View {
    @EnvironmentObject private var store: MosaicStore
    @State private var query = ""
    @State private var showGuide = false
    @State private var showEntryLab = false
    @State private var pendingCapture: CaptureSession?
    let capture: (MosaicNote, CaptureEntry) -> Void

    private var notes: [MosaicNote] {
        store.archive.notes.filter {
            query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        List {
            if store.sharedImportCount > 0 {
                Section { Label("已从分享导入 \(store.sharedImportCount) 条灵感", systemImage: "checkmark.circle") }
            }
            Section {
                Button("快捷唤醒体验 · A1 / A2 / B / C") { showEntryLab = true }
                    .accessibilityIdentifier("entryLab")
                Button { capture(MosaicNote(), .camera) } label: {
                    HStack(spacing: 14) {
                        Text("▣").font(.largeTitle).foregroundStyle(MosaicTheme.ink)
                            .frame(width: 56, height: 56).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thought Mosaic").font(.subheadline)
                            Text("拍照记录").font(.headline)
                        }
                        Spacer()
                    }.padding(14).frame(minHeight: 108)
                        .foregroundStyle(.white).background(MosaicTheme.action, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if let draft = store.archive.draft {
                Section("草稿") {
                    Button { capture(draft, .direct) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.title).lineLimit(2).foregroundStyle(MosaicTheme.ink)
                            Text("继续上次的记录").font(.caption).foregroundStyle(MosaicTheme.secondary)
                        }
                    }.accessibilityIdentifier("resumeDraft")
                }
            }
            Section("已保存 · \(store.archive.notes.count)") {
                if notes.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "给灵感留个位置" : "没有找到记录",
                                           systemImage: "square.and.pencil",
                                           description: Text(query.isEmpty ? "一句话、一张图，或一段语音。" : "试试其他文字或标签。"))
                }
                ForEach(notes) { note in
                    Button { capture(note, .direct) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.title).font(.body).lineLimit(3).foregroundStyle(MosaicTheme.ink)
                            if !note.tags.isEmpty {
                                Text(note.tags.map { "#\($0)" }.joined(separator: "  "))
                                    .font(.caption).foregroundStyle(MosaicTheme.secondary)
                            }
                            HStack {
                                Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                                Spacer()
                                if !note.attachments.isEmpty { Text("\(note.attachments.count) 份素材") }
                            }.font(.caption).foregroundStyle(MosaicTheme.muted)
                        }.padding(.vertical, 5)
                    }.accessibilityIdentifier("note-\(note.id)")
                }
            }
            Section {
                Button("导入截图") { capture(MosaicNote(), .screenshot) }
                Button("体验 Figma 示例") {
                    capture(MosaicNote(text: "两个人的手势很自然，想用在下一张人物画里。",
                                       tags: ["街头观察", "绘画参考"],
                                       attachments: [.init(kind: .sample, filename: "")]), .sample)
                }.accessibilityIdentifier("sampleFlow")
                Button("快捷入口使用说明") { showGuide = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Thought Mosaic")
        .searchable(text: $query, prompt: "搜索想法或标签")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { capture(MosaicNote(), .direct) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新建记录").accessibilityIdentifier("newNote")
            }
        }
        .sheet(isPresented: $showEntryLab, onDismiss: {
            if let pending = pendingCapture {
                pendingCapture = nil
                capture(pending.note, pending.entry)
            }
        }) {
            EntryLabView { note, entry in
                pendingCapture = CaptureSession(note: note, entry: entry)
                showEntryLab = false
            }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                List {
                    Section("桌面组件") { Text("长按 iPhone 桌面，添加 Thought Mosaic 小组件。点击“拍照记录”即可打开相机。") }
                    Section("截图分享 · A1") {
                        Text("完成系统截图 → 打开截图预览 → 分享 → Thought Mosaic。在分享面板内写想法、加标签并保存；下次打开 App 会自动导入。若首次找不到，请在分享列表的“更多”中启用 Thought Mosaic。")
                        Text("也可以在 App 中点击“导入截图”，从相册选择。系统截图浮窗不会增加自定义按钮；原型中的浮窗可在“快捷唤醒体验”中演示。")
                    }
                    Section("快捷指令 / 轻点背面") {
                        ShortcutsLink()
                        Text("打开“快捷指令” → 新建快捷指令 → 搜索 Thought Mosaic → 选择“记录灵感”“拍照记录”或“导入截图”。保存后，在 iPhone 设置 → 辅助功能 → 触控 → 轻点背面，选择运行这个快捷指令。支持操作按钮的机型也可绑定。")
                        Text("若快捷动作尚未索引，可使用“URL”与“打开 URL”两步，分别填写 thoughtmosaic://direct、thoughtmosaic://camera 或 thoughtmosaic://screenshot。")
                    }
                    Section("关于原型中的三指上滑") {
                        Text("“快捷唤醒体验”的 B 场景支持区域内三指上滑和按钮模拟。普通 iOS App 无法注册跨 App 的三指唤醒手势，实际系统入口请用轻点背面、快捷指令或桌面组件。")
                    }
                }.navigationTitle("快捷入口").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showGuide = false } } }
            }
        }
    }
}
