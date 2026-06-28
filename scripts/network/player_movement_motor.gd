@tool
extends Node
class_name PlayerMovementMotor

const DEFAULT_WALK_SPEED: float = 5.4
const DEFAULT_RUN_SPEED: float = 11.0
const DEFAULT_JUMP_VELOCITY: float = 8.2
const DEFAULT_GRAVITY: float = 24.8
const DEFAULT_GROUND_ACCELERATION: float = 20.0
const DEFAULT_GROUND_DECELERATION: float = 24.0
const DEFAULT_AIR_ACCELERATION: float = 7.0
const DEFAULT_AIR_DECELERATION: float = 2.4
const TURN_INPUT_DEADZONE: float = 0.05

@export var player_path: NodePath = NodePath("..")
@export var input_state_path: NodePath = NodePath("../PlayerInputState")
@export var mirror_player_physics_state: bool = true
@export var apply_simulation_to_player_root: bool = false
@export var use_character_body_collision: bool = true
@export_range(0.1, 40.0, 0.1, "or_greater") var walk_speed: float = DEFAULT_WALK_SPEED
@export_range(0.1, 60.0, 0.1, "or_greater") var run_speed: float = DEFAULT_RUN_SPEED
@export_range(0.0, 40.0, 0.1, "or_greater") var jump_velocity: float = DEFAULT_JUMP_VELOCITY
@export_range(0.0, 120.0, 0.1, "or_greater") var gravity: float = DEFAULT_GRAVITY
@export_range(0.1, 120.0, 0.1, "or_greater") var ground_acceleration: float = DEFAULT_GROUND_ACCELERATION
@export_range(0.1, 120.0, 0.1, "or_greater") var ground_deceleration: float = DEFAULT_GROUND_DECELERATION
@export_range(0.1, 120.0, 0.1, "or_greater") var air_acceleration: float = DEFAULT_AIR_ACCELERATION
@export_range(0.1, 120.0, 0.1, "or_greater") var air_deceleration: float = DEFAULT_AIR_DECELERATION

var simulated_position: Vector3 = Vector3.ZERO
var simulated_velocity: Vector3 = Vector3.ZERO
var simulated_current_speed: float = 0.0
var simulated_grounded: bool = false
var simulated_yaw: float = 0.0
var simulated_can_double_jump: bool = true
var simulated_has_double_jumped: bool = false
var last_simulated_tick: int = -1
var rollback_ticks_processed: int = 0
var last_input_sequence: int = 0

var _player: CharacterBody3D = null
var _input_state: PlayerInputState = null
var _has_simulated_state: bool = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_refresh_processing_policy()
	call_deferred("_sync_authority_from_player")


func _ready() -> void:
	_resolve_player()
	_resolve_input_state()
	_sync_authority_from_player()
	_refresh_processing_policy()
	capture_from_player()


func _physics_process(_delta: float) -> void:
	if mirror_player_physics_state:
		capture_from_player()


func _refresh_processing_policy() -> void:
	set_process(false)
	set_physics_process(mirror_player_physics_state)


func _get_rollback_state_properties() -> Array[String]:
	return [
		"simulated_position",
		"simulated_velocity",
		"simulated_current_speed",
		"simulated_grounded",
		"simulated_yaw",
		"simulated_can_double_jump",
		"simulated_has_double_jumped",
	]


func _get_interpolated_properties() -> Array[String]:
	return ["simulated_position"]


func capture_from_player() -> void:
	var player: CharacterBody3D = _resolve_player()
	if player == null or not is_instance_valid(player):
		return
	simulated_position = player.global_position
	simulated_velocity = player.velocity
	simulated_current_speed = Vector2(player.velocity.x, player.velocity.z).length()
	simulated_grounded = player.is_on_floor()
	simulated_yaw = _player_visual_yaw(player)
	if _player_has_property(player, "can_double_jump"):
		simulated_can_double_jump = bool(player.get("can_double_jump"))
	if _player_has_property(player, "has_double_jumped"):
		simulated_has_double_jumped = bool(player.get("has_double_jumped"))
	_has_simulated_state = true


