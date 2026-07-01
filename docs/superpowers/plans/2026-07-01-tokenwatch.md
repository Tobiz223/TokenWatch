# TokenWatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that reads Claude Code local logs and shows month-to-date spend, request history, "overkill" alerts, and a heuristic model advisor that can launch `claude -p`.

**Architecture:** A SwiftPM package with a pure-logic library target (`TokenWatchCore`) covered by unit tests, and an executable target (`TokenWatch`) that hosts the AppKit menu bar UI (SwiftUI popover) over an observable store. The core has zero UI/network dependencies; the UI is a thin layer.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit (`NSStatusItem`, `NSApplication.setActivationPolicy(.accessory)`), SwiftUI (popover content), Foundation (`JSONSerialization`, `DispatchSource` file watching). Tested via `swift test`; run via opening `Package.swift` in Xcode.

## Global Constraints

- Platform: macOS 13+ only. `Package.swift` declares `platforms: [.macOS(.v13)]`.
- No third-party dependencies. Foundation / AppKit / SwiftUI only.
- Data source is local files only: `~/.claude/projects/**/*.jsonl`. No network calls anywhere.
- Core library (`TokenWatchCore`) must not import AppKit or SwiftUI — keep it UI-free and testable.
- Parsing must be tolerant: skip malformed/unknown lines, never crash on schema drift.
- Money is `Double` dollars; token rates in `pricing.json` are **per 1,000,000 tokens**.
- Model CLI aliases for `claude --model`: `haiku`, `sonnet`, `opus`.
- Model ids used for pricing lookup: `claude-haiku-4-5`, `claude-sonnet-5`, `claude-opus-4-8`.

---

## File Structure

```
Package.swift
Sources/
  TokenWatchCore/
    UsageRecord.swift          # data model
    PricingTable.swift         # rates + JSON load
    CostEngine.swift           # per-record cost + aggregates
    LogParser.swift            # JSONL -> [UsageRecord]
    ComplexityHeuristics.swift # shared prompt/record complexity signal
    OverkillDetector.swift     # flag + overpay
    Advisor.swift              # recommendation + claude -p command
    Resources/
      pricing.json             # bundled, editable rates
  TokenWatch/
    main.swift                 # NSApplication bootstrap (.accessory)
    AppDelegate.swift          # NSStatusItem + popover wiring
    UsageStore.swift           # ObservableObject pipeline + FileWatcher
    FileWatcher.swift          # DispatchSource directory watcher
    Views/
      RootView.swift           # tab container
      HistoryView.swift
      StatsView.swift
      AdvisorView.swift
Tests/
  TokenWatchCoreTests/
    Fixtures/
      sample.jsonl
    PricingTableTests.swift
    CostEngineTests.swift
    LogParserTests.swift
    ComplexityHeuristicsTests.swift
    OverkillDetectorTests.swift
    AdvisorTests.swift
README.md
```

---

### Task 1: Package scaffold + smoke test

**Files:**
- Create: `Package.swift`
- Create: `Sources/TokenWatchCore/Version.swift`
- Create: `Sources/TokenWatch/main.swift` (temporary stub, replaced in Task 11)
- Test: `Tests/TokenWatchCoreTests/PricingTableTests.swift` (temporary smoke test, expanded in Task 3)

**Interfaces:**
- Produces: `TokenWatchCore.libraryVersion -> String`

- [ ] **Step 1: Write the failing test**

`Tests/TokenWatchCoreTests/PricingTableTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class PricingTableTests: XCTestCase {
    func testLibraryVersionIsNonEmpty() {
        XCTAssertFalse(libraryVersion.isEmpty)
    }
}
```

- [ ] **Step 2: Create Package.swift**

`Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenWatch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TokenWatchCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TokenWatch",
            dependencies: ["TokenWatchCore"]
        ),
        .testTarget(
            name: "TokenWatchCoreTests",
            dependencies: ["TokenWatchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

- [ ] **Step 3: Create the minimal sources so the package builds**

`Sources/TokenWatchCore/Version.swift`:
```swift
import Foundation

