extends CharacterBody3D
class_name Character

# =============================================================================
# Character 鈥?Prop Hunt 鐜╁绫?v0.3.3)
#
# 瑙掕壊绯荤粺:
#   - 閫氳繃 Network.Role 鏋氫妇璇嗗埆瑙掕壊
#   - 鍑嗗闃舵:Hunter 琚攣瀹?涓嶈兘绉诲姩
#   - 鎴樻枟闃舵:鎵€鏈夎鑹叉寜鍚勮嚜閫昏緫杩愪綔
# =============================================================================

const NORMAL_SPEED = 6.8
const SPRINT_SPEED = 10.4
const JUMP_VELOCITY = 8.2
const GROUND_ACCELERATION := 20.0
const GROUND_DECELERATION := 24.0
const AIR_ACCELERATION := 7.0
const AIR_DECELERATION := 2.4
const TURN_INPUT_DEADZONE := 0.05
const FOOTSTEP_WALK_INTERVAL := 0.38
const FOOTSTEP_SPRINT_INTERVAL := 0.24
const FOOTSTEP_MIN_SPEED := 0.6
const PROP_DISGUISE_HEIGHT_SPEED := 1.4
const PROP_DISGUISE_MIN_HEIGHT_OFFSET := -1.5
const PROP_DISGUISE_MAX_HEIGHT_OFFSET := 3.0
const PROP_DISGUISE_DROP_MIN_HEIGHT := 1.1
const PROP_DISGUISE_DROP_MAX_HEIGHT := 3.0
const PROP_COLLISION_MIN_RADIUS := 0.30
const PROP_COLLISION_MAX_RADIUS := 1.30
const PROP_COLLISION_MIN_HEIGHT := 0.42
const PROP_COLLISION_MAX_HEIGHT := 3.20
const PROP_PUSH_CONTACT_PADDING := 0.24
const PROP_PUSH_FORWARD_REACH := 0.34
const WORLD_COLLISION_MASK := 2
const PROP_DISGUISE_GROUND_SNAP_UP := 2.5
const PROP_DISGUISE_GROUND_SNAP_DOWN := 8.0

enum SkinColor { BLUE, YELLOW, GREEN, RED }

# -----------------------------------------------------------------------------
# 瑙掕壊(浠?Network 鍚屾杩囨潵)
# -----------------------------------------------------------------------------
var role: int = Network.Role.NONE

# 鍑嗗闃舵閿佸畾鐘舵€?server 鎺у埗)
var prep_phase_locked: bool = false

@onready var nickname: Label3D = $PlayerNick/Nickname

var player_inventory: PlayerInventory

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

@onready var _bottom_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var character_model_id := CharacterSkinCatalog.DEFAULT_ID
var _active_skin_node: Node3D = null
var _robot_visual_root: Node3D = null
var _prop_disguise_node: Node3D = null
var _prop_disguise_tween: Tween = null
var _is_prop_disguised := false
var _current_disguise_name := ""
var _prop_disguise_base_position := Vector3.ZERO
var _prop_disguise_height_offset := 0.0
var _jump_audio: AudioStreamPlayer3D = null
var _land_audio: AudioStreamPlayer3D = null
var _step_audio: AudioStreamPlayer3D = null
var _disguise_audio: AudioStreamPlayer3D = null
var _step_sounds: Array[AudioStream] = []
var _footstep_timer := 0.0
var _default_collision_shape: Shape3D = null
var _default_collision_transform := Transform3D.IDENTITY

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var can_double_jump = true
var has_double_jumped = false
var health: float = 100.0

signal health_changed(value: float)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()
	add_to_group("players")

func _ready():
	var is_local_player = is_multiplayer_authority()
	var local_client_id = multiplayer.get_unique_id()
	_robot_visual_root = get_node_or_null("3DGodotRobot/RobotArmature")
	_cache_default_collision_shape()
	_setup_player_audio()

	# 浠?Network 鍚屾瑙掕壊
	_sync_role_from_network()
	_sync_character_model_from_network()

	# 鐩戝惉瑙掕壊鍙樺寲
	if Network.player_role_changed.connect(_on_role_changed) != OK:
		pass  # 宸茶繛鎺?

	print("Debug: Player ", name, " ready - authority: ", get_multiplayer_authority(),
		", local client: ", local_client_id, ", is_local: ", is_local_player,
		", role: ", Network.role_to_string(role))

	# Hunter 鐜╁:鏈湴绔礋璐ｈ緭鍏?瑙嗚,鏈嶅姟鍣ㄧ璐熻矗鏉冨▉寮硅嵂/鍛戒腑鐘舵€併€?
	if is_hunter() and (is_local_player or multiplayer.is_server()):
		_setup_hunter_weapon()
	else:
		# 瑙掕壊鍚庡垎閰?寤跺悗鎸傝浇
		call_deferred("_check_role_after_assignment")

	if is_local_player:
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	elif multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		if get_multiplayer_authority() == local_client_id:
			request_inventory_sync.rpc_id(1)


