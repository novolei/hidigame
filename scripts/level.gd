extends Node3D
# =============================================================================
# Level — Prop Hunt 主场景管理器(v0.3.3)
#
# 状态机:
#   LOBBY → 等待玩家加入 → 玩家选职业
#   PREP   → 120s 倒计时,Hunter 在准备室,Props 在战场
#   PLAY   → 比赛开始,Hunter 解锁,所有人进入主战场
#   END    → 胜负结算
# =============================================================================

# -----------------------------------------------------------------------------
# 节点引用
# -----------------------------------------------------------------------------
@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: MainMenuUI = $MainMenuUI
@export var player_scene: PackedScene

@onready var multiplayer_chat: MultiplayerChatUI = $MultiplayerChatUI
@onready var inventory_ui: InventoryUI = $InventoryUI

# 准备室节点(新增 v0.3.3 — TASK-1.3 实施时创建)
@onready var preparation_room: Node3D = $PreparationRoom if has_node("PreparationRoom") else null

# 准备阶段倒计时 HUD(在 CanvasLayer 下,确保最上层渲染)
@onready var prep_timer_label: Label = $HUDCanvas/PrepTimerLabel if has_node("HUDCanvas/PrepTimerLabel") else null
var status_label: Label = null

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
enum GameState {
	LOBBY,        # 玩家加入 + 选职业
	PREP,         # 120s 准备阶段
	PLAY,         # 比赛阶段
	END           # 结算
}

var game_state: GameState = GameState.LOBBY
var chat_visible = false
var inventory_visible = false

# 准备阶段倒计时
var prep_timer: Timer = null
var prep_remaining: float = 0.0

# 比赛阶段倒计时
var match_timer: Timer = null
var match_remaining: float = 0.0

# -----------------------------------------------------------------------------
# Spawn 位置配置
# -----------------------------------------------------------------------------
const PROP_SPAWN_RADIUS: float = 10.0      # 主战场 Prop 出生半径
const HUNTER_SPAWN_RADIUS: float = 5.0     # 准备室 Hunter 出生半径
const HUNTER_ROOM_OFFSET: Vector3 = Vector3(0, 0, -80)  # 准备室相对主战场偏移

# 弹药包散落配置(v0.3.3)
const AMMO_PACK_COUNT_SMALL_8: int = 8
const AMMO_PACK_COUNT_MEDIUM_8: int = 4
const AMMO_PACK_COUNT_LARGE_8: int = 2
const AMMO_PACK_COUNT_SMALL_24: int = 22
const AMMO_PACK_COUNT_MEDIUM_24: int = 12
const AMMO_PACK_COUNT_LARGE_24: int = 5
const AMMO_PACK_MAP_RADIUS: float = 35.0  # 弹药包散落半径

# -----------------------------------------------------------------------------
# 生命周期
# -----------------------------------------------------------------------------
func _ready():
	if DisplayServer.get_name() == "headless":
		print("Dedicated server starting...")
		Network.start_host("", "")

	multiplayer_chat.hide()
	multiplayer_chat.set_process_input(true)
	main_menu.show_menu()

	main_menu.host_pressed.connect(_on_host_pressed)
	main_menu.join_pressed.connect(_on_join_pressed)
	main_menu.start_match_pressed.connect(_on_start_match_pressed)
	main_menu.auto_assign_pressed.connect(_on_auto_assign_pressed)
	main_menu.config_changed.connect(_on_lobby_config_changed)
	main_menu.lobby_chat_message_sent.connect(_on_lobby_chat_message_sent)
	main_menu.quit_pressed.connect(_on_quit_pressed)

	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	# 服务器逻辑
	if multiplayer.is_server():
		Network.player_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_remove_player)
		Network.roles_assigned.connect(_on_roles_assigned)

	Network.player_connected.connect(_refresh_lobby_ui)
	Network.player_disconnected.connect(func(_pid): _refresh_lobby_ui())
	Network.server_disconnected.connect(_on_server_disconnected)
	Network.lobby_config_updated.connect(func(_config): _refresh_lobby_ui())
	Network.start_match_requested.connect(_server_start_from_lobby)

	# 客户端也监听角色变化(用于 UI 更新)
	Network.player_role_changed.connect(_on_player_role_changed)

	# 监听准备阶段信号
	Network.prep_phase_started.connect(_on_prep_phase_started)
	Network.prep_phase_ended.connect(_on_prep_phase_ended)
	Network.match_started.connect(_on_match_started)
	I18n.locale_changed.connect(func(_locale): _update_status_hud())

	# 准备室位置偏移(关键:避免与主地图地板重合)
	if preparation_room:
		preparation_room.position = HUNTER_ROOM_OFFSET
		_set_preparation_gate_open(false)

	_ensure_status_hud()

	# Debug: 确认 HUD 节点找到
	print("[Level] _ready: prep_timer_label = ", prep_timer_label, " HUDCanvas found = ", has_node("HUDCanvas"))


