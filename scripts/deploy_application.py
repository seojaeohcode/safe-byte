"""Stream a small deployment archive over SSH; no local secret staging files."""
import argparse
import io
import ipaddress
import os
from pathlib import Path
import re
import subprocess
import tarfile
import time
import sys
import json
from dotenv import dotenv_values
from mobile_check import TARGET, web_source_hash

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--host', required=True)
    p.add_argument('--key', required=True)
    p.add_argument('--daily-limit', type=int, default=50)
    p.add_argument('--paid', action='store_true')
    p.add_argument('--domain', default='')
    p.add_argument('--docs', action='store_true', help='Serve /docs and /openapi.json on the deployed server.')
    args = p.parse_args()
    ipaddress.ip_address(args.host)
    if not 0 <= args.daily_limit <= 1000:
        raise SystemExit('Invalid daily limit')
    if args.domain and not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', args.domain):
        raise SystemExit('Invalid hostname')
    env = {k:v for k,v in dotenv_values(ROOT/'.env', encoding='utf-8-sig').items() if v is not None and not k.startswith('NCLOUD_')}
    if not re.match(r'https://[^/]+\.apigw\.ntruss\.com/', env.get('CLOVA_OCR_INVOKE_URL','')) or not env.get('CLOVA_OCR_SECRET_KEY'):
        raise SystemExit('Configure the CLOVA Invoke URL and secret in .env')
    env.update(OCR_PROVIDER='clova', ALLOW_PAID_OCR=str(args.paid).lower(), OCR_DAILY_LIMIT=str(args.daily_limit),
               HTTP_BIND='0.0.0.0', HTTP_PORT='8080' if args.domain else '80',
               ENABLE_DOCS=str(args.docs).lower())
    for key in ['APP_UID','APP_GID','COMPOSE_FILE','SAFEBYTE_DOMAIN']:
        env.pop(key,None)
    if args.domain:
        env.update(SAFEBYTE_DOMAIN=args.domain, COMPOSE_FILE='docker-compose.yml:docker-compose.tls.yml')
    files = list(ROOT.glob('app/**/*.py')) + [ROOT/n for n in ['Dockerfile','.dockerignore','requirements.txt','docker-compose.yml','docker-compose.tls.yml','data/risk_rules.json','config/mfds_public_apis.json','web/index.html','web/app.js','web/styles.css','deploy/nginx.conf','deploy/Caddyfile']]
    web_build = TARGET/'build/web'
    stamp = web_build/'safebyte-build.json'
    if not stamp.exists() or json.loads(stamp.read_text(encoding='utf-8')).get('source_hash') != web_source_hash():
        subprocess.run([sys.executable, str(ROOT/'scripts/mobile_check.py'), 'build', 'web', '--release', '--base-href=/mobile/', '--no-pub'], check=True)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w:gz') as archive:
        def add(name, raw, mode=0o644):
            info = tarfile.TarInfo(name); info.size=len(raw); info.mode=mode
            archive.addfile(info,io.BytesIO(raw))
        for file in files:
            add(file.relative_to(ROOT).as_posix(),file.read_bytes(), 0o600 if file.name=='mfds_public_apis.json' else 0o644)
        for file in web_build.rglob('*'):
            if file.is_file():
                add('web/mobile/'+file.relative_to(web_build).as_posix(), file.read_bytes())
        add('web/config.js',b'window.SAFE_BYTE_API_BASE_URL = "";')
        # Quote literal values to preserve dollar signs and comment characters in dotenv.
        lines=[]
        for key,value in env.items():
            if '\n' in value or "'" in value:
                raise SystemExit('Runtime env values must be single-line without single quotes: '+key)
            lines.append(f"{key}='{value}'")
        add('.env', ('\n'.join(lines)+'\n').encode(),0o600)
    ssh=['ssh','-i',str(Path(args.key).expanduser()),'-o','BatchMode=yes','-o','ConnectTimeout=10','-o','StrictHostKeyChecking=accept-new',f'deploy@{args.host}']
    for attempt in range(30):
        result=subprocess.run([*ssh,'docker compose version >/dev/null'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        if result.returncode==0:
            break
        time.sleep(10)
    else:
        raise SystemExit('Bootstrap or SSH is not ready')
    subprocess.run([*ssh,'umask 077; cat > /tmp/safebyte-deploy.tgz'],input=buffer.getvalue(),check=True)
    command=r'''
set -e
cd /opt/safebyte
[ "$(pwd -P)" = /opt/safebyte ] || exit 1
if [ -f data/safe_byte.sqlite3 ]; then
  mkdir -p backups
  docker compose exec -T safebyte-api python -c "import sqlite3; a=sqlite3.connect('/app/data/safe_byte.sqlite3'); b=sqlite3.connect('/app/data/pre-deploy.sqlite3'); a.backup(b); b.close(); a.close()"
  mv data/pre-deploy.sqlite3 "backups/pre-deploy-$(date +%Y%m%d%H%M%S).sqlite3"
fi
tar -xzf /tmp/safebyte-deploy.tgz --no-same-owner
rm -f /tmp/safebyte-deploy.tgz
mkdir -p logs data/selected_ocr_samples
printf '\nAPP_UID=%s\nAPP_GID=%s\n' "$(id -u)" "$(id -g)" >> .env
chmod 600 .env
# Force recreate: a rebuilt image is useless while the old container keeps running.
docker compose up -d --build --force-recreate
# Recreate the file bind mount: replacing the host config can leave a running
# container attached to the old inode, even after an nginx reload.
docker compose up -d --force-recreate nginx
# The recreated container already loaded the new config, and the unprivileged
# image has no master PID to signal, so only validate it here.
docker compose exec -T nginx nginx -t
for attempt in $(seq 1 40); do
  if docker compose exec -T nginx wget -qO- http://127.0.0.1:8080/health; then exit 0; fi
  sleep 3
done
exit 1
'''
    subprocess.run([*ssh,command],check=True)
    print('Application deployed. '+('https://'+args.domain if args.domain else f'http://{args.host}:80'))


if __name__=='__main__':
    main()
