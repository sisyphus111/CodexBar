import Foundation

enum TokenUsageModelNormalizer {
    static func codex(_ raw: String) -> String {
        var model = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.hasPrefix("openai/") {
            model.removeFirst("openai/".count)
        }
        if let suffix = model.range(of: #"-\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) {
            model.removeSubrange(suffix)
        }
        return model
    }

    static func claude(_ raw: String) -> String {
        var model = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.hasPrefix("anthropic.") {
            model.removeFirst("anthropic.".count)
        }
        if let lastDot = model.lastIndex(of: "."), model.contains("claude-") {
            let tail = String(model[model.index(after: lastDot)...])
            if tail.hasPrefix("claude-") { model = tail }
        }
        if let suffix = model.range(of: #"-v\d+:\d+$"#, options: .regularExpression) {
            model.removeSubrange(suffix)
        }
        if let suffix = model.range(of: #"-\d{8}$"#, options: .regularExpression) {
            model.removeSubrange(suffix)
        }
        return model
    }
}
