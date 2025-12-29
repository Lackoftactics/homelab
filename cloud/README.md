# Nextcloud Homelab Cloud Setup

A production-ready Docker Compose configuration for a personal homelab cloud setup centered around Nextcloud, with integrated document management and knowledge base systems.

## 🏗️ Architecture Overview

### Core Services
- **Nextcloud 29** (PHP-FPM) - Personal cloud storage and collaboration
- **PostgreSQL 16** - Primary database for all services
- **Redis 7** - Caching and session storage
- **Nginx** - Web server and reverse proxy for Nextcloud

### Additional Services
- **Paperless-ngx** - Document management with OCR capabilities
- **BookStack** - Wiki-style knowledge base for university materials

### Integration Features
- ✅ Traefik integration with automatic SSL certificates
- ✅ Tailscale network compatibility
- ✅ Security best practices implemented
- ✅ Health checks and auto-restart policies
- ✅ Resource limits for stability
- ✅ Optimized for performance

## 🚀 Quick Start

### Prerequisites
- **Unraid OS** with Docker enabled
- **Compose Manager** plugin installed (from Community Applications)
- **User Scripts** plugin (optional, for automated backups)
- Existing Traefik setup (from your infra directory)
- Domain configured (*.fajnachata.club)
- Sufficient storage space (recommend 100GB+ for `/mnt/user/appdata/`)

### 🎯 Unraid-Optimized Setup

This configuration is specifically optimized for Unraid OS with:
- Direct volume mounts (no complex named volumes)
- PUID/PGID environment variables for proper permissions
- Unraid User Scripts integration for backups
- Simplified directory structure

### 1. Automated Setup (Recommended)

```bash
# Navigate to the cloud directory
cd /mnt/user/appdata/docker/cloud

# Run the Unraid-optimized setup script
./scripts/setup.sh
```

### 2. Manual Setup (Alternative)

```bash
# Navigate to the cloud directory
cd /mnt/user/appdata/docker/cloud

# Create required directories (Unraid will handle permissions)
mkdir -p /mnt/user/appdata/nextcloud/{data,postgres,redis}
mkdir -p /mnt/user/appdata/paperless/{data,media,consume}
mkdir -p /mnt/user/appdata/bookstack/data
mkdir -p /mnt/user/backups/cloud

# Make scripts executable
chmod +x scripts/*.sh
chmod +x postgres/init-multiple-databases.sh
```

### 2. Environment Configuration

```bash
# Copy the example environment file
cp .env.example .env

# Edit the environment file with your secure passwords
nano .env
```

**Important**: Generate secure passwords for all services:
```bash
# Generate secure passwords
openssl rand -base64 32

# Generate Paperless secret key (50+ characters)
openssl rand -base64 64
```

### 3. Deploy Services

```bash
# Start the services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Initial Configuration

#### Nextcloud Setup
1. Access Nextcloud at `https://nextcloud.fajnachata.club`
2. Complete the initial setup wizard
3. Install recommended apps (Calendar, Contacts, Tasks)
4. Configure additional settings in Admin panel

#### Paperless-ngx Setup
1. Access Paperless at `https://paperless.fajnachata.club`
2. Login with admin credentials from .env file
3. Configure OCR languages and document processing
4. Set up consumption folders

#### BookStack Setup
1. Access BookStack at `https://bookstack.fajnachata.club`
2. Default login: `admin@admin.com` / `password`
3. Change default credentials immediately
4. Create your first book for university materials

## 🔧 Configuration Details

### Database Choice: PostgreSQL
- **Why PostgreSQL over MySQL/MariaDB?**
  - Better performance with complex queries
  - Superior concurrent access handling
  - More robust for production environments
  - Excellent JSON support for modern applications
  - Better compliance with SQL standards

### Security Features
- All services run with non-root users where possible
- Secrets managed through environment variables
- Security headers configured in Nginx
- Database access restricted to internal network
- Regular security updates through Alpine-based images

### Performance Optimizations
- Redis caching for Nextcloud sessions and data
- PHP OPcache enabled with optimized settings
- Nginx configured with gzip compression
- Resource limits prevent memory exhaustion
- Health checks ensure service reliability

## 📊 Monitoring and Maintenance

### Health Checks
All services include health checks that monitor:
- Database connectivity
- Application responsiveness
- Service-specific endpoints

### Log Management
```bash
# View service logs
docker-compose logs [service_name]

# Follow logs in real-time
docker-compose logs -f [service_name]

# View last 100 lines
docker-compose logs --tail=100 [service_name]
```

### Updates
```bash
# Update all services
docker-compose pull
docker-compose up -d

# Update specific service
docker-compose pull [service_name]
docker-compose up -d [service_name]
```

## 💾 Backup Strategy

### Critical Data Locations
- **Nextcloud Data**: `/mnt/user/appdata/nextcloud/data`
- **PostgreSQL Database**: `/mnt/user/appdata/nextcloud/postgres`
- **Paperless Documents**: `/mnt/user/appdata/paperless/{data,media}`
- **BookStack Data**: `/mnt/user/appdata/bookstack/data`