func _check_role_after_assignment() -> void:
	_sync_role_from_network()
	if is_hunter() and (is_multiplayer_authority() or multiplayer.is_server()) and not has_node("WeaponSystem"):
		_setup_hunter_weapon()
	elif is_chameleon() and is_multiplayer_authority() and not has_node("PaintSystem"):
		_setup_chameleon_systems()


# =============================================================================
# 钘忓尶鑰呯郴缁熷垵濮嬪寲(PoC-3)
# =============================================================================

var paint_system: PaintSystem = null
var shape_system: ShapeShiftSystem = null

func _setup_chameleon_systems() -> void:
	if not is_chameleon() or not is_multiplayer_authority():
		return

	# 鍠锋秱绯荤粺
	if not has_node("PaintSystem"):
		var ps = preload("res://scripts/paint_system.gd").new()
		ps.name = "PaintSystem"
		add_child(ps)
		var cam = $SpringArmOffset/SpringArm3D/Camera3D
		ps.initialize(self, cam)
		paint_system = ps

	# 鍙樺舰绯荤粺
	if not has_node("ShapeShiftSystem"):
		var ss = preload("res://scripts/shape_shift_system.gd").new()
		ss.name = "ShapeShiftSystem"
		add_child(ss)
		ss.initialize(self)
		shape_system = ss

	print("[Player] Chameleon systems initialized")


# =============================================================================
# Hunter 姝﹀櫒鍒濆鍖?
# =============================================================================

func _setup_hunter_weapon() -> void:
	var is_local_player = is_multiplayer_authority()
	var camera = $SpringArmOffset/SpringArm3D/Camera3D

	# 鍔犺浇 AK47 妯″瀷(浠呮湰鍦拌瑙?
	if is_local_player:
		var ak47_scene = preload("res://scenes/weapons/ak47.tscn")
		if not camera.has_node("WeaponVisual"):
			var visual = ak47_scene.instantiate()
			visual.name = "WeaponVisual"
			# 鎸傚湪 Camera3D 涓?浣滀负鏈湴绗竴/涓変汉绉拌瑙?
			camera.add_child(visual)
			visual.position = Vector3(0.3, -0.3, -0.5)
			visual.rotation = Vector3(0, 0, 0)

	# 鍔犺浇 WeaponSystem(缃戠粶鏉冨▉)
	if not has_node("WeaponSystem"):
		var weapon = preload("res://scripts/weapon_system.gd").new()
		weapon.name = "WeaponSystem"
		add_child(weapon)
		weapon.initialize(self, camera if is_local_player else null)

	# 娉ㄥ唽寮硅嵂鍙樺寲淇″彿
	var weapon = get_node_or_null("WeaponSystem")
	if weapon:
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)


func _on_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	# TODO: 鏇存柊 HUD 寮硅嵂鏄剧ず
	pass


# =============================================================================
# Hunter 杈撳叆澶勭悊
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Hunter 杈撳叆
	if is_hunter():
		_handle_hunter_input(event)

	# Chameleon 杈撳叆
	if is_chameleon():
		_handle_chameleon_input(event)


func _handle_hunter_input(event: InputEvent) -> void:
	# 鍑嗗闃舵閿佸畾涓嶈兘寮€鏋?
	if prep_phase_locked:
		return

	var weapon = get_node_or_null("WeaponSystem")
	if not weapon:
		return

	# 寮€鐏?
	if event.is_action_pressed("shoot"):
		weapon.request_fire()
	# 鎹㈠脊
	if event.is_action_pressed("reload"):
		weapon.request_reload()
	if event.is_action_pressed("paint_trigger") and weapon.has_method("request_scan"):
		weapon.request_scan()