# Hard-anchor the rolled-back simulation state to a teleport target. Without this,
# an authoritative teleport (e.g. releasing a Hunter from the prep room into the map)
# only moves player.global_position, and the very next _rollback_tick overwrites it
# with the stale simulated_position, snapping the player back and producing the
# "stuck jitter / endless jump" desync seen across peers.
func teleport_to(target_position: Vector3) -> void:
	simulated_position = target_position
	simulated_velocity = Vector3.ZERO
	simulated_current_speed = 0.0
	simulated_has_double_jumped = false
	simulated_can_double_jump = true
	_has_simulated_state = true
	var player: CharacterBody3D = _resolve_player()
	if player != null and is_instance_valid(player):
		simulated_grounded = player.is_on_floor()
		simulated_yaw = _player_visual_yaw(player)


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	var player: CharacterBody3D = _resolve_player()
	if player == null or not is_instance_valid(player):
		return
	var input_state: PlayerInputState = _resolve_input_state()
	if not _has_simulated_state:
		capture_from_player()
	if apply_simulation_to_player_root and not _player_allows_root_drive(player):
		capture_from_player()
		last_input_sequence = input_state.sequence if input_state != null else last_input_sequence
		last_simulated_tick = tick
		return
	var move_axis: Vector2 = input_state.move_axis if input_state != null else Vector2.ZERO
	var jump_pressed: bool = input_state.jump_pressed if input_state != null else false
	var sprint_held: bool = input_state.sprint_held if input_state != null else false
	last_input_sequence = input_state.sequence if input_state != null else last_input_sequence

	var config: Dictionary = _player_movement_config(player)
	var move_direction: Vector3 = _world_move_direction(player, move_axis)
	var has_move_input: bool = move_direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE
	var speed_multiplier: float = maxf(float(config.get("speed_multiplier", 1.0)), 0.0)
	var target_speed: float = (float(config.get("run_speed", run_speed)) if sprint_held else float(config.get("walk_speed", walk_speed))) * speed_multiplier
	var target_horizontal_velocity: Vector3 = move_direction * target_speed if has_move_input else Vector3.ZERO
	var horizontal_velocity: Vector3 = Vector3(simulated_velocity.x, 0.0, simulated_velocity.z)
	var acceleration: float = float(config.get("ground_acceleration", ground_acceleration)) if has_move_input else float(config.get("ground_deceleration", ground_deceleration))
	if not simulated_grounded:
		acceleration = float(config.get("air_acceleration", air_acceleration)) if has_move_input else float(config.get("air_deceleration", air_deceleration))
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal_velocity, acceleration * delta)
	simulated_velocity.x = horizontal_velocity.x
	simulated_velocity.z = horizontal_velocity.z

	var jump_type: String = ""
	if simulated_grounded:
		simulated_can_double_jump = true
		simulated_has_double_jumped = false
		if jump_pressed:
			simulated_velocity.y = float(config.get("jump_velocity", jump_velocity))
			simulated_grounded = false
			simulated_can_double_jump = true
			jump_type = "Jump"
	elif simulated_can_double_jump and not simulated_has_double_jumped and jump_pressed:
		simulated_velocity.y = float(config.get("jump_velocity", jump_velocity))
		simulated_has_double_jumped = true
		simulated_can_double_jump = false
		jump_type = "Jump2"
	else:
		# Asymmetric gravity: heavier while descending so the fall is snappy, not floaty.
		var fall_gravity: float = float(config.get("gravity", gravity))
		if simulated_velocity.y < 0.0:
			fall_gravity *= maxf(float(config.get("fall_gravity_multiplier", 1.0)), 1.0)
		simulated_velocity.y -= fall_gravity * delta

	if apply_simulation_to_player_root:
		_apply_to_player_root(player, delta)
	else:
		simulated_position += simulated_velocity * delta
		simulated_current_speed = Vector2(simulated_velocity.x, simulated_velocity.z).length()
		simulated_grounded = simulated_position.y <= 0.001 if simulated_velocity.y <= 0.0 else simulated_grounded
	if has_move_input:
		simulated_yaw = atan2(-move_direction.x, -move_direction.z)
	if is_fresh and not jump_type.is_empty() and player.has_method("_on_rollback_movement_jump"):
		player.call("_on_rollback_movement_jump", jump_type, last_input_sequence, tick)
	last_simulated_tick = tick
	rollback_ticks_processed += 1


