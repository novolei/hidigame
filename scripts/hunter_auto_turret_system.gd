extends Node3D
class_name HunterAutoTurretSystem

const DRONE_SCENE_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture.fbx"
const DRONE_ALBEDO_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture.png"
const DRONE_EMISSION_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_emission.png"
const DRONE_METALLIC_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_metallic.png"
const DRONE_NORMAL_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_normal.png"
const DRONE_ROUGHNESS_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_roughness.png"
const DRONE_EMBEDDED_ALBEDO_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_0.png"
const DRONE_EMBEDDED_AUX_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_1.png"
const DRONE_EMBEDDED_NORMAL_PATH := "res://assets/hunter_auto_turret/combat_drone/Meshy_AI_Unit_73_Combat_Drone_0623084302_texture_2.png"
const GATLING_SHOT_AUDIO_PATH := "res://assets/audio/weapons/gatling_turret_shot.wav"
const GATLING_OVERHEAT_AUDIO_PATH := "res://assets/audio/weapons/gatling_turret_overheat_stop.wav"

const SHOULDER_LOCAL_OFFSET := Vector3(0.62, 1.42, 0.10)
const MODEL_SCALE := 0.45
const MUZZLE_LOCAL_OFFSET := Vector3(0.0, 0.11, -0.72)
const VISION_HALF_ANGLE_DEGREES := 50.0
const TARGET_RANGE := 34.0
const FIRE_INTERVAL := 0.5
const TARGET_SCAN_INTERVAL := 0.22
const TARGET_LOCKED_SCAN_INTERVAL := 0.36
const DAMAGE_PER_BULLET := 10.0
const SPREAD_DEGREES := 2.2
const NEAR_MISS_HIT_RADIUS := 0.82
const SHOTS_BEFORE_OVERHEAT := 200
const OVERHEAT_COOLDOWN_SECONDS := 8.5
const SCAN_SWEEP_SPEED := 1.35
const RAY_COLLISION_MASK := 0xFFFFFFFF
const GUNSHOT_SAMPLE_RATE := 22050
const GUNSHOT_SECONDS := 0.13
const RECOIL_RECOVER_SPEED := 18.0
const RECOIL_POSITION_KICK := 0.075
const RECOIL_ROTATION_KICK := 0.055
const MUZZLE_FLASH_SECONDS := 0.105
const MODEL_FORWARD_YAW_OFFSET := PI
const NetworkInterestScript := preload("res://scripts/network_interest.gd")
const TPS_BULLET_SCENE := preload("res://player/bullet/bullet.tscn")
const TPS_BULLET_SCENE_PATH := "res://player/bullet/bullet.tscn"
const TPS_BULLET_VISUAL_SPEED := 20.0
const TPS_BULLET_VISUAL_MIN_SECONDS := 0.08
const TPS_BULLET_VISUAL_MAX_SECONDS := 1.25
const TPS_BULLET_MIN_DISTANCE := 0.12
const TURRET_VISUAL_RPC_RELEVANCE_RADIUS := 48.0
const USE_HIGH_POLY_DRONE_VISUAL_DEFAULT := false
const TURRET_VISUAL_CULL_RANGE := 42.0
const TURRET_VISUAL_CULL_MARGIN := 6.0

var hunter: Node3D = null
var owner_peer_id := 1
var visual_root: Node3D = null
var muzzle_marker: Node3D = null
var fire_cooldown := 0.0
var heat_shots := 0
var overheat_cooldown := 0.0
var sweep_phase := 0.0
var current_yaw_degrees := 0.0
var recoil_offset := Vector3.ZERO
var recoil_rotation := Vector3.ZERO
var _shot_stream: AudioStreamWAV = null
var _shot_audio: AudioStreamPlayer3D = null
var _overheat_audio: AudioStreamPlayer3D = null
var _suppress_shot_audio_until_msec := 0
var _target_scan_elapsed := TARGET_SCAN_INTERVAL
var _cached_target: Node3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	_rng.randomize()
	_ensure_visual()
	_ensure_audio()


func initialize(owner_node: Node3D) -> void:
	hunter = owner_node
	top_level = true
	if hunter and hunter.has_method("get_multiplayer_authority"):
		owner_peer_id = hunter.get_multiplayer_authority()
	_ensure_visual()
	_ensure_audio()


func _should_skip_dedicated_server_visuals() -> bool:
	return RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config)


func is_auto_turret_enabled() -> bool:
	return bool(Network.lobby_config.get("hunter_auto_turret_enabled", false))


func get_target_range() -> float:
	return clampf(float(Network.lobby_config.get("hunter_auto_turret_range", TARGET_RANGE)), 8.0, 60.0)


func _should_scan_targets() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.is_server():
		return true
	return hunter != null and is_instance_valid(hunter) and hunter.has_method("is_multiplayer_authority") and bool(hunter.call("is_multiplayer_authority"))


func _get_budgeted_target(delta: float) -> Node3D:
	if not _should_scan_targets():
		_cached_target = null
		return null
	_target_scan_elapsed += delta
	var has_trackable_cached_target: bool = _cached_target_is_still_trackable()
	if not has_trackable_cached_target:
		_cached_target = null
	var scan_interval: float = TARGET_LOCKED_SCAN_INTERVAL if has_trackable_cached_target else TARGET_SCAN_INTERVAL
	if _target_scan_elapsed >= scan_interval or _cached_target == null:
		_target_scan_elapsed = 0.0
		_cached_target = _find_best_visible_prop_target()
	return _cached_target


