import Foundation

enum TokenUsageCacheIO {
    private static func artifactVersion(for provider: UsageProvider) -> Int {
        switch provider {
        case .codex:
            5
        case .claude, .vertexai:
            3
        default:
            1
        }
    }

    private static func defaultCacheRoot() -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("CodexBar", isDirectory: true)
    }

    static func cacheFileURL(provider: UsageProvider, cacheRoot: URL? = nil) -> URL {
        let root = cacheRoot ?? self.defaultCacheRoot()
        let artifactVersion = self.artifactVersion(for: provider)
        return root
            .appendingPathComponent("token-usage", isDirectory: true)
            .appendingPathComponent("\(provider.rawValue)-v\(artifactVersion).json", isDirectory: false)
    }

    static func load(provider: UsageProvider, cacheRoot: URL? = nil) -> TokenUsageCache {
        let url = self.cacheFileURL(provider: provider, cacheRoot: cacheRoot)
        if let decoded = self.loadCache(at: url) { return decoded }
        return TokenUsageCache()
    }

    private static func loadCache(at url: URL) -> TokenUsageCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let decoded = try? JSONDecoder().decode(TokenUsageCache.self, from: data)
        else { return nil }
        guard decoded.version == 1 else { return nil }
        return decoded
    }

    static func save(provider: UsageProvider, cache: TokenUsageCache, cacheRoot: URL? = nil) {
        let url = self.cacheFileURL(provider: provider, cacheRoot: cacheRoot)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tmp = dir.appendingPathComponent(".tmp-\(UUID().uuidString).json", isDirectory: false)
        let data = (try? JSONEncoder().encode(cache)) ?? Data()
        do {
            try data.write(to: tmp, options: [.atomic])
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }
}

struct TokenUsageCache: Codable {
    var version: Int = 1
    var lastScanUnixMs: Int64 = 0

    /// filePath -> file usage
    var files: [String: TokenUsageFileUsage] = [:]

    /// dayKey -> model -> packed usage
    var days: [String: [String: [Int]]] = [:]

    /// rootPath -> mtime (for Claude roots)
    var roots: [String: Int64]?
}

struct TokenUsageFileUsage: Codable {
    var mtimeUnixMs: Int64
    var size: Int64
    var days: [String: [String: [Int]]]
    var parsedBytes: Int64?
    var lastModel: String?
    var lastTotals: TokenUsageCodexTotals?
    var sessionId: String?
    var forkedFromId: String?
    var claudeRows: [TokenUsageScanner.ClaudeUsageRow]?
}

struct TokenUsageCodexTotals: Codable {
    var input: Int
    var cached: Int
    var output: Int
}
