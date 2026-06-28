extends Resource
class_name MapProfile

# Data-driven description of how a single prop-hunt map should be prepared and
# played. One profile per map decouples per-map behavior (grounding, collision,
# lighting, support floor, spawn footprint) from the monolithic LevelLayoutConfig
# arena constants, which were authored only for the default circular Warehouse.
#
# Why this exists: before this, every non-default map reused the Warehouse spawn
# coordinate system and one-off special cases inside level.gd, so swapping maps
# silently dropped players into geometry or out of the world. A profile lets the
# shared MapController + level.gd loader prepare any map consistently.

# How embedded lighting from imported source scenes is handled.
enum Lighting {
	KEEP,              # Keep the map's own WorldEnvironment/DirectionalLight (dark interiors)
	STRIP_ALL,         # Remove embedded WorldEnvironment and disable DirectionalLights
	STRIP_DIRECTIONAL, # Keep WorldEnvironment, disable embedded DirectionalLights only
}

# How the map's collision is brought onto the gameplay world layer.
enum Collision {
	AS_IS,          # Trust the scene's own collision/layers (already authored)
	ADAPT_LAYERS,   # Re-route existing CollisionObject3D bodies onto the world layer
	GENERATE,       # Build trimesh static bodies from visible meshes (visual-only imports)
}

# How the map is vertically aligned so its playable floor sits at ground_y.
enum GroundAlign {
	NONE,           # Author already placed the floor correctly
	SPAWN_SURFACE,  # Probe the real floor by raycast and shift the map so it sits at ground_y
	BOTTOM,         # Align the lowest mesh bound to ground_y
}

# Map size bucket. Couples the authored map footprint to a suggested player
# population so the lobby can recommend a healthy Hunter:Prop fill (still 1:3)
# without each map hand-tuning a raw player number.
enum SizeCategory {
	SMALL,   # tight arenas / single interiors → ~4 players
	MEDIUM,  # default warehouse-scale arena → ~8 players
	LARGE,   # multi-zone maps → ~12 players
	HUGE,    # city-scale sprawl → ~24 players
}

const SIZE_CATEGORY_PLAYERS := {
	SizeCategory.SMALL: 4,
	SizeCategory.MEDIUM: 8,
	SizeCategory.LARGE: 12,
	SizeCategory.HUGE: 24,
}

const SIZE_CATEGORY_LABELS := {
	SizeCategory.SMALL: "Small (4p)",
	SizeCategory.MEDIUM: "Medium (8p)",
	SizeCategory.LARGE: "Large (12p)",
	SizeCategory.HUGE: "Huge (24p)",
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene_path: String = ""

@export_group("Preparation")
@export var lighting_mode: Lighting = Lighting.STRIP_ALL
@export var collision_mode: Collision = Collision.ADAPT_LAYERS
@export var ground_align_mode: GroundAlign = GroundAlign.NONE
@export var ground_y: float = 0.0

@export_group("Gameplay Support Floor")
## Invisible flat collision plane spanning the playable area so spawn raycasts
## always resolve and players never fall out of the world where art is missing.
@export var add_support_floor: bool = true
@export var support_size: Vector2 = Vector2(110.0, 110.0)
@export var support_margin: float = 18.0
## Playable floor height after grounding. With SPAWN_SURFACE/BOTTOM this stays 0.
@export var support_top_y: float = 0.0

@export_group("Spawn Footprint")
## Radius of the playable disc spawns are clamped into. Defaults to the legacy
## Warehouse value so unmigrated maps keep their current behavior.
@export var playable_radius: float = 42.0
## When true, in-map spawn XZ is sampled/validated against this map's own floor
## instead of reusing the hardcoded Warehouse layout centers.
@export var use_warehouse_layout: bool = true

@export_group("Lobby")
## Map size bucket. Drives the suggested player count (4 / 8 / 12 / 24).
@export var size_category: SizeCategory = SizeCategory.MEDIUM
@export var min_players: int = 2
@export var max_players: int = 24


## Suggested player count for this map, derived from its size category.
func recommended_players() -> int:
	return int(SIZE_CATEGORY_PLAYERS.get(size_category, 8))


## Human-readable size label for lobby/UI, e.g. "Medium (8p)".
func size_label() -> String:
	return str(SIZE_CATEGORY_LABELS.get(size_category, "Medium (8p)"))


static func make_default(map_name: String, path: String) -> MapProfile:
	# Default profile preserves the pre-framework behavior for any map that has
	# not been explicitly migrated yet: strip lighting, adapt collision layers,
	# no re-grounding, reuse the Warehouse spawn layout.
	var profile := MapProfile.new()
	profile.id = StringName(map_name)
	profile.display_name = map_name
	profile.scene_path = path
	profile.lighting_mode = Lighting.STRIP_ALL
	profile.collision_mode = Collision.ADAPT_LAYERS
	profile.ground_align_mode = GroundAlign.NONE
	profile.add_support_floor = false
	profile.use_warehouse_layout = true
	return profile
