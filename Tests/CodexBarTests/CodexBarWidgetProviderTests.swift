import Foundation
import Testing
@testable import CodexBarCore
@testable import CodexBarWidget

struct CodexBarWidgetProviderTests {
    @Test
    func `single account widget selection falls back to first codex entry`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let alpha = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            accountID: "alpha@example.com",
            accountDisplayName: "alpha@example.com",
            updatedAt: now,
            primary: nil,
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])
        let beta = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            accountID: "beta@example.com",
            accountDisplayName: "beta@example.com",
            updatedAt: now,
            primary: nil,
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])
        let snapshot = WidgetSnapshot(entries: [alpha, beta], enabledProviders: [.codex], generatedAt: now)

        #expect(WidgetEntrySelection.entry(in: snapshot, provider: .codex, accountID: nil)?.accountID == "alpha@example.com")
    }

    @Test
    func `single account widget selection ignores non codex entries`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .alibaba,
            updatedAt: now,
            primary: nil,
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])
        let snapshot = WidgetSnapshot(entries: [entry], enabledProviders: [.alibaba], generatedAt: now)

        #expect(WidgetEntrySelection.entry(in: snapshot, provider: .codex, accountID: nil) == nil)
    }

    @Test
    func `codex weekly only widget rows omit session`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: now,
            primary: nil,
            secondary: RateWindow(usedPercent: 25, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])

        let rows = WidgetUsageRow.rows(for: entry)

        #expect(rows.count == 1)
        #expect(rows.first?.title == "Weekly")
        #expect(rows.first?.percentLeft == 75)
    }

    @Test
    func `codex widget usage rows keep code review separate from rate rows`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 25, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: 60,
            tokenUsage: nil,
            dailyUsage: [])

        let rows = WidgetUsageRow.rows(for: entry)

        #expect(rows.map(\.title) == ["Session", "Weekly"])
        #expect(rows.count == 2)
        #expect(!rows.contains { $0.title == "Code review" })
    }

    @Test
    func `codex widget reset text matches menu formatter`() {
        let now = Date()
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval((2 * 24 * 60 * 60) + (10 * 60 * 60) + 1),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 25,
                windowMinutes: 10080,
                resetsAt: nil,
                resetDescription: "Resets in 1h 50m"),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])

        let rows = WidgetUsageRow.rows(for: entry)

        #expect(rows.first?.resetDetail == "Resets in 2d 10h")
        #expect(rows.last?.resetDetail == "Resets in 1h 50m")
    }

    @Test
    func `widget usage rows prefer projected rows over legacy slots`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 25, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            usageRows: [
                WidgetSnapshot.WidgetUsageRowSnapshot(id: "weekly", title: "Weekly", percentLeft: 75),
            ],
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])

        let rows = WidgetUsageRow.rows(for: entry)

        #expect(rows == [WidgetUsageRow(id: "weekly", title: "Weekly", percentLeft: 75)])
    }

    @Test
    func `widget configuration intent defaults to codex usage`() {
        let usageIntent = CodexUsageIntent()

        _ = usageIntent
    }
}
