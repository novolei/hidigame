# Performance Architecture Audit

Date: 2026-06-26

Scope: multiplayer performance, skill execution ownership, server/client CPU and GPU balance, public lobby deployment, export hygiene, and the path to a smooth 24-player target. This document preserves current character skills and focuses on reducing duplicated work and network/server pressure.

## Current Evidence

- VPS bandwidth was not saturated during the 4-player playtest. Public outbound traffic was roughly in the low Mbps range, while server CPU was the visible pressure point.
- The public lobby process was spawning room Godot processes and the VPS showed many defunct child processes from previous rooms. Restarting the service clears them, but room process supervision needs a cleaner long-term design.
- The dedicated server log showed the headless room server running `OverlayAtlasManager` and GPU texture painter setup. That is client visual work and should not run on a dedicated server.
- Stalker shadow visibility was being computed on every Stalker copy, including server and remote client copies. That duplicates recursive scene scans and raycasts across all machines.
- Export currently uses `all_resources`, which packages tests, editor addons, and unused resources into a 1.3GB+ server pack. This increases deploy time and exported runtime noise.
- Runtime autoloads still reference editor/MCP helpers. The server starts, but it logs missing Fennara runtime files because the addon is excluded from export.

## Changes Applied In This Pass

- Chameleon GPU painter runtime is now owner/client-only and disabled in headless dedicated server mode.
- Stalker shadow visibility is now owner-computed. The owner publishes compact visibility state, the server forwards it, and remote clients render from the synced state.
- Remote Stalker visual refresh uses synced visibility instead of re-running local shadow checks.
- Hunter auto turret and HUD visibility reads now go through the effective Stalker visibility getter, so they work with synced remote state.
- Local scene tests that simulate a remote owner without a connected peer still compute visibility, preserving offline/test behavior.
- Public room create/join now uses a guarded loading state, longer room-start readiness window, and client-side join timeout recovery back to the public lobby instead of leaving the UI stuck in "joining".
- Public-room clients can leave an active match through the ESC panel and return to the public server lobby without exiting the app.
- Public room redirects now keep the "joining room" state until the room server sends authoritative full sync. Late disconnect events from the previous public lobby connection no longer cancel the new room connection.
- Player replication now syncs position at a capped 20Hz budget, keeps nickname as spawn-only state, and infers remote animation/facing locally from movement instead of synchronizing cosmetic animation and model rotation every network frame.
- Chameleon sculpt remains lazy-initialized: non-Chameleon players cannot create it, and Chameleon players create/apply it only on the first valid sculpt batch.
- Hunter flashlight pose updates now run on a budgeted roughly 8Hz path with movement/angle thresholds and a forced refresh window instead of pushing active pose state every frame-like tick.
- Hunter auto turret target scans are budgeted and restricted to server/owner/offline test contexts. Remote client copies render from synced events instead of scanning every player and decoy every frame.
- Dedicated public room servers now skip local-only player audio creation and skip local rendering of weapon tracers, green blood impact VFX, turret model/audio, turret muzzle/projectile VFX, and flashlight light nodes.
- Hunter prop sense and Party Monster bounty feedback now reuse existing local feedback nodes, update transforms on a small local budget, and skip dedicated public server visual/audio feedback work without clearing authoritative gameplay state.
- Runtime debug logs in `player.gd`, `weapon_system.gd`, `network.gd`, `level.gd`, `inventory_ui.gd`, `ammo_pickup.gd`, `paint_system.gd`, `shape_shift_system.gd`, and `chameleon_sculpt_system.gd` are now gated by `MAOMAO_DEBUG_LOG`; exported/headless public servers default this off so combat, weapon, room, role, phase, pickup, paint, shape, and inventory paths do not write verbose stdout during normal multiplayer sessions.
- `SteamBridge` now self-disables when launched as a public lobby or room server, so headless VPS builds do not try to initialize Steam.
- `tools/export_public_server_pack.ps1` exports server packs through a temporary sanitized `project.godot`: local development keeps Fennara/Godot AI/editor autoloads, while the exported public-server pack strips editor/visual autoloads and disables editor plugin startup hooks before packaging.

## High-Priority Architecture Issues

1. `scripts/player.gd` is too large and mixes player movement, roles, skills, rendering, networking, UI feedback, inventory, death/spectator state, and visual effects. This makes authority boundaries easy to break.
2. Skill systems do not yet share a uniform execution policy. Every skill should explicitly declare where it runs: owner client, authoritative server, all clients render-only, or dedicated server disabled.
3. Public rooms are child processes of the public lobby Godot process. Godot has no robust child-process reaping API, so Linux deployment should move room lifecycle into systemd or a small external supervisor.
4. Runtime logging is now gated across the main hot paths, but remaining ordinary logs outside `scripts/` and any future gameplay feature logs should follow the same debug flag or sampling treatment.
5. Export presets need separation:
   - Client preset: only runtime gameplay resources and required client GDExtensions.
   - Dedicated server preset: no videos, intro art, editor addons, tests, client-only shaders, or client-only UI media unless required by headless loading.
6. Public server startup now avoids Steam and MCP/editor-adjacent autoloads when using `tools/export_public_server_pack.ps1`. This still needs to become a true dedicated server export preset instead of a temporary project-settings sanitization step.
7. Network sync lacks measured budgets. RPC frequency, payload size, and replicated property update rates need per-system limits before targeting 24 players.
8. The current public lobby uses JSON status files for room discovery. This is acceptable short term, but should become a managed room registry with process status, heartbeats, and cleanup guarantees.

## Skill Runtime Policy Target

