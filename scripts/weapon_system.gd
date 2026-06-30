extends Node3D
class_name WeaponSystem
# =============================================================================
# WeaponSystem — AK47 武器系统(v0.3.3)
#
# 设计:
#   - 30 发弹匣,120 总上限,初始 0 发(v0.3.2 锁定)
#   - 600 RPM 射速
#   - 单发 25% 伤害,4 发击杀(3 发爆头)
#   - 服务器侧 raycast 命中判定
#   - 弹药耗尽切近战(1 发 10%)
# =============================================================================

# -----------------------------------------------------------------------------
# 配置常量
# -----------------------------------------------------------------------------
const MAGAZINE_SIZE: int = 30
const MAX_TOTAL_AMMO: int = 120
const INITIAL_AMMO: int = 0  # v0.3.2 锁定:必须拾取
const FIRE_RATE_INTERVAL: float = 0.1  # 600 RPM
const DAMAGE_PER_BULLET: float = 25.0
const HEADSHOT_MULTIPLIER: float = 1.5
const RELOAD_TIME: float = 2.5
const MAX_RANGE: float = 60.0
const DAMAGE_FALLOFF_RANGE: float = 60.0
const DAMAGE_FALLOFF_FACTOR: float = 0.5
const SCAN_RANGE: float = 14.0
const SCAN_COOLDOWN: float = 4.0
const SCAN_SCULPT_RESET_RADIUS: float = 0.56
const SCAN_SCULPT_RESET_AMOUNT: float = 0.45
const VISUAL_RPC_RELEVANCE_RADIUS: float = 48.0
const GreenBloodImpactScript := preload("res://scripts/green_blood_impact.gd")
const NetworkInterestScript := preload("res://scripts/network_interest.gd")
const BulletTracerEffectScript := preload("res://scripts/effects/bullet_tracer_effect.gd")
const BulletImpactEffectScript := preload("res://scripts/effects/bullet_impact_effect.gd")

const MELEE_DAMAGE: float = 10.0  # 弹药耗尽时切近战

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
var current_magazine: int = 0        # 当前弹匣弹药
var total_ammo: int = INITIAL_AMMO   # 总弹药(弹匣 + 备弹)
var is_firing: bool = false
var is_reloading: bool = false
var fire_cooldown: float = 0.0
var last_fire_time: float = 0.0
var scan_cooldown: float = 0.0

# 武器所有者(通常是 Hunter player)— 注意:Node3D 有内置 owner 属性,避免重名
var shooter_node: Node3D = null
var camera: Camera3D = null
var owner_peer_id: int = 1

# -----------------------------------------------------------------------------
# 信号
# -----------------------------------------------------------------------------
signal ammo_changed(current_magazine: int, total_ammo: int)
signal weapon_fired(hit_position: Vector3, hit_target: Node, is_headshot: bool)
signal weapon_dry()  # 弹药耗尽
signal reload_started(duration: float)
signal reload_completed()
signal weapon_out_of_ammo()


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	pass


func _should_log_runtime_debug() -> bool:
	return GameSettings.should_log_runtime_debug()


func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if scan_cooldown > 0.0:
		scan_cooldown = max(0.0, scan_cooldown - delta)


func initialize(owner_node: Node3D, owner_camera: Camera3D = null) -> void:
	shooter_node = owner_node
	camera = owner_camera
	if shooter_node and shooter_node.has_method("get_multiplayer_authority"):
		owner_peer_id = shooter_node.get_multiplayer_authority()
	current_magazine = 0
	total_ammo = INITIAL_AMMO
	ammo_changed.emit(current_magazine, total_ammo)


# =============================================================================
# 客户端发起:请求开火
# =============================================================================

# 玩家按住鼠标左键时,每帧调用
func request_fire() -> void:
	if is_reloading:
		return

	if total_ammo <= 0:
		_on_weapon_out_of_ammo()
		return

	if fire_cooldown > 0.0:
		return

	if current_magazine <= 0:
		# 自动换弹
		_auto_reload()
		return

	fire_cooldown = FIRE_RATE_INTERVAL

	var aim_dir: Vector3 = _get_aim_direction()
	var shooter_pos: Vector3 = _get_shooter_position()
	var fire_tick: int = _get_fire_tick()
	var fire_sequence: int = _allocate_fire_sequence()
	if multiplayer.is_server():
		_server_fire(owner_peer_id, aim_dir, shooter_pos, fire_tick, fire_sequence)
	else:
		Network.record_rpc_event("weapon.fire_request", 1, 56)
		_request_fire_rpc.rpc_id(1, aim_dir, shooter_pos, fire_tick, fire_sequence)


