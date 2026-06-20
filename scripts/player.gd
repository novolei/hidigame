extends CharacterBody3D
class_name Character

# =============================================================================
# Character — Prop Hunt 玩家类(v0.3.3)
#
# 角色系统:
#   - 通过 Network.Role 枚举识别角色
#   - 准备阶段:Hunter 被锁定,不能移动
#   - 战斗阶段:所有角色按各自逻辑运作
# =============================================================================

const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10

enum SkinColor { BLUE, YELLOW, GREEN, RED }

# -----------------------------------------------------------------------------
# 角色(从 Network 同步过来)
# -----------------------------------------------------------------------------
var role: int = Network.Role.NONE

# 准备阶段锁定状态(server 控制)
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

	# 从 Network 同步角色
	_sync_role_from_network()

	# 监听角色变化
	if Network.player_role_changed.connect(_on_role_changed) != OK:
		pass  # 已连接

	print("Debug: Player ", name, " ready - authority: ", get_multiplayer_authority(),
		", local client: ", local_client_id, ", is_local: ", is_local_player,
		", role: ", Network.role_to_string(role))

	# Hunter 玩家:本地端负责输入/视觉,服务器端负责权威弹药/命中状态。
	if is_hunter() and (is_local_player or multiplayer.is_server()):
		_setup_hunter_weapon()
	else:
		# 角色后分配,延后挂载
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
# 藏匿者系统初始化(PoC-3)
# =============================================================================

var paint_system: PaintSystem = null
var shape_system: ShapeShiftSystem = null

func _setup_chameleon_systems() -> void:
	if not is_chameleon() or not is_multiplayer_authority():
		return

	# 喷涂系统
	if not has_node("PaintSystem"):
		var ps = preload("res://scripts/paint_system.gd").new()
		ps.name = "PaintSystem"
		add_child(ps)
		var cam = $SpringArmOffset/SpringArm3D/Camera3D
		ps.initialize(self, cam)
		paint_system = ps

	# 变形系统
	if not has_node("ShapeShiftSystem"):
		var ss = preload("res://scripts/shape_shift_system.gd").new()
		ss.name = "ShapeShiftSystem"
		add_child(ss)
		ss.initialize(self)
		shape_system = ss

	print("[Player] Chameleon systems initialized")


# =============================================================================
# Hunter 武器初始化
# =============================================================================

func _setup_hunter_weapon() -> void:
	var is_local_player = is_multiplayer_authority()
	var camera = $SpringArmOffset/SpringArm3D/Camera3D

	# 加载 AK47 模型(仅本地视觉)
	if is_local_player:
		var ak47_scene = preload("res://scenes/weapons/ak47.tscn")
		if not camera.has_node("WeaponVisual"):
			var visual = ak47_scene.instantiate()
			visual.name = "WeaponVisual"
			# 挂在 Camera3D 下,作为本地第一/三人称视觉
			camera.add_child(visual)
			visual.position = Vector3(0.3, -0.3, -0.5)
			visual.rotation = Vector3(0, 0, 0)

	# 加载 WeaponSystem(网络权威)
	if not has_node("WeaponSystem"):
		var weapon = preload("res://scripts/weapon_system.gd").new()
		weapon.name = "WeaponSystem"
		add_child(weapon)
		weapon.initialize(self, camera if is_local_player else null)

	# 注册弹药变化信号
	var weapon = get_node_or_null("WeaponSystem")
	if weapon:
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)


func _on_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	# TODO: 更新 HUD 弹药显示
	pass


# =============================================================================
# Hunter 输入处理
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Hunter 输入
	if is_hunter():
		_handle_hunter_input(event)

	# Chameleon 输入
	if is_chameleon():
		_handle_chameleon_input(event)


func _handle_hunter_input(event: InputEvent) -> void:
	# 准备阶段锁定不能开枪
	if prep_phase_locked:
		return

	var weapon = get_node_or_null("WeaponSystem")
	if not weapon:
		return

	# 开火
	if event.is_action_pressed("shoot"):
		weapon.request_fire()
	# 换弹
	if event.is_action_pressed("reload"):
		weapon.request_reload()


