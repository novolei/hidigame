extends Node
class_name PlayerInputState

const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_MOVE_FORWARD := "move_forward"
const ACTION_MOVE_BACKWARD := "move_backward"
const ACTION_JUMP := "jump"
const ACTION_SPRINT := "shift"
const ACTION_SHOOT := "shoot"
const ACTION_RELOAD := "reload"
const ACTION_PAINT := "paint_trigger"
const ACTION_SHAPE_SHIFT := "shape_shift"
const ACTION_CAMOUFLAGE_ABSORB := "camouflage_absorb"
const ACTION_FLASHLIGHT := "flashlight"
const ACTION_GRAPPLE := "stalker_grapple"
const ACTION_INTERACT := "interact"
const ACTION_HOLOGRAM_FLAG := "place_hologram_flag"

@export var player_path: NodePath = NodePath("..")
@export_range(0, 12, 1) var fresh_tick_window: int = 2
@export var capture_only_when_authority: bool = true
@export var buffer_frame_input: bool = true

var tick: int = -1
var sequence: int = 0
var move_axis: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var sprint_held: bool = false
var shoot_pressed: bool = false
var shoot_held: bool = false
var reload_pressed: bool = false
var paint_pressed: bool = false
var paint_held: bool = false
var shape_shift_pressed: bool = false
var camouflage_absorb_pressed: bool = false
var flashlight_pressed: bool = false
var grapple_pressed: bool = false
var interact_pressed: bool = false
var hologram_flag_pressed: bool = false

var _player: Node = null
var _intent_sequence: int = 0
var _move_axis_buffer: Vector2 = Vector2.ZERO
var _move_axis_sample_count: int = 0
var _jump_pressed_buffer: bool = false
var _shoot_pressed_buffer: bool = false
var _reload_pressed_buffer: bool = false
var _paint_pressed_buffer: bool = false
var _shape_shift_pressed_buffer: bool = false
var _camouflage_absorb_pressed_buffer: bool = false
var _flashlight_pressed_buffer: bool = false
var _grapple_pressed_buffer: bool = false
var _interact_pressed_buffer: bool = false
var _hologram_flag_pressed_buffer: bool = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	set_physics_process(false)
	_refresh_capture_policy()
	call_deferred("_sync_authority_from_player")


func _ready() -> void:
	_resolve_player()
	_sync_authority_from_player()
	_refresh_capture_policy()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_disconnect_tick_capture()


func _process(_delta: float) -> void:
	if not buffer_frame_input:
		return
	if not _should_capture_input():
		_clear_frame_input_buffer()
		return
	_accumulate_frame_input()


func _before_tick_loop() -> void:
	if not _should_capture_input():
		_refresh_capture_policy()
		return
	sample_now(NetworkTime.tick)


func _refresh_capture_policy() -> void:
	if Engine.is_editor_hint():
		return
	var should_capture: bool = _should_capture_input()
	set_process(buffer_frame_input and should_capture)
	if should_capture:
		if not NetworkTime.before_tick_loop.is_connected(_before_tick_loop):
			NetworkTime.before_tick_loop.connect(_before_tick_loop)
	else:
		_disconnect_tick_capture()
		_clear_frame_input_buffer()


func _disconnect_tick_capture() -> void:
	if NetworkTime.before_tick_loop.is_connected(_before_tick_loop):
		NetworkTime.before_tick_loop.disconnect(_before_tick_loop)


func sample_now(sample_tick: int = -1) -> void:
	tick = NetworkTime.tick if sample_tick < 0 else sample_tick
	sequence += 1
	move_axis = _consume_movement_axis()
	jump_pressed = _jump_pressed_buffer or _action_just_pressed(ACTION_JUMP)
	jump_held = _action_pressed(ACTION_JUMP)
	sprint_held = _action_pressed(ACTION_SPRINT)
	shoot_pressed = _shoot_pressed_buffer or _action_just_pressed(ACTION_SHOOT)
	shoot_held = _action_pressed(ACTION_SHOOT)
	reload_pressed = _reload_pressed_buffer or _action_just_pressed(ACTION_RELOAD)
	paint_pressed = _paint_pressed_buffer or _action_just_pressed(ACTION_PAINT)
	paint_held = _action_pressed(ACTION_PAINT)
	shape_shift_pressed = _shape_shift_pressed_buffer or _action_just_pressed(ACTION_SHAPE_SHIFT)
	camouflage_absorb_pressed = _camouflage_absorb_pressed_buffer or _action_just_pressed(ACTION_CAMOUFLAGE_ABSORB)
	flashlight_pressed = _flashlight_pressed_buffer or _action_just_pressed(ACTION_FLASHLIGHT)
	grapple_pressed = _grapple_pressed_buffer or _action_just_pressed(ACTION_GRAPPLE)
	interact_pressed = _interact_pressed_buffer or _action_just_pressed(ACTION_INTERACT)
	hologram_flag_pressed = _hologram_flag_pressed_buffer or _action_just_pressed(ACTION_HOLOGRAM_FLAG)
	_clear_frame_input_buffer()


