import Charts
import CodexBarCore
import SwiftUI

@MainActor
struct TokenHistoryChartMenuView: View {
    typealias DailyEntry = TokenUsageDailyReport.Entry

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let totalTokens: Int

        init(date: Date, totalTokens: Int) {
            self.date = date
            self.totalTokens = totalTokens
            self.id = "\(Int(date.timeIntervalSince1970))-\(totalTokens)"
        }
    }

    private let provider: UsageProvider
    private let daily: [DailyEntry]
    private let totalTokens: Int?
    private let width: CGFloat
    @State private var selectedDateKey: String?

    init(provider: UsageProvider, daily: [DailyEntry], totalTokens: Int?, width: CGFloat) {
        self.provider = provider
        self.daily = daily
        self.totalTokens = totalTokens
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(provider: self.provider, daily: self.daily)
        VStack(alignment: .leading, spacing: 10) {
            if model.points.isEmpty {
                Text("No token history data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(model.points) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Tokens", point.totalTokens))
                            .foregroundStyle(model.barColor)
                    }
                    if let peak = Self.peakPoint(model: model) {
                        let capStart = max(peak.totalTokens - Self.capHeight(maxValue: model.maxTokens), 0)
                        BarMark(
                            x: .value("Day", peak.date, unit: .day),
                            yStart: .value("Cap start", capStart),
                            yEnd: .value("Cap end", peak.totalTokens))
                            .foregroundStyle(Color(nsColor: .systemYellow))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: model.axisDates) { _ in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisTick().foregroundStyle(Color.clear)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 130)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                Rectangle()
                                    .fill(Self.selectionBandColor)
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .allowsHitTesting(false)
                            }
                            MouseLocationReader { location in
                                self.updateSelection(location: location, model: model, proxy: proxy, geo: geo)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                    }
                }

                let detail = self.detailLines(model: model)
                VStack(alignment: .leading, spacing: 0) {
                    Text(detail.primary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: 16, alignment: .leading)
                    Text(detail.secondary ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: 16, alignment: .leading)
                        .opacity(detail.secondary == nil ? 0 : 1)
                }
            }

            if let totalTokens {
                Text("Total (30d): \(UsageFormatter.tokenCountString(totalTokens)) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private struct Model {
        let points: [Point]
        let pointsByDateKey: [String: Point]
        let entriesByDateKey: [String: DailyEntry]
        let dateKeys: [(key: String, date: Date)]
        let axisDates: [Date]
        let barColor: Color
        let peakKey: String?
        let maxTokens: Int
    }

    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)

    private static func capHeight(maxValue: Int) -> Int {
        Int((Double(maxValue) * 0.05).rounded())
    }

    private static func makeModel(provider: UsageProvider, daily: [DailyEntry]) -> Model {
        let sorted = daily.sorted { $0.date < $1.date }
        var points: [Point] = []
        var pointsByKey: [String: Point] = [:]
        var entriesByKey: [String: DailyEntry] = [:]
        var dateKeys: [(key: String, date: Date)] = []
        var peak: (key: String, tokens: Int)?

        for entry in sorted {
            guard let totalTokens = entry.totalTokens, totalTokens >= 0,
                  let date = self.dateFromDayKey(entry.date) else { continue }
            let point = Point(date: date, totalTokens: totalTokens)
            points.append(point)
            pointsByKey[entry.date] = point
            entriesByKey[entry.date] = entry
            dateKeys.append((entry.date, date))
            if peak == nil || totalTokens > peak!.tokens { peak = (entry.date, totalTokens) }
        }

        let axisDates: [Date] = {
            guard let first = dateKeys.first?.date, let last = dateKeys.last?.date else { return [] }
            return Calendar.current.isDate(first, inSameDayAs: last) ? [first] : [first, last]
        }()
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Model(
            points: points,
            pointsByDateKey: pointsByKey,
            entriesByDateKey: entriesByKey,
            dateKeys: dateKeys,
            axisDates: axisDates,
            barColor: Color(red: color.red, green: color.green, blue: color.blue),
            peakKey: (peak?.tokens ?? 0) > 0 ? peak?.key : nil,
            maxTokens: peak?.tokens ?? 0)
    }

    private static func dateFromDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        return DateComponents(
            calendar: .current,
            timeZone: .current,
            year: year,
            month: month,
            day: day,
            hour: 12).date
    }

    private static func peakPoint(model: Model) -> Point? {
        model.peakKey.flatMap { model.pointsByDateKey[$0] }
    }

    private func selectionBandRect(model: Model, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let key = self.selectedDateKey,
              let plotAnchor = proxy.plotFrame,
              let index = model.dateKeys.firstIndex(where: { $0.key == key }),
              let x = proxy.position(forX: model.dateKeys[index].date)
        else { return nil }
        let plotFrame = geo[plotAnchor]
        let previous = index > 0 ? proxy.position(forX: model.dateKeys[index - 1].date) : nil
        let next = index + 1 < model.dateKeys.count ? proxy.position(forX: model.dateKeys[index + 1].date) : nil
        let left = previous.map { ($0 + x) / 2 } ?? next.map { x - ($0 - x) / 2 } ?? x - 8
        let right = next.map { ($0 + x) / 2 } ?? previous.map { x + (x - $0) / 2 } ?? x + 8
        return CGRect(
            x: plotFrame.origin.x + min(left, right),
            y: plotFrame.origin.y,
            width: abs(right - left),
            height: plotFrame.height)
    }

    private func updateSelection(location: CGPoint?, model: Model, proxy: ChartProxy, geo: GeometryProxy) {
        guard let location else { self.selectedDateKey = nil; return }
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location),
              let date: Date = proxy.value(atX: location.x - plotFrame.origin.x) else { return }
        self.selectedDateKey = model.dateKeys.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }?.key
    }

    private func detailLines(model: Model) -> (primary: String, secondary: String?) {
        guard let key = self.selectedDateKey,
              let point = model.pointsByDateKey[key],
              let date = Self.dateFromDayKey(key)
        else { return ("Hover a bar for details", nil) }
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return (
            "\(day): \(UsageFormatter.tokenCountString(point.totalTokens)) tokens",
            self.topModelsText(key: key, model: model))
    }

    private func topModelsText(key: String, model: Model) -> String? {
        guard let breakdown = model.entriesByDateKey[key]?.modelBreakdowns, !breakdown.isEmpty else { return nil }
        let parts = breakdown.compactMap { item -> String? in
            guard let tokens = item.totalTokens else { return nil }
            return "\(UsageFormatter.modelDisplayName(item.modelName)) \(UsageFormatter.tokenCountString(tokens))"
        }.prefix(3)
        return parts.isEmpty ? nil : "Top: \(parts.joined(separator: " · "))"
    }
}
