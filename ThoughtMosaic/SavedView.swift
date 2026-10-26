import SwiftUI

struct SavedView: View {
    let note: MosaicNote
    let done: () -> Void
    let again: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("✓").font(.largeTitle.bold()).foregroundStyle(.white)
                    .frame(width: 82, height: 82).background(MosaicTheme.action, in: Circle())
                    .accessibilityHidden(true)
                Text("已保存").font(.title.bold()).accessibilityIdentifier("savedTitle")
                Text("记录已经保存到 Thought Mosaic。")
                    .font(.subheadline).foregroundStyle(MosaicTheme.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text("本次保存内容").font(.subheadline.bold())
                    Text(summary).font(.footnote).foregroundStyle(MosaicTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(MosaicTheme.subtle, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MosaicTheme.line))
                Button("完成", action: done).buttonStyle(MosaicButtonStyle(primary: true))
                    .accessibilityIdentifier("finishCapture")
                Button("继续记录", action: again).buttonStyle(MosaicButtonStyle())
                    .accessibilityIdentifier("captureAgain")
            }.padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 30)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
    }
    private var summary: String {
        var pieces: [String] = []
        if !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pieces.append("想法文字") }
        if !note.attachments.isEmpty { pieces.append("\(note.attachments.count) 份素材") }
        if !note.tags.isEmpty { pieces.append("\(note.tags.count) 个标签") }
        return pieces.joined(separator: "、") + "已一起保留在此设备。"
    }
}
