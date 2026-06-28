# Map System Framework

Updated: 2026-06-28

This document is the working contract for how prop-hunt maps are described, loaded,
and prepared. It exists because maps other than the default circular Warehouse arena
could not be reliably used: selecting them dropped players into geometry or out of the
world. `TPS Demo Level` was the canonical broken case.

## Root cause (why a map "could not be used")

A map becomes playable only if, by the time players are placed, three things are true:

1. **Collision is on the world layer** (layer 2) so players/props collide with it.
2. **The playable floor sits at the spawn coordinate system's ground** (y ≈ 0), because
   `level.gd` grounds spawns by raycasting straight down at hardcoded Warehouse XZ
   coordinates (`LevelLayoutConfig`).
3. **There is ground under those spawn coordinates** — real floor, or a fallback.

Working maps satisfied these via a per-map root script (`imported_static_map.gd`,
`garden_map.gd`, `tank_demo_map.gd`, `polygon_apocalypse_map.gd`). The polygon maps in
particular add an invisible **gameplay support floor** so spawns never fall through.

`tps_demo_level.tscn` and `western_town_prop_hunt.tscn` had **no map root script at all**,
so they were never grounded, never layer-normalized, and had no support floor. Combined
with the Warehouse-only spawn coordinates, players spawned floating / inside walls / under
the level. That is the "can't be used as a map" symptom.

## The framework (`scripts/maps/`)

Data-driven description + one shared preparation path, so adding a map is authoring data,
not adding special cases in `level.gd` (a do-not-grow ~5300-line facade).

### `MapProfile` (Resource — `map_profile.gd`)
Per-map data: lighting / collision / grounding policy, gameplay support floor config,
spawn footprint, and a **size category** that drives the suggested player count.

- `Lighting`: `KEEP` / `STRIP_ALL` / `STRIP_DIRECTIONAL`
- `Collision`: `AS_IS` / `ADAPT_LAYERS` / `GENERATE`
- `GroundAlign`: `NONE` / `SPAWN_SURFACE` / `BOTTOM`
- `SizeCategory`: `SMALL`→4p, `MEDIUM`→8p, `LARGE`→12p, `HUGE`→24p
  (`recommended_players()` / `size_label()` derive from it; Hunter:Prop stays 1:3).
- `make_default(name, path)` reproduces pre-framework behavior for unmigrated maps.

### `MapController` (Node3D — `map_controller.gd`)
Attach to a map scene root. On `_ready` it runs an idempotent `prepare()` pipeline:

1. Apply lighting policy.
2. Normalize collision (`ADAPT_LAYERS` re-routes existing colliders to the world layer;
   `GENERATE` builds capped trimesh static bodies for visual-only imports).
3. Ground the map (`SPAWN_SURFACE` raycasts the real floor and shifts the map so it sits
   at `ground_y`; `BOTTOM` aligns the lowest mesh bound).
4. Add a **gameplay support floor** — an invisible world-layer box spanning the playable
   area, in group `map_gameplay_support`, carrying `support_top_y` / `support_size_xz`
   metas. This is the generalized version of the polygon maps' support body and is what
   guarantees no fall-through.

It runs on every peer (local scene-graph mutation only — no networking, audio, or
particles), so it is safe on the dedicated headless server.

#### Authored spawn points (native-coordinate maps)
A map can keep its **own** coordinate system and ship a `PlayerSpawnpoints` child node
(`Node3D` of `Marker3D`s) copied from its native design, instead of being re-grounded to
y=0 and reusing the origin-based Warehouse layout. `MapController.has_authored_spawns()` /
`get_player_spawn_points()` expose them in world space. This is required for imported maps
whose walkable floors are offset from the origin or span multiple decks — re-grounding such
a map to y=0 and spawning at Warehouse origin coordinates drops players onto whatever
geometry happens to sit over the origin (for TPS Demo, the top catwalk).

