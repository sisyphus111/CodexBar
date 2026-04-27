import SwiftUI
import WidgetKit

struct WidgetSnapshot: Decodable {
    struct Entry: Decodable, Identifiable {
        struct RateWindow: Decodable {
            let label: String?
            let usedPercent: Double?
            let remainingPercent: Double?
            let windowMinutes: Int?
            let resetsAt: Date?
            let resetDescription: String?
            let resetText: String?

            var percentLeft: Double? {
                if let remainingPercent {
                    return remainingPercent
                }
                return self.usedPercent.map { max(0, 100 - $0) }
            }

            func resetDetail(now: Date) -> String? {
                if let resetsAt {
                    return WidgetFormatting.resetLine(until: resetsAt, now: now)
                }
                let explicit = (self.resetDescription ?? self.resetText ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !explicit.isEmpty {
                    return WidgetFormatting.resetLine(from: explicit)
                }
                return nil
            }
        }

        struct TokenUsage: Decodable {
            let sessionCostUSD: Double?
            let sessionTokens: Int?
            let last30DaysCostUSD: Double?
            let last30DaysTokens: Int?
        }

        struct UsageRow: Decodable, Identifiable {
            let id: String
            let title: String
            let percentLeft: Double?
        }

        struct DailyUsagePoint: Decodable, Identifiable {
            let dayKey: String
            let totalTokens: Int?
            let costUSD: Double?

            var id: String { self.dayKey }
        }

        let provider: String
        let accountID: String?
        let accountDisplayName: String?
        let planDisplayName: String?
        let updatedAt: Date
        let primary: RateWindow?
        let secondary: RateWindow?
        let tertiary: RateWindow?
        let usageRows: [UsageRow]?
        let creditsRemaining: Double?
        let codeReviewRemainingPercent: Double?
        let tokenUsage: TokenUsage?
        let dailyUsage: [DailyUsagePoint]?
        let error: String?

        var id: String { self.accountID ?? self.provider }

        var displayName: String {
            let trimmed = (self.accountDisplayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return self.accountID ?? "Codex account" }
            return trimmed
        }

        var planText: String {
            let trimmed = (self.planDisplayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Plan pending" : trimmed
        }

        var visibleUsageRows: [UsageRow] {
            if let usageRows, !usageRows.isEmpty {
                return usageRows.filter { $0.percentLeft != nil }
            }
            return [
                UsageRow(id: "primary", title: "Session", percentLeft: self.primary?.percentLeft),
                UsageRow(id: "secondary", title: "Weekly", percentLeft: self.secondary?.percentLeft),
                UsageRow(id: "tertiary", title: "Monthly", percentLeft: self.tertiary?.percentLeft),
            ].filter { $0.percentLeft != nil }
        }

        func resetDetail(for row: UsageRow, now: Date) -> String? {
            self.window(for: row.id)?.resetDetail(now: now)
        }

        func quotaFacts(for row: UsageRow) -> [String] {
            [
                self.usedDetail(for: row),
            ].compactMap(\.self)
        }

        private func usedDetail(for row: UsageRow) -> String? {
            let used = self.window(for: row.id)?.usedPercent ?? row.percentLeft.map { max(0, 100 - $0) }
            guard let used else { return nil }
            return "Used \(WidgetFormatting.percent(used))"
        }

        private func window(for rowID: String) -> RateWindow? {
            switch rowID.lowercased() {
            case "session", "primary", "5h":
                self.primary
            case "weekly", "secondary", "week":
                self.secondary
            case "monthly", "tertiary", "code-review", "code_review":
                self.tertiary
            default:
                nil
            }
        }
    }

    let entries: [Entry]
    let generatedAt: Date
}

private enum WidgetDataStore {
    static func loadSnapshot() -> WidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snapshot = self.groupSnapshotURLs
            .compactMap({ url -> WidgetSnapshot? in
                guard let data = try? Data(contentsOf: url),
                      let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
                else {
                    return nil
                }
                return snapshot
            })
            .sorted(by: { $0.generatedAt > $1.generatedAt })
            .first
        {
            return snapshot
        }

        return self.fallbackSnapshotURLs
            .compactMap { url -> WidgetSnapshot? in
                guard let data = try? Data(contentsOf: url),
                      let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
                else {
                    return nil
                }
                return snapshot
            }
            .sorted(by: { $0.generatedAt > $1.generatedAt })
            .first
    }

