import SwiftUI

enum MosaicTheme {
    static let ink = Color(white: 17 / 255)
    static let action = Color(white: 43 / 255)
    static let secondary = Color(white: 102 / 255)
    static let muted = Color(white: 154 / 255)
    static let line = Color(white: 208 / 255)
    static let material = Color(white: 232 / 255)
    static let subtle = Color(white: 243 / 255)
}

struct MosaicButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(primary ? (enabled ? .white : MosaicTheme.secondary) : MosaicTheme.ink)
            .background(primary ? (enabled ? MosaicTheme.action : MosaicTheme.line) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(primary ? .clear : MosaicTheme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct TagChip: View {
    let text: String
    var selected = false
    var body: some View {
        Text((selected ? "✓  " : "") + text)
            .font(.subheadline)
            .foregroundStyle(MosaicTheme.ink)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(selected ? MosaicTheme.material : Color(.systemBackground), in: Capsule())
            .overlay(Capsule().stroke(selected ? MosaicTheme.ink : MosaicTheme.line, lineWidth: selected ? 1.5 : 1))
    }
}

/// Tags wrap naturally on smaller phones and with larger accessibility text.
struct TagFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 350, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                 proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        var positions: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            row = max(row, size.height)
        }
        return (CGSize(width: width, height: y + row), positions)
    }
}

/// The source Figma uses three gray rounded frames, not an image asset.
struct SampleMaterialView: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18).fill(Color(white: 212 / 255))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MosaicTheme.muted))
                .frame(maxWidth: 68, minHeight: 96, maxHeight: 96)
            RoundedRectangle(cornerRadius: 10).fill(Color(white: 225 / 255))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MosaicTheme.line))
                .frame(maxWidth: 150, minHeight: 78, maxHeight: 78)
            RoundedRectangle(cornerRadius: 18).fill(Color(white: 204 / 255))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MosaicTheme.muted))
                .frame(maxWidth: 68, minHeight: 96, maxHeight: 96)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .accessibilityLabel("Figma 灰色示例素材")
    }
}
