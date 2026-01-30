#!/bin/bash

################################################################################
# WP Express - Project Manager
# List, check status, and manage all client projects
#
# Directory Structure:
#   parent/
#   ├── scripts/         <- This script location
#   ├── wp-express-skeleton/
#   └── clients/         <- Client projects
#
# Usage: ./manage-projects.sh [command]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="${PARENT_DIR}/clients"

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }

show_usage() {
    cat << EOF
WP Express - Project Manager

Usage: ./manage-projects.sh [command] [options]

Commands:
  list              List all projects
  status            Show detailed status of all projects
  check <name>      Check specific project health
  backup <name>     Backup specific project
  backup-all        Backup all projects
  stop <name>       Stop project containers
  stop-all          Stop all project containers
  start <name>      Start project containers
  restart <name>    Restart project containers
  clean <name>      Clean Docker resources for project
  help              Show this help

Examples:
  ./manage-projects.sh list
  ./manage-projects.sh status
  ./manage-projects.sh check acme-corp
  ./manage-projects.sh backup acme-corp
  ./manage-projects.sh start acme-corp

EOF
}

get_project_info() {
    local project_dir="$1"
    local info_file="${project_dir}/.wp-express-project"

    if [ -f "$info_file" ]; then
        cat "$info_file"
    else
        echo "{}"
    fi
}

get_compose_file() {
    local project_dir="$1"
    local arch=$(uname -m)

    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        if [ -f "${project_dir}/docker-compose.apple-silicon.yml" ]; then
            echo "docker-compose.apple-silicon.yml"
        else
            echo "docker-compose.yml"
        fi
    else
        if [ -f "${project_dir}/docker-compose.intel.yml" ]; then
            echo "docker-compose.intel.yml"
        else
            echo "docker-compose.yml"
        fi
    fi
}

check_docker_status() {
    local project_dir="$1"

    if [ ! -d "$project_dir" ]; then
        echo "not-found"
        return
    fi

    cd "$project_dir" 2>/dev/null || return

    local compose_file=$(get_compose_file "$project_dir")

    # Check if any containers are running
    if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
        echo "running"
    else
        echo "stopped"
    fi
}

get_container_count() {
    local project_dir="$1"

    if [ ! -d "$project_dir" ]; then
        echo "0"
        return
    fi

    cd "$project_dir" 2>/dev/null || return
    local compose_file=$(get_compose_file "$project_dir")
    local count=$(docker-compose -f "$compose_file" --env-file .env ps -q 2>/dev/null | wc -l | tr -d ' ')
    echo "$count"
}

