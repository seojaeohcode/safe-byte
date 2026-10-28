"""Check deliverable dimensions and bundled translation glyph coverage."""
from pathlib import Path
import unicodedata
from PIL import Image
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
phone = 'splash login criteria home_scan analyzing result_safe result_caution result_danger detail cart history account pairing_code'.split()
kiosk = 'connect ready preview safe caution danger'.split()
for name in phone + ['kiosk_' + state for state in kiosk]:
    with Image.open(root / 'screenshots' / (name + '.png')) as image:
        assert image.size == ((1024, 600) if name.startswith('kiosk_') else (1080, 2340)), (name, image.size)
glyphs = set()
for path in (root / 'mobile/assets/fonts').glob('*.ttf'):
    with TTFont(path) as font:
        glyphs.update(font.getBestCmap())
text = '\n'.join((root / 'mobile/lib' / name).read_text(encoding='utf-8') for name in ['l10n_data.dart', 'v2_strings.dart'])
missing = sorted({character for character in text if ord(character) not in glyphs and not unicodedata.category(character).startswith('C')})
assert not missing, f'Missing glyphs: {missing}'
print('PASS: 19 required PNG dimensions; complete bundled glyph coverage for both UI catalogues.')
