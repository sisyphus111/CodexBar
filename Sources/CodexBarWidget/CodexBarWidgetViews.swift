import CodexBarCore
import SwiftUI
import WidgetKit

struct CodexBarUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarWidgetEntry

    var body: some View {
        let providerEntry = WidgetEntrySelection.entry(
            in: self.entry.snapshot,
            provider: self.entry.provider,
            accountID: self.entry.accountID)
        ZStack {
            if let providerEntry {
                self.content(providerEntry: providerEntry)
            } else {
                self.emptyState
            }
        }
        .containerBackground(.regularMaterial, for: .widget)
    }

    @ViewBuilder
    private func content(providerEntry: WidgetSnapshot.ProviderEntry) -> some View {
        switch self.family {
        case .systemSmall:
            SmallUsageView(entry: providerEntry)
        case .systemMedium:
            MediumUsageView(entry: providerEntry)
        default:
            LargeUsageView(entry: providerEntry)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open CodexBar")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct CodexBarHistoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarWidgetEntry

    var body: some View {
        let providerEntry = WidgetEntrySelection.entry(
            in: self.entry.snapshot,
            provider: self.entry.provider,
            accountID: self.entry.accountID)
        ZStack {
            if let providerEntry {
                HistoryView(entry: providerEntry, isLarge: self.family == .systemLarge)
            } else {
                self.emptyState
            }
        }
        .containerBackground(.regularMaterial, for: .widget)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open CodexBar")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage history will appear after a refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

enum WidgetEntrySelection {
    static func entry(in snapshot: WidgetSnapshot, provider: UsageProvider, accountID: String?)
        -> WidgetSnapshot.ProviderEntry?
    {
        let providerEntries = snapshot.entries.filter { $0.provider == provider }
        if let accountID,
           let match = providerEntries.first(where: { $0.accountID == accountID })
        {
            return match
        }
        return providerEntries.first
    }
}

private struct SmallUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                updatedAt: self.entry.updatedAt)
            ForEach(WidgetUsageRow.rows(for: self.entry)) { row in
                UsageBarRow(
                    title: row.title,
                    percentLeft: row.percentLeft,
                    resetDetail: row.resetDetail,
                    color: WidgetColors.color(for: self.entry.provider))
            }
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    resetDetail: nil,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(12)
    }
}

private struct MediumUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                updatedAt: self.entry.updatedAt)
            ForEach(WidgetUsageRow.rows(for: self.entry)) { row in
                UsageBarRow(
                    title: row.title,
                    percentLeft: row.percentLeft,
                    resetDetail: row.resetDetail,
                    color: WidgetColors.color(for: self.entry.provider))
            }
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    resetDetail: nil,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(12)
    }
}

private struct LargeUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                updatedAt: self.entry.updatedAt)
            ForEach(WidgetUsageRow.rows(for: self.entry)) { row in
                UsageBarRow(
                    title: row.title,
                    percentLeft: row.percentLeft,
                    resetDetail: row.resetDetail,
                    color: WidgetColors.color(for: self.entry.provider))
            }
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    resetDetail: nil,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(12)
    }
}

struct WidgetUsageRow: Identifiable, Equatable {
    let id: String
    let title: String
    let percentLeft: Double?
    let resetDetail: String?

    init(id: String, title: String, percentLeft: Double?, resetDetail: String? = nil) {
        self.id = id
        self.title = title
        self.percentLeft = percentLeft
        self.resetDetail = resetDetail
    }

    static func rows(for entry: WidgetSnapshot.ProviderEntry) -> [WidgetUsageRow] {
        if let usageRows = entry.usageRows {
            return usageRows.map { row in
                WidgetUsageRow(
                    id: row.id,
                    title: row.title,
                    percentLeft: row.percentLeft,
                    resetDetail: entry.resetDetail(for: row.id))
            }
        }

        let metadata = ProviderDefaults.metadata[entry.provider]
        return [
            WidgetUsageRow(
                id: "primary",
                title: metadata?.sessionLabel ?? "Session",
                percentLeft: entry.primary?.remainingPercent,
                resetDetail: entry.primary?.widgetResetDetail),
            WidgetUsageRow(
                id: "secondary",
                title: metadata?.weeklyLabel ?? "Weekly",
                percentLeft: entry.secondary?.remainingPercent,
                resetDetail: entry.secondary?.widgetResetDetail),
        ].filter { $0.percentLeft != nil }
    }
}

extension WidgetSnapshot.ProviderEntry {
    fileprivate func resetDetail(for rowID: String) -> String? {
        switch rowID.lowercased() {
        case "session", "primary", "5h":
            self.primary?.widgetResetDetail
        case "weekly", "secondary", "week":
            self.secondary?.widgetResetDetail
        case "monthly", "tertiary", "code-review", "code_review":
            self.tertiary?.widgetResetDetail
        default:
            nil
        }
    }
}

