#!/usr/bin/env bash
# Incremental dedicated-server PCK deploy via `zstd --patch-from`.
#
# Why: the headless server pack is ~1.8 GB but changes very little between releases
# (mostly a few scripts). Uploading the whole pack every time is painful. zstd's
# --patch-from builds a binary patch against the previously deployed pack, so we
# upload only the delta (typically a few MB) and reconstruct the full pack on the VPS.
#
# It compares the remote's currently deployed pack to a local copy with the same
# SHA-256 (the "base"); the patch is built old->new locally, uploaded, and applied
# remotely. Reconstruction is SHA-gated: the server pack is only swapped in if the
# reconstructed bytes match the new pack exactly. Falls back to a full upload when no
# local base matches the remote (e.g. first deploy on a new machine).
#
# Usage:
#   tools/deploy_server_pack_incremental.sh <new_pck> [base_pck]
# Env overrides:
#   REMOTE (default ubuntu@1.13.175.170), REMOTE_PATH (/opt/maomao/maomao_server.pck),
#   SERVICE (maomao-public.service), LONG (zstd window log2, 31 = 2 GiB), ZSTD (zstd path)
set -euo pipefail

NEW_PCK="${1:?usage: deploy_server_pack_incremental.sh <new_pck> [base_pck]}"
BASE_PCK="${2:-}"
REMOTE="${REMOTE:-ubuntu@1.13.175.170}"
REMOTE_PATH="${REMOTE_PATH:-/opt/maomao/maomao_server.pck}"
SERVICE="${SERVICE:-maomao-public.service}"
LONG="${LONG:-31}"
SSH_OPTS="-o BatchMode=yes"

# Resolve a zstd binary (PATH, or the winget install location used on this build machine).
ZSTD="${ZSTD:-zstd}"
if ! command -v "$ZSTD" >/dev/null 2>&1; then
  ZSTD="/c/Users/aresr/AppData/Local/Microsoft/WinGet/Packages/Meta.Zstandard_Microsoft.Winget.Source_8wekyb3d8bbwe/zstd-v1.5.7-win64/zstd.exe"
fi
command -v "$ZSTD" >/dev/null 2>&1 || { echo "ERROR: zstd not found (winget install Meta.Zstandard)"; exit 1; }
[ -f "$NEW_PCK" ] || { echo "ERROR: new pck not found: $NEW_PCK"; exit 1; }

NEW_SHA=$(sha256sum "$NEW_PCK" | cut -d' ' -f1)
echo "[deploy] new pck   : $NEW_PCK"
echo "[deploy] new sha   : $NEW_SHA"

REMOTE_SHA=$(ssh $SSH_OPTS "$REMOTE" "sha256sum '$REMOTE_PATH' 2>/dev/null | cut -d' ' -f1" || true)
echo "[deploy] remote sha: ${REMOTE_SHA:-<none>}"
if [ "$REMOTE_SHA" = "$NEW_SHA" ]; then
  echo "[deploy] remote already at target; nothing to do."
  exit 0
fi

# Auto-detect a local base whose SHA matches what is currently deployed remotely.
if [ -z "$BASE_PCK" ] && [ -n "${REMOTE_SHA:-}" ]; then
  for f in "$(dirname "$NEW_PCK")"/*.pck; do
    [ -f "$f" ] || continue
    if [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$REMOTE_SHA" ]; then BASE_PCK="$f"; break; fi
  done
fi

STAGE="/tmp/mh-srv-deploy-$$"
INSTALL_REMOTE="set -e
got=\$(sha256sum '$STAGE.pck' | cut -d' ' -f1)
if [ \"\$got\" != '$NEW_SHA' ]; then echo \"ERROR reconstructed/uploaded sha \$got != $NEW_SHA\"; rm -f '$STAGE.pck' '$STAGE.zst'; exit 1; fi
ts=\$(date +%Y%m%d%H%M%S)
cp -f '$REMOTE_PATH' '$REMOTE_PATH.bak-'\$ts 2>/dev/null || true
cp -f '$STAGE.pck' '$REMOTE_PATH'
chmod 0644 '$REMOTE_PATH'
rm -f '$STAGE.pck' '$STAGE.zst'
ls -t '$REMOTE_PATH'.bak-* 2>/dev/null | tail -n +2 | xargs -r rm -f
sudo systemctl restart '$SERVICE'
sleep 3
systemctl is-active '$SERVICE'"

if [ -n "$BASE_PCK" ] && [ -f "$BASE_PCK" ]; then
  echo "[deploy] base (== remote): $BASE_PCK"
  PATCH="$(dirname "$NEW_PCK")/.srv_patch_$$.zst"
  "$ZSTD" -19 --long="$LONG" --patch-from="$BASE_PCK" "$NEW_PCK" -o "$PATCH" -f -q
  echo "[deploy] patch size: $(ls -lh "$PATCH" | awk '{print $5}') (vs full $(ls -lh "$NEW_PCK" | awk '{print $5}'))"
  scp $SSH_OPTS "$PATCH" "$REMOTE:$STAGE.zst"
  rm -f "$PATCH"
  ssh $SSH_OPTS "$REMOTE" "set -e
zstd -d --long=$LONG --patch-from='$REMOTE_PATH' '$STAGE.zst' -o '$STAGE.pck' -f -q
$INSTALL_REMOTE"
else
  echo "[deploy] no local base matches remote -> full upload fallback"
  scp $SSH_OPTS "$NEW_PCK" "$REMOTE:$STAGE.pck"
  ssh $SSH_OPTS "$REMOTE" "$INSTALL_REMOTE"
fi

echo "[deploy] done. verify live version:"
echo "  ssh $REMOTE \"journalctl -u $SERVICE | grep DEDICATED-SERVER-VERSION | tail -1\""
