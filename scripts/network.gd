extends Node

# =============================================================================
# Network — Prop Hunt 多人网络单例(v0.3.3)
# 基于 godot-3d-multiplayer-template 原版扩展,加入:
#   - 角色系统(Chameleon / Stalker / Hunter)
#   - 1:3 自动分配(强制比例)
#   - 24 人 lobby 支持
#   - 玩家可选 + 自动 fallback
# =============================================================================

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 8080
const PUBLIC_SERVER_ADDRESS: String = "1.13.175.170"
const PUBLIC_SERVER_PRIMARY_CODE: String = "TX"
const PUBLIC_SERVER_BACKUP_ADDRESSES := ["8.153.148.157"]
const PUBLIC_SERVER_BACKUP_CODE_AL: String = "AL"
const PUBLIC_ROOM_PORT_START: int = 8081
const PUBLIC_ROOM_PORT_END: int = 8091
const PUBLIC_ROOM_STATUS_INTERVAL_SEC := 1.0
const PUBLIC_LOBBY_ROOM_POLL_INTERVAL_SEC := 1.5
const PUBLIC_ROOM_STALE_SECONDS := 20.0
const PUBLIC_ROOM_READY_TIMEOUT_SEC := 30.0
const PUBLIC_ROOM_START_GRACE_SECONDS := 45.0
const PUBLIC_ROOM_EMPTY_TTL_SECONDS := 3.0   # destroy an empty room ~3s after the last player leaves
const PUBLIC_ROOM_LAUNCH_MODE_ENV := "MAOMAO_ROOM_LAUNCH_MODE"
const PUBLIC_ROOM_LIFECYCLE_LOG_ENV: String = "MAOMAO_ROOM_LIFECYCLE_LOG"
const PUBLIC_ROOM_LAUNCH_MODE_CHILD := "child"
const PUBLIC_ROOM_LAUNCH_MODE_DETACHED := "detached"
const HOST_PORT_FALLBACK_ATTEMPTS: int = 12
const PERF_TELEMETRY_INTERVAL_SEC := 10.0
const PERF_TELEMETRY_SLOW_FRAME_MS := 50.0
const PERF_TELEMETRY_MAX_EVENT_KEYS := 10
const PERF_TELEMETRY_ENV_CACHE_MSEC := 250
var server_port: int = SERVER_PORT
const DEV_ALLOW_SINGLE_PLAYER_START := true
const MAX_PLAYERS: int = 24  # v0.3.2 改为 24(原模板 10)
const PUBLIC_SERVER_MAX_CLIENTS: int = 96
const DEFAULT_CHARACTER_MODEL := "basic_humanoid"
const SKIN_BLUE := 0
const SKIN_YELLOW := 1
const SKIN_GREEN := 2
const SKIN_RED := 3
const CharacterSkinCatalogScript := preload("res://scripts/character_skin_catalog.gd")
const PartyMonsterAccessoryCatalogScript := preload("res://scripts/party_monster_accessory_catalog.gd")
const CardDatabaseScript := preload("res://scripts/card_database.gd")
const NorayPrivateTransportScript := preload("res://scripts/network/noray_private_transport.gd")
const CARD_DRAFT_TOTAL_SECONDS := 20.0
const CARD_DRAFT_PICK_SECONDS := 10.0
const CARD_DRAFT_REQUIRED_PICKS := 2
const CARD_DRAFT_TIMER_SYNC_SECONDS := 0.25
const SKIN_CONFIG_TOTAL_SECONDS := 20.0

# -----------------------------------------------------------------------------
# 角色枚举(全局共享,Character / Player / Network 都用这个)
# -----------------------------------------------------------------------------
enum Role {
	NONE = -1,      # 未选择
	CHAMELEON = 0,  # 藏匿者(喷涂 + 变形)
	STALKER = 1,    # 潜行者(阴影隐身)
	HUNTER = 2,     # 猎人(AK47 + 探测)
	SPECTATOR = 3
}

const ROLE_NAMES := {
	Role.NONE: "未选择",
	Role.CHAMELEON: "藏匿者",
	Role.STALKER: "潜行者",
	Role.HUNTER: "猎人",
	Role.SPECTATOR: "观战者"
}

# -----------------------------------------------------------------------------
# 玩家信息字典(per peer)
#   nick: 昵称
#   skin: 皮肤枚举
#   role: 角色(Role 枚举值)
#   role_locked: 服务器是否已锁定该玩家的角色(防止客户端乱改)
# -----------------------------------------------------------------------------
var players: Dictionary = {}
var public_rooms: Dictionary = {}
var peer_rooms: Dictionary = {}
var active_public_room_id := ""
var _public_server_base_config: Dictionary = {}
var _has_received_full_sync := false
# Set once per connection when the server's handshake (server_info) has been
# validated, so plain 2-arg full-sync broadcasts cannot be mistaken for a stale
# server and falsely kick the client.
var _server_protocol_validated := false
var _redirecting_to_public_room := false
var _public_room_status_elapsed := 0.0
var _public_lobby_poll_elapsed := 0.0
var _public_lobby_snapshot_dirty := false
var _public_room_empty_elapsed := 0.0
var _public_room_created_msec := 0
var _public_room_runtime_ready := false
var _public_room_status_dir := ""
var _public_lobby_failover_endpoints: Array[String] = []
var _public_lobby_failover_index := 0
var _public_lobby_pending_context: Dictionary = {}
var _perf_telemetry_elapsed := 0.0
var _perf_telemetry_accumulated_delta := 0.0
var _perf_telemetry_worst_delta := 0.0
var _perf_telemetry_frames := 0
var _perf_telemetry_slow_frames := 0
var _perf_telemetry_enabled := false
var _perf_telemetry_enabled_cache := false
var _perf_telemetry_enabled_cache_msec := -1000000
var _perf_telemetry_event_counts: Dictionary = {}
var _perf_telemetry_event_bytes: Dictionary = {}
var _noray_private_transport: NorayPrivateTransport = null
# Latest user-facing networking error (e.g. version mismatch); UI may read this.
var last_error: String = ""


func _runtime_debug_log(
	value0: Variant = null,
	value1: Variant = null,
	value2: Variant = null,
	value3: Variant = null,
	value4: Variant = null,
	value5: Variant = null,
	value6: Variant = null,
	value7: Variant = null,
	value8: Variant = null,
	value9: Variant = null,
	value10: Variant = null,
	value11: Variant = null
) -> void:
	if not GameSettings.should_log_runtime_debug():
		return
	var output := ""
	for value in [value0, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11]:
		if value != null:
			output += str(value)
	print(output)


func has_runtime_multiplayer_peer() -> bool:
	return RuntimeMode.has_multiplayer_peer(multiplayer)


func local_peer_id() -> int:
	if has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	if players.has(1):
		return 1
	return 1


var player_info: Dictionary = {
	"nick": "host",
	"skin": SKIN_BLUE,
	"character_model": DEFAULT_CHARACTER_MODEL,
	"party_monster_accessories": {},
	"role": Role.NONE,
	"alive": true,
	"role_locked": false,
	"join_room_name": ""
}

# -----------------------------------------------------------------------------
# Lobby 配置(host 在 main_menu 设置,服务器使用)
# -----------------------------------------------------------------------------
var lobby_config: Dictionary = {
	"max_players": 24,
	"lobby_id": "",
	"room_name": "Private Match",
	"steam_lobby_id": "",
	"host_port": SERVER_PORT,
	"map": "Warehouse",
	"variant": "Default",
	"condition": "Normal",
	"game_show": "None",
	"gravity_mps2": 9.8,
	"low_gravity_events": true,
	"match_duration_sec": 600,       # 10 分钟默认
	"prep_duration_sec": 30,         # 30 秒默认
	"host_hunter_count": -1,         # -1 表示按 1:3 自动
	"host_stalker_count": -1,        # -1 表示按 1:1 自动
	"stalker_glass_alpha_max": 0.125,
	"stalker_glass_material": "classic",
	"hunter_auto_turret_enabled": false,
	"hunter_auto_turret_range": 34.0,
	"auto_balance": true,
	"public_server": false,
	"public_lobby": false,
	"public_room_id": "",
	"public_address": "",
	"public_server_code": "",
	"private_connection_mode": "direct",
	"private_connection_code": "",
	"private_connection_server": "",
	"host_peer_id": 1,
	"host_peer_name": "",
	"role_locked": false             # 服务器锁定角色后为 true,准备阶段开始时
}

# -----------------------------------------------------------------------------
# 信号
# -----------------------------------------------------------------------------
signal player_connected(peer_id, player_info)
signal players_synced(all_players)
signal player_role_changed(peer_id, new_role)        # 角色变化
signal player_life_state_changed(peer_id, alive)
signal player_disconnected(peer_id)
signal server_disconnected
signal version_mismatch(server_protocol: int, client_protocol: int, server_build_id: String)  # 版本/协议不匹配,被拒绝进房
signal roles_assigned()                              # 服务器完成角色分配
signal lobby_config_updated(config)                  # host 改配置
signal match_intro_started(remaining_sec: float)     # 全局正式开局倒计时开始
signal prep_phase_started(remaining_sec: float)      # 准备阶段开始
signal prep_phase_ended()                            # 准备阶段结束
signal match_started()                               # 正式比赛开始
signal start_match_requested()                       # host 点击开始
signal match_loading_started(map_name: String)
signal card_draft_updated(peer_id: int, draft_state: Dictionary)
signal card_loadout_updated(peer_id: int, loadout: Array)
signal card_activated(peer_id: int, card_id: String, slot_index: int)
signal skin_config_started(remaining_sec: float)
signal player_character_model_changed(peer_id: int, model_id: String)
signal player_party_monster_accessories_changed(peer_id: int, loadout: Dictionary)
signal card_drafts_completed()
signal public_room_redirect_requested(address: String, port: int, room_name: String, lobby_id: String)
signal public_room_join_failed(reason_key: String)
signal public_lobby_snapshot_received(rooms: Array)
signal public_lobby_connection_ready()
signal private_connection_status_changed(status_key: String, is_error: bool)
signal private_connection_share_updated(share_code: String)

var card_drafts: Dictionary = {}
var card_loadouts: Dictionary = {}
var _card_rng := RandomNumberGenerator.new()
var _card_draft_active := false
var _card_timer_sync_remaining := 0.0
var _card_intent_sequence: int = 0
var _last_card_intents: Dictionary = {}

# -----------------------------------------------------------------------------
# 阶段同步 RPC(server → 所有 client,通知阶段变化)
# -----------------------------------------------------------------------------
func can_start_lobby_match(lobby_players: Dictionary = {}) -> bool:
	var source := lobby_players if not lobby_players.is_empty() else players
	var active_count := _active_player_count(source)
	if DEV_ALLOW_SINGLE_PLAYER_START and active_count == 1:
		return true
	return source.size() >= 2 and _role_count(source, Role.HUNTER) > 0 and _prop_role_count(source) > 0


func lobby_start_hint_key(lobby_players: Dictionary = {}) -> String:
	var source := lobby_players if not lobby_players.is_empty() else players
	var active_count := _active_player_count(source)
	if DEV_ALLOW_SINGLE_PLAYER_START and active_count == 1:
		return "single_player_test_ready"
	return "players_needed" if source.size() < 2 else "teams_ready"


func _active_player_count(lobby_players: Dictionary) -> int:
	var count := 0
	for info in lobby_players.values():
		if int(info.get("role", Role.NONE)) != Role.SPECTATOR:
			count += 1
	return count


func _role_count(lobby_players: Dictionary, target_role: int) -> int:
	var count := 0
	for info in lobby_players.values():
		if int(info.get("role", Role.NONE)) == target_role:
			count += 1
	return count


func _prop_role_count(lobby_players: Dictionary) -> int:
	return _role_count(lobby_players, Role.CHAMELEON) + _role_count(lobby_players, Role.STALKER)


@rpc("authority", "call_local", "reliable")
func _rpc_match_loading_started(map_name: String):
	_runtime_debug_log("[Network] RPC match_loading_started RECEIVED, map=", map_name)
	match_loading_started.emit(map_name)


@rpc("authority", "call_local", "reliable")
func _rpc_match_intro_started(remaining_sec: float):
	_runtime_debug_log("[Network] RPC match_intro_started RECEIVED, remaining=", remaining_sec)
	match_intro_started.emit(remaining_sec)

@rpc("authority", "call_local", "reliable")
func _rpc_skin_config_started(remaining_sec: float):
	_runtime_debug_log("[Network] RPC skin_config_started RECEIVED, remaining=", remaining_sec)
	skin_config_started.emit(remaining_sec)

@rpc("authority", "call_local", "reliable")
func _rpc_prep_phase_started(remaining_sec: float):
	_runtime_debug_log("[Network] RPC prep_phase_started RECEIVED, remaining=", remaining_sec)
	prep_phase_started.emit(remaining_sec)

@rpc("authority", "call_local", "reliable")
func _rpc_prep_phase_ended():
	_runtime_debug_log("[Network] RPC prep_phase_ended RECEIVED")
	prep_phase_ended.emit()

@rpc("authority", "call_local", "reliable")
func _rpc_match_started():
	_runtime_debug_log("[Network] RPC match_started RECEIVED")
	match_started.emit()

# 服务器侧:广播给所有客户端
func server_broadcast_match_loading_started(map_name: String) -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting match_loading_started, map=", map_name, " peer_count=", multiplayer.get_peers().size())
	_rpc_match_loading_started.rpc(map_name)


func server_broadcast_match_intro_started(remaining_sec: float) -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting match_intro_started, remaining=", remaining_sec, " peer_count=", multiplayer.get_peers().size())
	_rpc_match_intro_started.rpc(remaining_sec)


func server_broadcast_skin_config_started(remaining_sec: float) -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting skin_config_started, remaining=", remaining_sec, " peer_count=", multiplayer.get_peers().size())
	_rpc_skin_config_started.rpc(remaining_sec)


func server_broadcast_prep_started(remaining_sec: float) -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting prep_phase_started, remaining=", remaining_sec, " peer_count=", multiplayer.get_peers().size())
	# call_local 模式下,server 调用时本地也会执行 emit,无需手动 emit
	_rpc_prep_phase_started.rpc(remaining_sec)

func server_broadcast_prep_ended() -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting prep_phase_ended")
	_rpc_prep_phase_ended.rpc()

func server_broadcast_match_started() -> void:
	if not multiplayer.is_server():
		return
	_runtime_debug_log("[Network] SERVER broadcasting match_started")
	_rpc_match_started.rpc()

# =============================================================================
# 生命周期
# =============================================================================

# =============================================================================
# Match card draft / loadout
# =============================================================================

