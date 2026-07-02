#!/usr/bin/env python3
"""
TokenWatch desktop app (Windows-runnable preview).

A tiny standard-library HTTP server that serves the TokenWatch UI and exposes the
core data as JSON. It reuses the exact same logic as the Swift core via the Python
mirror in ../preview/tokenwatch.py.

Run:
    py app/server.py
It opens http://127.0.0.1:8730 in your browser automatically.
"""
from __future__ import annotations

import http.server
import json
import os
import socketserver
import sys
import threading
import webbrowser
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "preview"))

from tokenwatch import TokenWatch, short_model  # noqa: E402

PORT = 8730
tw = TokenWatch()


def build_data() -> dict:
    recs = tw.records()
    now = datetime.now(timezone.utc)
    mtd = tw.cost_engine.month_to_date_total(recs, now)
    total = tw.cost_engine.total(recs)

    by_model: dict[str, float] = {}
    overpay_sum = 0.0
    overkill_count = 0
    history = []
    for r in recs:
        cost = tw.cost_engine.cost(r)
        by_model[r.model] = by_model.get(r.model, 0.0) + cost
        is_over, overpay = tw.detector.evaluate(r)
        if is_over:
            overkill_count += 1
            overpay_sum += overpay
        if len(history) < 120:
            history.append({
                "when": r.timestamp.astimezone().strftime("%b %d  %H:%M"),
                "model": r.model,
                "short": short_model(r.model),
                "cost": cost,
                "inTok": r.input_tokens,
                "outTok": r.output_tokens,
                "cacheRead": r.cache_read_tokens,
                "cacheWrite": r.cache_write_tokens,
                "project": r.project,
                "preview": r.prompt_preview,
                "overkill": is_over,
                "overpay": overpay,
            })

    models = sorted(
        ({"model": m, "short": short_model(m), "cost": c} for m, c in by_model.items()),
        key=lambda x: x["cost"], reverse=True,
    )
    return {
        "monthToDate": mtd,
        "allTime": total,
        "requestCount": len(recs),
        "overkillCount": overkill_count,
        "overpay": overpay_sum,
        "byModel": models,
        "history": history,
        "generatedAt": now.astimezone().strftime("%H:%M:%S"),
    }


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):  # keep the console quiet
        pass

    def _send(self, code, body: bytes, ctype: str):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj):
        self._send(200, json.dumps(obj).encode("utf-8"), "application/json; charset=utf-8")

    def do_GET(self):
        route = urlparse(self.path)
        if route.path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as fh:
                self._send(200, fh.read(), "text/html; charset=utf-8")
        elif route.path == "/api/data":
            self._json(build_data())
        elif route.path == "/api/advise":
            q = parse_qs(route.query)
            prompt = (q.get("prompt", [""])[0]).strip()
            if not prompt:
                self._json({"error": "empty prompt"})
                return
            if q.get("fast", ["0"])[0] == "1":
                r = tw.advisor.recommend(prompt)
                self._json({
                    "tier": r["tier"], "model_id": r["model_id"], "alias": r["alias"],
                    "estimated_cost": r["estimated_cost"], "situation": "offline estimate",
                    "reasoning": "Offline heuristic (no Claude call).", "confidence": 0.5,
                    "savings_vs_opus": 0.0, "source": "offline",
                    "command": " ".join(tw.advisor.run_command(prompt, r["alias"])),
                })
            else:
                self._json(tw.analyzer.analyze(prompt))
        else:
            self._send(404, b"not found", "text/plain; charset=utf-8")


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        url = f"http://127.0.0.1:{PORT}"
        print(f"👁  TokenWatch running at {url}   (Ctrl+C to stop)")
        if "--no-open" not in sys.argv:
            threading.Timer(0.6, lambda: webbrowser.open(url)).start()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


if __name__ == "__main__":
    main()
