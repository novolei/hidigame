class_name VegetationTouchSampler
extends Node

const MAX_TOUCH_SLOTS: int = 8
const MIN_TOUCH_EMIT_INTERVAL: float = 0.065

var _material: ShaderMaterial
var _touch_radius: float = 2.65
var _touch_push_strength: float = 0.72
var _touch_crush_strength: float = 0.62
var _touch_recovery_speed: float = 0.92
var _touch_min_move_distance: float = 0.24
var _active_slots: int = 6
var _next_slot: int = 0
var _active_touch_count: int = 0
var _previous_positions: Dictionary = {}
var _last_touch_positions: Dictionary = {}
var _distance_since_touch: Dictionary = {}
var _last_emit_times: Dictionary = {}


func configure(shader_material: ShaderMaterial, profile: VegetationProfile) -> void:
	_material = shader_material
	if profile != null:
		_touch_radius = profile.touch_radius
		_touch_push_strength = profile.touch_push_strength
		_touch_crush_strength = profile.touch_crush_strength
		_touch_recovery_speed = profile.touch_recovery_speed
		_touch_min_move_distance = profile.touch_min_move_distance
		_active_slots = clampi(profile.touch_slot_count, 1, MAX_TOUCH_SLOTS)
	_apply_static_parameters()
	_reset_touch_uniforms()
	set_process(_material != null and not RuntimeMode.is_headless())


func _process(_delta: float) -> void:
	if _material == null:
		return
	var now_seconds: float = float(Time.get_ticks_msec()) * 0.001
	_material.set_shader_parameter("veg_time", now_seconds)
	_sample_player_motion(now_seconds)


func _apply_static_parameters() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("touch_push_strength", _touch_push_strength)
	_material.set_shader_parameter("touch_crush_strength", _touch_crush_strength)
	_material.set_shader_parameter("touch_recovery", _touch_recovery_speed)


func _reset_touch_uniforms() -> void:
	if _material == null:
		return
	_active_touch_count = 0
	_next_slot = 0
	_material.set_shader_parameter("touch_count", 0)
	for slot in MAX_TOUCH_SLOTS:
		_material.set_shader_parameter("touch%d" % slot, Vector4.ZERO)
		_material.set_shader_parameter("touch_dir%d" % slot, Vector4.ZERO)


func _sample_player_motion(now_seconds: float) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	var alive_ids: Dictionary = {}
	for candidate in scene_tree.get_nodes_in_group("players"):
		if not candidate is Node3D:
			continue
		var player := candidate as Node3D
		var player_id: int = player.get_instance_id()
		alive_ids[player_id] = true
		var current_position: Vector3 = player.global_position
		var previous_position: Vector3 = _previous_positions.get(player_id, current_position)
		var movement: Vector3 = current_position - previous_position
		var movement_xz := Vector2(movement.x, movement.z)
		var movement_distance: float = movement_xz.length()
		if not _last_touch_positions.has(player_id):
			_last_touch_positions[player_id] = previous_position
		var accumulated_distance: float = float(_distance_since_touch.get(player_id, 0.0)) + movement_distance
		_distance_since_touch[player_id] = accumulated_distance
		var last_emit_time: float = float(_last_emit_times.get(player_id, -1000.0))
		if accumulated_distance >= _touch_min_move_distance and now_seconds - last_emit_time >= MIN_TOUCH_EMIT_INTERVAL:
			var touch_start: Vector3 = _last_touch_positions.get(player_id, previous_position)
			var touch_position: Vector3 = touch_start.lerp(current_position, 0.62)
			var travel: Vector3 = current_position - touch_start
			var travel_xz := Vector2(travel.x, travel.z)
			if travel_xz.length() < 0.001:
				travel_xz = movement_xz
			_emit_touch(touch_position, travel_xz, now_seconds, accumulated_distance)
			_last_emit_times[player_id] = now_seconds
			_last_touch_positions[player_id] = current_position
			_distance_since_touch[player_id] = 0.0
		_previous_positions[player_id] = current_position

	for stored_id in _previous_positions.keys():
		if not alive_ids.has(stored_id):
			_previous_positions.erase(stored_id)
			_last_touch_positions.erase(stored_id)
			_distance_since_touch.erase(stored_id)
			_last_emit_times.erase(stored_id)


func _emit_touch(world_position: Vector3, movement_xz: Vector2, now_seconds: float, travel_distance: float) -> void:
	if _material == null:
		return
	var direction := Vector2.ZERO
	if movement_xz.length() > 0.001:
		direction = movement_xz.normalized()
	var speed_factor: float = clampf(travel_distance / maxf(_touch_min_move_distance, 0.001), 0.46, 1.12)
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % _active_slots
	_active_touch_count = mini(_active_touch_count + 1, _active_slots)
	_material.set_shader_parameter("touch%d" % slot, Vector4(world_position.x, world_position.z, now_seconds, _touch_radius))
	_material.set_shader_parameter("touch_dir%d" % slot, Vector4(direction.x, direction.y, speed_factor, 1.0))
	_material.set_shader_parameter("touch_count", _active_touch_count)
