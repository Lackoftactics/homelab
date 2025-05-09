#!/bin/bash
# Jellyfin Health Check and Troubleshooting Script

echo "=== Jellyfin Health Check ==="
echo "Checking if Jellyfin is running..."

# Check if Jellyfin container is running
if docker ps | grep -q jellyfin; then
  echo "✅ Jellyfin container is running"
else
  echo "❌ Jellyfin container is not running"
  echo "Attempting to start Jellyfin..."
  cd /Volumes/appdata/docker/arr
  docker-compose up -d jellyfin
  sleep 10
  if docker ps | grep -q jellyfin; then
    echo "✅ Jellyfin container started successfully"
  else
    echo "❌ Failed to start Jellyfin container"
    echo "Checking logs for errors..."
    docker-compose logs jellyfin --tail 50
  fi
fi

# Check if Jellyfin is responding on its HTTP port
echo "Checking if Jellyfin is responding on port 8096..."
if curl -s -f http://localhost:8096/health > /dev/null; then
  echo "✅ Jellyfin is responding on port 8096"
else
  echo "❌ Jellyfin is not responding on port 8096"
fi

# Check if gluetun is healthy
echo "Checking if gluetun VPN is healthy..."
if curl -s -f http://localhost:9999/health > /dev/null; then
  echo "✅ Gluetun VPN is healthy"
else
  echo "❌ Gluetun VPN is not healthy"
  echo "This could be causing Jellyfin connectivity issues since Jellyfin uses gluetun's network"
  echo "Checking gluetun logs..."
  docker-compose logs gluetun --tail 20
fi

# Check Traefik routing
echo "Checking Traefik routing for Jellyfin..."
if docker exec -it traefik traefik healthcheck 2>/dev/null | grep -q "Health check successful"; then
  echo "✅ Traefik is running properly"
else
  echo "❓ Could not verify Traefik health (command may not be supported)"
fi

echo "=== Recommendations ==="
echo "1. If Jellyfin is running but not accessible, try restarting both gluetun and jellyfin:"
echo "   cd /Volumes/appdata/docker/arr && docker-compose restart gluetun jellyfin"
echo ""
echo "2. If you're getting a 'Bad Gateway' error, check that Jellyfin is properly configured to use port 8096:"
echo "   - Verify the port mapping in docker-compose.yml"
echo "   - Check that Traefik is routing to the correct port (8096)"
echo ""
echo "3. If hardware acceleration is causing issues, try disabling it temporarily:"
echo "   - Comment out the devices section in docker-compose.yml"
echo "   - Restart Jellyfin: docker-compose restart jellyfin"
echo ""
echo "4. Check Jellyfin logs for more detailed error information:"
echo "   docker-compose logs jellyfin --tail 100"
