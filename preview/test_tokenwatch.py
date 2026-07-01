#!/usr/bin/env python3
"""Unit tests for the TokenWatch Windows preview — mirrors the Swift XCTest suite.

Run with the standard library only (no pip needed):
    py preview/test_tokenwatch.py
    py -m unittest preview.test_tokenwatch
"""
import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tokenwatch import (  # noqa: E402
    PricingTable, CostEngine, LogParser, ComplexityHeuristics,
    OverkillDetector, Advisor,
)


def make_engine() -> CostEngine:
    return CostEngine(PricingTable({
        "haiku":   {"input": 1.0, "output": 5.0, "cacheWrite": 1.25, "cacheRead": 0.1},
        "opus":    {"input": 15.0, "output": 75.0, "cacheWrite": 18.75, "cacheRead": 1.5},
        "default": {"input": 3.0, "output": 15.0, "cacheWrite": 3.75, "cacheRead": 0.3},
    }))


class PricingTableTests(unittest.TestCase):
    def setUp(self):
        self.t = PricingTable({
            "haiku":   {"input": 1.0, "output": 5.0, "cacheWrite": 1.25, "cacheRead": 0.1},
            "default": {"input": 3.0, "output": 15.0, "cacheWrite": 3.75, "cacheRead": 0.3},
        })

    def test_family_match_for_versioned_id(self):
        # "claude-haiku-4-5-20251001" matches the "haiku" family.
        self.assertEqual(self.t.rates_for("claude-haiku-4-5-20251001")["output"], 5.0)
        self.assertTrue(self.t.is_known("claude-haiku-4-5-20251001"))

    def test_unknown_falls_back_to_default(self):
        self.assertEqual(self.t.rates_for("gpt-4")["input"], 3.0)
        self.assertFalse(self.t.is_known("gpt-4"))

    def test_bundled_loads(self):
        t = PricingTable.load()
        self.assertTrue(t.is_known("claude-opus-4-8"))


class CostEngineTests(unittest.TestCase):
    def test_cost_for_record(self):
        # 1e6 input @ $1 + 1e6 output @ $5 = $6
        p = LogParser()
        recs = p.parse_lines([
            '{"type":"assistant","timestamp":"2026-07-01T10:00:00Z","cwd":"/x/p",'
            '"message":{"id":"m","model":"claude-haiku-4-5","usage":'
            '{"input_tokens":1000000,"output_tokens":1000000}}}'
        ], "p")
        self.assertAlmostEqual(make_engine().cost(recs[0]), 6.0, places=9)

    def test_month_to_date_excludes_last_month(self):
        p = LogParser()
        lines = [
            '{"type":"assistant","timestamp":"2026-07-02T10:00:00Z","message":'
            '{"model":"claude-haiku-4-5","usage":{"input_tokens":1000000,"output_tokens":0}}}',
            '{"type":"assistant","timestamp":"2026-06-30T10:00:00Z","message":'
            '{"model":"claude-haiku-4-5","usage":{"input_tokens":1000000,"output_tokens":0}}}',
        ]
        recs = p.parse_lines(lines, "p")
        now = datetime(2026, 7, 15, tzinfo=timezone.utc)
        self.assertAlmostEqual(make_engine().month_to_date_total(recs, now), 1.0, places=9)


