"""Generate mobile/lib/l10n_data.dart: the UI copy catalogue keyed by the Korean source string.

Korean stays in the widget tree as the lookup key, so a missing translation degrades to
Korean instead of an empty screen. Run this after adding or changing Korean UI copy:

    python scripts/build_l10n.py            # translate only the strings that are new
    python scripts/build_l10n.py --all      # retranslate everything

The cache in scripts/l10n_cache.json is committed so a normal build never calls OpenAI.
"""
import argparse
import json
import re
import sys
from pathlib import Path

import httpx
from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "scripts/l10n_cache.json"
TARGET = ROOT / "mobile/lib/l10n_data.dart"
LANGUAGES = {"en": "English", "ar": "Arabic", "zh": "Simplified Chinese", "ja": "Japanese"}

LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'")
HANGUL = re.compile(r"[가-힣]")
# searchTerms blobs are matching tokens rather than copy, and they start with an ASCII word.
DATA_BLOB = re.compile(r"^[a-z][a-z ]")
PLACEHOLDER = re.compile(r"\{\d+\}")

SYSTEM = (
    "You localize the UI of Safe-Byte, a Korean food-label safety app used by people with "
    "food allergies and by halal, vegan and vegetarian shoppers. Translate each Korean UI "
    "string into {language}. Rules: keep the tone plain and calm; keep button and menu labels "
    "as short as the Korean; never translate the product name Safe-Byte, OCR, BLE, CLOVA or kcal; "
    "keep placeholders like {{0}} and {{1}} exactly as they are and in the same order; never add "
    "or remove a warning, and never soften or strengthen a risk statement; return the same number "
    "of items in the same order."
)


def is_fragment(value: str) -> bool:
    """A quote inside `${map['key']}` splits the literal, leaving unusable tails."""
    return any(char in PLACEHOLDER.sub("", value) for char in "[]{}$")


def collect_ui_strings() -> list[str]:
    found: dict[str, None] = {}
    for path in sorted((ROOT / "mobile/lib").rglob("*.dart")):
        if path.name.startswith("l10n"):
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            for match in LITERAL.finditer(line):
                value = match.group(1)
                if HANGUL.search(value) and not DATA_BLOB.match(value) and not is_fragment(value):
                    found[value] = None
    return list(found)


def templates_in_use() -> list[str]:
    """Placeholder templates are written directly as t('{0}님') in the sources."""
    found: dict[str, None] = {}
    call = re.compile(r"t\('((?:[^'\\\n]|\\.)*)'\)")
    for path in sorted((ROOT / "mobile/lib").rglob("*.dart")):
        if path.name.startswith("l10n"):
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            for match in call.finditer(line):
                value = match.group(1)
                if HANGUL.search(value) and PLACEHOLDER.search(value):
                    found[value] = None
    return list(found)


def translate(client: httpx.Client, key: str, model: str, language: str, batch: list[str]) -> list[str]:
    schema = {"type": "object", "additionalProperties": False,
              "properties": {"translations": {"type": "array", "items": {"type": "string"}}},
              "required": ["translations"]}
    response = client.post(
        "https://api.openai.com/v1/responses",
        headers={"Authorization": "Bearer " + key},
        json={"model": model,
              "input": [{"role": "system", "content": SYSTEM.format(language=LANGUAGES[language])},
                        {"role": "user", "content": json.dumps(batch, ensure_ascii=False)}],
              "store": False, "max_output_tokens": 4000,
              "text": {"format": {"type": "json_schema", "name": "translations",
                                  "strict": True, "schema": schema}}},
        timeout=120)
    response.raise_for_status()
    raw = response.json()
    if raw.get("status") != "completed":
        raise SystemExit("Model stopped early: " + str(raw.get("incomplete_details")))
    content = "".join(part["text"] for item in raw.get("output", [])
                      for part in item.get("content", []) if part.get("type") == "output_text")
    lines = json.loads(content)["translations"]
    if len(lines) != len(batch):
        raise SystemExit(f"Expected {len(batch)} translations, got {len(lines)}")
    for source, line in zip(batch, lines):
        if sorted(PLACEHOLDER.findall(source)) != sorted(PLACEHOLDER.findall(line)):
            raise SystemExit(f"Placeholders changed: {source!r} -> {line!r}")
    return lines


def dart_literal(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n") + "'"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true", help="Retranslate every string.")
    parser.add_argument("--batch", type=int, default=25)
    args = parser.parse_args()

    strings = collect_ui_strings() + templates_in_use()
    cache = {} if args.all else json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    missing = [s for s in strings if s not in cache or any(l not in cache[s] for l in LANGUAGES)]
    print(f"{len(strings)} UI strings, {len(missing)} need translation")

    if missing:
        env = dotenv_values(ROOT / ".env", encoding="utf-8-sig")
        key = env.get("OPENAI_API_KEY")
        model = env.get("OPENAI_MODEL") or "gpt-4o-mini"
        if not key:
            raise SystemExit("Set OPENAI_API_KEY in .env to translate new strings")
        with httpx.Client() as client:
            for language in LANGUAGES:
                todo = [s for s in missing if language not in cache.get(s, {})]
                for start in range(0, len(todo), args.batch):
                    batch = todo[start:start + args.batch]
                    for source, line in zip(batch, translate(client, key, model, language, batch)):
                        cache.setdefault(source, {})[language] = line
                    # Save every batch so a later failure never re-buys finished work.
                    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1, sort_keys=True),
                                     encoding="utf-8")
                    print(f"  {language}: {min(start + args.batch, len(todo))}/{len(todo)}", flush=True)

    body = ["// GENERATED by scripts/build_l10n.py - do not edit by hand.",
            "// The Korean source string is the key, so a missing entry falls back to Korean.",
            "",
            "const Map<String, Map<String, String>> uiStrings = {"]
    for source in sorted(strings):
        entries = ", ".join(f"'{code}': {dart_literal(cache[source][code])}" for code in LANGUAGES)
        body.append(f"  {dart_literal(source)}: {{{entries}}},")
    body.extend(["};", ""])
    TARGET.write_text("\n".join(body), encoding="utf-8")
    print("wrote", TARGET, f"({len(strings)} entries)")


if __name__ == "__main__":
    sys.exit(main())