extension RateWindow {
    fileprivate var widgetResetDetail: String? {
        UsageFormatter.resetLine(for: self, style: .countdown)
    }
}

private struct HistoryView: View {
    let entry: WidgetSnapshot.ProviderEntry
    let isLarge: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                updatedAt: self.entry.updatedAt)
            UsageHistoryChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                .frame(height: self.isLarge ? 90 : 60)
        }
        .padding(12)
    }
}

private struct HeaderView: View {
    let provider: UsageProvider
    let accountDisplayName: String?
    let updatedAt: Date

    init(provider: UsageProvider, accountDisplayName: String? = nil, updatedAt: Date) {
        self.provider = provider
        self.accountDisplayName = accountDisplayName
        self.updatedAt = updatedAt
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(self.accountDisplayName ?? ProviderDefaults.metadata[self.provider]?.displayName ?? "Codex")
                .font(.body)
                .fontWeight(.semibold)
            Spacer()
            Text(WidgetFormat.relativeDate(self.updatedAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UsageBarRow: View {
    let title: String
    let percentLeft: Double?
    let resetDetail: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.title)
                    .font(.caption)
                Spacer()
                Text(WidgetFormat.percent(self.percentLeft))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let width = max(0, min(1, (percentLeft ?? 0) / 100)) * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(self.color).frame(width: width)
                }
            }
            .frame(height: 6)
            if let resetDetail {
                Text(resetDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct UsageHistoryChart: View {
    let points: [WidgetSnapshot.DailyUsagePoint]
    let color: Color

    var body: some View {
        let values = self.points.map { point -> Double in
            if let cost = point.costUSD { return cost }
            return Double(point.totalTokens ?? 0)
        }
        let maxValue = values.max() ?? 0
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(values.indices, id: \.self) { index in
                let value = values[index]
                let height = maxValue > 0 ? CGFloat(value / maxValue) : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(self.color.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: 1, y: height, anchor: .bottom)
                    .animation(.easeOut(duration: 0.2), value: height)
            }
        }
    }
}

enum WidgetColors {
    // swiftlint:disable:next cyclomatic_complexity
    static func color(for provider: UsageProvider) -> Color {
        switch provider {
        case .codex:
            Color(red: 73 / 255, green: 163 / 255, blue: 176 / 255)
        case .claude:
            Color(red: 204 / 255, green: 124 / 255, blue: 94 / 255)
        case .gemini:
            Color(red: 171 / 255, green: 135 / 255, blue: 234 / 255)
        case .antigravity:
            Color(red: 96 / 255, green: 186 / 255, blue: 126 / 255)
        case .cursor:
            Color(red: 0 / 255, green: 191 / 255, blue: 165 / 255) // #00BFA5 - Cursor teal
        case .opencode:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .opencodego:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .alibaba:
            Color(red: 1.0, green: 106 / 255, blue: 0)
        case .zai:
            Color(red: 232 / 255, green: 90 / 255, blue: 106 / 255)
        case .factory:
            Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255) // Factory orange
        case .copilot:
            Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255) // Purple
        case .minimax:
            Color(red: 254 / 255, green: 96 / 255, blue: 60 / 255)
        case .vertexai:
            Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255) // Google Blue
        case .kilo:
            Color(red: 242 / 255, green: 112 / 255, blue: 39 / 255) // Kilo orange
        case .kiro:
            Color(red: 255 / 255, green: 153 / 255, blue: 0 / 255) // AWS orange
        case .augment:
            Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255) // Augment purple
        case .jetbrains:
            Color(red: 255 / 255, green: 51 / 255, blue: 153 / 255) // JetBrains pink
        case .kimi:
            Color(red: 254 / 255, green: 96 / 255, blue: 60 / 255) // Kimi orange
        case .kimik2:
            Color(red: 76 / 255, green: 0 / 255, blue: 255 / 255) // Kimi K2 purple
        case .amp:
            Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255) // Amp red
        case .ollama:
            Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255) // Ollama charcoal
        case .synthetic:
            Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255) // Synthetic charcoal
        case .openrouter:
            Color(red: 111 / 255, green: 66 / 255, blue: 193 / 255) // OpenRouter purple
        case .warp:
            Color(red: 147 / 255, green: 139 / 255, blue: 180 / 255)
        case .perplexity:
            Color(red: 32 / 255, green: 178 / 255, blue: 170 / 255) // Perplexity teal
        case .abacus:
            Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)
        case .mistral:
            Color(red: 255 / 255, green: 80 / 255, blue: 15 / 255) // Mistral orange
        }
    }
}

enum WidgetFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    static func credits(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func costAndTokens(cost: Double?, tokens: Int?) -> String {
        let costText = cost.map(self.usd) ?? "—"
        if let tokens {
            return "\(costText) · \(self.tokenCount(tokens))"
        }
        return costText
    }

    static func usd(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    static func tokenCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let raw = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(raw) tokens"
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