list_projects() {
    print_header "WP Express Projects"

    if [ ! -d "$CLIENTS_DIR" ]; then
        print_warning "No clients directory found at: ${CLIENTS_DIR}"
        echo ""
        echo "Create a new project with:"
        echo "  ./new-project.sh <client-name>"
        return
    fi

    local count=0

    printf "%-25s %-15s %-12s %-15s %s\n" "PROJECT" "STATUS" "CONTAINERS" "ENVIRONMENT" "CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            local status=$(check_docker_status "$project_dir")
            local containers=$(get_container_count "$project_dir")

            # Get info from .wp-express-project
            local info=$(get_project_info "$project_dir")
            local env=$(echo "$info" | grep -o '"environment": "[^"]*"' | cut -d'"' -f4)
            local created=$(echo "$info" | grep -o '"created_at": "[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)

            # Color code status
            if [ "$status" = "running" ]; then
                status="${GREEN}running${NC}"
            else
                status="${YELLOW}stopped${NC}"
            fi

            printf "%-25s %-25s %-12s %-15s %s\n" \
                "$project_name" \
                "$(echo -e "$status")" \
                "$containers" \
                "${env:-unknown}" \
                "${created:-unknown}"

            ((count++))
        fi
    done

    echo ""
    print_info "Total projects: $count"

    if [ $count -eq 0 ]; then
        echo ""
        echo "Create your first project:"
        echo "  ./new-project.sh my-first-client"
    fi
}

show_project_status() {
    print_header "Detailed Project Status"

    if [ ! -d "$CLIENTS_DIR" ]; then
        print_warning "No clients directory found"
        return
    fi

    local has_projects=false

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            has_projects=true
            local project_name=$(basename "$project_dir")
            echo ""
            echo -e "${CYAN}┌──────────────────────────────────────────────────────────────${NC}"
            echo -e "${CYAN}│ Project: ${project_name}${NC}"
            echo -e "${CYAN}└──────────────────────────────────────────────────────────────${NC}"

            cd "$project_dir"

            # Get project info
            if [ -f ".wp-express-project" ]; then
                local info=$(cat .wp-express-project)
                echo "  Client: $(echo "$info" | grep -o '"client_name": "[^"]*"' | cut -d'"' -f4)"
                echo "  Domain: $(echo "$info" | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)"
                echo "  Environment: $(echo "$info" | grep -o '"environment": "[^"]*"' | cut -d'"' -f4)"
                echo "  Redis: $(echo "$info" | grep -o '"redis_enabled": [^,}]*' | cut -d':' -f2 | tr -d ' ')"
            fi

            # Docker status
            echo ""
            echo "  Docker Status:"
            local compose_file=$(get_compose_file "$project_dir")
            if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
                docker-compose -f "$compose_file" --env-file .env ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | sed 's/^/    /'
            else
                echo "    No containers running"
                echo "    ${YELLOW}Start with: cd ${project_dir} && make apple-silicon${NC}"
            fi

            # Disk usage
            if [ -d "web/app/uploads" ]; then
                local upload_size=$(du -sh web/app/uploads 2>/dev/null | cut -f1)
                echo ""
                echo "  Uploads size: ${upload_size:-0B}"
            fi
        fi
    done

    if [ "$has_projects" = false ]; then
        print_warning "No projects found"
    fi
}

check_project_health() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        echo ""
        echo "Available projects:"
        list_projects
        return 1
    fi

    print_header "Health Check: ${project_name}"

    cd "$project_dir"

    # Check .env file
    echo -e "${CYAN}▶${NC} Checking configuration files..."
    if [ -f ".env" ]; then
        print_success ".env file exists"
    else
        print_error ".env file missing"
    fi

    if [ -f ".credentials" ]; then
        print_success ".credentials file exists"
    else
        print_warning ".credentials file missing (optional)"
    fi

    # Check Docker Compose files
    echo ""
    echo -e "${CYAN}▶${NC} Checking Docker configuration..."
    local arch=$(uname -m)
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        if [ -f "docker-compose.apple-silicon.yml" ]; then
            print_success "docker-compose.apple-silicon.yml exists"
        else
            print_error "docker-compose.apple-silicon.yml missing"
        fi
    else
        if [ -f "docker-compose.intel.yml" ]; then
            print_success "docker-compose.intel.yml exists"
        else
            print_error "docker-compose.intel.yml missing"
        fi
    fi

    # Check if containers are running
    echo ""
    echo -e "${CYAN}▶${NC} Checking Docker containers..."
    local compose_file=$(get_compose_file "$project_dir")
    if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
        print_success "Docker containers running"

        echo ""
        echo "Service Health:"
        docker-compose -f "$compose_file" --env-file .env ps --format "table {{.Name}}\t{{.Status}}" | grep "Up" | sed 's/^/  /'

        # Check if WordPress is accessible - read URL from project config
        echo ""
        echo -e "${CYAN}▶${NC} Checking WordPress accessibility..."
        local wp_url="http://localhost:8000"
        if [ -f ".wp-express-project" ]; then
            wp_url=$(grep -o '"wp_home": "[^"]*"' .wp-express-project | cut -d'"' -f4)
        elif [ -f ".env" ]; then
            wp_url=$(grep "^WP_HOME=" .env | cut -d"'" -f2)
        fi

        # Use -k to allow self-signed certificates
        local http_code=$(curl -sk -o /dev/null -w "%{http_code}" "${wp_url}" 2>/dev/null || echo "000")

        if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
            print_success "WordPress is accessible at ${wp_url} (HTTP $http_code)"
        else
            print_warning "WordPress returned HTTP $http_code (may still be loading)"
            print_info "URL: ${wp_url}"
        fi
    else
        print_warning "Docker containers not running"
        echo ""
        echo "Start containers:"
        echo "  cd ${project_dir}"
        echo "  make apple-silicon  # or make intel"
    fi

    # Check Composer
    echo ""
    echo -e "${CYAN}▶${NC} Checking dependencies..."
    if [ -d "vendor" ]; then
        print_success "Composer dependencies installed"
    else
        print_warning "Composer dependencies not installed"
        echo "  Run: composer install"
    fi

    if [ -d "web/wp" ]; then
        print_success "WordPress core installed"
    else
        print_warning "WordPress core not installed"
        echo "  Run: composer install"
    fi

    # Check disk usage
    echo ""
    echo "Disk Usage:"
    du -sh . 2>/dev/null | sed 's/^/  Total: /'
    du -sh web/app/uploads 2>/dev/null | sed 's/^/  Uploads: /' || echo "  Uploads: 0B"

    # Check Git status
    echo ""
    echo "Git Status:"
    if [ -d ".git" ]; then
        local branch=$(git branch --show-current 2>/dev/null)
        local commits=$(git rev-list --count HEAD 2>/dev/null)
        echo "  Branch: ${branch:-unknown}"
        echo "  Commits: ${commits:-0}"

        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            print_warning "Uncommitted changes present"
        else
            print_success "No uncommitted changes"
        fi
    else
        print_error "Not a Git repository"
    fi
}

backup_project() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        return 1
    fi

    print_header "Backing Up: ${project_name}"

    cd "$project_dir"

    local backup_dir="${project_dir}/backups"
    mkdir -p "$backup_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local compose_file=$(get_compose_file "$project_dir")

    # Read database credentials from .env
    local db_user="wordpress"
    local db_pass="wordpress"
    local db_name="wordpress"
    if [ -f ".env" ]; then
        db_user=$(grep "^DB_USER=" .env | cut -d"'" -f2)
        db_pass=$(grep "^DB_PASSWORD=" .env | cut -d"'" -f2)
        db_name=$(grep "^DB_NAME=" .env | cut -d"'" -f2)
        [ -z "$db_user" ] && db_user="wordpress"
        [ -z "$db_pass" ] && db_pass="wordpress"
        [ -z "$db_name" ] && db_name="wordpress"
    fi

    # Backup database
    print_info "Backing up database..."
    if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "database.*Up"; then
        docker-compose -f "$compose_file" --env-file .env exec -T database mysqldump -u"${db_user}" -p"${db_pass}" "${db_name}" > "${backup_dir}/db_${timestamp}.sql" 2>/dev/null
        print_success "Database backed up"
    else
        print_warning "Database container not running, skipping database backup"
    fi

    # Backup uploads
    print_info "Backing up uploads..."
    if [ -d "web/app/uploads" ] && [ "$(ls -A web/app/uploads)" ]; then
        tar -czf "${backup_dir}/uploads_${timestamp}.tar.gz" -C web/app uploads/ 2>/dev/null
        print_success "Uploads backed up"
    else
        print_info "No uploads to backup"
    fi

    # Backup .env
    print_info "Backing up configuration..."
    cp .env "${backup_dir}/env_${timestamp}.backup"
    print_success "Configuration backed up"

    # Create backup manifest
    cat > "${backup_dir}/manifest_${timestamp}.txt" << EOF
Backup Manifest
Project: ${project_name}
Date: $(date)
Timestamp: ${timestamp}

Files:
- db_${timestamp}.sql
- uploads_${timestamp}.tar.gz
- env_${timestamp}.backup

Database size: $(du -sh "${backup_dir}/db_${timestamp}.sql" 2>/dev/null | cut -f1 || echo "N/A")
Uploads size: $(du -sh "${backup_dir}/uploads_${timestamp}.tar.gz" 2>/dev/null | cut -f1 || echo "N/A")
EOF

    print_success "Backup completed: ${backup_dir}"
    print_info "Backup timestamp: ${timestamp}"
}

start_project() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        return 1
    fi

    print_info "Starting project: ${project_name}"
    cd "$project_dir"

    local compose_file=$(get_compose_file "$project_dir")

    # Check if Redis is enabled
    local redis_enabled="false"
    if [ -f ".wp-express-project" ]; then
        redis_enabled=$(grep -o '"redis_enabled": [^,}]*' .wp-express-project | cut -d':' -f2 | tr -d ' ')
    elif [ -f ".env" ]; then
        redis_enabled=$(grep "^REDIS_ENABLED=" .env | cut -d"'" -f2)
    fi

    if [ "$redis_enabled" = "true" ]; then
        docker-compose -f "$compose_file" --env-file .env --profile redis up -d
    else
        docker-compose -f "$compose_file" --env-file .env up -d nginx php database
    fi

    print_success "Project started"

    sleep 2
    docker-compose -f "$compose_file" --env-file .env ps
}