func server_start_card_drafts_for_match() -> void:
	if not multiplayer.is_server():
		return
	_card_rng.randomize()
	card_drafts.clear()
	card_loadouts.clear()
	_card_draft_active = true
	_card_timer_sync_remaining = 0.0
	for pid in players.keys():
		var peer_id := int(pid)
		var role := int(players[pid].get("role", Role.NONE))
		if role == Role.SPECTATOR or role == Role.NONE:
			continue
		_server_begin_card_pick(peer_id)
	_server_check_card_drafts_completed()


func server_clear_match_cards() -> void:
	if not multiplayer.is_server():
		return
	_card_draft_active = false
	_card_timer_sync_remaining = 0.0
	card_drafts.clear()
	card_loadouts.clear()
	for pid in players.keys():
		var peer_id := int(pid)
		_sync_card_draft_to_peer(peer_id, {})
		_sync_card_loadout_to_peer(peer_id, [])


func get_my_card_draft() -> Dictionary:
	var peer_id := local_peer_id()
	return (card_drafts.get(peer_id, {}) as Dictionary).duplicate(true)


func get_my_card_loadout() -> Array:
	var peer_id := local_peer_id()
	return (card_loadouts.get(peer_id, []) as Array).duplicate(true)


func get_card_loadout_for_peer(peer_id: int) -> Array:
	return (card_loadouts.get(peer_id, []) as Array).duplicate(true)


func request_keep_card(card_id: String) -> void:
	if multiplayer.is_server():
		_server_keep_card(local_peer_id(), card_id)
	else:
		_request_keep_card_rpc.rpc_id(1, card_id)


func _next_network_intent_sequence() -> int:
	_card_intent_sequence += 1
	if _card_intent_sequence >= 0x7fffffff:
		_card_intent_sequence = 1
	return _card_intent_sequence


func _record_card_intent(peer_id: int, slot_index: int, intent_tick: int, intent_sequence: int) -> void:
	if intent_tick < 0:
		return
	_last_card_intents[peer_id] = {
		"slot_index": slot_index,
		"intent_tick": intent_tick,
		"server_tick": NetworkTime.tick,
		"sequence": intent_sequence,
		"tick_delta": NetworkTime.tick - intent_tick,
	}
	Network.record_perf_event("card.intent")


func request_use_card_slot(slot_index: int) -> void:
	var intent_tick: int = NetworkTime.tick
	var intent_sequence: int = _next_network_intent_sequence()
	if multiplayer.is_server():
		_server_use_card_slot(local_peer_id(), slot_index, intent_tick, intent_sequence)
	else:
		_request_use_card_slot_rpc.rpc_id(1, slot_index, intent_tick, intent_sequence)


func server_try_consume_reactive_card(peer_id: int, card_id: String) -> bool:
	if not multiplayer.is_server():
		return false
	var loadout := card_loadouts.get(peer_id, []) as Array
	for i in range(loadout.size()):
		var slot := loadout[i] as Dictionary
		if str(slot.get("id", "")) != card_id or bool(slot.get("used", false)):
			continue
		if CardDatabaseScript.is_manual(card_id):
			continue
		slot["used"] = true
		loadout[i] = slot
		card_loadouts[peer_id] = loadout
		_sync_card_loadout_to_peer(peer_id, loadout)
		_emit_card_activated(peer_id, card_id, i)
		return true
	return false


@rpc("any_peer", "reliable")
func _request_keep_card_rpc(card_id: String) -> void:
	if not multiplayer.is_server():
		return
	_server_keep_card(multiplayer.get_remote_sender_id(), card_id)


@rpc("any_peer", "reliable")
func _request_use_card_slot_rpc(slot_index: int, intent_tick: int = -1, intent_sequence: int = 0) -> void:
	if not multiplayer.is_server():
		return
	_server_use_card_slot(multiplayer.get_remote_sender_id(), slot_index, intent_tick, intent_sequence)


func _server_begin_card_pick(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var role := int(players[peer_id].get("role", Role.NONE))
	var previous := card_drafts.get(peer_id, {}) as Dictionary
	var kept := (previous.get("kept", []) as Array).duplicate()
	var choices := CardDatabaseScript.random_choices_for_role(role, 3, kept, _card_rng)
	var now_msec := Time.get_ticks_msec()
	var draft_started_msec := int(previous.get("draft_started_msec", now_msec))
	var draft_expires_at_msec := int(previous.get("draft_expires_at_msec", now_msec + int(CARD_DRAFT_TOTAL_SECONDS * 1000.0)))
	var pick_expires_at_msec := now_msec + int(minf(CARD_DRAFT_PICK_SECONDS, maxf(0.0, float(draft_expires_at_msec - now_msec) / 1000.0)) * 1000.0)
	var state := {
		"role": role,
		"pick_index": kept.size() + 1,
		"choices": choices,
		"kept": kept,
		"complete": false,
		"draft_started_msec": draft_started_msec,
		"draft_expires_at_msec": draft_expires_at_msec,
		"pick_started_msec": now_msec,
		"pick_expires_at_msec": pick_expires_at_msec,
		"pick_duration_sec": CARD_DRAFT_PICK_SECONDS,
		"draft_duration_sec": CARD_DRAFT_TOTAL_SECONDS,
		"auto_selected": false,
	}
	_update_card_draft_remaining_fields(state, now_msec)
	card_drafts[peer_id] = state
	_sync_card_draft_to_peer(peer_id, state)


func _server_keep_card(peer_id: int, card_id: String, automatic: bool = false) -> void:
	if not players.has(peer_id):
		return
	var state := card_drafts.get(peer_id, {}) as Dictionary
	if state.is_empty() or bool(state.get("complete", false)):
		return
	if not automatic and _is_card_pick_expired(state):
		_server_auto_keep_card(peer_id)
		return
	var choices := state.get("choices", []) as Array
	if not choices.has(card_id):
		return
	var kept := (state.get("kept", []) as Array).duplicate()
	if kept.has(card_id):
		return
	kept.append(card_id)
	var loadout := _cards_to_loadout(kept)
	card_loadouts[peer_id] = loadout
	_sync_card_loadout_to_peer(peer_id, loadout)
	if kept.size() >= CARD_DRAFT_REQUIRED_PICKS:
		state["kept"] = kept
		state["choices"] = []
		state["complete"] = true
		state["auto_selected"] = automatic
		_update_card_draft_remaining_fields(state)
		card_drafts[peer_id] = state
		_sync_card_draft_to_peer(peer_id, state)
		_server_check_card_drafts_completed()
		return
	state["kept"] = kept
	state["auto_selected"] = automatic
	card_drafts[peer_id] = state
	_server_begin_card_pick(peer_id)


func _server_process_card_drafts(delta: float) -> void:
	_card_timer_sync_remaining = maxf(0.0, _card_timer_sync_remaining - delta)
	var now_msec := Time.get_ticks_msec()
	var should_sync_timers := _card_timer_sync_remaining <= 0.0
	if should_sync_timers:
		_card_timer_sync_remaining = CARD_DRAFT_TIMER_SYNC_SECONDS
	var peer_ids := card_drafts.keys()
	for pid in peer_ids:
		var peer_id := int(pid)
		var state := card_drafts.get(peer_id, {}) as Dictionary
		if state.is_empty() or bool(state.get("complete", false)):
			continue
		_update_card_draft_remaining_fields(state, now_msec)
		card_drafts[peer_id] = state
		if _is_card_pick_expired(state, now_msec):
			_server_auto_keep_card(peer_id)
		elif should_sync_timers:
			_sync_card_draft_to_peer(peer_id, state)
	_server_check_card_drafts_completed()


func _server_auto_keep_card(peer_id: int) -> void:
	var state := card_drafts.get(peer_id, {}) as Dictionary
	if state.is_empty() or bool(state.get("complete", false)):
		return
	var choices := state.get("choices", []) as Array
	if choices.is_empty():
		return
	var random_index := _card_rng.randi_range(0, choices.size() - 1)
	_server_keep_card(peer_id, str(choices[random_index]), true)


func _server_check_card_drafts_completed() -> void:
	if not _card_draft_active:
		return
	for pid in players.keys():
		var peer_id := int(pid)
		var role := int(players[pid].get("role", Role.NONE))
		if role == Role.SPECTATOR or role == Role.NONE:
			continue
		var loadout := card_loadouts.get(peer_id, []) as Array
		if loadout.size() < CARD_DRAFT_REQUIRED_PICKS:
			return
	_card_draft_active = false
	_card_timer_sync_remaining = 0.0
	card_drafts_completed.emit()


func _is_card_pick_expired(state: Dictionary, now_msec: int = -1) -> bool:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var pick_expires_at_msec := int(state.get("pick_expires_at_msec", now_msec))
	var draft_expires_at_msec := int(state.get("draft_expires_at_msec", now_msec))
	return now_msec >= pick_expires_at_msec or now_msec >= draft_expires_at_msec


func _update_card_draft_remaining_fields(state: Dictionary, now_msec: int = -1) -> void:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var pick_expires_at_msec := int(state.get("pick_expires_at_msec", now_msec))
	var draft_expires_at_msec := int(state.get("draft_expires_at_msec", now_msec))
	state["pick_remaining_sec"] = maxf(0.0, float(pick_expires_at_msec - now_msec) / 1000.0)
	state["draft_remaining_sec"] = maxf(0.0, float(draft_expires_at_msec - now_msec) / 1000.0)


func _server_use_card_slot(peer_id: int, slot_index: int, intent_tick: int = -1, intent_sequence: int = 0) -> void:
	_record_card_intent(peer_id, slot_index, intent_tick, intent_sequence)
	if not players.has(peer_id):
		return
	var loadout := card_loadouts.get(peer_id, []) as Array
	if slot_index < 0 or slot_index >= loadout.size():
		return
	var slot := loadout[slot_index] as Dictionary
	var card_id := str(slot.get("id", ""))
	if bool(slot.get("used", false)) or card_id.is_empty():
		return
	if not CardDatabaseScript.is_manual(card_id):
		return
	slot["used"] = true
	loadout[slot_index] = slot
	card_loadouts[peer_id] = loadout
	_sync_card_loadout_to_peer(peer_id, loadout)
	_emit_card_activated(peer_id, card_id, slot_index)


func _cards_to_loadout(card_ids: Array) -> Array:
	var loadout: Array = []
	for card_id in card_ids:
		loadout.append({
			"id": str(card_id),
			"used": false,
		})
	return loadout


func _sync_card_draft_to_peer(peer_id: int, state: Dictionary) -> void:
	if peer_id == 1:
		_client_receive_card_draft(peer_id, state)
	elif _can_send_card_rpc_to_peer(peer_id):
		_client_receive_card_draft.rpc_id(peer_id, peer_id, state)


func _sync_card_loadout_to_peer(peer_id: int, loadout: Array) -> void:
	if peer_id == 1:
		_client_receive_card_loadout(peer_id, loadout)
	elif _can_send_card_rpc_to_peer(peer_id):
		_client_receive_card_loadout.rpc_id(peer_id, peer_id, loadout)


func _can_send_card_rpc_to_peer(peer_id: int) -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id)


func _emit_card_activated(peer_id: int, card_id: String, slot_index: int) -> void:
	card_activated.emit(peer_id, card_id, slot_index)
	_rpc_card_activated.rpc(peer_id, card_id, slot_index)


