"""Run Terraform with local credentials without echoing them or persisting them in state."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import hashlib
import json
from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parents[1]


def main():
    terraform = shutil.which('terraform') or str(ROOT / '.tools/terraform/terraform.exe')
    env = os.environ.copy()
    for key, value in dotenv_values(ROOT / 'infra/terraform/.env.ncloud', encoding='utf-8-sig').items():
        if key.startswith('NCLOUD_') and value:
            env[key] = value
    env['TF_IN_AUTOMATION'] = '1'
    # State contains private material and must not be a OneDrive placeholder.
    workspace_id = hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
    local = Path(os.environ.get('LOCALAPPDATA', Path.home()/'.local/share')) / 'SafeByte' / workspace_id
    local.mkdir(parents=True, exist_ok=True)
    state = local / 'terraform.tfstate'
    original = ROOT/'infra/terraform/terraform.tfstate'
    if not state.exists() and original.exists():
        raw = original.read_bytes()
        json.loads(raw)  # Never silently replace an unreadable state with an empty one.
        with state.open('xb') as target:
            target.write(raw)
    env['TF_DATA_DIR'] = str(local/'terraform-data')
    args = sys.argv[1:]
    if args and args[0] == 'init':
        args += ['-backend-config=path='+state.as_posix()]
    print('Terraform local data: '+str(local), file=sys.stderr, flush=True)
    result = subprocess.run([terraform, *args], cwd=ROOT/'infra/terraform', env=env)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