func _apply_to_player_root(player: CharacterBody3D, delta: float) -> void:
	player.global_position = simulated_position
	player.velocity = simulated_velocity
	if use_character_body_collision and player.is_inside_tree() and player.get_world_3d() != null:
		player.move_and_slide()
		simulated_position = player.global_position
		simulated_velocity = player.velocity
		simulated_grounded = player.is_on_floor()
	else:
		simulated_position += simulated_velocity * delta
		player.global_position = simulated_position
		player.velocity = simulated_velocity
		simulated_grounded = simulated_position.y <= 0.001 if simulated_velocity.y <= 0.0 else simulated_grounded
	simulated_current_speed = Vector2(simulated_velocity.x, simulated_velocity.z).length()
	if player.has_method("_apply_body_rotation") and simulated_current_speed > TURN_INPUT_DEADZONE:
		player.call("_apply_body_rotation", Vector3(simulated_velocity.x, 0.0, simulated_velocity.z))


func _world_move_direction(player: CharacterBody3D, move_axis: Vector2) -> Vector3:
	if move_axis.length_squared() <= TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE:
		return Vector3.ZERO
	var basis: Basis = player.global_transform.basis
	var spring_arm_offset: Node3D = player.get_node_or_null("SpringArmOffset") as Node3D
	if spring_arm_offset != null:
		basis = spring_arm_offset.global_transform.basis
	var camera_forward: Vector3 = -basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right: Vector3 = basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction: Vector3 = camera_right * move_axis.x + camera_forward * -move_axis.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction


func _player_allows_root_drive(player: CharacterBody3D) -> bool:
	if not apply_simulation_to_player_root:
		return false
	if player.has_method("allows_rollback_movement_drive"):
		return bool(player.call("allows_rollback_movement_drive"))
	return true


func _player_movement_config(player: CharacterBody3D) -> Dictionary:
	if player.has_method("get_rollback_movement_config"):
		var raw_config: Variant = player.call("get_rollback_movement_config")
		if raw_config is Dictionary:
			return raw_config as Dictionary
	return {}


func _player_visual_yaw(player: CharacterBody3D) -> float:
	var body: Node3D = player.get_node_or_null("3DGodotRobot/RobotArmature") as Node3D
	if body != null:
		return wrapf(body.rotation.y, -PI, PI)
	return wrapf(player.rotation.y, -PI, PI)


func _player_has_property(player: Object, property_name: String) -> bool:
	for property: Dictionary in player.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _sync_authority_from_player() -> void:
	var player: CharacterBody3D = _resolve_player()
	if player == null or not is_instance_valid(player):
		_refresh_processing_policy()
		return
	var authority: int = player.get_multiplayer_authority()
	if authority > 0 and get_multiplayer_authority() != authority:
		set_multiplayer_authority(authority)
	_refresh_processing_policy()


func _resolve_player() -> CharacterBody3D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_node_or_null(player_path) as CharacterBody3D
	return _player


func _resolve_input_state() -> PlayerInputState:
	if _input_state != null and is_instance_valid(_input_state):
		return _input_state
	_input_state = get_node_or_null(input_state_path) as PlayerInputState
	return _input_state
