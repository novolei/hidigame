#!/usr/bin/env bash
# One-click client hot-update (core_patch) release for 0.4.6+ incremental updates.
#
# Builds the small code/UI core_patch PCK + manifest from the CURRENT build_info.json
# and publishes them to the VPS update channel. Baseline clients then auto-download the
# few-MB patch on next launch and mount it on boot (see RELEASE_AND_HOTUPDATE_OPERATIONS.md).
#
# Prereq: bump + commit build_info.json to the new version FIRST (content_version must be
# strictly newer than what clients currently run), e.g. 0.4.6+<YYYYMMDD>.<short_commit>.
#
# Usage:
#   GODOT_BIN="C:/Users/aresr/Desktop/Godot_v4.7-stable_win64.exe" tools/release_hotpatch.sh
# Env overrides:
#   GODOT_BIN, REMOTE (ubuntu@1.13.175.170), WEB_ROOT (/var/www/maomao-updates/maomao/dev),
#   BASE_URL (http://1.13.175.170/maomao/dev), SKIP_BUILD=1
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-C:/Users/aresr/Desktop/Godot_v4.7-stable_win64.exe}"
REMOTE="${REMOTE:-ubuntu@1.13.175.170}"
WEB_ROOT="${WEB_ROOT:-/var/www/maomao-updates/maomao/dev}"
BASE_URL="${BASE_URL:-http://1.13.175.170/maomao/dev}"
SSH_OPTS="-o BatchMode=yes"

read -r VERSION BUILD_ID CONTENT_VERSION < <(python -c "import json;d=json.load(open('build_info.json'));print(d['version'],d['build_id'],d['content_version'])" | tr -d '\r')
# min_app_version gates which BASELINE can apply this patch, and the client compares it
# against application/config/version (the bootstrap version baked into the baseline) — NOT
# the content_version. That bootstrap version only changes when a new full baseline ships,
# so derive it from project.godot instead of hardcoding, or baselines silently reject the
# patch ("Using bundled local content").
MIN_APP_VERSION="${MIN_APP_VERSION:-$(grep -E '^config/version=' project.godot | head -1 | sed -E 's/^config\/version="?([^"]*)"?.*/\1/' | tr -d '\r')}"
[ -n "$MIN_APP_VERSION" ] || MIN_APP_VERSION="$VERSION"
REL_DIR="builds/releases/${VERSION}_${BUILD_ID}"
echo "[hotpatch] version=$VERSION build=$BUILD_ID content_version=$CONTENT_VERSION min_app_version=$MIN_APP_VERSION"
echo "[hotpatch] release dir: $REL_DIR"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "[hotpatch] building core_patch PCK + manifest..."
  python tools/hot_update/build_release_packages.py \
    --partitions tools/hot_update/partitions_core_patch_only.json \
    --release-dir "$REL_DIR" \
    --version "$VERSION" \
    --content-version "$CONTENT_VERSION" \
    --min-app-version "$MIN_APP_VERSION" \
    --base-url "$BASE_URL" \
    --channel dev --protocol-version 1 \
    --godot-bin "$GODOT_BIN" --template-preset "Windows Desktop" \
    --run-export >/dev/null
fi

MANIFEST="$REL_DIR/manifest.json"
[ -f "$MANIFEST" ] || { echo "ERROR: manifest not built: $MANIFEST"; exit 1; }
echo "[hotpatch] publishing to $REMOTE:$WEB_ROOT ..."
ssh $SSH_OPTS "$REMOTE" "rm -rf /tmp/mh-hp && mkdir -p /tmp/mh-hp/packages"
scp $SSH_OPTS "$MANIFEST" "$REMOTE:/tmp/mh-hp/manifest.json"
scp $SSH_OPTS "$REL_DIR"/packages/*.pck "$REMOTE:/tmp/mh-hp/packages/" 2>/dev/null || echo "[hotpatch] (no package files — baseline-style manifest)"
ssh $SSH_OPTS "$REMOTE" "set -e
sudo mkdir -p '$WEB_ROOT/packages'
if ls /tmp/mh-hp/packages/*.pck >/dev/null 2>&1; then sudo cp -f /tmp/mh-hp/packages/*.pck '$WEB_ROOT/packages/'; fi
sudo cp -f /tmp/mh-hp/manifest.json '$WEB_ROOT/manifest.json'
sudo chmod 0644 '$WEB_ROOT/manifest.json' '$WEB_ROOT'/packages/*.pck 2>/dev/null || true
rm -rf /tmp/mh-hp
echo '--- published ---'; ls -lh '$WEB_ROOT/manifest.json' '$WEB_ROOT'/packages/ 2>/dev/null"

echo "[hotpatch] done. verify:"
echo "  curl -s $BASE_URL/manifest.json"
