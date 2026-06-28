extends Node3D

const LevelLayout := preload("res://scripts/level_layout_config.gd")
const UnityCatalog := preload("res://scripts/unity_asset_catalog.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_counts_scale_for_24_players()
	_test_prop_spawns_are_spread()
	_test_random_positions_stay_inside_playable_radius()
	_test_random_positions_keep_min_distance()
	_test_active_play_decor_pool_excludes_high_poly_decoration()

	if failures.is_empty():
		print("[LevelLayoutConfigTest] PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("[LevelLayoutConfigTest] " + failure)
		get_tree().quit(1)


func _test_counts_scale_for_24_players() -> void:
	_expect(LevelLayout.map_prop_count(2) == LevelLayout.MAP_PROP_COUNT_MIN, "2-player map prop count should use the small-room performance budget")
	_expect(LevelLayout.map_prop_count(5) > LevelLayout.MAP_PROP_COUNT_MIN and LevelLayout.map_prop_count(5) < LevelLayout.MAP_PROP_COUNT_8, "Small-room map prop count should scale gradually before 8 players")
	_expect(LevelLayout.map_prop_count(8) == LevelLayout.MAP_PROP_COUNT_8, "8-player map prop count should use the 8-player tuning point")
	_expect(LevelLayout.map_prop_count(24) == LevelLayout.MAP_PROP_COUNT_24, "24-player map prop count should use the 24-player tuning point")
	_expect(LevelLayout.unity_decor_count(24) == LevelLayout.UNITY_DECOR_COUNT_24, "Unity decor count should scale through LevelLayout")
	var ammo_counts: Dictionary = LevelLayout.ammo_pack_counts(24)
	_expect(int(ammo_counts.get("small", 0)) == LevelLayout.AMMO_PACK_COUNT_SMALL_24, "Small ammo count should scale through LevelLayout")
	_expect(int(ammo_counts.get("medium", 0)) == LevelLayout.AMMO_PACK_COUNT_MEDIUM_24, "Medium ammo count should scale through LevelLayout")
	_expect(int(ammo_counts.get("large", 0)) == LevelLayout.AMMO_PACK_COUNT_LARGE_24, "Large ammo count should scale through LevelLayout")


func _test_prop_spawns_are_spread() -> void:
	var prop_ids: Array[int] = []
	for index: int in range(18):
		prop_ids.append(index + 2)
	var positions: Array[Vector3] = []
	for pid: int in prop_ids:
		var spawn_position: Vector3 = LevelLayout.prop_spawn_point(pid, prop_ids)
		positions.append(spawn_position)
		_expect(_flat_radius(spawn_position) <= LevelLayout.PLAYABLE_RADIUS + 0.01, "Prop spawn should stay inside playable radius")

	var far_pairs: int = 0
	for a: int in range(positions.size()):
		for b: int in range(a + 1, positions.size()):
			if positions[a].distance_to(positions[b]) > 9.0:
				far_pairs += 1
	_expect(far_pairs > 80, "24-player prop spawn layout should spread hiders across multiple clusters")


func _test_random_positions_stay_inside_playable_radius() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337
	var used_props: Array[Vector3] = []
	var used_decor: Array[Vector3] = []
	var used_ammo: Array[Vector3] = []
	for index: int in range(64):
		var prop_pos: Vector3 = LevelLayout.random_map_prop_position(used_props, LevelLayout.MAP_PROP_MIN_DISTANCE, rng)
		var decor_pos: Vector3 = LevelLayout.random_unity_decor_position(used_decor, LevelLayout.UNITY_DECOR_MIN_DISTANCE, rng)
		var ammo_pos: Vector3 = LevelLayout.random_ammo_position(used_ammo, LevelLayout.AMMO_PACK_MIN_DISTANCE)
		used_props.append(prop_pos)
		used_decor.append(decor_pos)
		used_ammo.append(ammo_pos)
		_expect(_flat_radius(prop_pos) <= LevelLayout.MAP_PROP_OUTER_RADIUS + 0.01, "Random map prop should stay inside prop radius")
		_expect(_flat_radius(decor_pos) <= LevelLayout.UNITY_DECOR_OUTER_RADIUS + 0.01, "Random decor should stay inside decor radius")
		_expect(_flat_radius(ammo_pos) <= LevelLayout.AMMO_PACK_OUTER_RADIUS + 0.01, "Random ammo should stay inside ammo radius")


func _test_random_positions_keep_min_distance() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20240624
	var used: Array[Vector3] = []
	for index: int in range(20):
		var candidate_position: Vector3 = LevelLayout.random_map_prop_position(used, LevelLayout.MAP_PROP_MIN_DISTANCE, rng)
		for existing: Vector3 in used:
			_expect(candidate_position.distance_to(existing) >= LevelLayout.MAP_PROP_MIN_DISTANCE - 0.001, "Map prop positions should respect configured spacing")
		used.append(candidate_position)


func _test_active_play_decor_pool_excludes_high_poly_decoration() -> void:
	var excluded_ids: Dictionary = {
		"tanks_light_tank": true,
		"synty_car_small": true,
		"tanks_busted_tank": true,
	}
	var active_pool: Array = UnityCatalog.active_play_decorations()
	_expect(not active_pool.is_empty(), "Active-play decor pool should retain lightweight decoration options")
	for raw_decoration: Variant in active_pool:
		var decoration: Dictionary = raw_decoration as Dictionary
		var decor_id: String = str(decoration.get("id", ""))
		_expect(not excluded_ids.has(decor_id), "Active-play decor pool should exclude high-poly decor: %s" % decor_id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 68925
	for index: int in range(64):
		var sampled: Dictionary = UnityCatalog.random_active_play_decoration(rng)
		_expect(not excluded_ids.has(str(sampled.get("id", ""))), "Active-play random decor should not return excluded high-poly ids")


func _flat_radius(point: Vector3) -> float:
	return Vector2(point.x, point.z).length()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