func _cached_target_is_still_trackable() -> bool:
	if _cached_target == null or not is_instance_valid(_cached_target):
		return false
	if not _is_valid_prop_target(_cached_target):
		return false
	var aim_point: Vector3 = _get_target_aim_point(_cached_target)
	if _get_muzzle_position().distance_to(aim_point) > get_target_range():
		return false
	if not _is_inside_scan_cone(aim_point):
		return false
	return true


func _process(delta: float) -> void:
	if not _is_valid_hunter():
		visible = false
		return
	if not is_auto_turret_enabled():
		visible = false
		_cached_target = null
		return
	var skip_visuals := _should_skip_dedicated_server_visuals()
	visible = not skip_visuals
	global_position = _get_hover_anchor_position()
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if overheat_cooldown > 0.0:
		overheat_cooldown = maxf(0.0, overheat_cooldown - delta)
		if overheat_cooldown <= 0.0:
			heat_shots = 0
	if not skip_visuals:
		_process_recoil(delta)
	var target := _get_budgeted_target(delta)
	if not skip_visuals:
		_update_tracking(delta, target)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and target and fire_cooldown <= 0.0 and not is_overheated():
		fire_cooldown = FIRE_INTERVAL
		_server_fire_at_target(target)


func force_scan_for_test() -> Node3D:
	if not is_auto_turret_enabled():
		return null
	return _find_best_visible_prop_target()


func get_target_scan_debug_for_test(target: Node3D) -> Dictionary:
	var origin := _get_muzzle_position()
	var aim_point := _get_target_aim_point(target)
	var to_target := aim_point - global_position
	to_target.y = 0.0
	var forward := _get_scan_forward()
	var angle := 0.0
	if to_target.length_squared() > 0.0001:
		angle = rad_to_deg(acos(clampf(forward.dot(to_target.normalized()), -1.0, 1.0)))
	return {
		"valid": _is_valid_prop_target(target),
		"distance": origin.distance_to(aim_point),
		"angle": angle,
		"in_cone": _is_inside_scan_cone(aim_point),
		"los": _has_line_of_sight(origin, aim_point, target),
		"origin": origin,
		"aim_point": aim_point,
		"forward": forward,
		"group_count": get_tree().get_nodes_in_group("players").size() if is_inside_tree() else -1,
	}


func force_fire_for_test(target: Node3D) -> void:
	_server_fire_at_target(target)


func force_apply_hit_for_test(target: Node3D) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(DAMAGE_PER_BULLET, owner_peer_id, false)


func force_mark_shot_for_test() -> void:
	if is_overheated():
		return
	heat_shots += 1
	if heat_shots >= SHOTS_BEFORE_OVERHEAT:
		overheat_cooldown = OVERHEAT_COOLDOWN_SECONDS


func get_fire_interval() -> float:
	return FIRE_INTERVAL


func get_target_scan_interval_for_test() -> float:
	return TARGET_SCAN_INTERVAL


func get_locked_target_scan_interval_for_test() -> float:
	return TARGET_LOCKED_SCAN_INTERVAL


func get_damage_per_bullet() -> float:
	return DAMAGE_PER_BULLET


func get_vision_half_angle_degrees() -> float:
	return VISION_HALF_ANGLE_DEGREES


func get_spread_degrees() -> float:
	return SPREAD_DEGREES


func get_shots_before_overheat() -> int:
	return SHOTS_BEFORE_OVERHEAT


func get_overheat_cooldown_seconds() -> float:
	return OVERHEAT_COOLDOWN_SECONDS


func get_heat_shots() -> int:
	return heat_shots


func get_overheat_remaining() -> float:
	return overheat_cooldown


func is_overheated() -> bool:
	return overheat_cooldown > 0.0


func drain_by_card(duration: float = OVERHEAT_COOLDOWN_SECONDS) -> void:
	heat_shots = SHOTS_BEFORE_OVERHEAT
	overheat_cooldown = maxf(overheat_cooldown, duration)
	Network.record_rpc_event("turret.overheat", maxi(multiplayer.get_peers().size(), 1) if multiplayer.has_multiplayer_peer() else 1, 12)
	_broadcast_turret_overheat.rpc()


func get_model_scale() -> float:
	return MODEL_SCALE


func get_shoulder_local_offset() -> Vector3:
	return SHOULDER_LOCAL_OFFSET


func get_default_forward_for_test() -> Vector3:
	return _get_scan_forward()


func get_current_forward_for_test() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func get_visual_model_yaw_offset_for_test() -> float:
	return MODEL_FORWARD_YAW_OFFSET


func get_hover_anchor_position_for_test() -> Vector3:
	return _get_hover_anchor_position()


func get_recoil_offset_for_test() -> Vector3:
	return recoil_offset


func get_recoil_rotation_for_test() -> Vector3:
	return recoil_rotation


func get_muzzle_flash_count_for_test() -> int:
	var count := 0
	for child in get_children():
		if str(child.name).begins_with("AutoTurretMuzzleFlash"):
			count += 1
	return count