func _process(delta):
	# 更新倒计时显示(任何状态)
	if game_state == GameState.PREP:
		prep_remaining = max(0.0, prep_remaining - delta)
		_update_prep_ui()
		if multiplayer.is_server() and prep_remaining <= 0.0:
			_server_end_prep_phase()
	elif game_state == GameState.PLAY:
		match_remaining = max(0.0, match_remaining - delta)
		if multiplayer.is_server() and match_remaining <= 0.0:
			_server_end_match()
	_update_status_hud()


# -----------------------------------------------------------------------------
# 主菜单回调
# -----------------------------------------------------------------------------
func _on_host_pressed(nickname: String, skin: String, role: int):
	var error = Network.start_host(nickname, skin, role)
	if error:
		push_warning("Could not host lobby. ENet error: " + str(error))
		return
	main_menu.show_lobby(str(Network.lobby_config.get("lobby_id", "")), true)
	_set_hud_visible(false)
	_refresh_lobby_ui()


func _on_join_pressed(nickname: String, skin: String, address: String, lobby_id: String, role: int):
	var error = Network.join_game(nickname, skin, address, lobby_id, role)
	if error:
		push_warning("Could not join lobby. ENet error: " + str(error))
		return
	main_menu.show_lobby(lobby_id.strip_edges().to_upper(), false)
	_set_hud_visible(false)
	_refresh_lobby_ui()


func _on_server_disconnected() -> void:
	if game_state == GameState.LOBBY and main_menu:
		main_menu.show_landing()
		main_menu.show_menu()
		_set_hud_visible(false)


func _hide_menu_after_spawn() -> void:
	# 等 2 帧确保 player 节点完成 add_child + _ready
	await get_tree().process_frame
	await get_tree().process_frame
	if main_menu and is_instance_valid(main_menu):
		main_menu.hide_menu()


func _refresh_lobby_ui(_peer_id = null, _info = null) -> void:
	if main_menu and main_menu.is_menu_visible():
		_set_hud_visible(false)
		main_menu.update_lobby(Network.players, Network.lobby_config)


# -----------------------------------------------------------------------------
# 服务器:玩家连接 / 角色 / spawn
# -----------------------------------------------------------------------------
func _on_player_connected(peer_id, player_info):
	if multiplayer.is_server():
		_add_player(peer_id, player_info)
		_refresh_lobby_ui()


func _on_player_role_changed(peer_id: int, new_role: int):
	# 所有端都响应(server + client)
	var player_node = players_container.get_node_or_null(str(peer_id))
	if player_node and player_node.has_method("_sync_role_from_network"):
		player_node._sync_role_from_network()
	# 立即 reposition(关键修复:之前只在 server 端 reposition,client 端不动)
	_try_reposition_player(peer_id)
	_refresh_lobby_ui()


func _on_roles_assigned():
	# 所有端都 reposition(角色分配完成后统一处理)
	print("[Level] Roles assigned, repositioning all players")
	for pid in Network.players.keys():
		_try_reposition_player(pid)
	_refresh_lobby_ui()