@rpc("authority", "call_remote", "reliable")
func _client_receive_card_draft(peer_id: int, state: Dictionary) -> void:
	if state.is_empty():
		card_drafts.erase(peer_id)
	else:
		card_drafts[peer_id] = state.duplicate(true)
	card_draft_updated.emit(peer_id, state.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _client_receive_card_loadout(peer_id: int, loadout: Array) -> void:
	card_loadouts[peer_id] = loadout.duplicate(true)
	card_loadout_updated.emit(peer_id, loadout.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _rpc_card_activated(peer_id: int, card_id: String, slot_index: int) -> void:
	card_activated.emit(peer_id, card_id, slot_index)


func _process(delta):
	_process_performance_telemetry(delta)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and _card_draft_active:
		_server_process_card_drafts(delta)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		if is_public_lobby_server():
			_public_lobby_process_rooms(delta)
		elif is_public_room_server():
			_public_room_process_heartbeat(delta)


func _process_performance_telemetry(delta: float) -> void:
	_perf_telemetry_enabled = _should_log_performance_telemetry()
	if not _perf_telemetry_enabled:
		if _perf_telemetry_elapsed > 0.0 or _perf_telemetry_frames > 0 or not _perf_telemetry_event_counts.is_empty() or not _perf_telemetry_event_bytes.is_empty():
			_reset_performance_telemetry_window()
		return
	_perf_telemetry_elapsed += delta
	_perf_telemetry_accumulated_delta += delta
	_perf_telemetry_worst_delta = maxf(_perf_telemetry_worst_delta, delta)
	_perf_telemetry_frames += 1
	if delta * 1000.0 >= PERF_TELEMETRY_SLOW_FRAME_MS:
		_perf_telemetry_slow_frames += 1
	if _perf_telemetry_elapsed < PERF_TELEMETRY_INTERVAL_SEC:
		return
	var avg_delta_ms := 0.0
	if _perf_telemetry_frames > 0:
		avg_delta_ms = (_perf_telemetry_accumulated_delta / float(_perf_telemetry_frames)) * 1000.0
	var worst_delta_ms := _perf_telemetry_worst_delta * 1000.0
	var peer_count := multiplayer.get_peers().size() if multiplayer.multiplayer_peer != null else 0
	var event_summary := _format_performance_telemetry_events()
	var event_kb := float(_performance_telemetry_total_event_bytes()) / 1024.0
	print("[Perf] role=%s fps=%.1f avg_ms=%.2f worst_ms=%.2f slow_frames=%d peers=%d players=%d rooms=%d room=%s port=%d event_kb=%.1f events=%s" % [
		_performance_telemetry_role(),
		Engine.get_frames_per_second(),
		avg_delta_ms,
		worst_delta_ms,
		_perf_telemetry_slow_frames,
		peer_count,
		players.size(),
		public_rooms.size(),
		active_public_room_id if not active_public_room_id.is_empty() else "-",
		server_port,
		event_kb,
		event_summary,
	])
	_reset_performance_telemetry_window()


func is_performance_telemetry_enabled() -> bool:
	if _perf_telemetry_enabled:
		return true
	_perf_telemetry_enabled = _should_log_performance_telemetry()
	return _perf_telemetry_enabled


func record_perf_event(key: String, count: int = 1, approx_bytes: int = 0) -> void:
	if count <= 0:
		return
	if not _perf_telemetry_enabled and not _should_log_performance_telemetry():
		return
	_perf_telemetry_enabled = true
	var clean_key := key.strip_edges()
	if clean_key.is_empty():
		return
	_perf_telemetry_event_counts[clean_key] = int(_perf_telemetry_event_counts.get(clean_key, 0)) + count
	if approx_bytes > 0:
		_perf_telemetry_event_bytes[clean_key] = int(_perf_telemetry_event_bytes.get(clean_key, 0)) + approx_bytes


func record_rpc_event(key: String, recipient_count: int = 1, approx_bytes_per_recipient: int = 0) -> void:
	if not _perf_telemetry_enabled and not _should_log_performance_telemetry():
		return
	var clean_key := key.strip_edges()
	if clean_key.is_empty():
		return
	if not clean_key.begins_with("rpc."):
		clean_key = "rpc." + clean_key
	var recipients := maxi(recipient_count, 1)
	record_perf_event(clean_key, recipients, maxi(approx_bytes_per_recipient, 0) * recipients)


func _should_log_performance_telemetry() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _perf_telemetry_enabled_cache_msec < PERF_TELEMETRY_ENV_CACHE_MSEC:
		return _perf_telemetry_enabled_cache
	var env := OS.get_environment("MAOMAO_PERF_LOG").strip_edges().to_lower()
	if env == "1" or env == "true" or env == "yes" or env == "on":
		_perf_telemetry_enabled_cache = true
	elif env == "0" or env == "false" or env == "no" or env == "off":
		_perf_telemetry_enabled_cache = false
	else:
		_perf_telemetry_enabled_cache = RuntimeMode.is_dedicated_public_server(multiplayer, lobby_config)
	_perf_telemetry_enabled_cache_msec = now_msec
	return _perf_telemetry_enabled_cache


func _performance_telemetry_role() -> String:
	if is_public_lobby_server():
		return "public_lobby"
	if is_public_room_server():
		return "public_room"
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		return "server"
	return "client"


func _format_performance_telemetry_events(max_keys: int = PERF_TELEMETRY_MAX_EVENT_KEYS) -> String:
	if _perf_telemetry_event_counts.is_empty():
		return "-"
	var remaining: Array = _perf_telemetry_event_counts.keys()
	var parts: Array[String] = []
	while not remaining.is_empty() and parts.size() < max_keys:
		var best_index := 0
		var best_count := int(_perf_telemetry_event_counts.get(remaining[0], 0))
		for index in range(1, remaining.size()):
			var count := int(_perf_telemetry_event_counts.get(remaining[index], 0))
			if count > best_count:
				best_index = index
				best_count = count
		var best_key := str(remaining[best_index])
		var bytes := int(_perf_telemetry_event_bytes.get(best_key, 0))
		var label := "%s:%d" % [best_key, best_count]
		if bytes > 0:
			label += "/%.1fkb" % (float(bytes) / 1024.0)
		parts.append(label)
		remaining.remove_at(best_index)
	if not remaining.is_empty():
		parts.append("+%d" % remaining.size())
	return ",".join(parts)


func _performance_telemetry_total_event_bytes() -> int:
	var total := 0
	for value in _perf_telemetry_event_bytes.values():
		total += int(value)
	return total


func _reset_performance_telemetry_window() -> void:
	_perf_telemetry_elapsed = 0.0
	_perf_telemetry_accumulated_delta = 0.0
	_perf_telemetry_worst_delta = 0.0
	_perf_telemetry_frames = 0
	_perf_telemetry_slow_frames = 0
	_perf_telemetry_enabled = false
	_perf_telemetry_enabled_cache_msec = -1000000
	_perf_telemetry_event_counts.clear()
	_perf_telemetry_event_bytes.clear()


func _ready() -> void:
	_card_rng.randomize()
	_ensure_noray_private_transport()
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)


func _ensure_noray_private_transport() -> NorayPrivateTransport:
	if _noray_private_transport != null:
		return _noray_private_transport
	_noray_private_transport = NorayPrivateTransportScript.new()
	_noray_private_transport.status_changed.connect(_on_noray_private_status_changed)
	_noray_private_transport.host_handshake_requested.connect(_on_noray_private_host_handshake_requested)
	return _noray_private_transport


func _on_noray_private_status_changed(status_key: String, is_error: bool) -> void:
	private_connection_status_changed.emit(status_key, is_error)
	_runtime_debug_log("[Network] Noray private status: ", status_key, " error=", is_error)


func _on_noray_private_host_handshake_requested(address: String, port: int) -> void:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	var error: int = await PacketHandshake.over_enet_peer(peer, address, port, 4.0, 0.1)
	if error != OK:
		_runtime_debug_log("[Network] Noray host handshake failed: ", error, " target=", address, ":", port)


func is_noray_join_target(value: String) -> bool:
	return NorayPrivateTransport.is_noray_target(value)


func private_noray_server_label() -> String:
	var transport: NorayPrivateTransport = _ensure_noray_private_transport()
	return "%s:%d" % [transport.noray_host, transport.noray_port]


func get_diagnostic_snapshot() -> Dictionary:
	var has_peer: bool = multiplayer.multiplayer_peer != null
	var peer_ids: Array[int] = []
	if has_peer:
		for peer_id: int in multiplayer.get_peers():
			peer_ids.append(peer_id)
	return {
		"mode": _diagnostic_connection_mode(),
		"role": _performance_telemetry_role(),
		"local_peer_id": local_peer_id(),
		"peer_assigned": has_peer,
		"is_server": multiplayer.is_server() if has_peer else false,
		"connection_status": multiplayer.multiplayer_peer.get_connection_status() if has_peer else MultiplayerPeer.CONNECTION_DISCONNECTED,
		"peers": peer_ids,
		"peer_count": peer_ids.size(),
		"players": players.size(),
		"server_port": server_port,
		"room": {
			"name": str(lobby_config.get("room_name", "")),
			"public_server": bool(lobby_config.get("public_server", false)),
			"public_lobby": bool(lobby_config.get("public_lobby", false)),
			"public_room_id": str(lobby_config.get("public_room_id", active_public_room_id)),
			"public_address": str(lobby_config.get("public_address", "")),
			"public_server_code": str(lobby_config.get("public_server_code", "")),
			"private_connection_mode": str(lobby_config.get("private_connection_mode", "direct")),
			"private_connection_code": str(lobby_config.get("private_connection_code", "")),
			"private_connection_server": str(lobby_config.get("private_connection_server", "")),
		},
		"noray": _diagnostic_noray_snapshot(),
		"rtt": _diagnostic_peer_stats(peer_ids),
		"netfox": _diagnostic_netfox_snapshot(),
		"simulator": _diagnostic_simulator_snapshot(),
		"sync_budget": _diagnostic_sync_budget_snapshot(),
		"card_intents": _last_card_intents.duplicate(true),
	}


func _diagnostic_connection_mode() -> String:
	if is_public_lobby_server():
		return "public_lobby_server"
	if is_public_room_server():
		return "public_room_server"
	if bool(lobby_config.get("public_lobby", false)):
		return "public_lobby_client"
	if bool(lobby_config.get("public_server", false)):
		return "public_room_client"
	var private_mode: String = str(lobby_config.get("private_connection_mode", "direct"))
	if private_mode == "noray":
		return "private_noray"
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		return "private_direct_host"
	if multiplayer.multiplayer_peer != null:
		return "private_direct_client"
	return "offline"


func _diagnostic_noray_snapshot() -> Dictionary:
	var transport: NorayPrivateTransport = _ensure_noray_private_transport()
	return transport.get_diagnostic_snapshot()


func _diagnostic_peer_stats(peer_ids: Array[int]) -> Dictionary:
	var result: Dictionary = {}
	var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return result
	var ids_to_check: Array[int] = peer_ids.duplicate()
	if ids_to_check.is_empty() and not multiplayer.is_server():
		ids_to_check.append(1)
	for peer_id: int in ids_to_check:
		var packet_peer: ENetPacketPeer = enet_peer.get_peer(peer_id)
		if packet_peer == null or not packet_peer.is_active():
			continue
		result[str(peer_id)] = {
			"state": packet_peer.get_state(),
			"remote": "%s:%d" % [packet_peer.get_remote_address(), packet_peer.get_remote_port()],
			"rtt_ms": packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),
			"last_rtt_ms": packet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME),
			"packet_loss": packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE),
			"throttle": packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE) / float(ENetPacketPeer.PACKET_THROTTLE_SCALE),
		}
	return result


func _diagnostic_netfox_snapshot() -> Dictionary:
	return {
		"tick": NetworkTime.tick,
		"tick_factor": NetworkTime.tick_factor,
		"ticktime": NetworkTime.ticktime,
		"tickrate_setting": int(ProjectSettings.get_setting(&"netfox/time/tickrate", 30)),
		"max_ticks_per_frame": int(ProjectSettings.get_setting(&"netfox/time/max_ticks_per_frame", 8)),
		"physics_tps": Engine.physics_ticks_per_second,
		"physics_interpolation": bool(ProjectSettings.get_setting(&"physics/common/physics_interpolation", false)),
		"remote_rtt_ms": NetworkTime.remote_rtt * 1000.0,
		"remote_rtt_jitter_ms": NetworkTimeSynchronizer.rtt_jitter * 1000.0,
		"network_loop_ms": NetworkPerformance.get_network_loop_duration_ms(),
		"network_ticks": NetworkPerformance.get_network_ticks(),
		"rollback_loop_ms": NetworkPerformance.get_rollback_loop_duration_ms(),
		"rollback_ticks": NetworkPerformance.get_rollback_ticks(),
		"rollback_nodes": NetworkPerformance.get_rollback_nodes_simulated(),
		"full_state_props": NetworkPerformance.get_full_state_props_count(),
		"sent_state_props": NetworkPerformance.get_sent_state_props_count(),
		"sent_state_ratio": NetworkPerformance.get_sent_state_props_ratio(),
	}


func _diagnostic_simulator_snapshot() -> Dictionary:
	return {
		"enabled": NetworkSimulator.enabled,
		"host": NetworkSimulator.hostname,
		"port": NetworkSimulator.server_port,
		"latency_ms": NetworkSimulator.latency_ms,
		"packet_loss_percent": NetworkSimulator.packet_loss_percent,
		"compression": NetworkSimulator.use_compression,
	}


func _diagnostic_sync_budget_snapshot() -> Dictionary:
	return {
		"perf_enabled": is_performance_telemetry_enabled(),
		"event_summary": _format_performance_telemetry_events(),
		"event_kb": float(_performance_telemetry_total_event_bytes()) / 1024.0,
		"slow_frames": _perf_telemetry_slow_frames,
		"frames": _perf_telemetry_frames,
		"avg_ms": (_perf_telemetry_accumulated_delta / float(maxi(_perf_telemetry_frames, 1))) * 1000.0,
		"worst_ms": _perf_telemetry_worst_delta * 1000.0,
	}


func set_network_simulator_diagnostics_enabled(enabled: bool, latency_ms: int = -1, packet_loss_percent: float = -1.0) -> String:
	NetworkSimulator.enabled = enabled
	ProjectSettings.set_setting(&"netfox/autoconnect/enabled", enabled)
	if latency_ms >= 0:
		NetworkSimulator.latency_ms = latency_ms
		ProjectSettings.set_setting(&"netfox/autoconnect/simulated_latency_ms", latency_ms)
	if packet_loss_percent >= 0.0:
		NetworkSimulator.packet_loss_percent = packet_loss_percent
		ProjectSettings.set_setting(&"netfox/autoconnect/simulated_packet_loss_chance", packet_loss_percent)
	return "NetworkSimulator %s latency=%dms loss=%.2f%% (applies to new autoconnect sessions)" % ["on" if enabled else "off", NetworkSimulator.latency_ms, NetworkSimulator.packet_loss_percent]


# =============================================================================
# 连接管理
# =============================================================================

