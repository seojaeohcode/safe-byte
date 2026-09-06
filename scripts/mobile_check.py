"""Build the current mobile source outside cloud-synced folders (Windows-safe)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
TARGET = Path(os.environ.get('LOCALAPPDATA', Path.home()/'.local/share')) / 'SafeByte/mobile-work'


def web_source_hash():
    files = [ROOT/'mobile/pubspec.yaml', ROOT/'mobile/pubspec.lock']
    for name in ['lib', 'web', 'assets']:
        files.extend(p for p in (ROOT/'mobile'/name).rglob('*') if p.is_file())
    digest = hashlib.sha256()
    for path in sorted(files):
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main():
    source_revision = web_source_hash() if sys.argv[1:3] == ['build', 'web'] else None
    paths = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z', '--', 'mobile'], cwd=ROOT).decode().split('\0')
    for name in set(paths):
        if not name:
            continue
        source = ROOT/name
        if not source.is_file():
            continue
        target = TARGET/Path(name).relative_to('mobile')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    flutter = shutil.which('flutter')
    print('Mobile build workspace: '+str(TARGET), flush=True)
    subprocess.run([flutter, 'pub', 'get'], cwd=TARGET, check=True)
    subprocess.run([flutter, *(sys.argv[1:] or ['test', '--no-pub'])], cwd=TARGET, check=True)
    if '--update-goldens' in sys.argv:
        for image in (TARGET/'test/design_review').glob('*.png'):
            shutil.copyfile(image, ROOT/'mobile/test/design_review'/image.name)
    if sys.argv[1:3] == ['build', 'web']:
        (TARGET/'build/web/safebyte-build.json').write_text(json.dumps({'source_hash': source_revision}), encoding='utf-8')


if __name__ == '__main__':
    main()
