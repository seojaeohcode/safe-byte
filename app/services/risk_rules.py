from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from app.services.profile_tokens import (
    base_profile_enabled,
    selected_allergen_keys,
)
from app.services.text_parser import compact_for_match, evidence_window, normalize_text


SEVERITY_RANK = {"safe": 0, "caution": 1, "danger": 2}
OCCURRENCE_RANK = {"cross_contact": 0, "unknown": 1, "direct": 2}

CROSS_CONTACT_PATTERNS = [
    "같은제조시설",
    "같은생산시설",
    "같은생산라인",
    "같은라인",
    "같은공정",
    "같은시설에서제조",
    "같은제조시설에서제조",
    "제조시설에서함께",
    "제조공정상혼입",
    "사용한제품과같은",
    "사용한제품과같은시설",
    "사용한제품과같은제조시설",
    "사용하는제품과같은",
    "취급하는제품과같은",
    "혼입가능",
    "혼입될수",
    "혼입될가능",
    "혼입될우려",
    "교차오염",
    "crosscontact",
    "maycontain",
]

DIRECT_CONTEXT_PATTERNS = [
    "원재료명",
    "원료명",
    "원재료",
    "함유",
    "포함",
    "첨가",
    "사용",
    "혼합분유",
    "추출물",
    "분말",
    "페이스트",
    "농축",
]

NEGATED_CONTEXT_PATTERNS = [
    "{keyword}무첨가",
    "{keyword}무함유",
    "{keyword}불검출",
    "{keyword}미함유",
    "{keyword}프리",
    "{keyword}free",
    "{keyword}없음",
    "{keyword}제외",
    "무{keyword}",
    "{keyword}을함유하지않",
    "{keyword}를함유하지않",
    "{keyword}이들어있지않",
    "{keyword}가들어있지않",
]


