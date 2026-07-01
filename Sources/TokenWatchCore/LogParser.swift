import Foundation

public struct LogParser {
    public let previewLimit: Int
    private let formatter: ISO8601DateFormatter
    private let fallbackFormatter: ISO8601DateFormatter

    public init(previewLimit: Int = 80) {
        self.previewLimit = previewLimit
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = f
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        self.fallbackFormatter = f2
    }

    public func parse(fileContents: String, project: String) -> [UsageRecord] {
        parse(lines: fileContents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init),
              project: project)
    }

    public func parse(lines: [String], project: String) -> [UsageRecord] {
        var out: [UsageRecord] = []
        var lastPreview = ""
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { continue }

            let type = obj["type"] as? String
            let message = obj["message"] as? [String: Any]

            if type == "user", let m = message {
                lastPreview = extractPreview(from: m["content"])
                continue
            }

            guard type == "assistant", let m = message,
                  let usage = m["usage"] as? [String: Any],
                  let model = m["model"] as? String
            else { continue }

            let record = UsageRecord(
                id: m["id"] as? String,
                timestamp: parseDate(obj["timestamp"] as? String),
                model: model,
                inputTokens: intField(usage, "input_tokens"),
                outputTokens: intField(usage, "output_tokens"),
                cacheWriteTokens: intField(usage, "cache_creation_input_tokens"),
                cacheReadTokens: intField(usage, "cache_read_input_tokens"),
                promptPreview: lastPreview,
                project: projectName(fromCwd: obj["cwd"] as? String, fallback: project)
            )
            out.append(record)
        }
        return out
    }

    private func intField(_ dict: [String: Any], _ key: String) -> Int {
        if let i = dict[key] as? Int { return i }
        if let d = dict[key] as? Double { return Int(d) }
        return 0
    }

    private func parseDate(_ s: String?) -> Date {
        guard let s = s else { return Date() }
        return formatter.date(from: s) ?? fallbackFormatter.date(from: s) ?? Date()
    }

    private func projectName(fromCwd cwd: String?, fallback: String) -> String {
        guard let cwd = cwd, !cwd.isEmpty else { return fallback }
        return (cwd as NSString).lastPathComponent
    }

    private func extractPreview(from content: Any?) -> String {
        var text = ""
        if let s = content as? String {
            text = s
        } else if let arr = content as? [[String: Any]] {
            text = arr.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > previewLimit ? String(text.prefix(previewLimit)) + "…" : text
    }
}
