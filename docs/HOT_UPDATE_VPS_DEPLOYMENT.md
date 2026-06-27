# Hot Update VPS Deployment

Updated: 2026-06-27

This is the deployment contract for serving Monster & Hunter incremental update manifests and PCK packages from static HTTPS origins. Use TX as the primary distribution VPS and AL as the auxiliary distribution VPS. No game-specific backend is required for this version.

## Directory Layout

Recommended path on both TX and AL:

```text
/var/www/maomao-updates/
  maomao/
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
https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/dev/manifest.json
https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/live/manifest.json
```

Set the client primary manifest URL with either `hot_update/manifest_url` in `project.godot` or the `MAOMAO_UPDATE_MANIFEST_URL` environment variable. Set auxiliary manifest URLs with `hot_update/manifest_mirror_urls` or `MAOMAO_UPDATE_MANIFEST_MIRROR_URLS`.

For the current TX/AL topology:

```powershell
$env:MAOMAO_UPDATE_MANIFEST_URL = "https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/dev/manifest.json"
$env:MAOMAO_UPDATE_MANIFEST_MIRROR_URLS = "https://<AL_PUBLIC_IP_OR_DOMAIN>/maomao/dev/manifest.json"
```

The manifest itself should use TX as `base_url` and AL in top-level `mirrors`. The client tries package downloads from TX first and automatically retries AL if TX fails, returns a bad file, or returns bytes that fail SHA-256 verification.

Current direct-IP development values:

```text
TX base URL: http://1.13.175.170/maomao/dev
AL base URL: http://8.153.148.157/maomao/dev
TX manifest: http://1.13.175.170/maomao/dev/manifest.json
AL manifest: http://8.153.148.157/maomao/dev/manifest.json
```

Direct IP over HTTP is acceptable for the first connectivity test, because HTTPS direct-IP URLs usually fail certificate hostname validation unless a matching certificate is installed. For public release, prefer DNS names with valid TLS certificates.

## Nginx Example

For a direct-IP smoke test, start with HTTP:

```nginx
server {
    listen 80;
    server_name _;

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

For domain-backed production, use HTTPS:

```nginx
server {
    listen 443 ssl http2;
    server_name <TX_OR_AL_PUBLIC_DOMAIN>;

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
  --base-url https://<TX_PUBLIC_IP_OR_DOMAIN>/maomao/dev `
  --mirror-base-url AL=https://<AL_PUBLIC_IP_OR_DOMAIN>/maomao/dev `
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

Publish package files first, then publish `manifest.json` last. With TX/AL, use this exact order:

1. Upload `packages/*.pck` to AL.
2. Upload `packages/*.pck` to TX.
3. Upload `manifest.json` to AL.
4. Upload `manifest.json` to TX last.

Publishing TX's manifest last makes TX the release switch. Clients that receive the new TX manifest can still download from AL if TX package transfer fails.

## Pre-Publish Validation

Before uploading the release directory, verify the generated manifest and PCKs locally:

```powershell
python tests/hot_update_release_pack_load_test.py
python tests/hot_update_release_manifest_install_test.py
```

Also verify package-source fallback before publishing:

```powershell
$env:MAOMAO_TEST_FORCE_PACKAGE_PRIMARY_404 = "1"
python tests/hot_update_release_manifest_install_test.py
Remove-Item Env:\MAOMAO_TEST_FORCE_PACKAGE_PRIMARY_404
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
