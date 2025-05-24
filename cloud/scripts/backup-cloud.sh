#!/bin/bash
# =============================================================================
# Nextcloud Homelab Cloud Backup Script
# =============================================================================
# This script creates comprehensive backups of all cloud services including
# databases, application data, and configuration files.

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="/mnt/user/backups/cloud"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"
RETENTION_DAYS=7
LOG_FILE="/var/log/cloud-backup.log"

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
# BACKUP FUNCTIONS
# =============================================================================
create_backup_directory() {
    log "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    chmod 750 "$BACKUP_DIR"
}

backup_databases() {
    log "Starting database backup..."
    
    cd "$CLOUD_DIR"
    
    # Check if PostgreSQL container is running
    if ! docker-compose ps postgres | grep -q "Up"; then
        error "PostgreSQL container is not running"
        return 1
    fi
    
    # Backup all databases
    log "Backing up PostgreSQL databases..."
    docker-compose exec -T postgres pg_dumpall -U nextcloud_user > "$BACKUP_DIR/databases.sql"
    
    # Backup individual databases for easier restoration
    docker-compose exec -T postgres pg_dump -U nextcloud_user nextcloud > "$BACKUP_DIR/nextcloud_db.sql"
    docker-compose exec -T postgres pg_dump -U nextcloud_user paperless > "$BACKUP_DIR/paperless_db.sql"
    docker-compose exec -T postgres pg_dump -U nextcloud_user bookstack > "$BACKUP_DIR/bookstack_db.sql"
    
    log "Database backup completed"
}

backup_application_data() {
    log "Starting application data backup..."
    
    # Nextcloud data
    log "Backing up Nextcloud data..."
    tar -czf "$BACKUP_DIR/nextcloud_data.tar.gz" -C /mnt/user/appdata/nextcloud data
    
    # Paperless data
    log "Backing up Paperless data..."
    tar -czf "$BACKUP_DIR/paperless_data.tar.gz" -C /mnt/user/appdata paperless
    
    # BookStack data
    log "Backing up BookStack data..."
    tar -czf "$BACKUP_DIR/bookstack_data.tar.gz" -C /mnt/user/appdata bookstack
    
    log "Application data backup completed"
}

backup_configuration() {
    log "Backing up configuration files..."
    
    # Copy Docker Compose configuration
    cp "$CLOUD_DIR/docker-compose.yml" "$BACKUP_DIR/"
    cp "$CLOUD_DIR/.env" "$BACKUP_DIR/env_backup"
    
    # Copy custom configuration files
    cp -r "$CLOUD_DIR/nginx" "$BACKUP_DIR/"
    cp -r "$CLOUD_DIR/nextcloud" "$BACKUP_DIR/"
    cp -r "$CLOUD_DIR/postgres" "$BACKUP_DIR/"
    
    log "Configuration backup completed"
}

stop_services() {
    log "Stopping services for consistent backup..."
    cd "$CLOUD_DIR"
    docker-compose stop
}

start_services() {
    log "Starting services..."
    cd "$CLOUD_DIR"
    docker-compose start
    
    # Wait for services to be healthy
    log "Waiting for services to become healthy..."
    sleep 30
    
    # Check service health
    if docker-compose ps | grep -q "unhealthy"; then
        error "Some services are unhealthy after restart"
        docker-compose ps
    else
        log "All services are running normally"
    fi
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_BASE_DIR" -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    log "Cleanup completed"
}

create_backup_manifest() {
    log "Creating backup manifest..."
    
    cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Nextcloud Homelab Cloud Backup
==============================
Backup Date: $(date)
Backup Directory: $BACKUP_DIR
Script Version: 1.0

Contents:
- databases.sql: Complete PostgreSQL dump
- nextcloud_db.sql: Nextcloud database only
- paperless_db.sql: Paperless database only  
- bookstack_db.sql: BookStack database only
- nextcloud_data.tar.gz: Nextcloud application data
- paperless_data.tar.gz: Paperless documents and data
- bookstack_data.tar.gz: BookStack wiki data
- docker-compose.yml: Docker Compose configuration
- env_backup: Environment variables (sensitive)
- nginx/: Nginx configuration
- nextcloud/: Nextcloud PHP configuration
- postgres/: PostgreSQL initialization scripts

Restoration Notes:
1. Stop all services: docker-compose stop
2. Restore databases: psql < databases.sql
3. Extract data archives to /mnt/user/appdata/
4. Restore configuration files
5. Start services: docker-compose up -d

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

    log "Backup manifest created"
}

verify_backup() {
    log "Verifying backup integrity..."
    
    # Check if all expected files exist
    local expected_files=(
        "databases.sql"
        "nextcloud_data.tar.gz"
        "paperless_data.tar.gz"
        "bookstack_data.tar.gz"
        "docker-compose.yml"
        "env_backup"
    )
    
    for file in "${expected_files[@]}"; do
        if [[ ! -f "$BACKUP_DIR/$file" ]]; then
            error "Missing backup file: $file"
            return 1
        fi
    done
    
    # Check file sizes (should not be empty)
    for file in "${expected_files[@]}"; do
        if [[ ! -s "$BACKUP_DIR/$file" ]]; then
            error "Empty backup file: $file"
            return 1
        fi
    done
    
    log "Backup verification completed successfully"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    log "Starting Nextcloud Homelab Cloud backup..."
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Trap to ensure services are restarted even if script fails
    trap 'start_services' EXIT
    
    create_backup_directory
    stop_services
    backup_databases
    backup_application_data
    start_services
    backup_configuration
    create_backup_manifest
    verify_backup
    cleanup_old_backups
    
    log "Backup completed successfully: $BACKUP_DIR"
    log "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
