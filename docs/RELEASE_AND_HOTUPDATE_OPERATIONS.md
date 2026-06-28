# Release & Hot-Update Operations

Practical runbook for shipping Monster & Hunter: client baselines, incremental client
hot updates, the dedicated-server pack (full + **incremental**), and how to read the
version a live server is running. Read this before cutting a release.

Related: [HOT_UPDATE_ARCHITECTURE.md](HOT_UPDATE_ARCHITECTURE.md) (design),
[INCREMENTAL_UPDATE_REVIEW.md](INCREMENTAL_UPDATE_REVIEW.md) (version handshake).

## 0. Topology / cheat-sheet (TX — primary VPS)

| Thing | Value |
| --- | --- |
| SSH | `ubuntu@1.13.175.170` (key auth, passwordless sudo) |
| Update web root | `/var/www/maomao-updates/maomao/dev/` (nginx serves `/maomao/...`) |
| Manifest URL | `http://1.13.175.170/maomao/dev/manifest.json` (also in `project.godot [hot_update]`) |
| Server pack (runtime) | `/opt/maomao/maomao_server.pck` (loaded by the service) |
| Server service | `maomao-public.service` |
| Noray | docker container on TX, `8890/TCP` |
| Godot | `C:/Users/aresr/Desktop/Godot_v4.7-stable_win64.exe` (set `GODOT_BIN`) |

`build_info.json` (repo root) is the single source of truth for a build:
`version` (0.4.5), `build_id` (short commit), `content_version` (`0.4.5+<YYYYMMDD>.<commit>` —
this is what the version label shows and what the update check compares), `role`
(`baseline` | `hotpatch`). It ships inside `core_patch` and inside the server pack, so it
travels with the code.

## 1. One-click scripts (TL;DR)

| Script | Does |
| --- | --- |
| `tools/release_hotpatch.sh` | Build the small client `core_patch` PCK + manifest from `build_info.json` and publish to the TX update channel (incremental client update for 0.4.6+). |
| `tools/release_server.sh` | Export the dedicated-server pack and deploy it to TX **incrementally** (uploads a few-MB zstd patch, not 1.8 GB). |
| `tools/deploy_server_pack_incremental.sh <pck>` | Just the incremental deploy step (zstd `--patch-from`), used by `release_server.sh`. |
| `tools/export_public_server_pack.ps1` | Just the server export (versioned name + headless smoke test). |
| `tools/hot_update/build_release_packages.py` | Just the client package/manifest builder. |

All assume `GODOT_BIN` is set and the TX SSH key works. Run from the repo root.

## 2. The one bootstrap gotcha (must understand)

`project.godot` and `scripts/hot_update/**` are **bootstrap** — they cannot be hot-updated
(a pack can only be mounted by code that is already running). A client can only *apply*
downloaded packs on boot if `hot_update/load_installed_packs_on_boot` resolves true.

Its default is smart: **true in exported builds, false in the editor** — so do **not** set
it explicitly. The 0.4.4 baseline hard-set it `false`, which silently disabled update
application (clients downloaded packs but never mounted them). Fixing a bootstrap setting
like this requires shipping a **new full baseline** — it can't be hot-patched. This is why
0.4.5 was redistributed as a full baseline.

**`min_app_version` is compared against the bootstrap `application/config/version`, NOT the
content_version.** That bootstrap version is baked into the baseline and only changes with a
new full baseline (e.g. the 0.4.5 baseline still reports `config/version=0.4.4`). So a hot
patch's `min_app_version` must be **≤ the baseline's `config/version`**, or every baseline
silently rejects it with "Using bundled local content". `release_hotpatch.sh` derives it
from `project.godot` automatically — do not hardcode it above the shipped baseline's
`config/version`.

## 3. Client release — full baseline (rare)

Cut a new full baseline only when bootstrap changes (project.godot, the updater, engine/
template, or native extensions), or for a clean reset.

1. Make sure `build_info.json` is stamped (`role: baseline`, new `content_version`) and committed.
2. Full export: `godot --headless --path . --export-release "Windows Desktop" "builds/client/MonsterHunter_v<ver>_<commit>/MonsterHunter.exe"`.
3. Publish a **baseline manifest** (same `content_version`, `"packages": []`) to the TX
   web root so existing baselines see "nothing to fetch". (See `builds/releases/0.4.5_28ef6a52/manifest.json`.)
