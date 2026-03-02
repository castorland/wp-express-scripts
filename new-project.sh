#!/bin/bash

################################################################################
# WP Express - New Project Generator
# Creates a new client project by cloning wp-express-skeleton from GitHub
################################################################################

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GITHUB_REPO="https://github.com/castorland/wp-express-skeleton.git"
GITHUB_BRANCH="main"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="${WORKSPACE_DIR}/clients"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

show_usage() {
    cat << 'EOF'
Usage: ./new-project.sh <client-name> [options]

Arguments:
  client-name             Name of the client/project (required)

Options:
  --domain <domain>       Custom domain (default: {client-name}.local with HTTPS)
  --port <port>           Custom port (default: 443 for .local, 8000 for localhost)
  --email <email>         Admin email address (default: admin@example.com)
  --admin-user <user>     Admin username (default: admin)
  --admin-pass <pass>     Admin password (default: auto-generated)
  --site-title <title>    Site title (default: client name)
  --no-install            Skip WordPress installation
  --no-start              Don't start Docker containers
  --redis                 Enable Redis cache
  --branch <branch>       GitHub branch to clone (default: main)
  --use-localhost         Use localhost:8000 with HTTP instead of {client}.local
  --help                  Show this help

Default Behavior:
  - Uses HTTPS with {client-name}.local domain
  - Automatically adds entry to /etc/hosts (requires sudo)
  - Generates self-signed SSL certificates

Examples:
  ./new-project.sh acme-corp
    → https://acme-corp.local

  ./new-project.sh startup --redis
    → https://startup.local with Redis enabled

  ./new-project.sh client --use-localhost
    → http://localhost:8000 (no hosts file needed)

  ./new-project.sh project --domain custom.local
    → https://custom.local

EOF
}

sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-20
}

generate_salts() {
    # Generate salts locally in .env format (not PHP define format)
    cat <<EOF
AUTH_KEY='$(openssl rand -base64 64 | tr -d '\n')'
SECURE_AUTH_KEY='$(openssl rand -base64 64 | tr -d '\n')'
LOGGED_IN_KEY='$(openssl rand -base64 64 | tr -d '\n')'
NONCE_KEY='$(openssl rand -base64 64 | tr -d '\n')'
AUTH_SALT='$(openssl rand -base64 64 | tr -d '\n')'
SECURE_AUTH_SALT='$(openssl rand -base64 64 | tr -d '\n')'
LOGGED_IN_SALT='$(openssl rand -base64 64 | tr -d '\n')'
NONCE_SALT='$(openssl rand -base64 64 | tr -d '\n')'
EOF
}

check_dependencies() {
    print_info "Checking dependencies..."
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v docker-compose >/dev/null 2>&1 || missing+=("docker-compose")
    command -v composer >/dev/null 2>&1 || missing+=("composer")

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Please install missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        echo ""
        echo "Please start Docker and try again"
        return 1
    fi

    print_success "All dependencies OK"
    return 0
}

check_github_access() {
    print_info "Checking GitHub repository access..."

    if ! git ls-remote "$GITHUB_REPO" HEAD >/dev/null 2>&1; then
        print_error "Cannot access repository: $GITHUB_REPO"
        echo ""
        echo "Please check:"
        echo "  1. Repository URL is correct"
        echo "  2. You have internet connection"
        echo "  3. Repository is public or you have access"
        return 1
    fi

    print_success "GitHub repository accessible"
    return 0
}

add_hosts_entry() {
    local domain=$1

    # Check if entry already exists
    if grep -q "127.0.0.1.*${domain}" /etc/hosts 2>/dev/null; then
        print_info "Hosts entry for ${domain} already exists"
        return 0
    fi

    print_info "Adding ${domain} to /etc/hosts..."
    echo ""
    echo "This requires sudo access to edit /etc/hosts"

    if echo "127.0.0.1 ${domain}" | sudo tee -a /etc/hosts >/dev/null 2>&1; then
        print_success "Added ${domain} to /etc/hosts"
        return 0
    else
        print_warning "Could not add to /etc/hosts automatically"
        echo ""
        echo "Please add manually:"
        echo "  sudo sh -c 'echo \"127.0.0.1 ${domain}\" >> /etc/hosts'"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Check for help flag first
for arg in "$@"; do
    if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
        show_usage
        exit 0
    fi
done

CLIENT_NAME=$(sanitize_name "$1")
DOMAIN=""
PORT=""
EMAIL="admin@example.com"
ADMIN_USER="admin_$(openssl rand -hex 4)"
ADMIN_PASS=""
SITE_TITLE=""
START_CONTAINERS="true"
INSTALL_WP="true"
ENABLE_REDIS="false"
BRANCH="$GITHUB_BRANCH"
USE_LOCALHOST="false"

shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2;;
        --port) PORT="$2"; shift 2;;
        --email) EMAIL="$2"; shift 2;;
        --admin-user) ADMIN_USER="$2"; shift 2;;
        --admin-pass) ADMIN_PASS="$2"; shift 2;;
        --site-title) SITE_TITLE="$2"; shift 2;;
        --no-start) START_CONTAINERS="false"; INSTALL_WP="false"; shift;;
        --no-install) INSTALL_WP="false"; shift;;
        --redis) ENABLE_REDIS="true"; shift;;
        --branch) BRANCH="$2"; shift 2;;
        --use-localhost) USE_LOCALHOST="true"; shift;;
        --help|-h) show_usage; exit 0;;
        *) print_error "Unknown option: $1"; show_usage; exit 1;;
    esac