| System | Owner client | Server | Remote clients |
| --- | --- | --- | --- |
| Movement input | Simulate and send | Validate/relay authoritative state | Interpolate/render |
| Chameleon paint visuals | Compute GPU visuals | Never run GPU painter | Render received state only |
| Chameleon disguise gameplay | Request/apply intent | Validate and broadcast compact state | Render state |
| Stalker shadow visibility | Compute local visibility | Receive/forward compact visibility, use for authoritative checks | Render synced visibility |
| Player movement visuals | Compute local animation/facing | Relay compact position state | Infer animation/facing from replicated movement |
| Hunter flashlight | Publish owner pose on thresholded budget | No visual light on dedicated public server | Render synced light pose |
| Hunter turret | Owner/server-authoritative targeting policy with budgeted target scans | Validate damage and target legality, no local VFX/audio on dedicated public server | Render muzzle, recoil, hit feedback |
| Weapon damage | Owner aim intent | Validate damage/death, no local tracer/impact VFX on dedicated public server | Render feedback |
| Hunter/Party Monster feedback | Local feedback nodes with budgeted transforms | Keep state only, no feedback nodes/audio on dedicated public server | Render local feedback from replicated state |
| HUD/UI | Local only | Never | Local only |

## 24-Player Roadmap

1. Add a dedicated performance telemetry layer:
   - server tick time
   - room process CPU and memory
   - RPC count and bytes by system
   - per-client actor count and FPS samples
   - skill activation rates
2. Build a headless 8/16/24-player bot smoke harness that can join a public room, move, use skills, and collect metrics for 5-10 minutes.
3. Split `player.gd` into owned components:
   - `PlayerMovementController`
   - `PlayerSkillRouter`
   - `PlayerVisualController`
   - `PlayerNetworkState`
   - `PlayerCombatState`
4. Create a small authority helper API, for example:
   - `runs_on_owner()`
   - `runs_on_dedicated_server()`
   - `runs_on_remote_renderer()`
   - `can_send_to_server(peer_id)`
5. Add interest management:
   - distance-based visual update throttling
   - no high-frequency cosmetic sync for distant players
   - event batching for paint/skill feedback
6. Create separate export presets and reduce the server pack size.
7. Replace public room child-process spawning with systemd-run, a supervisor service, or a small daemon that owns room process lifecycle.
8. Gate logs and remove editor/test resources from runtime exports.

## Validation From This Pass

- `scripts/hunter_flashlight_system.gd`, `scripts/hunter_auto_turret_system.gd`, `scripts/weapon_system.gd`, and `tests/lobby_flow_test.gd`: Fennara diagnostics reported 0 errors.
- `scripts/player.gd` and `scripts/network.gd`: Fennara diagnostics reported 0 errors with existing non-blocking warnings.
- `scripts/game_settings.gd`, `scripts/player.gd`, `scripts/weapon_system.gd`, `scripts/network.gd`, `scripts/level.gd`, `scripts/inventory_ui.gd`, `scripts/ammo_pickup.gd`, `scripts/paint_system.gd`, `scripts/shape_shift_system.gd`, and `scripts/chameleon_sculpt_system.gd`: Fennara diagnostics reported 0 errors after adding `MAOMAO_DEBUG_LOG` runtime log gating.
- `res://tests/stalker_shadow_visibility_test.tscn`: CLI PASS.
- `res://tests/hunter_auto_turret_test.tscn`: CLI PASS.
- `res://tests/lobby_flow_test.tscn`: CLI PASS, including public room redirect state regression coverage.
- `res://tests/escape_quit_confirm_test.gd`: CLI PASS.
- `res://tests/lobby_flow_test.tscn`, `res://tests/escape_quit_confirm_test.gd`, `res://tests/party_monster_accessory_system_test.tscn`, `res://tests/hunter_prop_sense_test.tscn`, and `res://tests/hunter_auto_turret_test.tscn`: CLI PASS after broad runtime log gating.
- `res://tests/character_skin_runtime_test.tscn`: CLI PASS.
- `res://tests/player_spawn_gate_test.tscn`: CLI PASS.
- `res://tests/world_object_sync_test.tscn`: CLI PASS.
- `res://tests/chameleon_sculpt_network_test.tscn`: CLI PASS after aligning the test with lazy sculpt initialization.
- `res://tests/party_monster_accessory_system_test.tscn`: CLI PASS and Fennara validate_scene PASS after adding local feedback budget coverage.
- `res://tests/hunter_prop_sense_test.tscn`: CLI PASS and Fennara validate_scene PASS after adding local feedback budget coverage.
- `tools/export_public_server_pack.ps1 -SmokeOnly`: PASS against `newrelease/maomao_server.pck`; public lobby perf telemetry appears and startup logs no longer include Fennara, Godot AI, AmbientCG, or Steam initialization noise.
- VPS public lobby service restarted successfully and is listening on UDP 8080.

## Known Remaining Cleanup

- Fix or exclude malformed `res://scenes/food_scene*.tscn` files from export.
- Promote the temporary sanitized server export flow into a dedicated server export preset.
- Create server-only export settings to stop packaging tests/editor addons/client intro media into `maomao_server.pck`.
- Add process supervision for public room servers to prevent zombie child processes after repeated create/quit cycles.
- Keep `MAOMAO_PERF_LOG` enabled on staging/public-room smoke tests so performance telemetry remains visible while ordinary debug logs stay quiet.
- Godot headless validation still emits a `doc_tools.cpp` corrupt doc-cache error before tests run. It does not fail the gameplay tests, but it should be cleaned up so runtime logs stay signal-heavy.
