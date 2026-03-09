#!/bin/bash

################################################################################
# WP Express — Deploy Script
#
# Usage (from anywhere, pass client name):
#   ./deploy.sh local    staging    <client-name> [options]
#   ./deploy.sh staging  production <client-name> [--domain acme-corp.com]
#   ./deploy.sh local    production <client-name> [--domain acme-corp.com]
#
# Options:
#   --domain <domain>   Production domain (required for first production deploy)
#   --skip-db           Skip database sync (code + uploads only)
#   --skip-uploads      Skip uploads rsync
#   --fresh             Force fresh WP install on target (wipes existing data)
#   --help
#
# Prerequisites:
#   - scripts/vps/.env must have VPS_HOST, VPS_SSH_USER, VPS_SSH_KEY
#   - VPS bootstrapped with bootstrap-vps.sh
#   - Client project exists under clients/<client-name>/
#   - GitHub repo configured in clients/<client-name>/.wp-express-project
#   - Local Docker stack is running for 'local' source deploys
################################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${CYAN}[deploy]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC}     $1"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }
step()    { echo -e "\n${BLUE}▶ $1${NC}"; }

################################################################################
# Argument parsing
################################################################################

show_usage() {
    cat << 'EOF'
Usage: deploy.sh <source> <target> <client-name> [options]

Directions:
  local    staging    <client>              Push local site to staging
  staging  production <client> --domain <> Promote staging to production
  local    production <client> --domain <> Emergency: local directly to prod

Options:
  --domain <domain>   Production domain (e.g. acme-corp.com)
  --skip-db           Skip database sync
  --skip-uploads      Skip uploads rsync
  --fresh             Force fresh WordPress install on target
  --help

Examples:
  ./deploy.sh local staging acme-corp
  ./deploy.sh staging production acme-corp --domain acme-corp.com
EOF
}

[[ $# -lt 3 ]] && { show_usage; exit 1; }

SOURCE=$1; TARGET=$2; CLIENT_NAME=$3; shift 3

DOMAIN=""
SKIP_DB=false
SKIP_UPLOADS=false
FRESH_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)       DOMAIN="$2"; shift 2 ;;
        --skip-db)      SKIP_DB=true; shift ;;
        --skip-uploads) SKIP_UPLOADS=true; shift ;;
        --fresh)        FRESH_INSTALL=true; shift ;;
        --help|-h)      show_usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

[[ "$SOURCE" =~ ^(local|staging)$ ]]     || error "Source must be 'local' or 'staging'"
[[ "$TARGET" =~ ^(staging|production)$ ]] || error "Target must be 'staging' or 'production'"
[[ "$SOURCE" == "$TARGET" ]]              && error "Source and target must differ"

################################################################################
# Configuration loading
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPS_ENV="${SCRIPT_DIR}/vps/.env"
CLIENTS_DIR="$(dirname "$SCRIPT_DIR")/clients"
CLIENT_DIR="${CLIENTS_DIR}/${CLIENT_NAME}"
PROJECT_META="${CLIENT_DIR}/.wp-express-project"

[[ -f "$VPS_ENV" ]]       || error "VPS config not found: ${VPS_ENV}\nCopy scripts/vps/.env.example → scripts/vps/.env and fill in VPS_HOST."
[[ -d "$CLIENT_DIR" ]]    || error "Client project not found: ${CLIENT_DIR}"
[[ -f "$PROJECT_META" ]]  || error ".wp-express-project not found in ${CLIENT_DIR}"

# shellcheck source=/dev/null
source "$VPS_ENV"

: "${VPS_HOST:?VPS_HOST must be set in scripts/vps/.env}"
: "${VPS_SSH_USER:=deploy}"
: "${VPS_SSH_KEY:=~/.ssh/id_rsa}"

VPS_SSH_OPTS="-i ${VPS_SSH_KEY} -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=10"
VPS_CLIENTS_DIR="/opt/wp-express/clients"

