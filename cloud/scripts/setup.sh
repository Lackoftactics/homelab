#!/bin/bash
# =============================================================================
# Nextcloud Homelab Cloud Setup Script - Unraid Optimized
# =============================================================================
# This script automates the initial setup of the Nextcloud homelab cloud
# Specifically designed for Unraid OS

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/mnt/user/appdata/cloud-setup.log"

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
    log "Checking prerequisites for Unraid..."

    # Check if we're on Unraid
    if [[ ! -f "/etc/unraid-version" ]]; then
        log "WARNING: This script is optimized for Unraid OS"
    fi

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        error "Docker is not available. Please enable Docker in Unraid settings."
        exit 1
    fi

    # Check if Docker Compose is available
    if ! docker-compose --version &> /dev/null; then
        error "Docker Compose is not available. Please install the Compose Manager plugin."
        exit 1
    fi

    # Check if appdata directory exists
    if [[ ! -d "/mnt/user/appdata" ]]; then
        error "Unraid appdata directory not found at /mnt/user/appdata"
        exit 1
    fi

    success "Prerequisites check passed"
}

create_directories() {
    log "Creating required directories for Unraid..."

    local directories=(
        "/mnt/user/appdata/nextcloud/data"
        "/mnt/user/appdata/nextcloud/postgres"
        "/mnt/user/appdata/nextcloud/redis"
        "/mnt/user/appdata/paperless/data"
        "/mnt/user/appdata/paperless/media"
        "/mnt/user/appdata/paperless/consume"
        "/mnt/user/appdata/bookstack/data"
        "/mnt/user/backups/cloud"
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
    log "Setting Unraid-compatible permissions..."

    # Unraid typically handles permissions through PUID/PGID
    # We'll set basic permissions but rely on container PUID/PGID

    # Ensure directories are accessible
    chmod -R 755 /mnt/user/appdata/nextcloud
    chmod -R 755 /mnt/user/appdata/paperless
    chmod -R 755 /mnt/user/appdata/bookstack
    chmod -R 755 /mnt/user/backups/cloud

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    chmod +x "$CLOUD_DIR/postgres/init-multiple-databases.sh"

    success "Permissions set for Unraid"
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

setup_unraid_backup() {
    log "Setting up Unraid User Scripts backup..."

    # Create User Scripts directory if it doesn't exist
    local user_scripts_dir="/boot/config/plugins/user.scripts/scripts"

    if [[ -d "$user_scripts_dir" ]]; then
        local backup_script_dir="$user_scripts_dir/cloud-backup"

        if [[ ! -d "$backup_script_dir" ]]; then
            log "Creating User Scripts backup entry..."
            mkdir -p "$backup_script_dir"

            # Create the User Scripts wrapper
            cat > "$backup_script_dir/script" << 'EOF'
#!/bin/bash
# Nextcloud Cloud Backup - User Scripts Integration
# This script is called by Unraid User Scripts plugin

SCRIPT_DIR="/mnt/user/appdata/docker/cloud/scripts"
if [[ -f "$SCRIPT_DIR/backup-cloud.sh" ]]; then
    echo "Starting Nextcloud Cloud backup..."
    bash "$SCRIPT_DIR/backup-cloud.sh"
else
    echo "ERROR: Backup script not found at $SCRIPT_DIR/backup-cloud.sh"
    exit 1
fi
EOF
            chmod +x "$backup_script_dir/script"

            # Create description file
            echo "Automated backup for Nextcloud Cloud services" > "$backup_script_dir/description"

            success "User Scripts backup entry created"
            log "Configure schedule in Unraid User Scripts plugin: Settings > User Scripts"
        else
            log "User Scripts backup entry already exists"
        fi
    else
        log "User Scripts plugin not detected. Install from Community Applications for automated backups."
        log "Manual backup available: $SCRIPT_DIR/backup-cloud.sh"
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
    echo "Unraid Integration:"
    echo "🖥️  Monitor containers: Unraid Docker tab"
    echo "📊 Resource usage: Unraid Dashboard"
    echo "⚙️  Backup scheduling: Settings > User Scripts"
    echo "🔧 Manual backup: $SCRIPT_DIR/backup-cloud.sh"
    echo "🔄 Restore backup: $SCRIPT_DIR/restore-cloud.sh"
    echo
    echo "Storage Locations:"
    echo "💾 App data: /mnt/user/appdata/nextcloud/"
    echo "💾 Documents: /mnt/user/appdata/paperless/"
    echo "💾 Wiki data: /mnt/user/appdata/bookstack/"
    echo "💾 Backups: /mnt/user/backups/cloud/"
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
    log "Starting Nextcloud Homelab Cloud setup for Unraid..."

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    check_prerequisites
    create_directories
    set_permissions
    setup_environment
    check_traefik_network
    deploy_services
    setup_unraid_backup

    success "Setup completed successfully!"
    display_access_info
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
