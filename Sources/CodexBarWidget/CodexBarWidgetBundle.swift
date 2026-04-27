import SwiftUI
import WidgetKit

@main
struct CodexBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexBarAccountsWidget()
        CodexBarUsageWidget()
        CodexBarHistoryWidget()
    }
}

struct CodexBarAccountsWidget: Widget {
    private let kind = "CodexBarAccountsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: CodexBarStaticTimelineProvider()) { entry in
            CodexBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Dashboard")
        .description("Detailed usage for your Codex account.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CodexBarUsageWidget: Widget {
    private let kind = "CodexBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CodexUsageIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CodexBarHistoryWidget: Widget {
    private let kind = "CodexBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CodexUsageIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