func _add_player(id: int, player_info: Dictionary):
	if DisplayServer.get_name() == "headless" and id == 1:
		return

	if players_container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point_for_role(Network.players[id].get("role", Network.Role.NONE), id)
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.nickname.text = nick

	var skin_enum = player_info["skin"]
	player.set_player_skin(skin_enum)

	# 立即尝试按角色定位(角色已分配的情况)
	# 客户端可能在节点 spawn 时还不知道角色(role=NONE),后续通过 _on_player_role_changed 再次定位
	_try_reposition_player(id)


func _try_reposition_player(pid: int) -> bool:
	"""按角色把 player 放到正确位置。所有端都生效(server + client)"""
	if not players_container.has_node(str(pid)):
		return false
	var player_node = players_container.get_node(str(pid))
	var info = Network.players.get(pid, {})
	var role = info.get("role", Network.Role.NONE)

	# 角色未分配,不做 reposition
	if role == Network.Role.NONE:
		return false

	var new_pos = get_spawn_point_for_role(role, pid)
	player_node.global_position = new_pos

	# Hunter 在 PREP 阶段锁定
	if role == Network.Role.HUNTER and game_state == GameState.PREP:
		if player_node.has_method("set_prep_locked"):
			player_node.set_prep_locked(true)
	elif role == Network.Role.HUNTER and player_node.has_method("set_prep_locked"):
		player_node.set_prep_locked(false)

	print("[Level] Reposition player ", pid, " to role=", Network.role_to_string(role), " pos=", new_pos)
	return true


func _reposition_player_by_role(pid: int):
	# 已废弃,使用 _try_reposition_player
	_try_reposition_player(pid)


func get_spawn_point_for_role(role: int, pid: int) -> Vector3:
	match role:
		Network.Role.HUNTER:
			# 准备室位置(相对于主战场)
			var slot = pid % 8  # 8 个 Hunter 出生点
			var angle = slot * (TAU / 8.0)
			return HUNTER_ROOM_OFFSET + Vector3(cos(angle) * HUNTER_SPAWN_RADIUS, 0, sin(angle) * HUNTER_SPAWN_RADIUS)
		Network.Role.CHAMELEON, Network.Role.STALKER:
			# 主战场出生区
			var angle = randf() * TAU
			return Vector3(cos(angle) * PROP_SPAWN_RADIUS, 0, sin(angle) * PROP_SPAWN_RADIUS)
		_:
			# 未分配角色:暂时放主战场中心
			return Vector3.ZERO


func get_spawn_point() -> Vector3:
	# 兼容原模板接口
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10
	return Vector3(spawn_point.x, 0, spawn_point.y)


func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()


func _on_quit_pressed() -> void:
	get_tree().quit()


# =============================================================================
# 准备阶段管理(服务器)
# =============================================================================

func _server_schedule_prep_phase() -> void:
	if not multiplayer.is_server():
		return
	if game_state != GameState.LOBBY:
		return

	# 5s 缓冲(等所有玩家就绪)
	await get_tree().create_timer(5.0).timeout

	# v0.3.3 修复:允许单人 host 也能触发 prep phase(用于开发测试)
	# 多人时 (>1) 走正常流程,单人时 (==1) 走开发模式
	if Network.players.size() < 1:
		print("[Level] No players, aborting prep phase")
		return
	if Network.players.size() == 1:
		print("[Level] Single player mode — proceeding with 1 player (dev test)")

	# 执行 1:3 自动分配
	Network.server_auto_balance_roles(true)
	# 等角色分配广播
	await get_tree().process_frame

	# 进入准备阶段
	_server_start_prep_phase()


func _on_lobby_config_changed(config: Dictionary) -> void:
	if multiplayer.is_server():
		Network.request_update_lobby_config(config)


