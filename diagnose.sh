#!/bin/bash

################################################################################
# WP Express - Diagnostic Tool
# Helps troubleshoot why Docker containers won't start
#
# Usage: ./diagnose.sh [project-name]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_check() {
    echo -e "${CYAN}▶${NC} Checking: $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="${PARENT_DIR}/clients"

PROJECT_NAME="${1:-}"

################################################################################
# System Checks
################################################################################

check_system() {
    print_header "System Requirements"
    
    # Docker
    print_check "Docker installation"
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        print_success "Docker installed: ${docker_version}"
    else
        print_error "Docker not installed"
        echo ""
        echo "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        return 1
    fi
    
    # Docker running
    print_check "Docker service"
    if docker info >/dev/null 2>&1; then
        print_success "Docker is running"
    else
        print_error "Docker is not running"
        echo ""
        echo "Please start Docker Desktop and try again"
        return 1
    fi
    
    # Docker Compose
    print_check "Docker Compose"
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | awk '{print $NF}')
        print_success "Docker Compose installed: ${compose_version}"
    else
        print_error "Docker Compose not installed"
        return 1
    fi
    
    # Architecture
    print_check "System architecture"
    local arch=$(uname -m)
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        print_success "Apple Silicon (ARM64) detected"
        echo "  ${BLUE}→${NC} Use: make apple-silicon"
    else
        print_success "Intel (x86_64) detected"
        echo "  ${BLUE}→${NC} Use: make intel"
    fi
    
    # Memory
    print_check "Available memory"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local mem=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        print_info "${mem}GB total RAM"
        if [ "$mem" -lt 8 ]; then
            print_warning "Less than 8GB RAM detected. Docker may be slow."
        else
            print_success "Sufficient memory available"
        fi
    fi
    
    # Disk space
    print_check "Available disk space"
    local available=$(df -h . | awk 'NR==2 {print $4}')
    print_info "${available} available"
    
    return 0
}

################################################################################
# Port Checks
################################################################################

check_ports() {
    print_header "Port Availability"
    
    local ports=(8000 8443 3306 6379 9000)
    local port_names=("HTTP" "HTTPS" "MySQL" "Redis" "PHP-FPM")
    local has_conflict=false
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"
        
        print_check "Port ${port} (${name})"
        
        if lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
            local pid=$(lsof -Pi :${port} -sTCP:LISTEN -t)
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            print_error "Port ${port} is already in use by: ${process} (PID: ${pid})"
            has_conflict=true
        else
            print_success "Port ${port} is available"
        fi
    done
    
    if [ "$has_conflict" = true ]; then
        echo ""
        print_warning "Port conflicts detected!"
        echo ""
        echo "Solutions:"
        echo "  1. Stop the conflicting process"
        echo "  2. Change ports in docker-compose.yml"
        echo "  3. Use docker-compose.override.yml to customize ports"
        return 1
    fi
    
    return 0
}

################################################################################
# Project Checks
################################################################################

check_project() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"
    
    print_header "Project: ${project_name}"
    
    # Project directory
    print_check "Project directory"
    if [ -d "$project_dir" ]; then
        print_success "Found: ${project_dir}"
    else
        print_error "Project not found: ${project_dir}"
        return 1
    fi
    
    cd "$project_dir"
    
    # .env file
    print_check ".env file"
    if [ -f ".env" ]; then
        print_success ".env file exists"
        
        # Check required variables
        local required_vars=("DB_NAME" "DB_USER" "DB_PASSWORD" "WP_HOME")
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" .env; then
                print_success "${var} is set"
            else
                print_error "${var} is missing"
            fi
        done
    else
        print_error ".env file not found"
        return 1
    fi
    
    # Docker Compose files
    print_check "Docker Compose files"
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.apple-silicon.yml"
        "docker-compose.intel.yml"
    )
    
    for file in "${compose_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file exists"
        else
            print_warning "$file not found"
        fi
    done
    
    # Composer
    print_check "Composer dependencies"
    if [ -d "vendor" ]; then
        print_success "vendor/ directory exists"
    else
        print_warning "vendor/ directory not found"
        echo "  ${BLUE}→${NC} Run: composer install"
    fi
    
    # WordPress core
    print_check "WordPress core"
    if [ -d "web/wp" ]; then
        print_success "web/wp/ directory exists"
    else
        print_warning "web/wp/ directory not found"
        echo "  ${BLUE}→${NC} Run: composer install to download WordPress"
    fi
    
    # Permissions
    print_check "Directory permissions"
    if [ -w "web/app/uploads" ]; then
        print_success "web/app/uploads is writable"
    else
        print_error "web/app/uploads is not writable"
        echo "  ${BLUE}→${NC} Run: chmod -R 755 web/app/uploads"
    fi
    
    return 0
}

