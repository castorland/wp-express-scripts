#!/bin/bash

################################################################################
# WP Express - Notion Integration
# Sync project status with Notion databases
#
# Usage: ./scripts/notion-sync.sh [command]
#
# Requirements:
#   - Notion integration already connected via Claude MCP
#   - Project must have .wp-express-project file
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

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

show_usage() {
    cat << EOF
WP Express - Notion Integration

Usage: ./scripts/notion-sync.sh [command] [options]

Commands:
  create <project>      Create Notion project entry from local project
  update <project>      Update Notion project status
  sync-all              Sync all projects to Notion
  export-clients        Export client list for intake form
  help                  Show this help

Examples:
  ./scripts/notion-sync.sh create acme-corp
  ./scripts/notion-sync.sh update acme-corp
  ./scripts/notion-sync.sh sync-all

Notes:
  - This script generates data files that can be imported to Notion
  - For automated sync, use Claude with Notion MCP integration
  - Project info is read from .wp-express-project file

EOF
}

get_project_info() {
    local project_dir="$1"
    local info_file="${project_dir}/.wp-express-project"

    if [ -f "$info_file" ]; then
        cat "$info_file"
    else
        # Try to extract info from .env and .credentials if .wp-express-project doesn't exist
        local domain=""
        local email=""
        if [ -f "${project_dir}/.env" ]; then
            domain=$(grep "^WP_HOME=" "${project_dir}/.env" | cut -d"'" -f2 | sed 's|https\?://||')
        fi
        if [ -f "${project_dir}/.credentials" ]; then
            email=$(grep "Email:" "${project_dir}/.credentials" | tail -1 | awk '{print $2}')
        fi
        echo "{\"client_name\": \"$(basename "$project_dir")\", \"domain\": \"${domain}\", \"email\": \"${email}\"}"
    fi
}

create_notion_entry() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        return 1
    fi

    print_header "Creating Notion Entry: ${project_name}"

    local info=$(get_project_info "$project_dir")

    # Extract fields
    local client_name=$(echo "$info" | grep -o '"client_name": "[^"]*"' | cut -d'"' -f4)
    local domain=$(echo "$info" | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)
    local email=$(echo "$info" | grep -o '"email": "[^"]*"' | cut -d'"' -f4)
    local environment=$(echo "$info" | grep -o '"environment": "[^"]*"' | cut -d'"' -f4)
    local created_at=$(echo "$info" | grep -o '"created_at": "[^"]*"' | cut -d'"' -f4)

    # Get Git repo URL if available
    cd "$project_dir"
    local repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "")

    # Create export file
    local export_file="${project_dir}/.notion-export.json"

    cat > "$export_file" << EOF
{
  "project_data": {
    "Name": "${client_name}",
    "Project Type": "WP Express",
    "Pipeline Status": "In Progress",
    "Priority": "Medium",
    "Client": ["${client_name}"],
    "date:Deadline:start": "$(date -d '+5 days' +%Y-%m-%d)",
    "date:Deadline:is_datetime": 0,
    "Repo Link": "${repo_url}",
    "Documentation": "# ${client_name}\\n\\nDomain: ${domain}\\nEnvironment: ${environment}\\nCreated: ${created_at}",
    "Estimated Hours": 40,
    "Spent Hours": 0
  },
  "client_data": {
    "Name": "${client_name}",
    "Contact Person": "",
    "Email": "${email}",
    "Phone": "",
    "Client Type": "WP Express",
    "What pages do you need?": [],
    "Extra services": [],
    "Notes": "Auto-created from WP Express project generator",
    "Credentials": "See project .credentials file"
  }
}
EOF

    print_success "Notion export file created: ${export_file}"

    cat << EOF

${CYAN}To create this project in Notion:${NC}

1. Use Claude with Notion MCP integration
2. Share this JSON data with Claude:

${YELLOW}Project Data:${NC}
$(cat "$export_file" | grep -A 100 '"project_data"' | grep -B 100 '},' | sed 's/^/  /')

${YELLOW}Client Data:${NC}
$(cat "$export_file" | grep -A 100 '"client_data"' | grep -B 100 '}' | tail -n +2 | sed 's/^/  /')

Or use the file: ${export_file}

EOF
}