func _on_auto_assign_pressed(config: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	Network.request_update_lobby_config(config)
	await get_tree().process_frame
	Network.server_auto_balance_roles(false)
	_refresh_lobby_ui()


func _on_start_match_pressed(config: Dictionary) -> void:
	if multiplayer.is_server():
		Network.request_update_lobby_config(config)
		await get_tree().process_frame
		_server_start_from_lobby()
	else:
		Network.request_start_match()


func _server_start_from_lobby() -> void:
	if not multiplayer.is_server():
		return
	if game_state != GameState.LOBBY:
		return
	if Network.players.size() < 2:
		print("[Level] Need at least 2 players to start from lobby")
		return
	Network.server_auto_balance_roles(true)
	await get_tree().process_frame
	main_menu.hide_menu()
	_server_start_prep_phase()


func _server_start_prep_phase() -> void:
	game_state = GameState.PREP
	prep_remaining = float(Network.lobby_config.get("prep_duration_sec", 120))
	_set_preparation_gate_open(false)
	print("[Level] SERVER: prep phase starting, remaining: ", prep_remaining, "s, hunters=", Network.get_hunters().size(), " props=", Network.get_props().size())

	# 锁定所有 Hunter
	for pid in Network.get_hunters():
		if players_container.has_node(str(pid)):
			var p = players_container.get_node(str(pid))
			if p.has_method("set_prep_locked"):
				p.set_prep_locked(true)
			# 移动到准备室位置
			p.global_position = get_spawn_point_for_role(Network.Role.HUNTER, pid)

	# 在 server 本地立即更新 HUD
	print("[Level] SERVER: prep_timer_label = ", prep_timer_label)
	if prep_timer_label:
		prep_timer_label.visible = true
		_update_prep_ui()
		print("[Level] SERVER: PrepTimerLabel shown, text=", prep_timer_label.text)

	print("[Level] Prep phase started, remaining: ", prep_remaining, "s")
	Network.server_broadcast_prep_started(prep_remaining)


func _server_end_prep_phase() -> void:
	game_state = GameState.PLAY
	prep_remaining = 0.0
	_set_preparation_gate_open(true)

	# 解锁所有 Hunter,移动到主战场入口
	var entrance_offset = Vector3(0, 0, 30)  # 主战场入口
	for pid in Network.get_hunters():
		if players_container.has_node(str(pid)):
			var p = players_container.get_node(str(pid))
			if p.has_method("set_prep_locked"):
				p.set_prep_locked(false)
			# 移动到主战场入口
			p.global_position = entrance_offset + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))

	print("[Level] Prep phase ended, match started")
	Network.server_broadcast_prep_ended()
	_server_start_match()


func _server_start_match() -> void:
	match_remaining = float(Network.lobby_config.get("match_duration_sec", 600))
	Network.server_broadcast_match_started()
	# 生成弹药包
	_server_spawn_ammo_packs()


func _server_end_match() -> void:
	game_state = GameState.END
	match_remaining = 0.0
	print("[Level] Match ended")
	# TODO: 结算胜负(PoC-1 简化,后续 PoC 加)


# =============================================================================
# 弹药包生成(服务器,PoC-2)
# =============================================================================

func _server_spawn_ammo_packs() -> void:
	if not multiplayer.is_server():
		return

	var total = Network.players.size()
	var small_n: int
	var medium_n: int
	var large_n: int

	# 根据人数确定弹药包数量
	if total <= 8:
		small_n = AMMO_PACK_COUNT_SMALL_8
		medium_n = AMMO_PACK_COUNT_MEDIUM_8
		large_n = AMMO_PACK_COUNT_LARGE_8
	else:
		# 24 人上限按比例
		var ratio = float(total) / 24.0
		small_n = int(round(AMMO_PACK_COUNT_SMALL_24 * ratio))
		medium_n = int(round(AMMO_PACK_COUNT_MEDIUM_24 * ratio))
		large_n = int(round(AMMO_PACK_COUNT_LARGE_24 * ratio))

	print("[Level] Spawning ammo packs: ", small_n, " small, ", medium_n, " medium, ", large_n, " large")

	var ammo_scene = preload("res://scripts/ammo_pickup.gd")
	var container = _get_or_create_ammo_container()

	# 随机散落(避免重叠)
	var used_positions: Array[Vector3] = []
	var min_distance = 5.0
	var spawn_data: Array = []
	var index = 0

	for i in range(small_n):
		var pos = _get_random_ammo_position(used_positions, min_distance)
		var data = {"name": "AmmoPack_%03d_SMALL" % index, "position": pos, "type": AmmoPickup.AmmoType.SMALL}
		_spawn_one_ammo(container, ammo_scene, data)
		spawn_data.append(data)
		used_positions.append(pos)
		index += 1

	for i in range(medium_n):
		var pos = _get_random_ammo_position(used_positions, min_distance)
		var data = {"name": "AmmoPack_%03d_MEDIUM" % index, "position": pos, "type": AmmoPickup.AmmoType.MEDIUM}
		_spawn_one_ammo(container, ammo_scene, data)
		spawn_data.append(data)
		used_positions.append(pos)
		index += 1

	for i in range(large_n):
		var pos = _get_random_ammo_position(used_positions, min_distance)
		var data = {"name": "AmmoPack_%03d_LARGE" % index, "position": pos, "type": AmmoPickup.AmmoType.LARGE}
		_spawn_one_ammo(container, ammo_scene, data)
		spawn_data.append(data)
		used_positions.append(pos)
		index += 1

	_rpc_spawn_ammo_packs.rpc(spawn_data)


