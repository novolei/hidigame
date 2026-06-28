# Incremental Update & Versioning — Review and Robust Design

Updated: 2026-06-28

Reviews the existing hot-update / VPS-pack / versioning design ([HOT_UPDATE_ARCHITECTURE.md](HOT_UPDATE_ARCHITECTURE.md),
[INCREMENTAL_UPDATE_VERSIONING_DESIGN.md](INCREMENTAL_UPDATE_VERSIONING_DESIGN.md),
[HOT_UPDATE_VPS_DEPLOYMENT.md](HOT_UPDATE_VPS_DEPLOYMENT.md)) against the actual code/tools, and
defines a robust target design so the test team never has to ship a ~1.4 GB full build for an
ordinary change, and so client/server version drift can no longer silently crash players.

## What already works (keep)

- **Family-partitioned packages.** `tools/hot_update/content_partitions.example.json` splits the
  game into `bootstrap` (base exe), `core_patch` (scripts/UI/config), `characters_*`, `maps_*`,
  `audio_video`. A code change only needs `core_patch` (~5 MB), not the 1.34 GB monolith.
- **`core_patch` is already a binary patch** (`strategy: godot_export_patch` → Godot `--export-patch`).
- **Integrity is enforced.** Every package is SHA-256 + byte-size verified before mount
  (`hot_update_manifest.gd`, `hot_update_downloader.gd`); bad bytes fall back to the mirror.
- **Manifest-level compatibility check exists.** `hot_update_manifest.compatibility_errors()`
  rejects a manifest whose `min_app_version` is newer than the client or whose `protocol_version`
  differs from the client.
- **Release process is documented** (publish order, retention, rollback, cache rules, TX/AL mirror).
- **Server pack export is hardened** (`tools/export_public_server_pack.ps1` strips server-only
  autoloads/extensions, smoke-tests, prints SHA-256).

## Critical gaps (fix)

### G1 — No client↔server version handshake at multiplayer join (caused the live crash)
The protocol check only runs against the **static hot-update manifest**. When a client connects to
a **game server peer** (TX/AL room), `network.gd` exchanges **no** version/protocol/build info before
gameplay RPCs flow. A client and a room-server on different builds connect happily and then crash on
the first contract-divergent RPC (observed: `_rpc_spawn_unity_decorations_batch` — `Cannot convert
Array to Dictionary`, because a stale server PCK sent a different payload shape). The docs claim
"protocol mismatch blocks room entry"; that is currently **aspirational**, not enforced peer-to-peer.

### G2 — Server PCK carries no build identity
`maomao_server.pck` has no embedded version/commit stamp. You cannot tell which build TX/AL is
running, the client cannot verify it at join, and a stale server PCK goes unnoticed (root cause of
the divergence above).

### G3 — Big asset families are full packs, not deltas
Only `core_patch` ships as a binary patch. `characters_*` / `maps_*` / `audio_video` use full
`godot_export_pack`, so a one-asset change forces a full-family re-download (e.g. `maps_warehouse`
≈ 357 MB). The `--patches` plumbing already exists in `build_release_packages.py` but is unused for
these families.

### G4 — Build identity is manual and not tied to a commit
`content_version` is hand-typed (`2026.06.28.1`). Nothing derives it from git or forces the client
hot-update packages and the server PCK to be built **from the same frozen commit**. Today both the
hot-update system and gameplay changes are uncommitted, so client and server trivially diverge.

### G5 — No "what is live where" visibility
No origin-side `version.json` / deploy log records which `build_id` is live on TX, AL, and the
server PCK. Drift is invisible until a crash.

## Target design — three pillars

### Pillar A — One build identity + a join handshake (stops drift crashes)
1. **`build_id`** = `<git-short-sha>[+dirty]-<UTC-timestamp>`, generated at build time and written to a
   shipped resource (e.g. `res://build_info.tres` or `user://`-independent `build_info.json` baked
   into the pack). Surfaced at runtime via a tiny `BuildInfo` singleton: `build_id`,
   `content_version`, `protocol_version`, `role` (client/server).
2. **`NETWORK_PROTOCOL_VERSION`** constant in code, bumped on **any** RPC/room-contract change
   (the decoration batch change should have bumped it). This is the single gate that must match.
3. **Join handshake**: right after a peer connects and before gameplay RPCs, exchange
   `{protocol_version, build_id, content_version}`. The server validates the client (and vice-versa);
   on `protocol_version` mismatch the join is **refused with a clear "update required" message**
   instead of crashing later. Optionally warn (not block) on `build_id`/`content_version` mismatch.
   - This is the highest-value, self-contained, headlessly-testable fix. It converts the silent
     crash into an actionable block and makes a stale server PCK fail safe.