### Automated Backup Script
Create a backup script for regular data protection:

```bash
#!/bin/bash
# backup-cloud.sh - Automated backup script

BACKUP_DIR="/mnt/user/backups/cloud"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Stop services for consistent backup
cd /Volumes/appdata/docker/cloud
docker-compose stop

# Backup databases
docker-compose exec postgres pg_dumpall -U nextcloud_user > "$BACKUP_DIR/$DATE/databases.sql"

# Backup data directories
tar -czf "$BACKUP_DIR/$DATE/nextcloud_data.tar.gz" /mnt/user/appdata/nextcloud/data
tar -czf "$BACKUP_DIR/$DATE/paperless_data.tar.gz" /mnt/user/appdata/paperless
tar -czf "$BACKUP_DIR/$DATE/bookstack_data.tar.gz" /mnt/user/appdata/bookstack

# Restart services
docker-compose start

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \;

echo "Backup completed: $BACKUP_DIR/$DATE"
```

### Backup Schedule

#### Unraid User Scripts (Recommended)
1. Install **User Scripts** plugin from Community Applications
2. Go to **Settings > User Scripts**
3. Add new script: **cloud-backup** (created automatically by setup script)
4. Set schedule: **Daily at 2 AM** (`0 2 * * *`)

#### Manual Cron (Alternative)
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /mnt/user/appdata/docker/cloud/scripts/backup-cloud.sh
```

## 🔍 Troubleshooting

### Common Issues

#### Nextcloud Performance
- Check PHP memory limits in `nextcloud/php.ini`
- Verify Redis connection: `docker-compose exec redis redis-cli ping`
- Monitor database performance: `docker-compose exec postgres pg_stat_activity`

#### Database Connection Issues
- Verify PostgreSQL is healthy: `docker-compose ps postgres`
- Check database logs: `docker-compose logs postgres`
- Ensure environment variables are correct

#### SSL/TLS Issues
- Verify Traefik is running and healthy
- Check domain DNS resolution
- Ensure Cloudflare API tokens are valid

### Service-Specific Debugging

#### Nextcloud
```bash
# Access Nextcloud container
docker-compose exec nextcloud bash

# Run Nextcloud OCC commands
docker-compose exec nextcloud php occ status
docker-compose exec nextcloud php occ config:list
```

#### Paperless-ngx
```bash
# Check document processing
docker-compose logs paperless

# Access Paperless management
docker-compose exec paperless python manage.py shell
```

## 🔐 Security Recommendations

1. **Regular Updates**: Keep all services updated
2. **Strong Passwords**: Use unique, complex passwords for all services
3. **Network Segmentation**: Services communicate only through internal networks
4. **Access Control**: Limit access through Tailscale and proper firewall rules
5. **Monitoring**: Regularly check logs for suspicious activity
6. **Backups**: Maintain regular, tested backups
7. **SSL/TLS**: Ensure all connections use HTTPS

## 📚 Additional Resources

- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Paperless-ngx Documentation](https://paperless-ngx.readthedocs.io/)
- [BookStack Documentation](https://www.bookstackapp.com/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## 🤝 Integration with Existing Services

This setup is designed to work alongside your existing infrastructure:
- **Traefik**: Uses existing `traefik_proxy` network
- **Domain Pattern**: Follows `*.fajnachata.club` convention
- **Tailscale**: Compatible with your Tailscale network setup
- **Storage**: Uses standard `/mnt/user/appdata/` pattern
- **Environment**: Consistent with your existing `.env` patterns

## 🖥️ Unraid-Specific Features

### Container Management
- **Docker Tab**: Monitor all containers from Unraid's Docker tab
- **Resource Usage**: View CPU/RAM usage in Unraid Dashboard
- **Auto-Start**: Containers automatically start with Unraid
- **Updates**: Use Unraid's built-in update notifications

### Storage Integration
- **Cache Drive**: Containers run from cache drive for better performance
- **Array Storage**: Data stored on protected array storage
- **Mover**: Automatic data movement between cache and array
- **Snapshots**: Use Unraid's snapshot features for additional protection

### Backup Integration
- **User Scripts**: Automated backups through User Scripts plugin
- **CA Backup**: Compatible with Community Applications backup plugin
- **Manual Backups**: Easy manual backup execution from Unraid terminal

### Monitoring
- **Unraid Dashboard**: Resource usage and container status
- **Notifications**: Unraid can send alerts for container issues
- **Logs**: Access container logs through Unraid Docker tab
- **Health Checks**: Container health visible in Unraid interface

### Network Configuration
- **Bridge Mode**: Uses Unraid's default Docker bridge network
- **Traefik Integration**: Seamless integration with existing Traefik setup
- **Port Management**: No port conflicts with Unraid services
- **Tailscale**: Full compatibility with Tailscale exit nodes

### Performance Optimization
- **PUID/PGID**: Proper user mapping for Unraid permissions
- **Direct Mounts**: No performance overhead from named volumes
- **Resource Limits**: Prevents containers from overwhelming system
- **SSD Cache**: Fast access to frequently used data