4. Zip the client folder → `MonsterHunter_v<ver>_<commit>.zip`, record SHA-256, distribute.

## 4. Client release — incremental hot update (0.4.6+, the normal path)

For code/UI/config changes (no new assets), ship a small `core_patch` over the current baseline.

1. Bump `build_info.json` to the new version: `content_version = <ver>+<YYYYMMDD>.<commit>`
   (must be strictly newer), keep `role` meaningful, then commit. Re-stamp to the commit if needed.
2. Run **`tools/release_hotpatch.sh`**. It builds `core_patch_<ver>.pck` (a few MB — `scripts/**`,
   UI scenes, `build_info.json`; excludes `scripts/hot_update/**`, assets) + `manifest.json` and
   publishes both to `/var/www/maomao-updates/maomao/dev/`.
3. Verify: `curl -s http://1.13.175.170/maomao/dev/manifest.json` — `content_version` bumped,
   `packages` lists `core_patch`.

Clients fetch the manifest on the startup screen, download `core_patch` if newer, and **mount
it on next boot** (the version label, scripts, and `build_info.json` update). Partition rules
live in `tools/hot_update/partitions_core_patch_only.json`.

## 5. Server release — full export

`GODOT_BIN=... pwsh -File tools/export_public_server_pack.ps1` →
`builds/server/MonsterHunter_Server_v<ver>_<commit>.pck` (~1.8 GB; excludes editor/visual-only
extensions; runs a headless smoke test). The name follows the client convention; on the VPS the
runtime path is always `/opt/maomao/maomao_server.pck`.

## 6. Server release — **incremental** deploy (avoid the 1.8 GB upload)

The server pack barely changes between releases, so upload only the delta with zstd
`--patch-from`. A one-line-of-script change produced a **2.3 MB** patch vs a 1.8 GB pack.

Prereqs (one-time): `zstd` on the build machine (`winget install Meta.Zstandard`) and on the
VPS (`apt install zstd` — TX already has it; needs ~2 GB free RAM for the `--long=31` window).

**One-click:** `GODOT_BIN=... tools/release_server.sh` (export + incremental deploy).

What `tools/deploy_server_pack_incremental.sh` does:
1. Reads the SHA-256 of the remote's currently deployed pack; finds the matching local pack (base).
2. `zstd -19 --long=31 --patch-from=<base> <new> -o patch.zst` → few-MB patch.
3. Uploads the patch; the VPS reconstructs `zstd -d --long=31 --patch-from=<deployed> patch.zst`.
4. **SHA-gated**: installs only if the reconstructed bytes equal the new pack; backs up the old
   pack, swaps it in, restarts `maomao-public.service`. Falls back to a full upload if no base matches.

Keep the last-deployed local pack around so the next deploy can diff against it (the script
auto-detects it by SHA). A server-only change (e.g. a log line) may keep the same `content_version`
to preserve handshake parity with the client baseline — the binary differs but the version is the same.

## 7. Which version is a live server running?

Three ways, best first:

1. **Server log (definitive — the running process):** the dedicated server prints its build on boot.
   ```
   ssh ubuntu@1.13.175.170 "journalctl -u maomao-public.service | grep DEDICATED-SERVER-VERSION | tail -1"
   # [MaoMao] DEDICATED-SERVER-VERSION content_version=0.4.5+20260628.28ef6a52 build_id=28ef6a52 protocol=1
   ```
   (Added in `scripts/startup_splash.gd::_change_to_dedicated_server_scene`; present from that build on.)
2. **On-disk pack (what will run after the next restart):**
   ```
   ssh ubuntu@1.13.175.170 'grep -ao "[0-9]\.[0-9]\.[0-9]+[0-9.a-f]*" /opt/maomao/maomao_server.pck | head -1'
   ```
3. **From a connecting client:** the advisory version handshake sends the server's `build_info`;
   a mismatch is logged client-side (warn only, never disconnects).

## 8. Decommissioned

AL (8.153.148.157) is abandoned: dropped from the manifest mirrors and
`hot_update/manifest_mirror_urls`. Do not deploy to AL.
