#!/bin/bash

################################################################################
# WP Express — VPS Bootstrap Script
#
# Hardens a fresh Hetzner Ubuntu 24.04 VPS and deploys the WP Express
# infrastructure: Traefik (reverse proxy + SSL) and shared MariaDB instances
# (production + staging).
#
# Usage:
#   1. Copy scripts/vps/.env.example to scripts/vps/.env and fill in values
#   2. scp the scripts/vps/ directory to the VPS:
#        scp -r scripts/vps/ root@<VPS-IP>:/opt/wp-express/
#   3. SSH into the VPS as root and run:
#        bash /opt/wp-express/bootstrap-vps.sh
#
# Safe to re-run (idempotent).
################################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header()  { echo -e "\n${BLUE}══════════════════════════════════════════${NC}"; \
            echo -e "${BLUE}  $1${NC}"; \
            echo -e "${BLUE}══════════════════════════════════════════${NC}\n"; }

################################################################################
# Prerequisites
################################################################################

[ "$(id -u)" -eq 0 ] || error "Must be run as root"

if ! grep -q 'Ubuntu 24' /etc/os-release 2>/dev/null; then
    warn "This script is tested on Ubuntu 24.04. Proceeding anyway..."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPS_DIR="${SCRIPT_DIR}"
ENV_FILE="${VPS_DIR}/.env"

[ -f "$ENV_FILE" ] || error ".env not found at ${ENV_FILE}. Copy .env.example → .env and fill in values."

# shellcheck source=/dev/null
source "$ENV_FILE"

# Validate required values
: "${ACME_EMAIL:?ACME_EMAIL must be set in .env}"
: "${BASE_DOMAIN:?BASE_DOMAIN must be set in .env}"
: "${TRAEFIK_DASHBOARD_USER:?TRAEFIK_DASHBOARD_USER must be set in .env}"
: "${TRAEFIK_DASHBOARD_PASSWORD:?TRAEFIK_DASHBOARD_PASSWORD must be set in .env}"
: "${DEPLOY_USER:=deploy}"

INFRA_DIR="/opt/wp-express"
CLIENTS_DIR="/opt/wp-express/clients"
TRAEFIK_DIR="${INFRA_DIR}/traefik"
MARIADB_PROD_DIR="${INFRA_DIR}/mariadb-production"
MARIADB_STAGING_DIR="${INFRA_DIR}/mariadb-staging"
BACKUP_DIR="${INFRA_DIR}/backup"

################################################################################
header "Step 1/9 — System update & essential packages"
################################################################################

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl wget git unzip htop ufw fail2ban \
    apache2-utils \
    ca-certificates gnupg lsb-release \
    unattended-upgrades apt-listchanges \
    logrotate

success "Packages installed"

# Enable unattended security upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
systemctl enable --now unattended-upgrades >/dev/null
success "Unattended security upgrades enabled"

################################################################################
header "Step 2/9 — Deploy user"
################################################################################

if id "$DEPLOY_USER" &>/dev/null; then
    info "User '${DEPLOY_USER}' already exists — skipping creation"
else
    useradd -m -s /bin/bash -G sudo,docker "$DEPLOY_USER"
    success "User '${DEPLOY_USER}' created"
fi

# Allow deploy user to run docker-compose without sudo
if ! groups "$DEPLOY_USER" | grep -q docker; then
    usermod -aG docker "$DEPLOY_USER"
fi

# SSH directory for deploy user
DEPLOY_HOME=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
mkdir -p "${DEPLOY_HOME}/.ssh"
chmod 700 "${DEPLOY_HOME}/.ssh"

# Copy root's authorized_keys to deploy user (preserves your access)
if [ -f /root/.ssh/authorized_keys ] && [ ! -f "${DEPLOY_HOME}/.ssh/authorized_keys" ]; then
    cp /root/.ssh/authorized_keys "${DEPLOY_HOME}/.ssh/authorized_keys"
    chmod 600 "${DEPLOY_HOME}/.ssh/authorized_keys"
    chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_HOME}/.ssh"
    success "SSH keys copied to ${DEPLOY_USER}"
fi

################################################################################
header "Step 3/9 — SSH hardening"
################################################################################

SSH_CONFIG="/etc/ssh/sshd_config.d/99-wp-express.conf"
if [ ! -f "$SSH_CONFIG" ]; then
    # PermitRootLogin stays 'yes' for now so you keep access during bootstrap.
    # Run the final lockdown step manually after verifying deploy user SSH works.
    cat > "$SSH_CONFIG" << 'EOF'
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    success "SSH hardened (password auth disabled; root login disabled after final step)"
else
    info "SSH config already applied — skipping"
