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

## Build & Run (macOS)
Open `Package.swift` in Xcode and press Run, or from a terminal:

```
swift run TokenWatch
```

The app appears as an eye icon + dollar figure in the menu bar (no Dock icon).
Click it to open the popover: **Overview** (month-to-date odometer, spend meter,
by-model breakdown, overkill alert), **Receipt** (thermal-receipt request history),
and **Advisor** (recommend the cheapest adequate model + copy the `claude -p` command).

### Make a real double-clickable app
```
bash scripts/build-app.sh
open TokenWatch.app
```
This produces `TokenWatch.app` — a proper menu bar app (`LSUIElement`, no Dock icon)
you can drag to `/Applications`.

## Test

```
swift test
```

## Pricing
Rates live in `Sources/TokenWatchCore/Resources/pricing.json` (per 1,000,000 tokens).
Edit them to match current model pricing.

## Architecture
- `TokenWatchCore` — pure, UI-free, unit-tested logic:
  `LogParser`, `CostEngine`, `OverkillDetector`, `ComplexityHeuristics`, `Advisor`, `PricingTable`.
- `TokenWatch` — thin AppKit/SwiftUI menu bar shell over an observable `UsageStore`.

## Windows prototypes (validate logic without a Mac)
The native macOS app above is the product. Two dependency-free Python mirrors of
`TokenWatchCore` let you test the exact same logic on Windows first — same thresholds,
same formulas, same shared `pricing.json`:

- **CLI** — `py preview/tokenwatch.py stats` (also `status`, `history`, `advise`). See [preview/README.md](preview/README.md).
- **Web dashboard** — `py app/server.py` opens the "Running Meter" UI in a browser; this is
  the design reference the SwiftUI views are ported from.

```bash
py preview/tokenwatch.py stats     # numbers from your real ~/.claude/projects logs
py preview/test_tokenwatch.py      # 19 tests mirroring the Swift XCTest suite
```
