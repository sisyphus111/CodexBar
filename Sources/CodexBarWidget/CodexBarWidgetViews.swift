import CodexBarCore
import SwiftUI
import WidgetKit

struct CodexBarUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
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
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetPalette.background(for: self.renderingMode))
                .overlay {
                    ContainerRelativeShape()
                        .strokeBorder(WidgetPalette.border, lineWidth: 1)
                }
        }
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
                .foregroundStyle(WidgetPalette.text)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .foregroundStyle(WidgetPalette.secondaryText)
        }
        .padding(12)
    }
}

struct CodexBarHistoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
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
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetPalette.background(for: self.renderingMode))
                .overlay {
                    ContainerRelativeShape()
                        .strokeBorder(WidgetPalette.border, lineWidth: 1)
                }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open CodexBar")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetPalette.text)
            Text("Usage history will appear after a refresh.")
                .font(.caption)
                .foregroundStyle(WidgetPalette.secondaryText)
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
        VStack(alignment: .leading, spacing: 7) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                planDisplayName: self.entry.planDisplayName,
                updatedAt: self.entry.updatedAt,
                compact: true)
            ForEach(WidgetUsageRow.rows(for: self.entry).prefix(2)) { row in
                UsageBarRow(
                    title: row.title,
                    percentLeft: row.percentLeft,
                    resetDetail: row.resetDetail,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(10)
    }
}

private struct MediumUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                planDisplayName: self.entry.planDisplayName,
                updatedAt: self.entry.updatedAt)
            HStack(alignment: .center, spacing: 12) {
                ForEach(Array(WidgetUsageRow.rows(for: self.entry).prefix(2).enumerated()), id: \.element.id) { item in
                    let (index, row) = item
                    if index > 0 {
                        Rectangle()
                            .fill(WidgetPalette.divider)
                            .frame(width: 1)
                    }
                    QuotaPanel(row: row, color: WidgetColors.color(for: self.entry.provider))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
    }
}

private struct LargeUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(
                provider: self.entry.provider,
                accountDisplayName: self.entry.accountDisplayName,
                planDisplayName: self.entry.planDisplayName,
                updatedAt: self.entry.updatedAt)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(WidgetUsageRow.rows(for: self.entry).prefix(2).enumerated()), id: \.element.id) { item in
                    let (index, row) = item
                    if index > 0 {
                        Rectangle()
                            .fill(WidgetPalette.divider)
                            .frame(height: 1)
                            .padding(.vertical, 10)
                    }
                    QuotaBand(row: row, color: WidgetColors.color(for: self.entry.provider))
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            if let codeReview = self.entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    resetDetail: nil,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
        .padding(14)
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
                planDisplayName: self.entry.planDisplayName,
                updatedAt: self.entry.updatedAt)
            UsageHistoryChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                .frame(height: self.isLarge ? 90 : 60)
        }
        .padding(14)
    }
}

private struct HeaderView: View {
    let provider: UsageProvider
    let accountDisplayName: String?
    let planDisplayName: String?
    let updatedAt: Date
    let compact: Bool

    init(
        provider: UsageProvider,
        accountDisplayName: String? = nil,
        planDisplayName: String? = nil,
        updatedAt: Date,
        compact: Bool = false)
    {
        self.provider = provider
        self.accountDisplayName = accountDisplayName
        self.planDisplayName = planDisplayName
        self.updatedAt = updatedAt
        self.compact = compact
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ProviderDefaults.metadata[self.provider]?.displayName ?? "Codex")
                        .font(self.compact ? .headline.weight(.semibold) : .title2.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                    if let planDisplayName, !planDisplayName.isEmpty {
                        Text(planDisplayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetPalette.green)
                            .lineLimit(1)
                    }
                }
                if let accountDisplayName, !accountDisplayName.isEmpty {
                    Text(accountDisplayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength: 6)
            Text(WidgetFormat.relativeDate(self.updatedAt))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WidgetPalette.divider)
                .frame(height: 1)
                .offset(y: self.compact ? 6 : 7)
        }
        .padding(.bottom, self.compact ? 6 : 7)
    }
}

private struct UsageBarRow: View {
    let title: String
    let percentLeft: Double?
    let resetDetail: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.text)
                Spacer()
                Text(WidgetFormat.percent(self.percentLeft))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(WidgetPalette.text)
            }
            WidgetProgressBar(percentLeft: self.percentLeft, color: self.color)
                .frame(height: 6)
            if let resetDetail {
                Text(resetDetail)
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct QuotaPanel: View {
    let row: WidgetUsageRow
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RingProgressView(percentLeft: self.row.percentLeft, color: self.color, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(self.row.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(WidgetFormat.percent(self.row.percentLeft))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(WidgetPalette.text)
                }
                WidgetProgressBar(percentLeft: self.row.percentLeft, color: self.color)
                    .frame(height: 7)
                QuotaDetailView(row: self.row, compact: true)
            }
            .layoutPriority(1)
        }
    }
}

private struct QuotaBand: View {
    let row: WidgetUsageRow
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RingProgressView(percentLeft: self.row.percentLeft, color: self.color, size: 52)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(self.row.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                    Spacer(minLength: 8)
                    Text(WidgetFormat.percent(self.row.percentLeft))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.text)
                        .minimumScaleFactor(0.75)
                }
                WidgetProgressBar(percentLeft: self.row.percentLeft, color: self.color)
                    .frame(height: 8)
                QuotaDetailView(row: self.row, compact: false)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct QuotaDetailView: View {
    let row: WidgetUsageRow
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: self.compact ? 2 : 5) {
            if let percentLeft = self.row.percentLeft {
                Text("Used \(Int(max(0, min(100, 100 - percentLeft)).rounded()))%")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetPalette.secondaryText)
            }
            if let resetDetail = self.row.resetDetail {
                Text(resetDetail)
                    .font(.caption2.weight(self.compact ? .regular : .semibold))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

private struct WidgetProgressBar: View {
    let percentLeft: Double?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = max(0, min(1, (self.percentLeft ?? 0) / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.track)
                Capsule()
                    .fill(self.color)
                    .frame(width: proxy.size.width * fraction)
                    .widgetAccentable()
            }
        }
    }
}

private struct RingProgressView: View {
    let percentLeft: Double?
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.track, lineWidth: self.lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, (self.percentLeft ?? 0) / 100)))
                .stroke(
                    self.color,
                    style: StrokeStyle(lineWidth: self.lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .frame(width: self.size, height: self.size)
    }

    private var lineWidth: CGFloat {
        self.size <= 44 ? 5 : 6
    }
}

private struct UsageHistoryChart: View {
    let points: [WidgetSnapshot.DailyUsagePoint]
    let color: Color

    var body: some View {
        let values = self.points.map { Double($0.totalTokens ?? 0) }
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
                    .widgetAccentable()
            }
        }
    }
}

private enum WidgetPalette {
    static let border = Color.white.opacity(0.28)
    static let text = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let track = Color(red: 106 / 255, green: 123 / 255, blue: 139 / 255).opacity(0.40)
    static let divider = Color.white.opacity(0.12)
    static let green = Color(red: 45 / 255, green: 215 / 255, blue: 96 / 255)

    static func background(for renderingMode: WidgetRenderingMode) -> Color {
        let opacity = renderingMode == .fullColor ? 0.82 : 0.74
        return Color(red: 38 / 255, green: 56 / 255, blue: 74 / 255).opacity(opacity)
    }
}

enum WidgetColors {
    // swiftlint:disable:next cyclomatic_complexity
    static func color(for provider: UsageProvider) -> Color {
        switch provider {
        case .codex:
            WidgetPalette.green
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