func start_host(nickname: String, skin_color_str: String, host_role: int = Role.NONE, room_name: String = "", lobby_password: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	_redirecting_to_public_room = false
	_close_current_peer()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var requested_port: int = server_port
	var error: int = _create_host_peer_with_port_fallback(peer, requested_port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_configure_host_player_and_lobby(nickname, skin_color_str, host_role, room_name, lobby_password, character_model, "direct", "", "")
	return OK


func start_private_host(nickname: String, skin_color_str: String, host_role: int = Role.NONE, room_name: String = "", lobby_password: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	_redirecting_to_public_room = false
	_close_current_peer()
	var transport: NorayPrivateTransport = _ensure_noray_private_transport()
	var result: Dictionary = await transport.prepare_host(get_tree(), MAX_PLAYERS)
	var error: int = int(result.get("error", FAILED))
	if error != OK:
		return error
	var peer: ENetMultiplayerPeer = result.get("peer") as ENetMultiplayerPeer
	if peer == null:
		return ERR_CANT_CREATE
	server_port = int(result.get("local_port", server_port))
	multiplayer.multiplayer_peer = peer
	var share_code: String = str(result.get("share_code", ""))
	var server_label: String = "%s:%d" % [str(result.get("noray_host", "")), int(result.get("noray_port", 0))]
	_configure_host_player_and_lobby(nickname, skin_color_str, host_role, room_name, lobby_password, character_model, "noray", share_code, server_label)
	private_connection_share_updated.emit(share_code)
	return OK


func _configure_host_player_and_lobby(nickname: String, skin_color_str: String, host_role: int, room_name: String, lobby_password: String, character_model: String, connection_mode: String, connection_code: String, connection_server: String) -> void:
	if nickname.strip_edges().is_empty():
		nickname = "Host_" + str(local_peer_id())

	player_info["nick"] = nickname
	player_info["skin"] = skin_str_to_e(skin_color_str)
	player_info["character_model"] = normalize_character_model(character_model)
	player_info["party_monster_accessories"] = normalize_party_monster_accessories({}, str(player_info["character_model"]))
	player_info["role"] = host_role
	player_info["alive"] = true
	player_info["role_locked"] = false
	player_info["join_lobby_id"] = ""
	player_info["join_room_name"] = ""

	players.clear()
	lobby_config["room_name"] = _normalize_room_name(room_name, nickname)
	lobby_config["lobby_id"] = _normalize_lobby_password(lobby_password)
	if str(lobby_config["lobby_id"]).is_empty():
		lobby_config["lobby_id"] = _generate_lobby_id()
	lobby_config["steam_lobby_id"] = ""
	lobby_config["role_locked"] = false
	lobby_config["host_port"] = server_port
	lobby_config["public_server"] = false
	lobby_config["public_lobby"] = false
	lobby_config["public_room_id"] = ""
	lobby_config["public_address"] = ""
	lobby_config["public_server_code"] = ""
	lobby_config["private_connection_mode"] = connection_mode
	lobby_config["private_connection_code"] = connection_code
	lobby_config["private_connection_server"] = connection_server
	lobby_config["host_peer_id"] = 1
	lobby_config["host_peer_name"] = nickname

	players[1] = player_info.duplicate()
	player_connected.emit(1, players[1])


func _create_host_peer_with_port_fallback(peer: ENetMultiplayerPeer, requested_port: int) -> int:
	var first_port := requested_port if requested_port > 0 else SERVER_PORT
	for offset in range(HOST_PORT_FALLBACK_ATTEMPTS):
		var candidate_port := first_port + offset
		var error := peer.create_server(candidate_port, MAX_PLAYERS)
		if error == OK:
			if candidate_port != requested_port:
				_runtime_debug_log("[Network] Default host port unavailable; using fallback port ", candidate_port)
			server_port = candidate_port
			return OK
		if offset == 0:
			_runtime_debug_log("[Network] Could not create ENet host on port ", candidate_port, ": ", error)
		else:
			_runtime_debug_log("[Network] Could not create ENet host fallback port ", candidate_port, ": ", error)
	return ERR_CANT_CREATE


func _close_current_peer() -> void:
	if is_public_room_server():
		_delete_public_room_status_file()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _noray_private_transport != null:
		_noray_private_transport.reset(true)
	_has_received_full_sync = false
	_public_room_status_elapsed = 0.0
	_public_lobby_poll_elapsed = 0.0
	_public_lobby_snapshot_dirty = false
	_public_room_empty_elapsed = 0.0
	_public_room_runtime_ready = false


func start_public_lobby_server(public_address: String = "") -> int:
	_redirecting_to_public_room = false
	_close_current_peer()
	players.clear()
	card_drafts.clear()
	card_loadouts.clear()
	public_rooms.clear()
	peer_rooms.clear()
	active_public_room_id = ""
	_public_room_status_dir = _public_room_status_directory()
	_public_lobby_poll_elapsed = 0.0
	_public_lobby_snapshot_dirty = false
	_public_server_base_config = lobby_config.duplicate(true)

	var peer := ENetMultiplayerPeer.new()
	server_port = _env_int("MAOMAO_PUBLIC_PORT", SERVER_PORT)
	var error := peer.create_server(server_port, PUBLIC_SERVER_MAX_CLIENTS)
	if error != OK:
		_public_room_lifecycle_log("lobby_server_start_failed", "", {
			"port": server_port,
			"error": error,
		})
		return error
	multiplayer.multiplayer_peer = peer

	lobby_config["room_name"] = "Public Lobby"
	lobby_config["lobby_id"] = ""
	lobby_config["steam_lobby_id"] = ""
	lobby_config["role_locked"] = false
	lobby_config["host_port"] = server_port
	var external_address: String = _public_server_external_address(public_address)
	lobby_config["public_server"] = true
	lobby_config["public_lobby"] = true
	lobby_config["public_room_id"] = ""
	lobby_config["public_address"] = external_address
	lobby_config["public_server_code"] = public_server_code_for_address(external_address)
	lobby_config["host_peer_id"] = 0
	lobby_config["host_peer_name"] = ""
	_public_lobby_refresh_room_files()
	_public_room_lifecycle_log("lobby_server_started", "", {
		"port": server_port,
		"address": str(lobby_config["public_address"]),
		"server_code": str(lobby_config["public_server_code"]),
	})
	_runtime_debug_log("[Network] Public lobby server listening on UDP ", server_port, " address=", lobby_config["public_address"])
	return OK


func start_public_room_server_from_args() -> int:
	var port := _cmd_arg_int("--port", _env_int("MAOMAO_ROOM_PORT", server_port if server_port > 0 else PUBLIC_ROOM_PORT_START))
	var room_name := _cmd_arg_value("--room-name", OS.get_environment("MAOMAO_ROOM_NAME"))
	var lobby_password := _cmd_arg_value("--lobby-password", OS.get_environment("MAOMAO_ROOM_PASSWORD"))
	var room_id := _cmd_arg_value("--room-id", OS.get_environment("MAOMAO_ROOM_ID"))
	_public_room_status_dir = _cmd_arg_value("--status-dir", OS.get_environment("MAOMAO_ROOM_STATUS_DIR"))
	return start_public_room_server(room_name, lobby_password, port, room_id)


func start_public_room_server(room_name: String, lobby_password: String, port: int, room_id: String = "") -> int:
	_redirecting_to_public_room = false
	_close_current_peer()
	players.clear()
	card_drafts.clear()
	card_loadouts.clear()
	peer_rooms.clear()
	_public_room_status_elapsed = 0.0
	_public_room_empty_elapsed = 0.0
	_public_room_runtime_ready = false
	_public_room_created_msec = Time.get_ticks_msec()
	active_public_room_id = _public_room_key(room_name if not room_name.strip_edges().is_empty() else room_id)
	if not room_id.strip_edges().is_empty():
		active_public_room_id = room_id.strip_edges().to_lower()

	var peer := ENetMultiplayerPeer.new()
	server_port = port if port > 0 else PUBLIC_ROOM_PORT_START
	var error := peer.create_server(server_port, MAX_PLAYERS)
	if error != OK:
		_public_room_lifecycle_log("room_server_start_failed", active_public_room_id, {
			"port": server_port,
			"error": error,
			"room_name": room_name.strip_edges(),
		})
		return error
	multiplayer.multiplayer_peer = peer

	var normalized_room_name := _normalize_room_name(room_name, "Host")
	lobby_config["room_name"] = normalized_room_name
	lobby_config["lobby_id"] = _normalize_lobby_password(lobby_password)
	lobby_config["steam_lobby_id"] = ""
	lobby_config["role_locked"] = false
	lobby_config["host_port"] = server_port
	var external_address: String = _public_server_external_address("")
	lobby_config["public_server"] = true
	lobby_config["public_lobby"] = false
	lobby_config["public_room_id"] = active_public_room_id
	lobby_config["public_address"] = external_address
	lobby_config["public_server_code"] = public_server_code_for_address(external_address)
	lobby_config["host_peer_id"] = 0
	lobby_config["host_peer_name"] = ""
	_write_public_room_status()
	_public_room_lifecycle_log("room_server_started", active_public_room_id, {
		"room_name": normalized_room_name,
		"port": server_port,
		"locked": not str(lobby_config["lobby_id"]).is_empty(),
	})
	_runtime_debug_log("[Network] Public room server listening on UDP ", server_port, " room=", normalized_room_name, " locked=", not str(lobby_config["lobby_id"]).is_empty())
	return OK


func mark_public_room_runtime_ready() -> void:
	if not is_public_room_server():
		return
	_public_room_runtime_ready = true
	_public_room_status_elapsed = 0.0
	_write_public_room_status()
	_public_room_lifecycle_log("room_runtime_ready", active_public_room_id, {
		"room_name": str(lobby_config.get("room_name", "Public Room")),
		"port": int(lobby_config.get("host_port", server_port)),
	})


func is_public_lobby_server() -> bool:
	return RuntimeMode.is_public_lobby_server(multiplayer, lobby_config)


func is_public_room_server() -> bool:
	return RuntimeMode.is_public_room_server(multiplayer, lobby_config)


func is_public_lobby_server_command_line() -> bool:
	if is_public_room_server_command_line():
		return false
	return _cmd_arg_has("--maomao-public-server") or _cmd_arg_has("--public-server") or OS.get_environment("MAOMAO_PUBLIC_SERVER") == "1"


func is_public_room_server_command_line() -> bool:
	return _cmd_arg_has("--maomao-room-server") or OS.get_environment("MAOMAO_ROOM_SERVER") == "1"


func is_redirecting_to_public_room() -> bool:
	return _redirecting_to_public_room


func _public_server_external_address(override_address: String = "") -> String:
	var address: String = override_address.strip_edges()
	if address.is_empty():
		address = _cmd_arg_value("--public-address", OS.get_environment("MAOMAO_PUBLIC_ADDRESS"))
	if address.is_empty():
		address = PUBLIC_SERVER_ADDRESS
	return address


func public_server_code_for_address(address: String) -> String:
	var normalized_address: String = address.strip_edges()
	if normalized_address == PUBLIC_SERVER_ADDRESS:
		return PUBLIC_SERVER_PRIMARY_CODE
	if normalized_address == str(PUBLIC_SERVER_BACKUP_ADDRESSES[0]):
		return PUBLIC_SERVER_BACKUP_CODE_AL
	return "CUSTOM"


func join_public_lobby(nickname: String, skin_color_str: String, address: String = "%s:%d" % [PUBLIC_SERVER_ADDRESS, SERVER_PORT], client_role: int = Role.NONE, character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	_redirecting_to_public_room = false
	_public_lobby_failover_endpoints = _public_lobby_endpoint_candidates(address)
	_public_lobby_failover_index = 0
	_public_lobby_pending_context = {
		"nick": nickname,
		"skin": skin_color_str,
		"role": client_role,
		"character_model": character_model,
	}
	if _public_lobby_failover_endpoints.is_empty():
		return ERR_INVALID_PARAMETER
	return _connect_public_lobby_endpoint(_public_lobby_failover_endpoints[0])


func _public_lobby_endpoint_candidates(preferred_address: String) -> Array[String]:
	var endpoints: Array[String] = []
	_append_public_lobby_endpoint(endpoints, preferred_address)
	_append_public_lobby_endpoint(endpoints, "%s:%d" % [PUBLIC_SERVER_ADDRESS, SERVER_PORT])
	for backup_address in PUBLIC_SERVER_BACKUP_ADDRESSES:
		_append_public_lobby_endpoint(endpoints, "%s:%d" % [str(backup_address), SERVER_PORT])
	return endpoints


func _append_public_lobby_endpoint(endpoints: Array[String], endpoint_text: String) -> void:
	var clean_text := endpoint_text.strip_edges()
	if clean_text.is_empty():
		return
	var endpoint := _normalize_join_endpoint(clean_text)
	var host := str(endpoint.get("address", PUBLIC_SERVER_ADDRESS)).strip_edges()
	var port := int(endpoint.get("port", SERVER_PORT))
	if host.is_empty() or port <= 0:
		return
	var normalized := "%s:%d" % [host, port]
	if not endpoints.has(normalized):
		endpoints.append(normalized)


func _connect_public_lobby_endpoint(endpoint_text: String) -> int:
	_close_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var endpoint := _normalize_join_endpoint(endpoint_text)
	var address := str(endpoint.get("address", PUBLIC_SERVER_ADDRESS))
	server_port = int(endpoint.get("port", SERVER_PORT))
	var error := peer.create_client(address, server_port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	var nickname := str(_public_lobby_pending_context.get("nick", ""))
	if nickname.strip_edges().is_empty():
		nickname = "Player_" + str(local_peer_id())
	player_info["nick"] = nickname
	player_info["skin"] = skin_str_to_e(str(_public_lobby_pending_context.get("skin", "blue")))
	player_info["character_model"] = normalize_character_model(str(_public_lobby_pending_context.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	player_info["party_monster_accessories"] = normalize_party_monster_accessories({}, str(player_info["character_model"]))
	player_info["role"] = int(_public_lobby_pending_context.get("role", Role.NONE))
	player_info["alive"] = true
	player_info["role_locked"] = false
	player_info["join_lobby_id"] = ""
	player_info["join_room_name"] = ""
	players.clear()
	_runtime_debug_log("[Network] Connecting public lobby endpoint ", endpoint_text)
	public_lobby_connection_ready.emit()
	return OK


func _try_next_public_lobby_endpoint() -> bool:
	while _public_lobby_failover_index + 1 < _public_lobby_failover_endpoints.size():
		_public_lobby_failover_index += 1
		var endpoint_text := _public_lobby_failover_endpoints[_public_lobby_failover_index]
		_runtime_debug_log("[Network] Public lobby connection failed; trying backup endpoint ", endpoint_text)
		if _connect_public_lobby_endpoint(endpoint_text) == OK:
			return true
	return false


func _clear_public_lobby_failover() -> void:
	_public_lobby_failover_endpoints.clear()
	_public_lobby_failover_index = 0
	_public_lobby_pending_context.clear()


func request_public_room_list() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_request_public_room_list_rpc.rpc_id(1)


func request_create_public_room(room_name: String, lobby_password: String = "") -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var requested_room_name: String = room_name.strip_edges().substr(0, 32)
	if requested_room_name.is_empty():
		public_room_join_failed.emit("public_lobby.room_name_required")
		return
	_request_create_public_room_rpc.rpc_id(1, requested_room_name, _normalize_lobby_password(lobby_password))


func request_join_public_room(room_id: String, lobby_password: String = "") -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_request_join_public_room_rpc.rpc_id(1, room_id.strip_edges().to_lower(), _normalize_lobby_password(lobby_password))


func leave_public_lobby() -> void:
	_redirecting_to_public_room = false
	_close_current_peer()
	players.clear()
	public_lobby_snapshot_received.emit([])


func leave_current_lobby() -> void:
	_redirecting_to_public_room = false
	_close_current_peer()
	players.clear()
	card_drafts.clear()
	card_loadouts.clear()
	_has_received_full_sync = false


func _public_lobby_handle_room_request(peer_id: int, info: Dictionary) -> void:
	players[peer_id] = info.duplicate(true)
	_public_lobby_send_snapshot(peer_id)


@rpc("any_peer", "reliable")
func _request_public_room_list_rpc() -> void:
	if not is_public_lobby_server():
		return
	_public_lobby_refresh_room_files()
	_public_lobby_send_snapshot(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _request_create_public_room_rpc(room_name: String, lobby_id: String) -> void:
	if not is_public_lobby_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var requester: Dictionary = players.get(peer_id, {})
	var requester_name: String = str(requester.get("nick", "Host"))
	var requested_room_name: String = room_name.strip_edges().substr(0, 32)
	if requested_room_name.is_empty():
		_public_room_lifecycle_log("create_rejected", "", {
			"peer_id": peer_id,
			"requester": requester_name,
			"reason": "room_name_required",
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "public_lobby.room_name_required", false)
		_public_lobby_send_snapshot(peer_id)
		return
	var room_id: String = _public_room_key(requested_room_name)
	var requested_lobby_id: String = _normalize_lobby_password(lobby_id)
	_public_room_lifecycle_log("create_requested", room_id, {
		"peer_id": peer_id,
		"requester": requester_name,
		"room_name": requested_room_name,
		"locked": not requested_lobby_id.is_empty(),
	})
	_public_lobby_refresh_room_files()
	if public_rooms.has(room_id):
		_public_room_lifecycle_log("create_rejected", room_id, {
			"peer_id": peer_id,
			"requester": requester_name,
			"reason": "room_exists",
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.public_room_exists", false)
		_public_lobby_send_snapshot(peer_id)
		return
	var port := _public_lobby_allocate_room_port()
	if port <= 0:
		_public_room_lifecycle_log("create_rejected", room_id, {
			"peer_id": peer_id,
			"requester": requester_name,
			"reason": "no_public_room_ports",
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.no_public_room_ports", false)
		return
	var pid := _public_lobby_spawn_room_process(room_id, requested_room_name, requested_lobby_id, port)
	if pid < 0:
		_public_room_lifecycle_log("create_rejected", room_id, {
			"peer_id": peer_id,
			"requester": requester_name,
			"reason": "public_room_spawn_failed",
			"port": port,
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.public_room_spawn_failed", false)
		return
	var now := Time.get_unix_time_from_system()
	public_rooms[room_id] = {
		"room_id": room_id,
		"room_name": requested_room_name,
		"lobby_id": requested_lobby_id,
		"locked": not requested_lobby_id.is_empty(),
		"port": port,
		"process_id": pid,
		"host_peer_name": requester_name,
		"player_count": 0,
		"max_players": MAX_PLAYERS,
		"created_unix": now,
		"last_seen_unix": now,
		"ready": false,
	}
	_public_room_lifecycle_log("room_process_spawned", room_id, {
		"peer_id": peer_id,
		"requester": requester_name,
		"room_name": requested_room_name,
		"port": port,
		"pid": pid,
		"locked": not requested_lobby_id.is_empty(),
	})
	_runtime_debug_log("[Network] Public room created: ", requested_room_name, " port=", port, " pid=", pid)
	_public_lobby_mark_snapshot_dirty()
	_public_lobby_send_snapshot()
	if not await _public_lobby_wait_for_room_ready(room_id):
		_public_room_lifecycle_log("room_ready_timeout", room_id, {
			"peer_id": peer_id,
			"requester": requester_name,
			"room_name": requested_room_name,
			"port": port,
			"pid": pid,
		})
		public_rooms.erase(room_id)
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.public_room_not_ready", false)
		_public_lobby_mark_snapshot_dirty()
		_public_lobby_send_snapshot()
		return
	var ready_room: Dictionary = public_rooms.get(room_id, {})
	_public_room_lifecycle_log("creator_redirected", room_id, {
		"peer_id": peer_id,
		"requester": requester_name,
		"room_name": str(ready_room.get("room_name", requested_room_name)),
		"port": int(ready_room.get("port", port)),
	})
	_public_room_redirect_rpc.rpc_id(peer_id, _public_server_external_address(), int(ready_room.get("port", port)), str(ready_room.get("room_name", requested_room_name)), requested_lobby_id)


@rpc("any_peer", "reliable")
func _request_join_public_room_rpc(room_id: String, lobby_password: String) -> void:
	if not is_public_lobby_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	_public_lobby_refresh_room_files()
	var normalized_room_id: String = room_id.strip_edges().to_lower()
	_public_room_lifecycle_log("join_requested", normalized_room_id, {
		"peer_id": peer_id,
	})
	if not public_rooms.has(normalized_room_id):
		_public_room_lifecycle_log("join_rejected", normalized_room_id, {
			"peer_id": peer_id,
			"reason": "public_room_not_found",
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.public_room_not_found", false)
		_public_lobby_send_snapshot(peer_id)
		return
	var room: Dictionary = public_rooms.get(normalized_room_id, {})
	var expected_lobby_id: String = str(room.get("lobby_id", ""))
	if not expected_lobby_id.is_empty() and _normalize_lobby_password(lobby_password) != expected_lobby_id:
		_public_room_lifecycle_log("join_rejected", normalized_room_id, {
			"peer_id": peer_id,
			"reason": "wrong_password",
			"locked": true,
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.wrong_password", false)
		return
	if not await _public_lobby_wait_for_room_ready(normalized_room_id):
		_public_room_lifecycle_log("join_rejected", normalized_room_id, {
			"peer_id": peer_id,
			"reason": "public_room_not_ready",
			"port": int(room.get("port", PUBLIC_ROOM_PORT_START)),
		})
		_public_room_join_failed_rpc.rpc_id(peer_id, "join_status.public_room_not_ready", false)
		_public_lobby_send_snapshot(peer_id)
		return
	var ready_room: Dictionary = public_rooms.get(normalized_room_id, room)
	_public_room_lifecycle_log("joiner_redirected", normalized_room_id, {
		"peer_id": peer_id,
		"room_name": str(ready_room.get("room_name", normalized_room_id)),
		"port": int(ready_room.get("port", PUBLIC_ROOM_PORT_START)),
	})
	_public_room_redirect_rpc.rpc_id(peer_id, _public_server_external_address(), int(ready_room.get("port", PUBLIC_ROOM_PORT_START)), str(ready_room.get("room_name", normalized_room_id)), expected_lobby_id)


func _public_lobby_wait_for_room_ready(room_id: String, timeout_sec: float = PUBLIC_ROOM_READY_TIMEOUT_SEC) -> bool:
	var normalized_room_id := room_id.strip_edges().to_lower()
	var deadline_msec := Time.get_ticks_msec() + int(maxf(0.1, timeout_sec) * 1000.0)
	while Time.get_ticks_msec() <= deadline_msec:
		_public_lobby_refresh_room_files()
		var room: Dictionary = public_rooms.get(normalized_room_id, {})
		if _public_lobby_room_is_joinable(room, normalized_room_id):
			return true
		await get_tree().create_timer(0.15).timeout
	_public_lobby_refresh_room_files()
	var final_room: Dictionary = public_rooms.get(normalized_room_id, {})
	return _public_lobby_room_is_joinable(final_room, normalized_room_id)


func _public_lobby_room_is_joinable(room: Dictionary, room_id: String) -> bool:
	if room.is_empty():
		return false
	if str(room.get("room_id", "")).strip_edges().to_lower() != room_id:
		return false
	if int(room.get("port", -1)) <= 0:
		return false
	if not bool(room.get("ready", false)):
		return false
	var last_seen := float(room.get("last_seen_unix", 0.0))
	return Time.get_unix_time_from_system() - last_seen <= PUBLIC_ROOM_STALE_SECONDS


func _public_lobby_allocate_room_port() -> int:
	var used_ports: Array[int] = []
	for raw_room in public_rooms.values():
		var room: Dictionary = raw_room
		used_ports.append(int(room.get("port", -1)))
	var first_port := _env_int("MAOMAO_ROOM_PORT_START", PUBLIC_ROOM_PORT_START)
	var last_port := _env_int("MAOMAO_ROOM_PORT_END", PUBLIC_ROOM_PORT_END)
	for port in range(first_port, last_port + 1):
		if not used_ports.has(port):
			return port
	return -1


func _public_lobby_spawn_room_process(room_id: String, room_name: String, lobby_id: String, port: int) -> int:
	var executable := OS.get_executable_path()
	if executable.is_empty():
		return -1
	var args := _public_lobby_room_process_args(room_id, room_name, lobby_id, port)
	if _public_lobby_should_spawn_room_detached():
		var detached_pid := _public_lobby_spawn_room_detached(executable, args, room_id)
		if detached_pid > 0:
			return detached_pid
		_runtime_debug_log("[Network] Detached room launcher failed; falling back to child process.")
	return OS.create_process(executable, args, false)


func _public_lobby_room_process_args(room_id: String, room_name: String, lobby_id: String, port: int) -> PackedStringArray:
	var args := PackedStringArray()
	args.append("--headless")
	var pck_path: String = OS.get_environment("MAOMAO_PCK")
	if pck_path.is_empty():
		pck_path = _cmd_arg_value("--main-pack", "")
	if pck_path.is_empty() and OS.get_name() != "Windows" and FileAccess.file_exists("/opt/maomao/maomao_server.pck"):
		pck_path = "/opt/maomao/maomao_server.pck"
	if not pck_path.is_empty():
		args.append("--main-pack")
		args.append(pck_path)
	args.append("--")
	args.append("--maomao-room-server")
	args.append("--port")
	args.append(str(port))
	args.append("--room-name")
	args.append(room_name)
	args.append("--lobby-password")
	args.append(lobby_id)
	args.append("--room-id")
	args.append(room_id)
	args.append("--public-address")
	args.append(_public_server_external_address())
	args.append("--status-dir")
	args.append(_public_room_status_directory())
	return args


func _public_lobby_room_launch_mode() -> String:
	var mode := OS.get_environment(PUBLIC_ROOM_LAUNCH_MODE_ENV).strip_edges().to_lower()
	if mode == PUBLIC_ROOM_LAUNCH_MODE_CHILD or mode == "create_process":
		return PUBLIC_ROOM_LAUNCH_MODE_CHILD
	if mode == PUBLIC_ROOM_LAUNCH_MODE_DETACHED or mode == "nohup":
		return PUBLIC_ROOM_LAUNCH_MODE_DETACHED if _public_lobby_can_use_unix_shell() else PUBLIC_ROOM_LAUNCH_MODE_CHILD
	return PUBLIC_ROOM_LAUNCH_MODE_DETACHED if _public_lobby_can_use_unix_shell() else PUBLIC_ROOM_LAUNCH_MODE_CHILD


func _public_lobby_can_use_unix_shell() -> bool:
	return OS.get_name() != "Windows" and FileAccess.file_exists("/bin/sh")


func _public_lobby_should_spawn_room_detached() -> bool:
	return _public_lobby_room_launch_mode() == PUBLIC_ROOM_LAUNCH_MODE_DETACHED


func _public_lobby_spawn_room_detached(executable: String, args: PackedStringArray, room_id: String) -> int:
	var log_dir := _public_room_status_directory().path_join("logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var log_path := log_dir.path_join(_public_room_key(room_id) + ".log")
	var command_parts := PackedStringArray([_shell_quote_argument(executable)])
	for arg in args:
		command_parts.append(_shell_quote_argument(arg))
	var command := "nohup " + _join_shell_parts(command_parts) + " < /dev/null > " + _shell_quote_argument(log_path) + " 2>&1 & echo $!"
	var output: Array = []
	var exit_code := OS.execute("/bin/sh", PackedStringArray(["-c", command]), output, true, false)
	if exit_code != OK:
		push_warning("Public room detached launcher exited with code " + str(exit_code) + ": " + str(output))
		return -1
	var pid := _parse_detached_process_id(output)
	if pid <= 0:
		push_warning("Public room detached launcher did not return a valid pid: " + str(output))
		return -1
	_runtime_debug_log("[Network] Public room detached process started: room=", room_id, " pid=", pid, " log=", log_path)
	return pid


func _join_shell_parts(parts: PackedStringArray) -> String:
	var joined := ""
	for part in parts:
		if not joined.is_empty():
			joined += " "
		joined += part
	return joined


func _shell_quote_argument(value: String) -> String:
	return "'" + value.replace("'", "'\"'\"'") + "'"


func _parse_detached_process_id(output: Array) -> int:
	for entry in output:
		var lines := str(entry).split("\n", false)
		for raw_line in lines:
			var line := raw_line.strip_edges()
			if line.is_valid_int():
				return int(line)
	return -1


func _public_lobby_process_rooms(delta: float) -> void:
	_public_lobby_poll_elapsed += delta
	if _public_lobby_poll_elapsed >= PUBLIC_LOBBY_ROOM_POLL_INTERVAL_SEC:
		_public_lobby_poll_elapsed = 0.0
		_public_lobby_refresh_room_files()
	if _public_lobby_snapshot_dirty:
		_public_lobby_snapshot_dirty = false
		_public_lobby_send_snapshot()


func _public_room_process_heartbeat(delta: float) -> void:
	if active_public_room_id.is_empty():
		return
	_public_room_status_elapsed += delta
	var room_age_msec := Time.get_ticks_msec() - _public_room_created_msec
	if players.is_empty() and room_age_msec >= int(PUBLIC_ROOM_START_GRACE_SECONDS * 1000.0):
		_public_room_empty_elapsed += delta
	else:
		_public_room_empty_elapsed = 0.0
	if _public_room_status_elapsed >= PUBLIC_ROOM_STATUS_INTERVAL_SEC:
		_public_room_status_elapsed = 0.0
		_write_public_room_status()
	if _public_room_empty_elapsed >= PUBLIC_ROOM_EMPTY_TTL_SECONDS:
		_runtime_debug_log("[Network] Public room empty; shutting down room=", active_public_room_id)
		_delete_public_room_status_file("empty_ttl")
		get_tree().quit(0)


func _public_lobby_refresh_room_files() -> void:
	var status_dir := _public_room_status_directory()
	var dir := DirAccess.open(status_dir)
	var now := Time.get_unix_time_from_system()
	var seen_room_ids: Array[String] = []
	if dir != null:
		for file_name in DirAccess.get_files_at(status_dir):
			if not file_name.ends_with(".json"):
				continue
			var path := status_dir.path_join(file_name)
			var text := FileAccess.get_file_as_string(path)
			var parsed = JSON.parse_string(text)
			if not parsed is Dictionary:
				continue
			var room: Dictionary = parsed
			var room_id := str(room.get("room_id", "")).strip_edges().to_lower()
			if room_id.is_empty():
				continue
			var last_seen: float = float(room.get("last_seen_unix", now))
			if now - last_seen > PUBLIC_ROOM_STALE_SECONDS:
				var stale_removed: bool = DirAccess.remove_absolute(path) == OK
				_public_room_lifecycle_log("room_status_stale_file_removed", room_id, {
					"path": path,
					"removed": stale_removed,
					"last_seen_age_sec": now - last_seen,
				})
				continue
			seen_room_ids.append(room_id)
			var sanitized_room: Dictionary = _public_lobby_sanitize_room_record(room)
			var previous_room: Dictionary = public_rooms.get(room_id, {})
			if previous_room.is_empty():
				_public_room_lifecycle_log("room_status_seen", room_id, {
					"room_name": str(sanitized_room.get("room_name", room_id)),
					"port": int(sanitized_room.get("port", PUBLIC_ROOM_PORT_START)),
					"pid": int(sanitized_room.get("process_id", -1)),
					"ready": bool(sanitized_room.get("ready", false)),
				})
			elif bool(previous_room.get("ready", false)) != bool(sanitized_room.get("ready", false)):
				_public_room_lifecycle_log("room_status_ready_changed", room_id, {
					"room_name": str(sanitized_room.get("room_name", room_id)),
					"port": int(sanitized_room.get("port", PUBLIC_ROOM_PORT_START)),
					"ready": bool(sanitized_room.get("ready", false)),
				})
			elif int(previous_room.get("player_count", 0)) != int(sanitized_room.get("player_count", 0)):
				_public_room_lifecycle_log("room_status_players_changed", room_id, {
					"room_name": str(sanitized_room.get("room_name", room_id)),
					"player_count": int(sanitized_room.get("player_count", 0)),
				})
			if not public_rooms.has(room_id) or public_rooms.get(room_id, {}) != sanitized_room:
				_public_lobby_mark_snapshot_dirty()
			public_rooms[room_id] = sanitized_room
	var changed := false
	for key in public_rooms.keys():
		var room_id := str(key)
		if seen_room_ids.has(room_id):
			continue
		var room: Dictionary = public_rooms.get(room_id, {})
		var last_seen: float = float(room.get("last_seen_unix", now))
		if now - last_seen > PUBLIC_ROOM_STALE_SECONDS:
			_public_room_lifecycle_log("room_status_stale_cache_removed", room_id, {
				"room_name": str(room.get("room_name", room_id)),
				"port": int(room.get("port", PUBLIC_ROOM_PORT_START)),
				"last_seen_age_sec": now - last_seen,
			})
			public_rooms.erase(room_id)
			changed = true
	if changed:
		_public_lobby_mark_snapshot_dirty()


func _public_lobby_sanitize_room_record(room: Dictionary) -> Dictionary:
	var room_id := str(room.get("room_id", "")).strip_edges().to_lower()
	var lobby_id := _normalize_lobby_password(str(room.get("lobby_id", "")))
	return {
		"room_id": room_id,
		"room_name": _normalize_room_name(str(room.get("room_name", room_id)), str(room.get("host_peer_name", "Host"))),
		"lobby_id": lobby_id,
		"locked": bool(room.get("locked", not lobby_id.is_empty())),
		"port": int(room.get("port", PUBLIC_ROOM_PORT_START)),
		"process_id": int(room.get("process_id", -1)),
		"host_peer_name": str(room.get("host_peer_name", "")),
		"player_count": clampi(int(room.get("player_count", 0)), 0, MAX_PLAYERS),
		"max_players": int(room.get("max_players", MAX_PLAYERS)),
		"created_unix": float(room.get("created_unix", Time.get_unix_time_from_system())),
		"last_seen_unix": float(room.get("last_seen_unix", Time.get_unix_time_from_system())),
		"ready": bool(room.get("ready", false)),
	}


func _public_lobby_mark_snapshot_dirty() -> void:
	_public_lobby_snapshot_dirty = true


func _public_lobby_send_snapshot(peer_id: int = 0) -> void:
	var snapshot := _public_lobby_room_snapshot()
	if peer_id > 0:
		_public_lobby_snapshot_rpc.rpc_id(peer_id, snapshot)
	else:
		_public_lobby_snapshot_rpc.rpc(snapshot)


func _public_lobby_room_snapshot() -> Array:
	var rooms: Array = []
	for raw_room in public_rooms.values():
		var room: Dictionary = raw_room
		rooms.append({
			"room_id": str(room.get("room_id", "")),
			"room_name": str(room.get("room_name", "Public Room")),
			"locked": bool(room.get("locked", not str(room.get("lobby_id", "")).is_empty())),
			"player_count": int(room.get("player_count", 0)),
			"max_players": int(room.get("max_players", MAX_PLAYERS)),
			"host_peer_name": str(room.get("host_peer_name", "")),
			"port": int(room.get("port", PUBLIC_ROOM_PORT_START)),
			"ready": bool(room.get("ready", true)),
		})
	rooms.sort_custom(func(a, b): return str(a.get("room_name", "")) < str(b.get("room_name", "")))
	return rooms


@rpc("authority", "call_remote", "reliable")
func _public_lobby_snapshot_rpc(rooms: Array) -> void:
	public_lobby_snapshot_received.emit(rooms.duplicate(true))


func _write_public_room_status() -> void:
	if active_public_room_id.is_empty():
		return
	var status_dir := _public_room_status_directory()
	DirAccess.make_dir_recursive_absolute(status_dir)
	var status := {
		"room_id": active_public_room_id,
		"room_name": str(lobby_config.get("room_name", "Public Room")),
		"lobby_id": str(lobby_config.get("lobby_id", "")),
		"locked": not str(lobby_config.get("lobby_id", "")).is_empty(),
		"port": int(lobby_config.get("host_port", server_port)),
		"host_peer_name": str(lobby_config.get("host_peer_name", "")),
		"player_count": players.size(),
		"max_players": int(lobby_config.get("max_players", MAX_PLAYERS)),
		"created_unix": Time.get_unix_time_from_system() - (float(Time.get_ticks_msec() - _public_room_created_msec) / 1000.0),
		"last_seen_unix": Time.get_unix_time_from_system(),
		"ready": _public_room_runtime_ready,
	}
	var status_path: String = _public_room_status_path(active_public_room_id)
	var file: FileAccess = FileAccess.open(status_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(status))
	else:
		_public_room_lifecycle_log("room_status_write_failed", active_public_room_id, {
			"path": status_path,
		})


func _delete_public_room_status_file(reason: String = "cleanup") -> void:
	if active_public_room_id.is_empty():
		return
	var path: String = _public_room_status_path(active_public_room_id)
	var removed: bool = false
	if FileAccess.file_exists(path):
		removed = DirAccess.remove_absolute(path) == OK
	_public_room_lifecycle_log("room_status_deleted", active_public_room_id, {
		"reason": reason,
		"path": path,
		"removed": removed,
	})


func _public_room_status_directory() -> String:
	if not _public_room_status_dir.strip_edges().is_empty():
		return _public_room_status_dir.strip_edges()
	var status_dir := OS.get_environment("MAOMAO_ROOM_STATUS_DIR").strip_edges()
	if status_dir.is_empty():
		status_dir = _cmd_arg_value("--status-dir", "").strip_edges()
	if status_dir.is_empty():
		status_dir = OS.get_user_data_dir().path_join("public_rooms")
	_public_room_status_dir = status_dir
	return status_dir


func _public_room_status_path(room_id: String) -> String:
	var safe_id := _public_room_key(room_id).replace("/", "_").replace("\\", "_").replace(":", "_")
	return _public_room_status_directory().path_join(safe_id + ".json")


func _public_room_lifecycle_log_path() -> String:
	var override_path: String = OS.get_environment(PUBLIC_ROOM_LIFECYCLE_LOG_ENV).strip_edges()
	if not override_path.is_empty():
		return override_path
	return _public_room_status_directory().path_join("logs").path_join("room_lifecycle.jsonl")


func _public_room_lifecycle_log(event_name: String, room_id: String = "", details: Dictionary = {}) -> void:
	var normalized_room_id: String = room_id.strip_edges().to_lower()
	if normalized_room_id.is_empty():
		normalized_room_id = active_public_room_id.strip_edges().to_lower()
	var entry: Dictionary = {
		"ts_unix": Time.get_unix_time_from_system(),
		"event": event_name,
		"room_id": normalized_room_id,
		"mode": _diagnostic_connection_mode(),
		"public_address": str(lobby_config.get("public_address", "")),
		"public_server_code": str(lobby_config.get("public_server_code", "")),
		"server_port": server_port,
		"players": players.size(),
		"rooms": public_rooms.size(),
		"ready": _public_room_runtime_ready,
	}
	for raw_key in details.keys():
		var key: String = str(raw_key)
		if key == "lobby_id" or key == "password" or key == "lobby_password":
			continue
		entry[key] = details[raw_key]
	var log_path: String = _public_room_lifecycle_log_path()
	var log_dir: String = log_path.get_base_dir()
	if not log_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(log_dir)
	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write public room lifecycle log: " + log_path)
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))


func _server_prepare_public_room_host(peer_id: int, info: Dictionary) -> void:
	if not is_public_room_server():
		return
	if int(lobby_config.get("host_peer_id", 0)) > 0:
		return
	lobby_config["host_peer_id"] = peer_id
	lobby_config["host_peer_name"] = str(info.get("nick", "Host"))
	_public_room_lifecycle_log("room_host_assigned", active_public_room_id, {
		"peer_id": peer_id,
		"host_peer_name": str(lobby_config["host_peer_name"]),
	})
	_runtime_debug_log("[Network] Public room host assigned: peer=", peer_id, " name=", lobby_config["host_peer_name"])
	_write_public_room_status()


func _server_assign_public_room_host_if_needed() -> void:
	if not is_public_room_server():
		return
	var current_host := int(lobby_config.get("host_peer_id", 0))
	if current_host > 0 and players.has(current_host):
		return
	var ids := players.keys()
	if ids.is_empty():
		lobby_config["host_peer_id"] = 0
		lobby_config["host_peer_name"] = ""
		lobby_config["role_locked"] = false
		_public_room_lifecycle_log("room_host_cleared", active_public_room_id, {
			"reason": "no_players",
		})
		_write_public_room_status()
		return
	# Randomly hand the host role to a remaining player (the server decides and
	# then broadcasts the new lobby_config), so it isn't always the lowest peer id.
	var next_host := int(ids[randi() % ids.size()])
	lobby_config["host_peer_id"] = next_host
	lobby_config["host_peer_name"] = str(players[next_host].get("nick", "Host"))
	_public_room_lifecycle_log("room_host_transferred", active_public_room_id, {
		"peer_id": next_host,
		"host_peer_name": str(lobby_config["host_peer_name"]),
	})
	_runtime_debug_log("[Network] Public room host transferred: peer=", next_host, " name=", lobby_config["host_peer_name"])
	_write_public_room_status()


@rpc("authority", "call_remote", "reliable")
func _public_room_redirect_rpc(address: String, port: int, room_name: String, lobby_id: String) -> void:
	public_room_redirect_requested.emit(address, port, room_name, lobby_id)
	call_deferred("_connect_to_redirected_public_room", address, port, room_name, lobby_id)


@rpc("authority", "call_remote", "reliable")
func _public_room_join_failed_rpc(reason_key: String, close_peer: bool = true) -> void:
	public_room_join_failed.emit(reason_key)
	if close_peer:
		_close_current_peer()


func _connect_to_redirected_public_room(address: String, port: int, room_name: String, lobby_id: String) -> void:
	_redirecting_to_public_room = true
	_close_current_peer()
	await get_tree().process_frame
	var target := "%s:%d" % [address, port]
	var role := int(player_info.get("role", Role.NONE))
	var character_model := str(player_info.get("character_model", DEFAULT_CHARACTER_MODEL))
	var error: int = join_game(str(player_info.get("nick", "")), _skin_e_to_str(int(player_info.get("skin", SKIN_BLUE))), target, lobby_id, role, room_name, character_model)
	if error != OK:
		_redirecting_to_public_room = false
		public_room_join_failed.emit("join_status.failed")


func _cmd_arg_has(arg_name: String) -> bool:
	for arg in _cmd_args():
		if str(arg) == arg_name:
			return true
	return false


func _cmd_arg_value(arg_name: String, fallback: String = "") -> String:
	var args := _cmd_args()
	for index in range(args.size()):
		var arg := str(args[index])
		if arg == arg_name and index + 1 < args.size():
			return str(args[index + 1])
		if arg.begins_with(arg_name + "="):
			return arg.substr(arg_name.length() + 1)
	return fallback


func _cmd_arg_int(arg_name: String, fallback: int) -> int:
	var value := _cmd_arg_value(arg_name, "")
	if value.is_valid_int():
		return int(value)
	return fallback


func _cmd_args() -> PackedStringArray:
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	return args


func _env_int(env_name: String, fallback: int) -> int:
	var value := OS.get_environment(env_name)
	if value.is_valid_int():
		return int(value)
	return fallback


func _public_room_key(room_name: String) -> String:
	var key := room_name.strip_edges().to_lower()
	return key if not key.is_empty() else "public-room"


func join_private_game(nickname: String, skin_color_str: String, address: String = SERVER_ADDRESS, lobby_id: String = "", client_role: int = Role.NONE, room_name: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	if is_noray_join_target(address):
		return await _join_game_over_noray(nickname, skin_color_str, address, lobby_id, client_role, room_name, character_model)
	return join_game(nickname, skin_color_str, address, lobby_id, client_role, room_name, character_model)


func _join_game_over_noray(nickname: String, skin_color_str: String, target: String, lobby_id: String = "", client_role: int = Role.NONE, room_name: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	_close_current_peer()
	var transport: NorayPrivateTransport = _ensure_noray_private_transport()
	var result: Dictionary = await transport.prepare_client(get_tree(), target)
	var error: int = int(result.get("error", FAILED))
	if error != OK:
		return error
	var peer: ENetMultiplayerPeer = result.get("peer") as ENetMultiplayerPeer
	if peer == null:
		return ERR_CANT_CREATE
	server_port = int(result.get("port", server_port))
	_configure_join_player_info(nickname, skin_color_str, lobby_id, client_role, room_name, character_model)
	lobby_config["private_connection_mode"] = "noray_%s" % str(result.get("mode", "nat"))
	lobby_config["private_connection_code"] = target.strip_edges()
	lobby_config["private_connection_server"] = "%s:%d" % [str(result.get("noray_host", "")), int(result.get("noray_port", 0))]
	multiplayer.multiplayer_peer = peer
	return OK


func join_game(nickname: String, skin_color_str: String, address: String = SERVER_ADDRESS, lobby_id: String = "", client_role: int = Role.NONE, room_name: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> int:
	_close_current_peer()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var endpoint: Dictionary = _normalize_join_endpoint(address)
	var host_address: String = str(endpoint.get("address", SERVER_ADDRESS))
	server_port = int(endpoint.get("port", SERVER_PORT))
	var error: int = peer.create_client(host_address, server_port)
	if error != OK:
		return error

	_configure_join_player_info(nickname, skin_color_str, lobby_id, client_role, room_name, character_model)
	lobby_config["private_connection_mode"] = "direct"
	lobby_config["private_connection_code"] = ""
	lobby_config["private_connection_server"] = ""
	multiplayer.multiplayer_peer = peer
	return OK


func _configure_join_player_info(nickname: String, skin_color_str: String, lobby_id: String, client_role: int, room_name: String, character_model: String) -> void:
	var clean_nickname: String = nickname.strip_edges()
	if clean_nickname.is_empty():
		clean_nickname = "Player_" + str(local_peer_id())

	var skin_enum: int = skin_str_to_e(skin_color_str)
	player_info["nick"] = clean_nickname
	player_info["skin"] = skin_enum
	player_info["character_model"] = normalize_character_model(character_model)
	player_info["party_monster_accessories"] = normalize_party_monster_accessories({}, str(player_info["character_model"]))
	player_info["role"] = client_role
	player_info["alive"] = true
	player_info["role_locked"] = false
	player_info["join_lobby_id"] = lobby_id.strip_edges().to_upper()
	player_info["join_room_name"] = room_name.strip_edges()


# =============================================================================
# 角色选择 / 锁定
# =============================================================================

# 客户端调用:本地玩家选择角色 → 发送到服务器
func request_set_role(new_role: int) -> void:
	if not multiplayer.is_server():
		# 客户端:发 RPC 给服务器
		_request_set_role_rpc.rpc_id(1, new_role)
	else:
		# 服务器本地调用
		_server_apply_role(local_peer_id(), new_role)


@rpc("any_peer", "reliable")
func _request_set_role_rpc(new_role: int):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_server_apply_role(sender_id, new_role)


func _server_apply_role(peer_id: int, new_role: int) -> void:
	if not multiplayer.is_server():
		return
	if lobby_config.get("role_locked", false):
		push_warning("Roles are locked; ignoring set_role from " + str(peer_id))
		return
	if not players.has(peer_id):
		push_warning("Unknown player " + str(peer_id) + " set_role")
		return
	if new_role != Role.CHAMELEON and new_role != Role.STALKER and new_role != Role.HUNTER and new_role != Role.SPECTATOR:
		push_warning("Invalid role: " + str(new_role))
		return

	players[peer_id]["role"] = new_role
	player_role_changed.emit(peer_id, new_role)
	_broadcast_player_role.rpc(peer_id, new_role)
	_runtime_debug_log("[Network] Player ", peer_id, " selected role: ", ROLE_NAMES.get(new_role, "Unknown"))


@rpc("authority", "call_remote", "reliable")
func _broadcast_player_role(peer_id: int, new_role: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["role"] = new_role
	player_role_changed.emit(peer_id, new_role)


func request_set_character_model(model_id: String) -> void:
	var normalized := normalize_character_model(model_id)
	var default_loadout := normalize_party_monster_accessories({}, normalized)
	player_info["character_model"] = normalized
	player_info["party_monster_accessories"] = default_loadout
	var local_id := local_peer_id()
	if players.has(local_id):
		players[local_id]["character_model"] = normalized
		players[local_id]["party_monster_accessories"] = default_loadout
		player_character_model_changed.emit(local_id, normalized)
		player_party_monster_accessories_changed.emit(local_id, default_loadout)
	if multiplayer.is_server():
		server_set_player_character_model(local_id, normalized)
	else:
		_request_set_character_model_rpc.rpc_id(1, normalized)


@rpc("any_peer", "reliable")
func _request_set_character_model_rpc(model_id: String) -> void:
	if not multiplayer.is_server():
		return
	server_set_player_character_model(multiplayer.get_remote_sender_id(), model_id)


func server_set_player_character_model(peer_id: int, model_id: String) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(peer_id):
		return
	var normalized := normalize_character_model(model_id)
	var default_loadout := normalize_party_monster_accessories({}, normalized)
	players[peer_id]["character_model"] = normalized
	players[peer_id]["party_monster_accessories"] = default_loadout
	if peer_id == local_peer_id():
		player_info["character_model"] = normalized
		player_info["party_monster_accessories"] = default_loadout
	player_character_model_changed.emit(peer_id, normalized)
	player_party_monster_accessories_changed.emit(peer_id, default_loadout)
	_broadcast_player_character_model.rpc(peer_id, normalized, default_loadout)
	_broadcast_full_sync.rpc(players, lobby_config)
	players_synced.emit(players)


@rpc("authority", "call_remote", "reliable")
func _broadcast_player_character_model(peer_id: int, model_id: String, loadout: Dictionary = {}) -> void:
	var normalized := normalize_character_model(model_id)
	var clean_loadout := normalize_party_monster_accessories(loadout, normalized)
	if players.has(peer_id):
		players[peer_id]["character_model"] = normalized
		players[peer_id]["party_monster_accessories"] = clean_loadout
	if peer_id == local_peer_id():
		player_info["character_model"] = normalized
		player_info["party_monster_accessories"] = clean_loadout
	player_character_model_changed.emit(peer_id, normalized)
	player_party_monster_accessories_changed.emit(peer_id, clean_loadout)


func request_set_party_monster_accessories(loadout: Dictionary) -> void:
	var local_id := local_peer_id()
	var model_id := str(player_info.get("character_model", DEFAULT_CHARACTER_MODEL))
	var clean_loadout := normalize_party_monster_accessories(loadout, model_id)
	player_info["party_monster_accessories"] = clean_loadout
	if players.has(local_id):
		players[local_id]["party_monster_accessories"] = clean_loadout
		player_party_monster_accessories_changed.emit(local_id, clean_loadout)
	if multiplayer.is_server():
		server_set_player_party_monster_accessories(local_id, clean_loadout)
	else:
		_request_set_party_monster_accessories_rpc.rpc_id(1, clean_loadout)


@rpc("any_peer", "reliable")
func _request_set_party_monster_accessories_rpc(loadout: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	server_set_player_party_monster_accessories(multiplayer.get_remote_sender_id(), loadout)


func server_set_player_party_monster_accessories(peer_id: int, loadout: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(peer_id):
		return
	var model_id := str(players[peer_id].get("character_model", DEFAULT_CHARACTER_MODEL))
	var clean_loadout := normalize_party_monster_accessories(loadout, model_id)
	players[peer_id]["party_monster_accessories"] = clean_loadout
	if peer_id == local_peer_id():
		player_info["party_monster_accessories"] = clean_loadout
	player_party_monster_accessories_changed.emit(peer_id, clean_loadout)
	_broadcast_player_party_monster_accessories.rpc(peer_id, clean_loadout)
	_broadcast_full_sync.rpc(players, lobby_config)
	players_synced.emit(players)


@rpc("authority", "call_remote", "reliable")
func _broadcast_player_party_monster_accessories(peer_id: int, loadout: Dictionary) -> void:
	if not players.has(peer_id):
		return
	var model_id := str(players[peer_id].get("character_model", DEFAULT_CHARACTER_MODEL))
	var clean_loadout := normalize_party_monster_accessories(loadout, model_id)
	players[peer_id]["party_monster_accessories"] = clean_loadout
	if peer_id == local_peer_id():
		player_info["party_monster_accessories"] = clean_loadout
	player_party_monster_accessories_changed.emit(peer_id, clean_loadout)


# =============================================================================
# 1:3 自动分配(v0.3.2 锁定)
# =============================================================================

# 服务器调用:lock_roles 为 true 时用于正式开始比赛前锁定阵营。
func server_auto_balance_roles(lock_roles: bool = false) -> void:
	if not multiplayer.is_server():
		push_error("server_auto_balance_roles called on non-server")
		return

	var player_ids: Array = []
	for pid in players.keys():
		if players[pid].get("role", Role.NONE) != Role.SPECTATOR:
			player_ids.append(pid)

	var total = player_ids.size()
	if total < 1:
		_runtime_debug_log("[Network] Not enough players to start")
		return

	# 单人开发测试保留玩家选择；正式比例从 2 人起至少给 1 个 Hunter。
	if total == 1:
		var only_id = player_ids[0]
		var selected_role = players[only_id].get("role", Role.NONE)
		if selected_role == Role.NONE:
			selected_role = Role.CHAMELEON
		players[only_id]["role"] = selected_role
		players[only_id]["role_locked"] = lock_roles
		lobby_config["role_locked"] = lock_roles
		lobby_config["actual_hunter_count"] = 1 if selected_role == Role.HUNTER else 0
		lobby_config["actual_stalker_count"] = 1 if selected_role == Role.STALKER else 0
		lobby_config["actual_chameleon_count"] = 1 if selected_role == Role.CHAMELEON else 0
		player_role_changed.emit(only_id, selected_role)
		_broadcast_role_assignments.rpc(
			[only_id] if selected_role == Role.HUNTER else [],
			[only_id] if selected_role == Role.STALKER else [],
			[only_id] if selected_role == Role.CHAMELEON else [],
			lock_roles
		)
		_runtime_debug_log("[Network] Single-player dev assignment: ", only_id, " -> ", role_to_string(selected_role))
		roles_assigned.emit()
		return

	# 1. 计算 Hunter 数量。Host 可指定；否则按 1:3 自动。
	var configured_hunters = int(lobby_config.get("host_hunter_count", -1))
	var hunter_count = configured_hunters if configured_hunters > 0 else int(floor(total / 4.0))
	# 少人调试时至少 1 个 Hunter；4 人及以上仍符合 1:3。
	hunter_count = min(8, max(1, hunter_count))
	hunter_count = min(hunter_count, total - 1)
	var props_count = total - hunter_count
	var selected_stalker_count := 0
	for pid in player_ids:
		if int(players[pid].get("role", Role.NONE)) == Role.STALKER:
			selected_stalker_count += 1

	# 2. 计算 Stalker / Chameleon(默认 1:1)
	var stalker_count = int(floor(props_count / 2.0))
	var chameleon_count = props_count - stalker_count
	if selected_stalker_count > stalker_count:
		stalker_count = min(props_count, selected_stalker_count)
		chameleon_count = props_count - stalker_count

	_runtime_debug_log("[Network] Auto-balance: total=", total, " hunters=", hunter_count,
		" stalkers=", stalker_count, " chameleons=", chameleon_count)

	# 3. 收集所有玩家,按优先级排序(玩家自选的角色优先)
	var assigned_hunters: Array = []
	var assigned_stalkers: Array = []
	var assigned_chameleons: Array = []
	var to_assign: Array = []

	for pid in player_ids:
		var info = players[pid]
		var role = info.get("role", Role.NONE)
		match role:
			Role.SPECTATOR:
				continue
			Role.HUNTER:
				if assigned_hunters.size() < hunter_count:
					assigned_hunters.append(pid)
				else:
					to_assign.append(pid)
			Role.STALKER:
				if assigned_stalkers.size() < stalker_count:
					assigned_stalkers.append(pid)
				else:
					to_assign.append(pid)
			Role.CHAMELEON:
				if assigned_chameleons.size() < chameleon_count:
					assigned_chameleons.append(pid)
				else:
					to_assign.append(pid)
			_:
				to_assign.append(pid)

	# 4. 先填满 Hunter 槽位(没选 Hunter 的玩家,如果 Hunter 槽未满 → 强制 Hunter)
	#    注意:这是兜底,优先尊重玩家选择
	for pid in to_assign.duplicate():
		if assigned_hunters.size() < hunter_count:
			assigned_hunters.append(pid)
			to_assign.erase(pid)

	# 5. 剩余玩家分配为 Stalker / Chameleon
	for pid in to_assign:
		if assigned_stalkers.size() < stalker_count:
			assigned_stalkers.append(pid)
		elif assigned_chameleons.size() < chameleon_count:
			assigned_chameleons.append(pid)
		else:
			# 兜底:Hunter 还有空(理论上不会到这里,因为 1:3 已强制)
			assigned_hunters.append(pid)

	# 6. 应用分配 + 锁定角色
	for pid in assigned_hunters:
		players[pid]["role"] = Role.HUNTER
		players[pid]["role_locked"] = lock_roles
		player_role_changed.emit(pid, Role.HUNTER)
	for pid in assigned_stalkers:
		players[pid]["role"] = Role.STALKER
		players[pid]["role_locked"] = lock_roles
		player_role_changed.emit(pid, Role.STALKER)
	for pid in assigned_chameleons:
		players[pid]["role"] = Role.CHAMELEON
		players[pid]["role_locked"] = lock_roles
		player_role_changed.emit(pid, Role.CHAMELEON)

	lobby_config["role_locked"] = lock_roles
	lobby_config["actual_hunter_count"] = assigned_hunters.size()
	lobby_config["actual_stalker_count"] = assigned_stalkers.size()
	lobby_config["actual_chameleon_count"] = assigned_chameleons.size()

	_runtime_debug_log("[Network] Roles assigned: H=", assigned_hunters.size(),
		" S=", assigned_stalkers.size(), " C=", assigned_chameleons.size())

	# 7. 广播给所有客户端
	_broadcast_role_assignments.rpc(assigned_hunters, assigned_stalkers, assigned_chameleons, lock_roles)
	roles_assigned.emit()


@rpc("authority", "call_remote", "reliable")
func _broadcast_role_assignments(hunters: Array, stalkers: Array, chameleons: Array, lock_roles: bool = false):
	for pid in hunters:
		if players.has(pid):
			players[pid]["role"] = Role.HUNTER
			players[pid]["role_locked"] = lock_roles
			player_role_changed.emit(pid, Role.HUNTER)
	for pid in stalkers:
		if players.has(pid):
			players[pid]["role"] = Role.STALKER
			players[pid]["role_locked"] = lock_roles
			player_role_changed.emit(pid, Role.STALKER)
	for pid in chameleons:
		if players.has(pid):
			players[pid]["role"] = Role.CHAMELEON
			players[pid]["role_locked"] = lock_roles
			player_role_changed.emit(pid, Role.CHAMELEON)
	roles_assigned.emit()


# =============================================================================
# Lobby 配置管理(host 调用)
# =============================================================================

# 客户端(host)调用:更新 lobby 配置
func request_update_lobby_config(new_config: Dictionary) -> void:
	if multiplayer.is_server():
		_server_apply_lobby_config(new_config)
	else:
		_request_lobby_config_rpc.rpc_id(1, new_config)


func request_auto_assign_roles(new_config: Dictionary) -> void:
	if multiplayer.is_server():
		_server_apply_lobby_config(new_config)
		server_auto_balance_roles(false)
		_broadcast_full_sync.rpc(players, lobby_config)
		players_synced.emit(players)
	else:
		_request_auto_assign_rpc.rpc_id(1, new_config)


func request_start_match() -> void:
	if multiplayer.is_server():
		start_match_requested.emit()
	else:
		_request_start_match_rpc.rpc_id(1)


func can_peer_manage_lobby(peer_id: int) -> bool:
	if peer_id == 1 and not bool(lobby_config.get("public_server", false)):
		return true
	var configured_host_id := int(lobby_config.get("host_peer_id", 1))
	return configured_host_id > 0 and peer_id == configured_host_id


func can_local_peer_manage_lobby() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	return can_peer_manage_lobby(local_peer_id())


@rpc("any_peer", "reliable")
func _request_start_match_rpc():
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if not can_peer_manage_lobby(sender_id):
		push_warning("Non-host tried to start match")
		return
	start_match_requested.emit()


@rpc("any_peer", "reliable")
func _request_auto_assign_rpc(new_config: Dictionary):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if not can_peer_manage_lobby(sender_id):
		push_warning("Non-host tried to auto assign roles")
		return
	_server_apply_lobby_config(new_config)
	server_auto_balance_roles(false)
	_broadcast_full_sync.rpc(players, lobby_config)
	players_synced.emit(players)


@rpc("any_peer", "reliable")
func _request_lobby_config_rpc(new_config: Dictionary):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if not can_peer_manage_lobby(sender_id):
		push_warning("Non-host tried to update lobby config")
		return
	_server_apply_lobby_config(new_config)


func _server_apply_lobby_config(new_config: Dictionary) -> void:
	var protected_keys: Array[String] = ["public_server", "public_lobby", "public_room_id", "public_address", "public_server_code", "private_connection_mode", "private_connection_code", "private_connection_server", "host_peer_id", "host_peer_name", "host_port", "steam_lobby_id"]
	for key in new_config.keys():
		if lobby_config.has(key) and not protected_keys.has(str(key)):
			lobby_config[key] = new_config[key]
	lobby_config["lobby_id"] = str(lobby_config.get("lobby_id", "")).to_upper()
	lobby_config["stalker_glass_alpha_max"] = clampf(float(lobby_config.get("stalker_glass_alpha_max", 0.125)), 0.04, 0.24)
	if str(lobby_config.get("stalker_glass_material", "classic")) != "liquid_glass":
		lobby_config["stalker_glass_material"] = "classic"
	lobby_config["hunter_auto_turret_enabled"] = bool(lobby_config.get("hunter_auto_turret_enabled", false))
	lobby_config["hunter_auto_turret_range"] = clampf(float(lobby_config.get("hunter_auto_turret_range", 34.0)), 8.0, 60.0)
	_runtime_debug_log("[Network] Lobby config updated: ", lobby_config)
	lobby_config_updated.emit(lobby_config)
	_broadcast_lobby_config.rpc(lobby_config)


@rpc("authority", "call_remote", "reliable")
func _broadcast_lobby_config(config: Dictionary):
	lobby_config = config
	lobby_config_updated.emit(lobby_config)


# =============================================================================
# 多玩家回调
# =============================================================================

func _on_connected_ok():
	_clear_public_lobby_failover()
	# Re-arm server-protocol validation for this fresh connection (also covers the
	# public lobby -> room redirect, which connects a second time).
	_server_protocol_validated = false
	var peer_id = local_peer_id()
	if not players.has(peer_id):
		players[peer_id] = player_info.duplicate()
	player_connected.emit(peer_id, players[peer_id])
	_register_player.rpc_id(1, _handshake_registration_info())
	_request_full_sync.rpc_id(1)


func _on_player_connected(id):
	if DisplayServer.get_name() == "headless":
		return
	_register_player.rpc_id(id, player_info)


# Player info plus this build's handshake identity. Sent only to the server
# (peer 1) so it can reject incompatible clients before any gameplay RPC flows.
func _handshake_registration_info() -> Dictionary:
	var info: Dictionary = player_info.duplicate(true)
	info.merge(BuildInfo.handshake_payload(), true)
	return info


# Server -> client: the join was refused because of a network protocol mismatch.
# Surfaces a clear "update required" message instead of a later RPC crash.
@rpc("authority", "call_remote", "reliable")
func _rpc_reject_protocol(server_protocol: int, client_protocol: int, server_build_id: String) -> void:
	last_error = "版本不匹配 / Version mismatch: server protocol v%d, this client v%d. Please update before joining." % [server_protocol, client_protocol]
	push_warning(last_error + " (server build: " + server_build_id + ")")
	version_mismatch.emit(server_protocol, client_protocol, server_build_id)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	new_player_info["character_model"] = normalize_character_model(str(new_player_info.get("character_model", DEFAULT_CHARACTER_MODEL)))
	new_player_info["party_monster_accessories"] = normalize_party_monster_accessories(new_player_info.get("party_monster_accessories", {}), str(new_player_info["character_model"]))
	if not new_player_info.has("alive"):
		new_player_info["alive"] = true
	if multiplayer.is_server():
		# Version handshake is ADVISORY ONLY: log a protocol mismatch but never
		# disconnect. A gate that hard-kicks players (especially clients that simply
		# predate the handshake and send no protocol) is worse than the rare mismatch
		# it guards against; matched baseline deploys keep client/server in sync.
		var client_protocol := int(new_player_info.get("protocol_version", -1))
		if not BuildInfo.is_compatible(client_protocol):
			push_warning("Peer %d protocol v%d != server v%d (client build %s) — allowed (advisory handshake)." % [int(new_player_id), client_protocol, BuildInfo.NETWORK_PROTOCOL_VERSION, str(new_player_info.get("build_id", "?"))])
		# Handshake fields are transient; keep them out of the synced player record.
		new_player_info.erase("protocol_version")
		new_player_info.erase("build_id")
		new_player_info.erase("content_version")
		if is_public_lobby_server():
			_public_lobby_handle_room_request(new_player_id, new_player_info)
			return
		var provided_id = str(new_player_info.get("join_lobby_id", "")).to_upper()
		if not is_lobby_id_valid(provided_id):
			if is_public_room_server():
				_public_room_lifecycle_log("room_peer_rejected", active_public_room_id, {
					"peer_id": int(new_player_id),
					"reason": "wrong_lobby_id",
				})
			push_warning("Peer " + str(new_player_id) + " joined with wrong lobby id")
			multiplayer.multiplayer_peer.disconnect_peer(new_player_id)
			return
		var provided_room_name = str(new_player_info.get("join_room_name", ""))
		if not is_room_name_valid(provided_room_name):
			if is_public_room_server():
				_public_room_lifecycle_log("room_peer_rejected", active_public_room_id, {
					"peer_id": int(new_player_id),
					"reason": "wrong_room_name",
					"provided_room_name": provided_room_name,
				})
			push_warning("Peer " + str(new_player_id) + " joined with wrong room name")
			multiplayer.multiplayer_peer.disconnect_peer(new_player_id)
			return
		if is_public_room_server():
			_server_prepare_public_room_host(new_player_id, new_player_info)
	if not players.has(new_player_id):
		players[new_player_id] = new_player_info.duplicate()
	else:
		players[new_player_id].merge(new_player_info, true)
	player_connected.emit(new_player_id, players[new_player_id])
	if multiplayer.is_server():
		if is_public_room_server():
			_public_room_lifecycle_log("room_peer_joined", active_public_room_id, {
				"peer_id": new_player_id,
				"peer_name": str(players[new_player_id].get("nick", "")),
				"role": int(players[new_player_id].get("role", Role.NONE)),
			})
			_write_public_room_status()
		_broadcast_full_sync.rpc(players, lobby_config)


@rpc("any_peer", "reliable")
func _request_full_sync():
	if not multiplayer.is_server() or is_public_lobby_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	# 把所有玩家数据发给新客户端(附带服务器握手身份,供客户端校验协议版本)
	_broadcast_full_sync.rpc_id(sender_id, players, lobby_config, BuildInfo.handshake_payload())


@rpc("authority", "call_remote", "reliable")
func _broadcast_full_sync(all_players: Dictionary, config: Dictionary, server_info: Dictionary = {}):
	# Validate the server's protocol on the FIRST sync that actually carries the
	# server handshake (server_info). Plain 2-arg broadcasts (config / player-list
	# updates from _register_player etc.) routinely race ahead of this client's own
	# _request_full_sync response, so a missing server_info must NOT be treated as a
	# stale server — only a populated-but-incompatible server_info is a real mismatch.
	if not _server_protocol_validated and not server_info.is_empty() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_server_protocol_validated = true
		var server_protocol := int(server_info.get("protocol_version", -1))
		if not BuildInfo.is_compatible(server_protocol):
			var server_build := str(server_info.get("build_id", "?"))
			push_warning("Server protocol v%d != client v%d (server build %s) — proceeding (advisory handshake)." % [server_protocol, BuildInfo.NETWORK_PROTOCOL_VERSION, server_build])
			version_mismatch.emit(server_protocol, BuildInfo.NETWORK_PROTOCOL_VERSION, server_build)
	var previous_players := players.duplicate(true)
	var should_emit_diffs := _has_received_full_sync
	players = all_players
	lobby_config = config
	if _redirecting_to_public_room and bool(lobby_config.get("public_server", false)) and not bool(lobby_config.get("public_lobby", false)):
		_redirecting_to_public_room = false
	_has_received_full_sync = true
	lobby_config_updated.emit(lobby_config)
	if should_emit_diffs:
		_emit_player_sync_diffs(previous_players, players)
	players_synced.emit(players)


func _emit_player_sync_diffs(previous_players: Dictionary, synced_players: Dictionary) -> void:
	for pid in synced_players.keys():
		if not previous_players.has(pid):
			player_connected.emit(int(pid), synced_players[pid])
	for pid in previous_players.keys():
		if not synced_players.has(pid):
			player_disconnected.emit(int(pid))


func server_reset_alive_states() -> void:
	if not multiplayer.is_server():
		return
	for pid in players.keys():
		players[pid]["alive"] = true
	_broadcast_full_sync.rpc(players, lobby_config)
	players_synced.emit(players)


func server_set_player_alive(peer_id: int, alive: bool) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return
	if bool(players[peer_id].get("alive", true)) == alive:
		return
	players[peer_id]["alive"] = alive
	player_life_state_changed.emit(peer_id, alive)
	_broadcast_player_life_state.rpc(peer_id, alive)


@rpc("authority", "call_remote", "reliable")
func _broadcast_player_life_state(peer_id: int, alive: bool) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["alive"] = alive
	player_life_state_changed.emit(peer_id, alive)


func _on_player_disconnected(id):
	var disconnected_player: Dictionary = players.get(id, {})
	players.erase(id)
	player_disconnected.emit(id)
	if multiplayer.is_server():
		if is_public_lobby_server():
			_public_lobby_mark_snapshot_dirty()
			return
		if is_public_room_server():
			_public_room_lifecycle_log("room_peer_disconnected", active_public_room_id, {
				"peer_id": int(id),
				"peer_name": str(disconnected_player.get("nick", "")),
			})
		_server_assign_public_room_host_if_needed()
		if is_public_room_server():
			_write_public_room_status()
		_broadcast_full_sync.rpc(players, lobby_config)


func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	players.clear()
	if _redirecting_to_public_room:
		_redirecting_to_public_room = false
		_clear_public_lobby_failover()
		public_room_join_failed.emit("join_status.failed")
		return
	if _try_next_public_lobby_endpoint():
		return
	_clear_public_lobby_failover()
	public_lobby_snapshot_received.emit([])
	server_disconnected.emit()


func _on_server_disconnected():
	if _redirecting_to_public_room:
		return
	multiplayer.multiplayer_peer = null
	players.clear()
	public_lobby_snapshot_received.emit([])
	server_disconnected.emit()


# Client-side clean leave after detecting an incompatible server protocol on the
# first full sync. Tears down the peer so no gameplay RPC is ever processed.
func _leave_after_version_mismatch(message: String) -> void:
	last_error = message
	_redirecting_to_public_room = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	public_lobby_snapshot_received.emit([])
	server_disconnected.emit()


# =============================================================================
# 工具函数
# =============================================================================

func skin_str_to_e(s):
	match s.to_lower():
		"blue": return SKIN_BLUE
		"yellow": return SKIN_YELLOW
		"green": return SKIN_GREEN
		"red": return SKIN_RED
		_: return SKIN_BLUE


func _skin_e_to_str(skin_value: int) -> String:
	match skin_value:
		SKIN_YELLOW:
			return "yellow"
		SKIN_GREEN:
			return "green"
		SKIN_RED:
			return "red"
		_:
			return "blue"


func normalize_party_monster_accessories(value, model_id: String = "") -> Dictionary:
	return PartyMonsterAccessoryCatalogScript.sanitize_loadout(value, normalize_character_model(model_id))


func normalize_character_model(model_id: String) -> String:
	return CharacterSkinCatalogScript.normalize(model_id)


func role_to_string(r: int) -> String:
	return ROLE_NAMES.get(r, "Unknown")


# 获取指定角色的玩家 ID 列表
func get_players_by_role(role: int) -> Array:
	var result: Array = []
	for pid in players.keys():
		if players[pid].get("role", Role.NONE) == role:
			result.append(pid)
	return result


func get_hunters() -> Array:
	return get_players_by_role(Role.HUNTER)


func get_stalkers() -> Array:
	return get_players_by_role(Role.STALKER)


func get_chameleons() -> Array:
	return get_players_by_role(Role.CHAMELEON)


func get_props() -> Array:
	var result: Array = []
	result.append_array(get_chameleons())
	result.append_array(get_stalkers())
	return result


# 客户端:本地玩家自己的角色
func get_my_role() -> int:
	var my_id = local_peer_id()
	if players.has(my_id):
		return players[my_id].get("role", Role.NONE)
	return Role.NONE


func is_lobby_id_valid(provided_id: String) -> bool:
	var expected_id = str(lobby_config.get("lobby_id", "")).strip_edges().to_upper()
	return expected_id == "" or provided_id.strip_edges().to_upper() == expected_id


func is_room_name_valid(provided_room_name: String) -> bool:
	var expected_name := str(lobby_config.get("room_name", "")).strip_edges().to_lower()
	var received_name := provided_room_name.strip_edges().to_lower()
	return received_name.is_empty() or expected_name.is_empty() or received_name == expected_name


func _normalize_room_name(room_name: String, fallback_nick: String = "Host") -> String:
	var normalized := room_name.strip_edges()
	if normalized.is_empty():
		var host_name := fallback_nick.strip_edges()
		normalized = ("%s's Room" % host_name) if not host_name.is_empty() else "Private Match"
	return normalized.substr(0, 32)


func _normalize_lobby_password(value: String) -> String:
	var normalized := value.strip_edges().to_upper()
	if normalized.is_empty():
		return ""
	var output := ""
	for i in range(normalized.length()):
		var ch := normalized.substr(i, 1)
		if ch.is_valid_identifier() or ch.is_valid_int():
			output += ch
	return output.substr(0, 8)


func _normalize_join_address(address: String) -> String:
	return str(_normalize_join_endpoint(address).get("address", SERVER_ADDRESS))


func _normalize_join_endpoint(address: String) -> Dictionary:
	var normalized := address.strip_edges()
	if normalized.is_empty():
		normalized = SERVER_ADDRESS

	var host := normalized
	var port := server_port if server_port > 0 else SERVER_PORT
	var parsed_port := -1

	if normalized.begins_with("["):
		var close_index := normalized.find("]")
		if close_index > 0 and normalized.length() > close_index + 2 and normalized.substr(close_index + 1, 1) == ":":
			var bracket_port := normalized.substr(close_index + 2)
			if _is_valid_port_text(bracket_port):
				host = normalized.substr(1, close_index - 1)
				parsed_port = int(bracket_port)
	else:
		var first_colon := normalized.find(":")
		var last_colon := normalized.rfind(":")
		if first_colon > 0 and first_colon == last_colon:
			var port_text := normalized.substr(last_colon + 1)
			if _is_valid_port_text(port_text):
				host = normalized.substr(0, last_colon)
				parsed_port = int(port_text)

	host = host.strip_edges()
	if host.is_empty():
		host = SERVER_ADDRESS
	if parsed_port > 0:
		port = parsed_port

	return {
		"address": host,
		"port": port,
	}


func _is_valid_port_text(port_text: String) -> bool:
	var clean := port_text.strip_edges()
	if not clean.is_valid_int():
		return false
	var port := int(clean)
	return port > 0 and port <= 65535


func _generate_lobby_id() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in range(4):
		code += CHARS[rng.randi_range(0, CHARS.length() - 1)]
	return code