`level.gd` `get_spawn_point_for_role()` routes Chameleon/Stalker/unassigned roles through
`_get_authored_map_spawn_point(pid)` first (cycling the markers with a small deterministic
jitter), and only falls back to the Warehouse `LevelLayout` when the map ships none.

### `MapRegistry` (`map_registry.gd`)
`profile_for(map_name, scene_path)` returns the authored profile for migrated maps, or a
safe default for everything else. Authored profiles live here for now; they can later move
to `.tres` assets without touching callers.

## `level.gd` integration (minimal, additive)

- `_apply_selected_map_scene()`: if the instantiated map root `is MapController`, the
  controller owns lighting/collision/grounding/support — the legacy blunt
  `_sanitize_embedded_map_lighting` + TPS-specific `_adapt_embedded_map_collision` passes
  are skipped. Unmigrated maps are unchanged.
- `_get_selected_map_support_body()`: now finds **any** `map_gameplay_support` body, so
  spawn grounding works for every framework map (polygon's existing body still works via a
  back-compat path).

## Migrating a map

1. Attach `MapController` to the map's root node (via Fennara `run_scene_edit_script`:
   `root.set_script(load("res://scripts/maps/map_controller.gd"))`).
2. Set its exported policy fields for that map (see TPS settings below).
3. Add an authored `MapProfile` to `MapRegistry._ensure_built()` keyed by the catalog name.
4. Add the map to `FRAMEWORK_MAPS` in `tests/map_catalog_integrity_test.gd` and run it.

### Example: `TPS Demo Level` (done)
`KEEP` lighting (preserve the reactor look), `ADAPT_LAYERS` collision (it has authored
colliders), `SPAWN_SURFACE` grounding (re-seat the floor at y=0), support floor 120×120,
`MEDIUM` size (8p).

## Test

`tests/map_catalog_integrity_test.tscn` (`godot --headless`) verifies:
- `size_category` → 4/8/12/24 mapping and registry profiles.
- every catalog scene loads as a `PackedScene`.
- each framework map (currently TPS Demo) instantiates, has a `MapController`, builds a
  world-layer support floor in the shared group, reports non-empty playable bounds, and has
  world-layer ground under every near-center spawn probe (the fall-through guard).

## Status / remaining work

- **Done & verified headlessly:** framework (`scripts/maps/`), `level.gd` integration,
  integrity test, and migration of **both** previously script-less maps:
  - `TPS Demo Level` — `KEEP` lighting, `ADAPT_LAYERS` collision, **native coordinates**
    (`GroundAlign.NONE`, no support floor) + authored `PlayerSpawnpoints` markers copied
    from the original `tps-demo` (player + robot spawn positions on the reactor's real
    floors at y≈-1..-12, entrance at x≈64), `MEDIUM` (8p). This replaced an earlier
    re-grounding attempt that spawned players on the top catwalk.
  - `Western Town Prop Hunt` — has 135 authored colliders and its own lighting; meshes span
    y≈[-272, 223] (canyon walls / far background), so it is grounded by `SPAWN_SURFACE`
    (never `BOTTOM`). `STRIP_ALL` lighting, `ADAPT_LAYERS` collision, 100×100 support floor,
    `LARGE` (12p).
  - The integrity test now also asserts grounding quality (origin floor within ±8 of y=0).
  - Regression: `world_object_sync`, `lobby_flow`, `level_layout_config` tests pass.
- **Note:** the gameplay support floor is centered on the origin spawn coordinate system
  with a fixed size, not derived from mesh bounds, because sprawling maps' far geometry
  pollutes the AABB.
- **Future:** move the scene-path catalog out of `level.gd` (`TANK_DEMO_MAP_SCENES`, a
  misnomer — it holds all maps) into `MapRegistry`; author size categories + profiles for
  the remaining ~20 maps; optionally derive in-map spawn zones per map instead of reusing
  the Warehouse layout; in-editor visual pass (lighting/scale) per migrated map.
