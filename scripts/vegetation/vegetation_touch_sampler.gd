class_name VegetationTouchSampler
extends Node

const MAX_TOUCH_SLOTS: int = 8

var _material: ShaderMaterial
var _touch_radius: float = 2.85
var _touch_push_strength: float = 1.18
var _touch_crush_strength: float = 0.34
var _touch_recovery_speed: float = 1.28
var _touch_min_move_distance: float = 0.18
var _active_slots: int = 8
var _next_slot: int = 0
var _active_touch_count: int = 0
var _previous_positions: Dictionary = {}


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
		if movement_xz.length() >= _touch_min_move_distance:
			_emit_touch(current_position, movement_xz, now_seconds)
		_previous_positions[player_id] = current_position

	for stored_id in _previous_positions.keys():
		if not alive_ids.has(stored_id):
			_previous_positions.erase(stored_id)


func _emit_touch(world_position: Vector3, movement_xz: Vector2, now_seconds: float) -> void:
	if _material == null:
		return
	var direction := Vector2.ZERO
	if movement_xz.length() > 0.001:
		direction = movement_xz.normalized()
	var speed_factor: float = clampf(movement_xz.length() / maxf(_touch_min_move_distance, 0.001), 0.35, 1.65)
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % _active_slots
	_active_touch_count = mini(_active_touch_count + 1, _active_slots)
	_material.set_shader_parameter("touch%d" % slot, Vector4(world_position.x, world_position.z, now_seconds, _touch_radius))
	_material.set_shader_parameter("touch_dir%d" % slot, Vector4(direction.x, direction.y, speed_factor, 1.0))
	_material.set_shader_parameter("touch_count", _active_touch_count)