class LogParserTests(unittest.TestCase):
    FIXTURE = [
        '{"type":"user","timestamp":"2026-07-01T10:00:00Z","message":{"content":"fix the login bug please"}}',
        '{"type":"assistant","timestamp":"2026-07-01T10:00:05Z","cwd":"/Users/x/dev/myapp","message":'
        '{"id":"msg_1","model":"claude-opus-4-8","usage":{"input_tokens":2300,"output_tokens":800,'
        '"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}',
        '{"garbage line that is not json}',
        '{"type":"assistant","timestamp":"2026-07-01T10:01:00Z","cwd":"/Users/x/dev/myapp","message":'
        '{"id":"synth","model":"<synthetic>","usage":{"input_tokens":5,"output_tokens":5}}}',
        '{"type":"assistant","timestamp":"2026-07-01T10:02:00Z","cwd":"/Users/x/dev/myapp","message":'
        '{"id":"msg_2","model":"claude-haiku-4-5","usage":{"input_tokens":120,"output_tokens":40}}}',
    ]

    def test_parses_two_records_skipping_garbage_and_synthetic(self):
        recs = LogParser().parse_lines(self.FIXTURE, "fallback")
        self.assertEqual(len(recs), 2)

    def test_first_record_fields_and_preview(self):
        first = LogParser().parse_lines(self.FIXTURE, "fallback")[0]
        self.assertEqual(first.model, "claude-opus-4-8")
        self.assertEqual(first.input_tokens, 2300)
        self.assertEqual(first.output_tokens, 800)
        self.assertEqual(first.project, "myapp")
        self.assertIn("login bug", first.prompt_preview)
        self.assertEqual(first.id, "msg_1")

    def test_missing_cache_fields_default_zero(self):
        recs = LogParser().parse_lines(self.FIXTURE, "fallback")
        self.assertEqual(recs[1].cache_read_tokens, 0)
        self.assertEqual(recs[1].cache_write_tokens, 0)

    def test_list_content_preview(self):
        line = ('{"type":"user","message":{"content":[{"type":"text","text":"hello world"}]}}')
        # a following assistant line to attach the preview to
        asst = ('{"type":"assistant","message":{"model":"claude-haiku-4-5",'
                '"usage":{"input_tokens":1,"output_tokens":1}}}')
        recs = LogParser().parse_lines([line, asst], "p")
        self.assertEqual(recs[0].prompt_preview, "hello world")


class ComplexityHeuristicsTests(unittest.TestCase):
    def setUp(self):
        self.h = ComplexityHeuristics()

    def test_short_simple_is_haiku(self):
        self.assertEqual(self.h.recommend("rename this variable"), "haiku")

    def test_hard_keyword_is_opus(self):
        self.assertEqual(self.h.recommend("refactor the auth layer"), "opus")

    def test_code_block_is_sonnet(self):
        self.assertEqual(self.h.recommend("explain ```func foo() {}```"), "sonnet")

    def test_simple_task_detection(self):
        self.assertTrue(self.h.is_simple_task(40, 120, 20))
        self.assertFalse(self.h.is_simple_task(900, 120, 20))


class OverkillDetectorTests(unittest.TestCase):
    def setUp(self):
        self.det = OverkillDetector(make_engine(), ComplexityHeuristics())

    def _rec(self, model, out, ctx, preview):
        return LogParser().parse_lines([
            '{"type":"user","message":{"content":"' + preview + '"}}',
            '{"type":"assistant","message":{"model":"' + model + '","usage":'
            '{"input_tokens":' + str(ctx) + ',"output_tokens":' + str(out) + '}}}'
        ], "p")[0]

    def test_simple_task_on_opus_is_overkill(self):
        is_over, overpay = self.det.evaluate(self._rec("claude-opus-4-8", 50, 200, "rename var"))
        self.assertTrue(is_over)
        self.assertGreater(overpay, 0)

    def test_big_task_on_opus_not_overkill(self):
        is_over, _ = self.det.evaluate(self._rec("claude-opus-4-8", 5000, 50000, "big"))
        self.assertFalse(is_over)

    def test_simple_task_on_haiku_not_overkill(self):
        is_over, _ = self.det.evaluate(self._rec("claude-haiku-4-5", 50, 200, "hi"))
        self.assertFalse(is_over)


class AdvisorTests(unittest.TestCase):
    def setUp(self):
        self.adv = Advisor(CostEngine(PricingTable.load()), ComplexityHeuristics())

    def test_recommends_haiku_for_simple(self):
        rec = self.adv.recommend("rename this variable")
        self.assertEqual(rec["tier"], "haiku")
        self.assertEqual(rec["model_id"], "claude-haiku-4-5")
        self.assertGreater(rec["estimated_cost"], 0)

    def test_recommends_opus_for_hard(self):
        self.assertEqual(self.adv.recommend("refactor the module")["tier"], "opus")

    def test_run_command_shape(self):
        self.assertEqual(self.adv.run_command("do a thing", "haiku"),
                         ["claude", "-p", "do a thing", "--model", "haiku"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