# 客户端发起换弹
func request_reload() -> void:
	if is_reloading or current_magazine == MAGAZINE_SIZE:
		return
	if multiplayer.is_server():
		_server_start_reload()
	else:
		Network.record_rpc_event("weapon.reload_request", 1, 8)
		_request_reload_rpc.rpc_id(1)


func request_scan() -> void:
	if scan_cooldown > 0.0:
		_show_feedback_on_owner("SCAN %.1fs" % scan_cooldown, Color(0.65, 0.78, 1.0, 1.0), 0.55)
		return

	scan_cooldown = SCAN_COOLDOWN
	if multiplayer.is_server():
		_server_scan(owner_peer_id)
	else:
		Network.record_rpc_event("weapon.scan_request", 1, 8)
		_request_scan_rpc.rpc_id(1)


# 服务器发起:加载弹药(从弹药包)
func server_add_ammo(amount: int) -> bool:
	if not multiplayer.is_server():
		return false
	if total_ammo >= MAX_TOTAL_AMMO:
		return false
	var old_total = total_ammo
	total_ammo = min(MAX_TOTAL_AMMO, total_ammo + amount)
	# 弹药优先补入弹匣空位
	if current_magazine < MAGAZINE_SIZE:
		var needed = MAGAZINE_SIZE - current_magazine
		var to_mag = min(needed, total_ammo - current_magazine)
		current_magazine = min(MAGAZINE_SIZE, current_magazine + to_mag)
	ammo_changed.emit(current_magazine, total_ammo)
	_sync_ammo_to_owner()
	if _should_log_runtime_debug():
		print("[Weapon] +", total_ammo - old_total, " ammo, total=", total_ammo)
	return true


# =============================================================================
# 服务器侧:处理 RPC
# =============================================================================

@rpc("any_peer", "call_local", "reliable")
func _request_fire_rpc(aim_dir: Vector3, shooter_pos: Vector3, fire_tick: int = -1, fire_sequence: int = 0):
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_server_fire(sender_id, aim_dir, shooter_pos, fire_tick, fire_sequence)


@rpc("any_peer", "call_local", "reliable")
func _request_scan_rpc():
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_server_scan(sender_id)