    private static var groupSnapshotURLs: [URL] {
        let groupTeams = self.uniqueTeams([
            self.teamID,
            "JR6532PK35",
            "TNQ7CUG4AK",
            "Y5PE65HELJ",
        ].filter { !$0.isEmpty })

        let home = FileManager.default.homeDirectoryForCurrentUser
        return groupTeams.flatMap { team -> [URL] in
            let groupID = "\(team).com.steipete.codexbar"
            var urls: [URL] = []
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
                urls.append(containerURL.appendingPathComponent("widget-snapshot.json", isDirectory: false))
            }
            urls.append(
                home
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Group Containers", isDirectory: true)
                    .appendingPathComponent(groupID, isDirectory: true)
                    .appendingPathComponent("widget-snapshot.json", isDirectory: false))
            return urls
        }
    }

    private static var fallbackSnapshotURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var urls: [URL] = []
        if let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(
                applicationSupport
                    .appendingPathComponent("CodexBar", isDirectory: true)
                    .appendingPathComponent("widget-snapshot.json", isDirectory: false))
        }
        urls.append(
            home
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Containers", isDirectory: true)
                .appendingPathComponent("com.steipete.codexbar.widget", isDirectory: true)
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("CodexBar", isDirectory: true)
                .appendingPathComponent("widget-snapshot.json", isDirectory: false))
        return urls
    }

    private static var teamID: String {
        Bundle.main.object(forInfoDictionaryKey: "CodexBarTeamID") as? String ?? ""
    }

    private static func uniqueTeams(_ teams: [String]) -> [String] {
        var seen = Set<String>()
        return teams.filter { seen.insert($0).inserted }
    }
}

struct CodexBarWidgetEntry: TimelineEntry {
    let date: Date
    let account: WidgetSnapshot.Entry?
}

struct CodexBarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexBarWidgetEntry {
        CodexBarWidgetEntry(date: Date(), account: Self.previewAccount)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexBarWidgetEntry) -> Void) {
        completion(self.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexBarWidgetEntry>) -> Void) {
        completion(Timeline(entries: [self.entry()], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func entry() -> CodexBarWidgetEntry {
        let account = (WidgetDataStore.loadSnapshot()?.entries ?? [])
            .filter { $0.provider == "codex" }
            .first
        return CodexBarWidgetEntry(date: Date(), account: account)
    }

    private static let previewAccount = WidgetSnapshot.Entry(
        provider: "codex",
        accountID: "preview",
        accountDisplayName: "preview@example.com",
        planDisplayName: "Pro",
        updatedAt: Date(),
        primary: .init(
            label: "5h",
            usedPercent: 42,
            remainingPercent: 58,
            windowMinutes: 300,
            resetsAt: Date().addingTimeInterval(3 * 60 * 60),
            resetDescription: nil,
            resetText: nil),
        secondary: .init(
            label: "Weekly",
            usedPercent: 22,
            remainingPercent: 78,
            windowMinutes: 10080,
            resetsAt: Date().addingTimeInterval(2 * 24 * 60 * 60),
            resetDescription: nil,
            resetText: nil),
        tertiary: nil,
        usageRows: [
            .init(id: "session", title: "5h", percentLeft: 58),
            .init(id: "weekly", title: "Weekly", percentLeft: 78),
        ],
        creditsRemaining: 24.5,
        codeReviewRemainingPercent: 83,
        tokenUsage: .init(
            sessionCostUSD: 0.42,
            sessionTokens: 128_000,
            last30DaysCostUSD: 12.30,
            last30DaysTokens: 2_430_000),
        dailyUsage: [
            .init(dayKey: "2026-05-03", totalTokens: 95_000, costUSD: 0.31),
            .init(dayKey: "2026-05-04", totalTokens: 142_000, costUSD: 0.49),
            .init(dayKey: "2026-05-05", totalTokens: 118_000, costUSD: 0.38),
            .init(dayKey: "2026-05-06", totalTokens: 210_000, costUSD: 0.72),
            .init(dayKey: "2026-05-07", totalTokens: 86_000, costUSD: 0.25),
            .init(dayKey: "2026-05-08", totalTokens: 164_000, costUSD: 0.56),
            .init(dayKey: "2026-05-09", totalTokens: 128_000, costUSD: 0.42),
        ],
        error: nil)
}

@main
struct CodexBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexBarAccountsWidget()
    }
}