# Read client metadata
GITHUB_REPO=$(python3 -c "import json,sys; d=json.load(open('${PROJECT_META}')); print(d.get('github_repo',''))" 2>/dev/null || true)
LOCAL_URL=$(grep '^WP_HOME=' "${CLIENT_DIR}/.env" 2>/dev/null | cut -d= -f2- | tr -d "'" | tr -d '"')

# Base domain from VPS env
BASE_DOMAIN="${BASE_DOMAIN:-webdeveloping.hu}"

# Derived values
STAGING_DOMAIN="${CLIENT_NAME}.${BASE_DOMAIN}"
STAGING_URL="https://${STAGING_DOMAIN}"

if [[ "$TARGET" == "production" ]]; then
    [[ -z "$DOMAIN" ]] && {
        # Try reading from existing production .env on VPS
        DOMAIN=$(vps_run "grep '^SITE_DOMAIN=' ${VPS_CLIENTS_DIR}/${CLIENT_NAME}/production/.env 2>/dev/null | cut -d= -f2" 2>/dev/null || true)
    }
    [[ -z "$DOMAIN" ]] && error "Production domain required. Pass --domain acme-corp.com"
    PROD_URL="https://${DOMAIN}"
fi

echo ""
echo -e "${BLUE}WP Express Deploy${NC}"
echo -e "${BLUE}─────────────────────────────────────────${NC}"
echo "  Client:  ${CLIENT_NAME}"
echo "  Source:  ${SOURCE}"
echo "  Target:  ${TARGET}"
[[ "$TARGET" == "staging" ]]    && echo "  URL:     ${STAGING_URL}"
[[ "$TARGET" == "production" ]] && echo "  URL:     ${PROD_URL}"
echo ""

################################################################################
# Utility functions
################################################################################

vps_run() {
    # shellcheck disable=SC2086
    ssh ${VPS_SSH_OPTS} "${VPS_SSH_USER}@${VPS_HOST}" "$@"
}

# Run WP-CLI in a container on the VPS
# Usage: vps_wp <container_name> <wp-cli args...>
vps_wp() {
    local container=$1; shift
    vps_run "docker exec -i ${container} vendor/bin/wp --allow-root $*"
}

# Detect local compose file and container prefix from running containers
detect_local_env() {
    if docker ps --format '{{.Names}}' | grep -q 'wp_.*_m1'; then
        LOCAL_COMPOSE_FILE="docker-compose.apple-silicon.yml"
        LOCAL_PHP_CONTAINER="wp_php_m1"
    elif docker ps --format '{{.Names}}' | grep -q 'wp_.*_intel'; then
        LOCAL_COMPOSE_FILE="docker-compose.intel.yml"
        LOCAL_PHP_CONTAINER="wp_php_intel"
    else
        error "No local Docker stack running. Start with 'make apple-silicon' or 'make intel'."
    fi
}

# Run WP-CLI locally inside the running PHP container
local_wp() {
    docker exec -i "$LOCAL_PHP_CONTAINER" vendor/bin/wp --allow-root "$@"
}

# Generate a random password
gen_password() {
    openssl rand -base64 24 | tr -d '\n/+=' | cut -c1-20
}

# Check VPS reachability
check_vps() {
    step "Checking VPS connectivity"
    vps_run "echo 'VPS reachable'" >/dev/null 2>&1 || \
        error "Cannot reach VPS at ${VPS_HOST} with user ${VPS_SSH_USER}\nCheck VPS_HOST and VPS_SSH_KEY in scripts/vps/.env"
    success "VPS ${VPS_HOST} reachable"
}

################################################################################
# VPS stack management
################################################################################

