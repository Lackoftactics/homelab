FROM alpine:latest

# Install required packages
RUN apk add --no-cache bash curl docker-cli grep jq

# Create directories
RUN mkdir -p /var/log

# Copy the script
COPY vpn-monitor.sh /vpn-monitor.sh
RUN chmod +x /vpn-monitor.sh

# Set the entrypoint
CMD ["bash", "-c", "echo 'Waiting for gluetun to be fully ready...' && sleep 30 && echo 'Starting VPN monitor service' && /vpn-monitor.sh"]