################################################################################
# Docker Status
################################################################################

check_docker_status() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"
    
    print_header "Docker Status"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_dir}"
        return 1
    fi
    
    cd "$project_dir"
    
    # Check if containers exist
    print_check "Docker containers"
    
    local containers=$(docker-compose ps -q 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$containers" -eq 0 ]; then
        print_warning "No containers found"
        echo "  ${BLUE}→${NC} Start with: make apple-silicon (or make intel)"
    else
        print_success "${containers} container(s) found"
        echo ""
        docker-compose ps
    fi
    
    # Check running containers
    print_check "Running containers"
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        print_success "Some containers are running"
    else
        print_warning "No containers are running"
    fi
    
    # Recent logs
    print_check "Recent error logs"
    local errors=$(docker-compose logs --tail=50 2>/dev/null | grep -i "error\|failed\|fatal" | wc -l | tr -d ' ')
    
    if [ "$errors" -gt 0 ]; then
        print_warning "Found ${errors} error messages in recent logs"
        echo "  ${BLUE}→${NC} View with: make logs"
    else
        print_success "No recent errors in logs"
    fi
    
    return 0
}

################################################################################
# Main Diagnostic Flow
################################################################################

run_diagnostics() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   WP Express - Diagnostic Tool            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    
    # System checks
    if ! check_system; then
        echo ""
        print_error "System requirements not met. Please fix the issues above."
        exit 1
    fi
    
    # Port checks
    check_ports
    
    # Project-specific checks
    if [ -n "$PROJECT_NAME" ]; then
        check_project "$PROJECT_NAME"
        check_docker_status "$PROJECT_NAME"
    else
        print_header "Available Projects"
        
        if [ -d "$CLIENTS_DIR" ]; then
            local count=0
            for project in "$CLIENTS_DIR"/*; do
                if [ -d "$project" ]; then
                    echo "  • $(basename "$project")"
                    ((count++))
                fi
            done
            
            if [ "$count" -eq 0 ]; then
                print_info "No projects found in ${CLIENTS_DIR}"
            else
                echo ""
                print_info "Run './diagnose.sh <project-name>' for project-specific checks"
            fi
        else
            print_info "No clients directory found"
        fi
    fi
    
    # Summary
    print_header "Diagnostic Complete"
    
    if [ -n "$PROJECT_NAME" ]; then
        echo "Next steps for ${PROJECT_NAME}:"
        echo ""
        echo "1. Start containers:"
        echo "   ${YELLOW}cd ${CLIENTS_DIR}/${PROJECT_NAME}${NC}"
        echo "   ${YELLOW}make apple-silicon${NC}  # or make intel"
        echo ""
        echo "2. View logs if issues:"
        echo "   ${YELLOW}make logs${NC}"
        echo ""
        echo "3. Check container status:"
        echo "   ${YELLOW}docker-compose ps${NC}"
    fi
}

################################################################################
# Help
################################################################################

show_help() {
    cat << EOF
WP Express - Diagnostic Tool

Usage: ./diagnose.sh [project-name]

Without project name: Checks system requirements and lists projects
With project name: Performs detailed checks on specific project

Examples:
  ./diagnose.sh                # System check only
  ./diagnose.sh acme-corp      # Full diagnostic for acme-corp

What it checks:
  ✓ Docker installation and status
  ✓ Required ports availability
  ✓ Project files and configuration
  ✓ Docker container status
  ✓ Recent error logs

EOF
}

# Main
case "${1:-}" in
    --help|-h|help)
        show_help
        ;;
    *)
        run_diagnostics
        ;;
esac
