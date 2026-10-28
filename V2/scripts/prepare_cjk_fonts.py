"""Build deterministic 400/700 static faces from the SIL OFL variable fonts.

FontLoader golden rendering otherwise selects the variable font's default
100 weight for fallback glyphs. These faces also keep runtime weight consistent.
"""
from pathlib import Path
from urllib.request import urlopen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1] / 'mobile/assets/fonts'
for language in ('JP', 'SC'):
    family = 'NotoSans' + language
    source = root / (family + '-Variable.ttf')
    if not source.exists():
        url = f'https://raw.githubusercontent.com/google/fonts/main/ofl/{family.lower()}/{family}%5Bwght%5D.ttf'
        with urlopen(url, timeout=30) as response:
            source.write_bytes(response.read())
    for suffix, weight in [('Regular', 400), ('Bold', 700)]:
        font = TTFont(source)
        static = instantiateVariableFont(font, {'wght': weight}, inplace=True)
        static.save(root / f'{family}-{suffix}.ttf')
        font.close()
        print(f'{family}-{suffix}', flush=True)
    assert source.resolve().is_relative_to(root.resolve())
    source.unlink()
