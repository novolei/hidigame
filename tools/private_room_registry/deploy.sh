#!/usr/bin/env bash
# Deploy the private-room registry to the TX VPS: install the python service under systemd,
# then expose it through the existing nginx on port 80 under /private_rooms/ (no new firewall
# port needed). The nginx edit is additive and gated on `nginx -t`, so it cannot take down the
# update channel. Run from the repo root.
#
# Usage: REMOTE=ubuntu@1.13.175.170 tools/private_room_registry/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

REMOTE="${REMOTE:-ubuntu@1.13.175.170}"
SSH_OPTS="-o BatchMode=yes"
SRC="tools/private_room_registry"
echo "[registry] deploying to $REMOTE ..."

scp $SSH_OPTS "$SRC/registry.py" "$REMOTE:/tmp/registry.py"
scp $SSH_OPTS "$SRC/maomao-private-registry.service" "$REMOTE:/tmp/maomao-private-registry.service"

ssh $SSH_OPTS "$REMOTE" 'set -e
sudo mkdir -p /opt/maomao-private-registry
sudo cp -f /tmp/registry.py /opt/maomao-private-registry/registry.py
sudo cp -f /tmp/maomao-private-registry.service /etc/systemd/system/maomao-private-registry.service
sudo systemctl daemon-reload
sudo systemctl enable --now maomao-private-registry.service
sleep 1
echo "--- service status ---"
systemctl is-active maomao-private-registry.service
echo "--- local health ---"
curl -s http://127.0.0.1:8088/private_rooms/health || echo "(health check failed)"
echo

# Expose through nginx under /private_rooms/ if not already wired. Additive + nginx -t gated.
SITE=$(grep -rls "maomao-updates" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -1)
if [ -z "$SITE" ]; then SITE=$(grep -rls "server_name" /etc/nginx/sites-enabled 2>/dev/null | head -1); fi
echo "nginx site: ${SITE:-<not found>}"
if [ -n "$SITE" ] && ! sudo grep -q "/private_rooms/" "$SITE"; then
  sudo cp "$SITE" "${SITE}.bak.$(date +%s)"
  # Insert the location just inside the first server { ... } block.
  sudo awk '\''
    BEGIN{done=0}
    /server[[:space:]]*\{/ && !done {
      print;
      print "    location /private_rooms/ { proxy_pass http://127.0.0.1:8088/private_rooms/; proxy_read_timeout 8s; }";
      done=1; next
    }
    {print}
  '\'' "$SITE" | sudo tee "${SITE}.new" >/dev/null
  sudo mv "${SITE}.new" "$SITE"
  if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "nginx reloaded with /private_rooms/ location"
  else
    echo "!! nginx -t FAILED — restoring backup"
    sudo mv "$(ls -t ${SITE}.bak.* | head -1)" "$SITE"
  fi
else
  echo "nginx already has /private_rooms/ (or site not found) — skipping nginx edit"
fi
echo "--- done ---"'

echo "[registry] verify externally:"
echo "  curl -s http://1.13.175.170/private_rooms/health"