func get_tps_bullet_effect_count_for_test() -> int:
	var count := 0
	for child in get_children():
		if str(child.name).begins_with("AutoTurretTpsBullet"):
			count += 1
	return count


func get_tps_bullet_effect_sources_for_test() -> Array[String]:
	var sources: Array[String] = []
	for child in get_children():
		if str(child.name).begins_with("AutoTurretTpsBullet"):
			sources.append(str(child.get_meta("effect_source", "")))
	return sources


func get_tps_bullet_visual_speed_for_test() -> float:
	return TPS_BULLET_VISUAL_SPEED


func has_single_shot_audio_for_test() -> bool:
	return get_node_or_null("AutoTurretShotAudio") is AudioStreamPlayer3D


func has_extra_gatling_audio_for_test() -> bool:
	return get_node_or_null("AutoTurretGatlingLoopAudio") != null


func has_overheat_audio_for_test() -> bool:
	return get_node_or_null("AutoTurretOverheatStopAudio") is AudioStreamPlayer3D


func get_shot_audio_length_for_test() -> float:
	var player := get_node_or_null("AutoTurretShotAudio") as AudioStreamPlayer3D
	if player and player.stream:
		return player.stream.get_length()
	return 0.0


func get_overheat_audio_length_for_test() -> float:
	var player := get_node_or_null("AutoTurretOverheatStopAudio") as AudioStreamPlayer3D
	if player and player.stream:
		return player.stream.get_length()
	return 0.0


func get_visual_mesh_count_for_test() -> int:
	var meshes: Array[MeshInstance3D] = []
	_collect_visual_meshes(visual_root, meshes)
	return meshes.size()


func get_textured_visual_mesh_count_for_test() -> int:
	var meshes: Array[MeshInstance3D] = []
	_collect_visual_meshes(visual_root, meshes)
	var count := 0
	for mesh_instance in meshes:
		if _mesh_has_albedo_texture(mesh_instance):
			count += 1
	return count


func trigger_visual_shot_for_test(start: Vector3, end: Vector3) -> void:
	clear_tps_bullet_effects_for_test()
	_broadcast_turret_shot(start, end, Vector3.UP, false)


func clear_tps_bullet_effects_for_test() -> void:
	for child in get_children():
		if str(child.name).begins_with("AutoTurretTpsBullet"):
			remove_child(child)
			child.queue_free()


func _is_valid_hunter() -> bool:
	return hunter != null and is_instance_valid(hunter) and hunter.has_method("is_hunter") and hunter.is_hunter()


func _ensure_visual() -> void:
	if visual_root and is_instance_valid(visual_root):
		return
	if _should_skip_dedicated_server_visuals():
		return
	visual_root = Node3D.new()
	visual_root.name = "AutoTurretVisual"
	visual_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(visual_root)

	if _should_use_high_poly_drone_visual():
		var packed := load(DRONE_SCENE_PATH)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate()
			model.name = "CombatDroneModel"
			model.rotation.y = MODEL_FORWARD_YAW_OFFSET
			visual_root.add_child(model)
			_apply_drone_materials(model)
			_apply_turret_visual_performance_policy(model)
		else:
			_add_fallback_drone_visual()
	else:
		_add_fallback_drone_visual()

	muzzle_marker = Node3D.new()
	muzzle_marker.name = "AutoTurretMuzzle"
	visual_root.add_child(muzzle_marker)
	muzzle_marker.position = MUZZLE_LOCAL_OFFSET


func _should_use_high_poly_drone_visual() -> bool:
	if _should_skip_dedicated_server_visuals():
		return false
	return bool(Network.lobby_config.get("hunter_auto_turret_high_poly_visual", USE_HIGH_POLY_DRONE_VISUAL_DEFAULT))


func uses_high_poly_visual_for_test() -> bool:
	return visual_root != null and visual_root.get_node_or_null("CombatDroneModel") != null


func _add_fallback_drone_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "CombatDroneFallbackBody"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.55, 1.0)
	body.mesh = mesh
	var body_material := _make_emissive_material(Color(0.22, 0.30, 0.34, 1.0), Color(0.45, 0.95, 1.0, 1.0), 0.7)
	var albedo := _load_first_texture([DRONE_EMBEDDED_ALBEDO_PATH, DRONE_ALBEDO_PATH])
	if albedo:
		body_material.albedo_texture = albedo
		body_material.albedo_color = Color.WHITE
	body.material_override = body_material
	visual_root.add_child(body)
	_apply_turret_visual_performance_policy(body)

	var barrel := MeshInstance3D.new()
	barrel.name = "CombatDroneFallbackBarrel"
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.12
	barrel_mesh.bottom_radius = 0.12
	barrel_mesh.height = 1.05
	barrel_mesh.radial_segments = 10
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position.z = -0.72
	barrel.material_override = _make_emissive_material(Color(0.05, 0.07, 0.08, 1.0), Color(1.0, 0.46, 0.18, 1.0), 0.35)
	visual_root.add_child(barrel)
	_apply_turret_visual_performance_policy(barrel)


func _apply_turret_visual_performance_policy(node: Node) -> void:
	if node is GeometryInstance3D:
		var instance := node as GeometryInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		instance.visibility_range_end = TURRET_VISUAL_CULL_RANGE
		instance.visibility_range_end_margin = TURRET_VISUAL_CULL_MARGIN
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in node.get_children():
		_apply_turret_visual_performance_policy(child)