class RiskRuleEngine:
    def __init__(self, rules_path: Path):
        self.rules_path = rules_path
        self.rules: list[dict[str, Any]] = []
        self.reload()

    def reload(self) -> None:
        with self.rules_path.open(encoding="utf-8") as f:
            payload = json.load(f)
        self.rules = payload.get("rules", [])

    def list_rules(self) -> list[dict[str, Any]]:
        return self.rules

    def detect(self, text: str, profiles: list[str] | None = None) -> dict[str, Any]:
        profiles = profiles or ["halal", "vegan", "allergy"]
        selected_allergens = selected_allergen_keys(profiles)
        normalized = normalize_text(text)
        compact_text = compact_for_match(normalized)
        detections_by_key: dict[tuple[str, str], dict[str, Any]] = {}

        for rule in self.rules:
            if not self._rule_matches_profiles(rule, profiles, selected_allergens):
                continue

            for keyword in rule.get("keywords", []):
                compact_keyword = compact_for_match(str(keyword))
                if not compact_keyword:
                    continue
                matches = self._keyword_matches(
                    normalized, compact_text, str(keyword), compact_keyword
                )
                for position in matches:
                    detection = self._build_detection(normalized, rule, str(keyword), position)
                    if detection is None:
                        continue
                    key = (detection["category"], detection["canonical_name"])
                    existing = detections_by_key.get(key)
                    detections_by_key[key] = self._merge_detection(existing, detection)

        detections = list(detections_by_key.values())
        detections.sort(
            key=lambda item: (
                SEVERITY_RANK.get(item["severity"], 0),
                OCCURRENCE_RANK.get(item.get("occurrence_type", "unknown"), 0),
                item["confidence"],
                item["canonical_name"],
            ),
            reverse=True,
        )
        final_level = self.final_level(detections)
        return {
            "final_level": final_level,
            "detections": detections,
            "summary": self.summary(final_level, detections),
        }

    def _build_detection(
        self,
        normalized_text: str,
        rule: dict[str, Any],
        keyword: str,
        position: int,
    ) -> dict[str, Any] | None:
        context = self._context_window(normalized_text, position, keyword, radius=260)
        local_context = self._context_window(normalized_text, position, keyword, radius=90)
        statement_context = self._statement_window(normalized_text, position, keyword)
        if position >= 0:
            suffix = compact_for_match(normalized_text[position:position + len(keyword) + 18])
            compact_keyword = compact_for_match(keyword)
            if any(suffix.startswith(t.format(keyword=compact_keyword)) for t in NEGATED_CONTEXT_PATTERNS if not t.startswith("무")):
                return None
            if normalized_text[max(0, position - 1):position] == "무":
                return None
        if self._skip_detection(rule, keyword, statement_context, local_context):
            return None
        occurrence_type = self._classify_occurrence(statement_context, local_context, context)
        severity = str(rule["severity"])
        confidence = float(rule.get("confidence", 0.85))
        reason = str(rule["reason"])

        if occurrence_type == "cross_contact":
            severity = "caution"
            confidence = min(confidence, 0.78)
            reason = (
                f"{rule['canonical_name']}\uc740 \ub77c\ubca8\uc758 "
                "'\uac19\uc740 \uc81c\uc870\uc2dc\uc124\uc5d0\uc11c "
                "\uc81c\uc870' \ubb38\uad6c\uc5d0\uc11c \ud655\uc778\ub418\uc5c8\uc2b5\ub2c8\ub2e4. "
                "\uc9c1\uc811 \uc6d0\uc7ac\ub8cc \ud568\uc720\ub85c "
                "\ud310\ub2e8\ud558\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4."
            )

        if occurrence_type == "unknown":
            severity = "caution"
            confidence = min(confidence, 0.6)
            reason = f"{rule['canonical_name']}: 함유 문맥을 확인할 수 없어 추가 확인이 필요합니다."

        return {
            "rule_id": rule["id"],
            "category": str(rule["category"]),
            "severity": severity,
            "canonical_name": rule["canonical_name"],
            "allergen_key": rule.get("allergen_key"),
            "decision_basis": rule.get("decision_basis", "keyword_match"),
            "matched_keyword": keyword,
            "matched_keywords": [keyword],
            "reason": reason,
            "confidence": confidence,
            "evidence": self._trim_context(context),
            "occurrence_type": occurrence_type,
            "occurrence_label": self._occurrence_label(occurrence_type),
        }

    @staticmethod
    def _rule_matches_profiles(
        rule: dict[str, Any],
        profiles: list[str],
        selected_allergens: set[str],
    ) -> bool:
        category = str(rule["category"])
        if "all" in profiles:
            return True

        profile_tokens = set(str(item).lower() for item in rule.get("profile_tokens", []))
        if profile_tokens and profile_tokens.intersection(profiles):
            return True

        if category == "allergy":
            allergen_key = str(rule.get("allergen_key", ""))
            if allergen_key and allergen_key in selected_allergens:
                return True
            return "allergy" in profiles and bool(rule.get("default_in_allergy", True))

        if category == "vegetarian":
            return base_profile_enabled(profiles, "vegetarian")

        return base_profile_enabled(profiles, category)

    @staticmethod
    def _skip_detection(
        rule: dict[str, Any],
        keyword: str,
        statement_context: str,
        local_context: str,
    ) -> bool:
        compact_keyword = compact_for_match(keyword)
        compact_statement = compact_for_match(statement_context)
        compact_local = compact_for_match(local_context)
        compact_context = f"{compact_statement} {compact_local}"

        for pattern in rule.get("skip_context_patterns", []):
            if compact_for_match(str(pattern)) in compact_context:
                return True

        return False

    @staticmethod
    def _merge_detection(
        existing: dict[str, Any] | None,
        candidate: dict[str, Any],
    ) -> dict[str, Any]:
        if existing is None:
            return candidate

        existing_score = (
            SEVERITY_RANK.get(existing["severity"], 0),
            OCCURRENCE_RANK.get(existing.get("occurrence_type", "unknown"), 0),
            existing["confidence"],
        )
        candidate_score = (
            SEVERITY_RANK.get(candidate["severity"], 0),
            OCCURRENCE_RANK.get(candidate.get("occurrence_type", "unknown"), 0),
            candidate["confidence"],
        )
        if candidate_score > existing_score:
            winner, loser = candidate, existing
        else:
            winner, loser = existing, candidate

        keywords = list(winner.get("matched_keywords", [winner["matched_keyword"]]))
        for keyword in loser.get("matched_keywords", [loser["matched_keyword"]]):
            if keyword not in keywords:
                keywords.append(keyword)
        winner["matched_keywords"] = keywords
        winner["matched_keyword"] = ", ".join(keywords)
        return winner

    @staticmethod
    def _keyword_matches(
        normalized_text: str,
        compact_text: str,
        keyword: str,
        compact_keyword: str,
    ) -> list[int]:
        if len(compact_keyword) == 1 and re.fullmatch(r"[가-힣]", compact_keyword):
            return [
                match.start()
                for match in re.finditer(
                    rf"(?<![가-힣A-Za-z0-9]){re.escape(keyword)}(?![가-힣A-Za-z0-9])",
                    normalized_text,
                    flags=re.I,
                )
            ]

        exact_matches = [
            match.start()
            for match in re.finditer(re.escape(keyword), normalized_text, flags=re.I)
        ]
        if exact_matches:
            return exact_matches
        if re.fullmatch(r"[a-z0-9]+", compact_keyword) and compact_keyword in compact_text:
            return [-1]
        return []

    @staticmethod
    def _context_window(text: str, position: int, keyword: str, radius: int = 260) -> str:
        if position < 0:
            return evidence_window(text, keyword, radius)
        start = max(0, position - radius)
        end = min(len(text), position + len(keyword) + radius)
        return text[start:end].replace("\n", " ")

    @staticmethod
    def _statement_window(text: str, position: int, keyword: str, radius: int = 320) -> str:
        if position < 0:
            return evidence_window(text, keyword, radius)

        left_limit = max(0, position - radius)
        right_limit = min(len(text), position + len(keyword) + radius)
        left_slice = text[left_limit:position]
        right_slice = text[position:right_limit]

        left_boundary = max(left_slice.rfind(mark) for mark in ["\n", ".", "。", "·", "•"])
        start = left_limit if left_boundary < 0 else left_limit + left_boundary + 1

        right_candidates = [
            idx for idx in [right_slice.find(mark) for mark in ["\n", ".", "。", "·", "•"]]
            if idx >= 0
        ]
        end = right_limit if not right_candidates else position + min(right_candidates)
        return text[start:end].replace("\n", " ")

    @staticmethod
    def _classify_occurrence(
        statement_context: str,
        local_context: str,
        wide_context: str,
    ) -> str:
        compact_statement = compact_for_match(statement_context)
        compact_local = compact_for_match(local_context)
        compact_wide = compact_for_match(wide_context)
        if any(pattern in compact_statement for pattern in CROSS_CONTACT_PATTERNS):
            return "cross_contact"
        if any(pattern in compact_statement for pattern in DIRECT_CONTEXT_PATTERNS):
            return "direct"
        if any(pattern in compact_local for pattern in CROSS_CONTACT_PATTERNS):
            return "cross_contact"
        if any(pattern in compact_local for pattern in DIRECT_CONTEXT_PATTERNS):
            return "direct"
        if any(pattern in compact_wide for pattern in CROSS_CONTACT_PATTERNS):
            return "cross_contact"
        if any(pattern in compact_wide for pattern in DIRECT_CONTEXT_PATTERNS):
            return "direct"
        return "unknown"

    @staticmethod
    def _trim_context(context: str, limit: int = 220) -> str:
        context = re.sub(r"\s+", " ", context).strip()
        if len(context) <= limit:
            return context
        return context[:limit].rstrip() + "..."

    @staticmethod
    def _occurrence_label(occurrence_type: str) -> str:
        return {
            "direct": "\uc9c1\uc811 \ud568\uc720",
            "cross_contact": "\uc81c\uc870\uc2dc\uc124 \uacf5\uc720",
            "unknown": "\ubb38\ub9e5 \ud655\uc778",
        }.get(occurrence_type, "\ubb38\ub9e5 \ud655\uc778")

    @staticmethod
    def final_level(detections: list[dict[str, Any]]) -> str:
        if any(item["severity"] == "danger" for item in detections):
            return "DANGER"
        if any(item["severity"] == "caution" for item in detections):
            return "CAUTION"
        return "SAFE"

    @staticmethod
    def summary(final_level: str, detections: list[dict[str, Any]]) -> str:
        if final_level == "SAFE":
            return (
                "\uc124\uc815\ud55c \ud504\ub85c\ud544 \uae30\uc900\uc73c\ub85c "
                "\uc704\ud5d8 \uc131\ubd84 \ud0a4\uc6cc\ub4dc\uac00 "
                "\uac10\uc9c0\ub418\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4."
            )

        direct_danger_names = []
        direct_caution_names = []
        cross_contact_names = []
        unknown_names = []
        for item in detections:
            name = item["canonical_name"]
            occurrence_type = item.get("occurrence_type")
            if occurrence_type == "cross_contact":
                target = cross_contact_names
            elif occurrence_type == "direct" and item.get("severity") == "danger":
                target = direct_danger_names
            elif occurrence_type == "direct":
                target = direct_caution_names
            else:
                target = unknown_names
            if name not in target:
                target.append(name)

        parts = []
        if direct_danger_names:
            parts.append(f"\uc9c1\uc811 \ud568\uc720 \uc8fc\uc758 \uc131\ubd84: {', '.join(direct_danger_names[:6])}")
        if direct_caution_names:
            parts.append(f"\ucd94\uac00 \ud655\uc778 \uc131\ubd84: {', '.join(direct_caution_names[:5])}")
        if unknown_names:
            parts.append(f"\ubb38\ub9e5 \ud655\uc778 \ud544\uc694: {', '.join(unknown_names[:5])}")
        if cross_contact_names:
            cross_preview = ", ".join(cross_contact_names[:5])
            more = len(cross_contact_names) - 5
            suffix = f" \uc678 {more}\uac74" if more > 0 else ""
            parts.append(
                "\uc81c\uc870\uc2dc\uc124 \uacf5\uc720 \ud45c\uae30"
                f"(\uc9c1\uc811 \ud568\uc720 \uc544\ub2d8): {cross_preview}{suffix}"
            )

        if final_level == "DANGER":
            return ". ".join(parts)
        if cross_contact_names and not direct_caution_names and not unknown_names:
            return (
                "\uc9c1\uc811 \ud568\uc720 \uc704\ud5d8 \uc131\ubd84\uc740 "
                "\ud655\uc778\ub418\uc9c0 \uc54a\uc558\uace0, "
                f"\uc81c\uc870\uc2dc\uc124 \uacf5\uc720 \ud45c\uae30\uc5d0\uc11c {', '.join(cross_contact_names[:5])}"
                "\uc774/\uac00 \ud655\uc778\ub418\uc5c8\uc2b5\ub2c8\ub2e4."
            )
        return ". ".join(parts)