func _get_random_ammo_position(used: Array[Vector3], min_dist: float) -> Vector3:
	for attempt in range(20):
		var angle = randf() * TAU
		var radius = randf_range(5.0, AMMO_PACK_MAP_RADIUS)
		var pos = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		var ok = true
		for u in used:
			if pos.distance_to(u) < min_dist:
				ok = false
				break
		if ok:
			return pos
	# 兜底:返回中心附近
	return Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5))


func _get_or_create_ammo_container() -> Node3D:
	var existing = get_node_or_null("AmmoPackContainer")
	if existing:
		for child in existing.get_children():
			child.free()
		return existing
	var container = Node3D.new()
	container.name = "AmmoPackContainer"
	add_child(container)
	return container


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_ammo_packs(spawn_data: Array) -> void:
	var ammo_script = preload("res://scripts/ammo_pickup.gd")
	var container = _get_or_create_ammo_container()
	for data in spawn_data:
		_spawn_one_ammo(container, ammo_script, data)


func _spawn_one_ammo(container: Node3D, ammo_script, data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var type: int = data.get("type", AmmoPickup.AmmoType.SMALL)
	var node = Area3D.new()
	node.set_script(ammo_script)
	node.name = data.get("name", "AmmoPack_" + str(type))
	node.global_position = pos
	node.set("ammo_type", type)
	node.collision_layer = 4  # ammo layer

	# 视觉
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.4, 0.4, 0.4)
	mesh_inst.mesh = box_mesh

	var mat = StandardMaterial3D.new()
	var colors = {
		AmmoPickup.AmmoType.SMALL: Color(0.7, 0.7, 0.7),
		AmmoPickup.AmmoType.MEDIUM: Color(0.3, 0.6, 1.0),
		AmmoPickup.AmmoType.LARGE: Color(1.0, 0.5, 0.0)
	}
	mat.albedo_color = colors.get(type, Color.WHITE)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.5
	mesh_inst.set_surface_override_material(0, mat)
	node.add_child(mesh_inst)

	# 标签
	var label = Label3D.new()
	label.name = "Label"
	label.text = ["+30", "+60", "MAX"][type]
	label.position = Vector3(0, 0.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Label3D 不支持 modulate(3D 节点),用 modulate 通过材质或 outline_colors
	label.outline_modulate = mat.albedo_color
	node.add_child(label)

	# 碰撞
	var coll = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.8
	coll.shape = sphere
	node.add_child(coll)

	container.add_child(node, true)
	node.set_deferred("ammo_type", type)


# =============================================================================
# 客户端:阶段事件回调
# =============================================================================

func _on_prep_phase_started(remaining: float) -> void:
	game_state = GameState.PREP
	prep_remaining = remaining
	_set_preparation_gate_open(false)
	if main_menu:
		main_menu.hide_menu()
	_set_hud_visible(true)
	print("[Level] Client received: prep phase started, ", remaining, "s remaining")
	# 显示倒计时 HUD
	print("[Level] prep_timer_label = ", prep_timer_label, " is_inside_tree = ", prep_timer_label != null and prep_timer_label.is_inside_tree())
	if prep_timer_label:
		prep_timer_label.visible = true
		_update_prep_ui()
		print("[Level] PrepTimerLabel visible = ", prep_timer_label.visible, " text = ", prep_timer_label.text, " global_pos = ", prep_timer_label.global_position)
	else:
		print("[Level] WARNING: prep_timer_label is null - HUDCanvas/PrepTimerLabel node not found!")

	for pid in Network.players.keys():
		_try_reposition_player(pid)


func _on_prep_phase_ended() -> void:
	game_state = GameState.PLAY
	_set_hud_visible(true)
	_set_preparation_gate_open(true)
	# 隐藏倒计时 HUD
	if prep_timer_label:
		prep_timer_label.visible = false
	for pid in Network.get_hunters():
		var player_node = players_container.get_node_or_null(str(pid))
		if player_node and player_node.has_method("set_prep_locked"):
			player_node.set_prep_locked(false)


func _on_match_started() -> void:
	game_state = GameState.PLAY
	match_remaining = float(Network.lobby_config.get("match_duration_sec", 600))


func _update_prep_ui() -> void:
	if not prep_timer_label:
		return
	var secs = int(ceil(prep_remaining))
	var mins = secs / 60
	var sec = secs % 60
	prep_timer_label.text = "%s: %02d:%02d" % [I18n.t("prep_remaining"), mins, sec]
	# 最后 10 秒变红色
	if secs <= 10:
		prep_timer_label.modulate = Color(1.5, 0.3, 0.3, 1)
	else:
		prep_timer_label.modulate = Color(1, 1, 1, 1)


func _set_preparation_gate_open(open: bool) -> void:
	if not preparation_room:
		return
	var gate = preparation_room.get_node_or_null("Gate")
	if not gate:
		return
	gate.visible = not open
	for child in gate.get_children():
		if child is CollisionShape3D:
			child.disabled = open
	print("[Level] Preparation gate ", "opened" if open else "closed")


func _ensure_status_hud() -> void:
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	status_label = hud.get_node_or_null("StatusLabel")
	if status_label:
		return
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(16, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(status_label)
	_update_status_hud()


func _set_hud_visible(visible_value: bool) -> void:
	if prep_timer_label:
		prep_timer_label.visible = visible_value and game_state == GameState.PREP
	if status_label:
		status_label.visible = visible_value


func _update_status_hud() -> void:
	if not status_label:
		return
	status_label.visible = not (main_menu and main_menu.is_menu_visible())
	if not status_label.visible:
		return
	var role = Network.get_my_role()
	var phase_key = ["LOBBY", "PREP", "PLAY", "END"][game_state]
	var phase = I18n.t("phase." + phase_key)
	var lines := [
		"%s: %s" % [I18n.t("phase"), phase],
		"%s: %s" % [I18n.t("role"), _localized_role(role)],
		"%s: %d | %s: %d | Props: %d" % [I18n.t("players"), Network.players.size(), I18n.t("role.hunter"), Network.get_hunters().size(), Network.get_props().size()],
	]
	if game_state == GameState.PREP:
		lines.append("%s: %ds" % [I18n.t("prep_remaining"), int(ceil(prep_remaining))])
	elif game_state == GameState.PLAY:
		lines.append("%s: %ds" % [I18n.t("match_remaining"), int(ceil(match_remaining))])
	var local_player = _get_local_player()
	if local_player:
		if local_player.has_method("get_health"):
			lines.append("%s: %d" % [I18n.t("health"), int(local_player.get_health())])
		if local_player.has_node("WeaponSystem"):
			var weapon: WeaponSystem = local_player.get_node("WeaponSystem")
			lines.append("%s: %d / %d" % [I18n.t("ammo"), weapon.current_magazine, weapon.total_ammo])
	status_label.text = "\n".join(lines)


func _localized_role(role: int) -> String:
	match role:
		Network.Role.CHAMELEON:
			return I18n.t("role.chameleon")
		Network.Role.STALKER:
			return I18n.t("role.stalker")
		Network.Role.HUNTER:
			return I18n.t("role.hunter")
		_:
			return "-"


# =============================================================================
# MULTIPLAYER CHAT(保留原逻辑)
# =============================================================================

func toggle_chat():
	if main_menu.is_menu_visible():
		return
	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()


func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()


func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif chat_visible and multiplayer_chat.message.has_focus():
		if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
			multiplayer_chat._on_send_pressed()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_debug_add_item()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_debug_print_inventory()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		# Dev cheat:host 单人时强制触发 prep phase(用于 UI 测试)
		_debug_force_prep_phase()


func _on_chat_message_sent(message_text: String) -> void:
	_send_chat_message(message_text)


func _on_lobby_chat_message_sent(message_text: String) -> void:
	_send_chat_message(message_text)


func _send_chat_message(message_text: String) -> void:
	var trimmed_message = message_text.strip_edges()
	if trimmed_message == "":
		return
	var local_id := multiplayer.get_unique_id()
	var nick = Network.players.get(local_id, {}).get("nick", "Player")
	rpc("msg_rpc", nick, trimmed_message)


@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	multiplayer_chat.add_message(nick, msg)
	if main_menu:
		main_menu.add_lobby_chat_message(str(nick), str(msg))


# =============================================================================
# INVENTORY(保留原逻辑)
# =============================================================================

func toggle_inventory():
	if main_menu.is_menu_visible():
		return
	var local_player = _get_local_player()
	if not local_player:
		return
	inventory_visible = !inventory_visible
	if inventory_visible:
		inventory_ui.open_inventory(local_player)
	else:
		inventory_ui.close_inventory()


func is_inventory_visible() -> bool:
	return inventory_visible


func _notification(what):
	if what == NOTIFICATION_READY:
		print("=== Prop Hunt v0.3.3 ===")
		print("Controls:")
		print("  WASD - Move | Shift - Sprint | Space - Jump")
		print("  Ctrl - Toggle Chat | B - Toggle Inventory")
		print("  F1 - Add random test item (debug)")
		print("  F2 - Print inventory contents (debug)")
		print("Match: ", Network.lobby_config.get("match_duration_sec", 600) / 60, " min")
		print("Prep: ", Network.lobby_config.get("prep_duration_sec", 120), " s")
		print("Ratio: 1 Hunter : 3 Props")


func _on_inventory_closed():
	inventory_visible = false


func update_local_inventory_display():
	if inventory_ui:
		inventory_ui.refresh_display()


func _get_local_player() -> Character:
	var local_player_id = multiplayer.get_unique_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id)) as Character
	return null


