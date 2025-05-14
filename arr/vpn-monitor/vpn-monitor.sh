#!/bin/bash
# VPN Connection Monitor and Auto-healing Script
# This script monitors the VPN connection and attempts to heal it if issues are detected

# Configuration
CHECK_INTERVAL=300  # Check every 5 minutes
MAX_FAILURES=3      # Number of consecutive failures before taking action
LOG_FILE="/var/log/vpn-monitor.log"
HEALTH_ENDPOINT="http://gluetun:9999/health"
EXTERNAL_CHECK_URL="https://api.ipify.org"
QBITTORRENT_API="http://gluetun:8080/api/v2/app/version"

# Debug information
log_debug() {
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Print network diagnostic information
log_debug "Starting network diagnostics..."
log_debug "Checking DNS resolution..."
nslookup gluetun || echo "DNS resolution for gluetun failed"
log_debug "Checking connectivity to gluetun..."
ping -c 2 gluetun || echo "Cannot ping gluetun"

# Ensure we have proper permissions for Docker socket
if [ ! -w "/var/run/docker.sock" ]; then
    echo "WARNING: Docker socket is not writable. Auto-healing may not work properly."
    echo "This script may not be able to restart containers."
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Initialize counters
failure_count=0
success_count=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_vpn_connection() {
    # Check gluetun health endpoint with verbose output for debugging
    log_debug "Checking gluetun health endpoint: $HEALTH_ENDPOINT"
    HEALTH_RESPONSE=$(curl -v "$HEALTH_ENDPOINT" 2>&1)
    HEALTH_STATUS=$?
    log_debug "Health endpoint response: $HEALTH_RESPONSE"
    log_debug "Health endpoint status code: $HEALTH_STATUS"

    if [ $HEALTH_STATUS -ne 0 ]; then
        log "ERROR: Gluetun health endpoint not responding"
        return 1
    fi

    # Check if VPN is connected according to gluetun
    VPN_STATUS=$(curl -sf "$HEALTH_ENDPOINT")
    log_debug "VPN status response: $VPN_STATUS"

    if ! echo "$VPN_STATUS" | grep -q '"vpn_connected":true'; then
        log "ERROR: VPN is not connected according to gluetun"
        return 1
    fi

    # Check external connectivity
    log_debug "Checking external connectivity: $EXTERNAL_CHECK_URL"
    EXTERNAL_RESPONSE=$(curl -v "$EXTERNAL_CHECK_URL" 2>&1)
    EXTERNAL_STATUS=$?
    log_debug "External connectivity response: $EXTERNAL_RESPONSE"
    log_debug "External connectivity status code: $EXTERNAL_STATUS"

    if [ $EXTERNAL_STATUS -ne 0 ]; then
        log "ERROR: Cannot reach external services"
        return 1
    fi

    # Check qBittorrent connectivity
    log_debug "Checking qBittorrent API: $QBITTORRENT_API"
    QB_RESPONSE=$(curl -v "$QBITTORRENT_API" 2>&1)
    QB_STATUS=$?
    log_debug "qBittorrent API response: $QB_RESPONSE"
    log_debug "qBittorrent API status code: $QB_STATUS"

    if [ $QB_STATUS -ne 0 ]; then
        log "WARNING: qBittorrent API not responding"
        # This is just a warning, not a failure
    fi

    return 0
}

heal_vpn_connection() {
    log "HEALING: Attempting to heal VPN connection"

    # Check if Docker is running
    if ! docker ps > /dev/null 2>&1; then
        log "ERROR: Docker is not running, cannot heal"
        return 1
    fi

    # Restart gluetun container
    log "HEALING: Restarting gluetun container"
    docker restart gluetun

    # Wait for container to restart
    log "HEALING: Waiting for gluetun to restart (60s)"
    sleep 60

    # Check if healing was successful
    if check_vpn_connection; then
        log "HEALING: VPN connection restored successfully"
        return 0
    else
        log "HEALING: Failed to restore VPN connection"
        return 1
    fi
}

# Main loop
log "Starting VPN connection monitor"

while true; do
    if check_vpn_connection; then
        log "VPN connection is healthy"
        failure_count=0
        success_count=$((success_count + 1))

        # Log success stats every 12 hours (144 checks at 5-minute intervals)
        if [ $((success_count % 144)) -eq 0 ]; then
            log "STATS: VPN has been stable for $((success_count * CHECK_INTERVAL / 60)) hours"
        fi
    else
        failure_count=$((failure_count + 1))
        log "VPN connection check failed ($failure_count/$MAX_FAILURES)"

        if [ "$failure_count" -ge "$MAX_FAILURES" ]; then
            log "ALERT: $MAX_FAILURES consecutive failures detected, initiating healing"
            if heal_vpn_connection; then
                failure_count=0
                log "HEALED: VPN connection has been restored"
            else
                log "CRITICAL: Failed to heal VPN connection after $MAX_FAILURES attempts"
                # Could add more drastic measures here, like sending notifications
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
