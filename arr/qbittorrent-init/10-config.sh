#!/usr/bin/with-contenv bash
echo "[init] Waiting for WebUI…"
sleep 30
echo "[init] Applying secure preferences to qBittorrent"
curl -sf \
     -X POST \
     -d 'json={"interface_name":"tun0","bypass_local_auth":true,"bypass_auth_subnet_whitelist_enabled":true,"bypass_auth_subnet_whitelist":"127.0.0.1/32"}' \
     http://localhost:8080/api/v2/app/setPreferences
echo "[init] Done"