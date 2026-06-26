# Performance Architecture Audit

Date: 2026-06-26

Scope: multiplayer performance, skill execution ownership, server/client CPU and GPU balance, public lobby deployment, export hygiene, and the path to a smooth 24-player target. This document preserves current character skills and focuses on reducing duplicated work and network/server pressure.

## Current Evidence

- VPS bandwidth was not saturated during the 4-player playtest. Public outbound traffic was roughly in the low Mbps range, while server CPU was the visible pressure point.
- The public lobby process was spawning room Godot processes and the VPS showed many defunct child processes from previous rooms. Restarting the service clears them, but room process supervision needs a cleaner long-term design.
- The dedicated server log showed the headless room server running `OverlayAtlasManager` and GPU texture painter setup. That is client visual work and should not run on a dedicated server.
- Stalker shadow visibility was being computed on every Stalker copy, including server and remote client copies. That duplicates recursive scene scans and raycasts across all machines.
- Export currently uses `all_resources`, which packages tests, editor addons, and unused resources into a 1.3GB+ server pack. This increases deploy time and exported runtime noise.
- Runtime autoloads previously referenced editor/MCP helpers. The sanitized public-server export flow now removes those exported autoload references, including the Fennara capture helper.
- Public room launches now support a Unix detached launcher controlled by `MAOMAO_ROOM_LAUNCH_MODE`. On Linux/BSD/macOS with `/bin/sh`, the public lobby starts rooms through a short-lived `nohup` shell wrapper, waits for that wrapper to return, and lets the OS own the room process instead of leaving it as a long-lived child of the lobby.
- TX public-room create failures on 2026-06-26 were caused by room child processes being launched without the exported server PCK. The public lobby had `--main-pack /opt/maomao/maomao_server.pck`, but spawned room processes only received `--maomao-room-server`, so they never ran game code or wrote `ready=true` status files.

## Changes Applied In This Pass

