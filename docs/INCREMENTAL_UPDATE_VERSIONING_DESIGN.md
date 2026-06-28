# Incremental Update Versioning Design

Updated: 2026-06-28

This document defines the controlled release model for Monster & Hunter client updates, server pack deployment, and incremental hot-update packages. It is intentionally conservative: a broken update policy can strand players on incompatible clients, so version changes must be deliberate and auditable.

## Artifact Boundaries

The release system has three different artifact classes. They must not be mixed.

| Artifact | Example | Destination | Purpose |
| --- | --- | --- | --- |
| Full client build | `newrelease/mmm3.zip`, `newrelease/毛毛虫.exe` | Manually shared with players or a future installer/CDN lane | Updates the bootstrap executable, Godot runtime, GDExtensions, updater code, and bundled base content. |
| Public server pack | `newrelease/maomao_server.pck` | `/opt/maomao/maomao_server.pck` on VPS | Runs the authoritative public lobby and room server code. |
| Incremental hot-update package | `packages/core_patch_0.4.6.pck` | `/var/www/maomao-updates/maomao/<channel>/packages/` | Updates client content/scripts/resources that can be safely loaded from PCK packs. |

Public dedicated servers do not self-update from the client manifest. Server PCK deployment remains an ops action, even when the same gameplay changes also require a client hot-update package.

## Current Client Update Model

The current updater reads one current manifest URL, validates it, computes pending packages by stable package id, downloads missing or changed packages, verifies byte size and SHA-256, and stores installed state under `user://hot_update/`.

The client does **not** currently traverse a release chain such as `0.4.4 -> 0.4.5 -> 0.4.6`. A clean `0.4.4` client that reads the `0.4.6` manifest attempts to install the packages listed by the `0.4.6` manifest directly.

Therefore, until a release-index and delta-dependency resolver exist, every required package in the current manifest must be cumulative from the lowest supported base client version. For example, if `min_app_version` is `0.4.4`, then `core_patch_0.4.6.pck` must bring a clean `0.4.4` client directly to the `0.4.6` target state.

Historical packages are still kept on the VPS, but they are for rollback, in-flight client recovery, and manifests that still reference unchanged package versions. They are not a sequential migration script.

## Version Fields

| Field | Owner | When To Change | Meaning |
| --- | --- | --- | --- |
| `application/config/version` | Full client build | Change only when shipping a new base client build. | Bootstrap executable/client version. |
| Manifest `version` | Hot-update release | Change for every public manifest release. | Advertised content release, such as `0.4.6`. |
| Manifest `content_version` | Hot-update release | Change for every build attempt intended for testing or release. | Unique build identity, such as `2026.06.28.1`. |
| Package `version` | Package family | Change only when that package family changes. | Immutable package identity paired with SHA-256. |
| Manifest `min_app_version` | Release manager | Raise when older base clients cannot safely load the update. | Minimum full client version allowed to apply this manifest. |
| Manifest `protocol_version` | Network compatibility owner | Raise for breaking network/RPC/room protocol changes. | Multiplayer compatibility gate. |

Package filenames must include package id and package version. Once uploaded, a package filename is immutable. If bytes change, publish a new versioned file.

## When To Ship A Full Client Build

Ship a new full client build and bump `application/config/version` when any of these change:

- Hot-update bootstrap code under `scripts/hot_update/**`.
- Godot engine version, export template, or executable behavior.
- GDExtension DLLs, native plugins, Steam integration binaries, or platform runtime files.
- Project settings that must exist before update PCKs can be loaded.
- Manifest schema or update algorithm that old clients do not understand.
- Startup flow, updater UI, or early autoload ordering required for safe patch loading.
- A breaking network protocol change where old clients must be blocked from public rooms.

The current `core_patch` partition intentionally excludes `scripts/hot_update/**`, so updater changes cannot be delivered safely to old clients through hot update alone.

## When To Generate A Manifest

Generate a manifest only for a release candidate, not for every local edit.

Release candidate trigger:

1. Freeze the source commit or working build.
2. Decide release class: hot-update only, full client, server-only, or combined client/server.
3. Choose `version`, `content_version`, `min_app_version`, and `protocol_version`.
4. Build hot-update packages with `tools/hot_update/build_release_packages.py`.
5. Validate generated PCKs and manifest before any upload.
6. Upload packages to mirrors first.
7. Upload manifest last, with TX primary manifest last as the release switch.

Example:

```powershell
python tools/hot_update/build_release_packages.py `
  --partitions tools/hot_update/content_partitions.example.json `
  --release-dir builds/hot_update/dev/0.4.6 `
  --version 0.4.6 `
  --content-version 2026.06.28.1 `
  --min-app-version 0.4.4 `
  --base-url http://1.13.175.170/maomao/dev `
  --mirror-base-url al=http://8.153.148.157/maomao/dev `
  --protocol-version 1 `
  --run-export
```

## Package Retention Policy

The VPS must retain:

- All packages referenced by the current manifest.
- All packages referenced by the previous known-good manifest.
- All packages referenced by the lowest supported base-client compatibility window.
- Any package currently referenced by a rollback candidate.

Do not delete a package merely because a newer version exists. Delete only after confirming no retained manifest references it and no supported client path can request it.

## Publish Order

For TX primary plus AL mirror:

1. Upload package files to AL.
2. Upload package files to TX.
3. Verify package size and SHA-256 on both hosts.
4. Upload `manifest.json` to AL.
5. Upload `manifest.json` to TX last.

Publishing TX manifest last makes the new release visible to normal clients only after package files are present on both origins.

## Required Validation Gates

Before publishing TX manifest:

- Clean lowest-supported base client installs the latest manifest successfully.
- Previous release client installs the latest manifest successfully.
- Already-current client sees no pending required packages.
- Package primary URL failure falls back to mirror.
- Bad package bytes fail SHA-256 and are not promoted.
- Protocol mismatch blocks public lobby/room entry.
- Server PCK and client manifest agree on `protocol_version`.

## Future Release Index

A future release-index model can add sequential update traversal:

```json
{
  "schema_version": 1,
  "channel": "dev",
  "latest": "0.4.6",
  "releases": [
    {"version": "0.4.4", "manifest": "0.4.4/manifest.json"},
    {"version": "0.4.5", "manifest": "0.4.5/manifest.json"},
    {"version": "0.4.6", "manifest": "0.4.6/manifest.json"}
  ]
}
```

That requires a new full client build because old clients do not know how to read a release index or resolve dependency chains. Until then, current manifests remain cumulative target-state manifests.
