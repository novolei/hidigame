# Code Organization Standards (project constraint)

Updated: 2026-06-28

This is a **binding constraint** for all new and refactored code in Monster & Hunter.
It formalizes Godot community best practices (sources below) on top of the existing
[GDSCRIPT_MODULE_STANDARDS.md](GDSCRIPT_MODULE_STANDARDS.md) and
[RUNTIME_AUTHORITY_CONTRACT.md](RUNTIME_AUTHORITY_CONTRACT.md), and defines the target
folder tree plus a concrete plan to break the oversized scripts into focused modules.

Sources (Godot official docs):
- Project organization — group by feature, snake_case files, assets beside scenes.
- Scene organization — loose coupling, "signals up, calls down", parent mediates siblings.
- GDScript style guide — naming, declaration order, static typing, focused scripts.

## 1. Naming (enforced)

| Thing | Convention | Example |
| --- | --- | --- |
| Folders & files | `snake_case` | `player_movement_motor.gd` |
| Classes / `class_name` / nodes | `PascalCase` | `class_name PlayerMovementMotor` |
| Functions & variables | `snake_case` | `func apply_impact()` |
| Private members | leading `_` | `var _cached_state`, `func _refresh()` |
| Constants | `CONSTANT_CASE` | `const MAX_PLAYERS = 24` |
| Enums | `PascalCase` name, `CONSTANT_CASE` members | `enum Role { HUNTER }` |
| Signals | past tense | `signal player_died` |

Lowercase/snake_case files are mandatory (the exported PCK is case-sensitive; mixed case
breaks Windows↔Linux). New comments in English.

## 2. Script declaration order (enforced)

`@tool`/`@icon` → `class_name` → `extends` → `##` doc → signals → enums → constants →
static vars → `@export` vars → vars → `@onready` vars → methods (`_init`, `_ready`, virtuals,
then public, then private) → inner classes. Explicit static types on params/returns and
non-obvious locals; cast `get_node(...) as Type`. Keep method-local data local, not as members.

## 3. One file, one concept (enforced)

- `class_name` for reusable modules; `RefCounted` for pure data/validation; `Node` only when
  the scene tree / signals / timers / HTTP / lifecycle is needed. Autoloads stay thin.
- **Hard size triggers** — when a script crosses these, new behavior MUST go into a new module,
  not the script: any file > ~600 lines is "full"; the known facades (`player.gd`, `level.gd`,
  `network.gd`, `main_menu_ui.gd`) are already over budget and must only shrink.
- A new gameplay system is a controller that **receives the player/level as context**
  (e.g. `weapon_system.gd`), never a new `match`/`if` block bolted onto a facade.

## 4. Coupling rules (enforced)

- **Signals up, calls down.** A child emits a past-tense signal; the parent reacts. A parent may
  call a child's method. Children do not reach up the tree or to siblings directly.
- **Parent mediates siblings.** Sibling A talks to sibling B via their common parent, not a
  direct reference.
- **Dependency direction is one-way.** Feature modules depend on shared/core, never the reverse;
  no import cycles. A module exposes a small typed API + signals; callers do not scrape its
  internals.
- Parent-child nesting only when freeing the parent should free the child; otherwise siblings.
- Keep each scene self-contained; inject external needs via signal/method/callable/ref/NodePath
  (in that order of preference).

## 5. Target folder tree

Top level stays type-partitioned (Godot/asset-import friendly); **within `scripts/` group by
feature**, which this repo already started (`scripts/maps/`, `scripts/network/`,
`scripts/hot_update/`). Every feature folder owns its scripts + tests entrypoints.

```
scripts/
  core/            # cross-cutting singletons/util: build_info, runtime_mode, i18n, game_settings
  network/         # transport, rollback, sync, handshake (netfox glue)
  player/          # player facade + movement/animation/spawn controllers
  roles/
    chameleon/     # paint, camouflage, sculpt, shape-shift
    stalker/       # shadow visibility, grapple
    hunter/        # weapon, turret, flashlight, prop-sense
  cards/           # card database, effects, hud
  maps/            # map profile/controller/registry (done)
  props/           # fruit/map props, ammo, pickups, decor
  ui/
    menu/          # main menu, name panel, settings
    hud/           # match/skill/card huds
    startup/       # splash, intro
  hot_update/      # bootstrap updater (not hot-updatable)
tests/             # one runnable test scene/script per subsystem (mirrors scripts/ features)
tools/             # editor/build/ops helpers only (never runtime code)
docs/
scenes/, assets/, addons/   # assets grouped beside their feature scenes where practical
```

Rules: editor/build/one-off authoring scripts live in `tools/` only. `addons/` holds
third-party code untouched. Use an empty `.gdignore` in scratch dirs (`.codex_compare/`,
`.codex_tmp/`) so Godot skips them.

## 6. Refactoring plan for the oversized facades

Goal: shrink the four mega-scripts by **extracting cohesive controllers**, one at a time,
each behind a test, with **zero behavior change** per step. Order is lowest-risk-first.

| # | File (size) | Extract into | Acceptance |
| --- | --- | --- | --- |
| 1 | `main_menu_ui.gd` (~2.9k) | `scripts/ui/menu/`: split the procedural builders — `name_panel.gd`, `settings_panel.gd`, `public_lobby_panel.gd`, `landing_panel.gd` — each a `Control` the menu instantiates | landing/lobby visual snapshot tests unchanged |
| 2 | `network.gd` (~2.9k) | `scripts/network/`: `lobby_state.gd`, `card_draft.gd`, `public_room_router.gd`, `version_handshake.gd` (already partly modular); keep `Network` a thin autoload delegating to them | `lobby_flow`, `network_version_handshake` pass |
| 3 | `level.gd` (~5.3k) | `scripts/maps/` + `scripts/props/`: move map-prop sync, ammo spawn, decoration spawn, prep-room/release into systems that receive `level` as context | `world_object_sync`, `player_spawn_gate`, `lobby_flow` pass |
| 4 | `player.gd` (~8k) | `scripts/player/` + `scripts/roles/<role>/`: peel remaining role logic, camouflage GPU, remote-visual/animation, audio into controllers already in flight (`weapon_system`, `camouflage_system`, …) | `character_skin_runtime`, `network_latency_compensation` pass |

Per-step rules:
- One controller per PR-sized step; never a big-bang rewrite.
- The facade keeps only a public method + wiring; logic moves to the controller, which receives
  the facade as context and communicates back via signals.
- Add/extend a focused test in `tests/` beside each extracted module before moving on.
- Run the relevant headless tests after every step; behavior must be identical.

## 7. Definition of done for any change

Diagnostics clean (Fennara), the touched feature's test passes, no new file > ~600 lines, no
new logic added to a facade, comments in English explaining *why*/which boundary is protected.
