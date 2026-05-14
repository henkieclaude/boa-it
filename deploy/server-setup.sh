#!/usr/bin/env bash
# server-setup.sh — One-time bootstrap for a fresh Ubuntu 22.04/24.04 Kimsufi box.
#
# Run this ONCE as root after you SSH in for the first time:
#
#   wget https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/deploy/server-setup.sh
#   chmod +x server-setup.sh
#   sudo ./server-setup.sh
#
# After it finishes it prints the SSH private key you need to add to GitHub
# repo secrets as DEPLOY_SSH_KEY.

set -euo pipefail

DOMAIN="best-onlinecasinoaustralia.it.com"
DEPLOY_USER="deploy"
WEBROOT="/var/www/${DOMAIN}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo ./server-setup.sh)" >&2
  exit 1
fi

echo "==> Updating apt and installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  curl ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https \
  rsync ufw fail2ban unattended-upgrades

echo "==> Installing Caddy from official repo"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

echo "==> Creating deploy user"
if ! id -u "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
fi

echo "==> Preparing webroot at ${WEBROOT}"
mkdir -p "${WEBROOT}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${WEBROOT}"
# Caddy (running as the 'caddy' user) needs read access
chmod 755 /var/www
find "${WEBROOT}" -type d -exec chmod 755 {} \; 2>/dev/null || true

echo "==> Allowing deploy user to reload Caddy without a password"
cat >/etc/sudoers.d/deploy-caddy <<EOF
${DEPLOY_USER} ALL=(root) NOPASSWD: /bin/systemctl reload caddy, /bin/systemctl restart caddy, /usr/bin/cp /home/${DEPLOY_USER}/Caddyfile /etc/caddy/Caddyfile, /usr/bin/caddy validate --config /etc/caddy/Caddyfile
EOF
chmod 440 /etc/sudoers.d/deploy-caddy

echo "==> Generating SSH key for GitHub Actions"
SSH_DIR="/home/${DEPLOY_USER}/.ssh"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
if [[ ! -f "${SSH_DIR}/github_actions" ]]; then
  ssh-keygen -t ed25519 -N "" -f "${SSH_DIR}/github_actions" -C "github-actions@${DOMAIN}"
fi
touch "${SSH_DIR}/authorized_keys"
grep -qxF "$(cat "${SSH_DIR}/github_actions.pub")" "${SSH_DIR}/authorized_keys" \
  || cat "${SSH_DIR}/github_actions.pub" >> "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys" "${SSH_DIR}/github_actions"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${SSH_DIR}"

echo "==> Configuring firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Enabling unattended security updates"
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Creating log dir for Caddy"
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

echo "==> Placing a holding page until first deploy"
if [[ ! -f "${WEBROOT}/index.html" ]]; then
  cat >"${WEBROOT}/index.html" <<'HTML'
<!doctype html>
<title>Coming soon</title>
<h1>Coming soon.</h1>
HTML
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "${WEBROOT}/index.html"
fi

echo ""
echo "================================================================"
echo " Server bootstrap complete."
echo "================================================================"
echo ""
echo " 1. Point DNS at this server. Find this server's public IPv4:"
echo "      $(curl -4s ifconfig.me || echo '<run: curl -4 ifconfig.me>')"
echo "    At GoDaddy, create an A record for @ and www pointing here."
echo ""
echo " 2. Copy the Caddyfile from the repo onto the server, then start Caddy:"
echo "      sudo cp /path/to/Caddyfile /etc/caddy/Caddyfile"
echo "      sudo systemctl reload caddy"
echo "    (The GitHub Actions deploy does this automatically.)"
echo ""
echo " 3. Add the following GitHub repo secrets (Settings → Secrets and"
echo "    variables → Actions):"
echo ""
echo "      DEPLOY_HOST  = $(curl -4s ifconfig.me || echo '<server IPv4>')"
echo "      DEPLOY_USER  = ${DEPLOY_USER}"
echo "      DEPLOY_SSH_KEY = (the PRIVATE key below, including BEGIN/END lines)"
echo ""
echo "----------- BEGIN DEPLOY_SSH_KEY (copy everything between the lines) -----------"
cat "${SSH_DIR}/github_actions"
echo "----------- END DEPLOY_SSH_KEY -----------"
echo ""
echo " 4. Push to main on GitHub. The Actions workflow will deploy the site."
echo ""