func _handle_chameleon_input(event: InputEvent) -> void:
	if not paint_system or not shape_system:
		return


	# 鍠锋秱:鍙抽敭鎸変綇(鍦?_process_input_held 涓寔缁娴?
	if event.is_action_pressed("paint_trigger"):
		paint_system.start_paint()

	# 鍙樺舰杞洏:Q 鍒囨崲寮€/鍏?
	if event.is_action_pressed("shape_shift"):
		if shape_system.has_method("has_nearby_replicable_prop") and shape_system.has_nearby_replicable_prop():
			shape_system.try_replicate_nearby_prop()
			return
		var wheel = _get_shape_wheel()
		if wheel:
			if wheel.visible:
				wheel.hide_wheel()
			else:
				wheel.show_wheel(shape_system)
				# 閿佷綇瑙掕壊绉诲姩
				shape_system.open_wheel()


func _process_input_held():
	# 鍦?_process 涓寔缁娴?shoot / paint 鎸変綇鐘舵€?
	if not is_multiplayer_authority():
		return

	# Hunter 鎸佺画寮€鐏?
	if is_hunter():
		if prep_phase_locked:
			return
		var weapon = get_node_or_null("WeaponSystem")
		if weapon and Input.is_action_pressed("shoot"):
			weapon.request_fire()

	# Chameleon 鎸佺画鍠锋秱
	if is_chameleon():
		if paint_system and Input.is_action_pressed("paint_trigger"):
			if not paint_system.is_painting:
				paint_system.start_paint()
		elif paint_system and paint_system.is_painting:
			paint_system.stop_paint()


# 鏌ユ壘 level 涓殑鍙樺舰杞洏 UI
func _get_shape_wheel() -> ShapeShiftWheelUI:
	var level = get_tree().get_current_scene() if get_tree() else null
	if not level:
		return null
	var wheel = level.get_node_or_null("ShapeShiftWheelUI")
	if wheel and wheel is ShapeShiftWheelUI:
		return wheel
	return null


func _sync_role_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		role = Network.players[my_id].get("role", Network.Role.NONE)
	else:
		role = Network.Role.NONE


