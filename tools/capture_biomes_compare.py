"""Capture 1+ frames per biome (8 biomes) for v7.4 palette regression test.

Phase 4+ visual validation : confirms BiomePalettes wiring produces visibly
distinct plateau + grass + decor for each of the 8 biomes (bible §22 v3.4).

Usage:
    python tools/capture_biomes_compare.py
    python tools/capture_biomes_compare.py --duration 4 --interval 2000

Mechanism :
    - Sets MERLIN_AUTOPLAY=1 + MERLIN_BIOME_OVERRIDE=<biome_id>
    - Runs tools/cli.py godot smoke for ~4s with capture
    - Output : output/captures/biomes_v7_4/<biome_id>/frame_*.png
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "output" / "captures" / "biomes_v7_4"

BIOMES = [
    "foret_broceliande",
    "landes_bruyere",
    "cotes_sauvages",
    "villages_celtes",
    "cercles_pierres",
    "marais_korrigans",
    "collines_dolmens",
    "iles_mystiques",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=int, default=4, help="Smoke duration per biome (seconds)")
    parser.add_argument("--interval", type=int, default=2000, help="Capture interval (ms)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[capture] Writing to {OUTPUT_DIR}")

    summary: list[tuple[str, bool, int]] = []
    for biome in BIOMES:
        out_dir = OUTPUT_DIR / biome
        out_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["MERLIN_AUTOPLAY"] = "1"
        env["MERLIN_BIOME_OVERRIDE"] = biome
        # v7.4 — Skip LLM warmup : it's synchronous on the main thread and blocks
        # the CaptureRecorder Timer (idle process) for the entire smoke duration.
        env["MERLIN_SKIP_LLM_INIT"] = "1"
        cmd = [
            sys.executable, str(ROOT / "tools" / "cli.py"), "godot", "smoke",
            "--scene", "res://scenes/BoardNarration.tscn",
            "--duration", str(args.duration),
            "--capture", str(out_dir),
            "--capture_interval", str(args.interval),
        ]
        print(f"[capture] {biome} ...")
        try:
            r = subprocess.run(
                cmd, env=env, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=60,
            )
            stdout = r.stdout or ""
            stderr = r.stderr or ""
            blob = stdout + stderr
            ok = ("passed=True" in blob) or ("passed=true" in blob)
            frames = len(list(out_dir.glob("*.png")))
            summary.append((biome, ok, frames))
            print(f"  -> passed={ok}, frames={frames}, exit={r.returncode}")
            if not ok:
                # First 600 chars of stderr to help debug.
                snippet = stderr[:600].replace("\n", " | ")
                print(f"     stderr: {snippet}")
        except subprocess.TimeoutExpired:
            summary.append((biome, False, 0))
            print(f"  -> TIMEOUT")
        except Exception as e:
            summary.append((biome, False, 0))
            print(f"  -> ERROR: {e}")

    print("\n[capture] Summary:")
    print(f"{'Biome':<22} {'Pass':<6} {'Frames':<6}")
    for biome, ok, frames in summary:
        print(f"{biome:<22} {'OK' if ok else 'FAIL':<6} {frames:<6}")
    passes = sum(1 for _, ok, _ in summary if ok)
    print(f"\n{passes}/{len(BIOMES)} biomes captured successfully.")
    return 0 if passes == len(BIOMES) else 1


if __name__ == "__main__":
    sys.exit(main())