func _server_fire(sender_id: int, aim_dir: Vector3, shooter_pos: Vector3, fire_tick: int = -1, fire_sequence: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if sender_id != owner_peer_id:
		push_warning("Peer " + str(sender_id) + " tried to fire weapon owned by " + str(owner_peer_id))
		return
	if total_ammo <= 0 or current_magazine <= 0:
		return

	current_magazine -= 1
	total_ammo -= 1

	var clean_aim_dir: Vector3 = aim_dir.normalized() if aim_dir.length_squared() > 0.000001 else Vector3.FORWARD
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		shooter_pos,
		shooter_pos + clean_aim_dir * MAX_RANGE
	)
	query.exclude = [shooter_node.get_rid()] if shooter_node else []
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var world_result: Dictionary = space_state.intersect_ray(query)
	var hit_position: Vector3 = shooter_pos + clean_aim_dir * MAX_RANGE
	var hit_target: Node = null
	var hit_normal: Vector3 = -clean_aim_dir
	var is_headshot: bool = false
	var damage_dealt: float = DAMAGE_PER_BULLET
	var feedback_text: String = "MISS"
	var feedback_color: Color = Color(0.75, 0.78, 0.86, 1.0)
	var max_compensated_distance: float = MAX_RANGE
	var world_damageable_distance: float = INF
	# Captured at function scope so the environment impact VFX can use the real
	# surface point/normal even when a lag-compensated player hit overrides the
	# logical hit_position below.
	var has_world_hit: bool = false
	var world_hit_position: Vector3 = Vector3.ZERO
	var world_hit_normal: Vector3 = -clean_aim_dir
	var world_collider: Node = null

	if not world_result.is_empty():
		has_world_hit = true
		world_hit_position = world_result.get("position", hit_position)
		world_hit_normal = world_result.get("normal", world_hit_normal)
		max_compensated_distance = clampf(shooter_pos.distance_to(world_hit_position), 0.0, MAX_RANGE)
		var raw_world_target: Variant = world_result.get("collider", null)
		if raw_world_target is Node:
			world_collider = raw_world_target as Node
			if _is_damageable_weapon_target(raw_world_target):
				world_damageable_distance = max_compensated_distance

	var compensated_hit: Dictionary = _find_rewind_player_hit(sender_id, shooter_pos, clean_aim_dir, max_compensated_distance, fire_tick)
	var compensated_distance: float = float(compensated_hit.get("distance", INF)) if not compensated_hit.is_empty() else INF
	var use_compensated_hit: bool = not compensated_hit.is_empty() and compensated_distance <= world_damageable_distance + 0.05

	if use_compensated_hit:
		hit_position = compensated_hit.get("position", hit_position)
		hit_normal = compensated_hit.get("normal", hit_normal)
		var raw_compensated_target: Variant = compensated_hit.get("target", null)
		if raw_compensated_target is Node:
			hit_target = raw_compensated_target as Node
		is_headshot = bool(compensated_hit.get("headshot", false))
		feedback_text = "IMPACT"
		feedback_color = Color(0.95, 0.72, 0.28, 1.0)
		Network.record_perf_event("weapon.rewind_hit")
		if fire_sequence > 0:
			Network.record_perf_event("weapon.fire_sequence")
	elif not world_result.is_empty():
		hit_position = world_result.get("position", hit_position)
		hit_normal = world_result.get("normal", hit_normal)
		var raw_target: Variant = world_result.get("collider", null)
		if raw_target is Node:
			hit_target = raw_target as Node
		feedback_text = "IMPACT"
		feedback_color = Color(0.95, 0.72, 0.28, 1.0)

	if hit_target and hit_target.has_method("is_head_shot") and hit_target.is_head_shot():
		is_headshot = true
	if is_headshot:
		damage_dealt *= HEADSHOT_MULTIPLIER

	var distance: float = shooter_pos.distance_to(hit_position)
	if distance > DAMAGE_FALLOFF_RANGE:
		damage_dealt *= DAMAGE_FALLOFF_FACTOR

	if hit_target and _is_damageable_weapon_target(hit_target):
		if hit_target.is_in_group("players"):
			_send_green_blood_impact_visual(shooter_pos, hit_position, hit_normal, clean_aim_dir)
		hit_target.take_damage(damage_dealt, sender_id, is_headshot)
		if hit_target.has_method("is_card_decoy_target") and hit_target.is_card_decoy_target():
			feedback_text = "DECOY HIT -%d" % int(round(damage_dealt))
			feedback_color = Color(0.62, 0.92, 1.0, 1.0)
		elif hit_target.has_method("is_disguised") and hit_target.is_disguised():
			feedback_text = "DISGUISE HIT -%d" % int(round(damage_dealt))
			feedback_color = Color(0.18, 1.0, 0.86, 1.0)
		else:
			feedback_text = "HIT -%d" % int(round(damage_dealt))
			feedback_color = Color(1.0, 0.86, 0.25, 1.0)

	_send_tracer_visual(shooter_pos, hit_position)

	# Surface impact VFX: only when the bullet struck solid geometry/a prop and a
	# lag-compensated player hit did not take priority. Players use green blood.
	if has_world_hit and not use_compensated_hit:
		var world_hit_is_player: bool = world_collider != null and world_collider.is_in_group("players")
		if not world_hit_is_player:
			_send_bullet_impact_visual(shooter_pos, world_hit_position, world_hit_normal, clean_aim_dir)

	ammo_changed.emit(current_magazine, total_ammo)
	_sync_ammo_to_owner()
	_show_feedback_on_owner(feedback_text, feedback_color, 0.72)
	weapon_fired.emit(hit_position, hit_target, is_headshot)


func _should_skip_dedicated_server_visuals() -> bool:
	return RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config)