- Chameleon GPU painter runtime is now owner/client-only and disabled in headless dedicated server mode.
- Chameleon self-paint no longer eagerly creates the GPU painter when the brush opens; the optional GPU overlay now initializes only when an actual paint stroke is queued.
- `OverlayAtlasManager` now releases the previous RenderingDevice texture RID before replacing the overlay atlas texture, preventing repeated Chameleon self-paint sessions from leaking GPU textures.
- Chameleon paint sessions are capped at 45 seconds. Ordinary self-paint auto-stops on expiry, while prop white-model paint expiry routes through the environment blend system so the prop can commit/clean up instead of leaving the player locked.
- Dedicated public room servers now skip local Chameleon paint rendering entirely. They still validate/forward compact paint batches, but no longer create local paint canvases, paint textures, shader materials, or GPU paint queues for visual-only self/prop paint.
- Stalker shadow visibility is now owner-computed. The owner publishes compact visibility state, the server forwards it, and remote clients render from the synced state.
- Remote Stalker visual refresh uses synced visibility instead of re-running local shadow checks.
- Hunter auto turret and HUD visibility reads now go through the effective Stalker visibility getter, so they work with synced remote state.
- Local scene tests that simulate a remote owner without a connected peer still compute visibility, preserving offline/test behavior.
- Public room create/join now uses a guarded loading state, longer room-start readiness window, and client-side join timeout recovery back to the public lobby instead of leaving the UI stuck in "joining".
- Public-room clients can leave an active match through the ESC panel and return to the public server lobby without exiting the app.
- Public room redirects now keep the "joining room" state until the room server sends authoritative full sync. Late disconnect events from the previous public lobby connection no longer cancel the new room connection.
- Player replication now uses NetFox tick snapshots with a public-internet interpolation buffer, bounded extrapolation, and render smoothing. Nickname remains spawn-only state, and remote animation/facing is still inferred locally from motion instead of synchronizing cosmetic animation and model rotation every network frame.
- NetFox player transform sync now suppresses unchanged idle owner snapshots, keeps a bounded forced refresh, and records remote interpolation/extrapolation sample modes so `MAOMAO_PERF_LOG` can reveal whether visible stutter comes from stale snapshots, queue overflow, or clamped extrapolation.
- A runtime network console now exposes `net.mode`, `net.peers`, `net.rtt`, `net.noray`, `net.room`, `net.sync_budget`, and `net.simulator` from a shared diagnostic snapshot so field tests can capture ENet RTT / packet loss, Noray phase, NetFox counters, and sync-budget telemetry without adding ad hoc logs.
- Chameleon sculpt remains lazy-initialized: non-Chameleon players cannot create it, and Chameleon players create/apply it only on the first valid sculpt batch.
- Hunter flashlight pose updates now run on a budgeted roughly 8Hz path with movement/angle thresholds and a forced refresh window instead of pushing active pose state every frame-like tick.
- Hunter flashlight pose updates now use `NetworkInterest` segment relevance for targeted fan-out. Toggle/cooldown state remains reliable room-wide sync, while continuous pose updates record actual recipients and skip peers far from the flashlight beam.
- Hunter auto turret target scans are budgeted and restricted to server/owner/offline test contexts. Remote client copies render from synced events instead of scanning every player and decoy every frame.
- Dedicated public room servers now skip local-only player audio creation and skip local rendering of weapon tracers, green blood impact VFX, turret model/audio, turret muzzle/projectile VFX, and flashlight light nodes.
- Hunter prop sense and Party Monster bounty feedback now reuse existing local feedback nodes, update transforms on a small local budget, and skip dedicated public server visual/audio feedback work without clearing authoritative gameplay state.
- Weapon tracer and green-blood impact broadcasts are now unreliable ordered visual RPCs. Fire requests, ammo state, reload state, health, death, and owner combat feedback remain reliable so visual bursts cannot block critical gameplay state under sustained Hunter fire.
- Weapon tracer and green-blood impact visual RPCs now use server-side targeted fan-out. The shooter and observers near the shot segment receive the cosmetic event, while distant peers are skipped conservatively only when their player node can be resolved.
- Weapon and auto-turret shot visuals now share `NetworkInterest` segment relevance helpers. Auto-turret shot VFX/audio fan-out records actual recipient counts and no longer broadcasts every sustained turret shot to every connected peer.
- Runtime debug logs in `player.gd`, `weapon_system.gd`, `network.gd`, `level.gd`, `inventory_ui.gd`, `ammo_pickup.gd`, `paint_system.gd`, `shape_shift_system.gd`, and `chameleon_sculpt_system.gd` are now gated by `MAOMAO_DEBUG_LOG`; exported/headless public servers default this off so combat, weapon, room, role, phase, pickup, paint, shape, and inventory paths do not write verbose stdout during normal multiplayer sessions.
- `SteamBridge` now self-disables when launched as a public lobby or room server, so headless VPS builds do not try to initialize Steam.
- `tools/export_public_server_pack.ps1` exports server packs through temporary sanitized project settings: local development keeps Fennara/Godot AI/editor autoloads, while the exported public-server pack strips editor/visual autoloads, filters client/editor GDExtensions, excludes Terrain3D from the server package, and uses Godot recovery mode before packaging.
- Public room creation now requires an explicit room name on both the client UI and public-lobby RPC boundary. Empty names no longer fall back to a generated nickname room, which makes room creation state and duplicate checks easier to reason about.
- Public room subprocess args now pass `--main-pack` from `MAOMAO_PCK`, from a command-line pack hint, or from the Linux production fallback `/opt/maomao/maomao_server.pck`; the export smoke test also sets `MAOMAO_PCK`.
- Public-room lobby UI now shows the connected public server identity after room entry. Primary server `1.13.175.170` is labeled `TX`; backup server `8.153.148.157` is labeled `AL`.
- Public room process startup is now split into argument construction, launch-mode selection, shell quoting, detached PID parsing, and direct child fallback. This makes the room lifecycle path testable and reduces the risk of zombie room children after repeated create/quit cycles.
- Public lobby and room servers now persist room lifecycle JSONL under the room status `logs` directory, with create/join failures, process spawn, ready timeout, redirect, status discovery, stale cleanup, room ready, host assignment, peer join/leave, and status deletion events. This gives VPS field tests a concrete evidence trail without exposing room passwords.
- Map prop impact requests now have a server-side per-player/per-prop throttle. Normal client-cooldown impacts still pass, while duplicate bursts are dropped and counted as `map_prop.impact_throttled`.
- `level.gd`, `player.gd`, and `network.gd` now route local peer-id reads and server checks through runtime-peer helpers. Headless/offline tests no longer spam Godot's `No multiplayer peer is assigned` error while preserving real multiplayer server semantics when an ENet peer is present.
- NetFox player transform snapshots now record owner-submit and server-forward counts/approximate bytes through the existing `MAOMAO_PERF_LOG` telemetry window.
- Map prop rest/settle states now use capped reliable batches instead of one reliable RPC per prop. Motion and rest queues clear each other per prop so final settle state wins without double-sending stale motion.