func _sync_character_model_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		set_character_model(str(Network.players[my_id].get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	else:
		set_character_model(CharacterSkinCatalog.DEFAULT_ID)


func _on_role_changed(peer_id: int, new_role: int) -> void:
	if peer_id == str(name).to_int():
		role = new_role
		print("[Player ", name, "] Role updated to ", Network.role_to_string(new_role))
		# 濡傛灉鏄?Hunter 涓旇繕娌℃寕姝﹀櫒,琛ユ寕
		if new_role == Network.Role.HUNTER and (is_multiplayer_authority() or multiplayer.is_server()) and not has_node("WeaponSystem"):
			_setup_hunter_weapon()
		elif new_role == Network.Role.CHAMELEON and is_multiplayer_authority() and not has_node("PaintSystem"):
			_setup_chameleon_systems()


# =============================================================================
# 瑙掕壊 helper
# =============================================================================
func is_chameleon() -> bool:
	return role == Network.Role.CHAMELEON

func is_stalker() -> bool:
	return role == Network.Role.STALKER

func is_hunter() -> bool:
	return role == Network.Role.HUNTER

func is_prop() -> bool:
	return role == Network.Role.CHAMELEON or role == Network.Role.STALKER


# =============================================================================
# 鍑嗗闃舵閿佸畾(鏈嶅姟鍣ㄦ帶鍒?Hunter 涓嶈兘绉诲姩)
# =============================================================================
func set_prep_locked(locked: bool) -> void:
	prep_phase_locked = locked
	if locked:
		# 鍋滄浠讳綍绉诲姩
		velocity = Vector3.ZERO
		_current_speed = 0.0
		# 瑙嗚鎻愮ず(3D 鑺傜偣娌℃湁 modulate,鏀圭敤 mesh material albedo_color)
		_set_player_tint(Color(0.5, 0.5, 0.5))
	else:
		_set_player_tint(Color(1, 1, 1))


func _set_player_tint(color: Color) -> void:
	# 閬嶅巻鎵€鏈?MeshInstance3D,鏀?albedo_color(3D 鐗?modulate)
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(self, meshes)
	for mesh_inst in meshes:
		for i in range(mesh_inst.get_surface_override_material_count()):
			var mat = mesh_inst.get_surface_override_material(i)
			if mat == null:
				mat = StandardMaterial3D.new()
				mesh_inst.set_surface_override_material(i, mat)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = color


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_meshes(child, result)

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	# 鍑嗗闃舵 Hunter 閿佸畾(涓嶈兘绉诲姩)
	if is_hunter() and prep_phase_locked:
		velocity = Vector3.ZERO
		_current_speed = 0.0
		move_and_slide()
		return

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

		if should_freeze:
			freeze()
			return

	var was_on_floor := is_on_floor()
	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_play_body_jump("Jump")
	else:
		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_play_body_jump("Jump2")

	velocity.y -= gravity * delta

	_move(delta)
	var impact_velocity := velocity
	move_and_slide()
	if _apply_prop_collision_impacts(impact_velocity) and impact_velocity.y <= 0.1:
		velocity.y = minf(velocity.y, 0.0)
	_animate_body(velocity)
	_update_movement_audio(delta, was_on_floor)

func _process(delta):
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()
	# Hunter 鎸佺画寮€鐏娴?
	_process_input_held()
	_process_prop_disguise_height(delta)

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_animate_body(Vector3.ZERO)

func _move(delta: float) -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_backward"
			)

	var camera_basis := _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
	var camera_forward := -camera_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var _direction := (camera_right * _input_direction.x + camera_forward * -_input_direction.y)
	if _direction.length_squared() > 1.0:
		_direction = _direction.normalized()

	is_running()
	var has_move_input := _direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE
	var target_horizontal_velocity := Vector3.ZERO
	if has_move_input:
		target_horizontal_velocity = _direction.normalized() * _current_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := GROUND_ACCELERATION if has_move_input else GROUND_DECELERATION
	if not is_on_floor():
		acceleration = AIR_ACCELERATION if has_move_input else AIR_DECELERATION
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if has_move_input:
		_apply_body_rotation(velocity)


func _apply_prop_collision_impacts(impact_velocity: Vector3) -> bool:
	var horizontal_speed := Vector2(impact_velocity.x, impact_velocity.z).length()
	if horizontal_speed < 1.0:
		return false
	var impacted := {}
	var did_impact := false
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if not collider or not collider.has_method("apply_player_impact"):
			continue
		var collider_id := collider.get_instance_id()
		if impacted.has(collider_id):
			continue
		impacted[collider_id] = true
		collider.apply_player_impact(impact_velocity, collision.get_position(), collision.get_normal(), _is_prop_disguised)
		did_impact = true
	did_impact = _apply_nearby_prop_impacts(impact_velocity, impacted) or did_impact
	return did_impact


func _apply_nearby_prop_impacts(impact_velocity: Vector3, impacted: Dictionary) -> bool:
	if not is_inside_tree():
		return false
	var horizontal_velocity := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	if horizontal_velocity.length_squared() < 0.01:
		return false
	var move_direction := horizontal_velocity.normalized()
	var player_radius := _get_active_collision_radius()
	var did_impact := false
	for node in get_tree().get_nodes_in_group("map_props"):
		if not node is Node3D:
			continue
		if not node.has_method("apply_player_impact"):
			continue
		var node_id := node.get_instance_id()
		if impacted.has(node_id):
			continue
		var prop_position := (node as Node3D).global_position
		var to_prop := prop_position - global_position
		to_prop.y = 0.0
		var distance := to_prop.length()
		var prop_radius := 0.45
		var radius_value = node.get("collision_radius")
		if radius_value != null:
			prop_radius = float(radius_value)
		var contact_distance := player_radius + prop_radius + PROP_PUSH_CONTACT_PADDING
		var forward_distance := to_prop.dot(move_direction)
		if forward_distance < -0.05 or forward_distance > contact_distance + PROP_PUSH_FORWARD_REACH:
			continue
		if distance > contact_distance:
			continue
		var normal := Vector3.ZERO
		if distance > 0.001:
			normal = -to_prop.normalized()
		node.apply_player_impact(impact_velocity, prop_position, normal, _is_prop_disguised)
		impacted[node_id] = true
		did_impact = true
	return did_impact


func _get_active_collision_radius() -> float:
	if not _collision_shape or not _collision_shape.shape:
		return 0.42
	var shape := _collision_shape.shape
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return maxf(size.x, size.z) * 0.5
	return 0.42

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	clear_prop_disguise()

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)


func set_character_model(model_id: String) -> void:
	var normalized := CharacterSkinCatalog.normalize(model_id)
	character_model_id = normalized
	if not _body:
		return

	if normalized == CharacterSkinCatalog.DEFAULT_ID:
		if _active_skin_node and is_instance_valid(_active_skin_node):
			_active_skin_node.queue_free()
		_active_skin_node = null
		if _robot_visual_root:
			_robot_visual_root.visible = true
		return

	var scene_path := CharacterSkinCatalog.scene_path_for(normalized)
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_warning("Character model scene could not be loaded: " + scene_path)
		return

	if _active_skin_node and is_instance_valid(_active_skin_node):
		_active_skin_node.queue_free()

	_active_skin_node = scene.instantiate() as Node3D
	if not _active_skin_node:
		return

	_active_skin_node.name = "CustomCharacterSkin"
	var model := CharacterSkinCatalog.get_model(normalized)
	_active_skin_node.scale = model.get("scale", Vector3.ONE)
	_active_skin_node.position = model.get("offset", Vector3.ZERO)
	if _robot_visual_root:
		_robot_visual_root.visible = false
	_body.add_child(_active_skin_node)
	_play_skin_action("idle")


