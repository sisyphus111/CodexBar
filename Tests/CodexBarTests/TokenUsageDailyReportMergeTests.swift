import Testing
@testable import CodexBarCore

struct TokenUsageDailyReportMergeTests {
    @Test
    func `merged report sums overlapping day totals and model breakdowns`() {
        let native = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-04",
                inputTokens: 100,
                outputTokens: 20,
                cacheReadTokens: 10,
                totalTokens: 130,
                modelsUsed: ["gpt-5.6-sol"],
                modelBreakdowns: [
                    TokenUsageDailyReport.ModelBreakdown(modelName: "gpt-5.6-sol", totalTokens: 130),
                ])],
            summary: TokenUsageDailyReport.Summary(
                totalInputTokens: 100,
                totalOutputTokens: 20,
                cacheReadTokens: 10,
                totalTokens: 130))
        let pi = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-04",
                inputTokens: 50,
                outputTokens: 10,
                cacheReadTokens: 5,
                cacheCreationTokens: 2,
                totalTokens: 67,
                modelsUsed: ["gpt-5.6-sol"],
                modelBreakdowns: [
                    TokenUsageDailyReport.ModelBreakdown(modelName: "gpt-5.6-sol", totalTokens: 67),
                ])],
            summary: TokenUsageDailyReport.Summary(
                totalInputTokens: 50,
                totalOutputTokens: 10,
                cacheReadTokens: 5,
                cacheCreationTokens: 2,
                totalTokens: 67))

        let merged = TokenUsageDailyReport.merged([native, pi])

        #expect(merged.data.count == 1)
        #expect(merged.data.first?.inputTokens == 150)
        #expect(merged.data.first?.outputTokens == 30)
        #expect(merged.data.first?.cacheReadTokens == 15)
        #expect(merged.data.first?.cacheCreationTokens == 2)
        #expect(merged.data.first?.totalTokens == 197)
        #expect(merged.data.first?.modelBreakdowns == [
            TokenUsageDailyReport.ModelBreakdown(modelName: "gpt-5.6-sol", totalTokens: 197),
        ])
        #expect(merged.summary?.totalTokens == 197)
    }

    @Test
    func `merged report unions days and preserves token totals`() {
        let first = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-04",
                inputTokens: nil,
                outputTokens: nil,
                totalTokens: 30,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            summary: nil)
        let second = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-05",
                inputTokens: nil,
                outputTokens: nil,
                totalTokens: 40,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            summary: nil)

        let merged = TokenUsageDailyReport.merged([first, second])

        #expect(merged.data.map(\.date) == ["2026-04-04", "2026-04-05"])
        #expect(merged.summary?.totalTokens == 70)
    }

    @Test
    func `merged report includes derived token totals`() {
        let explicit = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-04",
                inputTokens: 70,
                outputTokens: 30,
                totalTokens: 100,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            summary: nil)
        let derived = TokenUsageDailyReport(
            data: [TokenUsageDailyReport.Entry(
                date: "2026-04-04",
                inputTokens: 10,
                outputTokens: 5,
                cacheReadTokens: 3,
                cacheCreationTokens: 2,
                totalTokens: nil,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            summary: nil)

        let merged = TokenUsageDailyReport.merged([explicit, derived])

        #expect(merged.data.first?.totalTokens == 120)
        #expect(merged.summary?.totalTokens == 120)
    }
}
