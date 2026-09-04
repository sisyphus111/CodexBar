import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar
@testable import CodexBarWidget

struct CodexAccountWidgetTests {
    private let now = Date()

    @Test
    func `weekly only primary never becomes a session quota`() throws {
        let account = self.account(primary: self.window(used: 30, minutes: 10080))
        let state = CodexAccountWidgetState(snapshot: self.snapshot(account), now: self.now)
        #expect(state.row("session").percentLeft == nil)
        #expect(state.row("weekly").percentLeft == 70)
        #expect(state.window("session") == nil)
        #expect(state.window("weekly")?.windowMinutes == 10080)
        #expect(state.visibleQuotaIDs == ["weekly"])
        let data = try JSONEncoder().encode(self.snapshot(account))
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.entries.first?.accountDisplayName == "reader@example.com")
    }

    @Test
    func `weekly cap blocks the session until reset and missing data stays unknown`() {
        let account = self.account(
            primary: self.window(used: 15, minutes: 300),
            secondary: self.window(used: 100, minutes: 10080))
        let state = CodexAccountWidgetState(snapshot: self.snapshot(account), now: self.now)
        #expect(state.weeklyBlocksSession)
        #expect(state.row("session").percentLeft == 0)
        let later = CodexAccountWidgetState(
            snapshot: self.snapshot(account), now: self.now.addingTimeInterval(7200))
        #expect(!later.weeklyBlocksSession)
        #expect(later.row("session").percentLeft == 85)
        let unavailable = CodexAccountWidgetState(snapshot: self.snapshot(self.account()), now: self.now)
        #expect(unavailable.row("session").percentLeft == nil)
        #expect(unavailable.row("weekly").percentLeft == nil)
    }

    @Test
    func `pace labels match the menu wording`() {
        let onPace = CodexAccountWidgetState(
            snapshot: self.snapshot(self.account(primary: self.window(used: 80, minutes: 300))), now: self.now)
        let deficit = CodexAccountWidgetState(
            snapshot: self.snapshot(self.account(primary: self.window(used: 90, minutes: 300))), now: self.now)
        let reserve = CodexAccountWidgetState(
            snapshot: self.snapshot(self.account(primary: self.window(used: 70, minutes: 300))), now: self.now)
        #expect(onPace.paceLabel("session") == "On pace")
        #expect(deficit.paceLabel("session") == "10% in deficit")
        #expect(reserve.paceLabel("session") == "10% in reserve")
        #expect(onPace.projectionLabel("session") == "Lasts until reset")
        #expect(deficit.projectionLabel("session") == "Runs out in 27m")
        #expect(onPace.limitDetail("session") == "5-hour limit · Resets in 1h")
        #expect(onPace.expectedRemainingPercent("session") == nil)
        #expect(deficit.expectedRemainingPercent("session") == 20)
        #expect(reserve.expectedRemainingPercent("session") == 20)
        #expect(deficit.paceIsDeficit("session"))
        #expect(!reserve.paceIsDeficit("session"))
    }

    @Test
    func `disabled Codex never shows a retained account`() {
        let snapshot = WidgetSnapshot(entries: [self.account()], enabledProviders: [.claude], generatedAt: self.now)
        #expect(CodexAccountWidgetState(snapshot: snapshot, now: self.now).account == nil)
    }

    @Test @MainActor
    func `account labels follow snapshot identity and privacy`() async {
        let settings = testSettingsStore(
            suiteName: "CodexAccountWidgetTests-identity",
            config: testConfigWithAllProvidersDisabled())
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(homeDirectory: "/nonexistent", fileExists: { _ in false }),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: [:])
        var saved: WidgetSnapshot?
        store._test_widgetSnapshotSaveOverride = { saved = $0 }
        defer { store._test_widgetSnapshotSaveOverride = nil }
        for email in ["first@example.com", "second@example.com"] {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: self.window(used: 15, minutes: 300),
                    secondary: nil,
                    updatedAt: self.now,
                    identity: ProviderIdentitySnapshot(
                        providerID: .codex, accountEmail: email, accountOrganization: nil, loginMethod: nil)),
                provider: .codex)
            store.persistWidgetSnapshot(reason: "account-switch-test")
            await store.widgetSnapshotPersistTask?.value
            #expect(saved?.entries.first { $0.provider == .codex }?.accountDisplayName == email)
        }
        settings.hidePersonalInfo = true
        store.persistWidgetSnapshot(reason: "privacy-test")
        await store.widgetSnapshotPersistTask?.value
        #expect(saved?.entries.first { $0.provider == .codex }?.accountDisplayName == nil)
    }

    @Test @MainActor
    func `render synthetic account overview variants`() throws {
        guard let path = ProcessInfo.processInfo.environment["CODEXBAR_ACCOUNT_WIDGET_PROOF_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let variants: [(String, WidgetSnapshot)] = [
            ("normal", self.snapshot(self.account(
                primary: self.window(used: 35, minutes: 300), secondary: self.window(used: 62, minutes: 10080)))),
            ("weekly-only", self.snapshot(self.account(primary: self.window(used: 91, minutes: 10080)))),
            ("deficit", self.snapshot(self.account(
                primary: self.window(used: 90, minutes: 300), secondary: self.window(used: 90, minutes: 10080)))),
            ("blocked", self.snapshot(self.account(
                primary: self.window(used: 15, minutes: 300), secondary: self.window(used: 100, minutes: 10080)))),
            ("empty", WidgetSnapshot(entries: [], generatedAt: self.now)),
        ]
        for (name, snapshot) in variants {
            for dark in [false, true] {
                let view = CodexAccountOverview(state: CodexAccountWidgetState(snapshot: snapshot, now: self.now))
                    .padding(16)
                    .frame(width: 344, height: 344)
                    .background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                let bitmap = NSBitmapImageRep(cgImage: image)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
            }
        }
    }

    private func window(used: Double, minutes: Int) -> RateWindow {
        RateWindow(
            usedPercent: used,
            windowMinutes: minutes,
            resetsAt: self.now.addingTimeInterval(3600),
            resetDescription: nil)
    }

    private func account(primary: RateWindow? = nil, secondary: RateWindow? = nil) -> WidgetSnapshot.ProviderEntry {
        WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: self.now,
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            creditsRemaining: 1234,
            codeReviewRemainingPercent: 78,
            tokenUsage: nil,
            dailyUsage: [],
            accountDisplayName: "reader@example.com")
    }

    private func snapshot(_ account: WidgetSnapshot.ProviderEntry) -> WidgetSnapshot {
        WidgetSnapshot(entries: [account], generatedAt: self.now)
    }
}
