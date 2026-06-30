extends RefCounted
class_name MapRegistry

# Single source of truth for per-map preparation/spawn behavior. Maps that have
# been explicitly migrated get an authored MapProfile here; everything else gets
# a default profile that reproduces the pre-framework behavior, so the loader can
# treat all maps uniformly without growing per-map special cases in level.gd.
#
# The scene-path catalog itself still lives in level.gd (MAP_CATALOG). This
# registry layers profiles on top of those names and is intentionally decoupled
# so authored profiles can later move to .tres assets without touching callers.

# Authored profiles keyed by the map's display name as used in MAP_CATALOG.
# Built lazily so MapProfile resource construction stays out of class load.
static var _authored: Dictionary = {}
static var _built: bool = false


static func profile_for(map_name: String, scene_path: String = "") -> MapProfile:
	_ensure_built()
	if _authored.has(map_name):
		return _authored[map_name] as MapProfile
	return MapProfile.make_default(map_name, scene_path)


static func has_authored_profile(map_name: String) -> bool:
	_ensure_built()
	return _authored.has(map_name)


static func authored_map_names() -> Array[String]:
	_ensure_built()
	var names: Array[String] = []
	for key in _authored.keys():
		names.append(str(key))
	return names


static func _ensure_built() -> void:
	if _built:
		return
	_built = true

	var medieval := MapProfile.new()
	medieval.id = &"medieval_strategy_world"
	medieval.display_name = "Medieval Strategy World"
	medieval.scene_path = "res://scenes/level/maps/medieval_strategy_world.tscn"
	medieval.lighting_mode = MapProfile.Lighting.KEEP
	medieval.collision_mode = MapProfile.Collision.ADAPT_LAYERS
	# NONE, not SPAWN_SURFACE: the map is authored already grounded (terrain surface ~y=21.5,
	# spawns ~y=22). The runtime spawn-surface align is a deferred physics-raycast shift that
	# diverged in the level context and dropped players onto the invisible support floor; keeping
	# the authored position makes grounding deterministic and identical on every peer.
	medieval.ground_align_mode = MapProfile.GroundAlign.NONE
	medieval.ground_y = 0.0
	medieval.add_support_floor = true
	medieval.support_size = Vector2(140.0, 140.0)
	medieval.use_warehouse_layout = false
	medieval.size_category = MapProfile.SizeCategory.LARGE
	_authored["Medieval Strategy World"] = medieval

	# TPS Demo Level: a visual reactor-interior import with its own authored
	# colliders but no map root script, so it was never grounded, layer-normalized,
	# or backed by a fall-through floor. Keep its dramatic embedded lighting,
	# re-route collision onto the world layer, re-ground the playable surface to
	# y=0, and add a support floor so Warehouse spawn coordinates land safely.
	var tps := MapProfile.new()
	tps.id = &"tps_demo_level"
	tps.display_name = "TPS Demo Level"
	tps.scene_path = "res://scenes/level/maps/tps_demo_level.tscn"
	# Use the map's NATIVE coordinate system and its authored PlayerSpawnpoints
	# markers (copied from the original tps-demo) rather than re-grounding to y=0:
	# the reactor's walkable floors sit at y≈-1..-12 and the entrance platform is
	# offset to x≈64, so origin-based grounding dropped players onto the top catwalk.
	tps.lighting_mode = MapProfile.Lighting.KEEP
	tps.collision_mode = MapProfile.Collision.ADAPT_LAYERS
	tps.ground_align_mode = MapProfile.GroundAlign.NONE
	tps.add_support_floor = false
	tps.use_warehouse_layout = false
	tps.size_category = MapProfile.SizeCategory.MEDIUM
	_authored["TPS Demo Level"] = tps

	# Western Town: also a script-less visual map, but it ships 135 authored
	# colliders and its own lighting, and its meshes span a huge Y range (canyon
	# walls / far background), so its floor must be re-grounded by raycast rather
	# than by mesh bottom. Strip embedded lighting to match the shared match
	# lighting like the other outdoor maps.
	var western := MapProfile.new()
	western.id = &"western_town_prop_hunt"
	western.display_name = "Western Town Prop Hunt"
	western.scene_path = "res://scenes/level/maps/western_town_prop_hunt.tscn"
	western.lighting_mode = MapProfile.Lighting.STRIP_ALL
	western.collision_mode = MapProfile.Collision.ADAPT_LAYERS
	western.ground_align_mode = MapProfile.GroundAlign.SPAWN_SURFACE
	western.ground_y = 0.0
	western.add_support_floor = true
	western.support_size = Vector2(100.0, 100.0)
	western.use_warehouse_layout = true
	western.size_category = MapProfile.SizeCategory.LARGE
	_authored["Western Town Prop Hunt"] = western
