"""Bulk-generate FastRoute fallback cards via Ollama qwen3.5:4b.

QA v2 HIGH 7.9 (2026-05-15) — pool 117 → 500+ for replayability.

Usage:
    python tools/bulk_generate_fastroute.py --target 400 --per_biome 50 --model qwen3.5:4b
    python tools/bulk_generate_fastroute.py --smoke 3      # quick 3-card smoke test
"""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POOL_PATH = ROOT / "data" / "ai" / "fastroute_cards.json"
OLLAMA_URL = "http://localhost:11434/api/generate"

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

FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]
EFFECT_TYPES = ["ADD_REPUTATION", "HEAL_LIFE", "DAMAGE_LIFE"]

BIOME_HINTS = {
    "foret_broceliande": "ancienne foret celtique, chenes, druides, biche argentee, fougeres",
    "landes_bruyere": "landes battues par le vent, cairns, bruyere, ankou, brouillard",
    "cotes_sauvages": "falaises, grottes marines, vagues, korrigans, naufrages",
    "villages_celtes": "village ancien, anciens conteurs, feu, foyer, dolmens",
    "cercles_pierres": "menhirs, cercles druidiques, runes ogham, equinoxe, lichen",
    "marais_korrigans": "marais brumeux, will-o-wisps, korrigans malicieux, tourbiere",
    "collines_dolmens": "collines verdoyantes, dolmens, ancestres, traces de chemins",
    "iles_mystiques": "iles flottantes, brume eternelle, niamh, fees, autre monde",
}


PROMPT_TEMPLATE = """Tu es l'ecrivain narratif d'un jeu de cartes celtique francophone (M.E.R.L.I.N.).
Genere UNE carte narrative au format JSON STRICT pour le biome "{biome}" ({hint}).

Structure exacte:
{{
  "text": "<phrase narrative francaise 15-30 mots, evocateur, mystere ou choix moral>",
  "options": [
    {{"label": "<action 4-7 mots>", "verb": "<verbe principal>", "effects": [...]}},
    {{"label": "<action 4-7 mots>", "verb": "<verbe principal>", "effects": [...]}},
    {{"label": "<action 4-7 mots>", "verb": "<verbe principal>", "effects": [...]}}
  ],
  "tags": ["<1-3 mots-cles>"]
}}

Regles effects (chaque option a 1-2 effets):
- ADD_REPUTATION : {{"type":"ADD_REPUTATION","faction":"<{factions}>","amount":<5-8>}}
- HEAL_LIFE     : {{"type":"HEAL_LIFE","amount":<3-5>}}
- DAMAGE_LIFE   : {{"type":"DAMAGE_LIFE","amount":<3-5>}}

CONTRAINTES:
- 3 options exactement, chacune avec 1-2 effets
- Pas de TODO, pas de placeholder
- Texte SANS guillemets internes
- Vocabulaire celtique authentique

Reponds UNIQUEMENT avec le JSON valide. Pas de markdown.
"""


def call_ollama(model: str, prompt: str, timeout: int = 60) -> str:
    body = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.85, "num_predict": 400},
    }).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data.get("response", "")