# Create client database + user on shared MariaDB if they don't exist
# Usage: create_client_db <stack_env>
create_client_db() {
    local stack_env=$1
    local db_name="${CLIENT_NAME//-/_}_${stack_env}"
    local db_user="${CLIENT_NAME//-/_}_${stack_env}"
    local container="mariadb_${stack_env}"
    local secret_file="/opt/wp-express/mariadb-${stack_env}/secrets/root_password"

    info "Ensuring database '${db_name}' exists on ${container}..."

    # Idempotent: always ensure DB, user, and correct password exist
    vps_run bash -s << EOF
set -e
ROOT_PASS=\$(cat "${secret_file}")
DB_PASS="${DB_PASS}"
docker exec ${container} mariadb -u root -p"\${ROOT_PASS}" << SQL
CREATE DATABASE IF NOT EXISTS \\\`${db_name}\\\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '\${DB_PASS}';
ALTER USER '${db_user}'@'%' IDENTIFIED BY '\${DB_PASS}';
GRANT ALL PRIVILEGES ON \\\`${db_name}\\\`.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
SQL
EOF
}

# Write .env for a client stack on the VPS
# Usage: write_vps_env <stack_env> <site_domain> <db_pass> <mariadb_network>
write_vps_env() {
    local stack_env=$1
    local site_domain=$2
    local db_pass=$3
    local mariadb_network=$4
    local db_name="${CLIENT_NAME//-/_}_${stack_env}"
    local db_user="${db_name}"
    local db_host="mariadb_${stack_env}"
    local stack_dir="${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${stack_env}"

    # Copy salts from local .env (they exist already from new-project.sh)
    local salts
    salts=$(grep -E '^(AUTH|SECURE_AUTH|LOGGED_IN|NONCE)_(KEY|SALT)=' "${CLIENT_DIR}/.env" || true)

    local redis_pass
    redis_pass=$(grep '^REDIS_PASSWORD=' "${CLIENT_DIR}/.env" 2>/dev/null | cut -d= -f2- | tr -d "'" | tr -d '"' || gen_password)

    local wp_env="staging"
    [[ "$stack_env" == "production" ]] && wp_env="production"

    local wp_home="https://${site_domain}"

    info "Writing .env for ${stack_env} stack..."

    # Use printf to write the .env remotely
    vps_run bash -s << EOF
cat > "${stack_dir}/.env" << 'ENVEOF'
# Database (shared MariaDB — do not change DB_HOST)
DB_NAME='${db_name}'
DB_USER='${db_user}'
DB_PASSWORD='${db_pass}'
DB_HOST='${db_host}'
DB_PREFIX='wp_'

# WordPress
WP_ENV='${wp_env}'
WP_HOME='${wp_home}'
WP_SITEURL='\${WP_HOME}/wp'

# Redis
REDIS_ENABLED='$([ "$stack_env" = "production" ] && echo true || echo false)'
REDIS_HOST='redis'
REDIS_PORT='6379'
REDIS_PASSWORD='${redis_pass}'

# PHP
PHP_MEMORY_LIMIT='256M'
PHP_MAX_EXECUTION_TIME='300'
PHP_UPLOAD_MAX_FILESIZE='64M'
PHP_POST_MAX_SIZE='64M'

# VPS / Traefik routing
CLIENT_NAME='${CLIENT_NAME}'
STACK_ENV='${stack_env}'
SITE_DOMAIN='${site_domain}'
MARIADB_NETWORK='${mariadb_network}'
ENVEOF

# Append salts (read from heredoc to avoid shell escaping issues)
cat >> "${stack_dir}/.env" << 'SALTEOF'
${salts}
SALTEOF
EOF
}

# Clone or pull the client git repo on the VPS, run composer install
# Usage: ensure_vps_stack <stack_env>
ensure_vps_stack() {
    local stack_env=$1
    local stack_dir="${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${stack_env}"

    info "Setting up ${stack_env} directory on VPS..."

    vps_run bash -s << EOF
set -e
mkdir -p "${VPS_CLIENTS_DIR}/${CLIENT_NAME}"

if [ -d "${stack_dir}/.git" ]; then
    echo "Pulling latest code..."
    cd "${stack_dir}"
    git pull --quiet
else
    echo "Cloning repository..."
    git clone --quiet "${GITHUB_REPO}" "${stack_dir}"
fi

# Make uploads directory for bind mount
mkdir -p "${stack_dir}/web/app/uploads"
chmod 755 "${stack_dir}/web/app/uploads"

# Composer install (production: no dev dependencies)
cd "${stack_dir}"
if command -v composer &>/dev/null; then
    composer install --no-interaction --no-dev --optimize-autoloader --quiet
else
    docker run --rm \
        -v "\$(pwd):/app" -w /app \
        composer:2 install --no-interaction --no-dev --optimize-autoloader --quiet
fi
EOF
    success "Code ready at ${stack_dir}"
}

# Wait for a container on the VPS to reach "running" state (not starting/restarting)
# Usage: wait_for_vps_container <container_name> [timeout_seconds]
wait_for_vps_container() {
    local container=$1
    local timeout=${2:-60}
    local elapsed=0

    info "Waiting for ${container} to be ready..."
    while [[ $elapsed -lt $timeout ]]; do
        local status
        status=$(vps_run "docker inspect --format='{{.State.Status}}' '${container}' 2>/dev/null" 2>/dev/null || echo "not_found")
        if [[ "$status" == "running" ]]; then
            success "${container} is ready"
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    error "${container} did not reach running state within ${timeout}s (last status: ${status})"
    return 1
}

# Start (or restart) the Docker stack on the VPS
# Usage: start_vps_stack <stack_env>
start_vps_stack() {
    local stack_env=$1
    local stack_dir="${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${stack_env}"
    local redis_profile=""
    [[ "$stack_env" == "production" ]] && redis_profile="--profile redis"

    info "Starting ${stack_env} Docker stack..."
    vps_run "cd '${stack_dir}' && docker compose -f docker-compose.vps.yml ${redis_profile} up -d --build"
    wait_for_vps_container "${CLIENT_NAME}_php_${stack_env}"
    success "${stack_env} stack running"
}

################################################################################
# DB and uploads sync
################################################################################

# Export DB from local, transfer to VPS, import into target container, search-replace URLs
# Usage: sync_db_local_to_vps <target_stack_env> <source_url> <target_url>
sync_db_local_to_vps() {
    local target_env=$1
    local source_url=$2
    local target_url=$3
    local target_container="${CLIENT_NAME}_php_${target_env}"
    local dump_file="deploy-dump-$$.sql"
    local local_dump="${CLIENT_DIR}/${dump_file}"
    local vps_dump="/tmp/${dump_file}"

    step "Syncing database: local → ${target_env}"

    # Export from local container (writes to /var/www/ which maps to $CLIENT_DIR)
    info "Exporting local database..."
    docker exec -i "$LOCAL_PHP_CONTAINER" \
        vendor/bin/wp --allow-root db export "/var/www/${dump_file}"

    # Transfer to VPS
    info "Transferring dump to VPS..."
    # shellcheck disable=SC2086
    scp ${VPS_SSH_OPTS} "$local_dump" "${VPS_SSH_USER}@${VPS_HOST}:${vps_dump}"
    rm -f "$local_dump"

    # Import on VPS — pipe from host /tmp into container stdin
    info "Importing database on ${target_env}..."
    vps_run "cat ${vps_dump} | docker exec -i ${target_container} vendor/bin/wp --allow-root db import -"

    # URL search-replace
    info "Replacing URLs: ${source_url} → ${target_url}"
    vps_run "docker exec -i ${target_container} vendor/bin/wp --allow-root \
        search-replace '${source_url}' '${target_url}' \
        --all-tables --recurse-objects --precise --report-changed-only"

    # Flush
    vps_run "docker exec -i ${target_container} vendor/bin/wp --allow-root cache flush" || true
    vps_run "rm -f ${vps_dump}"

    success "Database synced and URLs updated"
}

# Sync DB between two VPS stacks (staging → production), all on VPS
# Usage: sync_db_vps_to_vps <source_env> <target_env> <source_url> <target_url>
sync_db_vps_to_vps() {
    local source_env=$1
    local target_env=$2
    local source_url=$3
    local target_url=$4
    local source_container="${CLIENT_NAME}_php_${source_env}"
    local target_container="${CLIENT_NAME}_php_${target_env}"

    step "Syncing database: ${source_env} → ${target_env} (on VPS)"

    vps_run bash -s << EOF
set -e

echo "Exporting ${source_env} and piping into ${target_env}..."
docker exec -i ${source_container} vendor/bin/wp --allow-root db export - \
    | docker exec -i ${target_container} vendor/bin/wp --allow-root db import -

echo "Replacing URLs..."
docker exec -i ${target_container} vendor/bin/wp --allow-root \
    search-replace '${source_url}' '${target_url}' \
    --all-tables --recurse-objects --precise --report-changed-only

echo "Flushing cache..."
docker exec -i ${target_container} vendor/bin/wp --allow-root cache flush || true
EOF
    success "Database synced: ${source_env} → ${target_env}"
}

# Sync uploads from local to VPS staging/production
sync_uploads_local_to_vps() {
    local target_env=$1
    local target_uploads="${VPS_SSH_USER}@${VPS_HOST}:${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${target_env}/web/app/uploads/"
    local local_uploads="${CLIENT_DIR}/web/app/uploads/"

    step "Syncing uploads: local → ${target_env}"

    if [[ ! -d "$local_uploads" ]]; then
        info "No local uploads directory found — skipping"
        return 0
    fi

    # shellcheck disable=SC2086
    rsync -az --delete --progress \
        -e "ssh ${VPS_SSH_OPTS}" \
        "$local_uploads" \
        "$target_uploads"

    success "Uploads synced to ${target_env}"
}

# Sync uploads between two VPS stacks (all on VPS)
sync_uploads_vps_to_vps() {
    local source_env=$1
    local target_env=$2

    step "Syncing uploads: ${source_env} → ${target_env} (on VPS)"
    vps_run "rsync -az --delete \
        '${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${source_env}/web/app/uploads/' \
        '${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${target_env}/web/app/uploads/'"
    success "Uploads synced: ${source_env} → ${target_env}"
}

# Health check — wait for site to respond
health_check() {
    local url=$1
    step "Health check: ${url}"
    local attempts=0
    until curl -sf --max-time 10 -o /dev/null -w "%{http_code}" "$url" | grep -qE "^(200|301|302)$"; do
        attempts=$((attempts + 1))
        [[ $attempts -ge 12 ]] && { warn "Site not responding after 60s — check 'make logs' on VPS"; return 1; }
        echo -n "."
        sleep 5
    done
    echo ""
    success "${url} is responding ✓"
}

################################################################################
# Git: push local, pull on VPS
################################################################################

git_push_local() {
    step "Git: checking local repository"
    cd "$CLIENT_DIR"

    if ! git rev-parse --git-dir &>/dev/null; then
        error "No git repo found in ${CLIENT_DIR}. Run new-project.sh to initialise."
    fi

    if [[ -z "$(git remote)" ]]; then
        [[ -z "$GITHUB_REPO" ]] && error "No GitHub repo configured. Add 'github_repo' to .wp-express-project"
        git remote add origin "$GITHUB_REPO"
    fi

    # Warn about uncommitted changes but don't block
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        warn "Uncommitted changes detected. Auto-committing for deploy..."
        git add -A
        git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M')"
    fi

    info "Pushing to GitHub..."
    git push origin "$(git rev-parse --abbrev-ref HEAD)" --quiet
    DEPLOY_SHA=$(git rev-parse --short HEAD)
    success "Pushed commit ${DEPLOY_SHA}"
}

################################################################################
# Deploy directions
################################################################################

deploy_local_to_target() {
    local target_env=$1
    local target_domain=$2
    local target_url=$3
    local mariadb_network="mariadb_${target_env}_net"
    local db_pass

    check_vps
    detect_local_env
    git_push_local

    # Generate or retrieve DB password
    local existing_db_pass
    existing_db_pass=$(vps_run "grep '^DB_PASSWORD=' '${VPS_CLIENTS_DIR}/${CLIENT_NAME}/${target_env}/.env' 2>/dev/null | cut -d= -f2- | tr -d \"'\" || echo ''" 2>/dev/null || true)

    if [[ -n "$existing_db_pass" ]]; then
        db_pass="$existing_db_pass"
    else
        db_pass=$(gen_password)
    fi

    DB_PASS="$db_pass"
    export DB_PASS

    ensure_vps_stack "$target_env"

    # Write .env if stack is new or domain changed
    write_vps_env "$target_env" "$target_domain" "$db_pass" "$mariadb_network"
    create_client_db "$target_env"
    start_vps_stack "$target_env"

    # Give containers a moment to start
    sleep 5

    $SKIP_DB      || sync_db_local_to_vps "$target_env" "$LOCAL_URL" "$target_url"
    $SKIP_UPLOADS || sync_uploads_local_to_vps "$target_env"

    health_check "$target_url"
}

deploy_staging_to_production() {
    local staging_url="$STAGING_URL"
    local prod_url="$PROD_URL"
    local db_pass

    check_vps

    # Pull latest code on production (same commit that was deployed to staging)
    step "Syncing code: staging → production"
    local existing_db_pass
    existing_db_pass=$(vps_run "grep '^DB_PASSWORD=' '${VPS_CLIENTS_DIR}/${CLIENT_NAME}/production/.env' 2>/dev/null | cut -d= -f2- | tr -d \"'\" || echo ''" 2>/dev/null || true)

    if [[ -n "$existing_db_pass" ]]; then
        db_pass="$existing_db_pass"
    else
        db_pass=$(gen_password)
    fi

    DB_PASS="$db_pass"
    export DB_PASS

    # Sync code: production should be on the same commit as staging
    vps_run bash -s << EOF
set -e
STAGING_DIR="${VPS_CLIENTS_DIR}/${CLIENT_NAME}/staging"
PROD_DIR="${VPS_CLIENTS_DIR}/${CLIENT_NAME}/production"
mkdir -p "\${PROD_DIR}"

# Get the commit currently deployed in staging
STAGING_SHA=\$(git -C "\${STAGING_DIR}" rev-parse HEAD 2>/dev/null || echo "")

if [ -d "\${PROD_DIR}/.git" ]; then
    git -C "\${PROD_DIR}" pull --quiet
    [ -n "\${STAGING_SHA}" ] && git -C "\${PROD_DIR}" checkout "\${STAGING_SHA}" --quiet
else
    git clone --quiet "${GITHUB_REPO}" "\${PROD_DIR}"
    [ -n "\${STAGING_SHA}" ] && git -C "\${PROD_DIR}" checkout "\${STAGING_SHA}" --quiet
fi

mkdir -p "\${PROD_DIR}/web/app/uploads"
chmod 755 "\${PROD_DIR}/web/app/uploads"

cd "\${PROD_DIR}"
if command -v composer &>/dev/null; then
    composer install --no-interaction --no-dev --optimize-autoloader --quiet
else
    docker run --rm -v "\$(pwd):/app" -w /app composer:2 \
        install --no-interaction --no-dev --optimize-autoloader --quiet
fi
EOF
    success "Production code at staging commit"

    write_vps_env "production" "$DOMAIN" "$db_pass" "mariadb_prod_net"
    create_client_db "production"
    start_vps_stack "production"
    sleep 5

    $SKIP_DB      || sync_db_vps_to_vps "staging" "production" "$staging_url" "$prod_url"
    $SKIP_UPLOADS || sync_uploads_vps_to_vps "staging" "production"

    health_check "$prod_url"
}

################################################################################
# Main
################################################################################

echo -e "${BLUE}Starting deploy...${NC}"

case "${SOURCE}-${TARGET}" in
    local-staging)
        deploy_local_to_target "staging" "$STAGING_DOMAIN" "$STAGING_URL"
        ;;
    local-production)
        deploy_local_to_target "production" "$DOMAIN" "$PROD_URL"
        ;;
    staging-production)
        deploy_staging_to_production
        ;;
esac

echo ""
echo -e "${GREEN}✅  Deploy complete!${NC}"
[[ "$TARGET" == "staging" ]]    && echo -e "   ${CYAN}${STAGING_URL}${NC}"
[[ "$TARGET" == "production" ]] && echo -e "   ${CYAN}${PROD_URL}${NC}"
echo ""