func _apply_drone_materials(root: Node) -> void:
	var albedo := _load_first_texture([DRONE_EMBEDDED_ALBEDO_PATH, DRONE_ALBEDO_PATH])
	var normal := _load_first_texture([DRONE_EMBEDDED_NORMAL_PATH, DRONE_NORMAL_PATH])
	var metallic := _load_first_texture([DRONE_METALLIC_PATH, DRONE_EMBEDDED_AUX_PATH])
	var roughness := _load_first_texture([DRONE_ROUGHNESS_PATH, DRONE_EMBEDDED_AUX_PATH])
	_preserve_or_fill_pbr_materials(root, albedo, normal, metallic, roughness)


func _load_first_texture(paths: Array[String]) -> Texture2D:
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path)
		if texture is Texture2D:
			return texture
	return null


func _preserve_or_fill_pbr_materials(node: Node, albedo: Texture2D, normal: Texture2D, metallic: Texture2D, roughness: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = null
		var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0
		for surface in range(surface_count):
			var material := _get_mesh_surface_material(mesh_instance, surface)
			if material is StandardMaterial3D:
				var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				standard.resource_local_to_scene = true
				_fill_missing_drone_material_textures(standard, albedo, normal, metallic, roughness)
				mesh_instance.set_surface_override_material(surface, standard)
			elif not material and albedo:
				mesh_instance.set_surface_override_material(surface, _create_drone_fallback_material(albedo, normal, metallic, roughness))
	for child in node.get_children():
		_preserve_or_fill_pbr_materials(child, albedo, normal, metallic, roughness)


func _get_mesh_surface_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	var override := mesh_instance.get_surface_override_material(surface)
	if override:
		return override
	if mesh_instance.mesh and surface < mesh_instance.mesh.get_surface_count():
		return mesh_instance.mesh.surface_get_material(surface)
	return null


func _fill_missing_drone_material_textures(material: StandardMaterial3D, albedo: Texture2D, normal: Texture2D, metallic: Texture2D, roughness: Texture2D) -> void:
	if not material.albedo_texture and albedo:
		material.albedo_texture = albedo
		material.albedo_color = Color.WHITE
	if not material.normal_texture and normal:
		material.normal_enabled = true
		material.normal_texture = normal
	if not material.metallic_texture and metallic:
		material.metallic_texture = metallic
		material.metallic = maxf(material.metallic, 0.35)
	if not material.roughness_texture and roughness:
		material.roughness_texture = roughness
	material.emission_energy_multiplier = minf(material.emission_energy_multiplier, 0.25)


func _create_drone_fallback_material(albedo: Texture2D, normal: Texture2D, metallic: Texture2D, roughness: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = albedo
	if normal:
		material.normal_enabled = true
		material.normal_texture = normal
	if metallic:
		material.metallic_texture = metallic
		material.metallic = 0.55
	if roughness:
		material.roughness_texture = roughness
	material.roughness = 0.54
	return material


func _collect_visual_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if not node:
		return
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_visual_meshes(child, result)


func _mesh_has_albedo_texture(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override and _material_has_albedo_texture(mesh_instance.material_override):
		return true
	if not mesh_instance.mesh:
		return false
	for surface in range(mesh_instance.mesh.get_surface_count()):
		if _material_has_albedo_texture(mesh_instance.get_surface_override_material(surface)):
			return true
		if _material_has_albedo_texture(mesh_instance.mesh.surface_get_material(surface)):
			return true
	return false


func _material_has_albedo_texture(material: Material) -> bool:
	if not material:
		return false
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture != null
	return false


func _ensure_audio() -> void:
	if _should_skip_dedicated_server_visuals():
		return
	if not _shot_audio or not is_instance_valid(_shot_audio):
		_shot_audio = AudioStreamPlayer3D.new()
		_shot_audio.name = "AutoTurretShotAudio"
		var shot_stream := load(GATLING_SHOT_AUDIO_PATH)
		_shot_audio.stream = shot_stream if shot_stream is AudioStream else _get_shot_stream()
		_configure_turret_audio(_shot_audio, -2.0, 42.0)
		add_child(_shot_audio)
	if not _overheat_audio or not is_instance_valid(_overheat_audio):
		_overheat_audio = AudioStreamPlayer3D.new()
		_overheat_audio.name = "AutoTurretOverheatStopAudio"
		var overheat_stream := load(GATLING_OVERHEAT_AUDIO_PATH)
		_overheat_audio.stream = overheat_stream if overheat_stream is AudioStream else _get_shot_stream()
		_configure_turret_audio(_overheat_audio, -1.5, 46.0)
		add_child(_overheat_audio)


func _configure_turret_audio(player: AudioStreamPlayer3D, volume_db: float, max_distance: float) -> void:
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE


func _update_tracking(delta: float, target: Node3D) -> void:
	if not visual_root:
		return
	var target_yaw := current_yaw_degrees
	var desired_forward := _get_scan_forward()
	if target:
		desired_forward = _get_target_aim_point(target) - global_position
		desired_forward.y = 0.0
		if desired_forward.length_squared() <= 0.0001:
			desired_forward = _get_scan_forward()
		else:
			desired_forward = desired_forward.normalized()
		target_yaw = _signed_yaw_between(_get_scan_forward(), desired_forward)
		target_yaw = clampf(target_yaw, -VISION_HALF_ANGLE_DEGREES, VISION_HALF_ANGLE_DEGREES)
		desired_forward = _get_scan_forward().rotated(Vector3.UP, deg_to_rad(target_yaw)).normalized()
	else:
		sweep_phase += delta * SCAN_SWEEP_SPEED
		target_yaw = sin(sweep_phase) * VISION_HALF_ANGLE_DEGREES
		desired_forward = _get_scan_forward().rotated(Vector3.UP, deg_to_rad(target_yaw)).normalized()
	current_yaw_degrees = lerpf(current_yaw_degrees, target_yaw, minf(delta * 8.0, 1.0))
	_set_world_forward(desired_forward)
	var hover := sin(Time.get_ticks_msec() * 0.004) * 0.035
	visual_root.position = Vector3(0.0, hover, 0.0) + recoil_offset
	visual_root.rotation = recoil_rotation


func _process_recoil(delta: float) -> void:
	recoil_offset = recoil_offset.move_toward(Vector3.ZERO, RECOIL_RECOVER_SPEED * delta * RECOIL_POSITION_KICK)
	recoil_rotation = recoil_rotation.move_toward(Vector3.ZERO, RECOIL_RECOVER_SPEED * delta * RECOIL_ROTATION_KICK)


func _find_best_visible_prop_target() -> Node3D:
	if not is_auto_turret_enabled() or not _is_valid_hunter() or not is_inside_tree():
		return null
	var origin := _get_muzzle_position()
	var target_range := get_target_range()
	var best_target: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("card_decoy_targets"):
		if not node is Node3D:
			continue
		var candidate := node as Node3D
		if not _is_valid_prop_target(candidate):
			continue
		var aim_point := _get_target_aim_point(candidate)
		var distance := origin.distance_to(aim_point)
		if distance > target_range or distance >= best_distance:
			continue
		if not _is_inside_scan_cone(aim_point):
			continue
		if not _has_line_of_sight(origin, aim_point, candidate):
			continue
		best_target = candidate
		best_distance = distance
	if best_target:
		return best_target
	for node in get_tree().get_nodes_in_group("players"):
		if node == hunter or not node is Node3D:
			continue
		var candidate := node as Node3D
		if not _is_valid_prop_target(candidate):
			continue
		var aim_point := _get_target_aim_point(candidate)
		var distance := origin.distance_to(aim_point)
		if distance > target_range or distance >= best_distance:
			continue
		if not _is_inside_scan_cone(aim_point):
			continue
		if not _has_line_of_sight(origin, aim_point, candidate):
			continue
		best_target = candidate
		best_distance = distance
	return best_target


func _is_valid_prop_target(candidate: Node3D) -> bool:
	if candidate.has_method("get_health") and candidate.get_health() <= 0.0:
		return false
	if candidate.has_method("is_card_decoy_target") and candidate.is_card_decoy_target():
		return true
	if candidate.has_method("is_chameleon") and candidate.is_chameleon():
		if candidate.has_method("is_disguised") and candidate.is_disguised():
			return false
		return _target_has_visible_true_character_mesh(candidate)
	if candidate.has_method("is_stalker") and candidate.is_stalker():
		return _is_revealed_stalker_target(candidate) and _target_has_visible_true_character_mesh(candidate)
	return false


func _is_revealed_stalker_target(candidate: Node3D) -> bool:
	if candidate.has_method("get_stalker_visibility_alpha"):
		return float(candidate.call("get_stalker_visibility_alpha")) >= 0.99
	var shadow_system := candidate.get_node_or_null("ShadowVisibilitySystem")
	if not shadow_system or not shadow_system.has_method("get_visibility_alpha"):
		return false
	return float(shadow_system.call("get_visibility_alpha")) >= 0.99


func _target_has_visible_true_character_mesh(candidate: Node3D) -> bool:
	for path in [
		"3DGodotRobot/CustomCharacterSkin",
		"3DGodotRobot/RobotArmature",
		"3DGodotRobot",
	]:
		var root := candidate.get_node_or_null(path)
		if root and _node_has_visible_mesh(root):
			return true
	return false


func _node_has_visible_mesh(node: Node) -> bool:
	if node.name == "PropDisguise" or node.name == "HunterPropSenseOutline":
		return false
	if node is Node3D:
		var node_3d := node as Node3D
		if not node_3d.visible:
			return false
		if node_3d.is_inside_tree() and not node_3d.is_visible_in_tree():
			return false
	if node is MeshInstance3D:
		return true
	for child in node.get_children():
		if _node_has_visible_mesh(child):
			return true
	return false


func _is_inside_scan_cone(world_point: Vector3) -> bool:
	var to_target := world_point - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return true
	to_target = to_target.normalized()
	var forward := _get_scan_forward()
	var angle := rad_to_deg(acos(clampf(forward.dot(to_target), -1.0, 1.0)))
	return angle <= VISION_HALF_ANGLE_DEGREES


func _get_scan_forward() -> Vector3:
	var forward := Vector3.FORWARD
	if hunter and is_instance_valid(hunter):
		var spring_offset := hunter.get_node_or_null("SpringArmOffset")
		if spring_offset is Node3D:
			forward = -(spring_offset as Node3D).global_transform.basis.z
		else:
			forward = -hunter.global_transform.basis.z
	else:
		forward = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _get_hover_anchor_position() -> Vector3:
	if not hunter or not is_instance_valid(hunter):
		return global_position
	var anchor_basis := hunter.global_transform.basis
	var spring_offset := hunter.get_node_or_null("SpringArmOffset")
	if spring_offset is Node3D:
		anchor_basis = (spring_offset as Node3D).global_transform.basis
	var right := anchor_basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	return hunter.global_position + right * SHOULDER_LOCAL_OFFSET.x + Vector3.UP * SHOULDER_LOCAL_OFFSET.y + forward * SHOULDER_LOCAL_OFFSET.z


func _signed_yaw_between(from_dir: Vector3, to_dir: Vector3) -> float:
	var from_flat := Vector2(from_dir.x, from_dir.z).normalized()
	var to_flat := Vector2(to_dir.x, to_dir.z).normalized()
	var cross := from_flat.x * to_flat.y - from_flat.y * to_flat.x
	var dot := clampf(from_flat.dot(to_flat), -1.0, 1.0)
	return rad_to_deg(atan2(cross, dot))


func _set_world_forward(forward: Vector3) -> void:
	var flat := forward
	flat.y = 0.0
	if flat.length_squared() <= 0.0001:
		return
	flat = flat.normalized()
	global_rotation.y = atan2(-flat.x, -flat.z)


func _has_line_of_sight(origin: Vector3, aim_point: Vector3, target: Node3D) -> bool:
	if not get_world_3d():
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, aim_point, RAY_COLLISION_MASK)
	query.exclude = _get_excluded_rids()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return _collider_belongs_to_target(hit.get("collider", null), target)


func _server_fire_at_target(target: Node3D) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or not target or not is_instance_valid(target):
		return
	if not is_auto_turret_enabled() or is_overheated():
		return
	var start := _get_muzzle_position()
	var target_point := _get_target_aim_point(target)
	var direction := (target_point - start).normalized()
	direction = _apply_spread(direction)

	var target_range := get_target_range()
	var end := start + direction * target_range
	var normal := Vector3.UP
	var hit_prop := false
	var hit_collider = null
	if get_world_3d():
		var query := PhysicsRayQueryParameters3D.create(start, end, RAY_COLLISION_MASK)
		query.exclude = _get_excluded_rids()
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.get("position", end)
			normal = hit.get("normal", normal)
			hit_collider = hit.get("collider", null)
			if _collider_belongs_to_target(hit_collider, target):
				hit_prop = true
				if target.has_method("take_damage"):
					target.take_damage(DAMAGE_PER_BULLET, owner_peer_id, false)
		if not hit_prop and _can_correct_near_miss_to_target(start, end, target_point, target):
			end = target_point
			normal = -direction
			hit_prop = true
			if target.has_method("take_damage"):
				target.take_damage(DAMAGE_PER_BULLET, owner_peer_id, false)

	_send_turret_shot_visual(start, end, normal, hit_prop)
	heat_shots += 1
	if heat_shots >= SHOTS_BEFORE_OVERHEAT:
		overheat_cooldown = OVERHEAT_COOLDOWN_SECONDS
		Network.record_rpc_event("turret.overheat", maxi(multiplayer.get_peers().size(), 1) if multiplayer.has_multiplayer_peer() else 1, 12)
		_broadcast_turret_overheat.rpc()


func _send_turret_shot_visual(start: Vector3, end: Vector3, normal: Vector3, hit_prop: bool) -> void:
	var recipients: PackedInt32Array = _turret_visual_recipient_ids(start, end, owner_peer_id)
	if recipients.is_empty():
		return
	Network.record_rpc_event("turret.shot", recipients.size(), 72)
	for peer_id: int in recipients:
		if peer_id == 1:
			_broadcast_turret_shot(start, end, normal, hit_prop)
		else:
			_broadcast_turret_shot.rpc_id(peer_id, start, end, normal, hit_prop)


func _turret_visual_recipient_ids(segment_start: Vector3, segment_end: Vector3, always_peer_id: int) -> PackedInt32Array:
	var recipients: PackedInt32Array = PackedInt32Array()
	if multiplayer.multiplayer_peer == null:
		NetworkInterestScript.append_unique_peer_id(recipients, 1)
		return recipients

	if not _should_skip_dedicated_server_visuals() and (always_peer_id == 1 or NetworkInterestScript.is_peer_relevant_to_segment(_interest_tree(), _interest_scene(), 1, segment_start, segment_end, TURRET_VISUAL_RPC_RELEVANCE_RADIUS)):
		NetworkInterestScript.append_unique_peer_id(recipients, 1)

	for peer_id: int in multiplayer.get_peers():
		if peer_id == always_peer_id or NetworkInterestScript.is_peer_relevant_to_segment(_interest_tree(), _interest_scene(), peer_id, segment_start, segment_end, TURRET_VISUAL_RPC_RELEVANCE_RADIUS):
			NetworkInterestScript.append_unique_peer_id(recipients, peer_id)
	return recipients


func _interest_tree() -> SceneTree:
	return get_tree() if is_inside_tree() else null


func _interest_scene() -> Node:
	var tree: SceneTree = _interest_tree()
	return tree.get_current_scene() if tree else null


@rpc("authority", "call_local", "reliable")
func _broadcast_turret_overheat() -> void:
	if _should_skip_dedicated_server_visuals():
		return
	_spawn_overheat_pulse()
	_play_overheat_audio(_get_muzzle_position())


func _apply_spread(direction: Vector3) -> Vector3:
	var tangent := direction.cross(Vector3.UP)
	if tangent.length_squared() <= 0.0001:
		tangent = direction.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(direction).normalized()
	var spread_radius := tan(deg_to_rad(SPREAD_DEGREES))
	var offset := tangent * (_center_weighted_random() * spread_radius)
	offset += bitangent * (_center_weighted_random() * spread_radius)
	return (direction + offset).normalized()


func _center_weighted_random() -> float:
	return (_rng.randf() - _rng.randf()) * 0.72


func _can_correct_near_miss_to_target(start: Vector3, end: Vector3, target_point: Vector3, target: Node3D) -> bool:
	if start.distance_to(target_point) > get_target_range():
		return false
	if not _has_line_of_sight(start, target_point, target):
		return false
	var shot := end - start
	var shot_length_sq := shot.length_squared()
	if shot_length_sq <= 0.0001:
		return false
	var t := clampf((target_point - start).dot(shot) / shot_length_sq, 0.0, 1.0)
	var closest := start + shot * t
	return closest.distance_to(target_point) <= NEAR_MISS_HIT_RADIUS


func _get_muzzle_position() -> Vector3:
	if muzzle_marker and is_instance_valid(muzzle_marker):
		return muzzle_marker.global_position
	return global_position + (-global_transform.basis.z * 0.42) + Vector3.UP * 0.08


func _get_target_aim_point(target: Node3D) -> Vector3:
	if target.has_method("get_auto_turret_aim_point"):
		return target.get_auto_turret_aim_point()
	if target.has_method("get_hunter_prop_sense_position"):
		return target.get_hunter_prop_sense_position()
	return target.global_position + Vector3.UP * 1.0


func _get_excluded_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	if hunter and hunter.has_method("get_rid"):
		excluded.append(hunter.get_rid())
	return excluded


func _collider_belongs_to_target(collider, target: Node3D) -> bool:
	if not collider or not target:
		return false
	if collider == target:
		return true
	var node := collider as Node
	while node:
		if node == target:
			return true
		node = node.get_parent()
	return false


@rpc("any_peer", "call_local", "unreliable")
func _broadcast_turret_shot(start: Vector3, end: Vector3, normal: Vector3, hit_prop: bool) -> void:
	if _should_skip_dedicated_server_visuals():
		return
	var shot_direction := (end - start).normalized()
	_apply_fire_recoil()
	_spawn_muzzle_flash(start, shot_direction)
	_spawn_tps_bullet_effect(start, end, normal, hit_prop)
	_play_shot_audio(start)


func _apply_fire_recoil() -> void:
	recoil_offset = Vector3(
		_rng.randf_range(-0.018, 0.018),
		_rng.randf_range(-0.012, 0.020),
		RECOIL_POSITION_KICK
	)
	recoil_rotation = Vector3(
		_rng.randf_range(-RECOIL_ROTATION_KICK, -RECOIL_ROTATION_KICK * 0.35),
		_rng.randf_range(-RECOIL_ROTATION_KICK * 0.32, RECOIL_ROTATION_KICK * 0.32),
		_rng.randf_range(-RECOIL_ROTATION_KICK * 0.45, RECOIL_ROTATION_KICK * 0.45)
	)


func _spawn_muzzle_flash(start: Vector3, direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		direction = -global_transform.basis.z
	direction = direction.normalized()
	var flash := Node3D.new()
	flash.name = "AutoTurretMuzzleFlash"
	flash.top_level = true
	add_child(flash)
	flash.global_position = start + direction * 0.08
	flash.global_transform.basis = _basis_from_y_axis(direction)

	_add_flash_cone(flash, 0.28, 0.16, Color(1.0, 0.38, 0.06, 0.78), Color(1.0, 0.18, 0.03, 1.0), 3.4)
	_add_flash_cone(flash, 0.20, 0.095, Color(1.0, 0.88, 0.20, 0.86), Color(1.0, 0.74, 0.12, 1.0), 4.6)
	for i in range(3):
		_add_flash_blob(
			flash,
			Vector3(_rng.randf_range(-0.055, 0.055), _rng.randf_range(0.02, 0.18), _rng.randf_range(-0.045, 0.045)),
			_rng.randf_range(0.055, 0.09),
			Color(1.0, _rng.randf_range(0.38, 0.78), 0.08, 0.62)
		)
	var light := OmniLight3D.new()
	light.name = "AutoTurretMuzzleFlashLight"
	light.light_color = Color(1.0, 0.48, 0.14, 1.0)
	light.light_energy = 1.8
	light.omni_range = 2.3
	light.shadow_enabled = false
	flash.add_child(light)

	flash.scale = Vector3(0.18, 0.18, 0.18)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE, MUZZLE_FLASH_SECONDS * 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3(0.22, 0.38, 0.22), MUZZLE_FLASH_SECONDS * 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(flash.queue_free)


func _add_flash_cone(parent: Node3D, height: float, radius: float, albedo: Color, emission: Color, energy: float) -> void:
	var cone := MeshInstance3D.new()
	cone.name = "AutoTurretMuzzleFlashCone"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	cone.mesh = mesh
	cone.position.y = height * 0.5
	cone.rotation.y = _rng.randf_range(-PI, PI)
	cone.material_override = _make_muzzle_flash_material(albedo, emission, energy)
	parent.add_child(cone)


func _add_flash_blob(parent: Node3D, local_position: Vector3, radius: float, color: Color) -> void:
	var blob := MeshInstance3D.new()
	blob.name = "AutoTurretMuzzleFlashBlob"
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	blob.mesh = mesh
	blob.position = local_position
	blob.scale = Vector3(1.0, 1.35, 0.72)
	blob.material_override = _make_muzzle_flash_material(color, Color(1.0, 0.46, 0.08, 1.0), 2.8)
	parent.add_child(blob)


func _normalized_or_up(vector: Vector3) -> Vector3:
	if vector.length_squared() > 0.0001:
		return vector.normalized()
	return Vector3.UP


func _basis_from_negative_z_axis(axis: Vector3) -> Basis:
	var forward := axis.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	var z := -forward
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.96:
		up = Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()


func _spawn_tps_bullet_effect(start: Vector3, end: Vector3, normal: Vector3, hit_prop: bool) -> void:
	var length := start.distance_to(end)
	if length < TPS_BULLET_MIN_DISTANCE:
		return
	var bullet := TPS_BULLET_SCENE.instantiate() as Node3D
	if bullet == null:
		return
	bullet.name = "AutoTurretTpsBullet"
	bullet.top_level = true
	bullet.set_meta("effect_source", TPS_BULLET_SCENE_PATH)
	bullet.set_meta("hit_prop", hit_prop)
	bullet.set_meta("impact_style", "machine_gun_particles")
	add_child(bullet)

	var direction := (end - start).normalized()
	var impact_normal := _normalized_or_up(normal)
	bullet.global_position = start
	bullet.global_transform.basis = _basis_from_negative_z_axis(direction)
	if bullet.has_method("launch_visual"):
		bullet.call("launch_visual", start, end, impact_normal, hit_prop)
		return
	if bullet.has_method("play_flight"):
		bullet.call("play_flight")

	var impact_position := end + impact_normal * 0.018
	var travel_seconds := clampf(length / TPS_BULLET_VISUAL_SPEED, TPS_BULLET_VISUAL_MIN_SECONDS, TPS_BULLET_VISUAL_MAX_SECONDS)
	var tween := bullet.create_tween()
	tween.tween_property(bullet, "global_position", impact_position, travel_seconds).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "_trigger_tps_bullet_impact").bind(bullet, impact_position, impact_normal))


func _trigger_tps_bullet_impact(bullet: Node3D, impact_position: Vector3, _impact_normal: Vector3) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	bullet.global_position = impact_position
	if bullet.has_method("play_impact"):
		bullet.call("play_impact")
	else:
		bullet.queue_free()


func _play_shot_audio(audio_position: Vector3) -> void:
	if Time.get_ticks_msec() < _suppress_shot_audio_until_msec:
		return
	_ensure_audio()
	if not _shot_audio:
		return
	_shot_audio.global_position = audio_position
	_shot_audio.pitch_scale = _rng.randf_range(0.93, 1.08)
	if _shot_audio.playing:
		_shot_audio.stop()
	_shot_audio.play()


func _play_overheat_audio(audio_position: Vector3) -> void:
	_ensure_audio()
	if not _overheat_audio:
		return
	if _shot_audio and _shot_audio.playing:
		_shot_audio.stop()
	_suppress_shot_audio_until_msec = Time.get_ticks_msec() + 800
	_overheat_audio.global_position = audio_position
	_overheat_audio.pitch_scale = _rng.randf_range(0.96, 1.03)
	if _overheat_audio.playing:
		_overheat_audio.stop()
	_overheat_audio.play()


func _spawn_overheat_pulse() -> void:
	var pulse := MeshInstance3D.new()
	pulse.name = "AutoTurretOverheatPulse"
	pulse.top_level = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.36
	mesh.height = 0.72
	pulse.mesh = mesh
	pulse.material_override = _make_transparent_material(Color(1.0, 0.28, 0.08, 0.34))
	add_child(pulse)
	pulse.global_position = global_position
	var tween := pulse.create_tween()
	tween.parallel().tween_property(pulse, "scale", Vector3.ONE * 2.4, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(pulse.queue_free)


func _basis_from_y_axis(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() <= 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _make_emissive_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.roughness = 0.38
	material.metallic = 0.25
	return material


func _make_muzzle_flash_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.disable_receive_shadows = true
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _get_shot_stream() -> AudioStreamWAV:
	if _shot_stream:
		return _shot_stream
	var sample_count := int(GUNSHOT_SAMPLE_RATE * GUNSHOT_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(GUNSHOT_SAMPLE_RATE)
		var envelope := exp(-t * 24.0)
		var click := sin(TAU * 230.0 * t) * 0.48 + sin(TAU * 880.0 * t) * 0.34 + sin(TAU * 1720.0 * t) * 0.18
		var sample := int(clampf(click * envelope * 0.82, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = GUNSHOT_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_shot_stream = stream
	return _shot_stream