func _debug_add_item():
	var local_player = _get_local_player()
	if local_player:
		var test_items = ["iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"]
		var random_item = test_items[randi() % test_items.size()]
		print("Debug: Requesting to add ", random_item, " to player ", local_player.name)
		local_player.request_add_item.rpc_id(1, random_item, 1)
	else:
		print("Debug: No local player found!")


func _debug_print_inventory():
	var local_player = _get_local_player()
	if local_player and local_player.get_inventory():
		var inventory = local_player.get_inventory()
		print("=== Inventory Debug ===")
		for i in range(inventory.slots.size()):
			var slot = inventory.get_slot(i)
			if slot and not slot.is_empty():
				print("Slot ", i, ": ", slot.item_id, " x", slot.quantity)
		print("=====================")
	else:
		print("No inventory found for local player")


# Dev cheat:host 单人时强制触发 prep phase
func _debug_force_prep_phase() -> void:
	if not multiplayer.is_server():
		print("[Debug] Only server can force prep phase")
		return
	if game_state != GameState.LOBBY:
		print("[Debug] Already in progress (game_state=", game_state, ")")
		return
	if Network.players.size() < 1:
		print("[Debug] No players yet")
		return
	print("[Debug] F5: Force start prep phase (skip 2-player check)")
	Network.server_auto_balance_roles(true)
	_server_start_prep_phase()