struct CodexBarAccountsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexBarAccountsWidget", provider: CodexBarWidgetProvider()) { entry in
            CodexBarWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Dashboard")
        .description("Detailed usage for your Codex account.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CodexBarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarWidgetEntry

    var body: some View {
        self.content
            .padding(self.family == .systemSmall ? 10 : 14)
            .widgetAccentable(false)
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(WidgetPalette.background)
                    .overlay {
                        ContainerRelativeShape()
                            .strokeBorder(WidgetPalette.border, lineWidth: 1)
                    }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let account = self.entry.account {
            SingleAccountDashboardView(account: account, family: self.family)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Codex")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.text)
                Text("Open CodexBar to refresh usage.")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private enum WidgetPalette {
    static let background = Color(red: 38 / 255, green: 56 / 255, blue: 74 / 255).opacity(0.82)
    static let border = Color.white.opacity(0.28)
    static let text = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.62)
    static let mutedText = Color.white.opacity(0.44)
    static let track = Color(red: 110 / 255, green: 126 / 255, blue: 141 / 255).opacity(0.42)
    static let divider = Color.white.opacity(0.12)
    static let green = Color(red: 47 / 255, green: 216 / 255, blue: 103 / 255).opacity(0.96)
    static let amber = Color(red: 236 / 255, green: 177 / 255, blue: 74 / 255).opacity(0.94)
    static let red = Color(red: 235 / 255, green: 102 / 255, blue: 102 / 255).opacity(0.94)

    static func statusColor(percentLeft: Double?) -> Color {
        let percent = percentLeft ?? 100
        if percent <= 20 { return Self.red }
        if percent <= 45 { return Self.amber }
        return Self.green
    }
}

private struct SingleAccountDashboardView: View {
    let account: WidgetSnapshot.Entry
    let family: WidgetFamily

    var body: some View {
        switch self.family {
        case .systemSmall:
            self.small
        case .systemMedium:
            self.medium
        default:
            self.large
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(account: self.account, compact: true)
            ForEach(self.quotaRows) { row in
                CompactQuotaRow(account: self.account, row: row)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(account: self.account, compact: false)
            HStack(alignment: .top, spacing: 14) {
                ForEach(self.quotaRows) { row in
                    QuotaPanel(account: self.account, row: row)
                    if row.id != self.quotaRows.last?.id {
                        Rectangle()
                            .fill(WidgetPalette.divider)
                            .frame(width: 1)
                    }
                }
            }
            if let codeReview = self.account.codeReviewRemainingPercent {
                SupplementalProgressRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetPalette.statusColor(percentLeft: codeReview))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(account: self.account, compact: false)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(self.quotaRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(WidgetPalette.divider)
                            .frame(height: 1)
                            .padding(.vertical, 10)
                    }
                    QuotaBand(account: self.account, row: row)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            if let codeReview = self.account.codeReviewRemainingPercent {
                SupplementalProgressRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetPalette.statusColor(percentLeft: codeReview))
            }
            if let error = self.statusDetail {
                StatusNotice(text: error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var quotaRows: [WidgetSnapshot.Entry.UsageRow] {
        var rows: [WidgetSnapshot.Entry.UsageRow] = []
        if let session = self.row(matching: ["session", "primary", "5h"], titles: ["session", "5h"]) {
            rows.append(session)
        }
        if let weekly = self.row(matching: ["weekly", "secondary", "week"], titles: ["weekly", "week"]),
           !rows.contains(where: { $0.id == weekly.id })
        {
            rows.append(weekly)
        }
        if rows.isEmpty {
            rows = Array(self.account.visibleUsageRows.prefix(2))
        }
        return rows
    }

    private func row(matching ids: Set<String>, titles: [String]) -> WidgetSnapshot.Entry.UsageRow? {
        self.account.visibleUsageRows.first { row in
            let id = row.id.lowercased()
            let title = row.title.lowercased()
            return ids.contains(id) || titles.contains(where: { title.contains($0) })
        }
    }

    private var statusDetail: String? {
        let trimmed = (self.account.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct WidgetHeader: View {
    let account: WidgetSnapshot.Entry
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Codex")
                        .font(self.compact ? .headline.weight(.semibold) : .title2.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                    if !self.compact {
                        Text(self.account.planText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetPalette.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                Text(self.account.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(self.compact ? self.account.planText : WidgetFormatting.relativeDate(self.account.updatedAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(self.compact ? WidgetPalette.green : WidgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
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

private struct CompactQuotaRow: View {
    let account: WidgetSnapshot.Entry
    let row: WidgetSnapshot.Entry.UsageRow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(self.row.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(WidgetFormatting.percent(self.row.percentLeft))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(WidgetPalette.text)
            }
            ProgressBar(percentLeft: self.row.percentLeft, color: self.color)
                .frame(height: 6)
            ResetCountdownText(account: self.account, row: self.row, compact: true)
        }
    }

    private var color: Color {
        WidgetPalette.statusColor(percentLeft: self.row.percentLeft)
    }
}

private struct QuotaPanel: View {
    let account: WidgetSnapshot.Entry
    let row: WidgetSnapshot.Entry.UsageRow

    var body: some View {
        let color = WidgetPalette.statusColor(percentLeft: self.row.percentLeft)
        HStack(alignment: .center, spacing: 10) {
            RingProgressView(percentLeft: self.row.percentLeft, color: color, size: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(self.row.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text(WidgetFormatting.percent(self.row.percentLeft))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(WidgetPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ProgressBar(percentLeft: self.row.percentLeft, color: color)
                    .frame(height: 7)
                QuotaFactsRow(facts: self.account.quotaFacts(for: self.row), compact: true)
                ResetCountdownText(account: self.account, row: self.row, compact: false)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuotaBand: View {
    let account: WidgetSnapshot.Entry
    let row: WidgetSnapshot.Entry.UsageRow

    var body: some View {
        let color = WidgetPalette.statusColor(percentLeft: self.row.percentLeft)
        HStack(alignment: .center, spacing: 14) {
            RingProgressView(percentLeft: self.row.percentLeft, color: color, size: 48)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(self.row.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text(WidgetFormatting.percent(self.row.percentLeft))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                ProgressBar(percentLeft: self.row.percentLeft, color: color)
                    .frame(height: 8)
                QuotaFactsRow(facts: self.account.quotaFacts(for: self.row), compact: false)
                ResetCountdownText(account: self.account, row: self.row, compact: false)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct QuotaFactsRow: View {
    let facts: [String]
    let compact: Bool

    var body: some View {
        if !self.facts.isEmpty {
            HStack(spacing: self.compact ? 5 : 6) {
                ForEach(self.facts.prefix(self.compact ? 2 : 3), id: \.self) { fact in
                    Text(fact)
                        .font(.caption2.weight(self.compact ? .regular : .medium))
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
    }
}

private struct ResetCountdownText: View {
    let account: WidgetSnapshot.Entry
    let row: WidgetSnapshot.Entry.UsageRow
    let compact: Bool

    var body: some View {
        if let reset = self.account.resetDetail(for: self.row, now: Date()) {
            Text(reset)
                .font(.caption2.weight(self.compact ? .regular : .semibold))
                .monospacedDigit()
                .foregroundStyle(self.compact ? WidgetPalette.mutedText : WidgetPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct SupplementalProgressRow: View {
    let title: String
    let percentLeft: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetPalette.secondaryText)
                Spacer()
                Text(WidgetFormatting.percent(self.percentLeft))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(WidgetPalette.text)
            }
            ProgressBar(percentLeft: self.percentLeft, color: self.color)
                .frame(height: 7)
        }
    }
}

private struct ProgressBar: View {
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
        }
        .frame(width: self.size, height: self.size)
    }

    private var lineWidth: CGFloat {
        self.size <= 44 ? 4 : 5
    }
}

private struct StatusNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetPalette.amber)
            Text(self.text)
                .font(.caption2)
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WidgetPalette.amber.opacity(0.32))
                .frame(height: 1)
        }
    }
}

private enum WidgetFormatting {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(Int(value.rounded()))%"
    }

    static func resetLine(until date: Date, now: Date = .init()) -> String {
        "Resets \(Self.resetCountdownDescription(from: date, now: now))"
    }

    static func resetLine(from description: String) -> String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("resets") { return trimmed }
        return "Resets \(trimmed)"
    }

    static func resetCountdownDescription(from date: Date, now: Date = .init()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        if seconds < 1 { return "now" }

        let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            if hours > 0 { return "in \(days)d \(hours)h" }
            return "in \(days)d"
        }
        if hours > 0 {
            if minutes > 0 { return "in \(hours)h \(minutes)m" }
            return "in \(hours)h"
        }
        return "in \(totalMinutes)m"
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
