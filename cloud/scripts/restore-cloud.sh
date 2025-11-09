#!/bin/bash
# =============================================================================
# Nextcloud Homelab Cloud Restoration Script
# =============================================================================
# This script restores cloud services from backups created by backup-cloud.sh

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="/mnt/user/backups/cloud"
LOG_FILE="/var/log/cloud-restore.log"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
usage() {
    cat << EOF
Usage: $0 [OPTIONS] BACKUP_DIR

Restore Nextcloud Homelab Cloud from backup

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force restoration without confirmation
    -d, --data-only     Restore only data, skip configuration
    -c, --config-only   Restore only configuration, skip data
    
BACKUP_DIR:
    Path to backup directory (e.g., /mnt/user/backups/cloud/20240101_120000)
    Or use 'latest' to restore from the most recent backup

Examples:
    $0 /mnt/user/backups/cloud/20240101_120000
    $0 latest
    $0 --data-only latest
EOF
}

list_available_backups() {
    log "Available backups:"
    find "$BACKUP_BASE_DIR" -type d -name "20*" | sort -r | head -10 | while read -r backup; do
        local size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "Unknown")
        local date=$(basename "$backup")
        echo "  $date (Size: $size)"
    done
}

get_latest_backup() {
    find "$BACKUP_BASE_DIR" -type d -name "20*" | sort -r | head -1
}

confirm_restoration() {
    local backup_dir="$1"
    
    echo
    echo "WARNING: This will restore from backup and OVERWRITE existing data!"
    echo "Backup directory: $backup_dir"
    echo "Target directory: /mnt/user/appdata/"
    echo
    
    if [[ "${FORCE:-false}" == "true" ]]; then
        log "Force mode enabled, skipping confirmation"
        return 0
    fi
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Restoration cancelled by user"
        exit 0
    fi
}

