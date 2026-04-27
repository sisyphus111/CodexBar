import AppIntents
import CodexBarCore
import SwiftUI
import WidgetKit

struct CodexUsageIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Codex Usage"
    static let description = IntentDescription("Display usage for the active Codex account.")
}

struct CodexBarWidgetEntry: TimelineEntry {
    let date: Date
    let provider: UsageProvider
    let accountID: String?
    let snapshot: WidgetSnapshot
}

struct CodexBarTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CodexBarWidgetEntry {
        CodexBarWidgetEntry(
            date: Date(),
            provider: .codex,
            accountID: nil,
            snapshot: WidgetPreviewData.snapshot())
    }

    func snapshot(for configuration: CodexUsageIntent, in context: Context) async -> CodexBarWidgetEntry {
        CodexBarWidgetEntry(
            date: Date(),
            provider: .codex,
            accountID: nil,
            snapshot: WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot())
    }

    func timeline(
        for configuration: CodexUsageIntent,
        in context: Context) async -> Timeline<CodexBarWidgetEntry>
    {
        let snapshot = WidgetSnapshotStore.load() ?? WidgetPreviewData.emptySnapshot()
        let entry = CodexBarWidgetEntry(
            date: Date(),
            provider: .codex,
            accountID: nil,
            snapshot: snapshot)
        let refresh = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

struct CodexBarStaticTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexBarWidgetEntry {
        CodexBarWidgetEntry(
            date: Date(),
            provider: .codex,
            accountID: nil,
            snapshot: WidgetPreviewData.snapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexBarWidgetEntry) -> Void) {
        completion(self.makeEntry(snapshot: WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexBarWidgetEntry>) -> Void) {
        let entry = self.makeEntry(snapshot: WidgetSnapshotStore.load() ?? WidgetPreviewData.emptySnapshot())
        let refresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry(snapshot: WidgetSnapshot) -> CodexBarWidgetEntry {
        CodexBarWidgetEntry(
            date: Date(),
            provider: .codex,
            accountID: nil,
            snapshot: snapshot)
    }
}

enum WidgetPreviewData {
    static func emptySnapshot() -> WidgetSnapshot {
        WidgetSnapshot(entries: [], enabledProviders: [], generatedAt: Date())
    }

    static func snapshot() -> WidgetSnapshot {
        let primary = RateWindow(usedPercent: 35, windowMinutes: nil, resetsAt: nil, resetDescription: "Resets in 4h")
        let secondary = RateWindow(usedPercent: 60, windowMinutes: nil, resetsAt: nil, resetDescription: "Resets in 3d")
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            accountID: "preview@example.com",
            accountDisplayName: "preview@example.com",
            updatedAt: Date(),
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            creditsRemaining: 1243.4,
            codeReviewRemainingPercent: 78,
            tokenUsage: WidgetSnapshot.TokenUsageSummary(
                sessionCostUSD: 12.4,
                sessionTokens: 420_000,
                last30DaysCostUSD: 923.8,
                last30DaysTokens: 12_400_000),
            dailyUsage: [
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-01", totalTokens: 120_000, costUSD: 15.2),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-02", totalTokens: 80000, costUSD: 10.1),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-03", totalTokens: 140_000, costUSD: 17.9),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-04", totalTokens: 90000, costUSD: 11.4),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-05", totalTokens: 160_000, costUSD: 19.8),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-06", totalTokens: 70000, costUSD: 8.9),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-07", totalTokens: 110_000, costUSD: 13.7),
            ])
        return WidgetSnapshot(entries: [entry], generatedAt: Date())
    }
}