done

# Set defaults
[ -z "$SITE_TITLE" ] && SITE_TITLE=$(echo "$CLIENT_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
[ -z "$ADMIN_PASS" ] && ADMIN_PASS=$(generate_password)

# Determine domain and protocol
if [ "$USE_LOCALHOST" = "true" ]; then
    # Use localhost with HTTP
    [ -z "$DOMAIN" ] && DOMAIN="localhost"
    [ -z "$PORT" ] && PORT="8000"
    WP_HOME="http://localhost:${PORT}"
else
    # Use .local domain with HTTPS
    [ -z "$DOMAIN" ] && DOMAIN="${CLIENT_NAME}.local"
    [ -z "$PORT" ] && PORT="443"
    if [ "$PORT" = "443" ]; then
        WP_HOME="https://${DOMAIN}"
    else
        WP_HOME="https://${DOMAIN}:${PORT}"
    fi
fi

PROJECT_DIR="${CLIENTS_DIR}/${CLIENT_NAME}"

# Show configuration
print_header "WP Express - New Project Setup"
echo -e "${CYAN}Configuration:${NC}"
echo "  Project Name:     ${CLIENT_NAME}"
echo "  URL:              ${WP_HOME}"
echo "  Domain:           ${DOMAIN}"
echo "  Port:             ${PORT}"
echo "  Site Title:       ${SITE_TITLE}"
echo "  Admin User:       ${ADMIN_USER}"
echo "  Admin Email:      ${EMAIL}"
echo "  Redis:            ${ENABLE_REDIS}"
echo "  GitHub Branch:    ${BRANCH}"
echo "  Start Containers: ${START_CONTAINERS}"
echo "  Install WP:       ${INSTALL_WP}"
echo ""

read -p "Continue with this configuration? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_error "Aborted by user"
    exit 1
fi

# Pre-flight checks
check_dependencies || exit 1
check_github_access || exit 1

################################################################################
# STEP 1: Clone from GitHub
################################################################################

print_header "Step 1/6: Cloning from GitHub"
mkdir -p "$CLIENTS_DIR"

if [ -d "$PROJECT_DIR" ]; then
    print_warning "Project already exists: ${PROJECT_DIR}"
    read -p "Delete and recreate? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        exit 1
    fi
    print_info "Removing existing project..."
    rm -rf "$PROJECT_DIR"
fi

print_info "Cloning: ${GITHUB_REPO}"
print_info "Branch: ${BRANCH}"

if git clone -b "$BRANCH" "$GITHUB_REPO" "$PROJECT_DIR"; then
    print_success "Repository cloned successfully"
else
    print_error "Clone failed"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

# Initialize new git repo
rm -rf .git
git init -q
git add .
git commit -q -m "Initial commit for ${CLIENT_NAME}"
print_success "Git repository initialized"

################################################################################
# STEP 2: Create .env file
################################################################################

print_header "Step 2/6: Configuring Environment"

DB_PASS=$(generate_password)
REDIS_PASS=$(generate_password)

print_info "Creating .env file..."

cat > .env << ENVFILE
# Database
DB_NAME='wordpress'
DB_USER='wordpress'
DB_PASSWORD='${DB_PASS}'
DB_HOST='database'
DB_PREFIX='wp_'

# WordPress
WP_ENV='development'
WP_HOME='${WP_HOME}'
WP_SITEURL="\${WP_HOME}/wp"

# Redis
REDIS_ENABLED='${ENABLE_REDIS}'
REDIS_HOST='redis'
REDIS_PORT='6379'
REDIS_PASSWORD='${REDIS_PASS}'

# PHP
PHP_MEMORY_LIMIT='512M'
PHP_MAX_EXECUTION_TIME='300'
PHP_UPLOAD_MAX_FILESIZE='128M'
PHP_POST_MAX_SIZE='128M'

# PHP-FPM
PHP_FPM_PM='dynamic'
PHP_FPM_PM_MAX_CHILDREN='50'
PHP_FPM_PM_START_SERVERS='5'
PHP_FPM_PM_MIN_SPARE_SERVERS='5'
PHP_FPM_PM_MAX_SPARE_SERVERS='35'

# OPcache
OPCACHE_ENABLE='1'
OPCACHE_MEMORY_CONSUMPTION='256'

# Security
DISABLE_WP_CRON='false'
DISALLOW_FILE_EDIT='true'

# Fail2Ban
FAIL2BAN_ENABLED='true'

# Timezone
TIMEZONE='UTC'

ENVFILE

print_info "Generating WordPress salts..."
generate_salts >> .env
print_success ".env file created"

# Save credentials
cat > .credentials << CREDFILE
Project: ${CLIENT_NAME}
Created: $(date)

Database:
  Name: wordpress
  User: wordpress
  Password: ${DB_PASS}

Redis:
  Password: ${REDIS_PASS}

WordPress Admin:
  URL: ${WP_HOME}/wp/wp-admin
  Username: ${ADMIN_USER}
  Password: ${ADMIN_PASS}
  Email: ${EMAIL}
CREDFILE

chmod 600 .credentials
print_success "Credentials saved to .credentials"

# Create project metadata file for management scripts
cat > .wp-express-project << PROJECTFILE
{
  "client_name": "${CLIENT_NAME}",
  "site_title": "${SITE_TITLE}",
  "domain": "${DOMAIN}",
  "port": "${PORT}",
  "protocol": "$([ "$USE_LOCALHOST" = "true" ] && echo "http" || echo "https")",
  "wp_home": "${WP_HOME}",
  "email": "${EMAIL}",
  "admin_user": "${ADMIN_USER}",
  "environment": "development",
  "redis_enabled": ${ENABLE_REDIS},
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "github_branch": "${BRANCH}",
  "use_localhost": ${USE_LOCALHOST},
  "github_repo": ""
}
PROJECTFILE
print_success "Project metadata saved to .wp-express-project"

################################################################################
# STEP 3: Install dependencies with Composer
################################################################################

print_header "Step 3/6: Installing Dependencies"
print_info "Running: composer install"
print_info "This may take a few minutes..."
echo ""

if composer install --no-interaction --prefer-dist --optimize-autoloader; then
    echo ""
    print_success "Dependencies installed successfully"
    print_success "WordPress core, plugins, and theme are ready"
else
    echo ""
    print_error "Composer install failed"
    echo ""
    echo "Please check composer.json and try running manually:"
    echo "  cd ${PROJECT_DIR}"
    echo "  composer install"
    exit 1
fi

################################################################################
# STEP 4: Generate SSL certificates
################################################################################

print_header "Step 4/6: Generating SSL Certificates"

if [ -f docker/nginx/ssl/generate-ssl.sh ]; then
    print_info "Generating SSL certificates..."
    cd docker/nginx/ssl
    chmod +x generate-ssl.sh
    if ./generate-ssl.sh >/dev/null 2>&1; then
        cd "$PROJECT_DIR"
        print_success "SSL certificates generated"
    else
        cd "$PROJECT_DIR"
        print_warning "SSL generation failed (not critical)"
    fi
else
    print_info "No SSL generation script found (skipping)"
fi

# Commit configuration
git add .
git commit -q -m "Configure environment for ${CLIENT_NAME}" 2>/dev/null || true
print_success "Configuration committed to git"

################################################################################
# STEP 4b: Create GitHub repo under WP-Express-Clients org
################################################################################

GITHUB_ORG="WP-Express-Clients"
CLIENT_GITHUB_REPO="https://github.com/${GITHUB_ORG}/${CLIENT_NAME}.git"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh repo view "${GITHUB_ORG}/${CLIENT_NAME}" >/dev/null 2>&1; then
        print_info "GitHub repo ${GITHUB_ORG}/${CLIENT_NAME} already exists — setting remote"
    else
        gh repo create "${GITHUB_ORG}/${CLIENT_NAME}" --private --source=. --remote=origin --description "WP Express client site: ${CLIENT_NAME}" >/dev/null
        print_success "GitHub repo created: ${CLIENT_GITHUB_REPO}"
    fi
    git remote set-url origin "${CLIENT_GITHUB_REPO}" 2>/dev/null || git remote add origin "${CLIENT_GITHUB_REPO}"
    git push -u origin main -q
    print_success "Pushed to ${CLIENT_GITHUB_REPO}"

    # Update .wp-express-project with the repo URL
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
with open('.wp-express-project') as f: d = json.load(f)
d['github_repo'] = '${CLIENT_GITHUB_REPO}'
with open('.wp-express-project', 'w') as f: json.dump(d, f, indent=2)
"
        git add .wp-express-project
        git commit -q -m "Set github_repo in project config" 2>/dev/null || true
        git push -q
    fi
else
    print_warning "gh CLI not authenticated — skipping GitHub repo creation"
    print_warning "Create manually: gh repo create ${GITHUB_ORG}/${CLIENT_NAME} --private"
fi

################################################################################
# STEP 5: Start Docker containers
################################################################################

if [ "$START_CONTAINERS" = "true" ]; then
    print_header "Step 5/6: Starting Docker Containers"

    # Detect architecture
    arch=$(uname -m)
    COMPOSE_FILE="docker-compose.yml"

    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        print_info "Detected architecture: Apple Silicon (ARM64)"
        if [ -f "docker-compose.apple-silicon.yml" ]; then
            COMPOSE_FILE="docker-compose.apple-silicon.yml"
        fi
    else
        print_info "Detected architecture: Intel (x86_64)"
        if [ -f "docker-compose.intel.yml" ]; then
            COMPOSE_FILE="docker-compose.intel.yml"
        fi
    fi

    print_info "Using compose file: ${COMPOSE_FILE}"

    # Update ports if needed
    if [ "$USE_LOCALHOST" = "true" ]; then
        # Use HTTP port mapping
        if [ "$PORT" != "8000" ]; then
            print_info "Updating HTTP port to ${PORT}..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/8000:80/${PORT}:80/g" "$COMPOSE_FILE"
            else
                sed -i "s/8000:80/${PORT}:80/g" "$COMPOSE_FILE"
            fi
        fi
    else
        # Use HTTPS port mapping
        print_info "Configuring HTTPS on port ${PORT}..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/8000:80/${PORT}:443/g" "$COMPOSE_FILE"
        else
            sed -i "s/8000:80/${PORT}:443/g" "$COMPOSE_FILE"
        fi
    fi

    # Start containers
    print_info "Starting containers..."

    if [ "$ENABLE_REDIS" = "true" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file .env --profile redis up -d
    else
        docker-compose -f "$COMPOSE_FILE" --env-file .env up -d nginx php database
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to start containers"
        echo ""
        echo "Debug steps:"
        echo "  1. Check logs: cd ${PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} logs"
        echo "  2. Check port ${PORT}: lsof -i :${PORT}"
        echo "  3. Try manually: cd ${PROJECT_DIR} && make apple-silicon"
        exit 1
    fi

    print_success "Containers started successfully"

    # Wait for database
    print_info "Waiting for database to be ready..."
    print_info "This may take 20-30 seconds for first-time initialization..."
    max_attempts=40
    attempt=0

    # First wait for container to be healthy
    sleep 5

    while [ $attempt -lt $max_attempts ]; do
        # Try to connect using mariadb client with the generated password
        if docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T database mariadb -uwordpress -p"${DB_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
            echo ""
            print_success "Database is ready and accepting connections"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        echo ""
        print_error "Database connection test failed after ${max_attempts} attempts"
        print_warning "This might be a docker-compose environment variable issue"
        print_info "Attempting to diagnose..."

        # Try to see what's in the database container
        docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T database mariadb -uroot -p"${DB_PASS}" -e "SELECT User, Host FROM mysql.user;" 2>&1 || true

        print_info "Waiting an additional 10 seconds and continuing anyway..."
        sleep 10
    fi

    echo ""
    print_info "Container status:"
    docker-compose -f "$COMPOSE_FILE" --env-file .env ps
    echo ""

else
    print_info "Skipping container startup (--no-start)"
fi

################################################################################
# STEP 6: Install WordPress
################################################################################

if [ "$INSTALL_WP" = "true" ] && [ "$START_CONTAINERS" = "true" ]; then
    print_header "Step 6/6: Installing WordPress"

    # Detect compose file again
    arch=$(uname -m)
    COMPOSE_FILE="docker-compose.yml"
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        [ -f "docker-compose.apple-silicon.yml" ] && COMPOSE_FILE="docker-compose.apple-silicon.yml"
    else
        [ -f "docker-compose.intel.yml" ] && COMPOSE_FILE="docker-compose.intel.yml"
    fi

    print_info "Installing WordPress core..."

    if docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T php vendor/bin/wp core install \
        --url="${WP_HOME}" \
        --title="${SITE_TITLE}" \
        --admin_user="${ADMIN_USER}" \
        --admin_password="${ADMIN_PASS}" \
        --admin_email="${EMAIL}" \
        --skip-email \
        --allow-root; then

        print_success "WordPress installed successfully"

        print_info "Activating plugins..."
        docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T php vendor/bin/wp plugin activate --all --allow-root >/dev/null 2>&1
        print_success "Plugins activated"

        print_info "Activating Kadence theme..."
        docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T php vendor/bin/wp theme activate kadence --allow-root >/dev/null 2>&1
        print_success "Kadence theme activated"

        print_info "Configuring permalinks..."
        docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T php vendor/bin/wp rewrite structure '/%postname%/' --allow-root >/dev/null 2>&1
        docker-compose -f "$COMPOSE_FILE" --env-file .env exec -T php vendor/bin/wp rewrite flush --allow-root >/dev/null 2>&1
        print_success "Permalinks configured"

    else
        print_error "WordPress installation failed"
        echo ""
        echo "You can install manually by running:"
        echo "  cd ${PROJECT_DIR}"
        echo "  docker-compose -f ${COMPOSE_FILE} exec php vendor/bin/wp core install \\"
        echo "    --url=\"${WP_HOME}\" \\"
        echo "    --title=\"${SITE_TITLE}\" \\"
        echo "    --admin_user=\"${ADMIN_USER}\" \\"
        echo "    --admin_password=\"${ADMIN_PASS}\" \\"
        echo "    --admin_email=\"${EMAIL}\" \\"
        echo "    --allow-root"
    fi
else
    print_info "Skipping WordPress installation"
fi

################################################################################
# Success Summary
################################################################################

print_header "✅ Project Created Successfully!"

echo ""
echo -e "${GREEN}Project: ${CLIENT_NAME}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📁 Location: ${PROJECT_DIR}"
echo "🌐 URL: ${WP_HOME}"
echo ""

# Add hosts entry for .local domains
if [ "$USE_LOCALHOST" = "false" ]; then
    echo ""
    add_hosts_entry "${DOMAIN}"
    echo ""
fi

if [ "$INSTALL_WP" = "true" ] && [ "$START_CONTAINERS" = "true" ]; then
    echo -e "${GREEN}✓ WordPress is installed and ready!${NC}"
    echo ""
    echo "🔐 Admin Access:"
    echo "   URL:      ${WP_HOME}/wp/wp-admin"
    echo "   Username: ${ADMIN_USER}"
    echo "   Password: ${ADMIN_PASS}"
    echo "   Email:    ${EMAIL}"
    echo ""
fi

echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Navigate to project:"
echo -e "   ${YELLOW}cd ${PROJECT_DIR}${NC}"
echo ""

if [ "$START_CONTAINERS" != "true" ]; then
    echo "2. Start containers:"
    echo -e "   ${YELLOW}make apple-silicon${NC}  # or make intel"
    echo ""
fi

if [ "$INSTALL_WP" != "true" ]; then
    echo "3. Install WordPress:"
    echo -e "   ${YELLOW}open ${WP_HOME}${NC}"
    echo ""
fi

echo "4. Open your site:"
echo -e "   ${YELLOW}open ${WP_HOME}${NC}"
echo ""
echo "5. Access admin:"
echo -e "   ${YELLOW}open ${WP_HOME}/wp/wp-admin${NC}"
echo ""
echo "6. View logs:"
echo -e "   ${YELLOW}make logs${NC}"
echo ""

echo -e "${CYAN}Important Files:${NC}"
echo "  📄 .env          - Environment configuration"
echo "  🔐 .credentials  - Passwords (keep secure!)"
echo "  📖 README.md     - Project documentation"
echo ""

echo -e "${CYAN}Useful Commands:${NC}"
echo -e "  ${YELLOW}make help${NC}           - Show all available commands"
echo -e "  ${YELLOW}make logs${NC}           - View container logs"
echo -e "  ${YELLOW}make restart${NC}        - Restart containers"
echo -e "  ${YELLOW}make down${NC}           - Stop containers"
echo -e "  ${YELLOW}make backup${NC}         - Backup database"
echo ""

echo -e "${GREEN}🚀 Happy building!${NC}"
echo ""