func _send_green_blood_impact_visual(shooter_position: Vector3, impact_position: Vector3, impact_normal: Vector3, shooter_direction: Vector3) -> void:
	var recipients: PackedInt32Array = _weapon_visual_recipient_ids(shooter_position, impact_position, owner_peer_id)
	if recipients.is_empty():
		return
	Network.record_rpc_event("weapon.green_blood", recipients.size(), 60)
	for peer_id: int in recipients:
		if peer_id == 1:
			_broadcast_green_blood_impact(impact_position, impact_normal, shooter_direction)
		else:
			_broadcast_green_blood_impact.rpc_id(peer_id, impact_position, impact_normal, shooter_direction)


@rpc("authority", "call_local", "unreliable_ordered")
func _broadcast_green_blood_impact(impact_position: Vector3, impact_normal: Vector3, shooter_direction: Vector3) -> void:
	if _should_skip_dedicated_server_visuals():
		return
	var parent: Node = get_tree().get_current_scene() if get_tree() else null
	if parent == null:
		parent = self
	GreenBloodImpactScript.spawn(parent, impact_position, impact_normal, shooter_direction)


func _send_bullet_impact_visual(shooter_position: Vector3, impact_position: Vector3, impact_normal: Vector3, shooter_direction: Vector3) -> void:
	var recipients: PackedInt32Array = _weapon_visual_recipient_ids(shooter_position, impact_position, owner_peer_id)
	if recipients.is_empty():
		return
	Network.record_rpc_event("weapon.bullet_impact", recipients.size(), 60)
	for peer_id: int in recipients:
		if peer_id == 1:
			_broadcast_bullet_impact(impact_position, impact_normal, shooter_direction)
		else:
			_broadcast_bullet_impact.rpc_id(peer_id, impact_position, impact_normal, shooter_direction)


@rpc("authority", "call_local", "unreliable_ordered")
func _broadcast_bullet_impact(impact_position: Vector3, impact_normal: Vector3, shooter_direction: Vector3) -> void:
	if _should_skip_dedicated_server_visuals():
		return
	var parent: Node = get_tree().get_current_scene() if get_tree() else null
	if parent == null:
		parent = self
	BulletImpactEffectScript.spawn(parent, impact_position, impact_normal, shooter_direction)


func _is_damageable_weapon_target(target) -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	if target is Node and (target as Node).is_in_group("players"):
		return true
	return target.has_method("is_card_decoy_target") and target.is_card_decoy_target()


