# NetFox and Noray Migration / Diagnostic Roadmap

Updated: 2026-06-27

This document is the working contract for improving Monster & Hunter multiplayer. It combines the current public VPS room model, the private player-hosted model, the newly enabled NetFox stack, and direct Noray integration.

## Goals

- Keep two supported multiplayer modes:
  - Public server mode: players enter a VPS lobby, create or join public rooms, and the room server remains authoritative for room membership and match flow.
  - Private server mode: one player's client hosts the match, friends join directly, and Noray is used for NAT punchthrough / relay instead of requiring manual port forwarding or Tailscale.
- Move high-frequency gameplay sync toward "owner computes, server forwards, remotes render".
- Reduce visible stutter for remote players by replacing raw `MultiplayerSynchronizer`-style transform replication with NetFox-tick-based snapshot interpolation first, then RollbackSynchronizer / predictive input in later phases.
- Add practical diagnostics so multiplayer problems produce actionable logs: connection mode, server code, Noray phase, RTT / packet budget, sync queue health, and room lifecycle.
- Keep public VPS and private P2P code paths separable so one failing mode does not regress the other.

## References

- NetFox official Noray guide: `https://foxssake.github.io/netfox/latest/netfox.noray/guides/noray/`
- NetFox official PacketHandshake guide: `https://foxssake.github.io/netfox/latest/netfox.noray/guides/packet-handshake/`
- Local addon API verified from:
  - `res://addons/netfox.noray/noray.gd`
  - `res://addons/netfox.noray/packet-handshake.gd`
  - `res://addons/netfox.noray/netfox-noray.gd`
- Noray upstream server reference: `https://github.com/foxssake/noray`

## Current State

- `project.godot` has NetFox autoloads enabled: `NetworkTime`, `NetworkTimeSynchronizer`, `NetworkRollback`, `NetworkEvents`, `NetworkPerformance`, `NetworkSimulator`, plus Noray's `Noray` and `PacketHandshake`.
- `res://scenes/level/player.tscn` uses `NetfoxTransformSync` instead of the old `MultiplayerSynchronizer` node for player transform sync.
- `res://scripts/network/netfox_player_transform_sync.gd` sends owner transform snapshots on NetFox ticks. The server validates and forwards them, while remote clients interpolate and briefly extrapolate.
- NetFox transform sync has an idle-send budget and a forced-refresh window, so unchanged owner snapshots no longer consume a full 30Hz path while moving players can still submit every NetFox tick.
- `MAOMAO_PERF_LOG` now includes transform sync diagnostics for owner idle skips, stale/rejected snapshots, queue overflow, and remote interpolation / extrapolation / clamped extrapolation samples.
- Public server room flow is still based on VPS-hosted ENet rooms and must remain direct IP based.
- Private server flow now routes the main "Create Private Server" and `noray:<OpenID>` join path through Noray. Direct IP remains available for LAN / forwarded-port / Tailscale fallback.

## AL Noray Server

Primary private Noray relay target:

- Code name: `AL`
- Address: `8.153.148.157`
- Noray TCP control port: `8890`
- Noray metrics port: `8891`
- UDP remote registrar: `8809`
- UDP relay range: `49152-51200`

Deployed service:

- Runtime: Docker, `ghcr.io/foxssake/noray:main`
- Systemd unit: `/etc/systemd/system/noray.service`
- Environment file: `/opt/noray/.env`
- Firewall bootstrap: `/usr/local/sbin/noray-firewall.sh`, called by `noray.service` before the container starts.
- Docker mode: `--network host`

Server-local verification on 2026-06-27:

- `systemctl status noray.service`: active/running.
- Container `noray-server`: up.
- `curl http://127.0.0.1:8891/metrics`: OK.
- Listening sockets include TCP `0.0.0.0:8890`, TCP `0.0.0.0:8891`, UDP `0.0.0.0:8809`, and UDP relay ports `49152-51200`.
- Host firewall allows TCP `8890`, TCP `8891`, UDP `8809`, and UDP `49152-51200`.
- Systemd owns the service via `noray.service`, and the Docker container runs with host networking.
- Root disk was cleaned from roughly 93% used to roughly 19% used by removing stale `maomao_server.pck.bak-*`, previous PCK, and upload/release ZIP artifacts while keeping the active PCK plus the latest backup.

External verification on 2026-06-27:

- Windows-side `curl http://8.153.148.157:8891/metrics`: OK.
- Windows-side TCP connect probe to `8.153.148.157:8890`: connection established.
- Keep these inbound security-group rules open:
  - TCP `8890` from `0.0.0.0/0`.
  - UDP `8809` from `0.0.0.0/0`.
  - UDP `49152-51200` from `0.0.0.0/0`.
  - TCP `8891` is optional for metrics; if enabled, restrict to the developer IP if possible.

## Runtime Authority Contract

| System | Owner client | Server | Remote clients | Headless server |
| --- | --- | --- | --- | --- |
| Player movement input | Samples input and predicts local motion | Validates / forwards state | Interpolates remote state | No camera, no local-only visuals |
| Player transform snapshots | Sends bounded snapshots | Rejects invalid sender / outlier position / forwards | Render-only interpolation | Forward-only in public room server |
| Weapon fire | Sends intent and aim sample | Authoritative hit validation, later lag compensation | Plays tracers / impact feedback | Validate only, no particles |
| Flashlight pose | Owner computes pose | Forwards compressed pose | Render-only pose update | Disabled except replication metadata |
| Turret events | Owner/host requests deploy | Server validates range, enabled flag, fire events | Render-only turret motion / shots | Authoritative turret target decisions |
| Map props | Server owns durable prop state | Sends dirty snapshots at bounded rate | Render-only interpolation | Authoritative physics / lifecycle |
| Chameleon paint | Owner batches local stroke intent | Validates duration/rate and forwards compact batches | Applies visual batches only | No GPU paint workloads |
| UI / HUD / audio | Local only | No gameplay authority | Local only | Disabled |

## Noray Private Server Contract

Noray is used only for private player-hosted rooms.

Host flow:

1. Connect to a Noray orchestration server.
2. Call `Noray.register_host()`.
3. Wait for OpenID / PrivateID.
4. Call `Noray.register_remote()` so Noray learns the host's external address and sets `Noray.local_port`.
5. Create the ENet server on `Noray.local_port`.
6. Show the room's shareable connection code as `noray:<OpenID>`.

Client flow:

1. If the join target starts with `noray:` or `noray://`, connect to Noray instead of direct IP.
2. Register remote address and bind client ENet to `Noray.local_port`.
3. Request `Noray.connect_nat(host_oid)`.
4. When `Noray.on_connect_nat(address, port)` arrives, run `PacketHandshake.over_packet_peer(...)`.
5. Create the ENet client with explicit local port `Noray.local_port`.
6. If NAT fails, request `Noray.connect_relay(host_oid)` and repeat the handshake over the relay target.

Notes:

- The OpenID is public and can be shared. The PrivateID must never be displayed or sent through chat/logs.
- Direct IP joining remains supported for LAN, port-forwarded, or Tailscale scenarios.
- For shipping, we should run our own Noray service instead of depending on a public demo server.

## Migration Phases

### Phase 0: Baseline and Safety Rails

- Keep public VPS rooms working.
- Add NetFox tick settings and transform snapshot tests.
- Remove player `MultiplayerSynchronizer` dependency from `player.tscn`.
- Add diagnostic assertions in tests so regressions are caught.

Status: Implemented for player scene safety rails. The old player `MultiplayerSynchronizer` has been removed, `NetfoxTransformSync` is covered by scene tests, and transform snapshot bounds / telemetry byte estimates are asserted.
The safety rail now also asserts idle transform throttling and remote sample telemetry, which keeps the current owner-submit / server-forward / remote-render bridge observable while Phase 2 prediction work is staged.