## High-Priority Architecture Issues

1. `scripts/player.gd` is too large and mixes player movement, roles, skills, rendering, networking, UI feedback, inventory, death/spectator state, and visual effects. This makes authority boundaries easy to break.
2. Skill systems do not yet share a uniform execution policy. Every skill should explicitly declare where it runs: owner client, authoritative server, all clients render-only, or dedicated server disabled.
3. Public rooms no longer need to be direct long-lived children of the public lobby on Unix-like deployments, but the detached launcher is still a pragmatic bridge. The longer-term production shape should move room lifecycle into systemd units or a small external supervisor with explicit process status and cleanup.
4. Runtime logging is now gated across the main hot paths, but remaining ordinary logs outside `scripts/` and any future gameplay feature logs should follow the same debug flag or sampling treatment.
5. Export presets need separation:
   - Client preset: only runtime gameplay resources and required client GDExtensions.
   - Dedicated server preset: no videos, intro art, editor addons, tests, client-only shaders, or client-only UI media unless required by headless loading.
6. Public server startup now avoids Steam, Terrain3D, Voxel, and MCP/editor-adjacent autoloads when using `tools/export_public_server_pack.ps1`. This still needs to become a true dedicated server export preset instead of a temporary project-settings sanitization step, because the all-resources pack remains much larger than a dedicated server should be.
7. Network sync lacks measured budgets. RPC frequency, payload size, and replicated property update rates need per-system limits before targeting 24 players.
8. The current public lobby uses JSON status files for room discovery. This is acceptable short term, but should become a managed room registry with process status, heartbeats, and cleanup guarantees.
9. Live TX room telemetry showed `rpc.map_prop.motion` dominating traffic with thousands of per-prop updates per 10-second window even with one peer. Map prop motion now uses capped batch RPCs, keeps overflow states for later flushes, and no longer broadcasts solely because a body is non-sleeping without meaningful transform or velocity deltas.

## Skill Runtime Policy Target

