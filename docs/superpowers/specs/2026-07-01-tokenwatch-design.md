# TokenWatch v1 — Design Spec

**Date:** 2026-07-01
**Status:** Approved (design), pending spec review
**Platform:** macOS (native), developed on Windows, tested on Mac Mini via Xcode

## 1. Summary

TokenWatch is a native macOS **menu bar app** that tracks AI coding spend by reading
Claude Code's local usage logs. It shows request **history**, **spend statistics**, and
**"overkill" alerts** (an expensive model used on a simple task), plus a **model advisor**
that recommends the cheapest adequate model for a given prompt and can launch it via
`claude -p`.

The v1 data source is **Claude Code local logs only** — fully offline, private, zero
integrations. Other providers (Cursor, ChatGPT, OpenAI, Anthropic API keys) are explicitly
out of scope for v1.

### Why Claude Code logs only

Claude Code writes JSONL logs at `~/.claude/projects/**/*.jsonl` containing exact per-request
token counts and the model used. This gives accurate, real-time cost tracking with no API
keys and no network access. Subscription tools (ChatGPT Plus, Claude Pro/Max) are flat-fee
and have no per-token billing, so "real-time spend" does not apply to them — the genuine
"surprise bill" pain is usage-based billing, which Claude Code logs capture directly.

## 2. Goals & Non-Goals

### Goals (v1)
- Menu bar shows **month-to-date spend** in dollars, updating in real time.
- History of requests: model, cost, token counts, prompt preview, project, overkill flag.
- Statistics: today / week / month, broken down by model and project, plus total "overkill overpay".
- Overkill detector: flag requests where a simple task used an expensive model.
- Advisor: paste a prompt → local heuristics recommend 🟢 Haiku / 🟡 Sonnet / 🔴 Opus with a
  cost estimate → optional "Run in Claude Code" button that executes `claude -p "<prompt>" --model <X>`.
- Ships as a Swift Package that opens in Xcode and runs (no hand-written `.xcodeproj`).

### Non-Goals (v1 — YAGNI)
- Cursor, ChatGPT, OpenAI, or Anthropic-API-key data sources.
- Cloud sync, accounts, paid tiers / the $3.99 plan.
- LLM-as-judge advisor (Haiku classifier). Heuristics only.
- Controlling an already-open interactive Claude Code session.
- Notifications/alerts beyond in-app flags.

## 3. Architecture

Four isolated, independently testable core modules plus a thin UI shell.

```
┌─────────────────────────────────────────────┐
│  MenuBarApp (SwiftUI + NSStatusItem)          │  ← UI shell
│   • icon + $ month-to-date in the menu bar    │
│   • popover: History / Stats / Advisor tabs    │
└───────────────┬───────────────────────────────┘
                │
   ┌────────────┼───────────────┬──────────────┐
   ▼            ▼               ▼              ▼
LogParser   CostEngine    OverkillDetector  Advisor
```

### 3.1 LogParser
- **Purpose:** turn Claude Code JSONL log lines into structured `UsageRecord` values.
- **Input:** files under `~/.claude/projects/**/*.jsonl`.
- **Output:** `[UsageRecord]` (see Data Model).
- **Behavior:** initial full scan on launch; then a `FileWatcher` (DispatchSource on the
  projects directory) triggers incremental re-parse of changed files for real-time updates.
- **Robustness:** skips malformed/non-usage lines; tolerates unknown fields (schema drift);
  deduplicates by message id if present.
- **Dependencies:** Foundation only. No UI, no network.

### 3.2 CostEngine
- **Purpose:** compute dollar cost per `UsageRecord` and aggregate totals.
- **Input:** `UsageRecord` + a `PricingTable` loaded from bundled `pricing.json`.
- **Output:** per-record cost; aggregates by day / week / month, by model, by project.
- **Pricing:** `pricing.json` maps model id → per-MTok rates for input, output, cache-write,
  cache-read. Editable by the user; unknown models fall back to a configurable default and
  are surfaced as "unknown pricing" rather than silently costing $0.
- **Dependencies:** Foundation only.

### 3.3 OverkillDetector
- **Purpose:** flag requests where a simple task used an expensive model.
- **Rule (v1):** a record is "overkill" when it is classified **simple** (short prompt,
  small output token count, no large context/cache-read) **and** ran on an expensive model
  (Sonnet/Opus tier). Thresholds are constants in one place, easy to tune.
- **Output:** boolean flag + estimated overpay = (actual cost − cost had it run on Haiku).
- **Dependencies:** CostEngine (for the counterfactual Haiku cost), Foundation.