def extract_json(text: str) -> dict | None:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```\s*$", "", text)
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start:i + 1])
                except json.JSONDecodeError:
                    return None
    return None


def validate_card(card: dict) -> tuple[bool, str]:
    if not isinstance(card.get("text"), str) or not (10 <= len(card["text"]) <= 240):
        return False, "text length out of range"
    opts = card.get("options", [])
    if not isinstance(opts, list) or len(opts) != 3:
        return False, "options must be exactly 3"
    for opt in opts:
        if not isinstance(opt, dict):
            return False, "option not dict"
        if not isinstance(opt.get("label"), str) or not opt["label"]:
            return False, "option missing label"
        if not isinstance(opt.get("verb"), str) or not opt["verb"]:
            return False, "option missing verb"
        fx = opt.get("effects", [])
        if not isinstance(fx, list) or not (1 <= len(fx) <= 2):
            return False, "effects must be 1-2"
        for e in fx:
            if not isinstance(e, dict):
                return False, "effect not dict"
            if e.get("type") not in EFFECT_TYPES:
                return False, f"unknown effect {e.get('type')}"
            if e["type"] == "ADD_REPUTATION":
                if e.get("faction") not in FACTIONS:
                    return False, f"bad faction {e.get('faction')}"
                if not isinstance(e.get("amount"), int) or not (1 <= e["amount"] <= 20):
                    return False, "rep amount oob"
            else:
                if not isinstance(e.get("amount"), int) or not (1 <= e["amount"] <= 10):
                    return False, "life amount oob"
    if not isinstance(card.get("tags"), list):
        card["tags"] = []
    return True, ""


def biome_prefix(biome: str) -> str:
    short_map = {
        "foret_broceliande": "broceliande",
        "landes_bruyere": "landes",
        "cotes_sauvages": "cotes",
        "villages_celtes": "villages",
        "cercles_pierres": "cercles",
        "marais_korrigans": "marais",
        "collines_dolmens": "collines",
        "iles_mystiques": "iles",
    }
    return short_map.get(biome, biome.split("_")[0])


def next_id(biome: str, existing_ids: set[str]) -> str:
    prefix = biome_prefix(biome)
    n = 1
    while True:
        cand = f"fr_{prefix}_{n:03d}"
        if cand not in existing_ids:
            return cand
        n += 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=int, default=400)
    parser.add_argument("--per_biome", type=int, default=50)
    parser.add_argument("--model", default="qwen3.5:4b")
    parser.add_argument("--max_retries", type=int, default=3)
    parser.add_argument("--smoke", type=int, default=0)
    args = parser.parse_args()

    pool = json.loads(POOL_PATH.read_text(encoding="utf-8"))
    narrative = pool.setdefault("narrative", [])
    existing_ids = {c.get("id") for c in narrative if isinstance(c, dict)}
    print(f"[bulk_gen] Pool baseline: {len(narrative)} narrative cards.")

    targets: list[str] = []
    if args.smoke > 0:
        for i in range(args.smoke):
            targets.append(BIOMES[i % len(BIOMES)])
    else:
        for biome in BIOMES:
            targets.extend([biome] * args.per_biome)
        if len(targets) > args.target:
            targets = targets[: args.target]

    generated = 0
    skipped = 0
    start = time.time()
    for idx, biome in enumerate(targets):
        prompt = PROMPT_TEMPLATE.format(
            biome=biome, hint=BIOME_HINTS[biome], factions="|".join(FACTIONS),
        )
        success = False
        for attempt in range(args.max_retries):
            try:
                raw = call_ollama(args.model, prompt, timeout=60)
                card = extract_json(raw)
                if card is None:
                    raise ValueError("no JSON")
                ok, err = validate_card(card)
                if not ok:
                    raise ValueError(err)
                card["id"] = next_id(biome, existing_ids)
                card["biome"] = biome
                card_ordered = {
                    "id": card["id"],
                    "text": card["text"],
                    "biome": card["biome"],
                    "options": card["options"],
                    "tags": card.get("tags", []),
                }
                narrative.append(card_ordered)
                existing_ids.add(card_ordered["id"])
                generated += 1
                success = True
                elapsed = time.time() - start
                rate = generated / elapsed if elapsed > 0 else 0
                eta_s = (len(targets) - idx - 1) / rate if rate > 0 else 0
                print(f"[{idx+1}/{len(targets)}] {card_ordered['id']} OK "
                      f"(rate {rate:.2f}/s, ETA {int(eta_s/60)}m)")
                break
            except Exception as e:
                print(f"[{idx+1}/{len(targets)}] {biome} retry {attempt+1}: {e}")
        if not success:
            skipped += 1
        if generated % 20 == 0 and generated > 0:
            POOL_PATH.write_text(json.dumps(pool, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"[bulk_gen] Snapshot saved at {generated} cards.")

    POOL_PATH.write_text(json.dumps(pool, indent=2, ensure_ascii=False), encoding="utf-8")
    elapsed = time.time() - start
    print(f"\n[bulk_gen] DONE. Generated {generated}, skipped {skipped} in {elapsed/60:.1f} min.")
    print(f"[bulk_gen] Pool total: {len(narrative)} narrative cards.")


if __name__ == "__main__":
    main()
