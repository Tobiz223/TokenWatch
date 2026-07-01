#!/usr/bin/env python3
"""
TokenWatch — Windows-testable preview (Python mirror of the Swift TokenWatchCore).

This is a 1:1 port of the Swift core logic (LogParser, CostEngine, OverkillDetector,
ComplexityHeuristics, Advisor) so behaviour can be tested on Windows before the native
macOS/Xcode build. Same thresholds, same formulas, same shared pricing.json.

Runs on Windows/macOS/Linux with only the Python standard library.

Usage:
    py preview/tokenwatch.py status
    py preview/tokenwatch.py history [--limit N]
    py preview/tokenwatch.py stats
    py preview/tokenwatch.py advise "your prompt here"
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# PricingTable  (mirrors Sources/TokenWatchCore/PricingTable.swift)
# ---------------------------------------------------------------------------
FAMILIES = ("opus", "sonnet", "haiku")

DEFAULT_PRICING = {
    "opus":    {"input": 15.0, "output": 75.0, "cacheWrite": 18.75, "cacheRead": 1.5},
    "sonnet":  {"input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3},
    "haiku":   {"input": 1.0,  "output": 5.0,  "cacheWrite": 1.25,  "cacheRead": 0.1},
    "default": {"input": 3.0,  "output": 15.0, "cacheWrite": 3.75,  "cacheRead": 0.3},
}


def _pricing_json_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "..", "Sources", "TokenWatchCore", "Resources", "pricing.json")


class PricingTable:
    def __init__(self, rates: dict):
        self.default = rates.get("default", DEFAULT_PRICING["default"])
        self.rates = {k: v for k, v in rates.items() if k != "default"}

    @classmethod
    def load(cls) -> "PricingTable":
        path = _pricing_json_path()
        try:
            with open(path, encoding="utf-8") as fh:
                return cls(json.load(fh))
        except (OSError, json.JSONDecodeError):
            return cls(dict(DEFAULT_PRICING))

    @staticmethod
    def family_key(model: str):
        m = model.lower()
        for fam in FAMILIES:
            if fam in m:
                return fam
        return None

    def rates_for(self, model: str) -> dict:
        if model in self.rates:
            return self.rates[model]
        fam = self.family_key(model)
        if fam and fam in self.rates:
            return self.rates[fam]
        return self.default

    def is_known(self, model: str) -> bool:
        if model in self.rates:
            return True
        fam = self.family_key(model)
        return bool(fam and fam in self.rates)


# ---------------------------------------------------------------------------
# UsageRecord  (mirrors Sources/TokenWatchCore/UsageRecord.swift)
# ---------------------------------------------------------------------------
@dataclass
class UsageRecord:
    id: str | None
    timestamp: datetime
    model: str
    input_tokens: int
    output_tokens: int
    cache_write_tokens: int
    cache_read_tokens: int
    prompt_preview: str
    project: str


# ---------------------------------------------------------------------------
# CostEngine  (mirrors Sources/TokenWatchCore/CostEngine.swift)
# ---------------------------------------------------------------------------
class CostEngine:
    def __init__(self, pricing: PricingTable):
        self.pricing = pricing

    def cost_tokens(self, input_tokens, output_tokens, cache_write, cache_read, model) -> float:
        r = self.pricing.rates_for(model)
        raw = (input_tokens * r["input"]
               + output_tokens * r["output"]
               + cache_write * r["cacheWrite"]
               + cache_read * r["cacheRead"])
        return raw / 1_000_000.0

    def cost(self, rec: UsageRecord) -> float:
        return self.cost_tokens(rec.input_tokens, rec.output_tokens,
                                rec.cache_write_tokens, rec.cache_read_tokens, rec.model)

    def total(self, records) -> float:
        return sum(self.cost(r) for r in records)

    def month_to_date_total(self, records, now: datetime) -> float:
        return sum(self.cost(r) for r in records
                   if r.timestamp.year == now.year and r.timestamp.month == now.month)


# ---------------------------------------------------------------------------
# LogParser  (mirrors Sources/TokenWatchCore/LogParser.swift)
# ---------------------------------------------------------------------------
class LogParser:
    def __init__(self, preview_limit: int = 80):
        self.preview_limit = preview_limit

    def parse_lines(self, lines, project: str):
        out = []
        last_preview = ""
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(obj, dict):
                continue

            typ = obj.get("type")
            message = obj.get("message")

            if typ == "user" and isinstance(message, dict):
                last_preview = self._extract_preview(message.get("content"))
                continue

            if typ != "assistant" or not isinstance(message, dict):
                continue
            usage = message.get("usage")
            model = message.get("model")
            if not isinstance(usage, dict) or not isinstance(model, str):
                continue
            if model.startswith("<"):   # skip Claude Code synthetic messages
                continue

            out.append(UsageRecord(
                id=message.get("id"),
                timestamp=self._parse_date(obj.get("timestamp")),
                model=model,
                input_tokens=self._int(usage, "input_tokens"),
                output_tokens=self._int(usage, "output_tokens"),
                cache_write_tokens=self._int(usage, "cache_creation_input_tokens"),
                cache_read_tokens=self._int(usage, "cache_read_input_tokens"),
                prompt_preview=last_preview,
                project=self._project(obj.get("cwd"), project),
            ))
        return out

    def parse_file(self, path: str, project: str):
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                return self.parse_lines(fh, project)
        except OSError:
            return []

    @staticmethod
    def _int(d: dict, key: str) -> int:
        v = d.get(key, 0)
        return int(v) if isinstance(v, (int, float)) else 0

    @staticmethod
    def _parse_date(s):
        if not isinstance(s, str):
            return datetime.now(timezone.utc)
        try:
            return datetime.fromisoformat(s.replace("Z", "+00:00"))
        except ValueError:
            return datetime.now(timezone.utc)

    @staticmethod
    def _project(cwd, fallback: str) -> str:
        if isinstance(cwd, str) and cwd:
            return os.path.basename(cwd.replace("\\", "/").rstrip("/"))
        return fallback

    def _extract_preview(self, content) -> str:
        text = ""
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            text = " ".join(part.get("text", "") for part in content
                            if isinstance(part, dict) and isinstance(part.get("text"), str))
        text = text.strip()
        if len(text) > self.preview_limit:
            return text[:self.preview_limit] + "…"
        return text


# ---------------------------------------------------------------------------
# ComplexityHeuristics  (mirrors Sources/TokenWatchCore/ComplexityHeuristics.swift)
# ---------------------------------------------------------------------------
HARD_KEYWORDS = ["refactor", "architecture", "debug", "design", "prove",
                 "optimize", "concurrency", "security", "migrate", "threading"]
CODE_MARKERS = ["```", "func ", "class ", "{"]


class ComplexityHeuristics:
    def recommend(self, prompt: str) -> str:
        lower = prompt.lower()
        if any(k in lower for k in HARD_KEYWORDS) or len(prompt) > 2000:
            return "opus"
        if any(marker in prompt for marker in CODE_MARKERS) or len(prompt) >= 280:
            return "sonnet"
        return "haiku"

    def is_simple_task(self, output_tokens, context_tokens, preview_length) -> bool:
        return output_tokens < 400 and context_tokens < 3000 and preview_length < 200


# ---------------------------------------------------------------------------
# OverkillDetector  (mirrors Sources/TokenWatchCore/OverkillDetector.swift)
# ---------------------------------------------------------------------------
class OverkillDetector:
    def __init__(self, cost_engine: CostEngine, heuristics: ComplexityHeuristics,
                 haiku_model_id="claude-haiku-4-5", expensive=("opus", "sonnet")):
        self.cost_engine = cost_engine
        self.heuristics = heuristics
        self.haiku_model_id = haiku_model_id
        self.expensive = expensive

    def evaluate(self, rec: UsageRecord):
        model_lower = rec.model.lower()
        is_expensive = any(sub in model_lower for sub in self.expensive)
        is_simple = self.heuristics.is_simple_task(
            rec.output_tokens, rec.input_tokens + rec.cache_read_tokens, len(rec.prompt_preview))
        if not (is_expensive and is_simple):
            return (False, 0.0)
        actual = self.cost_engine.cost(rec)
        as_haiku = self.cost_engine.cost_tokens(
            rec.input_tokens, rec.output_tokens, rec.cache_write_tokens,
            rec.cache_read_tokens, self.haiku_model_id)
        return (True, max(0.0, actual - as_haiku))


# ---------------------------------------------------------------------------
# Advisor  (mirrors Sources/TokenWatchCore/Advisor.swift)
# ---------------------------------------------------------------------------
TIER_IDS = {
    "haiku": ("claude-haiku-4-5", "haiku"),
    "sonnet": ("claude-sonnet-5", "sonnet"),
    "opus": ("claude-opus-4-8", "opus"),
}


class Advisor:
    def __init__(self, cost_engine: CostEngine, heuristics: ComplexityHeuristics,
                 assumed_output_tokens=500):
        self.cost_engine = cost_engine
        self.heuristics = heuristics
        self.assumed_output_tokens = assumed_output_tokens

    def recommend(self, prompt: str):
        tier = self.heuristics.recommend(prompt)
        model_id, alias = TIER_IDS[tier]
        cost = self.cost_engine.cost_tokens(
            len(prompt) // 4, self.assumed_output_tokens, 0, 0, model_id)
        return {"tier": tier, "model_id": model_id, "alias": alias, "estimated_cost": cost}

    def run_command(self, prompt: str, alias: str):
        return ["claude", "-p", prompt, "--model", alias]


# ---------------------------------------------------------------------------
# Store / loading  (mirrors Sources/TokenWatch/UsageStore.swift)
# ---------------------------------------------------------------------------
def default_root() -> str:
    return os.path.expanduser(os.path.join("~", ".claude", "projects"))


def load_all_records(root: str, parser: LogParser):
    records = []
    for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        records += parser.parse_file(path, "unknown")
    return records


def short_model(m: str) -> str:
    if "opus" in m:
        return "Opus"
    if "sonnet" in m:
        return "Sonnet"
    if "haiku" in m:
        return "Haiku"
    return m


class TokenWatch:
    def __init__(self, root: str | None = None):
        self.root = root or default_root()
        self.pricing = PricingTable.load()
        self.cost_engine = CostEngine(self.pricing)
        self.heuristics = ComplexityHeuristics()
        self.detector = OverkillDetector(self.cost_engine, self.heuristics)
        self.advisor = Advisor(self.cost_engine, self.heuristics)
        self.parser = LogParser()

    def records(self):
        recs = load_all_records(self.root, self.parser)
        recs.sort(key=lambda r: r.timestamp, reverse=True)
        return recs


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def cmd_status(tw: TokenWatch, _args):
    recs = tw.records()
    mtd = tw.cost_engine.month_to_date_total(recs, datetime.now(timezone.utc))
    print(f"👁  TokenWatch — month to date: ${mtd:.2f}   ({len(recs)} requests total)")


def cmd_history(tw: TokenWatch, args):
    recs = tw.records()[: args.limit]
    if not recs:
        print("No requests found in", tw.root)
        return
    for r in recs:
        is_over, overpay = tw.detector.evaluate(r)
        cost = tw.cost_engine.cost(r)
        flag = f"  ⚠️ overkill -${overpay:.4f}" if is_over else ""
        when = r.timestamp.astimezone().strftime("%m-%d %H:%M")
        preview = (r.prompt_preview[:48] + "…") if len(r.prompt_preview) > 48 else r.prompt_preview
        print(f"{when}  {short_model(r.model):6}  ${cost:8.4f}  "
              f"{r.input_tokens:>7}->{r.output_tokens:<6} tok  {preview}{flag}")


def cmd_stats(tw: TokenWatch, _args):
    recs = tw.records()
    now = datetime.now(timezone.utc)
    mtd = tw.cost_engine.month_to_date_total(recs, now)
    total = tw.cost_engine.total(recs)
    by_model: dict[str, float] = {}
    overpay_sum = 0.0
    overkill_count = 0
    for r in recs:
        by_model[r.model] = by_model.get(r.model, 0.0) + tw.cost_engine.cost(r)
        is_over, overpay = tw.detector.evaluate(r)
        if is_over:
            overkill_count += 1
            overpay_sum += overpay
    print("=== TokenWatch Stats ===")
    print(f"Requests (all time): {len(recs)}")
    print(f"Month to date:       ${mtd:.2f}")
    print(f"All time:            ${total:.2f}")
    print(f"Overkill requests:   {overkill_count}  (overpay ${overpay_sum:.4f})")
    print("\nBy model:")
    for model, cost in sorted(by_model.items(), key=lambda kv: kv[1], reverse=True):
        print(f"  {short_model(model):8} ({model:20}) ${cost:.4f}")


def cmd_advise(tw: TokenWatch, args):
    prompt = args.prompt
    rec = tw.advisor.recommend(prompt)
    emoji = {"haiku": "🟢", "sonnet": "🟡", "opus": "🔴"}[rec["tier"]]
    print(f"{emoji} Recommended: {rec['tier'].upper()}  ({rec['model_id']})")
    print(f"   Estimated cost: ~${rec['estimated_cost']:.4f}")
    print(f"   Run: {' '.join(tw.advisor.run_command(prompt, rec['alias']))}")


def main(argv=None):
    # Windows consoles often default to cp1251/cp866 which cannot encode emoji.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    p = argparse.ArgumentParser(description="TokenWatch — Windows preview")
    p.add_argument("--root", help="override logs root (default ~/.claude/projects)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    h = sub.add_parser("history")
    h.add_argument("--limit", type=int, default=20)
    sub.add_parser("stats")
    a = sub.add_parser("advise")
    a.add_argument("prompt")

    args = p.parse_args(argv)
    tw = TokenWatch(root=args.root)
    {"status": cmd_status, "history": cmd_history,
     "stats": cmd_stats, "advise": cmd_advise}[args.cmd](tw, args)


if __name__ == "__main__":
    sys.exit(main())
