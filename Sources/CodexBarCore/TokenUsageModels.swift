import Foundation

public struct TokenUsageTokenSnapshot: Sendable, Equatable {
    public let sessionTokens: Int?
    public let last30DaysTokens: Int?
    public let daily: [TokenUsageDailyReport.Entry]
    public let updatedAt: Date

    public init(
        sessionTokens: Int?,
        last30DaysTokens: Int?,
        daily: [TokenUsageDailyReport.Entry],
        updatedAt: Date)
    {
        self.sessionTokens = sessionTokens
        self.last30DaysTokens = last30DaysTokens
        self.daily = daily
        self.updatedAt = updatedAt
    }
}

public struct TokenUsageDailyReport: Sendable, Decodable {
    public struct ModelBreakdown: Sendable, Decodable, Equatable {
        public let modelName: String
        public let totalTokens: Int?

        public init(modelName: String, totalTokens: Int? = nil) {
            self.modelName = modelName
            self.totalTokens = totalTokens
        }
    }

    public struct Entry: Sendable, Decodable, Equatable {
        public let date: String
        public let inputTokens: Int?
        public let cacheReadTokens: Int?
        public let cacheCreationTokens: Int?
        public let outputTokens: Int?
        public let totalTokens: Int?
        public let modelsUsed: [String]?
        public let modelBreakdowns: [ModelBreakdown]?

        private enum CodingKeys: String, CodingKey {
            case date
            case inputTokens
            case cacheReadTokens
            case cacheCreationTokens
            case cacheReadInputTokens
            case cacheCreationInputTokens
            case outputTokens
            case totalTokens
            case modelsUsed
            case models
            case modelBreakdowns
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try container.decode(String.self, forKey: .date)
            self.inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
            self.cacheReadTokens =
                try container.decodeIfPresent(Int.self, forKey: .cacheReadTokens)
                ?? container.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens)
            self.cacheCreationTokens =
                try container.decodeIfPresent(Int.self, forKey: .cacheCreationTokens)
                ?? container.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
            self.outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)
            self.totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
            self.modelsUsed = Self.decodeModelsUsed(from: container)
            self.modelBreakdowns = try container.decodeIfPresent([ModelBreakdown].self, forKey: .modelBreakdowns)
        }

        public init(
            date: String,
            inputTokens: Int?,
            outputTokens: Int?,
            cacheReadTokens: Int? = nil,
            cacheCreationTokens: Int? = nil,
            totalTokens: Int?,
            modelsUsed: [String]?,
            modelBreakdowns: [ModelBreakdown]?)
        {
            self.date = date
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cacheReadTokens = cacheReadTokens
            self.cacheCreationTokens = cacheCreationTokens
            self.totalTokens = totalTokens
            self.modelsUsed = modelsUsed
            self.modelBreakdowns = modelBreakdowns
        }

        private static func decodeModelsUsed(from container: KeyedDecodingContainer<CodingKeys>) -> [String]? {
            if let modelsUsed = try? container.decodeIfPresent([String].self, forKey: .modelsUsed) {
                return modelsUsed
            }
            if let models = try? container.decodeIfPresent([String].self, forKey: .models) {
                return models
            }
            guard container.contains(.models),
                  let modelMap = try? container.nestedContainer(
                      keyedBy: TokenUsageAnyCodingKey.self,
                      forKey: .models)
            else {
                return nil
            }
            let modelNames = modelMap.allKeys.map(\.stringValue).sorted()
            return modelNames.isEmpty ? nil : modelNames
        }
    }

    public struct Summary: Sendable, Decodable, Equatable {
        public let totalInputTokens: Int?
        public let totalOutputTokens: Int?
        public let cacheReadTokens: Int?
        public let cacheCreationTokens: Int?
        public let totalTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case totalInputTokens
            case totalOutputTokens
            case cacheReadTokens
            case cacheCreationTokens
            case totalCacheReadTokens
            case totalCacheCreationTokens
            case totalTokens
        }

        public init(
            totalInputTokens: Int?,
            totalOutputTokens: Int?,
            cacheReadTokens: Int? = nil,
            cacheCreationTokens: Int? = nil,
            totalTokens: Int?)
        {
            self.totalInputTokens = totalInputTokens
            self.totalOutputTokens = totalOutputTokens
            self.cacheReadTokens = cacheReadTokens
            self.cacheCreationTokens = cacheCreationTokens
            self.totalTokens = totalTokens
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.totalInputTokens = try container.decodeIfPresent(Int.self, forKey: .totalInputTokens)
            self.totalOutputTokens = try container.decodeIfPresent(Int.self, forKey: .totalOutputTokens)
            self.cacheReadTokens =
                try container.decodeIfPresent(Int.self, forKey: .cacheReadTokens)
                ?? container.decodeIfPresent(Int.self, forKey: .totalCacheReadTokens)
            self.cacheCreationTokens =
                try container.decodeIfPresent(Int.self, forKey: .cacheCreationTokens)
                ?? container.decodeIfPresent(Int.self, forKey: .totalCacheCreationTokens)
            self.totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        }
    }

    public let data: [Entry]
    public let summary: Summary?

    private enum CodingKeys: String, CodingKey {
        case type
        case data
        case summary
        case daily
        case totals
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.type) {
            _ = try container.decode(String.self, forKey: .type)
            self.data = try container.decode([Entry].self, forKey: .data)
            self.summary = try container.decodeIfPresent(Summary.self, forKey: .summary)
        } else {
            self.data = try container.decode([Entry].self, forKey: .daily)
            self.summary = try container.decodeIfPresent(Summary.self, forKey: .totals)
        }
    }

    public init(data: [Entry], summary: Summary?) {
        self.data = data
        self.summary = summary
    }
}