fi

################################################################################
header "Step 4/9 — Firewall (UFW)"
################################################################################

ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp comment 'SSH' >/dev/null
ufw allow 80/tcp comment 'HTTP (Traefik)' >/dev/null
ufw allow 443/tcp comment 'HTTPS (Traefik)' >/dev/null
ufw --force enable >/dev/null
success "UFW enabled: ports 22, 80, 443 open"

################################################################################
header "Step 5/9 — Fail2ban (SSH protection)"
################################################################################

cat > /etc/fail2ban/jail.d/sshd.conf << 'EOF'
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 3600
findtime = 600
EOF

systemctl enable --now fail2ban >/dev/null
systemctl reload fail2ban >/dev/null
success "Fail2ban active for SSH"

################################################################################
header "Step 6/9 — Docker"
################################################################################

if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
else
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh >/dev/null
    systemctl enable --now docker >/dev/null
    success "Docker installed"
fi

# Create shared Docker networks (idempotent)
for NETWORK in traefik_web mariadb_prod_net mariadb_staging_net; do
    if ! docker network inspect "$NETWORK" &>/dev/null; then
        docker network create "$NETWORK" >/dev/null
        success "Docker network '${NETWORK}' created"
    else
        info "Docker network '${NETWORK}' already exists"
    fi
done

################################################################################
header "Step 7/9 — Traefik"
################################################################################

mkdir -p "${TRAEFIK_DIR}/acme" "${TRAEFIK_DIR}/logs" "${TRAEFIK_DIR}/dynamic"

# Copy config files from this script's directory (skip if already in place)
if [ "${VPS_DIR}/traefik" != "${TRAEFIK_DIR}" ]; then
    cp "${VPS_DIR}/traefik/traefik.yml"                  "${TRAEFIK_DIR}/traefik.yml"
    cp "${VPS_DIR}/traefik/dynamic/middlewares.yml"       "${TRAEFIK_DIR}/dynamic/middlewares.yml"
    cp "${VPS_DIR}/traefik/docker-compose.yml"            "${TRAEFIK_DIR}/docker-compose.yml"
fi

# Traefik does not substitute env vars in traefik.yml — write email directly
sed -i "s|email: \"\${ACME_EMAIL}\"|email: \"${ACME_EMAIL}\"|" "${TRAEFIK_DIR}/traefik.yml"

# acme.json must exist with 600 permissions before Traefik starts
ACME_JSON="${TRAEFIK_DIR}/acme/acme.json"
[ -f "$ACME_JSON" ] || touch "$ACME_JSON"
chmod 600 "$ACME_JSON"

# Generate htpasswd for dashboard
# Escape $ → $$ so Docker Compose doesn't interpret the hash as variable substitutions
TRAEFIK_DASHBOARD_AUTH=$(htpasswd -nb "$TRAEFIK_DASHBOARD_USER" "$TRAEFIK_DASHBOARD_PASSWORD" | sed 's/\$/\$\$/g')

# Write Traefik .env
cat > "${TRAEFIK_DIR}/.env" << EOF
ACME_EMAIL=${ACME_EMAIL}
BASE_DOMAIN=${BASE_DOMAIN}
TRAEFIK_DASHBOARD_AUTH=${TRAEFIK_DASHBOARD_AUTH}
EOF
chmod 600 "${TRAEFIK_DIR}/.env"

cd "${TRAEFIK_DIR}"
docker compose --env-file .env up -d
success "Traefik running — dashboard at https://traefik.${BASE_DOMAIN}"

################################################################################
header "Step 8/9 — Shared MariaDB (production + staging)"
################################################################################

