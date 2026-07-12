from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from app.services.text_parser import normalize_text


@dataclass(frozen=True)
class CorrectionRule:
    name: str
    pattern: re.Pattern[str]
    replacement: str
    category: str


def _rule(name: str, pattern: str, replacement: str, category: str) -> CorrectionRule:
    return CorrectionRule(
        name=name,
        pattern=re.compile(pattern, re.I),
        replacement=replacement,
        category=category,
    )


CORRECTION_RULES: tuple[CorrectionRule, ...] = (
    _rule("ingredient_marker_spacing", r"원\s+재료\s*명|원재료\s+명", "원재료명", "label_marker"),
    _rule("raw_material_marker_spacing", r"원\s+료\s*명|원료\s+명", "원료명", "label_marker"),
    _rule("allergy_marker_variant", r"알\s*러\s*지", "알레르기", "label_marker"),
    _rule("allergy_marker_spacing", r"알\s+레\s*르\s*기|알레\s+르기|알레르\s+기", "알레르기", "label_marker"),
    _rule("allergen_phrase_spacing", r"유\s+발\s*물\s*질|유발\s+물질", "유발물질", "label_marker"),
    _rule("nutrition_marker_spacing", r"영\s+양\s*정\s*보|영양\s+정보", "영양정보", "label_marker"),
    _rule("nutrition_component_spacing", r"영\s+양\s*성\s*분|영양\s+성분", "영양성분", "label_marker"),
    _rule("contains_context_spacing", r"함\s+유", "함유", "context"),
    _rule("cross_contact_context_spacing", r"혼\s+입", "혼입", "context"),
    _rule("facility_context_spacing", r"제조\s+시설", "제조시설", "context"),
    _rule("pork_spacing", r"돼\s*지\s*고\s*기", "돼지고기", "risk_term"),
    _rule("pork_meat_spacing", r"돈\s*육", "돈육", "risk_term"),
    _rule("pork_fat_spacing", r"돈\s*지", "돈지", "risk_term"),
    _rule("pork_skin_spacing", r"돈\s*피", "돈피", "risk_term"),
    _rule("beef_spacing", r"쇠\s*고\s*기|소\s*고\s*기", "쇠고기", "risk_term"),
    _rule("beef_meat_spacing", r"우\s*육", "우육", "risk_term"),
    _rule("chicken_spacing", r"닭\s*고\s*기", "닭고기", "risk_term"),
    _rule("chicken_meat_spacing", r"계\s*육", "계육", "risk_term"),
    _rule("gelatin_spacing", r"젤\s*라\s*틴", "젤라틴", "risk_term"),
    _rule("alcohol_spacing", r"알\s*코\s*올", "알코올", "risk_term"),
    _rule("ethanol_spacing", r"에\s*탄\s*올", "에탄올", "risk_term"),
    _rule("milk_spacing", r"우\s*유", "우유", "risk_term"),
    _rule("dairy_spacing", r"유\s*제\s*품", "유제품", "risk_term"),
    _rule("whey_spacing", r"유\s*청", "유청", "risk_term"),
    _rule("lactose_spacing", r"유\s*당", "유당", "risk_term"),
    _rule("skim_milk_powder_spacing", r"탈\s*지\s*분\s*유", "탈지분유", "risk_term"),
    _rule("whole_milk_powder_spacing", r"전\s*지\s*분\s*유", "전지분유", "risk_term"),
    _rule("mixed_milk_powder_spacing", r"혼\s*합\s*분\s*유", "혼합분유", "risk_term"),
    _rule("egg_spacing", r"계\s*란", "계란", "risk_term"),
    _rule("egg_class_spacing", r"난\s*류", "난류", "risk_term"),
    _rule("egg_white_spacing", r"난\s*백", "난백", "risk_term"),
    _rule("egg_yolk_spacing", r"난\s*황", "난황", "risk_term"),
    _rule("soy_spacing", r"대\s*두", "대두", "risk_term"),
    _rule("wheat_flour_spacing", r"밀\s*가\s*루", "밀가루", "risk_term"),
    _rule("gluten_spacing", r"글\s*루\s*텐", "글루텐", "risk_term"),
    _rule("buckwheat_spacing", r"메\s*밀", "메밀", "risk_term"),
    _rule("peanut_spacing", r"땅\s*콩", "땅콩", "risk_term"),
    _rule("tree_nut_spacing", r"견\s*과\s*류", "견과류", "risk_term"),
    _rule("walnut_spacing", r"호\s*두", "호두", "risk_term"),
    _rule("pine_nut_spacing", r"잣", "잣", "risk_term"),
    _rule("almond_spacing", r"아\s*몬\s*드", "아몬드", "risk_term"),
    _rule("cashew_spacing", r"캐\s*슈\s*넛", "캐슈넛", "risk_term"),
    _rule("pistachio_spacing", r"피\s*스\s*타\s*치\s*오", "피스타치오", "risk_term"),
    _rule("crustacean_spacing", r"갑\s*각\s*류", "갑각류", "risk_term"),
    _rule("seafood_spacing", r"어\s*패\s*류", "어패류", "risk_term"),
    _rule("shellfish_spacing", r"조\s*개\s*류", "조개류", "risk_term"),
    _rule("shrimp_spacing", r"새\s*우", "새우", "risk_term"),
    _rule("squid_spacing", r"오\s*징\s*어", "오징어", "risk_term"),
    _rule("mackerel_spacing", r"고\s*등\s*어", "고등어", "risk_term"),
    _rule("peach_spacing", r"복\s*숭\s*아", "복숭아", "risk_term"),
    _rule("tomato_spacing", r"토\s*마\s*토", "토마토", "risk_term"),
    _rule("sulfite_spacing", r"아\s*황\s*산\s*류", "아황산류", "risk_term"),
    _rule("sulfur_dioxide_spacing", r"이\s*산\s*화\s*황", "이산화황", "risk_term"),
    _rule("metabisulfite_spacing", r"메\s*타\s*중\s*아\s*황\s*산", "메타중아황산", "risk_term"),
    _rule("glycerin_fatty_ester_spacing", r"글\s*리\s*세\s*린\s*지\s*방\s*산\s*에\s*스\s*테\s*르", "글리세린지방산에스테르", "risk_term"),
    _rule("mono_glyceride_spacing", r"모\s*노\s*글\s*리\s*세\s*라\s*이\s*드", "모노글리세라이드", "risk_term"),
    _rule("di_glyceride_spacing", r"디\s*글\s*리\s*세\s*라\s*이\s*드", "디글리세라이드", "risk_term"),
    _rule("cochineal_spacing", r"코\s*치\s*닐", "코치닐", "risk_term"),
    _rule("carmine_spacing", r"카\s*르\s*민|카\s*민", "카민", "risk_term"),
    _rule("shellac_spacing", r"쉘\s*락", "쉘락", "risk_term"),
    _rule("sesame_spacing", r"참\s*깨", "참깨", "risk_term"),
)


def correct_ocr_text(text: str) -> tuple[str, list[dict[str, Any]]]:
    corrected = normalize_text(text)
    corrections: list[dict[str, Any]] = []

    for rule in CORRECTION_RULES:
        count = 0

        def replace(match: re.Match[str]) -> str:
            nonlocal count
            if match.group(0) == rule.replacement:
                return match.group(0)
            count += 1
            return rule.replacement

        corrected = rule.pattern.sub(replace, corrected)
        if count:
            corrections.append(
                {
                    "name": rule.name,
                    "category": rule.category,
                    "to": rule.replacement,
                    "count": count,
                }
            )

    return normalize_text(corrected), corrections
