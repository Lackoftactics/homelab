#!/bin/bash
# =============================================================================
# Nextcloud Homelab Cloud Setup Script
# =============================================================================
# This script automates the initial setup of the Nextcloud homelab cloud

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/cloud-setup.log"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! docker-compose --version &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

create_directories() {
    log "Creating required directories..."
    
    local directories=(
        "/mnt/user/appdata/nextcloud/data"
        "/mnt/user/appdata/nextcloud/postgres"
        "/mnt/user/appdata/nextcloud/redis"
        "/mnt/user/appdata/paperless/data"
        "/mnt/user/appdata/paperless/media"
        "/mnt/user/appdata/paperless/consume"
        "/mnt/user/appdata/bookstack/data"
        "/mnt/user/backups/cloud"
        "/var/log"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log "Creating directory: $dir"
            mkdir -p "$dir"
        else
            log "Directory already exists: $dir"
        fi
    done
    
    success "Directories created"
}

set_permissions() {
    log "Setting proper permissions..."
    
    # Set ownership for application data
    chown -R 1000:1000 /mnt/user/appdata/nextcloud
    chown -R 1000:1000 /mnt/user/appdata/paperless
    chown -R 1000:1000 /mnt/user/appdata/bookstack
    
    # Set permissions for backup directory
    chmod 750 /mnt/user/backups/cloud
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    chmod +x "$CLOUD_DIR/postgres/init-multiple-databases.sh"
    
    success "Permissions set"
}

setup_environment() {
    log "Setting up environment configuration..."
    
    if [[ ! -f "$CLOUD_DIR/.env" ]]; then
        if [[ -f "$CLOUD_DIR/.env.example" ]]; then
            log "Copying .env.example to .env"
            cp "$CLOUD_DIR/.env.example" "$CLOUD_DIR/.env"
            
            echo
            echo "=============================================="
            echo "IMPORTANT: Environment Configuration Required"
            echo "=============================================="
            echo "Please edit $CLOUD_DIR/.env and set:"
            echo "1. Strong passwords for all services"
            echo "2. Your domain name"
            echo "3. Paperless secret key (50+ characters)"
            echo
            echo "Generate secure passwords with:"
            echo "  openssl rand -base64 32"
            echo
            echo "Generate Paperless secret key with:"
            echo "  openssl rand -base64 64"
            echo
            read -p "Press Enter after you've configured the .env file..."
        else
            error ".env.example file not found"
            exit 1
        fi
    else
        log ".env file already exists"
    fi
    
    success "Environment configuration ready"
}

check_traefik_network() {
    log "Checking Traefik network..."
    
    if ! docker network ls | grep -q "traefik_proxy"; then
        log "Creating traefik_proxy network..."
        docker network create traefik_proxy
    else
        log "traefik_proxy network already exists"
    fi
    
    success "Traefik network ready"
}

deploy_services() {
    log "Deploying cloud services..."
    
    cd "$CLOUD_DIR"
    
    # Pull latest images
    log "Pulling latest Docker images..."
    docker-compose pull
    
    # Start services
    log "Starting services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to initialize (this may take a few minutes)..."
    sleep 120
    
    # Check service status
    log "Checking service status..."
    docker-compose ps
    
    success "Services deployed"
}

setup_cron_backup() {
    log "Setting up automated backups..."
    
    # Create cron job for daily backups at 2 AM
    local cron_job="0 2 * * * $SCRIPT_DIR/backup-cloud.sh"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "backup-cloud.sh"; then
        log "Backup cron job already exists"
    else
        log "Adding backup cron job..."
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        success "Backup cron job added (daily at 2 AM)"
    fi
}

display_access_info() {
    local domain_name=$(grep "DOMAIN_NAME=" "$CLOUD_DIR/.env" | cut -d'=' -f2)
    
    echo
    echo "=============================================="
    echo "🎉 Nextcloud Homelab Cloud Setup Complete!"
    echo "=============================================="
    echo
    echo "Your services are now available at:"
    echo "📁 Nextcloud:    https://nextcloud.$domain_name"
    echo "📄 Paperless:    https://paperless.$domain_name"
    echo "📚 BookStack:    https://bookstack.$domain_name"
    echo
    echo "Initial Setup Required:"
    echo "1. Complete Nextcloud setup wizard"
    echo "2. Login to Paperless with admin credentials"
    echo "3. Change BookStack default password"
    echo
    echo "Default BookStack Login:"
    echo "  Email: admin@admin.com"
    echo "  Password: password"
    echo "  ⚠️  CHANGE THIS IMMEDIATELY!"
    echo
    echo "Backup Information:"
    echo "📅 Automated backups: Daily at 2:00 AM"
    echo "💾 Backup location: /mnt/user/backups/cloud/"
    echo "🔧 Manual backup: $SCRIPT_DIR/backup-cloud.sh"
    echo "🔄 Restore backup: $SCRIPT_DIR/restore-cloud.sh"
    echo
    echo "Logs and Monitoring:"
    echo "📊 Setup log: $LOG_FILE"
    echo "🔍 Service logs: docker-compose logs -f [service_name]"
    echo "💡 Service status: docker-compose ps"
    echo
    echo "Documentation:"
    echo "📖 Full documentation: $CLOUD_DIR/README.md"
    echo
    echo "=============================================="
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    log "Starting Nextcloud Homelab Cloud setup..."
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    create_directories
    set_permissions
    setup_environment
    check_traefik_network
    deploy_services
    setup_cron_backup
    
    success "Setup completed successfully!"
    display_access_info
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
