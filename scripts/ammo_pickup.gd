extends Area3D
class_name AmmoPickup
# =============================================================================
# AmmoPickup — 弹药包(v0.3.3)
#
# 设计:
#   - 4 种类型:小(+30) / 中(+60) / 大(填满) / 特殊(占位)
#   - Hunter 走近 1m 自动拾取(服务端权威)
#   - Prop 不可拾取(v0.3.3 默认)
#   - 拾取后 30s 重置
# =============================================================================

# -----------------------------------------------------------------------------
# 配置
# -----------------------------------------------------------------------------
enum AmmoType {
	SMALL,      # +30 发
	MEDIUM,     # +60 发
	LARGE,      # 填满到 120
	SPECIAL     # 特殊(穿甲/追踪/爆破,后续扩展)
}

const AMMO_AMOUNTS := {
	AmmoType.SMALL: 30,
	AmmoType.MEDIUM: 60,
	AmmoType.LARGE: 120,  # 表示填满
	AmmoType.SPECIAL: 0   # 特殊类型,占位
}

const AMMO_COLORS := {
	AmmoType.SMALL: Color(0.7, 0.7, 0.7, 1),    # 灰色
	AmmoType.MEDIUM: Color(0.3, 0.6, 1.0, 1),   # 蓝色
	AmmoType.LARGE: Color(1.0, 0.5, 0.0, 1),    # 橙色
	AmmoType.SPECIAL: Color(1.0, 0.2, 0.8, 1)   # 紫色
}

const AMMO_LABELS := {
	AmmoType.SMALL: "+30",
	AmmoType.MEDIUM: "+60",
	AmmoType.LARGE: "MAX",
	AmmoType.SPECIAL: "?"
}

const PICKUP_RANGE: float = 1.5
const RESPAWN_TIME: float = 30.0

const AMMO_VISUAL_SCENES := {
	AmmoType.SMALL: "res://assets/pickups/ammo_boxes/small_ammo_box_30.glb",
	AmmoType.MEDIUM: "res://assets/pickups/ammo_boxes/medium_ammo_crate_60.glb",
	AmmoType.LARGE: "res://assets/pickups/ammo_boxes/large_ammo_supply_box_120.glb",
	AmmoType.SPECIAL: "res://assets/pickups/ammo_boxes/special_ammo_cache.glb",
}
const AMMO_VISUAL_SCALES := {
	AmmoType.SMALL: Vector3(0.42, 0.42, 0.42),
	AmmoType.MEDIUM: Vector3(0.42, 0.42, 0.42),
	AmmoType.LARGE: Vector3(0.42, 0.42, 0.42),
	AmmoType.SPECIAL: Vector3(0.42, 0.42, 0.42),
}
const AMMO_COLLISION_RADII := {
	AmmoType.SMALL: 0.8,
	AmmoType.MEDIUM: 0.8,
	AmmoType.LARGE: 0.8,
	AmmoType.SPECIAL: 0.8,
}
const AMMO_LABEL_HEIGHTS := {
	AmmoType.SMALL: 0.8,
	AmmoType.MEDIUM: 0.8,
	AmmoType.LARGE: 0.8,
	AmmoType.SPECIAL: 0.8,
}

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
@export var ammo_type: AmmoType = AmmoType.SMALL
var is_available: bool = true  # 是否可被拾取
var respawn_timer: float = 0.0

# 视觉节点
@onready var mesh_instance: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var label_instance: Label3D = get_node_or_null("Label") as Label3D


static func visual_scene_path_for_type(type: int) -> String:
	return str(AMMO_VISUAL_SCENES.get(type, AMMO_VISUAL_SCENES[AmmoType.SMALL]))


static func visual_scale_for_type(type: int) -> Vector3:
	var scale_value: Variant = AMMO_VISUAL_SCALES.get(type, AMMO_VISUAL_SCALES[AmmoType.SMALL])
	if scale_value is Vector3:
		return scale_value as Vector3
	return AMMO_VISUAL_SCALES[AmmoType.SMALL] as Vector3