### 3.4 Advisor
- **Purpose:** recommend the cheapest adequate model for a prompt, and optionally run it.
- **Logic (v1, local heuristics):** score prompt on length, presence of code/keywords
  (refactor, debug, architecture, design, prove, etc.), and estimated context size →
  bucket into Haiku / Sonnet / Opus. Same complexity signals as OverkillDetector, shared
  in a single `ComplexityHeuristics` helper to keep them consistent.
- **Run action:** builds and executes `claude -p "<prompt>" --model <id>` via `Process`,
  surfacing stdout/exit status. Gracefully reports if the `claude` binary is not found.
- **Dependencies:** CostEngine (cost estimate), Foundation.

### 3.5 UI shell (MenuBarApp)
- `NSApplication` with `setActivationPolicy(.accessory)` (no Dock icon, no storyboard).
- `NSStatusItem` shows the eye icon + month-to-date dollar figure.
- Clicking opens a SwiftUI popover with three tabs: **History**, **Stats**, **Advisor**.
- Subscribes to a `UsageStore` (ObservableObject) that owns the pipeline and republishes on updates.

## 4. Data Model

```swift
struct UsageRecord {
    let id: String?            // message id if present (for dedup)
    let timestamp: Date
    let model: String          // e.g. "claude-opus-4-8"
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    let promptPreview: String   // first N chars of the user prompt, truncated
    let project: String         // derived from the log path
}

struct PricingTable {           // from pricing.json
    // model id -> per-MTok rates
    struct Rates { let input, output, cacheWrite, cacheRead: Double }
    let rates: [String: Rates]
    let defaultRates: Rates
}
```

`pricing.json` (bundled, editable) — indicative starting values, user-updatable:

```json
{
  "claude-opus-4-8":   { "input": 15.0, "output": 75.0, "cacheWrite": 18.75, "cacheRead": 1.5 },
  "claude-sonnet-5":   { "input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3 },
  "claude-haiku-4-5":  { "input": 1.0,  "output": 5.0,  "cacheWrite": 1.25,  "cacheRead": 0.1 },
  "default":           { "input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3 }
}
```

## 5. Data Flow

1. On launch, `LogParser` scans all JSONL files → `[UsageRecord]`.
2. `CostEngine` prices each record and builds aggregates.
3. `OverkillDetector` flags records and computes overpay.
4. `UsageStore` publishes the current month-to-date total → menu bar label updates.
5. `FileWatcher` detects new log lines → incremental parse → steps 2–4 rerun for the delta.
6. In the Advisor tab, the user's typed prompt runs through `ComplexityHeuristics` → model
   recommendation + cost estimate → optional `claude -p` launch.

## 6. UX

- **Menu bar:** eye icon + `$47.80` (month-to-date). Shows `—` before first parse completes.
- **Popover tabs:**
  - **History** — reverse-chronological rows: `model · $0.12 · 2.3k→800 tok · "fix the login bug…"`,
    with a ⚠️ badge on overkill rows.
  - **Stats** — today / week / month totals; breakdown by model and by project; "overkill overpay: $X".
  - **Advisor** — multiline prompt field → recommended model chip (🟢/🟡/🔴) + estimated cost +
    "Run in Claude Code" button.

## 7. Delivery & Build

- **Swift Package** with an executable target. The user opens `Package.swift` in Xcode on the
  Mac Mini and hits Run. The menu bar app is created programmatically (`NSApplication` +
  `.accessory`), so no `Info.plist`/storyboard/`.xcodeproj` is required — this avoids
  hand-authoring a fragile `.xcodeproj` blind on Windows.
- Public GitHub repo; the user clones and opens it.
- `pricing.json` is bundled as a package resource.

## 8. Testing

- Core modules (LogParser, CostEngine, OverkillDetector, Advisor/ComplexityHeuristics) are
  pure logic with no UI or network dependencies, covered by unit tests runnable via
  `swift test` on the Mac. Fixture JSONL files exercise parsing, pricing, overkill flags,
  and advisor bucketing.
- UI is a thin layer over the tested store and is verified manually on the Mac Mini.

## 9. Risks & Mitigations

- **Developed blind on Windows (no Swift compiler here).** Mitigation: SwiftPM layout that
  opens-and-runs in Xcode; keep files small and idiomatic; the user runs `swift build` /
  `swift test` on the Mac Mini and reports errors to iterate.
- **Claude Code log schema may differ from assumptions.** Mitigation: tolerant parser, dedup
  by id, unknown-field tolerance; validate against a real log on the Mac Mini early.
- **Pricing drift.** Mitigation: editable `pricing.json`; unknown models flagged, not silently free.
- **`claude` binary path/availability.** Mitigation: detect binary, surface a clear message if missing.
```
