from __future__ import annotations

import re
import unicodedata


SEGMENT_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("allergen", re.compile(r"(알레르기|알러지|함유|혼입|이 제품은|같은 제조시설)", re.I)),
    ("nutrition", re.compile(r"(영양정보|영양성분|나트륨|탄수화물|당류|지방|단백질|열량)", re.I)),
    ("ingredient", re.compile(r"(원재료|원료명|성분|식품유형|내용량)", re.I)),
]


def normalize_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text or "")
    normalized = normalized.replace("\r\n", "\n").replace("\r", "\n")
    normalized = re.sub(r"[ \t]+", " ", normalized)
    normalized = re.sub(r"\n{3,}", "\n\n", normalized)
    return normalized.strip()


def compact_for_match(text: str) -> str:
    normalized = normalize_text(text).lower()
    return re.sub(r"[\s,.;:()\[\]{}<>·ㆍ|/\\_+\-=~!?'\"`]+", "", normalized)


def extract_segments(text: str) -> list[dict[str, str]]:
    normalized = normalize_text(text)
    if not normalized:
        return []

    lines = [line.strip() for line in normalized.splitlines() if line.strip()]
    segments: list[dict[str, str]] = [{"type": "full_text", "text": normalized}]
    seen: set[tuple[str, str]] = {("full_text", normalized)}

    for line in lines:
        for segment_type, pattern in SEGMENT_PATTERNS:
            if pattern.search(line):
                key = (segment_type, line)
                if key not in seen:
                    seen.add(key)
                    segments.append({"type": segment_type, "text": line})
                break

    # OCR often returns one long block. Extract coarse marker-based snippets too.
    marker_regex = re.compile(
        r"(원재료명?|원료명|알레르기|알러지|영양정보|영양성분)[\s:：]*(.{0,450})",
        re.I | re.S,
    )
    for match in marker_regex.finditer(normalized):
        marker = match.group(1)
        snippet = f"{marker}: {match.group(2).strip()}"
        segment_type = "ingredient"
        if "알" in marker:
            segment_type = "allergen"
        elif "영양" in marker:
            segment_type = "nutrition"
        key = (segment_type, snippet)
        if key not in seen:
            seen.add(key)
            segments.append({"type": segment_type, "text": snippet})

    return segments


def evidence_window(text: str, keyword: str, radius: int = 42) -> str:
    normalized = normalize_text(text)
    if not keyword:
        return normalized[: radius * 2]
    idx = normalized.lower().find(keyword.lower())
    if idx < 0:
        return normalized[: radius * 2]
    start = max(0, idx - radius)
    end = min(len(normalized), idx + len(keyword) + radius)
    return normalized[start:end].replace("\n", " ")