@rpc("any_peer", "call_local", "reliable")
func apply_prop_disguise(preset: Dictionary) -> void:
	if not _body:
		push_warning("Cannot apply prop disguise without a body node.")
		return
	var mesh_type := str(preset.get("mesh", "none"))
	if mesh_type == "none":
		clear_prop_disguise()
		return

	var effective_preset := preset.duplicate(true)
	_clear_prop_disguise_node()
	_prop_disguise_node = _build_prop_disguise_node(effective_preset)
	if not _prop_disguise_node:
		return

	_prop_disguise_node.name = "PropDisguise"
	_prop_disguise_height_offset = 0.0
	_body.add_child(_prop_disguise_node)
	var visual_bounds := _align_prop_disguise_visual_to_ground()
	if visual_bounds.size != Vector3.ZERO:
		effective_preset["prop_height"] = visual_bounds.size.y
	_prop_disguise_base_position = _prop_disguise_node.position
	_set_character_visual_visible(false)
	_is_prop_disguised = true
	_current_disguise_name = str(effective_preset.get("name", "Prop"))
	_apply_prop_disguise_collision(effective_preset)
	_snap_prop_disguise_to_floor()
	_play_prop_disguise_land_animation(effective_preset)
	_play_audio(_disguise_audio)
	print("[ShapeShift] ", name, " disguised as ", _current_disguise_name)


@rpc("any_peer", "call_local", "reliable")
func clear_prop_disguise() -> void:
	_clear_prop_disguise_node()
	_set_character_visual_visible(true)
	_is_prop_disguised = false
	_current_disguise_name = ""
	_prop_disguise_base_position = Vector3.ZERO
	_prop_disguise_height_offset = 0.0
	_restore_default_collision_shape()
	print("[ShapeShift] ", name, " cleared disguise")


func is_disguised() -> bool:
	return _is_prop_disguised


func get_disguise_name() -> String:
	return _current_disguise_name


func _process_prop_disguise_height(delta: float) -> void:
	if not _is_prop_disguised:
		return
	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		direction += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		direction -= 1.0
	if is_zero_approx(direction):
		return
	_adjust_prop_disguise_height(direction * PROP_DISGUISE_HEIGHT_SPEED * delta)


func _adjust_prop_disguise_height(delta: float) -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
		_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.scale = Vector3.ONE
	var next_offset := clampf(
		_prop_disguise_height_offset + delta,
		PROP_DISGUISE_MIN_HEIGHT_OFFSET,
		PROP_DISGUISE_MAX_HEIGHT_OFFSET
	)
	_apply_prop_disguise_height_offset(next_offset)
	_set_prop_disguise_height_offset.rpc(next_offset)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _set_prop_disguise_height_offset(offset: float) -> void:
	_apply_prop_disguise_height_offset(offset)


func _apply_prop_disguise_height_offset(offset: float) -> void:
	_prop_disguise_height_offset = clampf(offset, PROP_DISGUISE_MIN_HEIGHT_OFFSET, PROP_DISGUISE_MAX_HEIGHT_OFFSET)
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.position = _prop_disguise_base_position + Vector3(0.0, _prop_disguise_height_offset, 0.0)


func _cache_default_collision_shape() -> void:
	if not _collision_shape or not _collision_shape.shape:
		return
	_default_collision_shape = _collision_shape.shape.duplicate()
	_default_collision_transform = _collision_shape.transform


func _apply_prop_disguise_collision(preset: Dictionary) -> void:
	if not _collision_shape:
		return
	var dimensions := _get_prop_collision_dimensions(preset)
	var radius: float = dimensions.x
	var height: float = dimensions.y
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	_collision_shape.shape = cylinder
	_collision_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_collision_shape.rotation = Vector3.ZERO
	_collision_shape.scale = Vector3.ONE


