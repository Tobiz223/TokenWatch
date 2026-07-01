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

The app appears as an eye icon + dollar figure in the menu bar (no Dock icon).

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
