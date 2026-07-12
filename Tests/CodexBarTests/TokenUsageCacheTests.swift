import Foundation
import Testing
@testable import CodexBarCore

struct TokenUsageCacheTests {
    @Test
    func `cache file URL uses codex specific artifact version`() {
        let root = URL(fileURLWithPath: "/tmp/codexbar-token-cache", isDirectory: true)

        let codexURL = TokenUsageCacheIO.cacheFileURL(provider: .codex, cacheRoot: root)
        let claudeURL = TokenUsageCacheIO.cacheFileURL(provider: .claude, cacheRoot: root)

        #expect(codexURL.lastPathComponent == "codex-v5.json")
        #expect(claudeURL.lastPathComponent == "claude-v3.json")
    }
}
