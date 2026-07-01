class_name WaterRippleSampler
extends Node

const MAX_RIPPLE_SLOTS: int = 8
const MIN_RIPPLE_EMIT_INTERVAL: float = 0.08

var _material: ShaderMaterial
var _ripple_radius: float = 2.35
var _min_move_distance: float = 0.30
var _active_slots: int = MAX_RIPPLE_SLOTS
var _next_slot: int = 0
var _active_ripple_count: int = 0
var _previous_positions: Dictionary = {}
var _last_ripple_positions: Dictionary = {}
var _distance_since_ripple: Dictionary = {}
var _last_emit_times: Dictionary = {}


func configure(shader_material: ShaderMaterial, ripple_radius: float = 2.35, slot_count: int = MAX_RIPPLE_SLOTS, min_move_distance: float = 0.30) -> void:
	_material = shader_material
	_ripple_radius = maxf(ripple_radius, 0.25)
	_min_move_distance = maxf(min_move_distance, 0.05)
	_active_slots = clampi(slot_count, 1, MAX_RIPPLE_SLOTS)
	_reset_ripple_uniforms()
	set_process(_material != null and not RuntimeMode.is_headless())


func _process(_delta: float) -> void:
	if _material == null:
		return
	var now_seconds: float = float(Time.get_ticks_msec()) * 0.001
	_material.set_shader_parameter("water_time", now_seconds)
	_sample_player_motion(now_seconds)


func _reset_ripple_uniforms() -> void:
	if _material == null:
		return
	_active_ripple_count = 0
	_next_slot = 0
	_material.set_shader_parameter("ripple_count", 0)
	for slot in MAX_RIPPLE_SLOTS:
		_material.set_shader_parameter("ripple%d" % slot, Vector4.ZERO)
		_material.set_shader_parameter("ripple_dir%d" % slot, Vector4.ZERO)


func _sample_player_motion(now_seconds: float) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	var alive_ids: Dictionary = {}
	for candidate in scene_tree.get_nodes_in_group("players"):
		if not candidate is Node3D:
			continue
		var player: Node3D = candidate as Node3D
		var player_id: int = player.get_instance_id()
		alive_ids[player_id] = true
		var current_position: Vector3 = player.global_position
		var previous_position: Vector3 = _previous_positions.get(player_id, current_position)
		var movement: Vector3 = current_position - previous_position
		var movement_xz: Vector2 = Vector2(movement.x, movement.z)
		var movement_distance: float = movement_xz.length()
		if not _last_ripple_positions.has(player_id):
			_last_ripple_positions[player_id] = previous_position
		var accumulated_distance: float = float(_distance_since_ripple.get(player_id, 0.0)) + movement_distance
		_distance_since_ripple[player_id] = accumulated_distance
		var last_emit_time: float = float(_last_emit_times.get(player_id, -1000.0))
		if accumulated_distance >= _min_move_distance and now_seconds - last_emit_time >= MIN_RIPPLE_EMIT_INTERVAL:
			var ripple_start: Vector3 = _last_ripple_positions.get(player_id, previous_position)
			var ripple_position: Vector3 = ripple_start.lerp(current_position, 0.58)
			var travel: Vector3 = current_position - ripple_start
			var travel_xz: Vector2 = Vector2(travel.x, travel.z)
			if travel_xz.length() < 0.001:
				travel_xz = movement_xz
			_emit_ripple(ripple_position, travel_xz, now_seconds, accumulated_distance)
			_last_emit_times[player_id] = now_seconds
			_last_ripple_positions[player_id] = current_position
			_distance_since_ripple[player_id] = 0.0
		_previous_positions[player_id] = current_position

	for stored_id in _previous_positions.keys():
		if not alive_ids.has(stored_id):
			_previous_positions.erase(stored_id)
			_last_ripple_positions.erase(stored_id)
			_distance_since_ripple.erase(stored_id)
			_last_emit_times.erase(stored_id)


func _emit_ripple(world_position: Vector3, movement_xz: Vector2, now_seconds: float, travel_distance: float) -> void:
	if _material == null:
		return
	var direction: Vector2 = Vector2.ZERO
	if movement_xz.length() > 0.001:
		direction = movement_xz.normalized()
	var speed_factor: float = clampf(travel_distance / maxf(_min_move_distance, 0.001), 0.48, 1.30)
	var ripple_radius: float = _ripple_radius * lerpf(0.82, 1.22, clampf(speed_factor - 0.48, 0.0, 0.82) / 0.82)
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % _active_slots
	_active_ripple_count = mini(_active_ripple_count + 1, _active_slots)
	_material.set_shader_parameter("ripple%d" % slot, Vector4(world_position.x, world_position.z, now_seconds, ripple_radius))
	_material.set_shader_parameter("ripple_dir%d" % slot, Vector4(direction.x, direction.y, speed_factor, 1.0))
	_material.set_shader_parameter("ripple_count", _active_ripple_count)