public let libraryVersion = "1.0.0"
```

`Sources/TokenWatchCore/Resources/pricing.json`:
```json
{
  "claude-opus-4-8":  { "input": 15.0, "output": 75.0, "cacheWrite": 18.75, "cacheRead": 1.5 },
  "claude-sonnet-5":  { "input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3 },
  "claude-haiku-4-5": { "input": 1.0,  "output": 5.0,  "cacheWrite": 1.25,  "cacheRead": 0.1 },
  "default":          { "input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3 }
}
```

`Sources/TokenWatch/main.swift` (temporary stub):
```swift
import Foundation

print("TokenWatch stub — replaced in Task 11")
```

Create an empty `Tests/TokenWatchCoreTests/Fixtures/.gitkeep` so the resource path exists.

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter PricingTableTests`
Expected: builds and PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold TokenWatch SwiftPM package"
```

---

### Task 2: UsageRecord data model

**Files:**
- Create: `Sources/TokenWatchCore/UsageRecord.swift`
- Test: `Tests/TokenWatchCoreTests/CostEngineTests.swift` (starts here, expanded in Task 4)

**Interfaces:**
- Produces:
```swift
public struct UsageRecord: Equatable {
    public let id: String?
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheWriteTokens: Int
    public let cacheReadTokens: Int
    public let promptPreview: String
    public let project: String
    public init(id: String?, timestamp: Date, model: String,
                inputTokens: Int, outputTokens: Int,
                cacheWriteTokens: Int, cacheReadTokens: Int,
                promptPreview: String, project: String)
}
```

- [ ] **Step 1: Write the failing test**

`Tests/TokenWatchCoreTests/CostEngineTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class CostEngineTests: XCTestCase {
    func testUsageRecordStoresFields() {
        let r = UsageRecord(id: "msg_1", timestamp: Date(timeIntervalSince1970: 0),
                            model: "claude-haiku-4-5", inputTokens: 100, outputTokens: 50,
                            cacheWriteTokens: 0, cacheReadTokens: 0,
                            promptPreview: "hi", project: "demo")
        XCTAssertEqual(r.model, "claude-haiku-4-5")
        XCTAssertEqual(r.inputTokens, 100)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter CostEngineTests`
Expected: FAIL — `UsageRecord` not found.

- [ ] **Step 3: Implement the model**

`Sources/TokenWatchCore/UsageRecord.swift`:
```swift
import Foundation

public struct UsageRecord: Equatable {
    public let id: String?
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheWriteTokens: Int
    public let cacheReadTokens: Int
    public let promptPreview: String
    public let project: String

    public init(id: String?, timestamp: Date, model: String,
                inputTokens: Int, outputTokens: Int,
                cacheWriteTokens: Int, cacheReadTokens: Int,
                promptPreview: String, project: String) {
        self.id = id
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cacheReadTokens = cacheReadTokens
        self.promptPreview = promptPreview
        self.project = project
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter CostEngineTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatchCore/UsageRecord.swift Tests/TokenWatchCoreTests/CostEngineTests.swift
git commit -m "feat: add UsageRecord model"
```

---

### Task 3: PricingTable + JSON loading

**Files:**
- Create: `Sources/TokenWatchCore/PricingTable.swift`
- Test: `Tests/TokenWatchCoreTests/PricingTableTests.swift` (replace the smoke test)

**Interfaces:**
- Produces:
```swift
public struct Rates: Codable, Equatable {
    public let input: Double
    public let output: Double
    public let cacheWrite: Double
    public let cacheRead: Double
}
public struct PricingTable: Equatable {
    public let rates: [String: Rates]
    public let defaultRates: Rates
    public func rates(for model: String) -> Rates
    public func isKnown(_ model: String) -> Bool
    public static func load(from data: Data) throws -> PricingTable
    public static func bundled() -> PricingTable   // loads Resources/pricing.json
}
```

- [ ] **Step 1: Write the failing tests**

Replace `Tests/TokenWatchCoreTests/PricingTableTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class PricingTableTests: XCTestCase {
    let json = """
    {
      "claude-haiku-4-5": { "input": 1.0, "output": 5.0, "cacheWrite": 1.25, "cacheRead": 0.1 },
      "default":          { "input": 3.0, "output": 15.0, "cacheWrite": 3.75, "cacheRead": 0.3 }
    }
    """.data(using: .utf8)!

    func testLoadsKnownModel() throws {
        let t = try PricingTable.load(from: json)
        XCTAssertEqual(t.rates(for: "claude-haiku-4-5").output, 5.0)
        XCTAssertTrue(t.isKnown("claude-haiku-4-5"))
    }

    func testUnknownModelFallsBackToDefault() throws {
        let t = try PricingTable.load(from: json)
        XCTAssertEqual(t.rates(for: "mystery-model").input, 3.0)
        XCTAssertFalse(t.isKnown("mystery-model"))
    }

    func testBundledLoads() {
        let t = PricingTable.bundled()
        XCTAssertTrue(t.isKnown("claude-opus-4-8"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter PricingTableTests`
Expected: FAIL — `PricingTable` / `Rates` not found.

- [ ] **Step 3: Implement PricingTable**

`Sources/TokenWatchCore/PricingTable.swift`:
```swift
import Foundation

public struct Rates: Codable, Equatable {
    public let input: Double
    public let output: Double
    public let cacheWrite: Double
    public let cacheRead: Double
    public init(input: Double, output: Double, cacheWrite: Double, cacheRead: Double) {
        self.input = input; self.output = output
        self.cacheWrite = cacheWrite; self.cacheRead = cacheRead
    }
}

public enum PricingError: Error { case missingDefault }

public struct PricingTable: Equatable {
    public let rates: [String: Rates]
    public let defaultRates: Rates

    public init(rates: [String: Rates], defaultRates: Rates) {
        self.rates = rates
        self.defaultRates = defaultRates
    }

    public func rates(for model: String) -> Rates { rates[model] ?? defaultRates }
    public func isKnown(_ model: String) -> Bool { rates[model] != nil }

    public static func load(from data: Data) throws -> PricingTable {
        var all = try JSONDecoder().decode([String: Rates].self, from: data)
        guard let def = all.removeValue(forKey: "default") else { throw PricingError.missingDefault }
        return PricingTable(rates: all, defaultRates: def)
    }

    public static func bundled() -> PricingTable {
        if let url = Bundle.module.url(forResource: "pricing", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let table = try? load(from: data) {
            return table
        }
        // Safe fallback if the resource is missing.
        let def = Rates(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3)
        return PricingTable(rates: [:], defaultRates: def)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter PricingTableTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatchCore/PricingTable.swift Tests/TokenWatchCoreTests/PricingTableTests.swift
git commit -m "feat: add PricingTable with JSON loading"
```

---

### Task 4: CostEngine

**Files:**
- Create: `Sources/TokenWatchCore/CostEngine.swift`
- Test: `Tests/TokenWatchCoreTests/CostEngineTests.swift` (expand)

**Interfaces:**
- Consumes: `UsageRecord`, `PricingTable`, `Rates`
- Produces:
```swift
public struct CostEngine {
    public init(pricing: PricingTable)
    public func cost(inputTokens: Int, outputTokens: Int,
                     cacheWriteTokens: Int, cacheReadTokens: Int, model: String) -> Double
    public func cost(for record: UsageRecord) -> Double
    public func total(_ records: [UsageRecord]) -> Double
    public func totalByModel(_ records: [UsageRecord]) -> [String: Double]
    public func totalByProject(_ records: [UsageRecord]) -> [String: Double]
    public func monthToDateTotal(_ records: [UsageRecord], now: Date, calendar: Calendar) -> Double
}
```

- [ ] **Step 1: Write the failing tests**

Add to `Tests/TokenWatchCoreTests/CostEngineTests.swift`:
```swift
    func makeEngine() -> CostEngine {
        let rates = ["claude-haiku-4-5": Rates(input: 1.0, output: 5.0, cacheWrite: 1.25, cacheRead: 0.1)]
        return CostEngine(pricing: PricingTable(rates: rates,
            defaultRates: Rates(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3)))
    }

    func testCostForRecord() {
        // 1,000,000 input @ $1 + 1,000,000 output @ $5 = $6
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-haiku-4-5",
                            inputTokens: 1_000_000, outputTokens: 1_000_000,
                            cacheWriteTokens: 0, cacheReadTokens: 0,
                            promptPreview: "", project: "p")
        XCTAssertEqual(makeEngine().cost(for: r), 6.0, accuracy: 1e-9)
    }

    func testMonthToDateExcludesLastMonth() {
        let cal = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: cal, year: 2026, month: 7, day: 15).date!
        let thisMonth = DateComponents(calendar: cal, year: 2026, month: 7, day: 2).date!
        let lastMonth = DateComponents(calendar: cal, year: 2026, month: 6, day: 30).date!
        func rec(_ d: Date) -> UsageRecord {
            UsageRecord(id: nil, timestamp: d, model: "claude-haiku-4-5",
                        inputTokens: 1_000_000, outputTokens: 0,
                        cacheWriteTokens: 0, cacheReadTokens: 0, promptPreview: "", project: "p")
        }
        let total = makeEngine().monthToDateTotal([rec(thisMonth), rec(lastMonth)], now: now, calendar: cal)
        XCTAssertEqual(total, 1.0, accuracy: 1e-9) // only thisMonth's $1 counts
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter CostEngineTests`
Expected: FAIL — `CostEngine` not found.

- [ ] **Step 3: Implement CostEngine**

`Sources/TokenWatchCore/CostEngine.swift`:
```swift
import Foundation

public struct CostEngine {
    public let pricing: PricingTable
    public init(pricing: PricingTable) { self.pricing = pricing }

    public func cost(inputTokens: Int, outputTokens: Int,
                     cacheWriteTokens: Int, cacheReadTokens: Int, model: String) -> Double {
        let r = pricing.rates(for: model)
        let raw = Double(inputTokens) * r.input
                + Double(outputTokens) * r.output
                + Double(cacheWriteTokens) * r.cacheWrite
                + Double(cacheReadTokens) * r.cacheRead
        return raw / 1_000_000.0
    }

    public func cost(for record: UsageRecord) -> Double {
        cost(inputTokens: record.inputTokens, outputTokens: record.outputTokens,
             cacheWriteTokens: record.cacheWriteTokens, cacheReadTokens: record.cacheReadTokens,
             model: record.model)
    }

    public func total(_ records: [UsageRecord]) -> Double {
        records.reduce(0) { $0 + cost(for: $1) }
    }

    public func totalByModel(_ records: [UsageRecord]) -> [String: Double] {
        var out: [String: Double] = [:]
        for r in records { out[r.model, default: 0] += cost(for: r) }
        return out
    }

    public func totalByProject(_ records: [UsageRecord]) -> [String: Double] {
        var out: [String: Double] = [:]
        for r in records { out[r.project, default: 0] += cost(for: r) }
        return out
    }

    public func monthToDateTotal(_ records: [UsageRecord], now: Date, calendar: Calendar) -> Double {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return total(records.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.timestamp)
            return c.year == comps.year && c.month == comps.month
        })
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter CostEngineTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatchCore/CostEngine.swift Tests/TokenWatchCoreTests/CostEngineTests.swift
git commit -m "feat: add CostEngine with per-record cost and aggregates"
```

---

### Task 5: LogParser (JSONL → records)

**Files:**
- Create: `Sources/TokenWatchCore/LogParser.swift`
- Create: `Tests/TokenWatchCoreTests/Fixtures/sample.jsonl`
- Test: `Tests/TokenWatchCoreTests/LogParserTests.swift`

**Interfaces:**
- Consumes: `UsageRecord`
- Produces:
```swift
public struct LogParser {
    public init(previewLimit: Int = 80)
    public func parse(lines: [String], project: String) -> [UsageRecord]
    public func parse(fileContents: String, project: String) -> [UsageRecord]
}
```

**Notes on schema (tolerant, JSONSerialization-based):** Each line is a JSON object.
- Assistant usage line: `type == "assistant"`, with `message.model` (String) and
  `message.usage` containing `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens` (all optional ints). `message.id` (String, optional). Top-level
  `timestamp` (ISO8601 String, optional). Top-level `cwd` used for project fallback.
- User line: `type == "user"`, `message.content` is either a String or an array of
  `{ "type": "text", "text": String }`. Captured as the running prompt preview.
- Any line that doesn't parse or has no usage is skipped. The most recent user preview is
  attached to the next assistant record.

- [ ] **Step 1: Create the fixture**

`Tests/TokenWatchCoreTests/Fixtures/sample.jsonl`:
```
{"type":"user","timestamp":"2026-07-01T10:00:00Z","message":{"content":"fix the login bug please"}}
{"type":"assistant","timestamp":"2026-07-01T10:00:05Z","cwd":"/Users/x/dev/myapp","message":{"id":"msg_1","model":"claude-opus-4-8","usage":{"input_tokens":2300,"output_tokens":800,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
{"garbage line that is not json}
{"type":"assistant","timestamp":"2026-07-01T10:01:00Z","cwd":"/Users/x/dev/myapp","message":{"id":"msg_2","model":"claude-haiku-4-5","usage":{"input_tokens":120,"output_tokens":40}}}
```

- [ ] **Step 2: Write the failing tests**

`Tests/TokenWatchCoreTests/LogParserTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class LogParserTests: XCTestCase {
    func loadFixture() throws -> String {
        let url = Bundle.module.url(forResource: "sample", withExtension: "jsonl", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testParsesTwoRecordsSkippingGarbage() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        XCTAssertEqual(records.count, 2)
    }

    func testFirstRecordFieldsAndPreview() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        let first = records[0]
        XCTAssertEqual(first.model, "claude-opus-4-8")
        XCTAssertEqual(first.inputTokens, 2300)
        XCTAssertEqual(first.outputTokens, 800)
        XCTAssertEqual(first.project, "myapp")            // from cwd lastPathComponent
        XCTAssertTrue(first.promptPreview.contains("login bug"))
        XCTAssertEqual(first.id, "msg_1")
    }

    func testMissingCacheFieldsDefaultToZero() throws {
        let records = LogParser().parse(fileContents: try loadFixture(), project: "fallback")
        XCTAssertEqual(records[1].cacheReadTokens, 0)
        XCTAssertEqual(records[1].cacheWriteTokens, 0)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `swift test --filter LogParserTests`
Expected: FAIL — `LogParser` not found.

- [ ] **Step 4: Implement LogParser**

`Sources/TokenWatchCore/LogParser.swift`:
```swift
import Foundation

public struct LogParser {
    public let previewLimit: Int
    private let formatter: ISO8601DateFormatter

    public init(previewLimit: Int = 80) {
        self.previewLimit = previewLimit
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = f
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
        return formatter.date(from: s) ?? Date()
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
```

- [ ] **Step 5: Run to verify it passes**

Run: `swift test --filter LogParserTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/TokenWatchCore/LogParser.swift Tests/TokenWatchCoreTests/LogParserTests.swift Tests/TokenWatchCoreTests/Fixtures/sample.jsonl
git commit -m "feat: add tolerant JSONL LogParser"
```

---

### Task 6: ComplexityHeuristics

**Files:**
- Create: `Sources/TokenWatchCore/ComplexityHeuristics.swift`
- Test: `Tests/TokenWatchCoreTests/ComplexityHeuristicsTests.swift`

**Interfaces:**
- Produces:
```swift
public enum ModelTier: String, Equatable { case haiku, sonnet, opus }
public struct ComplexityHeuristics {
    public init(hardKeywords: [String] = ComplexityHeuristics.defaultHardKeywords)
    public static let defaultHardKeywords: [String]
    public func recommend(prompt: String) -> ModelTier
    public func isSimpleTask(outputTokens: Int, contextTokens: Int, previewLength: Int) -> Bool
}
```

**Rules (single source of truth for both advisor and overkill):**
- `recommend`: contains a hard keyword OR length > 2000 → `.opus`; else contains code
  markers (```` ``` ````, `func `, `class `, `{`) OR length ≥ 280 → `.sonnet`; else `.haiku`.
- `isSimpleTask`: `outputTokens < 400 && contextTokens < 3000 && previewLength < 200`.
- `defaultHardKeywords`: `["refactor","architecture","debug","design","prove","optimize","concurrency","security","migrate","threading"]`.

- [ ] **Step 1: Write the failing tests**

`Tests/TokenWatchCoreTests/ComplexityHeuristicsTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class ComplexityHeuristicsTests: XCTestCase {
    let h = ComplexityHeuristics()

    func testShortSimplePromptIsHaiku() {
        XCTAssertEqual(h.recommend(prompt: "rename this variable"), .haiku)
    }

    func testHardKeywordIsOpus() {
        XCTAssertEqual(h.recommend(prompt: "refactor the auth layer"), .opus)
    }

    func testCodeBlockIsAtLeastSonnet() {
        XCTAssertEqual(h.recommend(prompt: "explain ```func foo() {}```"), .sonnet)
    }

    func testSimpleTaskDetection() {
        XCTAssertTrue(h.isSimpleTask(outputTokens: 40, contextTokens: 120, previewLength: 20))
        XCTAssertFalse(h.isSimpleTask(outputTokens: 900, contextTokens: 120, previewLength: 20))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ComplexityHeuristicsTests`
Expected: FAIL — `ComplexityHeuristics` not found.

- [ ] **Step 3: Implement**

`Sources/TokenWatchCore/ComplexityHeuristics.swift`:
```swift
import Foundation

public enum ModelTier: String, Equatable { case haiku, sonnet, opus }

public struct ComplexityHeuristics {
    public static let defaultHardKeywords = ["refactor","architecture","debug","design",
        "prove","optimize","concurrency","security","migrate","threading"]
    public let hardKeywords: [String]

    public init(hardKeywords: [String] = ComplexityHeuristics.defaultHardKeywords) {
        self.hardKeywords = hardKeywords
    }

    public func recommend(prompt: String) -> ModelTier {
        let lower = prompt.lowercased()
        if hardKeywords.contains(where: { lower.contains($0) }) || prompt.count > 2000 {
            return .opus
        }
        let codeMarkers = ["```", "func ", "class ", "{"]
        if codeMarkers.contains(where: { prompt.contains($0) }) || prompt.count >= 280 {
            return .sonnet
        }
        return .haiku
    }

    public func isSimpleTask(outputTokens: Int, contextTokens: Int, previewLength: Int) -> Bool {
        outputTokens < 400 && contextTokens < 3000 && previewLength < 200
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter ComplexityHeuristicsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatchCore/ComplexityHeuristics.swift Tests/TokenWatchCoreTests/ComplexityHeuristicsTests.swift
git commit -m "feat: add ComplexityHeuristics shared signal"
```

---

### Task 7: OverkillDetector

**Files:**
- Create: `Sources/TokenWatchCore/OverkillDetector.swift`
- Test: `Tests/TokenWatchCoreTests/OverkillDetectorTests.swift`

**Interfaces:**
- Consumes: `UsageRecord`, `CostEngine`, `ComplexityHeuristics`, `ModelTier`
- Produces:
```swift
public struct OverkillResult: Equatable {
    public let isOverkill: Bool
    public let overpay: Double        // actual cost - haiku-equivalent cost (>= 0)
}
public struct OverkillDetector {
    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                haikuModelId: String = "claude-haiku-4-5",
                expensiveModelSubstrings: [String] = ["opus", "sonnet"])
    public func evaluate(_ record: UsageRecord) -> OverkillResult
}
```

**Rule:** overkill when `isSimpleTask(outputTokens, contextTokens = inputTokens + cacheReadTokens,
previewLength)` is true AND the model name contains an expensive substring. `overpay =
max(0, actualCost - costAsHaiku)`.

- [ ] **Step 1: Write the failing tests**

`Tests/TokenWatchCoreTests/OverkillDetectorTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class OverkillDetectorTests: XCTestCase {
    func makeDetector() -> OverkillDetector {
        let rates = [
            "claude-opus-4-8":  Rates(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
            "claude-haiku-4-5": Rates(input: 1.0,  output: 5.0,  cacheWrite: 1.25,  cacheRead: 0.1),
        ]
        let engine = CostEngine(pricing: PricingTable(rates: rates,
            defaultRates: Rates(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3)))
        return OverkillDetector(costEngine: engine)
    }

    func testSimpleTaskOnOpusIsOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-opus-4-8",
                            inputTokens: 200, outputTokens: 50, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "rename var", project: "p")
        let result = makeDetector().evaluate(r)
        XCTAssertTrue(result.isOverkill)
        XCTAssertGreaterThan(result.overpay, 0)
    }

    func testBigTaskOnOpusIsNotOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-opus-4-8",
                            inputTokens: 50_000, outputTokens: 5_000, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "big refactor", project: "p")
        XCTAssertFalse(makeDetector().evaluate(r).isOverkill)
    }

    func testSimpleTaskOnHaikuIsNotOverkill() {
        let r = UsageRecord(id: nil, timestamp: Date(), model: "claude-haiku-4-5",
                            inputTokens: 200, outputTokens: 50, cacheWriteTokens: 0,
                            cacheReadTokens: 0, promptPreview: "hi", project: "p")
        XCTAssertFalse(makeDetector().evaluate(r).isOverkill)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter OverkillDetectorTests`
Expected: FAIL — `OverkillDetector` not found.

- [ ] **Step 3: Implement**

`Sources/TokenWatchCore/OverkillDetector.swift`:
```swift
import Foundation

public struct OverkillResult: Equatable {
    public let isOverkill: Bool
    public let overpay: Double
    public init(isOverkill: Bool, overpay: Double) {
        self.isOverkill = isOverkill; self.overpay = overpay
    }
}

public struct OverkillDetector {
    public let costEngine: CostEngine
    public let heuristics: ComplexityHeuristics
    public let haikuModelId: String
    public let expensiveModelSubstrings: [String]

    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                haikuModelId: String = "claude-haiku-4-5",
                expensiveModelSubstrings: [String] = ["opus", "sonnet"]) {
        self.costEngine = costEngine
        self.heuristics = heuristics
        self.haikuModelId = haikuModelId
        self.expensiveModelSubstrings = expensiveModelSubstrings
    }

    public func evaluate(_ record: UsageRecord) -> OverkillResult {
        let modelLower = record.model.lowercased()
        let expensive = expensiveModelSubstrings.contains { modelLower.contains($0) }
        let simple = heuristics.isSimpleTask(
            outputTokens: record.outputTokens,
            contextTokens: record.inputTokens + record.cacheReadTokens,
            previewLength: record.promptPreview.count)

        guard expensive && simple else { return OverkillResult(isOverkill: false, overpay: 0) }

        let actual = costEngine.cost(for: record)
        let asHaiku = costEngine.cost(inputTokens: record.inputTokens,
                                      outputTokens: record.outputTokens,
                                      cacheWriteTokens: record.cacheWriteTokens,
                                      cacheReadTokens: record.cacheReadTokens,
                                      model: haikuModelId)
        return OverkillResult(isOverkill: true, overpay: max(0, actual - asHaiku))
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter OverkillDetectorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatchCore/OverkillDetector.swift Tests/TokenWatchCoreTests/OverkillDetectorTests.swift
git commit -m "feat: add OverkillDetector with overpay estimate"
```

---

### Task 8: Advisor

**Files:**
- Create: `Sources/TokenWatchCore/Advisor.swift`
- Test: `Tests/TokenWatchCoreTests/AdvisorTests.swift`

**Interfaces:**
- Consumes: `ComplexityHeuristics`, `ModelTier`, `CostEngine`, `PricingTable`
- Produces:
```swift
public struct Recommendation: Equatable {
    public let tier: ModelTier
    public let modelId: String        // e.g. "claude-haiku-4-5"
    public let cliAlias: String       // "haiku" | "sonnet" | "opus"
    public let estimatedCost: Double  // for a typical prompt+response
}
public struct Advisor {
    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                assumedOutputTokens: Int = 500)
    public func recommend(prompt: String) -> Recommendation
    public func runCommand(prompt: String, alias: String) -> [String]  // ["claude","-p",prompt,"--model",alias]
}
```

**Tier → model mapping:** `.haiku` → (`claude-haiku-4-5`, `haiku`), `.sonnet` →
(`claude-sonnet-5`, `sonnet`), `.opus` → (`claude-opus-4-8`, `opus`). Estimated cost uses
`inputTokens = prompt.count / 4` and `outputTokens = assumedOutputTokens` through CostEngine.

- [ ] **Step 1: Write the failing tests**

`Tests/TokenWatchCoreTests/AdvisorTests.swift`:
```swift
import XCTest
@testable import TokenWatchCore

final class AdvisorTests: XCTestCase {
    func makeAdvisor() -> Advisor {
        Advisor(costEngine: CostEngine(pricing: PricingTable.bundled()))
    }

    func testRecommendsHaikuForSimplePrompt() {
        let rec = makeAdvisor().recommend(prompt: "rename this variable")
        XCTAssertEqual(rec.tier, .haiku)
        XCTAssertEqual(rec.modelId, "claude-haiku-4-5")
        XCTAssertEqual(rec.cliAlias, "haiku")
        XCTAssertGreaterThan(rec.estimatedCost, 0)
    }

    func testRecommendsOpusForHardPrompt() {
        XCTAssertEqual(makeAdvisor().recommend(prompt: "refactor the module").tier, .opus)
    }

    func testRunCommandShape() {
        let cmd = makeAdvisor().runCommand(prompt: "do a thing", alias: "haiku")
        XCTAssertEqual(cmd, ["claude", "-p", "do a thing", "--model", "haiku"])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter AdvisorTests`
Expected: FAIL — `Advisor` not found.

- [ ] **Step 3: Implement**

`Sources/TokenWatchCore/Advisor.swift`:
```swift
import Foundation

public struct Recommendation: Equatable {
    public let tier: ModelTier
    public let modelId: String
    public let cliAlias: String
    public let estimatedCost: Double
    public init(tier: ModelTier, modelId: String, cliAlias: String, estimatedCost: Double) {
        self.tier = tier; self.modelId = modelId; self.cliAlias = cliAlias
        self.estimatedCost = estimatedCost
    }
}

public struct Advisor {
    public let costEngine: CostEngine
    public let heuristics: ComplexityHeuristics
    public let assumedOutputTokens: Int

    public init(costEngine: CostEngine,
                heuristics: ComplexityHeuristics = ComplexityHeuristics(),
                assumedOutputTokens: Int = 500) {
        self.costEngine = costEngine
        self.heuristics = heuristics
        self.assumedOutputTokens = assumedOutputTokens
    }

    private func ids(for tier: ModelTier) -> (modelId: String, alias: String) {
        switch tier {
        case .haiku:  return ("claude-haiku-4-5", "haiku")
        case .sonnet: return ("claude-sonnet-5", "sonnet")
        case .opus:   return ("claude-opus-4-8", "opus")
        }
    }

    public func recommend(prompt: String) -> Recommendation {
        let tier = heuristics.recommend(prompt: prompt)
        let (modelId, alias) = ids(for: tier)
        let cost = costEngine.cost(inputTokens: prompt.count / 4,
                                   outputTokens: assumedOutputTokens,
                                   cacheWriteTokens: 0, cacheReadTokens: 0, model: modelId)
        return Recommendation(tier: tier, modelId: modelId, cliAlias: alias, estimatedCost: cost)
    }

    public func runCommand(prompt: String, alias: String) -> [String] {
        ["claude", "-p", prompt, "--model", alias]
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter AdvisorTests`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `swift test`
Expected: all core tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/TokenWatchCore/Advisor.swift Tests/TokenWatchCoreTests/AdvisorTests.swift
git commit -m "feat: add heuristic Advisor with cost estimate and run command"
```

---

### Task 9: FileWatcher (directory change notifications)

**Files:**
- Create: `Sources/TokenWatch/FileWatcher.swift`

**Interfaces:**
- Produces:
```swift
final class FileWatcher {
    init(path: String, onChange: @escaping () -> Void)
    func start()
    func stop()
}
```

**Note:** This is UI-target infrastructure, verified manually via the running app in Task 12
(no unit test — it wraps a system `DispatchSource`). Watches the directory; coalesces bursts
with a short debounce.

- [ ] **Step 1: Implement FileWatcher**

`Sources/TokenWatch/FileWatcher.swift`:
```swift
import Foundation

final class FileWatcher {
    private let path: String
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var debounce: DispatchWorkItem?

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global())
        src.setEventHandler { [weak self] in self?.scheduleChange() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
        }
        source = src
        src.resume()
    }

    private func scheduleChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/TokenWatch/FileWatcher.swift
git commit -m "feat: add debounced directory FileWatcher"
```

---

### Task 10: UsageStore (pipeline + observable state)

**Files:**
- Create: `Sources/TokenWatch/UsageStore.swift`

**Interfaces:**
- Consumes: `TokenWatchCore` (LogParser, CostEngine, OverkillDetector, Advisor, PricingTable), `FileWatcher`
- Produces:
```swift
struct HistoryItem: Identifiable {
    let id: String
    let record: UsageRecord
    let cost: Double
    let isOverkill: Bool
    let overpay: Double
}
@MainActor
final class UsageStore: ObservableObject {
    @Published var monthToDateText: String   // e.g. "$47.80" or "—"
    @Published var history: [HistoryItem]     // newest first
    @Published var totalOverpay: Double
    let advisor: Advisor
    init(rootPath: String = NSString(string: "~/.claude/projects").expandingTildeInPath)
    func refresh()
    func startWatching()
}
```

- [ ] **Step 1: Implement UsageStore**

`Sources/TokenWatch/UsageStore.swift`:
```swift
import Foundation
import Combine
import TokenWatchCore

struct HistoryItem: Identifiable {
    let id: String
    let record: UsageRecord
    let cost: Double
    let isOverkill: Bool
    let overpay: Double
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var monthToDateText: String = "—"
    @Published var history: [HistoryItem] = []
    @Published var totalOverpay: Double = 0

    let advisor: Advisor
    private let rootPath: String
    private let parser = LogParser()
    private let costEngine: CostEngine
    private let detector: OverkillDetector
    private var watcher: FileWatcher?

    init(rootPath: String = NSString(string: "~/.claude/projects").expandingTildeInPath) {
        self.rootPath = rootPath
        let pricing = PricingTable.bundled()
        self.costEngine = CostEngine(pricing: pricing)
        self.detector = OverkillDetector(costEngine: costEngine)
        self.advisor = Advisor(costEngine: costEngine)
        refresh()
    }

    func startWatching() {
        watcher = FileWatcher(path: rootPath) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        watcher?.start()
    }

    func refresh() {
        let records = loadAllRecords()
        let cal = Calendar.current
        let mtd = costEngine.monthToDateTotal(records, now: Date(), calendar: cal)
        monthToDateText = String(format: "$%.2f", mtd)

        var items: [HistoryItem] = []
        var overpaySum = 0.0
        for r in records {
            let res = detector.evaluate(r)
            overpaySum += res.overpay
            items.append(HistoryItem(id: r.id ?? UUID().uuidString, record: r,
                                     cost: costEngine.cost(for: r),
                                     isOverkill: res.isOverkill, overpay: res.overpay))
        }
        history = items.sorted { $0.record.timestamp > $1.record.timestamp }
        totalOverpay = overpaySum
    }

    private func loadAllRecords() -> [UsageRecord] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: rootPath) else { return [] }
        var records: [UsageRecord] = []
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            let full = (rootPath as NSString).appendingPathComponent(rel)
            if let contents = try? String(contentsOfFile: full, encoding: .utf8) {
                records += parser.parse(fileContents: contents, project: "unknown")
            }
        }
        return records
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/TokenWatch/UsageStore.swift
git commit -m "feat: add UsageStore pipeline with month-to-date and overkill totals"
```

---

### Task 11: Menu bar app bootstrap (NSStatusItem)

**Files:**
- Modify/replace: `Sources/TokenWatch/main.swift`
- Create: `Sources/TokenWatch/AppDelegate.swift`
- Create: `Sources/TokenWatch/Views/RootView.swift` (minimal placeholder; tabs added in Task 12)

**Interfaces:**
- Consumes: `UsageStore`
- Produces: a running menu bar app whose status item title tracks `store.monthToDateText`.

- [ ] **Step 1: Replace main.swift with the NSApplication bootstrap**

`Sources/TokenWatch/main.swift`:
```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
app.run()
```

- [ ] **Step 2: Implement AppDelegate**

`Sources/TokenWatch/AppDelegate.swift`:
```swift
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = UsageStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "TokenWatch")
            button.imagePosition = .imageLeading
            button.title = " " + store.monthToDateText
            button.action = #selector(togglePopover)
            button.target = self
        }

        store.$monthToDateText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.statusItem.button?.title = " " + text }
            .store(in: &cancellables)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 460)
        popover.contentViewController = NSHostingController(rootView: RootView().environmentObject(store))

        store.startWatching()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 3: Add a minimal RootView placeholder**

`Sources/TokenWatch/Views/RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TokenWatch").font(.headline)
            Text("Month to date: \(store.monthToDateText)")
            Text("Requests: \(store.history.count)")
        }
        .padding()
        .frame(width: 380, height: 460, alignment: .topLeading)
    }
}
```

- [ ] **Step 4: Build and run manually on the Mac**

Run: `swift build` then `swift run TokenWatch`
Expected: an eye icon + dollar figure appears in the menu bar; clicking shows the placeholder popover. (If `~/.claude/projects` has logs, the figure is non-zero.)

- [ ] **Step 5: Commit**

```bash
git add Sources/TokenWatch/main.swift Sources/TokenWatch/AppDelegate.swift Sources/TokenWatch/Views/RootView.swift
git commit -m "feat: add menu bar app with live month-to-date status item"
```

---

### Task 12: Popover UI — History, Stats, Advisor tabs

**Files:**
- Modify: `Sources/TokenWatch/Views/RootView.swift`
- Create: `Sources/TokenWatch/Views/HistoryView.swift`
- Create: `Sources/TokenWatch/Views/StatsView.swift`
- Create: `Sources/TokenWatch/Views/AdvisorView.swift`

**Interfaces:**
- Consumes: `UsageStore`, `HistoryItem`, `Advisor`, `Recommendation`, `ModelTier`

- [ ] **Step 1: Implement the tab container**

`Sources/TokenWatch/Views/RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        TabView {
            HistoryView().tabItem { Text("History") }
            StatsView().tabItem { Text("Stats") }
            AdvisorView().tabItem { Text("Advisor") }
        }
        .frame(width: 380, height: 460)
        .padding(.top, 4)
    }
}
```

- [ ] **Step 2: Implement HistoryView**

`Sources/TokenWatch/Views/HistoryView.swift`:
```swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading) {
            Text("Month to date: \(store.monthToDateText)").font(.headline).padding(.horizontal)
            List(store.history) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(shortModel(item.record.model)).bold()
                        Text(String(format: "$%.4f", item.cost)).foregroundColor(.secondary)
                        if item.isOverkill {
                            Text("⚠️ overkill −$\(String(format: "%.4f", item.overpay))")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                    Text("\(item.record.inputTokens)→\(item.record.outputTokens) tok")
                        .font(.caption).foregroundColor(.secondary)
                    if !item.record.promptPreview.isEmpty {
                        Text(item.record.promptPreview).font(.caption).lineLimit(1)
                    }
                }
            }
        }
    }
    private func shortModel(_ m: String) -> String {
        if m.contains("opus") { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku") { return "Haiku" }
        return m
    }
}
```

- [ ] **Step 3: Implement StatsView**

`Sources/TokenWatch/Views/StatsView.swift`:
```swift
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistics").font(.headline)
            Text("Month to date: \(store.monthToDateText)")
            Text("Requests this session: \(store.history.count)")
            Text(String(format: "Overkill overpay: $%.4f", store.totalOverpay))
                .foregroundColor(.orange)
            Divider()
            Text("By model").font(.subheadline).bold()
            ForEach(byModel(), id: \.0) { name, cost in
                HStack { Text(name); Spacer(); Text(String(format: "$%.4f", cost)) }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func byModel() -> [(String, Double)] {
        var totals: [String: Double] = [:]
        for item in store.history { totals[item.record.model, default: 0] += item.cost }
        return totals.sorted { $0.value > $1.value }
    }
}
```

- [ ] **Step 4: Implement AdvisorView**

`Sources/TokenWatch/Views/AdvisorView.swift`:
```swift
import SwiftUI
import AppKit
import TokenWatchCore

struct AdvisorView: View {
    @EnvironmentObject var store: UsageStore
    @State private var prompt: String = ""
    @State private var recommendation: Recommendation?
    @State private var runOutput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Advisor").font(.headline)
            TextEditor(text: $prompt)
                .frame(height: 120)
                .border(Color.gray.opacity(0.3))
            Button("Recommend") { recommendation = store.advisor.recommend(prompt: prompt) }
            if let rec = recommendation {
                HStack {
                    Text(chip(rec.tier)).bold()
                    Text(String(format: "~$%.4f", rec.estimatedCost)).foregroundColor(.secondary)
                }
                Button("Run in Claude Code") { run(rec) }
            }
            if !runOutput.isEmpty {
                ScrollView { Text(runOutput).font(.system(.caption, design: .monospaced)) }
                    .frame(maxHeight: 120)
            }
            Spacer()
        }
        .padding()
    }

    private func chip(_ tier: ModelTier) -> String {
        switch tier {
        case .haiku:  return "🟢 Haiku"
        case .sonnet: return "🟡 Sonnet"
        case .opus:   return "🔴 Opus"
        }
    }

    private func run(_ rec: Recommendation) {
        let args = store.advisor.runCommand(prompt: prompt, alias: rec.cliAlias)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            runOutput = String(data: data, encoding: .utf8) ?? ""
        } catch {
            runOutput = "Could not launch `claude`. Is Claude Code installed and on PATH?\n\(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 5: Build and run manually on the Mac**

Run: `swift run TokenWatch`
Expected: popover shows three working tabs. History lists requests with overkill badges;
Stats shows totals and by-model breakdown; Advisor recommends a tier and, if `claude` is on
PATH, runs it and shows output.

- [ ] **Step 6: Commit**

```bash
git add Sources/TokenWatch/Views
git commit -m "feat: add History, Stats, and Advisor popover tabs"
```

---

### Task 13: README + full-suite verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

`README.md`:
```markdown
# TokenWatch

A native macOS menu bar app that tracks AI coding spend by reading Claude Code's
local usage logs (`~/.claude/projects/**/*.jsonl`). Fully offline — no API keys, no network.

## Features
- Month-to-date spend in the menu bar
- Request history with model, cost, tokens, and prompt preview
- "Overkill" alerts: an expensive model used on a simple task, with estimated overpay
- Model Advisor: paste a prompt → recommended cheapest adequate model → run via `claude -p`

## Requirements
- macOS 13+
- Xcode 15+ (Swift 5.9)
- Claude Code installed (for the Advisor "Run" action)

## Build & Run
Open `Package.swift` in Xcode and press Run, or from a terminal:
```
swift run TokenWatch
```

## Test
```
swift test
```

## Pricing
Rates live in `Sources/TokenWatchCore/Resources/pricing.json` (per 1,000,000 tokens).
Edit them to match current model pricing.
```

- [ ] **Step 2: Run the full test suite**

Run: `swift test`
Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Self-Review Notes

- **Spec coverage:** menu bar month-to-date (Task 11), history (Task 12/HistoryView), stats
  (Task 12/StatsView), overkill detector (Task 7), advisor + `claude -p` (Task 8/12), local
  JSONL source (Task 5/10), editable pricing.json (Task 3), SwiftPM/Xcode delivery (Task 1),
  unit-tested UI-free core (Tasks 2–8). All spec sections map to a task.
- **Type consistency:** `ModelTier`, `Rates`, `PricingTable`, `CostEngine.cost(inputTokens:…)`,
  `Advisor.runCommand(prompt:alias:)`, `HistoryItem`, `UsageStore.monthToDateText` are used
  identically across tasks.
- **Known limitation to validate on-device:** the exact Claude Code JSONL field names are
  assumed (Task 5). Validate against a real log early; if fields differ, only `LogParser`
  changes — its tests pin the contract.
```
