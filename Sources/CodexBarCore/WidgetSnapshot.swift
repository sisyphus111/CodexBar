import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public struct WidgetUsageRowSnapshot: Codable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let percentLeft: Double?

        public init(id: String, title: String, percentLeft: Double?) {
            self.id = id
            self.title = title
            self.percentLeft = percentLeft
        }
    }

    public struct ProviderEntry: Codable, Sendable {
        public let provider: UsageProvider
        public let accountID: String?
        public let accountDisplayName: String?
        public let planDisplayName: String?
        public let updatedAt: Date
        public let primary: RateWindow?
        public let secondary: RateWindow?
        public let tertiary: RateWindow?
        public let usageRows: [WidgetUsageRowSnapshot]?
        public let creditsRemaining: Double?
        public let codeReviewRemainingPercent: Double?
        public let tokenUsage: TokenUsageSummary?
        public let dailyUsage: [DailyUsagePoint]
        public let error: String?

        public init(
            provider: UsageProvider,
            accountID: String? = nil,
            accountDisplayName: String? = nil,
            planDisplayName: String? = nil,
            updatedAt: Date,
            primary: RateWindow?,
            secondary: RateWindow?,
            tertiary: RateWindow?,
            usageRows: [WidgetUsageRowSnapshot]? = nil,
            creditsRemaining: Double?,
            codeReviewRemainingPercent: Double?,
            tokenUsage: TokenUsageSummary?,
            dailyUsage: [DailyUsagePoint],
            error: String? = nil)
        {
            self.provider = provider
            self.accountID = accountID
            self.accountDisplayName = accountDisplayName
            self.planDisplayName = planDisplayName
            self.updatedAt = updatedAt
            self.primary = primary
            self.secondary = secondary
            self.tertiary = tertiary
            self.usageRows = usageRows
            self.creditsRemaining = creditsRemaining
            self.codeReviewRemainingPercent = codeReviewRemainingPercent
            self.tokenUsage = tokenUsage
            self.dailyUsage = dailyUsage
            self.error = error
        }
    }

    public struct TokenUsageSummary: Codable, Sendable {
        public let sessionCostUSD: Double?
        public let sessionTokens: Int?
        public let last30DaysCostUSD: Double?
        public let last30DaysTokens: Int?

        public init(
            sessionCostUSD: Double?,
            sessionTokens: Int?,
            last30DaysCostUSD: Double?,
            last30DaysTokens: Int?)
        {
            self.sessionCostUSD = sessionCostUSD
            self.sessionTokens = sessionTokens
            self.last30DaysCostUSD = last30DaysCostUSD
            self.last30DaysTokens = last30DaysTokens
        }
    }

    public struct DailyUsagePoint: Codable, Sendable {
        public let dayKey: String
        public let totalTokens: Int?
        public let costUSD: Double?

        public init(dayKey: String, totalTokens: Int?, costUSD: Double?) {
            self.dayKey = dayKey
            self.totalTokens = totalTokens
            self.costUSD = costUSD
        }
    }

    public let entries: [ProviderEntry]
    public let enabledProviders: [UsageProvider]
    public let generatedAt: Date

    public init(entries: [ProviderEntry], enabledProviders: [UsageProvider]? = nil, generatedAt: Date) {
        self.entries = entries
        self.enabledProviders = enabledProviders ?? entries.map(\.provider)
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case entries
        case enabledProviders
        case generatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entries = try container.decode([ProviderEntry].self, forKey: .entries)
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.enabledProviders = try container.decodeIfPresent([UsageProvider].self, forKey: .enabledProviders)
            ?? self.entries.map(\.provider)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.entries, forKey: .entries)
        try container.encode(self.enabledProviders, forKey: .enabledProviders)
        try container.encode(self.generatedAt, forKey: .generatedAt)
    }
}

public enum WidgetSnapshotStore {
    private static let filename = AppGroupSupport.widgetSnapshotFilename

    public static func load(bundleID: String? = Bundle.main.bundleIdentifier) -> WidgetSnapshot? {
        let url = self.snapshotURL(bundleID: bundleID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? self.decoder.decode(WidgetSnapshot.self, from: data)
    }

    public static func save(_ snapshot: WidgetSnapshot, bundleID: String? = Bundle.main.bundleIdentifier) {
        let urls = self.saveURLs(bundleID: bundleID)
        let data: Data
        do {
            data = try self.encoder.encode(snapshot)
        } catch {
            return
        }

        for url in urls {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                continue
            }
        }
    }

    private static func snapshotURL(bundleID: String?) -> URL {
        AppGroupSupport.snapshotURL(bundleID: bundleID)
    }

    private static func saveURLs(bundleID: String?) -> [URL] {
        let primaryURL = self.snapshotURL(bundleID: bundleID)
        let fallbackURL = AppGroupSupport.localFallbackDirectory(bundleID: bundleID)
            .appendingPathComponent(self.filename, isDirectory: false)
        var seen = Set<String>()
        return [primaryURL, fallbackURL].filter { seen.insert($0.path).inserted }
    }

    public static func appGroupID(for bundleID: String?) -> String? {
        AppGroupSupport.currentGroupID(for: bundleID)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
