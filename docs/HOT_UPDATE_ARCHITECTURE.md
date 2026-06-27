# Incremental Hot Update Architecture

Updated: 2026-06-27

This document is the working contract for Monster & Hunter incremental content updates on Godot 4.7. The goal is to avoid asking players to redownload a full exported game or a single multi-GB PCK when only a small set of resources changed.

## Current Constraints

- The existing Windows export preset still exports all resources and embeds the PCK into the executable. That is a good historical full-build artifact, but it is not an incremental update model.
- Runtime pack mounting must use `ProjectSettings.load_resource_pack(pack, replace_files := true)`.
- A mounted pack can override files already present in `res://` when paths match and `replace_files` is true.
- `DirAccess` does not reliably show files added to `res://` after `load_resource_pack`, so package contents must be described by the manifest instead of discovered by scanning mounted packs.
- The bootstrap updater itself must be treated as base-game code. If `scripts/hot_update/*` must change, ship a new base build or an external launcher update.
- Dedicated public servers should not self-update from the client manifest. Server PCK deployment stays an ops pipeline.

## Target Package Layout

Use a small base build plus ordered content packs:

| Package | Purpose | Expected cadence |
| --- | --- | --- |
| `bootstrap` | Godot executable, minimal boot scene, hot update scripts, version/protocol constants | Rare full build |
| `core_patch` | Gameplay scripts, UI scripts, localization, small config resources | Frequent small patch |
| `characters_party_monster` | Party Monster meshes, textures, materials, wrapper scenes | When character assets change |
| `maps_warehouse` | Current Warehouse map resources and prop catalogs | When map/layout changes |
| `maps_polygon_apocalypse` | Large migrated city resources | Optional/on-demand map content |
| `audio_video` | Intro media, music, large UI/audio/video assets | Rare and optional |

The important rule is that large assets should live in stable package families. A gameplay-script fix must not require downloading a map or character PCK.

The initial machine-readable partition plan lives in `tools/hot_update/content_partitions.example.json`. Treat it as the input for a temporary export-preset generator, not as a final hand-maintained Godot preset. The current production `Windows Desktop` preset can remain the full-build fallback while package presets are generated for CI/release jobs.

## Manifest Contract

The remote manifest is a JSON object:

```json
{
  "schema_version": 1,
  "app_id": "monster_hunter",
  "channel": "dev",
  "version": "0.4.5",
  "content_version": "2026.06.27.1",
  "min_app_version": "0.4.4",
  "protocol_version": 1,
  "base_url": "https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/dev",
  "mirrors": [
    {
      "id": "AL",
      "base_url": "https://<AL_PUBLIC_IP_OR_DOMAIN>/maomao/dev"
    }
  ],
  "packages": [
    {
      "id": "core_patch",
      "version": "0.4.5",
      "type": "patch",
      "url": "packages/core_patch_0.4.5.pck",
      "sha256": "64 lowercase hex characters",
      "size_bytes": 123456,
      "load_order": 10,
      "required": true,
      "restart_required": true
    }
  ]
}
```

Package fields:

- `id`: Stable package family id. Do not put timestamps here.
- `version`: Package version. Bump only when this package changes.
- `type`: `base`, `content`, `patch`, `delta`, or `launcher`.
- `url`: Relative to `base_url`, or absolute `https://...`.
- `sha256`: Mandatory SHA-256 of the final downloadable file.
- `size_bytes`: Mandatory byte count.
- `load_order`: Lower values mount first. Script/config patches should mount before large content packs.
- `required`: Required packages are considered during the default update check. Optional packages stay in the manifest but are not auto-downloaded unless the caller explicitly includes optional content.
- `restart_required`: True for script, scene, project config, autoload, or shader changes.

Top-level `base_url` is the primary package origin. For the current VPS topology, `base_url` must point to TX and top-level `mirrors` should include AL. Package URLs are tried in this order: absolute package URL or TX `base_url` first, then AL mirror base URLs, then any package-level absolute mirror URLs.

Installed state is written to `user://hot_update/installed_manifest.json`. Downloaded packages live under `user://hot_update/packages/`.

## Runtime Flow

1. `HotUpdate` autoload enters before `Network`.
2. If enabled and not running as a public dedicated server, it loads verified installed packages from `user://hot_update/packages/`.
3. If `hot_update/auto_check_on_boot` or `MAOMAO_UPDATE_MANIFEST_URL` is configured, it downloads the remote manifest with `HTTPRequest`. `MAOMAO_UPDATE_MANIFEST_MIRROR_URLS` or `hot_update/manifest_mirror_urls` can provide manifest fallback sources.
4. The manifest is validated for schema, channel, app version, protocol version, package SHA, and package order.
5. Missing or changed required packages are downloaded into `user://hot_update/tmp/`. Optional packages can be downloaded by calling the check path with optional content enabled for a later content browser or map-selection flow.
6. Each package is verified by byte count and SHA-256 before being promoted into `user://hot_update/packages/`.
7. Installed state is saved atomically enough for the next launch.
8. If any package has `restart_required=true`, the UI should ask the player to restart before joining online rooms.

Runtime project settings:

- `hot_update/enabled`: Master client-side switch.
- `hot_update/server_enabled`: Keep false for public servers unless ops explicitly wants server-side pack loading.
- `hot_update/auto_check_on_boot`: Whether to fetch the manifest automatically during boot.
- `hot_update/load_installed_packs_on_boot`: Whether to mount already installed packs before other autoloads run.
- `hot_update/show_status_overlay`: Whether to show a small in-game status panel for checking/installing updates.
- `hot_update/manifest_url`: Default remote manifest URL.
- `hot_update/manifest_mirror_urls`: Optional manifest mirror URL list, used after the primary manifest URL fails.
- `hot_update/channel`: Client channel such as `dev`, `staging`, or `live`.
- `hot_update/protocol_version`: Network/content protocol gate.
- `hot_update/http_timeout_sec`: Manifest request timeout. `0.0` disables the timeout.
- `hot_update/package_timeout_sec`: Package download timeout. Defaults to `0.0` because large PCK downloads should not fail only because they exceed a short manifest timeout.
- `hot_update/download_chunk_size_bytes`: HTTP package download chunk size. Defaults to `1048576` bytes to keep large PCK downloads moving faster than Godot's conservative default.

## Export Pipeline

Recommended near-term pipeline:

1. Keep the current full export for emergency fallback.
2. Add a dedicated bootstrap export preset with `binary_format/embed_pck=false` once the first updater build is accepted.
3. Export package PCKs by family from `tools/hot_update/content_partitions.example.json`. Use Godot 4.7 `--export-patch` for `core_patch`; use `--export-pack` for large stable asset families.
4. Generate a manifest with `tools/hot_update/build_manifest.py`.
5. Upload `manifest.json` and `packages/*.pck` to a static HTTPS origin or CDN.
6. Keep old package files for at least one previous public version so clients can update from yesterday's build.

Release-plan command:

```powershell
python tools/hot_update/build_release_packages.py `
  --partitions tools/hot_update/content_partitions.example.json `
  --release-dir builds/hot_update/dev/0.4.5 `
  --version 0.4.5 `
  --content-version 2026.06.27.1 `
  --min-app-version 0.4.4 `
  --base-url https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/dev `
  --mirror-base-url AL=https://<AL_PUBLIC_IP_OR_DOMAIN>/maomao/dev
```

This writes `package_plan.json`, `export_plan.json`, and `export_hot_update.ps1` under the release directory. Add `--run-export` to let the script temporarily swap in generated Godot export presets, call Godot 4.7 `--export-pack` or `--export-patch`, restore the original `export_presets.cfg`, and write `manifest.json`. The generated manifest keeps TX as `base_url` and writes AL into `mirrors`.

Validated local export snapshot from 2026-06-27:

| Package | Size | Notes |
| --- | ---: | --- |
| `core_patch_0.4.5.pck` | 5.49 MB | Script/UI/config patch lane. |
| `characters_party_monster_0.4.5.pck` | 110.97 MB | Party Monster asset family. |
| `maps_warehouse_0.4.5.pck` | 357.52 MB | Current warehouse map family and required migrated dependencies. |
| `audio_video_0.4.5.pck` | 15.64 MB | Audio/video package lane. |

The first real export proves that the update model no longer depends on one 1.34 GB monolithic PCK. In the validated manifest, only `core_patch` is `required=true`; the larger map, character, and media packs are advertised as optional/on-demand packages. It also shows a Godot export behavior to remember: `--export-pack` may include `project.binary`, autoload dependencies, and imported dependency resources that are needed by selected files. Treat `include_filter` and `exclude_filter` as the partition intent, then verify the actual PCK contents and size during release.

Large package install tests should use the status/progress output from `HotUpdateManager`. The downloader polls Godot 4.7 `HTTPRequest.get_downloaded_bytes()` and `HTTPRequest.get_body_size()` so failures can be tied to a specific package instead of a silent "installing" timeout.

VPS/static-origin deployment details live in `docs/HOT_UPDATE_VPS_DEPLOYMENT.md`.

## Version Rules

- `application/config/version` is the bootstrap/base game version.
- Manifest `version` is the currently advertised content release.
- Package `version` changes only when that package changes.
- `protocol_version` gates network compatibility. If it changes, clients must update before joining public rooms.
- Public lobby room metadata should eventually include `content_version` and `protocol_version`, not just the Steam lobby version string.

## Security And Failure Rules

- Never load a package whose SHA-256 does not match the manifest.
- Prefer HTTPS for manifest and packages.
- Do not accept arbitrary URLs from player input.
- Do not load packages from multiplayer peers.
- Keep public-server update deployment separate from client self-update.
- Treat updater script changes as a full bootstrap update.

## Implemented In This Branch

- `scripts/hot_update/hot_update_constants.gd`
- `scripts/hot_update/hot_update_manifest.gd`
- `scripts/hot_update/hot_update_store.gd`
- `scripts/hot_update/hot_update_downloader.gd`
- `scripts/hot_update/hot_update_manager.gd`
- `scripts/hot_update/hot_update_status_overlay.gd`
- `tests/hot_update_manifest_test.gd`
- `tests/hot_update_http_install_test.gd`
- `tests/hot_update_release_pack_load_test.gd`
- `tests/hot_update_release_pack_load_test.py`
- `tests/hot_update_release_manifest_install_test.py`
- `tools/hot_update/build_manifest.py`
- `tools/hot_update/build_release_packages.py`
