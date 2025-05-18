# AdGuard Home DNS Server with Tailscale Integration

This directory contains the Docker Compose configuration for running AdGuard Home as a network-wide DNS server with ad-blocking capabilities, optimized for use with Tailscale.

## Setup Instructions

1. Create the necessary directories for persistent storage:
   ```bash
   mkdir -p /mnt/user/appdata/adguardhome/work
   mkdir -p /mnt/user/appdata/adguardhome/conf
   ```

2. Copy the example environment file and adjust as needed:
   ```bash
   cp .env.example .env
   ```

3. Edit the `.env` file to set your Tailscale IP address:
   ```bash
   # Make sure this matches your Tailscale IP
   TAILSCALE_IP=100.92.119.22 # Replace with your Tailscale IP

   # Uncomment and set this if you want to bind to a specific local IP
   # HOST_IP=192.168.1.x
   ```

4. Start the AdGuard Home container:
   ```bash
   docker-compose up -d
   ```

5. Access the initial setup interface at:
   - http://your-server-ip:3000
   - or https://adguard-setup.yourdomain.com (if Traefik is configured)

6. After completing the setup, the main interface will be available at:
   - http://your-server-ip:8001
   - or https://adguard.yourdomain.com (if Traefik is configured)

## Tailscale Integration

This configuration is optimized for use with Tailscale:

1. **DNS Service Availability**:
   - DNS service is available on both your local network and Tailscale network
   - Port 53 is bound to both your host IP and Tailscale IP

2. **Tailscale DNS Configuration**:
   - You can configure Tailscale to use your AdGuard Home as a DNS server:
     - In Tailscale admin console: `DNS > Override local DNS > Add nameserver > [Your Tailscale IP]:53`
   - This will make all your Tailscale-connected devices use AdGuard Home for DNS

3. **MagicDNS Integration**:
   - If you're using Tailscale's MagicDNS, AdGuard Home can complement it by:
     - Blocking ads and trackers across your Tailnet
     - Providing additional DNS features like custom DNS records
     - Offering detailed analytics on DNS queries

## Configuration Recommendations

### DNS Upstream Servers

For better privacy and security, consider using encrypted DNS providers:

- Cloudflare: `https://cloudflare-dns.com/dns-query` (DoH)
- Quad9: `https://dns.quad9.net/dns-query` (DoH with malware blocking)
- NextDNS: Custom configuration with your NextDNS ID

### Recommended Blocklists

- AdGuard DNS filter
- EasyList
- Steven Black's hosts
- OISD
- Malware Domain List

### Network Configuration

After setup, you have several options for using AdGuard Home:

1. **Router Configuration**: Set your router to use AdGuard Home as the primary DNS server
2. **Tailscale Configuration**: Configure Tailscale to use AdGuard Home for all Tailnet devices
3. **Individual Devices**: Configure specific devices to use AdGuard Home
4. **Mixed Approach**: Use different DNS servers for different network segments

## Troubleshooting

- If port 53 is already in use, you may need to stop any existing DNS services on your host.
- Check logs with `docker-compose logs adguardhome`
- Verify DNS resolution with `nslookup example.com your-server-ip`
- For Tailscale-specific issues, check `tailscale status` to verify connectivity
