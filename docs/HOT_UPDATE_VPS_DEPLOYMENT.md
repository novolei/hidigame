# Hot Update VPS Deployment

Updated: 2026-06-27

This is the first deployment contract for serving Monster & Hunter incremental update manifests and PCK packages from a VPS. The server can be a static HTTPS origin; no game-specific backend is required for the first version.

## Directory Layout

Recommended VPS path:

```text
/var/www/maomao-updates/
  dev/
    manifest.json
    packages/
      core_patch_0.4.5.pck
      characters_party_monster_0.4.5.pck
      maps_warehouse_0.4.5.pck
  live/
    manifest.json
    packages/
```

Client manifest URL examples:

```text
https://updates.example.com/maomao/dev/manifest.json
https://updates.example.com/maomao/live/manifest.json
```

Set the client with either `hot_update/manifest_url` in `project.godot` or the `MAOMAO_UPDATE_MANIFEST_URL` environment variable.

## Nginx Example

```nginx
server {
    listen 443 ssl http2;
    server_name updates.example.com;

    root /var/www/maomao-updates;

    location ~ /manifest\.json$ {
        default_type application/json;
        add_header Cache-Control "no-cache";
        try_files $uri =404;
    }

    location ~ \.pck$ {
        default_type application/octet-stream;
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files $uri =404;
    }
}
```

Keep TLS enabled. The client verifies package SHA-256, but HTTPS still protects the manifest and prevents easy downgrade or replacement attacks.

## Build And Publish

From the project root:

```powershell
python tools/hot_update/build_release_packages.py `
  --partitions tools/hot_update/content_partitions.example.json `
  --release-dir builds/hot_update/dev/0.4.5 `
  --version 0.4.5 `
  --content-version 2026.06.27.1 `
  --min-app-version 0.4.4 `
  --base-url https://updates.example.com/maomao/dev `
  --run-export
```

The release directory should contain:

```text
package_plan.json
export_plan.json
export_hot_update.ps1
manifest.json
packages/*.pck
```

Publish package files first, then publish `manifest.json` last. This prevents a client from seeing a manifest that references a package that is not uploaded yet.

## Pre-Publish Validation

Before uploading the release directory, verify the generated manifest and PCKs locally:

```powershell
python tests/hot_update_release_pack_load_test.py
python tests/hot_update_release_manifest_install_test.py
```

`hot_update_release_pack_load_test.py` verifies every generated PCK from `builds/hot_update/dev/0.4.5/manifest.json` by size, SHA-256, and `ProjectSettings.load_resource_pack()`.

`hot_update_release_manifest_install_test.py` starts a local HTTP server and verifies the client download/install path with the generated release manifest. By default it installs only `core_patch` so the check stays fast. Use this for a full local long run:

```powershell
$env:MAOMAO_TEST_RELEASE_PACKAGE_IDS = "all"
$env:MAOMAO_TEST_INSTALL_TIMEOUT_SEC = "900"
python tests/hot_update_release_manifest_install_test.py
```

The full local HTTP run can be much slower than a real VPS/CDN transfer on this machine, so keep the direct PCK load test as the required all-package gate and use the full HTTP run as an overnight stress check.

## Rollback

Keep package files for at least the previous public release. To roll back:

1. Replace `manifest.json` with the previous known-good manifest.
2. Do not delete packages referenced by either the current or previous manifest.
3. Restart affected clients only if the rolled-back manifest contains `restart_required=true` packages.

## Cache Rules

- `manifest.json`: no-cache, because clients must see the latest release decision.
- `packages/*.pck`: immutable, because package URLs include package id and version. Never overwrite an existing package file with different bytes.
- If a package was built incorrectly, bump its package version or content release and publish a new file.

## Public Servers

Public dedicated servers should not self-update from the client manifest by default. Keep `hot_update/server_enabled=false` unless an ops deployment flow explicitly enables and validates server-side pack loading. Server and client must still agree on `protocol_version` before joining rooms.