### Pillar B — Minimize bytes for every change (kills the "1.4 GB each time" loop)
- **Default the test-team loop to hot-update, never the full exe.** The 1.34 GB build is the
  `bootstrap` exe and changes rarely; ship it once, then iterate via packages.
- **Code/gameplay change → `core_patch` binary patch** (already ~MB).
- **Asset change → that family as a `--export-patch` delta vs the last published version**, so only
  changed bytes ship. Add `previous_pack` tracking per family to the release tool and pass it through
  the existing `--patches` path; flip `characters_*`/`maps_*`/`audio_video` from full-pack to
  delta-patch once a baseline version exists.
- Net: the test team downloads the manifest + only the changed package(s); the exe is rarely touched.

### Pillar C — One release command, same commit for client + server (prevents divergence)
- **`tools/release/build_release.py`** (or extend `build_release_packages.py`) that, in one run:
  1. Refuses to build from a dirty tree unless `--allow-dirty` (frozen-commit gate).
  2. Computes `build_id` from git; chooses `content_version` automatically (date + counter or SHA).
  3. Builds client hot-update packages **and** the server PCK from the **same commit**, stamping both
     with the same `build_id` / `content_version` / `protocol_version`.
  4. Runs the validation gates (pack load test, clean-client install, mirror fallback, protocol
     agreement) before emitting an upload bundle.
- **Deploy together**: for a given `build_id`, publish server PCK + client packages + manifest as one
  unit. Write a `version.json` to each origin (TX/AL) and beside the server PCK recording the live
  `build_id`/`content_version`/`protocol_version` so "what is live where" is queryable.
- Pillar A enforces all of this at runtime.

## Prioritized plan

| Phase | Deliverable | Fixes | Effort | Verifiable headlessly |
| --- | --- | --- | --- | --- |
| 1 | `BuildInfo` singleton + `NETWORK_PROTOCOL_VERSION` + join handshake (refuse on protocol mismatch) | G1, G2 (runtime side) | M | Yes (loopback peer test) |
| 2 | Release tool stamps `build_id`/protocol into client packs **and** server PCK from the same commit; dirty-tree gate | G2, G4 | M | Partly (build + parse stamp) |
| 3 | Delta (`--export-patch`) for `characters_*`/`maps_*`/`audio_video` vs previous version | G3 | M–L | Yes (pack load + size delta) |
| 4 | `version.json` per origin + deploy log + handshake build-id warning surfaced in UI | G5 | S | Manual |
| 5 | (Future) release-index for sequential `0.4.x` traversal | doc-listed | L | — |

Recommended start: **Phase 1** — it directly fixes the crash class the test team just hit, is fully
testable headlessly, and makes every later phase safe (a wrong/stale deploy now fails closed with a
clear message instead of crashing players).

## Phase 1 — implemented (2026-06-28)

- `scripts/build_info.gd` (`BuildInfo`): `NETWORK_PROTOCOL_VERSION` code constant (authoritative gate),
  optional `res://build_info.json` for `build_id`/`content_version`, `is_compatible()`,
  `handshake_payload()`.
- `scripts/network.gd` join handshake, both directions:
  - Client sends `{protocol_version, build_id, content_version}` to the server on connect
    (`_handshake_registration_info()` in `_register_player.rpc_id(1, …)`).
  - **Server gates the client** in `_register_player`: `not BuildInfo.is_compatible(client_protocol)`
    → `_rpc_reject_protocol` + `disconnect_peer`, before the player is added or any gameplay runs.
  - **Server advertises its identity** in the first full sync (`_broadcast_full_sync(..., server_info)`).
  - **Client gates the server** on its first full sync; a stale server that sends no `server_info`
    reads as protocol `-1` and is refused via `_leave_after_version_mismatch()`. A new
    `version_mismatch` signal + `last_error` let the UI show "update required".
- Test: `tests/network_version_handshake_test.gd` (gate logic + producer/consumer key contract).
  Regressions pass: `lobby_flow`, `world_object_sync`, `player_spawn_gate`, `character_skin_runtime`,
  `map_catalog_integrity`.

**Immediate effect on the current stale TX/AL server:** a new client connecting to the still-old
server now **blocks with a clear version-mismatch message instead of crashing** on the decoration RPC.
Once the server PCK is rebuilt from the same commit (Pillar C), both sides carry the handshake and
validate each other normally.

**Protocol-bump discipline:** `NETWORK_PROTOCOL_VERSION` is `1` (this first handshake-aware baseline).
Bump it to `2` on the next breaking networked-contract change after this baseline ships. The decoration
batch payload change is folded into this baseline; future contract edits must bump the number.

## Process note (do this regardless of code)
The hot-update system and current gameplay changes are **uncommitted**. Commit them first, then always
build client packages and the server PCK from that same commit (Pillar C). Most drift incidents are a
deploy/process problem, not a code bug.