The detailed implementation contract now lives in `docs/RUNTIME_AUTHORITY_CONTRACT.md`. New multiplayer work should treat that file as the source of truth for owner/server/remote/headless execution boundaries, static typing expectations, and memory cleanup rules.

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
- `res://tests/lobby_flow_test.tscn`: CLI PASS after replacing direct `multiplayer.is_server()` checks in `level.gd` and `player.gd`; the previous no-peer error from `player.gd:342` is gone.
- `res://tests/lobby_flow_test.tscn` and `res://tests/character_skin_runtime_test.tscn`: CLI PASS after adding NetFox transform snapshot budget assertions.
- `res://tests/character_skin_runtime_test.tscn`: CLI PASS after adding NetFox idle transform budget and remote sample telemetry coverage.
- `res://tests/lobby_flow_test.tscn`: CLI PASS after adding network diagnostic console command coverage.
- `res://tests/escape_quit_confirm_test.gd`: CLI PASS.
- `res://tests/lobby_flow_test.tscn`, `res://tests/escape_quit_confirm_test.gd`, `res://tests/party_monster_accessory_system_test.tscn`, `res://tests/hunter_prop_sense_test.tscn`, and `res://tests/hunter_auto_turret_test.tscn`: CLI PASS after broad runtime log gating.
- `res://tests/character_skin_runtime_test.tscn`: CLI PASS.
- `res://tests/player_spawn_gate_test.tscn`: CLI PASS.
- `res://tests/world_object_sync_test.tscn`: CLI PASS.
- `res://tests/world_object_sync_test.tscn`: CLI PASS after adding capped map prop motion batching and non-sleeping no-delta suppression coverage.
- `res://tests/world_object_sync_test.tscn`: CLI PASS after adding reliable map prop rest-state batching and overflow coverage.
- `res://tests/chameleon_sculpt_paint_integration_test.tscn`: CLI PASS after adding the 45-second Chameleon paint-session expiry regression and aligning paint RPC chunk expectations to 16/1 stamps.
- `res://tests/chameleon_sculpt_paint_integration_test.tscn`: CLI PASS after adding dedicated public server paint-render skip coverage so headless room servers forward compact batches without allocating local paint render buffers.
- `res://tests/shape_combat_poc_test.tscn`: CLI PASS after making paint-session timing compatible with legacy direct `skill_active` test probes.
- Fennara windowed runtime for `res://tests/shape_combat_poc_test.tscn`: PASS, and the runtime log no longer reports leaked RenderingDevice texture RIDs after repeated `OverlayAtlasManager` texture creation/cleanup.
- `res://tests/chameleon_sculpt_network_test.tscn`: CLI PASS after aligning the test with lazy sculpt initialization.
- `res://tests/party_monster_accessory_system_test.tscn`: CLI PASS and Fennara validate_scene PASS after adding local feedback budget coverage.
- `res://tests/hunter_prop_sense_test.tscn`: CLI PASS and Fennara validate_scene PASS after adding local feedback budget coverage.
- `res://tests/hunter_prop_sense_test.tscn`: CLI PASS after adding Hunter flashlight pose targeted fan-out coverage.
- `res://tests/hunter_auto_turret_test.tscn`: CLI PASS after adding weapon visual RPC budget and relevance regressions that keep tracer/green-blood effects off reliable transport, target cosmetic fan-out by shot proximity, and preserve reliable ammo/reload/feedback sync.
- `res://tests/hunter_auto_turret_test.tscn`: CLI PASS after moving weapon shot relevance math into `NetworkInterest` and adding auto-turret shot visual targeted fan-out coverage.
- `tools/export_public_server_pack.ps1`: PASS against `newrelease/maomao_server.pck` from an isolated temporary working directory; public lobby perf telemetry appears and startup logs no longer include Fennara, Godot AI, AmbientCG, Steam, Terrain3D, or Voxel startup noise.
- VPS public lobby service restarted successfully and is listening on UDP 8080.

## Known Remaining Cleanup

- Fix or exclude malformed `res://scenes/food_scene*.tscn` files from export.
- Promote the temporary sanitized server export flow into a dedicated server export preset.
- Create server-only export settings to stop packaging tests/editor addons/client intro media into `maomao_server.pck`.
- Keep Terrain3D, Steam, Voxel, Fennara, and Godot AI out of server exports. The current sanitized export and smoke check cover this, but a dedicated server export preset should make it explicit instead of relying on temporary file patching.
- Stress-test repeated public room create/join/empty-shutdown cycles on the VPS to verify the detached launcher prevents zombie child processes under real player churn, then decide whether to promote the next step to systemd-run or a dedicated supervisor daemon.
- Keep `MAOMAO_PERF_LOG` enabled on staging/public-room smoke tests so performance telemetry remains visible while ordinary debug logs stay quiet.
- Godot headless validation still emits a `doc_tools.cpp` corrupt doc-cache error before tests run. It does not fail the gameplay tests, but it should be cleaned up so runtime logs stay signal-heavy.
