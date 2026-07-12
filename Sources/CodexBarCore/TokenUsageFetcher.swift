import Foundation

public enum TokenUsageError: LocalizedError, Sendable {
    case unsupportedProvider(UsageProvider)
    case timedOut(seconds: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Token history is not supported for \(provider.rawValue)."
        case let .timedOut(seconds):
            if seconds >= 60, seconds % 60 == 0 {
                return "Token refresh timed out after \(seconds / 60)m."
            }
            return "Token refresh timed out after \(seconds)s."
        }
    }
}

public struct TokenUsageFetcher: Sendable {
    public init() {}

    public func loadTokenSnapshot(
        provider: UsageProvider,
        now: Date = Date(),
        forceRefresh: Bool = false,
        allowVertexClaudeFallback: Bool = false) async throws -> TokenUsageTokenSnapshot
    {
        try await Self.loadTokenSnapshot(
            provider: provider,
            now: now,
            forceRefresh: forceRefresh,
            allowVertexClaudeFallback: allowVertexClaudeFallback)
    }

    static func loadTokenSnapshot(
        provider: UsageProvider,
        now: Date = Date(),
        forceRefresh: Bool = false,
        allowVertexClaudeFallback: Bool = false,
        scannerOptions overrideScannerOptions: TokenUsageScanner.Options? = nil,
        piScannerOptions overridePiScannerOptions: PiSessionTokenScanner
            .Options? = nil) async throws -> TokenUsageTokenSnapshot
    {
        guard provider == .codex || provider == .claude || provider == .vertexai else {
            throw TokenUsageError.unsupportedProvider(provider)
        }

        let until = now
        // Rolling window: last 30 days (inclusive). Use -29 for inclusive boundaries.
        let since = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now

        var options = overrideScannerOptions ?? TokenUsageScanner.Options()
        if provider == .vertexai {
            options.claudeLogProviderFilter = allowVertexClaudeFallback ? .all : .vertexAIOnly
        } else if provider == .claude {
            options.claudeLogProviderFilter = .excludeVertexAI
        }
        if forceRefresh {
            options.refreshMinIntervalSeconds = 0
            options.forceRescan = true
        }
        var daily = TokenUsageScanner.loadDailyReport(
            provider: provider,
            since: since,
            until: until,
            now: now,
            options: options)

        if provider == .vertexai,
           !allowVertexClaudeFallback,
           options.claudeLogProviderFilter == .vertexAIOnly,
           daily.data.isEmpty
        {
            var fallback = options
            fallback.claudeLogProviderFilter = .all
            daily = TokenUsageScanner.loadDailyReport(
                provider: provider,
                since: since,
                until: until,
                now: now,
                options: fallback)
        }

        if provider == .codex || provider == .claude {
            var piOptions = overridePiScannerOptions ?? PiSessionTokenScanner.Options()
            if piOptions.cacheRoot == nil {
                piOptions.cacheRoot = options.cacheRoot
            }
            if forceRefresh {
                piOptions.refreshMinIntervalSeconds = 0
                piOptions.forceRescan = true
            }
            let piReport = PiSessionTokenScanner.loadDailyReport(
                provider: provider,
                since: since,
                until: until,
                now: now,
                options: piOptions)
            daily = TokenUsageDailyReport.merged([daily, piReport])
        }

        return Self.tokenSnapshot(from: daily, now: now)
    }

    static func tokenSnapshot(from daily: TokenUsageDailyReport, now: Date) -> TokenUsageTokenSnapshot {
        // Pick the most recent day; break ties by tokens to keep a stable "today" row.
        let currentDay = daily.data.max { lhs, rhs in
            let lDate = TokenUsageDateParser.parse(lhs.date) ?? .distantPast
            let rDate = TokenUsageDateParser.parse(rhs.date) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.date < rhs.date
        }
        let totalTokensFromSummary = daily.summary?.totalTokens
        let totalTokensFromEntries = daily.data.compactMap(\.totalTokens).reduce(0, +)
        let last30DaysTokens = totalTokensFromSummary ?? (totalTokensFromEntries > 0 ? totalTokensFromEntries : nil)

        return TokenUsageTokenSnapshot(
            sessionTokens: currentDay?.totalTokens,
            last30DaysTokens: last30DaysTokens,
            daily: daily.data,
            updatedAt: now)
    }
}
