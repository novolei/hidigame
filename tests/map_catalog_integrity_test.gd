extends Node3D

# Integrity test for the map framework (scripts/maps/) + the map catalog.
# Guards the failure that motivated the framework: a map that loads fine in
# isolation but drops players into geometry / out of the world once selected,
# because it was never grounded, layer-normalized, or backed by a support floor.
#
# Run headlessly:
#   godot --headless tests/map_catalog_integrity_test.tscn
# Prints "[MapCatalogIntegrityTest] PASS" and exits 0 on success.

const WORLD_LAYER: int = 2

# Keep in sync with level.gd MAP_CATALOG (a.k.a. TANK_DEMO_MAP_SCENES). Only the
# scene PATHS are checked for load-ability here; heavy city maps are loaded but
# not instantiated to keep the headless run cheap.
const CATALOG := {
	"Medieval Strategy World": "res://scenes/level/maps/medieval_strategy_world.tscn",
	"Tank Demo Desert": "res://scenes/level/maps/tank_demo_desert.tscn",
	"Tank Demo Jungle": "res://scenes/level/maps/tank_demo_jungle.tscn",
	"Tank Demo Moon": "res://scenes/level/maps/tank_demo_moon.tscn",
	"TPS Demo Level": "res://scenes/level/maps/tps_demo_level.tscn",
	"garden": "res://scenes/level/maps/garden.tscn",
	"Japanese Town Street": "res://scenes/level/maps/japanese_town_street.tscn",
	"Western Town Prop Hunt": "res://scenes/level/maps/western_town_prop_hunt.tscn",
	"Polygon Apocalypse Bunker": "res://scenes/level/maps/polygon_apocalypse_bunker.tscn",
	"Polygon Apocalypse Interior": "res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn",
	"Polygon Apocalypse City": "res://scenes/level/maps/polygon_apocalypse_city_standard.tscn",
	"Polygon Apocalypse City URP": "res://scenes/level/maps/polygon_apocalypse_city_urp.tscn",
}

# Maps that should be fully prepared (instantiated + grounded + support floor).
const FRAMEWORK_MAPS: Array[String] = ["Medieval Strategy World", "TPS Demo Level", "Western Town Prop Hunt"]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_size_category_player_counts()
	_test_registry_profiles()
	_test_catalog_scenes_loadable()
	await _test_framework_maps_are_playable()

	if failures.is_empty():
		print("[MapCatalogIntegrityTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[MapCatalogIntegrityTest] " + failure)
		get_tree().quit(1)


func _test_size_category_player_counts() -> void:
	# size_category must drive the documented 4 / 8 / 12 / 24 recommendations.
	var expected := {
		MapProfile.SizeCategory.SMALL: 4,
		MapProfile.SizeCategory.MEDIUM: 8,
		MapProfile.SizeCategory.LARGE: 12,
		MapProfile.SizeCategory.HUGE: 24,
	}
	for category: int in expected.keys():
		var profile := MapProfile.new()
		profile.size_category = category as MapProfile.SizeCategory
		_expect(profile.recommended_players() == int(expected[category]),
			"size_category %d should recommend %d players (got %d)" % [category, int(expected[category]), profile.recommended_players()])
		_expect(not profile.size_label().is_empty(), "size_category %d should expose a label" % category)


func _test_registry_profiles() -> void:
	var medieval := MapRegistry.profile_for("Medieval Strategy World", CATALOG["Medieval Strategy World"])
	_expect(medieval != null, "Registry should return a profile for Medieval Strategy World")
	_expect(MapRegistry.has_authored_profile("Medieval Strategy World"), "Medieval Strategy World should have an authored profile")
	_expect(medieval.lighting_mode == MapProfile.Lighting.KEEP, "Medieval profile should preserve its authored lighting")
	_expect(not medieval.use_warehouse_layout, "Medieval profile should use authored spawns, not the warehouse layout")

	var tps := MapRegistry.profile_for("TPS Demo Level", CATALOG["TPS Demo Level"])
	_expect(tps != null, "Registry should return a profile for TPS Demo Level")
	_expect(MapRegistry.has_authored_profile("TPS Demo Level"), "TPS Demo Level should have an authored profile")
	_expect(tps.ground_align_mode == MapProfile.GroundAlign.NONE, "TPS profile should keep its native coordinate system")
	_expect(not tps.use_warehouse_layout, "TPS profile should use authored spawns, not the warehouse layout")

	# Unmigrated maps must still receive a safe default profile (no crash, sane values).
	var default_profile := MapRegistry.profile_for("garden", CATALOG["garden"])
	_expect(default_profile != null, "Registry should return a default profile for unmigrated maps")
	_expect(not MapRegistry.has_authored_profile("garden"), "garden should fall back to a default profile")
	_expect(default_profile.recommended_players() > 0, "Default profile should still recommend a player count")