func _snap_prop_disguise_to_floor() -> void:
	if not is_inside_tree() or not get_world_3d():
		return
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * PROP_DISGUISE_GROUND_SNAP_UP
	var to := global_position + Vector3.DOWN * PROP_DISGUISE_GROUND_SNAP_DOWN
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.hit_from_inside = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	global_position.y = hit_position.y
	velocity.y = 0.0


func _align_prop_disguise_visual_to_ground() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var bounds := _calculate_prop_disguise_bounds_in_body_space()
	if bounds.size == Vector3.ZERO:
		return AABB()
	var ground_local_y := _body.to_local(global_position).y
	_prop_disguise_node.position.y += ground_local_y - bounds.position.y
	return _calculate_prop_disguise_bounds_in_body_space()


func _calculate_prop_disguise_bounds_in_body_space() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(_prop_disguise_node, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(_body.global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _find_prop_disguise_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_prop_disguise_mesh_instances(child, result)


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _restore_default_collision_shape() -> void:
	if not _collision_shape or not _default_collision_shape:
		return
	_collision_shape.shape = _default_collision_shape.duplicate()
	_collision_shape.transform = _default_collision_transform


func _get_prop_collision_dimensions(preset: Dictionary) -> Vector2:
	var radius := float(preset.get("collision_radius", 0.0))
	var height := float(preset.get("collision_height", 0.0))
	if radius <= 0.0 or height <= 0.0:
		var size: Vector3 = preset.get("size", Vector3.ONE)
		radius = maxf(absf(size.x), absf(size.z)) * 0.42
		height = maxf(absf(size.y) * 0.82, radius * 0.75)
	if preset.has("prop_height"):
		height = maxf(height, float(preset.get("prop_height", height)))
	radius = clampf(radius, PROP_COLLISION_MIN_RADIUS, PROP_COLLISION_MAX_RADIUS)
	height = clampf(height, PROP_COLLISION_MIN_HEIGHT, PROP_COLLISION_MAX_HEIGHT)
	return Vector2(radius, height)


func _clear_prop_disguise_node() -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
	_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.queue_free()
	_prop_disguise_node = null


func _play_prop_disguise_land_animation(preset: Dictionary) -> void:
	if not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()

	var final_position: Vector3 = _prop_disguise_base_position
	var prop_height: float = maxf(float(preset.get("prop_height", 1.0)), 0.6)
	var drop_height: float = clampf(float(preset.get("drop_height", prop_height * 0.32)), PROP_DISGUISE_DROP_MIN_HEIGHT, PROP_DISGUISE_DROP_MAX_HEIGHT)
	var bounce_height: float = clampf(prop_height * 0.045, 0.12, 0.42)

	_prop_disguise_node.position = final_position + Vector3(0.0, drop_height, 0.0)
	_prop_disguise_node.scale = Vector3(0.96, 1.04, 0.96)

	_prop_disguise_tween = create_tween()
	_prop_disguise_tween.set_parallel(false)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(1.08, 0.82, 1.08), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position - Vector3(0.0, 0.035, 0.0), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(0.95, 1.08, 0.95), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position + Vector3(0.0, bounce_height, 0.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_character_visual_visible(visible_value: bool) -> void:
	if _robot_visual_root:
		_robot_visual_root.visible = visible_value and character_model_id == CharacterSkinCatalog.DEFAULT_ID
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_active_skin_node.visible = visible_value and character_model_id != CharacterSkinCatalog.DEFAULT_ID


func _build_prop_disguise_node(preset: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.position = preset.get("offset", Vector3.ZERO)
	holder.rotation = preset.get("rotation", Vector3.ZERO)
	var mesh_type := str(preset.get("mesh", "box"))
	if mesh_type == "scene":
		var scene_path := str(preset.get("scene_path", ""))
		var scene := load(scene_path)
		if scene is PackedScene:
			var scene_node := (scene as PackedScene).instantiate() as Node3D
			if scene_node:
				scene_node.name = "ScenePropVisual"
				scene_node.scale = preset.get("scale", Vector3.ONE)
				holder.add_child(scene_node)
				_apply_scene_prop_material(scene_node, str(preset.get("material_path", "")))
				_disable_prop_collisions(scene_node)
		return holder
	match mesh_type:
		"cactus":
			_add_prop_mesh(holder, "cylinder", Vector3(0.38, 1.7, 0.38), Vector3(0, 0, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "sphere", Vector3(0.42, 0.42, 0.42), Vector3(0, 0.82, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.72, 0.18), Vector3(0.36, 0.24, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.62, 0.18), Vector3(-0.33, 0.08, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
		_:
			_add_prop_mesh(holder, mesh_type, preset.get("size", Vector3.ONE), Vector3.ZERO, preset.get("color", Color.WHITE))
	return holder


func _add_prop_mesh(parent: Node3D, mesh_type: String, mesh_size: Vector3, local_pos: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = local_pos
	mesh_instance.rotation = local_rot
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	match mesh_type:
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			mesh_instance.mesh = sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			mesh_instance.mesh = cylinder
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh_instance.mesh = box
	mesh_instance.scale = mesh_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = 0.18 if mesh_type == "cylinder" else 0.0
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _disable_prop_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_prop_collisions(child)


func _apply_scene_prop_material(node: Node, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material_resource := load(material_path)
	if not material_resource is Material:
		return
	_apply_material_to_unassigned_prop_meshes(node, material_resource as Material)


func _apply_material_to_unassigned_prop_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not _prop_mesh_has_material(mesh_instance):
			mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_to_unassigned_prop_meshes(child, material)


func _prop_mesh_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override:
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if mesh_instance.get_surface_override_material(i):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(i):
				return true
	return false


func _apply_body_rotation(move_velocity: Vector3) -> void:
	if _body and _body.has_method("apply_rotation"):
		_body.apply_rotation(move_velocity)


func _animate_body(move_velocity: Vector3) -> void:
	if _active_skin_node:
		if not is_on_floor():
			_play_skin_action("fall" if move_velocity.y < 0.0 else "jump")
		elif Vector2(move_velocity.x, move_velocity.z).length_squared() > 0.01:
			_play_skin_action("move")
		else:
			_play_skin_action("idle")
		return

	if _body and _body.has_method("animate"):
		_body.animate(move_velocity)


func _play_body_jump(jump_type: String = "Jump") -> void:
	_play_audio(_jump_audio)
	if _active_skin_node:
		_play_skin_action("jump")
	elif _body and _body.has_method("play_jump_animation"):
		_body.play_jump_animation(jump_type)


func _setup_player_audio() -> void:
	_jump_audio = _make_audio_player("JumpAudio", "res://assets/audio/player/robot_jump.wav", -7.0)
	_land_audio = _make_audio_player("LandAudio", "res://assets/audio/player/robot_land.wav", -5.0)
	_step_audio = _make_audio_player("StepAudio", "", -12.0)
	_disguise_audio = _make_audio_player("DisguiseAudio", "res://assets/audio/player/prop_disguise.wav", -3.5, 30.0)
	_step_sounds.clear()
	for path in [
		"res://assets/audio/player/robot_step_01.wav",
		"res://assets/audio/player/robot_step_02.wav",
		"res://assets/audio/player/robot_step_03.wav",
		"res://assets/audio/player/robot_step_04.wav",
		"res://assets/audio/player/robot_step_05.wav",
	]:
		var stream := load(path)
		if stream is AudioStream:
			_step_sounds.append(stream)


func _make_audio_player(node_name: String, stream_path: String, volume_db: float, max_distance: float = 22.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if not stream_path.is_empty():
		var stream := load(stream_path)
		if stream is AudioStream:
			player.stream = stream
	add_child(player)
	return player


func _update_movement_audio(delta: float, was_on_floor: bool) -> void:
	if is_on_floor() and not was_on_floor:
		_play_audio(_land_audio)
		_footstep_timer = 0.0

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > FOOTSTEP_MIN_SPEED:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_play_step_audio()
			_footstep_timer = FOOTSTEP_SPRINT_INTERVAL if Input.is_action_pressed("shift") else FOOTSTEP_WALK_INTERVAL
	else:
		_footstep_timer = 0.0


func _play_step_audio() -> void:
	if not _step_audio or _step_sounds.is_empty():
		return
	_step_audio.stream = _step_sounds.pick_random()
	_play_audio(_step_audio)


func _play_audio(player: AudioStreamPlayer3D) -> void:
	if not player or not player.stream:
		return
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()


func _play_skin_action(action: String) -> void:
	if not _active_skin_node:
		return

	match action:
		"move":
			if _active_skin_node.has_method("set_walk_run_blending"):
				_active_skin_node.call("set_walk_run_blending", 1.0 if Input.is_action_pressed("shift") else 0.25)
			if _active_skin_node.has_method("move"):
				_active_skin_node.call("move")
			elif _active_skin_node.has_method("run"):
				_active_skin_node.call("run")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		"jump":
			if _active_skin_node.has_method("jump"):
				_active_skin_node.call("jump")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		"fall":
			if _active_skin_node.has_method("fall"):
				_active_skin_node.call("fall")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		_:
			if _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")


func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

# Inventory Network Functions - Server authoritative, client-specific
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	print("Debug: request_inventory_sync called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to request inventory for player " + str(get_multiplayer_authority()))
		return

	if player_inventory:
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	print("Debug: sync_inventory_to_owner called on player ", name, " (authority: ", get_multiplayer_authority(), ") - local unique id: ", multiplayer.get_unique_id(), " from: ", multiplayer.get_remote_sender_id())

	if multiplayer.get_remote_sender_id() != 1:
		return

	if not is_multiplayer_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if level_scene:
		if is_multiplayer_authority() or get_multiplayer_authority() == multiplayer.get_unique_id():
			print("Debug: This is the local player, updating UI")
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					print("Debug: Calling refresh_display directly on InventoryUI")
					inventory_ui.refresh_display()
		else:
			print("Debug: Not the local player, skipping UI update")

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	print("Debug: request_move_item called - from:", from_slot, " to:", to_slot, " on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to modify inventory for player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if from_slot < 0 or from_slot >= PlayerInventory.INVENTORY_SIZE or to_slot < 0 or to_slot >= PlayerInventory.INVENTORY_SIZE:
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
			print("Debug: Swapped items between slots ", from_slot, " and ", to_slot)
		else:
			print("Debug: Moved item from slot ", from_slot, " to ", to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
		print("Debug: Moved ", quantity, " items from slot ", from_slot, " to ", to_slot)

	if success:
		print("Debug: Move successful, syncing inventory to owner ", get_multiplayer_authority())
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
	else:
		print("Debug: Move/swap failed")

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	print("Debug: request_add_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:
		push_warning("Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining
	print("Debug: Added ", added, " ", item_id, " to inventory (", remaining, " remaining)")

	if added > 0:
		var owner_id = get_multiplayer_authority()
		print("Debug: Syncing inventory to owner ", owner_id)
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	print("Debug: request_remove_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to remove items from player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func get_health() -> float:
	return health

func _add_starting_items():
	if not player_inventory:
		return

	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")

	if sword:
		player_inventory.add_item(sword, 1)
	if potion:
		player_inventory.add_item(potion, 3)


# =============================================================================
# 鎴樻枟绯荤粺(琚?WeaponSystem 璋冪敤)
# =============================================================================

# 鏈嶅姟鍣ㄤ晶:鐜╁鍙楀埌浼ゅ
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, attacker_id: int, is_headshot: bool = false):
	if not multiplayer.is_server():
		return

	print("[Combat] Player ", name, " took ", amount, "% damage from ",
		attacker_id, " (headshot=", is_headshot, ")")

	health = max(0.0, health - amount)
	_sync_health.rpc(health)

	if health <= 0.0:
		_server_die(attacker_id)


func _server_die(killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Combat] Player ", name, " killed by ", killer_id)

	# 骞挎挱姝讳骸
	_broadcast_death.rpc(killer_id)

	# 绠€鍖栫殑姝讳骸澶勭悊:5s 鍚庨噸鐢?
	await get_tree().create_timer(5.0).timeout
	if multiplayer.is_server() and is_instance_valid(self):
		health = 100.0
		_sync_health.rpc(health)
		# 閲嶇疆浣嶇疆
		var level = get_tree().get_current_scene()
		if level and level.has_method("get_spawn_point_for_role"):
			var role = Network.players.get(int(name), {}).get("role", Network.Role.NONE)
			global_position = level.get_spawn_point_for_role(role, int(name))


@rpc("authority", "call_local", "reliable")
func _broadcast_death(killer_id: int):
	print("[Combat] ", name, " was killed by ", killer_id)
	clear_prop_disguise()
	# TODO: 瑙﹀彂姝讳骸鍔ㄧ敾 + UI


@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float):
	health = new_health
	health_changed.emit(health)


# 鏈嶅姟鍣ㄤ晶:澶撮儴鍒ゅ畾(绠€鍖?鐢ㄧ鎾炰綅缃?vs 澶撮儴楂樺害)
func is_head_shot() -> bool:
	# 绠€鍖?浠讳綍鍑讳腑澶撮儴楂樺害鐨勫皠绾胯涓虹垎澶?
	# 鐪熷疄瀹炵幇:raycast 鍛戒腑鐐?y 鍧愭爣 vs 瑙掕壊澶撮儴 y 鍧愭爣
	return false  # TODO: 瀹炵幇绮剧‘鐖嗗ご鍒ゅ畾