setup_mariadb() {
    local NAME=$1         # e.g. mariadb-production
    local DIR=$2          # e.g. /opt/wp-express/mariadb-production
    local PASS_VAR=$3     # e.g. MARIADB_PROD_ROOT_PASSWORD
    local CONTAINER=$4    # e.g. mariadb_prod

    mkdir -p "${DIR}/secrets"

    # Generate root password if not provided
    local ROOT_PASS="${!PASS_VAR:-}"
    if [ -z "$ROOT_PASS" ]; then
        ROOT_PASS=$(openssl rand -base64 32 | tr -d '\n/+=')
        info "${NAME}: generated root password"
    fi

    # Save password to secrets file
    echo -n "$ROOT_PASS" > "${DIR}/secrets/root_password"
    chmod 600 "${DIR}/secrets/root_password"
    chown root:root "${DIR}/secrets/root_password"

    # Copy config files (skip if already in place)
    if [ "${VPS_DIR}/${NAME}" != "${DIR}" ]; then
        cp "${VPS_DIR}/${NAME}/docker-compose.yml" "${DIR}/docker-compose.yml"
        cp "${VPS_DIR}/${NAME}/my.cnf"             "${DIR}/my.cnf"
    fi

    cd "$DIR"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        info "${CONTAINER} already running"
    else
        docker compose up -d
        # Wait for healthy
        info "Waiting for ${CONTAINER} to be ready..."
        local attempts=0
        until docker exec "${CONTAINER}" mariadb -u root -p"${ROOT_PASS}" -e "SELECT 1" &>/dev/null; do
            sleep 3; attempts=$((attempts+1))
            [ $attempts -lt 20 ] || error "${CONTAINER} did not become ready"
        done
        success "${CONTAINER} is ready"
    fi
}

setup_mariadb "mariadb-production" "$MARIADB_PROD_DIR"    "MARIADB_PROD_ROOT_PASSWORD"    "mariadb_prod"
setup_mariadb "mariadb-staging"    "$MARIADB_STAGING_DIR" "MARIADB_STAGING_ROOT_PASSWORD" "mariadb_staging"

################################################################################
header "Step 9/9 — Backup (rclone + cron)"
################################################################################

# Install rclone
if ! command -v rclone &>/dev/null; then
    info "Installing rclone..."
    curl -fsSL https://rclone.org/install.sh | bash >/dev/null
    success "rclone installed"
else
    info "rclone already installed"
fi

# Configure rclone for Hetzner Object Storage if credentials are provided
if [ -n "${HETZNER_S3_ACCESS_KEY:-}" ] && [ -n "${HETZNER_S3_SECRET_KEY:-}" ]; then
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf << EOF
[hetzner-s3]
type = s3
provider = Other
env_auth = false
access_key_id = ${HETZNER_S3_ACCESS_KEY}
secret_access_key = ${HETZNER_S3_SECRET_KEY}
endpoint = ${HETZNER_S3_ENDPOINT}
acl = private
EOF
    chmod 600 /root/.config/rclone/rclone.conf
    success "rclone configured for Hetzner Object Storage"
else
    warn "Hetzner S3 credentials not set — backups will be local only"
    warn "Edit ${VPS_DIR}/.env and re-run to enable cloud backups"
fi

# Copy backup script and set up cron
mkdir -p "${BACKUP_DIR}/dumps"
if [ "${VPS_DIR}/backup" != "${BACKUP_DIR}" ]; then
    cp "${VPS_DIR}/backup/backup.sh" "${BACKUP_DIR}/backup.sh"
fi
chmod +x "${BACKUP_DIR}/backup.sh"

CRON_ENTRY="0 * * * * /opt/wp-express/backup/backup.sh >> /opt/wp-express/backup/backup.log 2>&1"
if ! crontab -l 2>/dev/null | grep -q "backup.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    success "Hourly backup cron job installed"
else
    info "Backup cron already installed"
fi

# Create client directories
mkdir -p "$CLIENTS_DIR"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$CLIENTS_DIR"

################################################################################
header "✅  Bootstrap complete!"
################################################################################

echo ""
echo -e "${GREEN}Infrastructure is running:${NC}"
echo ""
echo "  🔀  Traefik           → https://traefik.${BASE_DOMAIN}"
echo "  🗄️   MariaDB (prod)    → container: mariadb_prod    | network: mariadb_prod_net"
echo "  🗄️   MariaDB (staging) → container: mariadb_staging | network: mariadb_staging_net"
echo ""
echo -e "${CYAN}Secrets stored in:${NC}"
echo "  ${MARIADB_PROD_DIR}/secrets/root_password"
echo "  ${MARIADB_STAGING_DIR}/secrets/root_password"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Verify DNS: *.${BASE_DOMAIN} → $(curl -sf https://api.ipify.org || echo '<VPS IP>')"
echo "  2. Deploy your first site: deploy.sh local staging <client-name>"
echo ""
echo -e "${YELLOW}⚠  Keep secrets/root_password files backed up securely!${NC}"
echo ""
echo -e "${YELLOW}🔒  Final lockdown (run when deploy user SSH is verified):${NC}"
echo "  sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config.d/99-wp-express.conf"
echo "  systemctl reload ssh"
echo "  # Then update ~/.ssh/config: change User from root → deploy"