update_notion_status() {
    local project_name="$1"
    local project_dir="${CLIENTS_DIR}/${project_name}"

    if [ ! -d "$project_dir" ]; then
        print_error "Project not found: ${project_name}"
        return 1
    fi

    print_header "Updating Notion Status: ${project_name}"

    cd "$project_dir"

    # Detect architecture and compose file
    local arch=$(uname -m)
    local compose_file="docker-compose.yml"
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
        [ -f "docker-compose.apple-silicon.yml" ] && compose_file="docker-compose.apple-silicon.yml"
    else
        [ -f "docker-compose.intel.yml" ] && compose_file="docker-compose.intel.yml"
    fi

    # Check Docker status
    local docker_status="stopped"
    if docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
        docker_status="running"
    fi

    # Check if WordPress is installed
    local wp_installed="false"
    if [ -d "web/wp" ] && [ -f "web/wp/wp-config.php" ]; then
        wp_installed="true"
    fi

    # Get latest commit
    local latest_commit=$(git log -1 --format="%s" 2>/dev/null || echo "No commits")

    # Calculate spent hours (rough estimate based on commits)
    local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    local estimated_hours=$((commit_count * 2))

    # Determine pipeline status
    local pipeline_status="In Progress"
    if [ "$wp_installed" = "true" ] && [ "$docker_status" = "running" ]; then
        pipeline_status="Review"
    fi

    local update_file="${project_dir}/.notion-update.json"

    cat > "$update_file" << EOF
{
  "project_update": {
    "Pipeline Status": "${pipeline_status}",
    "Spent Hours": ${estimated_hours},
    "Documentation": "# Status Update\\n\\nDocker: ${docker_status}\\nWordPress: ${wp_installed}\\nLast commit: ${latest_commit}\\nUpdated: $(date)"
  }
}
EOF

    print_success "Update data created: ${update_file}"

    cat << EOF

${CYAN}Project Status Summary:${NC}
  Docker: ${docker_status}
  WordPress: ${wp_installed}
  Commits: ${commit_count}
  Estimated hours: ${estimated_hours}
  Suggested status: ${pipeline_status}

${CYAN}To update Notion:${NC}
1. Find the project in your Notion Projects database
2. Update with this data:

$(cat "$update_file" | sed 's/^/  /')

EOF
}

sync_all_projects() {
    print_header "Syncing All Projects to Notion"

    if [ ! -d "$CLIENTS_DIR" ]; then
        print_warning "No projects directory found"
        return
    fi

    local sync_file="${CLIENTS_DIR}/.notion-sync-batch.json"

    echo "[" > "$sync_file"

    local first=true

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            local info=$(get_project_info "$project_dir")

            if [ "$info" != "{}" ]; then
                if [ "$first" = false ]; then
                    echo "," >> "$sync_file"
                fi
                first=false

                cat "$project_dir/.notion-export.json" 2>/dev/null >> "$sync_file" || echo "{}" >> "$sync_file"
            fi
        fi
    done

    echo "]" >> "$sync_file"

    print_success "Batch sync file created: ${sync_file}"
    print_info "Share this file with Claude to sync all projects to Notion"
}

export_clients_csv() {
    print_header "Exporting Clients List"

    local csv_file="${CLIENTS_DIR}/clients_export.csv"

    echo "Client Name,Domain,Email,Environment,Created,Status" > "$csv_file"

    for project_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$project_dir" ]; then
            local info=$(get_project_info "$project_dir")

            if [ "$info" != "{}" ]; then
                local client_name=$(echo "$info" | grep -o '"client_name": "[^"]*"' | cut -d'"' -f4)
                local domain=$(echo "$info" | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)
                local email=$(echo "$info" | grep -o '"email": "[^"]*"' | cut -d'"' -f4)
                local env=$(echo "$info" | grep -o '"environment": "[^"]*"' | cut -d'"' -f4)
                local created=$(echo "$info" | grep -o '"created_at": "[^"]*"' | cut -d'"' -f4)

                # Check status
                cd "$project_dir"
                local status="Active"

                # Detect architecture and compose file
                local arch=$(uname -m)
                local compose_file="docker-compose.yml"
                if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
                    [ -f "docker-compose.apple-silicon.yml" ] && compose_file="docker-compose.apple-silicon.yml"
                else
                    [ -f "docker-compose.intel.yml" ] && compose_file="docker-compose.intel.yml"
                fi

                if ! docker-compose -f "$compose_file" --env-file .env ps 2>/dev/null | grep -q "Up"; then
                    status="Inactive"
                fi

                echo "${client_name},${domain},${email},${env},${created},${status}" >> "$csv_file"
            fi
        fi
    done

    print_success "Clients exported: ${csv_file}"
    print_info "Import this CSV to Notion or use for reporting"
}

################################################################################
# Main
################################################################################

COMMAND="${1:-help}"

case $COMMAND in
    create)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        create_notion_entry "$2"
        ;;
    update)
        if [ -z "$2" ]; then
            print_error "Project name required"
            show_usage
            exit 1
        fi
        update_notion_status "$2"
        ;;
    sync-all)
        sync_all_projects
        ;;
    export-clients)
        export_clients_csv
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
