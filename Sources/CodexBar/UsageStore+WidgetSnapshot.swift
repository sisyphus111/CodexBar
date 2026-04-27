import CodexBarCore
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

extension UsageStore {
    func persistWidgetSnapshot(reason: String) {
        let snapshot = self.makeWidgetSnapshot()
        let previousTask = self.widgetSnapshotPersistTask
        self.widgetSnapshotPersistTask = Task { @MainActor in
            _ = await previousTask?.result

            if let override = self._test_widgetSnapshotSaveOverride {
                await override(snapshot)
                return
            }

            await Task.detached(priority: .utility) {
                WidgetSnapshotStore.save(snapshot)
            }.value
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private func makeWidgetSnapshot() -> WidgetSnapshot {
        let enabledProviders = self.enabledProviders()
        let accountEntries = self.makeCodexAccountWidgetEntries()
        let entries = accountEntries.isEmpty
            ? UsageProvider.monitoredProviders.compactMap { provider in self.makeWidgetEntry(for: provider) }
            : accountEntries
        return WidgetSnapshot(entries: entries, enabledProviders: enabledProviders, generatedAt: Date())
    }

    private func makeCodexAccountWidgetEntries() -> [WidgetSnapshot.ProviderEntry] {
        let projection = self.settings.codexVisibleAccountProjection
        guard let account = projection.visibleAccounts.first(where: { $0.id == projection.activeVisibleAccountID })
            ?? projection.visibleAccounts.first
        else { return [] }
        let previousEntriesByAccountID = self.previousCodexWidgetEntriesByAccountID()
        if let accountSnapshot = self.codexAccountUsageSnapshots[account.id] {
            return [
                self.makeWidgetEntryOrPlaceholder(
                    for: .codex,
                    snapshot: accountSnapshot.usage,
                    accountID: accountSnapshot.id,
                    accountDisplayName: accountSnapshot.displayName,
                    credits: accountSnapshot.credits,
                    previousEntry: previousEntriesByAccountID[account.id],
                    error: accountSnapshot.error),
            ]
        }
        let snapshot = account.id == projection.activeVisibleAccountID ? self.snapshots[.codex] : nil
        let credits = account.id == projection.activeVisibleAccountID ? self.credits : nil
        let error = account.id == projection.activeVisibleAccountID ? self.errors[.codex] : nil
        return [
            self.makeWidgetEntryOrPlaceholder(
                for: .codex,
                snapshot: snapshot,
                accountID: account.id,
                accountDisplayName: account.menuDisplayName,
                credits: credits,
                previousEntry: previousEntriesByAccountID[account.id],
                error: error),
        ]
    }

    private func makeWidgetEntry(for provider: UsageProvider) -> WidgetSnapshot.ProviderEntry? {
        self.makeWidgetEntry(
            for: provider,
            snapshot: self.snapshots[provider],
            accountID: nil,
            accountDisplayName: nil,
            credits: provider == .codex ? self.credits : nil)
    }

    private func makeWidgetEntry(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        accountID: String?,
        accountDisplayName: String?,
        credits accountCredits: CreditsSnapshot?)
        -> WidgetSnapshot.ProviderEntry?
    {
        guard let snapshot else { return nil }

        let tokenSnapshot = self.tokenSnapshots[provider]
        let dailyUsage = tokenSnapshot?.daily.map { entry in
            WidgetSnapshot.DailyUsagePoint(
                dayKey: entry.date,
                totalTokens: entry.totalTokens,
                costUSD: entry.costUSD)
        } ?? []

        let tokenUsage = Self.widgetTokenUsageSummary(from: tokenSnapshot)
        let usageRows = self.widgetUsageRows(provider: provider, snapshot: snapshot)

        let creditsRemaining: Double?
        let codeReviewRemaining: Double?
        if provider == .codex {
            let projection = self.codexConsumerProjection(
                surface: .widget,
                snapshotOverride: snapshot,
                now: snapshot.updatedAt)
            let displayOnlyExtrasHidden = projection.dashboardVisibility == .displayOnly
            creditsRemaining = displayOnlyExtrasHidden
                ? nil
                : accountCredits?.remaining ?? projection.credits?.remaining
            codeReviewRemaining = displayOnlyExtrasHidden ? nil : projection.remainingPercent(for: .codeReview)
        } else {
            creditsRemaining = nil
            codeReviewRemaining = nil
        }

        return WidgetSnapshot.ProviderEntry(
            provider: provider,
            accountID: accountID,
            accountDisplayName: accountDisplayName,
            planDisplayName: self.widgetPlanDisplayName(provider: provider, snapshot: snapshot),
            updatedAt: snapshot.updatedAt,
            primary: snapshot.primary,
            secondary: snapshot.secondary,
            tertiary: snapshot.tertiary,
            usageRows: usageRows,
            creditsRemaining: creditsRemaining,
            codeReviewRemainingPercent: codeReviewRemaining,
            tokenUsage: tokenUsage,
            dailyUsage: dailyUsage,
            error: self.errors[provider])
    }

    private func makeWidgetEntryOrPlaceholder(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        accountID: String,
        accountDisplayName: String,
        credits accountCredits: CreditsSnapshot?,
        previousEntry: WidgetSnapshot.ProviderEntry? = nil,
        error: String?)
        -> WidgetSnapshot.ProviderEntry
    {
        if let entry = self.makeWidgetEntry(
            for: provider,
            snapshot: snapshot,
            accountID: accountID,
            accountDisplayName: accountDisplayName,
            credits: accountCredits)
        {
            guard entry.error != error else { return entry }
            return WidgetSnapshot.ProviderEntry(
                provider: entry.provider,
                accountID: entry.accountID,
                accountDisplayName: entry.accountDisplayName,
                planDisplayName: entry.planDisplayName,
                updatedAt: entry.updatedAt,
                primary: entry.primary,
                secondary: entry.secondary,
                tertiary: entry.tertiary,
                usageRows: entry.usageRows,
                creditsRemaining: entry.creditsRemaining,
                codeReviewRemainingPercent: entry.codeReviewRemainingPercent,
                tokenUsage: entry.tokenUsage,
                dailyUsage: entry.dailyUsage,
                error: error)
        }

        if let previousEntry, Self.widgetEntryHasUsage(previousEntry) {
            return WidgetSnapshot.ProviderEntry(
                provider: provider,
                accountID: accountID,
                accountDisplayName: accountDisplayName,
                planDisplayName: previousEntry.planDisplayName,
                updatedAt: previousEntry.updatedAt,
                primary: previousEntry.primary,
                secondary: previousEntry.secondary,
                tertiary: previousEntry.tertiary,
                usageRows: previousEntry.usageRows,
                creditsRemaining: accountCredits?.remaining ?? previousEntry.creditsRemaining,
                codeReviewRemainingPercent: previousEntry.codeReviewRemainingPercent,
                tokenUsage: previousEntry.tokenUsage,
                dailyUsage: previousEntry.dailyUsage,
                error: error ?? previousEntry.error)
        }

        return WidgetSnapshot.ProviderEntry(
            provider: provider,
            accountID: accountID,
            accountDisplayName: accountDisplayName,
            planDisplayName: nil,
            updatedAt: Date(),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            usageRows: [],
            creditsRemaining: accountCredits?.remaining,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [],
            error: error)
    }

    private func previousCodexWidgetEntriesByAccountID() -> [String: WidgetSnapshot.ProviderEntry] {
        guard self._test_widgetSnapshotSaveOverride == nil else { return [:] }
        guard let snapshot = WidgetSnapshotStore.load() else { return [:] }
        return snapshot.entries.reduce(into: [:]) { result, entry in
            guard entry.provider == .codex,
                  let accountID = entry.accountID,
                  result[accountID] == nil
            else {
                return
            }
            result[accountID] = entry
        }
    }

    private nonisolated static func widgetEntryHasUsage(_ entry: WidgetSnapshot.ProviderEntry) -> Bool {
        if entry.primary != nil || entry.secondary != nil || entry.tertiary != nil {
            return true
        }
        return entry.usageRows?.contains { $0.percentLeft != nil } == true
    }

    private func widgetPlanDisplayName(provider: UsageProvider, snapshot: UsageSnapshot?) -> String? {
        guard let raw = snapshot?.loginMethod(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }

        if provider == .codex {
            return CodexPlanFormatting.displayName(raw) ?? UsageFormatter.cleanPlanName(raw)
        }
        return UsageFormatter.cleanPlanName(raw)
    }

    private nonisolated static func widgetTokenUsageSummary(
        from snapshot: CostUsageTokenSnapshot?) -> WidgetSnapshot.TokenUsageSummary?
    {
        guard let snapshot else { return nil }
        let fallbackTokens = snapshot.daily.compactMap(\.totalTokens).reduce(0, +)
        let monthTokensValue = snapshot.last30DaysTokens ?? (fallbackTokens > 0 ? fallbackTokens : nil)
        return WidgetSnapshot.TokenUsageSummary(
            sessionCostUSD: snapshot.sessionCostUSD,
            sessionTokens: snapshot.sessionTokens,
            last30DaysCostUSD: snapshot.last30DaysCostUSD,
            last30DaysTokens: monthTokensValue)
    }

    private func widgetUsageRows(
        provider: UsageProvider,
        snapshot: UsageSnapshot) -> [WidgetSnapshot.WidgetUsageRowSnapshot]
    {
        let metadata = ProviderDefaults.metadata[provider]
        if provider == .codex {
            let projection = self.codexConsumerProjection(
                surface: .widget,
                snapshotOverride: snapshot,
                now: snapshot.updatedAt)
            return projection.visibleRateLanes.compactMap { lane in
                guard let window = projection.rateWindow(for: lane) else { return nil }
                let title = switch lane {
                case .session:
                    metadata?.sessionLabel ?? "Session"
                case .weekly:
                    metadata?.weeklyLabel ?? "Weekly"
                }
                return WidgetSnapshot.WidgetUsageRowSnapshot(
                    id: lane.rawValue,
                    title: title,
                    percentLeft: window.remainingPercent)
            }
        }

        let rows: [WidgetSnapshot.WidgetUsageRowSnapshot] = [
            WidgetSnapshot.WidgetUsageRowSnapshot(
                id: "primary",
                title: metadata?.sessionLabel ?? "Session",
                percentLeft: snapshot.primary?.remainingPercent),
            WidgetSnapshot.WidgetUsageRowSnapshot(
                id: "secondary",
                title: metadata?.weeklyLabel ?? "Weekly",
                percentLeft: snapshot.secondary?.remainingPercent),
        ]
        return rows.filter { $0.percentLeft != nil }
    }
}