static func collision_radius_for_type(type: int) -> float:
	return float(AMMO_COLLISION_RADII.get(type, AMMO_COLLISION_RADII[AmmoType.SMALL]))


static func label_height_for_type(type: int) -> float:
	return float(AMMO_LABEL_HEIGHTS.get(type, AMMO_LABEL_HEIGHTS[AmmoType.SMALL]))


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	add_to_group("ammo_pickups")
	_apply_visual()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not is_available:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()


# =============================================================================
# 视觉
# =============================================================================

func _apply_visual() -> void:
	var color = AMMO_COLORS.get(ammo_type, Color.WHITE)
	if mesh_instance and mesh_instance.get_surface_override_material(0) is StandardMaterial3D:
		var mat = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5

	if label_instance:
		label_instance.text = AMMO_LABELS.get(ammo_type, "?")
		label_instance.outline_modulate = color


# =============================================================================
# 拾取逻辑
# =============================================================================

func _on_body_entered(body: Node) -> void:
	if not is_available:
		return
	if not body.is_in_group("players"):
		return

	if not multiplayer.is_server():
		# 客户端触发,转发给服务器
		_request_pickup_rpc.rpc_id(1)
		return

	if body.has_method("get_multiplayer_authority"):
		var pid = body.get_multiplayer_authority()
		_server_try_pickup_by_id(pid)


@rpc("any_peer", "call_local", "reliable")
func _request_pickup_rpc():
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_server_try_pickup_by_id(sender_id)


func _server_try_pickup(body: Node) -> void:
	# body 可能是玩家节点
	if body and body.has_method("get_multiplayer_authority"):
		var pid = body.get_multiplayer_authority()
		_server_try_pickup_by_id(pid)


func _server_try_pickup_by_id(pid: int) -> void:
	# v0.3.3 默认:Prop 不可拾取
	if not Network.players.has(pid):
		return
	var info = Network.players[pid]
	var role = info.get("role", Network.Role.NONE)
	if role != Network.Role.HUNTER:
		# Chameleon / Stalker 不能拾取弹药
		return

	# 找到 Hunter 的 WeaponSystem — 用全局 scene tree
	var tree = get_tree()
	if not tree:
		return
	var level = tree.get_current_scene() if tree.get_current_scene() else null
	if not level:
		return

	var players_container = level.get_node_or_null("PlayersContainer")
	if not players_container:
		return

	var player_node = players_container.get_node_or_null(str(pid))
	if not player_node or not player_node.has_node("WeaponSystem"):
		return
	var weapon: WeaponSystem = player_node.get_node("WeaponSystem")

	if ammo_type == AmmoType.LARGE:
		# 大弹药包:填满到 120
		var needed = WeaponSystem.MAX_TOTAL_AMMO - weapon.total_ammo
		if needed <= 0:
			return  # 弹药已满
		weapon.server_add_ammo(needed)
	elif ammo_type == AmmoType.SMALL or ammo_type == AmmoType.MEDIUM:
		var amount = AMMO_AMOUNTS.get(ammo_type, 30)
		weapon.server_add_ammo(amount)
	elif ammo_type == AmmoType.SPECIAL:
		# TODO: 后续扩展
		pass

	print("[Ammo] Hunter ", pid, " picked up ", ammo_type, " (+", AMMO_AMOUNTS.get(ammo_type, 0), ")")

	# 隐藏 + 计时重置
	_consume()


func _consume() -> void:
	if not multiplayer.is_server():
		return
	_set_available.rpc(false, RESPAWN_TIME)


func _respawn() -> void:
	if not multiplayer.is_server():
		return
	_set_available.rpc(true, 0.0)
	print("[Ammo] ", ammo_type, " respawned at ", global_position)


@rpc("authority", "call_local", "reliable")
func _set_available(available: bool, timer_value: float) -> void:
	is_available = available
	respawn_timer = timer_value
	visible = available
	set_deferred("monitoring", available)
	set_deferred("monitorable", available)
	_set_collision_shapes_enabled(available)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not enabled)


# =============================================================================
# 工具
# =============================================================================

func setup(type: AmmoType) -> void:
	ammo_type = type
	if is_inside_tree():
		_apply_visual()
