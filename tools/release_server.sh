#!/usr/bin/env bash
# One-click dedicated-server release: export the server PCK, then deploy it to the VPS
# incrementally (zstd patch, ~a few MB) instead of re-uploading the full ~1.8 GB.
#
# Usage:
#   GODOT_BIN="C:/Users/aresr/Desktop/Godot_v4.7-stable_win64.exe" tools/release_server.sh
# Env overrides (also forwarded to the deploy step):
#   GODOT_BIN, REMOTE, REMOTE_PATH, SERVICE, SKIP_EXPORT=1 (deploy an already-built pck)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-C:/Users/aresr/Desktop/Godot_v4.7-stable_win64.exe}"

# Server pack name follows the client convention (game + version + build commit),
# derived from build_info.json — the same name export_public_server_pack.ps1 produces.
read -r VERSION BUILD_ID < <(python -c "import json;d=json.load(open('build_info.json'));print(d['version'],d['build_id'])")
NEW_PCK="builds/server/MonsterHunter_Server_v${VERSION}_${BUILD_ID}.pck"
echo "[release-server] target: $NEW_PCK (version $VERSION, build $BUILD_ID)"

if [ "${SKIP_EXPORT:-0}" != "1" ]; then
  echo "[release-server] exporting server pack (this also runs a headless smoke test)..."
  pwsh -NoProfile -File tools/export_public_server_pack.ps1 -GodotExe "$GODOT_BIN" >/dev/null
fi
[ -f "$NEW_PCK" ] || { echo "ERROR: server pack not found: $NEW_PCK"; exit 1; }

echo "[release-server] deploying incrementally..."
tools/deploy_server_pack_incremental.sh "$NEW_PCK"

echo "[release-server] done."
