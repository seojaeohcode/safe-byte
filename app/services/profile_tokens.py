from __future__ import annotations

from typing import Any


BASE_PROFILES = {"halal", "vegan", "allergy", "vegetarian", "all"}

ALLERGEN_OPTIONS: dict[str, str] = {
    "egg": "난류/계란",
    "milk": "우유",
    "buckwheat": "메밀",
    "peanut": "땅콩",
    "soy": "대두",
    "wheat": "밀/글루텐",
    "mackerel": "고등어",
    "crab": "게",
    "shrimp": "새우",
    "pork": "돼지고기",
    "peach": "복숭아",
    "tomato": "토마토",
    "sulfite": "아황산류",
    "walnut": "호두",
    "chicken": "닭고기",
    "beef": "쇠고기",
    "squid": "오징어",
    "shellfish": "조개류",
    "pine_nut": "잣",
    # Optional expanded user-specific allergens. These are not all Korean
    # mandatory labeling targets, but are useful for foreign visitors.
    "fish": "생선류",
    "tree_nut": "견과류",
    "sesame": "참깨",
}

PROFILE_ALIASES = {
    "알레르기": "allergy",
    "할랄": "halal",
    "비건": "vegan",
    "채식": "vegetarian",
    "전체": "all",
}

ALLERGEN_ALIASES = {
    "계란": "egg",
    "난류": "egg",
    "알류": "egg",
    "우유": "milk",
    "유제품": "milk",
    "메밀": "buckwheat",
    "땅콩": "peanut",
    "대두": "soy",
    "콩": "soy",
    "밀": "wheat",
    "글루텐": "wheat",
    "고등어": "mackerel",
    "게": "crab",
    "새우": "shrimp",
    "돼지고기": "pork",
    "돈육": "pork",
    "복숭아": "peach",
    "토마토": "tomato",
    "아황산류": "sulfite",
    "호두": "walnut",
    "닭고기": "chicken",
    "쇠고기": "beef",
    "소고기": "beef",
    "오징어": "squid",
    "조개류": "shellfish",
    "잣": "pine_nut",
    "생선": "fish",
    "생선류": "fish",
    "견과류": "tree_nut",
    "참깨": "sesame",
}


def normalize_profile_token(value: Any) -> str | None:
    token = str(value).strip().lower()
    if not token:
        return None
    token = PROFILE_ALIASES.get(token, token)
    token = token.replace("allergen:", "allergy:", 1)
    token = token.replace("allergy_", "allergy:", 1)

    if token in BASE_PROFILES:
        return token
    if token in {"halal:strict", "halal:cautious", "vegan:strict"}:
        return token
    if token.startswith("allergy:"):
        key = token.split(":", 1)[1].strip()
        key = ALLERGEN_ALIASES.get(key, key)
        return f"allergy:{key}" if key in ALLERGEN_OPTIONS else None
    if token in ALLERGEN_OPTIONS:
        return f"allergy:{token}"
    if token in ALLERGEN_ALIASES:
        return f"allergy:{ALLERGEN_ALIASES[token]}"
    return None


def normalize_profiles(profiles: Any, default: list[str] | None = None) -> list[str]:
    if isinstance(profiles, str):
        raw_values = profiles.split(",")
    elif isinstance(profiles, list):
        raw_values = profiles
    elif isinstance(profiles, tuple | set):
        raw_values = list(profiles)
    else:
        raw_values = default or ["halal", "vegan", "allergy"]

    cleaned: list[str] = []
    for item in raw_values:
        token = normalize_profile_token(item)
        if token and token not in cleaned:
            cleaned.append(token)
    if cleaned:
        return cleaned
    return default if default is not None else ["allergy"]


def selected_allergen_keys(profiles: list[str]) -> set[str]:
    keys = set()
    for token in profiles:
        if token.startswith("allergy:"):
            keys.add(token.split(":", 1)[1])
    return keys


def base_profile_enabled(profiles: list[str], category: str) -> bool:
    return "all" in profiles or category in profiles or f"{category}:strict" in profiles
