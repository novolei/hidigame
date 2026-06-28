# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project actually is

Despite the repo name and `README.md`, this is **"Monster & Hunter"** (代号 Phantom Hunt / Prop Hunt) — a 24-player 3D prop-hunt game built **on top of** the `godot-3d-multiplayer-template`. Engine target is **Godot 4.7** (`project.godot` → `config/features=("4.7", "Forward Plus")`), GDScript only (no C#). The original template README describes only the base layer; the real game is the role/skill/card/networking systems under `scripts/`.

Three player roles drive most gameplay code (`Network.Role`): **Chameleon** (藏匿者 — paint/sculpt camouflage), **Stalker** (潜行者 — shadow stealth + grapple), **Hunter** (猎人 — AK47 + detection), plus Spectator. Hunter:Prop ratio is forced 1:3. The authoritative design lives in [docs/PROP_HUNT_GDD.md](docs/PROP_HUNT_GDD.md) (in Chinese).

## Working with Godot files — Fennara MCP

`AGENTS.md` and [.fennara/ai/guidelines.md](.fennara/ai/guidelines.md) mandate the **Fennara MCP** workflow for any Godot-specific work (`.gd`, `.cs`, `.gdshader`, `.tscn`, `.tres`, `.res`, `project.godot`, nodes, scenes, project settings):

- **Never hand-edit `.tscn` / `.tres` / `.res` as text.** They are Godot-serialized; edit via Fennara's `run_scene_edit_script` / `save_custom_resource` / `project_settings`.
- Edit `.gd` / `.gdshader` via `write_or_update_file` (it auto-runs diagnostics), not generic text tools.
- Inspect scenes with `get_scene_tree` / `get_node_properties` before editing; never guess node paths.
- Fennara requires Godot open with this project loaded and the Fennara addon active. If it is unavailable in your session, say so rather than silently falling back to raw `.tscn` text surgery.
- Fennara autoloads/scripts under `addons/fennara/` and `addons/godot_ai/` are infrastructure — do not remove or "clean up."

## Tests

There is **no test framework** (no GUT/GdUnit). Each test is a standalone runnable scene under `tests/` whose script does its work in `_ready()` → `_run()`, calls `get_tree().quit(0)` on pass / `quit(1)` on fail, and prints `[TestName] PASS` or `push_error` lines. Most have a paired `.tscn` (some are bare `.gd`).

Run a single test headlessly from the CLI:

```bash
godot --headless tests/world_object_sync_test.tscn
# or a bare-script test:
godot --headless tests/escape_quit_confirm_test.gd
```

(`PASS` is printed and exit code is 0 on success; failures are `push_error`'d with exit code 1.) When Godot is open with the project, prefer Fennara `validate_scene`. Add a focused test beside each new subsystem; pure helpers (`RefCounted`) should get headless script tests. Test pass/fail history is logged in [docs/PERFORMANCE_ARCHITECTURE_AUDIT.md](docs/PERFORMANCE_ARCHITECTURE_AUDIT.md).

## Running the game

- Main scene is `res://scenes/ui/startup.tscn`. Press F5 in the editor.
- Local multiplayer: `Debug` → `Customize Run Instances` → enable multiple instances.
- Headless dedicated server: `./run_headless_server.sh` (`godot --headless --path .`).
- Windows client build: export via the `Windows Desktop` preset in `export_presets.cfg` (outputs `newrelease/`, embeds PCK).
- Dedicated server pack: `tools/export_public_server_pack.ps1`.
- Hot-update release packaging: `tools/hot_update/build_release_packages.py` + `build_manifest.py`.

## Architecture

### Autoload singletons (`project.godot` → `[autoload]`)
The game is orchestrated through globals. The most important:
- **`Network`** (`scripts/network.gd`, ~2900 lines) — authoritative for lobby state, role assignment (1:3), card draft/consumption, room settings, public-VPS room routing, and Noray private transport. This is the spine of multiplayer.
- **`ItemDatabase`**, **`GameSettings`**, **`I18n`** (localization; comments/UI are bilingual zh/en), **`SteamBridge`** (GodotSteam).
- **netfox** stack: `NetworkTime`, `NetworkRollback`, `NetworkEvents`, `NetworkPerformance`, etc. Tickrate is **60 Hz**, synced to physics (`[netfox]` + `[physics]` sections).
- **`HotUpdate`** (`scripts/hot_update/hot_update_manager.gd`) — incremental PCK update client.

### Rollback netcode (netfox)
Movement/combat use **netfox rollback** (`addons/netfox`). The newer modular netcode lives in `scripts/network/`: `player_input_state.gd`, `player_movement_motor.gd` (predicted movement sim), `player_action_bus.gd` (semantic action events), `network_rewind_history.gd` (lag-compensation rewind queries), `netfox_player_transform_sync.gd`. `rollback-synchronizer.gd` in the addon is locally patched — check `git diff` before assuming upstream behavior.

### `player.gd` is a facade (~8000 lines) — do not grow it
`scripts/player.gd` (`class_name Character`, extends `CharacterBody3D`) is intentionally a thin-ish facade. Per [docs/RUNTIME_AUTHORITY_CONTRACT.md](docs/RUNTIME_AUTHORITY_CONTRACT.md) and [docs/GDSCRIPT_MODULE_STANDARDS.md](docs/GDSCRIPT_MODULE_STANDARDS.md): **new behavior belongs in dedicated controller systems** that receive the player as context (e.g. `weapon_system.gd`, `paint_system.gd`, `camouflage_system.gd`, `shape_shift_system.gd`, `stalker_grapple_system.gd`, `hunter_*_system.gd`, `player_card_effect_controller.gd`, `shadow_visibility_system.gd`), not in new match blocks on the character root. Same rule for `network.gd` and `scripts/level.gd` (~5300 lines).

### Runtime Authority Contract — read before any networked feature
[docs/RUNTIME_AUTHORITY_CONTRACT.md](docs/RUNTIME_AUTHORITY_CONTRACT.md) defines where each system is allowed to run (owner client / server room / remote client / headless public server). Key invariants:
- Server room owns: match state, damage, death, spawn, card consumption, validated skill effects.
- Owner client owns: input sampling, local camera/HUD/feedback, optional prediction.
- **Never** create CanvasLayers, AudioStreamPlayers, particles, GPU painters, or high-poly nodes on a dedicated headless server.
- **Never** add per-frame scans on remote clients when the owner/server can publish compact state.
- Every repeated RPC path needs an event budget + telemetry key (see `map_prop_sync_budget.gd`, `network_interest.gd`, `remote_motion_sampler.gd`, `remote_visual_policy.gd` for the batching/throttling/interest patterns).

### Hot update system (`scripts/hot_update/`)
Incremental content delivery: a small `bootstrap` build + ordered content PCK packs (`core_patch`, character/map/audio families) mounted via `load_resource_pack(replace_files=true)`. Treat `scripts/hot_update/*` as **base-game bootstrap code** — it cannot itself be hot-updated. Packages are SHA-256 verified; pack contents come from the manifest, never from `DirAccess` scans of mounted packs. See [docs/HOT_UPDATE_ARCHITECTURE.md](docs/HOT_UPDATE_ARCHITECTURE.md). Config is in `project.godot` `[hot_update]`.

## Coding conventions (from docs/GDSCRIPT_MODULE_STANDARDS.md)

- Group new systems under `scripts/<feature>/`. Test entrypoints under `tests/`. Editor/build/ops helpers go in `tools/` — keep runtime code out of `tools/`, and keep one-off authoring/scene-edit scripts out of `scripts/`.
- Use `class_name` for reusable modules; `RefCounted` for pure data/validation; `Node` only when tree/signals/timers/HTTP/lifecycle are needed. Keep autoloads thin.
- **Explicit static types** on params, returns, and non-obvious locals. Validate/normalize loose JSON/manifest data at the boundary.
- `bool` return for start/queue methods + a signal for async completion; store latest error in `last_error`. Include stable IDs (peer/room/card/package id) in errors.
- `user://` for downloaded/generated data, `res://` for shipped resources.
- **New code comments must be in English** and explain *why* / which boundary is protected (existing code mixes Chinese and English).

## Map content

Maps live in `scenes/level/maps/`. Large `polygon_apocalypse_*` city maps are Unity-migrated (see `assets/unity_migrated/`, `scripts/polygon_apocalypse_map.gd`). `.codex_compare/` and `.codex_tmp/` are scratch/comparison dirs (Unity batch project, gdquest characters) — not part of the shipped game; ignore them for normal work.
