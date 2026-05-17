#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
embed_reference_scenarios.py — v7.7.23 (2026-05-17)

Pre-compute embeddings for the 100 Brocéliande reference scenarios so the
in-game ScenariosRAG autoload can do kNN cosine retrieval at runtime.

Input  : data/ai/scenarios_reference_broceliande.json
Output : data/ai/scenarios_reference_broceliande.embeddings.json
         { model, dim, status, count, generated_at, embeddings: [{id, vector}] }

Uses Ollama embeddings API (model: nomic-embed-text, 768-dim, 137 MB).
Pulls the model first if not installed. Idempotent.
"""

from __future__ import annotations
import json
import sys
import time
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError

OLLAMA_BASE = "http://localhost:11434"
EMBED_MODEL = "nomic-embed-text"
INPUT_PATH = Path(__file__).resolve().parent.parent / "data" / "ai" / "scenarios_reference_broceliande.json"
OUTPUT_PATH = Path(__file__).resolve().parent.parent / "data" / "ai" / "scenarios_reference_broceliande.embeddings.json"


def ollama_call(endpoint: str, payload: dict, timeout: int = 120) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(f"{OLLAMA_BASE}{endpoint}", data=body,
                  headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def ensure_model_pulled() -> bool:
    """Check the embedding model is installed ; pull if not."""
    try:
        with urlopen(f"{OLLAMA_BASE}/api/tags", timeout=5) as r:
            tags = json.loads(r.read().decode("utf-8"))
    except URLError as e:
        print(f"[FATAL] Ollama not reachable at {OLLAMA_BASE} : {e}", file=sys.stderr)
        return False
    installed = [m.get("name", "") for m in tags.get("models", [])]
    if any(EMBED_MODEL in n for n in installed):
        print(f"[OK] {EMBED_MODEL} already installed")
        return True
    print(f"[INFO] {EMBED_MODEL} not found — pulling now (~137 MB)…")
    try:
        # /api/pull is a streaming endpoint, just block until done.
        body = json.dumps({"name": EMBED_MODEL, "stream": False}).encode("utf-8")
        req = Request(f"{OLLAMA_BASE}/api/pull", data=body,
                      headers={"Content-Type": "application/json"})
        with urlopen(req, timeout=600) as r:
            r.read()
        print(f"[OK] Pulled {EMBED_MODEL}")
        return True
    except Exception as e:
        print(f"[FATAL] Pull failed : {e}", file=sys.stderr)
        return False


def embed_text(text: str) -> list[float]:
    """Call Ollama embed for a single text. Returns 768-dim float vector."""
    resp = ollama_call("/api/embeddings", {"model": EMBED_MODEL, "prompt": text})
    return resp.get("embedding", [])


def compose_embed_input(scenario: dict) -> str:
    """Concatenate fields that best characterize the scenario for similarity.
    title + archetype_name + intro is enough — premise is redundant for RAG retrieval."""
    parts = [
        scenario.get("title", ""),
        scenario.get("archetype_name", ""),
        scenario.get("intro", ""),
    ]
    return " · ".join(p for p in parts if p)


def main() -> int:
    if not INPUT_PATH.exists():
        print(f"[FATAL] Input not found : {INPUT_PATH}", file=sys.stderr)
        return 1
    scenarios = json.loads(INPUT_PATH.read_text(encoding="utf-8"))
    print(f"[OK] Loaded {len(scenarios)} reference scenarios from {INPUT_PATH.name}")

    if not ensure_model_pulled():
        # Write an empty embeddings file so the autoload can detect "no embeddings"
        # and fall back gracefully to archetype-matching retrieval.
        OUTPUT_PATH.write_text(json.dumps({
            "model": EMBED_MODEL,
            "dim": 0,
            "status": "ollama_unavailable",
            "embeddings": [],
        }, indent=2), encoding="utf-8")
        print(f"[WARN] Wrote empty embeddings to {OUTPUT_PATH.name}")
        return 2

    embeddings: list[dict] = []
    start = time.time()
    for i, s in enumerate(scenarios):
        sid = s.get("id", f"broc_{i:03d}")
        text = compose_embed_input(s)
        if not text:
            print(f"[WARN] {sid} : empty embed input, skipping")
            continue
        try:
            vec = embed_text(text)
        except Exception as e:
            print(f"[ERROR] {sid} : embed failed : {e}", file=sys.stderr)
            continue
        if not vec:
            print(f"[ERROR] {sid} : empty vector returned")
            continue
        embeddings.append({"id": sid, "vector": vec})
        if (i + 1) % 10 == 0:
            elapsed = time.time() - start
            rate = (i + 1) / elapsed if elapsed > 0 else 0
            eta = (len(scenarios) - (i + 1)) / rate if rate > 0 else 0
            print(f"[PROGRESS] {i + 1}/{len(scenarios)} · {rate:.1f}/s · ETA {eta:.0f}s")

    dim = len(embeddings[0]["vector"]) if embeddings else 0
    output = {
        "model": EMBED_MODEL,
        "dim": dim,
        "status": "ok" if embeddings else "no_embeddings",
        "count": len(embeddings),
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "embeddings": embeddings,
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False), encoding="utf-8")
    elapsed = time.time() - start
    print(f"[OK] Wrote {len(embeddings)} embeddings ({dim}-dim) to {OUTPUT_PATH.name}")
    print(f"[OK] Total time : {elapsed:.1f}s · File size : {OUTPUT_PATH.stat().st_size / 1024:.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
