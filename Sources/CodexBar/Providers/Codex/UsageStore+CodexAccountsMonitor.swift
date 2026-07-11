import CodexBarCore
import Foundation

struct CodexAccountUsageSnapshot {
    let id: String
    let displayName: String
    let source: CodexActiveSource
    let usage: UsageSnapshot?
    let credits: CreditsSnapshot?
    let sourceLabel: String?
    let error: String?
    let updatedAt: Date
}

@MainActor
extension UsageStore {
    func refreshAllCodexAccountsForMonitoring() async {
        guard self.isEnabled(.codex) else {
            self.codexAccountUsageSnapshots = [:]
            return
        }

        let projection = self.settings.codexVisibleAccountProjection
        guard !projection.visibleAccounts.isEmpty else {
            self.codexAccountUsageSnapshots = [:]
            return
        }

        var refreshed: [String: CodexAccountUsageSnapshot] = [:]
        refreshed.reserveCapacity(projection.visibleAccounts.count)
        for account in projection.visibleAccounts {
            refreshed[account.id] = self.codexAccountUsageSnapshots[account.id] ?? CodexAccountUsageSnapshot(
                id: account.id,
                displayName: account.menuDisplayName,
                source: account.selectionSource,
                usage: nil,
                credits: nil,
                sourceLabel: nil,
                error: nil,
                updatedAt: Date())
        }
        self.codexAccountUsageSnapshots = refreshed
        self.persistWidgetSnapshot(reason: "codex-accounts-monitor-start")

        for account in projection.visibleAccounts {
            if Task.isCancelled { return }
            let entry = await self.mergingPreviousCodexAccountUsageIfNeeded(
                self.refreshCodexAccountForMonitoring(account),
                previous: self.codexAccountUsageSnapshots[account.id])
            refreshed[account.id] = entry
            self.codexAccountUsageSnapshots = refreshed
            self.persistWidgetSnapshot(reason: "codex-account-monitor-update")
        }
    }

    private func mergingPreviousCodexAccountUsageIfNeeded(
        _ entry: CodexAccountUsageSnapshot,
        previous: CodexAccountUsageSnapshot?)
        -> CodexAccountUsageSnapshot
    {
        guard entry.usage == nil,
              let previous,
              previous.usage != nil
        else {
            return entry
        }

        return CodexAccountUsageSnapshot(
            id: entry.id,
            displayName: entry.displayName,
            source: entry.source,
            usage: previous.usage,
            credits: previous.credits,
            sourceLabel: entry.sourceLabel ?? previous.sourceLabel,
            error: entry.error,
            updatedAt: previous.updatedAt)
    }

    private func refreshCodexAccountForMonitoring(_ account: CodexVisibleAccount) async -> CodexAccountUsageSnapshot {
        if account.id == self.settings.codexVisibleAccountProjection.activeVisibleAccountID,
           let snapshot = self.snapshots[.codex]
        {
            return CodexAccountUsageSnapshot(
                id: account.id,
                displayName: account.menuDisplayName,
                source: account.selectionSource,
                usage: snapshot,
                credits: self.credits,
                sourceLabel: self.lastSourceLabels[.codex],
                error: self.errors[.codex],
                updatedAt: snapshot.updatedAt)
        }

        guard let env = self.codexMonitoringEnvironment(for: account) else {
            return CodexAccountUsageSnapshot(
                id: account.id,
                displayName: account.menuDisplayName,
                source: account.selectionSource,
                usage: nil,
                credits: nil,
                sourceLabel: nil,
                error: "Codex account credentials are unavailable.",
                updatedAt: Date())
        }

        let sourceMode: ProviderSourceMode = switch self.settings.codexUsageDataSource {
        case .auto: .auto
        case .oauth: .oauth
        case .cli: .cli
        }
        let fetcher = UsageFetcher(environment: env)
        let context = ProviderFetchContext(
            runtime: .app,
            sourceMode: sourceMode,
            includeCredits: true,
            webTimeout: 60,
            webDebugDumpHTML: false,
            verbose: self.settings.isVerboseLoggingEnabled,
            env: env,
            settings: ProviderRegistry.makeSettingsSnapshot(settings: self.settings, tokenOverride: nil),
            fetcher: fetcher,
            claudeFetcher: self.claudeFetcher,
            browserDetection: self.browserDetection)
        let outcome = await ProviderDescriptorRegistry.descriptor(for: .codex).fetchOutcome(context: context)

        switch outcome.result {
        case let .success(result):
            return CodexAccountUsageSnapshot(
                id: account.id,
                displayName: account.menuDisplayName,
                source: account.selectionSource,
                usage: result.usage.scoped(to: .codex),
                credits: result.credits,
                sourceLabel: result.sourceLabel,
                error: nil,
                updatedAt: result.usage.updatedAt)
        case let .failure(error):
            return CodexAccountUsageSnapshot(
                id: account.id,
                displayName: account.menuDisplayName,
                source: account.selectionSource,
                usage: nil,
                credits: nil,
                sourceLabel: outcome.attempts.last?.strategyID,
                error: error.localizedDescription,
                updatedAt: Date())
        }
    }

    private func codexMonitoringEnvironment(for account: CodexVisibleAccount) -> [String: String]? {
        switch account.selectionSource {
        case .liveSystem:
            return self.environmentBase
        case let .managedAccount(id):
            let snapshot = self.settings.codexAccountReconciliationSnapshot
            guard let managed = snapshot.storedAccounts.first(where: { $0.id == id }) else { return nil }
            return CodexHomeScope.scopedEnvironment(base: self.environmentBase, codexHome: managed.managedHomePath)
        }
    }
}