# =============================================================================
# RESTORATION FUNCTIONS
# =============================================================================
verify_backup_directory() {
    local backup_dir="$1"
    
    log "Verifying backup directory: $backup_dir"
    
    if [[ ! -d "$backup_dir" ]]; then
        error "Backup directory does not exist: $backup_dir"
        return 1
    fi
    
    # Check for required files
    local required_files=(
        "databases.sql"
        "nextcloud_data.tar.gz"
        "paperless_data.tar.gz"
        "bookstack_data.tar.gz"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$backup_dir/$file" ]]; then
            error "Missing required backup file: $file"
            return 1
        fi
    done
    
    log "Backup directory verification completed"
}

stop_services() {
    log "Stopping all cloud services..."
    cd "$CLOUD_DIR"
    docker-compose down
}

restore_databases() {
    local backup_dir="$1"
    
    log "Starting database restoration..."
    
    cd "$CLOUD_DIR"
    
    # Start only PostgreSQL for restoration
    log "Starting PostgreSQL container..."
    docker-compose up -d postgres
    
    # Wait for PostgreSQL to be ready
    log "Waiting for PostgreSQL to be ready..."
    sleep 30
    
    # Drop existing databases (except template databases)
    log "Dropping existing databases..."
    docker-compose exec -T postgres psql -U nextcloud_user -d postgres -c "DROP DATABASE IF EXISTS nextcloud;"
    docker-compose exec -T postgres psql -U nextcloud_user -d postgres -c "DROP DATABASE IF EXISTS paperless;"
    docker-compose exec -T postgres psql -U nextcloud_user -d postgres -c "DROP DATABASE IF EXISTS bookstack;"
    
    # Restore databases
    log "Restoring databases from backup..."
    docker-compose exec -T postgres psql -U nextcloud_user -d postgres < "$backup_dir/databases.sql"
    
    log "Database restoration completed"
}

restore_application_data() {
    local backup_dir="$1"
    
    log "Starting application data restoration..."
    
    # Create backup of existing data
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_existing="/tmp/cloud_data_backup_$timestamp"
    
    log "Creating backup of existing data to: $backup_existing"
    mkdir -p "$backup_existing"
    
    if [[ -d "/mnt/user/appdata/nextcloud/data" ]]; then
        mv "/mnt/user/appdata/nextcloud/data" "$backup_existing/nextcloud_data_old"
    fi
    
    if [[ -d "/mnt/user/appdata/paperless" ]]; then
        mv "/mnt/user/appdata/paperless" "$backup_existing/paperless_old"
    fi
    
    if [[ -d "/mnt/user/appdata/bookstack" ]]; then
        mv "/mnt/user/appdata/bookstack" "$backup_existing/bookstack_old"
    fi
    
    # Restore data from backup
    log "Restoring Nextcloud data..."
    mkdir -p "/mnt/user/appdata/nextcloud"
    tar -xzf "$backup_dir/nextcloud_data.tar.gz" -C "/mnt/user/appdata/nextcloud"
    
    log "Restoring Paperless data..."
    tar -xzf "$backup_dir/paperless_data.tar.gz" -C "/mnt/user/appdata"
    
    log "Restoring BookStack data..."
    tar -xzf "$backup_dir/bookstack_data.tar.gz" -C "/mnt/user/appdata"
    
    # Set proper permissions
    log "Setting proper permissions..."
    chown -R 1000:1000 /mnt/user/appdata/nextcloud
    chown -R 1000:1000 /mnt/user/appdata/paperless
    chown -R 1000:1000 /mnt/user/appdata/bookstack
    
    log "Application data restoration completed"
    log "Previous data backed up to: $backup_existing"
}

restore_configuration() {
    local backup_dir="$1"
    
    log "Starting configuration restoration..."
    
    # Backup existing configuration
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local config_backup="/tmp/cloud_config_backup_$timestamp"
    mkdir -p "$config_backup"
    
    # Backup current configuration
    if [[ -f "$CLOUD_DIR/.env" ]]; then
        cp "$CLOUD_DIR/.env" "$config_backup/"
    fi
    
    if [[ -d "$CLOUD_DIR/nginx" ]]; then
        cp -r "$CLOUD_DIR/nginx" "$config_backup/"
    fi
    
    # Restore configuration from backup
    if [[ -f "$backup_dir/env_backup" ]]; then
        log "Restoring environment configuration..."
        cp "$backup_dir/env_backup" "$CLOUD_DIR/.env"
    fi
    
    if [[ -d "$backup_dir/nginx" ]]; then
        log "Restoring Nginx configuration..."
        cp -r "$backup_dir/nginx" "$CLOUD_DIR/"
    fi
    
    if [[ -d "$backup_dir/nextcloud" ]]; then
        log "Restoring Nextcloud configuration..."
        cp -r "$backup_dir/nextcloud" "$CLOUD_DIR/"
    fi
    
    if [[ -d "$backup_dir/postgres" ]]; then
        log "Restoring PostgreSQL configuration..."
        cp -r "$backup_dir/postgres" "$CLOUD_DIR/"
    fi
    
    log "Configuration restoration completed"
    log "Previous configuration backed up to: $config_backup"
}

start_services() {
    log "Starting all cloud services..."
    cd "$CLOUD_DIR"
    docker-compose up -d
    
    # Wait for services to be healthy
    log "Waiting for services to become healthy..."
    sleep 60
    
    # Check service health
    local unhealthy_services=$(docker-compose ps | grep -c "unhealthy" || true)
    if [[ $unhealthy_services -gt 0 ]]; then
        error "Some services are unhealthy after restoration"
        docker-compose ps
        return 1
    else
        log "All services are running normally"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    local backup_dir=""
    local data_only=false
    local config_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--data-only)
                data_only=true
                shift
                ;;
            -c|--config-only)
                config_only=true
                shift
                ;;
            *)
                backup_dir="$1"
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$backup_dir" ]]; then
        error "Backup directory not specified"
        usage
        exit 1
    fi
    
    # Handle 'latest' keyword
    if [[ "$backup_dir" == "latest" ]]; then
        backup_dir=$(get_latest_backup)
        if [[ -z "$backup_dir" ]]; then
            error "No backups found in $BACKUP_BASE_DIR"
            list_available_backups
            exit 1
        fi
        log "Using latest backup: $backup_dir"
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "Starting Nextcloud Homelab Cloud restoration..."
    log "Backup source: $backup_dir"
    
    verify_backup_directory "$backup_dir"
    confirm_restoration "$backup_dir"
    
    stop_services
    
    if [[ "$config_only" == "false" ]]; then
        restore_databases "$backup_dir"
        restore_application_data "$backup_dir"
    fi
    
    if [[ "$data_only" == "false" ]]; then
        restore_configuration "$backup_dir"
    fi
    
    start_services
    
    log "Restoration completed successfully!"
    log "Please verify that all services are working correctly"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
