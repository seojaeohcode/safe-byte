#!/bin/bash
set -euxo pipefail

DEPLOY_USER="${deploy_user}"
APP_DIR="${app_dir}"
SSH_KEY="${admin_ssh_public_key}"
SSH_ALLOWED_CIDR="${ssh_allowed_cidr}"
WEB_ALLOWED_CIDR="${web_allowed_cidr}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl fail2ban gnupg rsync ufw unattended-upgrades

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
fi

usermod -aG docker "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
printf '%s\n' "$SSH_KEY" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

mkdir -p "$APP_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR"

printf '%s\n' \
  'PasswordAuthentication no' \
  'PermitRootLogin no' \
  'PubkeyAuthentication yes' \
  'MaxAuthTries 3' \
  "AllowUsers $DEPLOY_USER" \
  > /etc/ssh/sshd_config.d/99-safebyte-hardening.conf

printf '%s\n' \
  '[sshd]' \
  'enabled = true' \
  'maxretry = 3' \
  'findtime = 10m' \
  'bantime = 1h' \
  > /etc/fail2ban/jail.d/sshd.local

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
# ACG restricts source IP for SSH. Keeping host UFW tied to the same
# ever-changing client IP can lock out deployment after a network change.
ufw limit 22/tcp
ufw allow from "$WEB_ALLOWED_CIDR" to any port 80 proto tcp
ufw allow from "$WEB_ALLOWED_CIDR" to any port 443 proto tcp
ufw --force enable

printf '%s\n' \
  'net.ipv4.conf.all.accept_redirects = 0' \
  'net.ipv4.conf.default.accept_redirects = 0' \
  'net.ipv4.conf.all.send_redirects = 0' \
  'net.ipv4.conf.default.send_redirects = 0' \
  'net.ipv4.conf.all.accept_source_route = 0' \
  'net.ipv4.conf.default.accept_source_route = 0' \
  'net.ipv4.tcp_syncookies = 1' \
  > /etc/sysctl.d/99-safebyte-hardening.conf
sysctl --system

dpkg-reconfigure -f noninteractive unattended-upgrades

systemctl enable --now docker
systemctl enable --now fail2ban
systemctl reload ssh || systemctl reload sshd
