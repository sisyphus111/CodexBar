import Foundation
import Testing
@testable import CodexBarCore

struct TokenUsageDecodingTests {
    @Test
    func `decodes daily token report`() throws {
        let json = """
        {
          "type": "daily",
          "data": [{
            "date": "2025-12-20",
            "inputTokens": 10,
            "cacheReadTokens": 2,
            "cacheCreationTokens": 3,
            "outputTokens": 20,
            "totalTokens": 30
          }],
          "summary": {
            "totalInputTokens": 10,
            "totalOutputTokens": 20,
            "cacheReadTokens": 2,
            "cacheCreationTokens": 3,
            "totalTokens": 30
          }
        }
        """

        let report = try JSONDecoder().decode(TokenUsageDailyReport.self, from: Data(json.utf8))
        #expect(report.data.count == 1)
        #expect(report.data[0].date == "2025-12-20")
        #expect(report.data[0].inputTokens == 10)
        #expect(report.data[0].outputTokens == 20)
        #expect(report.data[0].cacheReadTokens == 2)
        #expect(report.data[0].cacheCreationTokens == 3)
        #expect(report.data[0].totalTokens == 30)
        #expect(report.summary?.totalTokens == 30)
    }

    @Test
    func `decodes legacy daily token format`() throws {
        let json = """
        {
          "daily": [{
            "date": "2025-12-20",
            "inputTokens": 1,
            "cacheReadInputTokens": 2,
            "cacheCreationInputTokens": 3,
            "outputTokens": 2,
            "totalTokens": 3
          }],
          "totals": {
            "totalInputTokens": 1,
            "totalOutputTokens": 2,
            "totalCacheReadTokens": 2,
            "totalCacheCreationTokens": 3,
            "totalTokens": 3
          }
        }
        """

        let report = try JSONDecoder().decode(TokenUsageDailyReport.self, from: Data(json.utf8))
        #expect(report.data[0].cacheReadTokens == 2)
        #expect(report.data[0].cacheCreationTokens == 3)
        #expect(report.summary?.cacheReadTokens == 2)
        #expect(report.summary?.cacheCreationTokens == 3)
        #expect(report.summary?.totalTokens == 3)
    }

    @Test
    func `decodes legacy model map as token breakdowns`() throws {
        let json = """
        {
          "daily": [{
            "date": "Dec 20, 2025",
            "totalTokens": 30,
            "models": {
              "z-model": { "totalTokens": 10 },
              "a-model": { "totalTokens": 20 }
            }
          }]
        }
        """

        let report = try JSONDecoder().decode(TokenUsageDailyReport.self, from: Data(json.utf8))
        #expect(report.data[0].modelsUsed == ["a-model", "z-model"])
    }

    @Test
    func `decodes explicit model token breakdown`() throws {
        let json = """
        {
          "type": "daily",
          "data": [{
            "date": "2025-12-20",
            "totalTokens": 30,
            "modelBreakdowns": [
              { "modelName": "gpt-5.6-sol", "totalTokens": 30 }
            ]
          }]
        }
        """

        let report = try JSONDecoder().decode(TokenUsageDailyReport.self, from: Data(json.utf8))
        #expect(report.data[0].modelBreakdowns == [
            TokenUsageDailyReport.ModelBreakdown(modelName: "gpt-5.6-sol", totalTokens: 30),
        ])
    }

    @Test
    func `token snapshot selects most recent day and sums thirty day tokens`() {
        let report = TokenUsageDailyReport(
            data: [
                TokenUsageDailyReport.Entry(
                    date: "2025-12-20",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 30,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
                TokenUsageDailyReport.Entry(
                    date: "2025-12-21",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 10,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            summary: TokenUsageDailyReport.Summary(
                totalInputTokens: nil,
                totalOutputTokens: nil,
                totalTokens: 40))
        let now = Date(timeIntervalSince1970: 1_766_275_200)

        let snapshot = TokenUsageFetcher.tokenSnapshot(from: report, now: now)

        #expect(snapshot.sessionTokens == 10)
        #expect(snapshot.last30DaysTokens == 40)
        #expect(snapshot.daily.count == 2)
        #expect(snapshot.updatedAt == now)
    }
}