func _test_catalog_scenes_loadable() -> void:
	# Every catalog entry must exist and load as a PackedScene; a broken/missing
	# scene here is exactly what makes a map unusable when selected.
	for map_name: String in CATALOG.keys():
		var path: String = str(CATALOG[map_name])
		_expect(ResourceLoader.exists(path), "Catalog map '%s' resource is missing: %s" % [map_name, path])
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path)
		_expect(packed is PackedScene, "Catalog map '%s' did not load as PackedScene: %s" % [map_name, path])


func _test_framework_maps_are_playable() -> void:
	for map_name in FRAMEWORK_MAPS:
		await _assert_map_prepared(map_name)


func _assert_map_prepared(map_name: String) -> void:
	var path: String = str(CATALOG.get(map_name, ""))
	var packed := load(path)
	if not packed is PackedScene:
		_expect(false, "Framework map '%s' failed to load" % map_name)
		return
	var instance := (packed as PackedScene).instantiate() as Node3D
	_expect(instance != null, "Framework map '%s' did not instantiate as Node3D" % map_name)
	if instance == null:
		return
	add_child(instance)

	# MapController prepares deferred (collision -> physics frame -> ground align ->
	# support floor). Give it several physics frames to finish.
	for _i in range(8):
		await get_tree().physics_frame

	_expect(instance is MapController, "Framework map '%s' root should be a MapController" % map_name)

	var controller := instance as MapController
	var space := get_world_3d().direct_space_state

	if controller != null and controller.has_authored_spawns():
		# Native-coordinate map (e.g. TPS Demo): every authored spawn marker must sit
		# on world-layer floor. This is what actually places players inside the level
		# instead of on whatever geometry sits over the origin.
		var spawns := controller.get_player_spawn_points()
		_expect(not spawns.is_empty(), "'%s' should expose authored spawn points" % map_name)
		var grounded := 0
		for spawn_transform in spawns:
			var sp: Vector3 = spawn_transform.origin
			var q := PhysicsRayQueryParameters3D.create(sp + Vector3.UP * 4.0, sp + Vector3.DOWN * 12.0, WORLD_LAYER)
			q.collide_with_bodies = true
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and absf((hit.get("position", Vector3.ZERO) as Vector3).y - sp.y) < 3.5:
				grounded += 1
		_expect(grounded == spawns.size(), "'%s' every authored spawn must rest on world-layer floor (%d/%d)" % [map_name, grounded, spawns.size()])
	else:
		# Warehouse-layout map (e.g. Western Town): validate the origin-based support
		# floor + grounding that keep its Warehouse spawn coordinates safe.
		var support := _find_support_body(instance)
		_expect(support != null, "'%s' should build a gameplay support floor" % map_name)
		if support != null:
			_expect(support.collision_layer == WORLD_LAYER, "'%s' support floor must be on the world layer" % map_name)
			_expect(support.is_in_group("map_gameplay_support"), "'%s' support floor must join the shared support group" % map_name)
		var hits := 0
		var probes: Array[Vector3] = [
			Vector3.ZERO, Vector3(12, 0, 0), Vector3(-12, 0, 0),
			Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(20, 0, 20), Vector3(-20, 0, -20),
		]
		for probe in probes:
			var query := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 80.0, probe + Vector3.DOWN * 200.0, WORLD_LAYER)
			query.collide_with_bodies = true
			if not space.intersect_ray(query).is_empty():
				hits += 1
		_expect(hits == probes.size(), "'%s' must have world-layer ground under every near-center spawn probe (%d/%d)" % [map_name, hits, probes.size()])
		var origin_query := PhysicsRayQueryParameters3D.create(Vector3(0, 300, 0), Vector3(0, -400, 0), WORLD_LAYER)
		origin_query.collide_with_bodies = true
		var origin_hit := space.intersect_ray(origin_query)
		_expect(not origin_hit.is_empty(), "'%s' must have ground under the origin spawn" % map_name)
		if not origin_hit.is_empty():
			var ground_y: float = (origin_hit.get("position", Vector3.ZERO) as Vector3).y
			_expect(absf(ground_y) < 8.0, "'%s' origin floor should be grounded near y=0 (got %.1f)" % [map_name, ground_y])

	instance.queue_free()
	await get_tree().process_frame


func _find_support_body(map_root: Node) -> StaticBody3D:
	for node in map_root.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body != null and body.is_in_group("map_gameplay_support"):
			return body
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
