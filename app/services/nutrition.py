"""Extract label amounts as unverified candidates; aggregate only user-confirmed amounts."""
import re

NUTRIENTS = {'energy_kcal': ('열량', 'kcal'), 'sodium_mg': ('나트륨', 'mg'),
             'carbohydrate_g': ('탄수화물', 'g'), 'sugars_g': ('당류', 'g'),
             'fat_g': ('지방', 'g'), 'saturated_fat_g': ('포화지방', 'g'),
             'protein_g': ('단백질', 'g')}


def extract_nutrition(text):
    values = {}
    section = text[text.find('영양정보'):] if '영양정보' in text else text
    for key, (name, unit) in NUTRIENTS.items():
        pattern = (r'(\d+(?:\.\d+)?)\s*kcal' if key == 'energy_kcal' else
                   rf'(?<![가-힣]){name}\s*[:：]?\s*(\d+(?:\.\d+)?)\s*{unit}\b')
        match = re.search(pattern, section, re.I)
        if match:
            values[key] = float(match.group(1))
    basis = re.search(r'(?:총\s*내용량\s*(?:당)?|100\s*(?:g|ml)\s*당|1\s*회\s*(?:제공량|분량)[^\n]{0,30})', section, re.I)
    return {'status': 'unverified' if values else 'not_found', 'values': values,
            'basis_text': basis.group(0) if basis else None,
            'note': '라벨의 기준량을 확인한 뒤 상품 1개 전체의 영양성분으로 입력하세요.'}