func has_fresh_sample(max_age_ticks: int = -1) -> bool:
	if tick < 0:
		return false
	var allowed_age: int = fresh_tick_window if max_age_ticks < 0 else max_age_ticks
	return absi(NetworkTime.tick - tick) <= maxi(allowed_age, 0) + 1


func is_action_just_pressed(action: String) -> bool:
	match action:
		ACTION_JUMP:
			return jump_pressed
		ACTION_SHOOT:
			return shoot_pressed
		ACTION_RELOAD:
			return reload_pressed
		ACTION_PAINT:
			return paint_pressed
		ACTION_SHAPE_SHIFT:
			return shape_shift_pressed
		ACTION_CAMOUFLAGE_ABSORB:
			return camouflage_absorb_pressed
		ACTION_FLASHLIGHT:
			return flashlight_pressed
		ACTION_GRAPPLE:
			return grapple_pressed
		ACTION_INTERACT:
			return interact_pressed
		ACTION_HOLOGRAM_FLAG:
			return hologram_flag_pressed
		_:
			return _action_just_pressed(action)


func is_action_held(action: String) -> bool:
	match action:
		ACTION_JUMP:
			return jump_held
		ACTION_SPRINT:
			return sprint_held
		ACTION_SHOOT:
			return shoot_held
		ACTION_PAINT:
			return paint_held
		_:
			return _action_pressed(action)


func allocate_intent_sequence() -> int:
	_intent_sequence += 1
	if _intent_sequence >= 0x7fffffff:
		_intent_sequence = 1
	return _intent_sequence


func _should_capture_input() -> bool:
	if not capture_only_when_authority:
		return true
	var player: Node = _resolve_player()
	if player == null:
		return true
	if player.has_method("_is_local_authority"):
		return bool(player.call("_is_local_authority"))
	if not multiplayer.has_multiplayer_peer():
		return true
	if player.has_method("get_multiplayer_authority"):
		return int(player.call("get_multiplayer_authority")) == multiplayer.get_unique_id()
	return true


func _resolve_player() -> Node:
	if _player and is_instance_valid(_player):
		return _player
	_player = get_node_or_null(player_path)
	return _player


func _sync_authority_from_player() -> void:
	var player: Node = _resolve_player()
	if player == null or not is_instance_valid(player):
		_refresh_capture_policy()
		return
	if not player.has_method("get_multiplayer_authority"):
		_refresh_capture_policy()
		return
	var authority: int = int(player.call("get_multiplayer_authority"))
	if authority > 0 and get_multiplayer_authority() != authority:
		set_multiplayer_authority(authority)
	_refresh_capture_policy()


func _accumulate_frame_input() -> void:
	_move_axis_buffer += _read_movement_axis()
	_move_axis_sample_count += 1
	_jump_pressed_buffer = _jump_pressed_buffer or _action_just_pressed(ACTION_JUMP)
	_shoot_pressed_buffer = _shoot_pressed_buffer or _action_just_pressed(ACTION_SHOOT)
	_reload_pressed_buffer = _reload_pressed_buffer or _action_just_pressed(ACTION_RELOAD)
	_paint_pressed_buffer = _paint_pressed_buffer or _action_just_pressed(ACTION_PAINT)
	_shape_shift_pressed_buffer = _shape_shift_pressed_buffer or _action_just_pressed(ACTION_SHAPE_SHIFT)
	_camouflage_absorb_pressed_buffer = _camouflage_absorb_pressed_buffer or _action_just_pressed(ACTION_CAMOUFLAGE_ABSORB)
	_flashlight_pressed_buffer = _flashlight_pressed_buffer or _action_just_pressed(ACTION_FLASHLIGHT)
	_grapple_pressed_buffer = _grapple_pressed_buffer or _action_just_pressed(ACTION_GRAPPLE)
	_interact_pressed_buffer = _interact_pressed_buffer or _action_just_pressed(ACTION_INTERACT)
	_hologram_flag_pressed_buffer = _hologram_flag_pressed_buffer or _action_just_pressed(ACTION_HOLOGRAM_FLAG)


func _consume_movement_axis() -> Vector2:
	if _move_axis_sample_count <= 0:
		return _read_movement_axis()
	var averaged_axis: Vector2 = _move_axis_buffer / float(_move_axis_sample_count)
	if averaged_axis.length_squared() > 1.0:
		averaged_axis = averaged_axis.normalized()
	return averaged_axis


func _clear_frame_input_buffer() -> void:
	_move_axis_buffer = Vector2.ZERO
	_move_axis_sample_count = 0
	_jump_pressed_buffer = false
	_shoot_pressed_buffer = false
	_reload_pressed_buffer = false
	_paint_pressed_buffer = false
	_shape_shift_pressed_buffer = false
	_camouflage_absorb_pressed_buffer = false
	_flashlight_pressed_buffer = false
	_grapple_pressed_buffer = false
	_interact_pressed_buffer = false
	_hologram_flag_pressed_buffer = false


func _read_movement_axis() -> Vector2:
	return Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACKWARD
	)


func _action_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