### Phase 1: Direct Noray Private Server

- Add `Network` private-host Noray bootstrap.
- Add `Network` private-client NAT / relay bootstrap.
- Show server code in lobby config as `noray:<oid>`.
- Preserve direct IP fallback.
- Add join status messages for Noray phases and failures.

Status: Implemented for first end-to-end game client path. AL Noray server is deployed and externally reachable for metrics and TCP control. A two-client private-host smoke test is still required to prove NAT / relay behavior through the game client.

### Phase 2: NetFox Gameplay Sync Stabilization

- Convert player movement to a true NetFox input/prediction path.
- Keep the current owner-submit / server-forward / remote-render snapshot path observable through `MAOMAO_PERF_LOG` while the predictive path is designed.
- Introduce rollback/predictive synchronizers only after the ownership contract is explicit.
- Keep visual-only systems off headless server paths.
- Add 2 / 4 / 8 / 16 bot smoke scripts for remote motion smoothness and CPU/network budget.

### Phase 3: High-Impact Gameplay RPC Cleanup

Focus areas:

- Weapon RPC: move from visual RPC spam to intent + server validation + compact replicated result.
- Flashlight pose: quantized pose snapshots, lower frequency than player movement.
- Auto turret events: server-owned target selection, lobby-configurable range/enabled state.
- Map prop sync: dirty batching, relevance limits, sleep-state suppression.
- Chameleon paint: max 45-second active paint session, stroke batching, remote render-only application, no GPU paint work on headless.

### Phase 4: Diagnostics, Console, and Runtime Ops

- Add a runtime console similar to FPS debug consoles.
- Commands:
  - `net.mode`
  - `net.peers`
  - `net.rtt`
  - `net.noray`
  - `net.room`
  - `net.sync_budget`
  - `net.simulator on/off`
- Surface NetFox logger levels and NetworkPerformance counters.
- Add a diagnostic overlay for test builds only.
- Persist server-side room lifecycle logs for VPS diagnosis.

Status: Runtime console foundation is implemented. Press the backquote / tilde key in the level to open a lightweight network console and run `net.mode`, `net.peers`, `net.rtt`, `net.noray`, `net.room`, `net.sync_budget`, or `net.simulator`. `Network.get_diagnostic_snapshot()` is the shared source for console output and automated tests, exposing ENet RTT / packet loss, Noray route state, NetFox tick and `NetworkPerformance` counters, sync-budget telemetry, room metadata, and simulator settings. Server-side lifecycle log persistence remains a separate production-ops task.

## Validation Checklist

Before each packaged build:

- Fennara `script_diagnostics` on modified scripts.
- Fennara `validate_scene` for `res://scenes/level/player.tscn` and `res://scenes/level/level.tscn` where feasible.
- Headless tests:
  - `res://tests/lobby_flow_test.tscn`
  - `res://tests/character_skin_runtime_test.tscn`
  - `res://tests/hunter_auto_turret_test.tscn`
  - `res://tests/world_object_sync_test.tscn`
- Manual multiplayer smoke:
  - Public VPS lobby create -> join -> start -> return to lobby.
  - Private Noray host -> second client joins by `noray:<oid>`.
  - Private direct IP still works on localhost / LAN.

## Failure Modes To Log

- Noray server unreachable.
- Host registration timed out.
- Remote registration timed out.
- NAT handshake timed out.
- Relay fallback started.
- Relay connection failed.
- ENet client created without binding to `Noray.local_port`.
- Public room process created but readiness file not written before timeout.
- Peer connected but full sync did not arrive within lobby timeout.

## Implementation Rule

Do not migrate every replicated system at once. Make one authority boundary explicit, add a diagnostic signal/test for it, then move to the next system. Multiplayer stability comes from boring, inspectable contracts.
