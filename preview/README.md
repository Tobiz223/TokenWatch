# TokenWatch — Windows Preview (Python)

This folder is a **Windows-testable preview** of TokenWatch. It is a dependency-free
Python mirror of the Swift `TokenWatchCore` logic, so you can run and validate the real
behaviour on Windows **before** the native macOS/Xcode build.

The Swift version under `../Sources/` remains the final product (menu bar app for macOS).
This preview exists only to test the logic and read real Claude Code logs on Windows.

## Requirements
- Python 3.10+ (on Windows use the `py` launcher — the bare `python` command is a
  Microsoft Store stub and won't work).
- No pip packages. Standard library only.

## Run against your real Claude Code logs (`~/.claude/projects`)

```bash
py preview/tokenwatch.py status                       # month-to-date spend + request count
py preview/tokenwatch.py stats                        # totals, by-model breakdown, overkill overpay
py preview/tokenwatch.py history --limit 20           # recent requests with cost + overkill flags
py preview/tokenwatch.py advise "refactor the auth"   # recommend cheapest adequate model
```

Point it at a different logs folder with `--root`:

```bash
py preview/tokenwatch.py --root "C:\path\to\logs" status
```

## Run the tests

```bash
py preview/test_tokenwatch.py
```

19 tests mirror the Swift XCTest suite (pricing, cost, parsing, heuristics, overkill, advisor).

## Swift ↔ Python mapping (for the Xcode port)

Every Python class maps 1:1 to a Swift file. Same thresholds, same formulas, same
shared `../Sources/TokenWatchCore/Resources/pricing.json`.

| Python (`tokenwatch.py`) | Swift (`Sources/TokenWatchCore/`) |
|---|---|
| `PricingTable`          | `PricingTable.swift`         |
| `UsageRecord`           | `UsageRecord.swift`          |
| `CostEngine`            | `CostEngine.swift`           |
| `LogParser`             | `LogParser.swift`            |
| `ComplexityHeuristics`  | `ComplexityHeuristics.swift` |
| `OverkillDetector`      | `OverkillDetector.swift`     |
| `Advisor`               | `Advisor.swift`              |
| `TokenWatch` (store)    | `Sources/TokenWatch/UsageStore.swift` |
| CLI (`cmd_*`)           | `Sources/TokenWatch/Views/*` (menu bar UI) |

When porting changes: keep both sides in step. Thresholds live in `ComplexityHeuristics`
(hard keywords, code markers, simple-task limits) and pricing lives in the shared JSON.

## Verified on real data (Windows)
Running `stats` against a real `~/.claude/projects` parsed 3,800+ requests across
Opus/Sonnet/Haiku, computed month-to-date and all-time spend, and flagged overkill
requests — confirming the core logic works end-to-end before the Swift build.