func _server_scan(sender_id: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id != owner_peer_id:
		push_warning("Peer " + str(sender_id) + " tried to scan with weapon owned by " + str(owner_peer_id))
		return

	var origin := _get_shooter_position()
	var nearest_target: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("players"):
		if node == shooter_node:
			continue
		if not node is Node3D:
			continue
		if not node.has_method("is_prop") or not node.is_prop():
			continue
		var distance := origin.distance_to((node as Node3D).global_position)
		if distance <= SCAN_RANGE and distance < nearest_distance:
			nearest_target = node
			nearest_distance = distance

	if nearest_target:
		var is_disguise: bool = nearest_target.has_method("is_disguised") and nearest_target.is_disguised()
		if _apply_scan_counterplay_to_target(nearest_target):
			_show_feedback_on_owner("CLAY SIGNAL %.1fm" % nearest_distance, Color(1.0, 0.62, 0.28, 1.0), 1.1)
		elif is_disguise:
			_show_feedback_on_owner("DISGUISE SIGNAL %.1fm" % nearest_distance, Color(0.18, 1.0, 0.86, 1.0), 1.1)
		else:
			_show_feedback_on_owner("PROP SIGNAL %.1fm" % nearest_distance, Color(0.65, 0.78, 1.0, 1.0), 1.0)
	else:
		_show_feedback_on_owner("SCAN CLEAR", Color(0.75, 0.78, 0.86, 1.0), 0.75)


@rpc("any_peer", "call_local", "reliable")
func _request_reload_rpc():
	if not multiplayer.is_server():
		return
	_server_start_reload()


func _server_start_reload() -> void:
	if is_reloading:
		return
	if current_magazine >= MAGAZINE_SIZE:
		return
	if total_ammo <= current_magazine:
		# 备弹不够填满弹匣
		return

	is_reloading = true
	reload_started.emit(RELOAD_TIME)
	if _should_log_runtime_debug():
		print("[Weapon] Reload started")
	Network.record_rpc_event("weapon.reload_state", maxi(multiplayer.get_peers().size(), 1), 8)
	_broadcast_reload.rpc(true)
	_sync_reload_to_owner(true)

	await get_tree().create_timer(RELOAD_TIME).timeout

	if not is_reloading:
		return  # 被中断

	var needed = MAGAZINE_SIZE - current_magazine
	var available = total_ammo - current_magazine
	var to_load = min(needed, available)
	current_magazine += to_load
	is_reloading = false
	reload_completed.emit()
	ammo_changed.emit(current_magazine, total_ammo)
	_sync_ammo_to_owner()
	Network.record_rpc_event("weapon.reload_state", maxi(multiplayer.get_peers().size(), 1), 8)
	_broadcast_reload.rpc(false)
	_sync_reload_to_owner(false)
	if _should_log_runtime_debug():
		print("[Weapon] Reload completed, mag=", current_magazine, " total=", total_ammo)


func _auto_reload() -> void:
	if is_reloading or current_magazine >= MAGAZINE_SIZE:
		return
	if multiplayer.is_server():
		_server_start_reload()
	else:
		request_reload()


func _send_tracer_visual(start: Vector3, end: Vector3) -> void:
	var recipients: PackedInt32Array = _weapon_visual_recipient_ids(start, end, owner_peer_id)
	if recipients.is_empty():
		return
	Network.record_rpc_event("weapon.tracer", recipients.size(), 40)
	for peer_id: int in recipients:
		if peer_id == 1:
			_broadcast_tracer(start, end)
		else:
			_broadcast_tracer.rpc_id(peer_id, start, end)


@rpc("authority", "call_local", "unreliable_ordered")
func _broadcast_tracer(start: Vector3, end: Vector3):
	# 客户端显示弹道(0.15s 后消失)
	if _should_skip_dedicated_server_visuals():
		return
	_show_tracer(start, end)


@rpc("authority", "call_local", "reliable")
func _broadcast_reload(reloading: bool):
	is_reloading = reloading


@rpc("authority", "call_local", "reliable")
func _sync_ammo(current: int, total: int):
	current_magazine = current
	total_ammo = total
	ammo_changed.emit(current_magazine, total_ammo)


@rpc("authority", "call_local", "reliable")
func _sync_reload(reloading: bool):
	is_reloading = reloading


func _sync_ammo_to_owner() -> void:
	if not multiplayer.is_server():
		return
	if owner_peer_id == 1:
		_sync_ammo(current_magazine, total_ammo)
	else:
		Network.record_rpc_event("weapon.ammo_owner", 1, 12)
		_sync_ammo.rpc_id(owner_peer_id, current_magazine, total_ammo)


func _sync_reload_to_owner(reloading: bool) -> void:
	if not multiplayer.is_server():
		return
	if owner_peer_id == 1:
		_sync_reload(reloading)
	else:
		Network.record_rpc_event("weapon.reload_owner", 1, 8)
		_sync_reload.rpc_id(owner_peer_id, reloading)


@rpc("authority", "call_local", "reliable")
func _client_weapon_feedback(text: String, color: Color, duration: float = 0.85) -> void:
	var level = get_tree().get_current_scene()
	if level and level.has_method("show_combat_feedback"):
		level.show_combat_feedback(text, color, duration)
	elif _should_log_runtime_debug():
		print("[WeaponFeedback] ", text)


func _show_feedback_on_owner(text: String, color: Color = Color.WHITE, duration: float = 0.85) -> void:
	if not multiplayer.is_server():
		_client_weapon_feedback(text, color, duration)
		return
	if owner_peer_id == 1:
		_client_weapon_feedback(text, color, duration)
	else:
		_client_weapon_feedback.rpc_id(owner_peer_id, text, color, duration)


func _weapon_visual_recipient_ids(segment_start: Vector3, segment_end: Vector3, always_peer_id: int) -> PackedInt32Array:
	var recipients: PackedInt32Array = PackedInt32Array()
	if multiplayer.multiplayer_peer == null:
		_append_visual_recipient_id(recipients, 1)
		return recipients

	if not _should_skip_dedicated_server_visuals() and (always_peer_id == 1 or _is_peer_relevant_to_weapon_visual(1, segment_start, segment_end)):
		_append_visual_recipient_id(recipients, 1)

	for peer_id: int in multiplayer.get_peers():
		if peer_id == always_peer_id or _is_peer_relevant_to_weapon_visual(peer_id, segment_start, segment_end):
			_append_visual_recipient_id(recipients, peer_id)
	return recipients


func _append_visual_recipient_id(recipients: PackedInt32Array, peer_id: int) -> void:
	NetworkInterestScript.append_unique_peer_id(recipients, peer_id)


func _is_peer_relevant_to_weapon_visual(peer_id: int, segment_start: Vector3, segment_end: Vector3) -> bool:
	return NetworkInterestScript.is_peer_relevant_to_segment(_interest_tree(), _interest_scene(), peer_id, segment_start, segment_end, VISUAL_RPC_RELEVANCE_RADIUS)


func _find_player_node_for_peer(peer_id: int) -> Node3D:
	return NetworkInterestScript.find_player_node_for_peer(_interest_tree(), _interest_scene(), peer_id)


func _point_segment_distance_squared(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	return NetworkInterestScript.point_segment_distance_squared(point, segment_start, segment_end)


func _interest_tree() -> SceneTree:
	return get_tree() if is_inside_tree() else null


func _interest_scene() -> Node:
	var tree: SceneTree = _interest_tree()
	return tree.get_current_scene() if tree else null


func _apply_scan_counterplay_to_target(target: Node3D) -> bool:
	if not target or not target.has_method("apply_chameleon_sculpt_counterplay_reset"):
		return false
	var sculpt_system := target.get_node_or_null("ChameleonSculptSystem")
	if not sculpt_system or not sculpt_system.has_method("get_debug_summary"):
		return false
	var summary: Dictionary = sculpt_system.call("get_debug_summary")
	if not bool(summary.get("active", false)):
		return false
	var reset_position := target.global_position + Vector3.UP * 0.95
	var shell := sculpt_system.get("shell") as Node3D
	if shell and is_instance_valid(shell):
		reset_position = shell.global_position + Vector3.UP * 0.95
	target.call(
		"apply_chameleon_sculpt_counterplay_reset",
		reset_position,
		SCAN_SCULPT_RESET_RADIUS,
		SCAN_SCULPT_RESET_AMOUNT
	)
	return true


func _show_tracer(start: Vector3, end: Vector3) -> void:
	# High-quality hot tracer + muzzle flash (HOVL-style, see BulletTracerEffect).
	# Parented to the current scene (top_level) so the world-space beam never
	# drifts with the moving shooter the way the old shooter-child line did.
	var parent: Node = get_tree().get_current_scene() if get_tree() else null
	if parent == null:
		return
	BulletTracerEffectScript.spawn(parent, start, end)


func _on_weapon_out_of_ammo():
	weapon_out_of_ammo.emit()
	weapon_dry.emit()
	if _should_log_runtime_debug():
		print("[Weapon] Out of ammo, switching to melee")


# =============================================================================
# 工具函数
# =============================================================================

func _find_rewind_player_hit(sender_id: int, shooter_pos: Vector3, aim_dir: Vector3, max_distance: float, fire_tick: int) -> Dictionary:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(tree)
	if history == null:
		return {}
	return history.find_player_hit_on_segment(shooter_pos, aim_dir, max_distance, fire_tick, sender_id)


func _get_fire_tick() -> int:
	if shooter_node and shooter_node.has_method("get_network_input_tick"):
		return int(shooter_node.call("get_network_input_tick"))
	return NetworkTime.tick


func _allocate_fire_sequence() -> int:
	if shooter_node and shooter_node.has_method("allocate_network_intent_sequence"):
		return int(shooter_node.call("allocate_network_intent_sequence"))
	return int(Time.get_ticks_msec() & 0x7fffffff)


func _get_aim_direction() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z.normalized()
	elif shooter_node:
		return -shooter_node.global_transform.basis.z.normalized()
	return Vector3.FORWARD


func _get_shooter_position() -> Vector3:
	if camera:
		return camera.global_position
	elif shooter_node:
		return shooter_node.global_position + Vector3(0, 1.5, 0)
	return Vector3.ZERO


# 获取弹药百分比(0.0 - 1.0)
func get_ammo_percent() -> float:
	return float(total_ammo) / float(MAX_TOTAL_AMMO)


func is_weapon_ready() -> bool:
	return current_magazine > 0 and not is_reloading
