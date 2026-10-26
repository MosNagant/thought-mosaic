import SwiftUI

struct TagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var chosen: [String]
    let recent: [String]
    let onDone: ([String]) -> Void

    init(selected: [String], recent: [String], onDone: @escaping ([String]) -> Void) {
        _chosen = State(initialValue: selected)
        self.recent = recent
        self.onDone = onDone
    }

    private var cleaned: String { String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24)) }
    private var tags: [String] {
        MosaicNote.normalizedTags(recent + chosen).filter { cleaned.isEmpty || $0.localizedCaseInsensitiveContains(cleaned) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    TextField("搜索或创建标签", text: $query)
                        .font(.subheadline).padding(12).frame(minHeight: 48)
                        .background(MosaicTheme.material, in: RoundedRectangle(cornerRadius: 10))
                        .submitLabel(.done).onSubmit(createTag)
                        .accessibilityIdentifier("tagSearch")
                    Text(cleaned.isEmpty ? "最近使用" : "搜索结果").font(.subheadline.bold())
                    TagFlow(spacing: 10) {
                        ForEach(tags, id: \.self) { tag in
                            Button { toggle(tag) } label: { TagChip(text: tag, selected: chosen.contains(tag)) }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(chosen.contains(tag) ? .isSelected : [])
                        }
                    }
                    if !cleaned.isEmpty && !tags.contains(where: { $0.lowercased() == cleaned.lowercased() }) {
                        Button("＋ 创建“\(cleaned)”", action: createTag)
                            .buttonStyle(MosaicButtonStyle()).accessibilityIdentifier("createTag")
                    }
                    Button("完成") { onDone(chosen); dismiss() }
                        .buttonStyle(MosaicButtonStyle(primary: true)).padding(.top, 4)
                        .accessibilityIdentifier("confirmTags")
                }.padding(18)
            }
            .navigationTitle("添加标签").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.accessibilityLabel("取消标签修改")
                }
            }
        }
        .presentationDetents([.height(370), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(26)
    }

    private func toggle(_ tag: String) {
        if chosen.contains(tag) { chosen.removeAll { $0 == tag } } else { chosen.append(tag) }
    }
    private func createTag() {
        guard !cleaned.isEmpty else { return }
        chosen = MosaicNote.normalizedTags(chosen + [cleaned])
        query = ""
    }
}
