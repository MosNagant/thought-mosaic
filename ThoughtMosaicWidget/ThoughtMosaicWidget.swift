import WidgetKit
import SwiftUI

struct CaptureEntry: TimelineEntry { let date: Date }

struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry { CaptureEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(CaptureEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        completion(Timeline(entries: [CaptureEntry(date: Date())], policy: .never))
    }
}

struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CaptureEntry
    var body: some View {
        Group {
            if family == .accessoryCircular {
                Text("TM").font(.headline)
            } else {
                HStack(spacing: 14) {
                    Text("▣").font(.largeTitle).foregroundStyle(Color(white: 0.17))
                        .frame(width: 56, height: 56).background(.white, in: RoundedRectangle(cornerRadius: 14))
                    if family == .systemMedium {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thought Mosaic").font(.subheadline)
                            Text("拍照记录").font(.headline)
                        }
                        Spacer(minLength: 0)
                    }
                }.foregroundStyle(.white)
            }
        }
        .containerBackground(for: .widget) { Color(white: 43 / 255) }
        .widgetURL(URL(string: "thoughtmosaic://camera"))
        .accessibilityLabel("Thought Mosaic，拍照记录")
    }
}

@main
struct ThoughtMosaicWidget: Widget {
    let kind = "ThoughtMosaicQuickCapture"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { entry in CaptureWidgetView(entry: entry) }
            .configurationDisplayName("拍照记录")
            .description("在灵感出现的那一刻，留下照片与想法。")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