stop_project() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        return 1
    fi

    print_info "Stopping project: ${project_name}"
    cd "$project_dir"
    local compose_file=$(get_compose_file "$project_dir")
    docker-compose -f "$compose_file" --env-file .env down
    print_success "Project stopped"
}

restart_project() {
    local project_name="$1"

    print_info "Restarting project: ${project_name}"
    stop_project "$project_name"
    sleep 2
    start_project "$project_name"
}

stop_all_projects() {
    print_header "Stopping All Projects"

    if [ ! -d "$CLIENTS_DIR" ]; then
        print_warning "No clients directory found"
        return
    fi

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            cd "$project_dir"
            local compose_file=$(get_compose_file "$project_dir")

            if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
                print_info "Stopping ${project_name}..."
                docker-compose -f "$compose_file" --env-file .env down
            fi
        fi
    done

    print_success "All projects stopped"
}

backup_all_projects() {
    print_header "Backing Up All Projects"

    if [ ! -d "$CLIENTS_DIR" ]; then
        print_warning "No clients directory found"
        return
    fi

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            backup_project "$project_name"
            echo ""
        fi
    done
}

################################################################################
# Main
################################################################################

COMMAND="${1:-list}"

case $COMMAND in
    list)
        list_projects
        ;;
    status)
        show_project_status
        ;;
    check)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        check_project_health "$2"
        ;;
    backup)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        backup_project "$2"
        ;;
    backup-all)
        backup_all_projects
        ;;
    start)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        start_project "$2"
        ;;
    stop)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        stop_project "$2"
        ;;
    restart)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        restart_project "$2"
        ;;
    stop-all)
        stop_all_projects
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
