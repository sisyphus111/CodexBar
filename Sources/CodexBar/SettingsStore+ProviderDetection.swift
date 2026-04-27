import CodexBarCore
import Foundation

extension SettingsStore {
    func runInitialProviderDetectionIfNeeded(force: Bool = false) {
        guard force || !self.providerDetectionCompleted else { return }
        LoginShellPathCache.shared.captureOnce { [weak self] _ in
            Task { @MainActor in
                await self?.applyProviderDetection()
            }
        }
    }

    func applyProviderDetection() async {
        guard !self.providerDetectionCompleted else { return }
        let codexInstalled = BinaryLocator.resolveCodexBinary() != nil
        let logger = CodexBarLog.logger(LogCategories.providerDetection)

        // Keep Codex enabled even before the CLI is installed so login/setup remains reachable.
        logger.info(
            "Provider detection results",
            metadata: [
                "codexInstalled": codexInstalled ? "1" : "0",
            ])
        logger.info(
            "Provider detection enablement",
            metadata: [
                "codex": "1",
            ])

        if self.config.providerConfig(for: .codex)?.enabled != false {
            self.updateProviderConfig(provider: .codex) { entry in
                entry.enabled = true
            }
        }
        self.providerDetectionCompleted = true
        logger.info("Provider detection completed")
    }
}