extension TokenUsageDailyReport {
    private struct BreakdownAccumulator {
        var totalTokens = 0
        var sawTotalTokens = false

        mutating func add(_ breakdown: ModelBreakdown) {
            if let totalTokens = breakdown.totalTokens {
                self.totalTokens += totalTokens
                self.sawTotalTokens = true
            }
        }

        func build(modelName: String) -> ModelBreakdown {
            ModelBreakdown(modelName: modelName, totalTokens: self.sawTotalTokens ? self.totalTokens : nil)
        }
    }

    private struct EntryAccumulator {
        var inputTokens = 0
        var sawInputTokens = false
        var cacheReadTokens = 0
        var sawCacheReadTokens = false
        var cacheCreationTokens = 0
        var sawCacheCreationTokens = false
        var outputTokens = 0
        var sawOutputTokens = false
        var totalTokens = 0
        var sawTotalTokens = false
        var derivedTotalTokensWithoutExplicitTotal = 0
        var modelsUsed: Set<String> = []
        var breakdowns: [String: BreakdownAccumulator] = [:]

        mutating func add(_ entry: Entry) {
            let derived = (entry.inputTokens ?? 0)
                + (entry.cacheReadTokens ?? 0)
                + (entry.cacheCreationTokens ?? 0)
                + (entry.outputTokens ?? 0)
            if let value = entry.inputTokens { self.inputTokens += value; self.sawInputTokens = true }
            if let value = entry.cacheReadTokens { self.cacheReadTokens += value; self.sawCacheReadTokens = true }
            if let value = entry.cacheCreationTokens {
                self.cacheCreationTokens += value
                self.sawCacheCreationTokens = true
            }
            if let value = entry.outputTokens { self.outputTokens += value; self.sawOutputTokens = true }
            if let value = entry.totalTokens {
                self.totalTokens += value
                self.sawTotalTokens = true
            } else if derived > 0 {
                self.derivedTotalTokensWithoutExplicitTotal += derived
            }
            if let modelsUsed = entry.modelsUsed { self.modelsUsed.formUnion(modelsUsed) }
            for breakdown in entry.modelBreakdowns ?? [] {
                var accumulator = self.breakdowns[breakdown.modelName] ?? BreakdownAccumulator()
                accumulator.add(breakdown)
                self.breakdowns[breakdown.modelName] = accumulator
                self.modelsUsed.insert(breakdown.modelName)
            }
        }

        func build(date: String) -> Entry {
            let derived = self.inputTokens + self.cacheReadTokens + self.cacheCreationTokens + self.outputTokens
            let total: Int? = if self.sawTotalTokens {
                self.totalTokens + self.derivedTotalTokensWithoutExplicitTotal
            } else if derived > 0 {
                derived
            } else {
                nil
            }
            let breakdowns = self.breakdowns.isEmpty ? nil : TokenUsageDailyReport.sortedModelBreakdowns(
                self.breakdowns.map { $0.value.build(modelName: $0.key) })
            return Entry(
                date: date,
                inputTokens: self.sawInputTokens ? self.inputTokens : nil,
                outputTokens: self.sawOutputTokens ? self.outputTokens : nil,
                cacheReadTokens: self.sawCacheReadTokens ? self.cacheReadTokens : nil,
                cacheCreationTokens: self.sawCacheCreationTokens ? self.cacheCreationTokens : nil,
                totalTokens: total,
                modelsUsed: self.modelsUsed.isEmpty ? nil : self.modelsUsed.sorted(),
                modelBreakdowns: breakdowns)
        }
    }

    public static func merged(_ reports: [TokenUsageDailyReport]) -> TokenUsageDailyReport {
        var accumulators: [String: EntryAccumulator] = [:]
        for entry in reports.flatMap(\.data) {
            var accumulator = accumulators[entry.date] ?? EntryAccumulator()
            accumulator.add(entry)
            accumulators[entry.date] = accumulator
        }
        let entries = accumulators.keys.sorted().map { accumulators[$0, default: EntryAccumulator()].build(date: $0) }
        guard !entries.isEmpty else { return TokenUsageDailyReport(data: [], summary: nil) }
        return TokenUsageDailyReport(data: entries, summary: self.mergedSummary(from: entries))
    }

    private static func mergedSummary(from entries: [Entry]) -> Summary {
        func sum(_ keyPath: KeyPath<Entry, Int?>) -> Int? {
            let values = entries.compactMap { $0[keyPath: keyPath] }
            return values.isEmpty ? nil : values.reduce(0, +)
        }
        return Summary(
            totalInputTokens: sum(\.inputTokens),
            totalOutputTokens: sum(\.outputTokens),
            cacheReadTokens: sum(\.cacheReadTokens),
            cacheCreationTokens: sum(\.cacheCreationTokens),
            totalTokens: sum(\.totalTokens))
    }

    private static func sortedModelBreakdowns(_ values: [ModelBreakdown]) -> [ModelBreakdown] {
        values.sorted { lhs, rhs in
            let lhsTokens = lhs.totalTokens ?? -1
            let rhsTokens = rhs.totalTokens ?? -1
            if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }
            return lhs.modelName.localizedCaseInsensitiveCompare(rhs.modelName) == .orderedAscending
        }
    }
}

enum TokenUsageDateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(secondsFromGMT: 0)
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: raw)
    }
}

private struct TokenUsageAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