func _handle_chameleon_input(event: InputEvent) -> void:
	if not paint_system or not shape_system:
		return

	# 喷涂:右键按住(在 _process_input_held 中持续检测)
	if event.is_action_pressed("paint_trigger"):
		paint_system.start_paint()

	# 变形轮盘:Q 切换开/关
	if event.is_action_pressed("shape_shift"):
		var wheel = _get_shape_wheel()
		if wheel:
			if wheel.visible:
				wheel.hide_wheel()
			else:
				wheel.show_wheel(shape_system)
				# 锁住角色移动
				shape_system.open_wheel()


func _process_input_held():
	# 在 _process 中持续检测 shoot / paint 按住状态
	if not is_multiplayer_authority():
		return

	# Hunter 持续开火
	if is_hunter():
		if prep_phase_locked:
			return
		var weapon = get_node_or_null("WeaponSystem")
		if weapon and Input.is_action_pressed("shoot"):
			weapon.request_fire()

	# Chameleon 持续喷涂
	if is_chameleon():
		if paint_system and Input.is_action_pressed("paint_trigger"):
			if not paint_system.is_painting:
				paint_system.start_paint()
		elif paint_system and paint_system.is_painting:
			paint_system.stop_paint()


# 查找 level 中的变形轮盘 UI
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


func _on_role_changed(peer_id: int, new_role: int) -> void:
	if peer_id == str(name).to_int():
		role = new_role
		print("[Player ", name, "] Role updated to ", Network.role_to_string(new_role))
		# 如果是 Hunter 且还没挂武器,补挂
		if new_role == Network.Role.HUNTER and (is_multiplayer_authority() or multiplayer.is_server()) and not has_node("WeaponSystem"):
			_setup_hunter_weapon()
		elif new_role == Network.Role.CHAMELEON and is_multiplayer_authority() and not has_node("PaintSystem"):
			_setup_chameleon_systems()


# =============================================================================
# 角色 helper
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
# 准备阶段锁定(服务器控制,Hunter 不能移动)
# =============================================================================
func set_prep_locked(locked: bool) -> void:
	prep_phase_locked = locked
	if locked:
		# 停止任何移动
		velocity = Vector3.ZERO
		_current_speed = 0.0
		# 视觉提示(3D 节点没有 modulate,改用 mesh material albedo_color)
		_set_player_tint(Color(0.5, 0.5, 0.5))
	else:
		_set_player_tint(Color(1, 1, 1))


func _set_player_tint(color: Color) -> void:
	# 遍历所有 MeshInstance3D,改 albedo_color(3D 版 modulate)
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

	# 准备阶段 Hunter 锁定(不能移动)
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

	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_body.play_jump_animation("Jump")
	else:
		velocity.y -= gravity * delta

		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_body.play_jump_animation("Jump2")

	velocity.y -= gravity * delta

	_move()
	move_and_slide()
	_body.animate(velocity)

func _process(_delta):
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()
	# Hunter 持续开火检测
	_process_input_held()

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)

func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_backward"
			)

	var _direction: Vector3 = transform.basis * Vector3(_input_direction.x, 0, _input_direction.y).normalized()

	is_running()
	_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		_body.apply_rotation(velocity)
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)

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
# 战斗系统(被 WeaponSystem 调用)
# =============================================================================

# 服务器侧:玩家受到伤害
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

	# 广播死亡
	_broadcast_death.rpc(killer_id)

	# 简化的死亡处理:5s 后重生
	await get_tree().create_timer(5.0).timeout
	if multiplayer.is_server() and is_instance_valid(self):
		health = 100.0
		_sync_health.rpc(health)
		# 重置位置
		var level = get_tree().get_current_scene()
		if level and level.has_method("get_spawn_point_for_role"):
			var role = Network.players.get(int(name), {}).get("role", Network.Role.NONE)
			global_position = level.get_spawn_point_for_role(role, int(name))


@rpc("authority", "call_local", "reliable")
func _broadcast_death(killer_id: int):
	print("[Combat] ", name, " was killed by ", killer_id)
	# TODO: 触发死亡动画 + UI


@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float):
	health = new_health
	health_changed.emit(health)


# 服务器侧:头部判定(简化:用碰撞位置 vs 头部高度)
func is_head_shot() -> bool:
	# 简化:任何击中头部高度的射线视为爆头
	# 真实实现:raycast 命中点 y 坐标 vs 角色头部 y 坐标
	return false  # TODO: 实现精确爆头判定
