extends Node3D
# =============================================================================
# Level 鈥?Prop Hunt 涓诲満鏅鐞嗗櫒(v0.3.3)
#
# 鐘舵€佹満:
#   LOBBY 鈫?绛夊緟鐜╁鍔犲叆 鈫?鐜╁閫夎亴涓?#   PREP   鈫?120s 鍊掕鏃?Hunter 鍦ㄥ噯澶囧,Props 鍦ㄦ垬鍦?#   PLAY   鈫?姣旇禌寮€濮?Hunter 瑙ｉ攣,鎵€鏈変汉杩涘叆涓绘垬鍦?#   END    鈫?鑳滆礋缁撶畻
# =============================================================================

# -----------------------------------------------------------------------------
# 鑺傜偣寮曠敤
# -----------------------------------------------------------------------------
@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: MainMenuUI = $MainMenuUI
@export var player_scene: PackedScene
const MatchIntroOverlayScript := preload("res://scripts/match_intro_overlay.gd")
const CharacterSetupOverlayScript := preload("res://scripts/character_setup_overlay.gd")
const LevelLayout := preload("res://scripts/level_layout_config.gd")
const RuntimeModeScript := preload("res://scripts/runtime_mode.gd")
const MapPropSyncBudgetScript := preload("res://scripts/map_prop_sync_budget.gd")
const NetworkInterestScript := preload("res://scripts/network_interest.gd")
const PartyMonsterAccessoryCatalogScript := preload("res://scripts/party_monster_accessory_catalog.gd")
const PartyMonsterAccessoryPickupScript := preload("res://scripts/party_monster_accessory_pickup.gd")
const PartyMonsterHuntHUDScript := preload("res://scripts/party_monster_hunt_hud.gd")
const DebugOverlayScript := preload("res://scripts/debug_overlay.gd")
const NetworkDiagnosticConsoleScript := preload("res://scripts/network_diagnostic_console.gd")
const HologramFlagScene := preload("res://scenes/effects/hologram_flag.tscn")
const BENCHMARK_WINDOW_SIZE := Vector2i(1280, 720)
const BENCHMARK_DECOR_VISIBILITY_RANGE := 90.0
const BENCHMARK_DECOR_VISIBILITY_MARGIN := 12.0
const MATCH_PERFORMANCE_DECOR_VISIBILITY_RANGE := 48.0
const MATCH_PERFORMANCE_DECOR_VISIBILITY_MARGIN := 6.0
const MATCH_PERFORMANCE_RUNTIME_PROP_VISIBILITY_RANGE := 28.0
const MATCH_PERFORMANCE_RUNTIME_PROP_VISIBILITY_MARGIN := 5.0
const MATCH_PERFORMANCE_PICKUP_VISIBILITY_RANGE := 26.0
const MATCH_PERFORMANCE_PICKUP_VISIBILITY_MARGIN := 4.0
const MATCH_PERFORMANCE_PICKUP_LABEL_VISIBILITY_RANGE := 18.0
const MATCH_PERFORMANCE_BOUNTY_BEACON_VISIBILITY_RANGE := 80.0
const MATCH_PERFORMANCE_BOUNTY_BEACON_VISIBILITY_MARGIN := 8.0
const MATCH_PERFORMANCE_PLAYER_VISUAL_VISIBILITY_RANGE := 80.0
const MATCH_PERFORMANCE_PLAYER_VISUAL_VISIBILITY_MARGIN := 8.0
const MATCH_PERFORMANCE_HEAVY_MAP_DECOR_VISIBILITY_RANGE := 30.0
const MATCH_PERFORMANCE_HEAVY_MAP_DECOR_VISIBILITY_MARGIN := 5.0
const MATCH_PERFORMANCE_HEAVY_MAP_DECOR_NAME_TOKENS := [
	"tree",
	"bridge",
	"big_",
	"mid_",
]
const MATCH_PERFORMANCE_HIDDEN_DECOR_NAME_TOKENS := [
	"fixeddecor_cozybeaver",
	"tanks_light_tank",
	"tank_light_model",
	"synty_car_small",
	"sm_polygoncity_veh_car_small",
	"tanks_busted_tank",
	"bustedtank",
]
const MATCH_PERFORMANCE_HIDDEN_DECOR_RESOURCE_TOKENS := [
	"meshy_ai_cozy_beaver",
	"tank_light_model",
	"sm_polygoncity_veh_car_small",
	"bustedtank",
]
const MATCH_PERFORMANCE_MAIN_SHADOW_DISTANCE := 28.0
const MATCH_PERFORMANCE_MAIN_SHADOW_BLUR := 0.2
const MATCH_PERFORMANCE_LIGHT_FADE_BEGIN := 22.0
const MATCH_PERFORMANCE_LIGHT_FADE_LENGTH := 8.0
const MATCH_PERFORMANCE_LIGHT_FADE_SHADOW := 12.0
const HUD_REFRESH_INTERVAL := 0.10
const MENU_BACKGROUND_NODE_PATHS := [
	"Environment",
	"PlayersContainer",
	"PreparationRoom",
	"HologramFlagContainer",
	"TrainingTargets",
]
const LOADING_TIPS := [
	"Tip: Hunters should listen for prop movement before committing to a chase.",
	"Tip: Props survive longer when they break line of sight before disguising.",
	"Tip: Stalkers can punish predictable patrol routes.",
	"Tip: Machine-gun tracers are easiest to read when you watch the impact sparks.",
	"Tip: Team balance is decided before loading finishes, so pick your role early.",
]
const LOADING_MIN_SECONDS := 1.25
const LOADING_TIP_SECONDS := 1.8
const LOADING_TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const LOADING_VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const LOADING_BODY_FONT_PATH := "res://assets/fonts/SairaCondensed-Medium.woff2"
const LOADING_START_COLOR := Color(0.18, 0.74, 1.0, 1.0)
const LOADING_BAND_BG_COLOR := Color(0.015, 0.035, 0.07, 0.82)
const LOADING_BAND_BORDER_COLOR := Color(0.40, 0.82, 1.0, 0.58)

@onready var multiplayer_chat: MultiplayerChatUI = $MultiplayerChatUI
@onready var inventory_ui: InventoryUI = $InventoryUI

# 鍑嗗瀹よ妭鐐?鏂板 v0.3.3 鈥?TASK-1.3 瀹炴柦鏃跺垱寤?
@onready var preparation_room: Node3D = $PreparationRoom if has_node("PreparationRoom") else null

# 鍑嗗闃舵鍊掕鏃?HUD(鍦?CanvasLayer 涓?纭繚鏈€涓婂眰娓叉煋)
@onready var prep_timer_label: Label = $HUDCanvas/PrepTimerLabel if has_node("HUDCanvas/PrepTimerLabel") else null
var status_label: Label = null
var combat_feedback_label: Label = null
var skill_hud = null
var card_hud = null
var health_hud = null
var world_nameplate_hud = null
var map_ping_hud = null
var match_status_hud = null
var party_monster_hunt_hud = null
var debug_overlay: DebugOverlay = null
var benchmark_mode_enabled := false
var _benchmark_restore_state: Dictionary = {}
var _benchmark_environment_state: Dictionary = {}
var _benchmark_light_states: Array[Dictionary] = []
var _benchmark_geometry_states: Array[Dictionary] = []
var _match_performance_policy_enabled := false
var _match_performance_environment_state: Dictionary = {}
var _match_performance_light_states: Array[Dictionary] = []
var _match_performance_geometry_states: Array[Dictionary] = []
var _match_performance_refresh_pending := false
var _training_targets_suspended_for_match := false
var _training_targets_process_mode_before_suspend := -1
var _preparation_room_process_mode_before_suspend := -1
var _menu_background_suspended := false
var _menu_world_environment_resource: Environment = null
var match_intro_overlay: MatchIntroOverlay = null
var character_setup_overlay: CharacterSetupOverlay = null
var loading_overlay_layer: CanvasLayer = null
var loading_root_control: Control = null
var loading_title_label: Label = null
var loading_map_label: Label = null
var loading_tip_label: Label = null
var loading_progress_bar: ProgressBar = null
var loading_progress_sweep: ColorRect = null
var loading_status_label: Label = null
var loading_percent_label: Label = null
var loading_scan_line: ColorRect = null
var loading_tip_timer: float = 0.0
var loading_tip_index: int = 0
var loading_overlay_time: float = 0.0
var loading_sequence_active: bool = false
var loading_title_font: Font = null
var loading_value_font: Font = null
var loading_body_font: Font = null
var loading_show_tween: Tween = null

# -----------------------------------------------------------------------------
# Game state
# -----------------------------------------------------------------------------
enum GameState {
	LOBBY,
	LOADING,
	CARD_DRAFT,
	SKIN_CONFIG,
	MATCH_INTRO,
	PREP,
	PLAY,
	END,
}

var game_state: GameState = GameState.LOBBY
var chat_visible = false
var inventory_visible = false
var pending_steam_join := {}
var pending_direct_join_lobby_id := ""
var pending_direct_join_waiting_for_sync := false
var _public_room_join_timeout_token := 0
var _public_lobby_room_request_token := 0
var _returning_to_public_lobby := false
var room_toast_layer: CanvasLayer = null
var room_toast_stack: VBoxContainer = null
var network_console_layer: CanvasLayer = null
var network_console_panel: PanelContainer = null
var network_console_output: RichTextLabel = null
var network_console_input: LineEdit = null
var _network_console_previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _console_drawer_height: float = 320.0
var _console_drawer_width: float = 600.0
var _console_player_locked: bool = false
var game_pause_menu: GamePauseMenu = null
var _pause_menu_active := false
var _console_history: PackedStringArray = PackedStringArray()
var _console_history_index: int = 0
var _known_player_names: Dictionary = {}
var _hologram_flag_states: Dictionary = {}
var _hologram_flag_intent_sequence: int = 0
var _quit_confirm_previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _map_prop_sync_budget: MapPropSyncBudget = MapPropSyncBudgetScript.new()
var _map_prop_impact_last_msec: Dictionary = {}
var _map_prop_spawn_queue: Array = []
var _map_prop_spawn_container: Node3D = null
var _map_prop_spawn_generation: int = 0
var _unity_decor_spawn_queue: Array = []
var _unity_decor_spawn_container: Node3D = null
var _unity_decor_spawn_generation: int = 0
var _unity_decor_scene_cache: Dictionary = {}
var _unity_decor_material_cache: Dictionary = {}
var _match_pickup_activation_queue: Array[Node] = []
var _match_pickup_activation_active := false
var _hud_refresh_elapsed: float = HUD_REFRESH_INTERVAL

var prep_timer: Timer = null
var prep_remaining: float = 0.0
var skin_config_remaining: float = 0.0
var match_intro_remaining: float = 0.0

var match_timer: Timer = null
var match_remaining: float = 0.0
var base_gravity_mps2: float = 9.8
var active_gravity_mps2: float = 9.8
var gravity_event_remaining: float = 0.0
var low_gravity_check_remaining: float = 0.0
var gravity_event_label := ""
var party_monster_bounty_accessories: Array = []
var party_monster_bounty_remaining := 0.0
var party_monster_bounty_next_timer := 0.0
var party_monster_bounty_marked_count := 0
var party_monster_bounty_clear_timer := 0.0
var _party_monster_rng := RandomNumberGenerator.new()
var _party_monster_accessory_spawn_round := 0

# -----------------------------------------------------------------------------
# Spawn 浣嶇疆閰嶇疆
# -----------------------------------------------------------------------------
const HUNTER_SPAWN_RADIUS: float = 5.0     # 鍑嗗瀹?Hunter 鍑虹敓鍗婂緞
const HUNTER_ROOM_OFFSET: Vector3 = Vector3(0, 0, -80)  # 鍑嗗瀹ょ浉瀵逛富鎴樺満鍋忕Щ

# Dynamic entity sizing stays here; placement density/radius lives in LevelLayout.
const MAP_PROP_MIN_SCALE_MULTIPLIER: float = 4.0
const MAP_PROP_MAX_SCALE_MULTIPLIER: float = 6.0
const MAP_PROP_MIN_COLLISION_RADIUS: float = 0.16
const MAP_PROP_MAX_COLLISION_RADIUS: float = 0.32
const UNITY_DECOR_COLLISION_LAYER: int = 2
const UNITY_DECOR_COLLISION_PADDING: Vector3 = Vector3(0.08, 0.04, 0.08)
const UNITY_DECOR_VISUAL_CULL_RANGE: float = 32.0
const UNITY_DECOR_VISUAL_CULL_MARGIN: float = 6.0
const MAP_PROP_IMPACT_MAX_DISTANCE: float = 4.5
const MAP_PROP_MOTION_SYNC_RELEVANCE_RADIUS: float = 20.0
const MAP_PROP_IMPACT_SERVER_MIN_INTERVAL_MSEC: int = 90
const MAP_PROP_IMPACT_THROTTLE_MAX_ENTRIES: int = 256
const MAP_PROP_IMPACT_THROTTLE_PRUNE_MSEC: int = 2000
const MAP_PROP_SPAWN_BATCH_SIZE: int = 2
const MAP_PROP_SPAWN_BATCH_DELAY_SECONDS: float = 1.0 / 60.0
const UNITY_DECOR_SPAWN_BATCH_SIZE: int = 3
const UNITY_DECOR_SPAWN_BATCH_DELAY_SECONDS: float = 1.0 / 60.0
const WORLD_COLLISION_MASK: int = 2
const TPS_DEMO_LEVEL_MAP_NAME := "TPS Demo Level"
const HOLOGRAM_FLAG_MAX_PLACE_DISTANCE: float = 18.0
const GROUND_RAY_UP: float = 80.0
const GROUND_RAY_DOWN: float = 160.0
const FIXED_SHADOW_COVER_GROUP := "stalker_shadow_caster"
const FIXED_SHADOW_ZONE_GROUP := "stalker_shadow_zone"
const RANDOM_DECOR_SHADOW_NOISE_GROUP := "dynamic_shadow_noise"
const FIXED_SHADOW_COVER_MATERIAL := Color(0.18, 0.14, 0.10, 1.0)
const TANK_DEMO_MAP_SCENES := {
	"Tank Demo Desert": "res://scenes/level/maps/tank_demo_desert.tscn",
	"Tank Demo Jungle": "res://scenes/level/maps/tank_demo_jungle.tscn",
	"Tank Demo Moon": "res://scenes/level/maps/tank_demo_moon.tscn",
	"TPS Demo Level": "res://scenes/level/maps/tps_demo_level.tscn",
	"garden": "res://scenes/level/maps/garden.tscn",
	"Japanese Town Street": "res://scenes/level/maps/japanese_town_street.tscn",
	"Western Town Prop Hunt": "res://scenes/level/maps/western_town_prop_hunt.tscn",
	"Polygon Apocalypse Bunker": "res://scenes/level/maps/polygon_apocalypse_bunker.tscn",
	"Polygon Apocalypse Interior": "res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn",
	"Polygon Apocalypse City": "res://scenes/level/maps/polygon_apocalypse_city_standard.tscn",
	"Polygon Apocalypse City URP": "res://scenes/level/maps/polygon_apocalypse_city_urp.tscn",
	"Polygon Apocalypse City: Downtown Escape": "res://scenes/level/maps/polygon_apocalypse_city_downtown_escape.tscn",
	"Polygon Apocalypse City: Quarantine Crossing": "res://scenes/level/maps/polygon_apocalypse_city_quarantine_crossing.tscn",
	"Polygon Apocalypse City: Market Row": "res://scenes/level/maps/polygon_apocalypse_city_market_row.tscn",
	"Polygon Apocalypse City: Overpass Camp": "res://scenes/level/maps/polygon_apocalypse_city_overpass_camp.tscn",
	"Polygon Apocalypse City: Warehouse Ward": "res://scenes/level/maps/polygon_apocalypse_city_warehouse_ward.tscn",
	"Polygon Apocalypse City URP: Downtown Escape": "res://scenes/level/maps/polygon_apocalypse_city_urp_downtown_escape.tscn",
	"Polygon Apocalypse City URP: Quarantine Crossing": "res://scenes/level/maps/polygon_apocalypse_city_urp_quarantine_crossing.tscn",
	"Polygon Apocalypse City URP: Market Row": "res://scenes/level/maps/polygon_apocalypse_city_urp_market_row.tscn",
	"Polygon Apocalypse City URP: Overpass Camp": "res://scenes/level/maps/polygon_apocalypse_city_urp_overpass_camp.tscn",
	"Polygon Apocalypse City URP: Warehouse Ward": "res://scenes/level/maps/polygon_apocalypse_city_urp_warehouse_ward.tscn",
}
const MATCH_INTRO_DURATION := 3.0
const PUBLIC_ROOM_JOIN_TIMEOUT_SEC := 40.0
const PUBLIC_LOBBY_ROOM_REQUEST_TIMEOUT_SEC := 45.0
const LOW_GRAVITY_MULTIPLIER := 0.42
const LOW_GRAVITY_EVENT_DURATION := 24.0
const LOW_GRAVITY_CHECK_INTERVAL := 18.0
const LOW_GRAVITY_EVENT_CHANCE := 0.34
const PARTY_MONSTER_ACCESSORY_MIN_PICKUPS := 21
const PARTY_MONSTER_ACCESSORY_MAX_PICKUPS := 24
const PARTY_MONSTER_ACCESSORY_MIN_DISTANCE := 5.5
const PARTY_MONSTER_ACCESSORY_MIN_PER_SLOT := 3
const MATCH_PICKUP_ACTIVATION_BATCH_SIZE := 2
const PARTY_MONSTER_BOUNTY_FIRST_DELAY := 18.0
const PARTY_MONSTER_BOUNTY_ACTIVE_SECONDS := 78.0
const PARTY_MONSTER_BOUNTY_REST_SECONDS := 22.0
const PARTY_MONSTER_BOUNTY_ESCAPE_REST_SECONDS := 12.0
const PARTY_MONSTER_BOUNTY_CLEAR_GRACE := 4.0


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
	var settings := _game_settings()
	if settings and settings.has_method("should_log_runtime_debug") and not bool(settings.call("should_log_runtime_debug")):
		return
	var output := ""
	for value in [value0, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11]:
		if value != null:
			output += str(value)
	print(output)


func _game_settings() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameSettings")


func _has_runtime_multiplayer_peer() -> bool:
	return RuntimeModeScript.has_multiplayer_peer(multiplayer)


func _is_multiplayer_server() -> bool:
	return RuntimeModeScript.is_multiplayer_server(multiplayer)


func _local_peer_id() -> int:
	if _has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	if Network.players.has(1):
		return 1
	return 1


# -----------------------------------------------------------------------------
# 鐢熷懡鍛ㄦ湡
# -----------------------------------------------------------------------------
func _ready():
	add_to_group("party_monster_level")
	_party_monster_rng.randomize()
	if DisplayServer.get_name() == "headless" and (Network.is_public_lobby_server_command_line() or Network.is_public_room_server_command_line()):
		_runtime_debug_log("Dedicated server starting...")
		var server_error := Network.start_public_room_server_from_args() if Network.is_public_room_server_command_line() else Network.start_public_lobby_server()
		if server_error != OK:
			push_error("Dedicated server failed to start. ENet error: " + str(server_error))

	_configure_match_lighting()
	_ensure_fixed_shadow_cover()
	var settings := _game_settings()
	var graphics_changed_callable: Callable = Callable(self, "_on_graphics_settings_changed")
	if settings and settings.has_signal("graphics_changed") and not settings.is_connected("graphics_changed", graphics_changed_callable):
		settings.connect("graphics_changed", graphics_changed_callable)

	multiplayer_chat.hide()
	multiplayer_chat.set_process_input(true)
	main_menu.show_menu()

	main_menu.host_pressed.connect(_on_host_pressed)
	main_menu.join_pressed.connect(_on_join_pressed)
	main_menu.public_server_pressed.connect(_on_public_server_pressed)
	main_menu.public_room_create_pressed.connect(_on_public_room_create_pressed)
	main_menu.public_room_join_pressed.connect(_on_public_room_join_pressed)
	main_menu.public_lobby_refresh_pressed.connect(_on_public_lobby_refresh_pressed)
	main_menu.public_lobby_leave_pressed.connect(_on_public_lobby_leave_pressed)
	main_menu.lobby_back_pressed.connect(_on_lobby_back_pressed)
	main_menu.lobby_leave_pressed.connect(_on_lobby_leave_pressed)
	main_menu.start_match_pressed.connect(_on_start_match_pressed)
	main_menu.auto_assign_pressed.connect(_on_auto_assign_pressed)
	main_menu.config_changed.connect(_on_lobby_config_changed)
	main_menu.lobby_chat_message_sent.connect(_on_lobby_chat_message_sent)
	main_menu.quit_pressed.connect(_on_quit_pressed)

	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	# 鏈嶅姟鍣ㄩ€昏緫
	Network.player_connected.connect(_on_player_connected)
	Network.players_synced.connect(_on_players_synced)
	Network.player_life_state_changed.connect(_on_player_life_state_changed)
	Network.player_character_model_changed.connect(_on_player_character_model_changed)
	Network.player_party_monster_accessories_changed.connect(_on_player_party_monster_accessories_changed)
	Network.skin_config_started.connect(_on_skin_config_started)
	Network.match_loading_started.connect(_on_match_loading_started)
	Network.match_intro_started.connect(_on_match_intro_started)
	Network.card_draft_updated.connect(_on_card_draft_updated)
	Network.card_loadout_updated.connect(_on_card_loadout_updated)
	Network.card_activated.connect(_on_card_activated)
	Network.card_drafts_completed.connect(_on_card_drafts_completed)
	if _is_multiplayer_server():
		multiplayer.peer_disconnected.connect(_remove_player)
		Network.roles_assigned.connect(_on_roles_assigned)

	Network.player_connected.connect(_refresh_lobby_ui)
	Network.player_disconnected.connect(_on_network_player_disconnected)
	Network.server_disconnected.connect(_on_server_disconnected)
	Network.public_lobby_snapshot_received.connect(_on_public_lobby_snapshot_received)
	Network.public_room_redirect_requested.connect(_on_public_room_redirect_requested)
	Network.public_room_join_failed.connect(_on_public_room_join_failed)
	Network.private_connection_status_changed.connect(_on_private_connection_status_changed)
	Network.lobby_config_updated.connect(func(_config):
		_refresh_lobby_ui()
	)
	Network.start_match_requested.connect(_server_start_from_lobby)
	SteamBridge.lobby_created.connect(_on_steam_lobby_created)
	SteamBridge.lobby_lookup_completed.connect(_on_steam_lobby_lookup_completed)

	# 瀹㈡埛绔篃鐩戝惉瑙掕壊鍙樺寲(鐢ㄤ簬 UI 鏇存柊)
	Network.player_role_changed.connect(_on_player_role_changed)

	# 鐩戝惉鍑嗗闃舵淇″彿
	Network.prep_phase_started.connect(_on_prep_phase_started)
	Network.prep_phase_ended.connect(_on_prep_phase_ended)
	Network.match_started.connect(_on_match_started)
	I18n.locale_changed.connect(func(_locale): _update_status_hud())

	# 鍑嗗瀹や綅缃亸绉?鍏抽敭:閬垮厤涓庝富鍦板浘鍦版澘閲嶅悎)
	if preparation_room:
		preparation_room.position = HUNTER_ROOM_OFFSET
		_set_preparation_room_active(true)
		_set_preparation_gate_open(false)

	_apply_runtime_graphics_settings()
	_sync_menu_background_performance_state(true)
	_ensure_debug_overlay()
	_ensure_status_hud()
	_ensure_skill_hud()
	_ensure_card_hud()
	_ensure_health_hud()
	_ensure_world_nameplate_hud()
	_ensure_map_ping_hud()
	_ensure_party_monster_hunt_hud()
	_ensure_match_intro_overlay()
	_ensure_character_setup_overlay()

	# Debug: 纭 HUD 鑺傜偣鎵惧埌
	_runtime_debug_log("[Level] _ready: prep_timer_label = ", prep_timer_label, " HUDCanvas found = ", has_node("HUDCanvas"))
	if Network.is_public_room_server():
		call_deferred("_mark_public_room_runtime_ready")


func _mark_public_room_runtime_ready() -> void:
	Network.mark_public_room_runtime_ready()


func _on_match_loading_started(map_name: String) -> void:
	if _is_multiplayer_server():
		return
	call_deferred("_begin_client_match_loading", map_name)


func _begin_client_match_loading(map_name: String) -> void:
	await _run_match_loading_sequence(map_name)
	if game_state == GameState.LOADING:
		_set_loading_progress(100.0, "Waiting for host...")


func _server_start_loading_phase() -> void:
	if not _is_multiplayer_server():
		return
	var selected_map := str(Network.lobby_config.get("map", "Warehouse"))
	Network.server_broadcast_match_loading_started(selected_map)
	await _run_match_loading_sequence(selected_map)
	if game_state != GameState.LOADING:
		return
	_hide_loading_overlay()
	_server_start_card_draft_phase()


func _run_match_loading_sequence(map_name: String) -> void:
	if loading_sequence_active:
		return
	loading_sequence_active = true
	game_state = GameState.LOADING
	if main_menu:
		main_menu.hide_menu()
	_set_hud_visible(false)
	_show_loading_overlay(map_name)
	_set_loading_progress(6.0, "Preparing lobby configuration...")
	await get_tree().process_frame
	await _preload_selected_map_resource(map_name)
	_set_loading_progress(78.0, "Mounting arena...")
	Network.lobby_config["map"] = map_name
	_apply_selected_map_scene()
	_apply_runtime_graphics_settings()
	await get_tree().process_frame
	_set_loading_progress(88.0, "Preparing players...")
	await get_tree().process_frame
	_set_loading_progress(96.0, "Finalizing match setup...")
	var started_msec := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < LOADING_MIN_SECONDS:
		await get_tree().process_frame
	_set_loading_progress(100.0, "Ready")
	loading_sequence_active = false


func _preload_selected_map_resource(map_name: String) -> void:
	if not TANK_DEMO_MAP_SCENES.has(map_name):
		_set_loading_progress(48.0, "Using default arena...")
		await get_tree().process_frame
		return
	var scene_path := str(TANK_DEMO_MAP_SCENES[map_name])
	_set_loading_progress(12.0, "Loading " + map_name + "...")
	if ResourceLoader.has_cached(scene_path):
		_set_loading_progress(70.0, "Arena already cached...")
		await get_tree().process_frame
		return
	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		var fallback := load(scene_path)
		if fallback is PackedScene:
			_set_loading_progress(70.0, "Arena loaded...")
		else:
			push_warning("Configured map scene did not load: " + scene_path)
		await get_tree().process_frame
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var ratio := 0.0
		if not progress.is_empty():
			ratio = clampf(float(progress[0]), 0.0, 1.0)
		_set_loading_progress(12.0 + ratio * 58.0, "Loading " + map_name + "...")
		await get_tree().process_frame
		progress.clear()
		status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(scene_path)
		_set_loading_progress(72.0, "Arena loaded...")
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_warning("Configured map scene did not load: " + scene_path)
	else:
		push_warning("Configured map scene load status was invalid: " + scene_path)
	await get_tree().process_frame


func _show_loading_overlay(map_name: String) -> void:
	_ensure_loading_overlay()
	loading_overlay_time = 0.0
	loading_overlay_layer.visible = true
	loading_tip_timer = LOADING_TIP_SECONDS
	loading_tip_index = randi() % maxi(LOADING_TIPS.size(), 1)
	if loading_map_label:
		loading_map_label.text = map_name.to_upper()
	if loading_root_control:
		loading_root_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if loading_title_label:
		loading_title_label.modulate = Color.WHITE
	if loading_progress_sweep:
		loading_progress_sweep.position = Vector2(-160.0, 0.0)
	_set_loading_tip(loading_tip_index, false)
	_set_loading_progress(0.0, "Loading " + map_name + "...")
	_start_loading_show_tween()


func _hide_loading_overlay() -> void:
	if loading_show_tween and loading_show_tween.is_valid():
		loading_show_tween.kill()
	if loading_root_control:
		loading_root_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if loading_overlay_layer:
		loading_overlay_layer.visible = false


func _ensure_loading_overlay() -> void:
	if loading_overlay_layer:
		return
	_ensure_loading_fonts()
	loading_overlay_layer = CanvasLayer.new()
	loading_overlay_layer.name = "MapLoadingOverlay"
	loading_overlay_layer.layer = 90
	loading_overlay_layer.visible = false
	add_child(loading_overlay_layer)

	loading_root_control = Control.new()
	loading_root_control.name = "LoadingRoot"
	loading_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay_layer.add_child(loading_root_control)

	var background := ColorRect.new()
	background.name = "BlueBackdrop"
	background.color = Color(0.006, 0.030, 0.075, 0.98)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_root_control.add_child(background)

	var upper_glow := ColorRect.new()
	upper_glow.name = "UpperCyanWash"
	upper_glow.color = Color(0.0, 0.58, 1.0, 0.18)
	upper_glow.anchor_right = 1.0
	upper_glow.offset_bottom = 220.0
	loading_root_control.add_child(upper_glow)

	var lower_glow := ColorRect.new()
	lower_glow.name = "LowerDeepBlueWash"
	lower_glow.color = Color(0.02, 0.16, 0.42, 0.26)
	lower_glow.anchor_top = 1.0
	lower_glow.anchor_right = 1.0
	lower_glow.anchor_bottom = 1.0
	lower_glow.offset_top = -260.0
	loading_root_control.add_child(lower_glow)

	loading_scan_line = ColorRect.new()
	loading_scan_line.name = "LoadingScanLine"
	loading_scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_scan_line.color = Color(0.65, 0.92, 1.0, 0.12)
	loading_scan_line.anchor_left = 0.0
	loading_scan_line.anchor_right = 1.0
	loading_scan_line.offset_top = -70.0
	loading_scan_line.offset_bottom = -68.0
	loading_root_control.add_child(loading_scan_line)

	var band := PanelContainer.new()
	band.name = "LoadingBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_left = 0.0
	band.offset_right = 0.0
	band.offset_top = -180.0
	band.offset_bottom = 180.0
	band.add_theme_stylebox_override("panel", _loading_band_style())
	loading_root_control.add_child(band)

	var content := VBoxContainer.new()
	content.name = "LoadingContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(980.0, 300.0)
	content.add_theme_constant_override("separation", 12)
	band.add_child(content)

	var eyebrow := _make_loading_label("ARENA SYNC", 20, Color(0.62, 0.90, 1.0, 0.78), _get_loading_value_font(), 3)
	eyebrow.name = "LoadingEyebrow"
	content.add_child(eyebrow)

	loading_title_label = _make_loading_label("LOADING MATCH", 58, LOADING_START_COLOR, _get_loading_title_font(), 8)
	loading_title_label.name = "LoadingTitle"
	content.add_child(loading_title_label)

	loading_map_label = _make_loading_label("", 22, Color(0.88, 0.94, 1.0, 0.76), _get_loading_body_font(), 2)
	loading_map_label.name = "LoadingMapName"
	content.add_child(loading_map_label)

	loading_tip_label = _make_loading_label("", 25, Color(0.90, 0.97, 1.0, 0.94), _get_loading_value_font(), 4)
	loading_tip_label.name = "LoadingTip"
	loading_tip_label.custom_minimum_size = Vector2(900.0, 52.0)
	loading_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(loading_tip_label)

	var progress_group := PanelContainer.new()
	progress_group.name = "LoadingProgressGroup"
	progress_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	progress_group.custom_minimum_size = Vector2(920.0, 58.0)
	progress_group.add_theme_stylebox_override("panel", _loading_style(Color(0.010, 0.040, 0.105, 0.70), Color(0.35, 0.82, 1.0, 0.42), 1, 12))
	content.add_child(progress_group)

	var progress_row := HBoxContainer.new()
	progress_row.name = "LoadingProgressRow"
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_row.add_theme_constant_override("separation", 10)
	progress_group.add_child(progress_row)

	loading_progress_bar = ProgressBar.new()
	loading_progress_bar.name = "LoadingProgressBar"
	loading_progress_bar.min_value = 0.0
	loading_progress_bar.max_value = 100.0
	loading_progress_bar.step = 0.1
	loading_progress_bar.show_percentage = false
	loading_progress_bar.clip_contents = true
	loading_progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	loading_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loading_progress_bar.custom_minimum_size = Vector2(760.0, 34.0)
	loading_progress_bar.add_theme_stylebox_override("background", _loading_style(Color(0.006, 0.050, 0.135, 0.98), Color(0.42, 0.86, 1.0, 0.84), 2, 10))
	loading_progress_bar.add_theme_stylebox_override("fill", _loading_style(Color(0.05, 0.74, 1.0, 1.0), Color(0.88, 0.98, 1.0, 0.96), 2, 10))
	progress_row.add_child(loading_progress_bar)

	loading_progress_sweep = ColorRect.new()
	loading_progress_sweep.name = "LoadingProgressSweep"
	loading_progress_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_progress_sweep.color = Color(0.92, 1.0, 1.0, 0.34)
	loading_progress_sweep.position = Vector2(-160.0, 0.0)
	loading_progress_sweep.size = Vector2(150.0, 34.0)
	loading_progress_bar.add_child(loading_progress_sweep)

	loading_percent_label = _make_loading_label("0%", 38, Color(1.0, 1.0, 1.0, 0.96), _get_loading_value_font(), 8)
	loading_percent_label.name = "LoadingPercent"
	loading_percent_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	loading_percent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loading_percent_label.custom_minimum_size = Vector2(88.0, 44.0)
	progress_row.add_child(loading_percent_label)

	loading_status_label = _make_loading_label("", 17, Color(0.64, 0.84, 0.98, 0.84), _get_loading_body_font(), 2)
	loading_status_label.name = "LoadingStatus"
	loading_status_label.custom_minimum_size = Vector2(900.0, 28.0)
	content.add_child(loading_status_label)


func _ensure_loading_fonts() -> void:
	if loading_title_font and loading_value_font and loading_body_font:
		return
	loading_title_font = _load_loading_font(LOADING_TITLE_FONT_PATH)
	loading_value_font = _load_loading_font(LOADING_VALUE_FONT_PATH)
	loading_body_font = _load_loading_font(LOADING_BODY_FONT_PATH)


func _load_loading_font(path: String) -> Font:
	var resource: Resource = load(path)
	return resource if resource is Font else null


func _get_loading_title_font() -> Font:
	return loading_title_font if loading_title_font else ThemeDB.fallback_font


func _get_loading_value_font() -> Font:
	return loading_value_font if loading_value_font else _get_loading_title_font()


func _get_loading_body_font() -> Font:
	return loading_body_font if loading_body_font else _get_loading_value_font()


func _make_loading_label(text: String, font_size: int, color: Color, font: Font, outline_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _loading_band_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LOADING_BAND_BG_COLOR
	style.border_color = LOADING_BAND_BORDER_COLOR
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 48.0
	style.content_margin_right = 48.0
	style.content_margin_top = 30.0
	style.content_margin_bottom = 30.0
	return style


func _loading_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.15, 0.68, 1.0, 0.18)
	style.shadow_size = 8 if border_width > 0 else 0
	return style


func _start_loading_show_tween() -> void:
	if not loading_root_control:
		return
	if loading_show_tween and loading_show_tween.is_valid():
		loading_show_tween.kill()
	loading_show_tween = create_tween()
	loading_show_tween.tween_property(loading_root_control, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_loading_progress(value: float, status_text: String) -> void:
	if not loading_progress_bar:
		return
	var progress := clampf(value, 0.0, 100.0)
	loading_progress_bar.value = progress
	if loading_percent_label:
		loading_percent_label.text = "%d%%" % int(round(progress))
	if loading_status_label:
		loading_status_label.text = status_text.to_upper()
	if loading_progress_sweep:
		loading_progress_sweep.visible = progress > 1.0


func _update_loading_tip(delta: float) -> void:
	if not loading_overlay_layer or not loading_overlay_layer.visible:
		return
	_update_loading_overlay_motion(delta)
	loading_tip_timer -= delta
	if loading_tip_timer <= 0.0:
		loading_tip_index = (loading_tip_index + 1) % maxi(LOADING_TIPS.size(), 1)
		_set_loading_tip(loading_tip_index)
		loading_tip_timer = LOADING_TIP_SECONDS


func _update_loading_overlay_motion(delta: float) -> void:
	loading_overlay_time += delta
	var pulse := 0.5 + 0.5 * sin(loading_overlay_time * TAU * 0.72)
	if loading_title_label:
		var title_color: Color = LOADING_START_COLOR.lerp(Color(0.75, 0.95, 1.0, 1.0), pulse * 0.35)
		loading_title_label.add_theme_color_override("font_color", title_color)
		var title_modulate: Color = loading_title_label.modulate
		title_modulate.a = 0.92 + pulse * 0.08
		loading_title_label.modulate = title_modulate
	if loading_scan_line:
		var viewport_height: float = maxf(1.0, get_viewport().get_visible_rect().size.y)
		var scan_y: float = fposmod(loading_overlay_time * 115.0, viewport_height + 140.0) - 70.0
		loading_scan_line.offset_top = scan_y
		loading_scan_line.offset_bottom = scan_y + 2.0
		var scan_color: Color = loading_scan_line.color
		scan_color.a = 0.10 + pulse * 0.06
		loading_scan_line.color = scan_color
	if loading_progress_sweep and loading_progress_bar:
		var bar_width: float = maxf(loading_progress_bar.size.x, loading_progress_bar.custom_minimum_size.x)
		var bar_height: float = maxf(loading_progress_bar.size.y, loading_progress_bar.custom_minimum_size.y)
		loading_progress_sweep.size = Vector2(150.0, bar_height)
		loading_progress_sweep.position = Vector2(fposmod(loading_overlay_time * 310.0, bar_width + 170.0) - 160.0, 0.0)
	if loading_tip_label:
		var tip_modulate: Color = loading_tip_label.modulate
		tip_modulate.a = move_toward(tip_modulate.a, 1.0, delta * 2.8)
		loading_tip_label.modulate = tip_modulate
	if loading_percent_label:
		var percent_modulate: Color = loading_percent_label.modulate
		percent_modulate.a = 0.90 + pulse * 0.10
		loading_percent_label.modulate = percent_modulate


func _set_loading_tip(index: int, animate: bool = true) -> void:
	if not loading_tip_label or LOADING_TIPS.is_empty():
		return
	loading_tip_label.text = str(LOADING_TIPS[index % LOADING_TIPS.size()])
	var tip_modulate: Color = loading_tip_label.modulate
	tip_modulate.a = 0.42 if animate else 1.0
	loading_tip_label.modulate = tip_modulate


func _apply_selected_map_scene() -> void:
	var environment := get_node_or_null("Environment") as Node3D
	if not environment:
		return
	var existing := environment.get_node_or_null("TankDemoMapRoot")
	if existing:
		existing.free()

	var selected_map := str(Network.lobby_config.get("map", "Warehouse"))
	var gdquest_arena := environment.get_node_or_null("GDQuestControllerArena") as Node3D
	var is_tank_demo_map := TANK_DEMO_MAP_SCENES.has(selected_map)
	if gdquest_arena:
		gdquest_arena.visible = not is_tank_demo_map
		_sanitize_embedded_map_lighting(gdquest_arena)

	var floor_body := environment.get_node_or_null("Floor") as CollisionObject3D
	if floor_body:
		floor_body.visible = not is_tank_demo_map
		floor_body.collision_layer = 0 if is_tank_demo_map else 2

	if not is_tank_demo_map:
		return

	var packed := load(str(TANK_DEMO_MAP_SCENES[selected_map]))
	if not packed is PackedScene:
		push_warning("Configured map scene did not load: " + str(TANK_DEMO_MAP_SCENES[selected_map]))
		return
	var map_root := (packed as PackedScene).instantiate() as Node3D
	if not map_root:
		push_warning("Configured map scene did not instantiate: " + selected_map)
		return
	map_root.name = "TankDemoMapRoot"
	map_root.set_meta("selected_map", selected_map)
	environment.add_child(map_root)
	# Maps migrated to the map framework carry a MapController on their root, which
	# owns lighting / collision-layer / grounding / support-floor preparation in one
	# place (see scripts/maps/). Only unmigrated maps fall back to the legacy blunt
	# lighting-strip + TPS-specific collision pass below.
	if map_root is MapController:
		return
	_sanitize_embedded_map_lighting(map_root)
	_adapt_embedded_map_collision(map_root, selected_map)


func _apply_selected_map_scene_if_stale() -> void:
	var environment := get_node_or_null("Environment") as Node3D
	if not environment:
		return
	var selected_map := str(Network.lobby_config.get("map", "Warehouse"))
	var existing := environment.get_node_or_null("TankDemoMapRoot")
	if TANK_DEMO_MAP_SCENES.has(selected_map):
		if existing and str(existing.get_meta("selected_map", "")) == selected_map:
			return
		_apply_selected_map_scene()
	elif existing:
		_apply_selected_map_scene()


func _sanitize_embedded_map_lighting(map_root: Node) -> void:
	if map_root == null:
		return
	var embedded_worlds: Array[Node] = map_root.find_children("*", "WorldEnvironment", true, false)
	for node in embedded_worlds:
		var world_environment := node as WorldEnvironment
		if world_environment:
			world_environment.environment = null
	var embedded_directionals: Array[Node] = map_root.find_children("*", "DirectionalLight3D", true, false)
	for node in embedded_directionals:
		var directional := node as DirectionalLight3D
		if directional:
			directional.visible = false
			directional.light_energy = 0.0


func _adapt_embedded_map_collision(map_root: Node, selected_map: String) -> void:
	if selected_map != TPS_DEMO_LEVEL_MAP_NAME or map_root == null:
		return
	var adapted_count := 0
	var skipped_area_count := 0
	var collision_nodes: Array[Node] = map_root.find_children("*", "CollisionObject3D", true, false)
	for node in collision_nodes:
		var collision := node as CollisionObject3D
		if collision == null:
			continue
		if collision is Area3D:
			skipped_area_count += 1
			continue
		if collision.collision_layer == 0:
			continue
		collision.collision_layer = WORLD_COLLISION_MASK
		adapted_count += 1
	map_root.set_meta("world_collision_adapted_count", adapted_count)
	map_root.set_meta("world_collision_skipped_area_count", skipped_area_count)


func is_benchmark_mode_enabled() -> bool:
	return benchmark_mode_enabled


func get_benchmark_status_text() -> String:
	if not benchmark_mode_enabled:
		return "Off"
	return "On %dx%d VSync Off" % [BENCHMARK_WINDOW_SIZE.x, BENCHMARK_WINDOW_SIZE.y]


func get_benchmark_metrics() -> Dictionary:
	var metrics: Dictionary = {
		"enabled": benchmark_mode_enabled,
		"fps": Engine.get_frames_per_second(),
		"max_fps": Engine.max_fps,
		"menu_background_suspended": _menu_background_suspended,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"memory_static_mib": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
	}
	if DisplayServer.get_name() != "headless":
		metrics["vsync_mode"] = DisplayServer.window_get_vsync_mode()
		metrics["window_mode"] = DisplayServer.window_get_mode()
		metrics["window_size"] = DisplayServer.window_get_size()
	return metrics


func _on_graphics_settings_changed(_settings: Dictionary) -> void:
	_apply_runtime_graphics_settings()


func _apply_runtime_graphics_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_configure_match_lighting()
	var settings := _game_settings()
	if settings and settings.has_method("apply_graphics_settings"):
		settings.call("apply_graphics_settings", get_window(), get_viewport(), _get_match_environment_resource(), self)
	_sync_match_performance_policy(true)
	if benchmark_mode_enabled:
		_apply_benchmark_window_state(true)
		_apply_benchmark_render_policy(true)
	_sync_menu_background_performance_state(true)


func _should_enable_match_performance_policy() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return game_state == GameState.CARD_DRAFT \
		or game_state == GameState.SKIN_CONFIG \
		or game_state == GameState.MATCH_INTRO \
		or game_state == GameState.PREP \
		or game_state == GameState.PLAY


func _sync_match_performance_policy(force: bool = false) -> void:
	if benchmark_mode_enabled:
		return
	var desired_enabled: bool = _should_enable_match_performance_policy()
	if not force and desired_enabled == _match_performance_policy_enabled:
		return
	if _match_performance_policy_enabled:
		_apply_match_performance_render_policy(false)
		_match_performance_policy_enabled = false
	if desired_enabled:
		_apply_match_performance_render_policy(true)
		_match_performance_policy_enabled = true


func _apply_match_performance_render_policy(enabled: bool) -> void:
	var environment: Environment = _get_match_environment_resource()
	if environment:
		_apply_match_performance_environment_policy(environment, enabled)
	_apply_match_performance_light_policy(enabled)
	_apply_match_performance_geometry_policy(enabled)


func _request_match_performance_policy_refresh() -> void:
	if not _match_performance_policy_enabled:
		return
	if _match_performance_refresh_pending:
		return
	_match_performance_refresh_pending = true
	call_deferred("_refresh_match_performance_policy_for_runtime_nodes")


func _refresh_match_performance_policy_for_runtime_nodes() -> void:
	_match_performance_refresh_pending = false
	if not _match_performance_policy_enabled:
		return
	_apply_match_performance_runtime_node_policy()


func _apply_match_performance_runtime_node_policy() -> void:
	for container_name in ["MapPropContainer", "UnityDecorContainer", "AmmoPackContainer", "PartyMonsterAccessoryContainer", "PlayersContainer"]:
		var container: Node = get_node_or_null(container_name)
		if not container:
			continue
		_apply_match_performance_lights_in_subtree(container)
		_apply_match_performance_geometry_in_subtree(container)


func _apply_match_performance_environment_policy(environment: Environment, enabled: bool) -> void:
	if enabled:
		if _match_performance_environment_state.is_empty():
			_match_performance_environment_state = _make_property_state(environment, [
				"glow_enabled",
				"fog_enabled",
				"volumetric_fog_enabled",
				"ssao_enabled",
				"ssil_enabled",
				"sdfgi_enabled",
				"reflected_light_source",
			])
		_set_property_if_present(environment, "glow_enabled", false)
		_set_property_if_present(environment, "fog_enabled", false)
		_set_property_if_present(environment, "volumetric_fog_enabled", false)
		_set_property_if_present(environment, "ssao_enabled", false)
		_set_property_if_present(environment, "ssil_enabled", false)
		_set_property_if_present(environment, "sdfgi_enabled", false)
		_set_property_if_present(environment, "reflected_light_source", Environment.REFLECTION_SOURCE_DISABLED)
		return
	_restore_property_state(_match_performance_environment_state)
	_match_performance_environment_state.clear()


func _apply_match_performance_light_policy(enabled: bool) -> void:
	if enabled:
		_match_performance_light_states.clear()
		var lights: Array[Node] = _find_light_nodes()
		for node in lights:
			var light := node as Light3D
			if not light:
				continue
			_match_performance_light_states.append(_make_property_state(light, [
				"shadow_enabled",
				"shadow_blur",
				"light_volumetric_fog_energy",
				"distance_fade_enabled",
				"distance_fade_begin",
				"distance_fade_length",
				"distance_fade_shadow",
				"directional_shadow_max_distance",
			]))
			var keep_main_shadow: bool = _is_main_match_shadow_light(light)
			light.shadow_enabled = keep_main_shadow
			light.light_volumetric_fog_energy = 0.0
			_set_property_if_present(light, "shadow_blur", MATCH_PERFORMANCE_MAIN_SHADOW_BLUR if keep_main_shadow else 0.0)
			_set_property_if_present(light, "directional_shadow_max_distance", MATCH_PERFORMANCE_MAIN_SHADOW_DISTANCE if keep_main_shadow else 0.0)
			_set_property_if_present(light, "distance_fade_enabled", true)
			_set_property_if_present(light, "distance_fade_begin", MATCH_PERFORMANCE_LIGHT_FADE_BEGIN)
			_set_property_if_present(light, "distance_fade_length", MATCH_PERFORMANCE_LIGHT_FADE_LENGTH)
			_set_property_if_present(light, "distance_fade_shadow", MATCH_PERFORMANCE_LIGHT_FADE_SHADOW)
		return
	for state in _match_performance_light_states:
		_restore_property_state(state)
	_match_performance_light_states.clear()


func _is_main_match_shadow_light(light: Light3D) -> bool:
	if not light is DirectionalLight3D:
		return false
	var environment_root: Node = get_node_or_null("Environment")
	return environment_root != null and light.get_parent() == environment_root and String(light.name) == "DirectionalLight3D"


func _find_light_nodes() -> Array[Node]:
	var lights: Array[Node] = []
	_collect_light_nodes(self, lights)
	return lights


func _collect_light_nodes(node: Node, lights: Array[Node]) -> void:
	if node is Light3D:
		lights.append(node)
	for child: Node in node.get_children():
		_collect_light_nodes(child, lights)


func _apply_match_performance_lights_in_subtree(root_node: Node) -> void:
	var lights: Array[Node] = []
	_collect_light_nodes(root_node, lights)
	for node: Node in lights:
		var light := node as Light3D
		if not light:
			continue
		if not _has_match_performance_state_for(_match_performance_light_states, light):
			_match_performance_light_states.append(_make_property_state(light, [
				"shadow_enabled",
				"shadow_blur",
				"light_volumetric_fog_energy",
				"distance_fade_enabled",
				"distance_fade_begin",
				"distance_fade_length",
				"distance_fade_shadow",
				"directional_shadow_max_distance",
			]))
		var keep_main_shadow: bool = _is_main_match_shadow_light(light)
		light.shadow_enabled = keep_main_shadow
		light.light_volumetric_fog_energy = 0.0
		_set_property_if_present(light, "shadow_blur", MATCH_PERFORMANCE_MAIN_SHADOW_BLUR if keep_main_shadow else 0.0)
		_set_property_if_present(light, "directional_shadow_max_distance", MATCH_PERFORMANCE_MAIN_SHADOW_DISTANCE if keep_main_shadow else 0.0)
		_set_property_if_present(light, "distance_fade_enabled", true)
		_set_property_if_present(light, "distance_fade_begin", MATCH_PERFORMANCE_LIGHT_FADE_BEGIN)
		_set_property_if_present(light, "distance_fade_length", MATCH_PERFORMANCE_LIGHT_FADE_LENGTH)
		_set_property_if_present(light, "distance_fade_shadow", MATCH_PERFORMANCE_LIGHT_FADE_SHADOW)


func _apply_match_performance_geometry_in_subtree(root_node: Node) -> void:
	var geometry_nodes: Array[Node] = []
	_collect_match_performance_geometry_nodes(root_node, geometry_nodes)
	for node: Node in geometry_nodes:
		var instance := node as GeometryInstance3D
		if not instance:
			continue
		if not _has_match_performance_state_for(_match_performance_geometry_states, instance):
			_match_performance_geometry_states.append(_make_property_state(instance, [
				"visible",
				"cast_shadow",
				"gi_mode",
				"visibility_range_end",
				"visibility_range_end_margin",
				"visibility_range_fade_mode",
			]))
		if _should_limit_benchmark_visibility(instance):
			_apply_match_performance_geometry_limits(instance)


func _apply_match_performance_geometry_limits(instance: GeometryInstance3D) -> void:
	_set_property_if_present(instance, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if _is_hidden_match_decor_geometry(instance):
		instance.visible = false
		instance.visibility_range_end = 0.0
		instance.visibility_range_end_margin = 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		return
	var runtime_prop: bool = _is_runtime_map_prop_geometry(instance)
	if runtime_prop:
		instance.visibility_range_end = MATCH_PERFORMANCE_RUNTIME_PROP_VISIBILITY_RANGE
		instance.visibility_range_end_margin = MATCH_PERFORMANCE_RUNTIME_PROP_VISIBILITY_MARGIN
	elif _is_player_visual_geometry(instance):
		instance.visibility_range_end = MATCH_PERFORMANCE_PLAYER_VISUAL_VISIBILITY_RANGE
		instance.visibility_range_end_margin = MATCH_PERFORMANCE_PLAYER_VISUAL_VISIBILITY_MARGIN
	elif _is_bounty_beacon_geometry(instance):
		instance.visibility_range_end = MATCH_PERFORMANCE_BOUNTY_BEACON_VISIBILITY_RANGE
		instance.visibility_range_end_margin = MATCH_PERFORMANCE_BOUNTY_BEACON_VISIBILITY_MARGIN
	elif _is_match_pickup_geometry(instance):
		if instance is Label3D:
			instance.visibility_range_end = MATCH_PERFORMANCE_PICKUP_LABEL_VISIBILITY_RANGE
			instance.visibility_range_end_margin = MATCH_PERFORMANCE_PICKUP_VISIBILITY_MARGIN
		else:
			instance.visibility_range_end = MATCH_PERFORMANCE_PICKUP_VISIBILITY_RANGE
			instance.visibility_range_end_margin = MATCH_PERFORMANCE_PICKUP_VISIBILITY_MARGIN
	elif _is_heavy_match_map_decor_geometry(instance):
		instance.visibility_range_end = MATCH_PERFORMANCE_HEAVY_MAP_DECOR_VISIBILITY_RANGE
		instance.visibility_range_end_margin = MATCH_PERFORMANCE_HEAVY_MAP_DECOR_VISIBILITY_MARGIN
	else:
		instance.visibility_range_end = MATCH_PERFORMANCE_DECOR_VISIBILITY_RANGE
		instance.visibility_range_end_margin = MATCH_PERFORMANCE_DECOR_VISIBILITY_MARGIN
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _collect_match_performance_geometry_nodes(node: Node, result: Array[Node]) -> void:
	if node is MeshInstance3D or node is CSGShape3D or node is GPUParticles3D or node is Label3D:
		result.append(node)
	for child: Node in node.get_children():
		_collect_match_performance_geometry_nodes(child, result)


func _has_match_performance_state_for(states: Array[Dictionary], object: Object) -> bool:
	for state: Dictionary in states:
		if state.get("node", null) == object:
			return true
	return false


func _apply_match_performance_geometry_policy(enabled: bool) -> void:
	if enabled:
		_match_performance_geometry_states.clear()
		var geometry_nodes: Array[Node] = []
		geometry_nodes.append_array(find_children("*", "MeshInstance3D", true, false))
		geometry_nodes.append_array(find_children("*", "CSGShape3D", true, false))
		geometry_nodes.append_array(find_children("*", "GPUParticles3D", true, false))
		geometry_nodes.append_array(find_children("*", "Label3D", true, false))
		for node in geometry_nodes:
			var instance := node as GeometryInstance3D
			if not instance:
				continue
			_match_performance_geometry_states.append(_make_property_state(instance, [
				"visible",
				"cast_shadow",
				"gi_mode",
				"visibility_range_end",
				"visibility_range_end_margin",
				"visibility_range_fade_mode",
			]))
			if _should_limit_benchmark_visibility(instance):
				_apply_match_performance_geometry_limits(instance)
		return
	for state in _match_performance_geometry_states:
		_restore_property_state(state)
	_match_performance_geometry_states.clear()


func _set_benchmark_mode_enabled(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if benchmark_mode_enabled == enabled:
		return
	if enabled:
		if _match_performance_policy_enabled:
			_apply_match_performance_render_policy(false)
			_match_performance_policy_enabled = false
		_capture_benchmark_restore_state()
		benchmark_mode_enabled = true
		_apply_benchmark_window_state(true)
		_apply_benchmark_render_policy(true)
	else:
		benchmark_mode_enabled = false
		_apply_benchmark_render_policy(false)
		_apply_benchmark_window_state(false)
		_sync_match_performance_policy(true)
	if debug_overlay and is_instance_valid(debug_overlay):
		debug_overlay._process(0.0)


func _capture_benchmark_restore_state() -> void:
	var viewport: Viewport = get_viewport()
	_benchmark_restore_state = {
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"window_mode": DisplayServer.window_get_mode(),
		"window_size": DisplayServer.window_get_size(),
		"window_position": DisplayServer.window_get_position(),
		"max_fps": Engine.max_fps,
	}
	if viewport:
		_benchmark_restore_state["scaling_3d_mode"] = viewport.scaling_3d_mode
		_benchmark_restore_state["scaling_3d_scale"] = viewport.scaling_3d_scale


func _apply_benchmark_window_state(enabled: bool) -> void:
	var viewport: Viewport = get_viewport()
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(BENCHMARK_WINDOW_SIZE)
		if viewport:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = 1.0
		return
	if _benchmark_restore_state.is_empty():
		return
	if viewport:
		if _benchmark_restore_state.has("scaling_3d_mode"):
			viewport.set("scaling_3d_mode", int(_benchmark_restore_state.get("scaling_3d_mode", viewport.scaling_3d_mode)))
		if _benchmark_restore_state.has("scaling_3d_scale"):
			viewport.scaling_3d_scale = float(_benchmark_restore_state.get("scaling_3d_scale", viewport.scaling_3d_scale))
	DisplayServer.window_set_vsync_mode(int(_benchmark_restore_state.get("vsync_mode", DisplayServer.VSYNC_ENABLED)))
	Engine.max_fps = int(_benchmark_restore_state.get("max_fps", 0))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if _benchmark_restore_state.has("window_size"):
		DisplayServer.window_set_size(_benchmark_restore_state.get("window_size", BENCHMARK_WINDOW_SIZE))
	if _benchmark_restore_state.has("window_position"):
		DisplayServer.window_set_position(_benchmark_restore_state.get("window_position", Vector2i.ZERO))
	DisplayServer.window_set_mode(int(_benchmark_restore_state.get("window_mode", DisplayServer.WINDOW_MODE_WINDOWED)))
	_benchmark_restore_state.clear()


func _apply_benchmark_render_policy(enabled: bool) -> void:
	var environment: Environment = _get_match_environment_resource()
	if environment:
		_apply_benchmark_environment_policy(environment, enabled)
	_apply_benchmark_light_policy(enabled)
	_apply_benchmark_geometry_policy(enabled)


func _get_match_environment_resource() -> Environment:
	var world_environment := get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		return world_environment.environment
	return _menu_world_environment_resource


func _apply_benchmark_environment_policy(environment: Environment, enabled: bool) -> void:
	if enabled:
		if _benchmark_environment_state.is_empty():
			_benchmark_environment_state = _make_property_state(environment, [
				"glow_enabled",
				"fog_enabled",
				"volumetric_fog_enabled",
				"ssao_enabled",
				"ssil_enabled",
				"sdfgi_enabled",
				"tonemap_mode",
				"tonemap_exposure",
			])
		_set_property_if_present(environment, "glow_enabled", false)
		_set_property_if_present(environment, "fog_enabled", false)
		_set_property_if_present(environment, "volumetric_fog_enabled", false)
		_set_property_if_present(environment, "ssao_enabled", false)
		_set_property_if_present(environment, "ssil_enabled", false)
		_set_property_if_present(environment, "sdfgi_enabled", false)
		_set_property_if_present(environment, "tonemap_mode", Environment.TONE_MAPPER_LINEAR)
		_set_property_if_present(environment, "tonemap_exposure", 1.0)
		return
	_restore_property_state(_benchmark_environment_state)
	_benchmark_environment_state.clear()


func _apply_benchmark_light_policy(enabled: bool) -> void:
	if enabled:
		_benchmark_light_states.clear()
		var lights: Array[Node] = _find_light_nodes()
		for node in lights:
			var light := node as Light3D
			if not light:
				continue
			_benchmark_light_states.append(_make_property_state(light, [
				"visible",
				"shadow_enabled",
				"shadow_blur",
				"light_energy",
				"light_volumetric_fog_energy",
				"distance_fade_enabled",
				"distance_fade_begin",
				"distance_fade_length",
				"distance_fade_shadow",
				"directional_shadow_max_distance",
			]))
			light.shadow_enabled = false
			light.light_volumetric_fog_energy = 0.0
			_set_property_if_present(light, "shadow_blur", 0.0)
			_set_property_if_present(light, "directional_shadow_max_distance", 45.0)
			_set_property_if_present(light, "distance_fade_enabled", true)
			_set_property_if_present(light, "distance_fade_begin", 28.0)
			_set_property_if_present(light, "distance_fade_length", 10.0)
			_set_property_if_present(light, "distance_fade_shadow", 20.0)
		return
	for state in _benchmark_light_states:
		_restore_property_state(state)
	_benchmark_light_states.clear()


func _apply_benchmark_geometry_policy(enabled: bool) -> void:
	if enabled:
		_benchmark_geometry_states.clear()
		var geometry_nodes: Array[Node] = []
		geometry_nodes.append_array(find_children("*", "MeshInstance3D", true, false))
		geometry_nodes.append_array(find_children("*", "CSGShape3D", true, false))
		geometry_nodes.append_array(find_children("*", "GPUParticles3D", true, false))
		geometry_nodes.append_array(find_children("*", "Label3D", true, false))
		for node in geometry_nodes:
			var instance := node as GeometryInstance3D
			if not instance:
				continue
			_benchmark_geometry_states.append(_make_property_state(instance, [
				"cast_shadow",
				"gi_mode",
				"visibility_range_end",
				"visibility_range_end_margin",
				"visibility_range_fade_mode",
			]))
			_set_property_if_present(instance, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			if _should_limit_benchmark_visibility(instance):
				instance.visibility_range_end = BENCHMARK_DECOR_VISIBILITY_RANGE
				instance.visibility_range_end_margin = BENCHMARK_DECOR_VISIBILITY_MARGIN
				instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		return
	for state in _benchmark_geometry_states:
		_restore_property_state(state)
	_benchmark_geometry_states.clear()


func _should_limit_benchmark_visibility(instance: GeometryInstance3D) -> bool:
	if _is_runtime_map_prop_geometry(instance):
		return true
	var lower_name := String(instance.name).to_lower()
	for token in ["ground", "floor", "wall", "border", "gate", "terrain", "map"]:
		if lower_name.contains(token):
			return false
	return true


func _is_hidden_match_decor_geometry(instance: GeometryInstance3D) -> bool:
	if _is_runtime_map_prop_geometry(instance):
		return false
	var current: Node = instance
	while current:
		var lower_name: String = String(current.name).to_lower()
		for token: String in MATCH_PERFORMANCE_HIDDEN_DECOR_NAME_TOKENS:
			if lower_name.contains(token):
				return true
		current = current.get_parent()
	if instance is MeshInstance3D:
		var mesh_instance: MeshInstance3D = instance as MeshInstance3D
		if mesh_instance.mesh:
			var resource_path: String = String(mesh_instance.mesh.resource_path).to_lower()
			for token: String in MATCH_PERFORMANCE_HIDDEN_DECOR_RESOURCE_TOKENS:
				if resource_path.contains(token):
					return true
	return false


func _is_heavy_match_map_decor_geometry(instance: GeometryInstance3D) -> bool:
	if _is_runtime_map_prop_geometry(instance):
		return false
	if not _is_imported_match_map_geometry(instance):
		return false
	var current: Node = instance
	while current:
		var lower_name: String = String(current.name).to_lower()
		for token: String in MATCH_PERFORMANCE_HEAVY_MAP_DECOR_NAME_TOKENS:
			if lower_name.contains(token):
				return true
		current = current.get_parent()
	return false


func _is_imported_match_map_geometry(instance: GeometryInstance3D) -> bool:
	var current: Node = instance
	while current:
		if String(current.scene_file_path).to_lower().contains("assets/map/map.gltf"):
			return true
		current = current.get_parent()
	if instance is MeshInstance3D:
		var mesh_instance: MeshInstance3D = instance as MeshInstance3D
		if mesh_instance.mesh and String(mesh_instance.mesh.resource_path).to_lower().contains("assets/map/map.gltf"):
			return true
	return false


func _is_bounty_beacon_geometry(instance: GeometryInstance3D) -> bool:
	var current: Node = instance
	while current:
		var current_name: String = String(current.name)
		if current_name == "AccessoryBountyBeacon" or current_name.begins_with("BountyBeam"):
			return true
		current = current.get_parent()
	return false


func _is_match_pickup_geometry(instance: GeometryInstance3D) -> bool:
	var current: Node = instance
	while current:
		if current.is_in_group("ammo_pickups") or current.is_in_group("party_monster_accessory_pickups"):
			return true
		var current_name: String = String(current.name)
		if current_name == "AmmoPackContainer" or current_name == "PartyMonsterAccessoryContainer":
			return true
		current = current.get_parent()
	return false


func _is_runtime_map_prop_geometry(instance: GeometryInstance3D) -> bool:
	var current: Node = instance
	while current:
		if current.is_in_group("map_props") or String(current.name).begins_with("MapProp_"):
			return true
		current = current.get_parent()
	return false


func _is_player_visual_geometry(instance: GeometryInstance3D) -> bool:
	var players_root: Node = get_node_or_null("PlayersContainer")
	if players_root == null:
		return false
	var current: Node = instance
	while current:
		if current == players_root:
			return true
		current = current.get_parent()
	return false


func _make_property_state(object: Object, property_names: Array) -> Dictionary:
	var properties: Dictionary = {}
	for property_name in property_names:
		var key := str(property_name)
		if _has_property(object, key):
			properties[key] = object.get(key)
	return {
		"node": object,
		"properties": properties,
	}


func _restore_property_state(state: Dictionary) -> void:
	var object_value: Variant = state.get("node", null)
	if object_value == null or not is_instance_valid(object_value):
		return
	var object: Object = object_value as Object
	if object == null:
		return
	var properties: Dictionary = state.get("properties", {})
	for property_name in properties.keys():
		var key := str(property_name)
		if _has_property(object, key):
			object.set(key, properties[property_name])


func _has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _sync_menu_background_performance_state(force: bool = false) -> void:
	var should_suspend := _should_suspend_background_world_for_menu()
	if not force and should_suspend == _menu_background_suspended:
		return
	_menu_background_suspended = should_suspend
	_set_menu_background_suspended(should_suspend)


func _should_suspend_background_world_for_menu() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return game_state == GameState.LOBBY and main_menu and main_menu.is_menu_visible()


func _set_menu_background_suspended(suspended: bool) -> void:
	for node_path in MENU_BACKGROUND_NODE_PATHS:
		var node := get_node_or_null(str(node_path)) as Node3D
		if node:
			node.visible = not suspended
	var world_environment := get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if not world_environment:
		return
	if suspended:
		if _menu_world_environment_resource == null:
			_menu_world_environment_resource = world_environment.environment
		world_environment.environment = null
	elif _menu_world_environment_resource:
		world_environment.environment = _menu_world_environment_resource
		_menu_world_environment_resource = null


func _process(delta):
	_sync_menu_background_performance_state()
	_sync_match_performance_policy()
	_sync_active_match_training_targets()
	_process_match_pickup_activation_queue()
	# 鏇存柊鍊掕鏃舵樉绀?浠讳綍鐘舵€?
	if game_state == GameState.LOADING:
		_update_loading_tip(delta)
	elif game_state == GameState.SKIN_CONFIG:
		skin_config_remaining = max(0.0, skin_config_remaining - delta)
		_update_character_setup_ui()
		if _is_multiplayer_server() and skin_config_remaining <= 0.0:
			_server_start_match_intro_phase()
	elif game_state == GameState.MATCH_INTRO:
		match_intro_remaining = max(0.0, match_intro_remaining - delta)
		_update_match_intro_ui()
		if _is_multiplayer_server() and match_intro_remaining <= 0.0:
			_server_start_prep_phase()
	elif game_state == GameState.PREP:
		prep_remaining = max(0.0, prep_remaining - delta)
		_update_prep_ui()
		if _is_multiplayer_server() and prep_remaining <= 0.0:
			_server_end_prep_phase()
	elif game_state == GameState.PLAY:
		match_remaining = max(0.0, match_remaining - delta)
		if not party_monster_bounty_accessories.is_empty():
			party_monster_bounty_remaining = maxf(0.0, party_monster_bounty_remaining - delta)
		_process_gravity_events(delta)
		if _is_multiplayer_server():
			_server_process_party_monster_bounties(delta)
		if _is_multiplayer_server() and match_remaining <= 0.0:
			_server_end_match()
	_process_map_prop_motion_sync(delta)
	if _is_dedicated_public_server_runtime():
		return
	_process_client_hud_refresh(delta)
	_update_world_nameplates()
	_update_mouse_capture()


func _process_client_hud_refresh(delta: float) -> void:
	_hud_refresh_elapsed += maxf(delta, 0.0)
	if _hud_refresh_elapsed < HUD_REFRESH_INTERVAL:
		return
	_hud_refresh_elapsed = 0.0
	_update_status_hud()
	_update_party_monster_hunt_hud()
	_update_skill_hud()
	_update_health_hud()


func _is_dedicated_public_server_runtime() -> bool:
	return RuntimeModeScript.is_dedicated_public_server(multiplayer, Network.lobby_config)


func _process_map_prop_motion_sync(delta: float) -> void:
	if not RuntimeModeScript.is_multiplayer_server(multiplayer):
		return
	var rest_states: Array[Dictionary] = _map_prop_sync_budget.tick_rest(delta)
	if not rest_states.is_empty():
		_flush_map_prop_state_batch(rest_states, true)
	var motion_states: Array[Dictionary] = _map_prop_sync_budget.tick(delta)
	if not motion_states.is_empty():
		_flush_map_prop_state_batch(motion_states, false)


func _flush_map_prop_state_batch(states: Array[Dictionary], reliable: bool) -> void:
	if states.is_empty():
		return
	var payload: Array = []
	for state: Dictionary in states:
		var prop_name: String = str(state.get("prop_name", ""))
		if prop_name.is_empty():
			continue
		var next_transform: Transform3D = state.get("transform", Transform3D.IDENTITY)
		var next_linear_velocity: Vector3 = state.get("linear_velocity", Vector3.ZERO)
		var next_angular_velocity: Vector3 = state.get("angular_velocity", Vector3.ZERO)
		var next_sleeping: bool = bool(state.get("sleeping", false))
		payload.append([prop_name, next_transform, next_linear_velocity, next_angular_velocity, next_sleeping])
	if payload.is_empty():
		return
	if reliable:
		var recipients: PackedInt32Array = _map_prop_state_recipient_ids(payload, true)
		if recipients.is_empty():
			return
		Network.record_rpc_event("map_prop.rest_batch", recipients.size(), payload.size() * 104)
		for peer_id: int in recipients:
			_rpc_sync_map_prop_rest_states.rpc_id(peer_id, payload)
		return
	var peer_payloads: Dictionary = _map_prop_motion_payloads_by_peer(payload)
	if peer_payloads.is_empty():
		return
	var total_states: int = 0
	for raw_peer_id: Variant in peer_payloads.keys():
		var peer_payload: Array = peer_payloads.get(raw_peer_id, []) as Array
		total_states += peer_payload.size()
	Network.record_rpc_event("map_prop.motion", peer_payloads.size(), total_states * 104)
	for raw_peer_id: Variant in peer_payloads.keys():
		var peer_id: int = int(raw_peer_id)
		var peer_payload: Array = peer_payloads.get(raw_peer_id, []) as Array
		if not peer_payload.is_empty():
			_rpc_sync_map_prop_motion_states.rpc_id(peer_id, peer_payload)


func _map_prop_state_recipient_ids(payload: Array, reliable: bool) -> PackedInt32Array:
	var recipients: PackedInt32Array = PackedInt32Array()
	if multiplayer.multiplayer_peer == null:
		return recipients
	for peer_id: int in multiplayer.get_peers():
		if reliable or _is_peer_relevant_to_map_prop_payload(peer_id, payload):
			NetworkInterestScript.append_unique_peer_id(recipients, peer_id)
	return recipients


func _map_prop_motion_payloads_by_peer(payload: Array) -> Dictionary:
	var peer_payloads: Dictionary = {}
	if multiplayer.multiplayer_peer == null:
		return peer_payloads
	for peer_id: int in multiplayer.get_peers():
		var peer_payload: Array = _map_prop_motion_payload_for_peer(peer_id, payload)
		if not peer_payload.is_empty():
			peer_payloads[peer_id] = peer_payload
	return peer_payloads


func _map_prop_motion_payload_for_peer(peer_id: int, payload: Array) -> Array:
	if peer_id <= 0:
		return []
	if _should_receive_all_map_prop_motion(peer_id):
		return payload.duplicate()
	var player_node: Node3D = NetworkInterestScript.find_player_node_for_peer(get_tree() if is_inside_tree() else null, self, peer_id)
	if player_node == null:
		return payload.duplicate()
	var radius_sq: float = MAP_PROP_MOTION_SYNC_RELEVANCE_RADIUS * MAP_PROP_MOTION_SYNC_RELEVANCE_RADIUS
	var observer_position: Vector3 = player_node.global_position if player_node.is_inside_tree() else player_node.position
	var peer_payload: Array = []
	for raw_state: Variant in payload:
		if _is_map_prop_state_near_observer(raw_state, observer_position, radius_sq):
			peer_payload.append(raw_state)
	return peer_payload


func _should_receive_all_map_prop_motion(peer_id: int) -> bool:
	if not Network.players.has(peer_id):
		return false
	var role: int = int(Network.players[peer_id].get("role", Network.Role.NONE))
	return role == Network.Role.NONE


func _is_map_prop_state_near_observer(raw_state: Variant, observer_position: Vector3, radius_sq: float) -> bool:
	if not (raw_state is Array):
		return false
	var state: Array = raw_state as Array
	if state.size() < 2 or not (state[1] is Transform3D):
		return false
	var next_transform: Transform3D = state[1]
	return observer_position.distance_squared_to(next_transform.origin) <= radius_sq


func _is_peer_relevant_to_map_prop_payload(peer_id: int, payload: Array) -> bool:
	return not _map_prop_motion_payload_for_peer(peer_id, payload).is_empty()


# -----------------------------------------------------------------------------
# 涓昏彍鍗曞洖璋?# -----------------------------------------------------------------------------
func _on_host_pressed(nickname: String, skin: String, role: int, room_name: String = "", lobby_password: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> void:
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	if main_menu:
		# Immediate click feedback + block a duplicate attempt during the ~8s Noray handshake.
		main_menu.set_private_host_connecting(true)
		main_menu.show_join_status(I18n.t("join_status.creating_private"), false)
	var error: int = await Network.start_private_host(nickname, skin, role, room_name, lobby_password, character_model)
	if main_menu:
		main_menu.set_private_host_connecting(false)
	if error != OK:
		push_warning("Could not host lobby through Noray. ENet error: " + str(error))
		if main_menu:
			# Human, actionable failure (the relay/Noray was unreachable) — the button is now
			# re-enabled so the player can simply retry.
			main_menu.show_join_status(I18n.t("join_status.failed_private"), true)
		return
	if SteamBridge.is_available():
		SteamBridge.create_lobby(
			str(Network.lobby_config.get("room_name", room_name)),
			str(Network.lobby_config.get("lobby_id", lobby_password)),
			str(Network.lobby_config.get("private_connection_code", Network.SERVER_ADDRESS)),
			int(Network.lobby_config.get("max_players", Network.MAX_PLAYERS)),
			int(Network.lobby_config.get("host_port", Network.server_port))
		)
	main_menu.show_lobby(str(Network.lobby_config.get("lobby_id", "")), true)
	main_menu.show_join_status("")
	_set_hud_visible(false)
	_refresh_lobby_ui()


func _on_join_pressed(nickname: String, skin: String, address: String, lobby_id: String, role: int, room_name: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID):
	if not room_name.strip_edges().is_empty() and SteamBridge.is_available():
		pending_steam_join = {
			"nickname": nickname,
			"skin": skin,
			"address": address,
			"lobby_id": lobby_id,
			"role": role,
			"room_name": room_name,
			"character_model": character_model,
		}
		if SteamBridge.find_lobby(room_name, lobby_id):
			return
	_join_lobby_direct(nickname, skin, address, lobby_id, role, room_name, character_model)


func _join_lobby_direct(nickname: String, skin: String, address: String, lobby_id: String, role: int, room_name: String = "", character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> void:
	var normalized_lobby_id: String = lobby_id.strip_edges().to_upper()
	var error: int = OK
	if Network.is_noray_join_target(address):
		error = await Network.join_private_game(nickname, skin, address, normalized_lobby_id, role, room_name, character_model)
	else:
		error = Network.join_game(nickname, skin, address, normalized_lobby_id, role, room_name, character_model)
	if error != OK:
		pending_direct_join_waiting_for_sync = false
		pending_direct_join_lobby_id = ""
		push_warning("Could not join lobby. ENet error: " + str(error))
		main_menu.show_join_status(I18n.t("join_status.failed"), true)
		return
	pending_direct_join_lobby_id = normalized_lobby_id
	pending_direct_join_waiting_for_sync = true
	_set_hud_visible(false)


func _on_public_server_pressed(nickname: String, skin: String, role: int, character_model: String = CharacterSkinCatalog.DEFAULT_ID) -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	var error := Network.join_public_lobby(nickname, skin, MainMenuUI.PUBLIC_SERVER_TARGET, role, character_model)
	if error != OK:
		push_warning("Could not join public lobby. ENet error: " + str(error))
		main_menu.show_join_status(I18n.t("join_status.failed"), true)
		return
	main_menu.show_public_lobby([], I18n.t("public_lobby.loading"))
	_set_hud_visible(false)


func _on_public_lobby_snapshot_received(rooms: Array) -> void:
	if not main_menu or not main_menu.is_public_lobby_visible():
		return
	_returning_to_public_lobby = false
	main_menu.update_public_lobby(rooms)
	main_menu.show_public_lobby_status(I18n.t("public_lobby.connected"), false)
	_set_hud_visible(false)


func _on_private_connection_status_changed(status_key: String, is_error: bool) -> void:
	if not main_menu:
		return
	main_menu.show_join_status(I18n.t(status_key), is_error)


func _on_public_room_create_pressed(room_name: String, lobby_password: String) -> void:
	_start_public_lobby_room_request_timeout()
	Network.request_create_public_room(room_name, lobby_password)


func _on_public_room_join_pressed(room_id: String, lobby_password: String) -> void:
	_start_public_lobby_room_request_timeout()
	Network.request_join_public_room(room_id, lobby_password)


func _on_public_lobby_refresh_pressed() -> void:
	Network.request_public_room_list()


func _on_public_lobby_leave_pressed() -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	Network.leave_public_lobby()
	if main_menu:
		main_menu.show_landing()
		main_menu.show_menu()
	_set_hud_visible(false)


func _on_lobby_back_pressed() -> void:
	_on_lobby_leave_pressed()


func _on_lobby_leave_pressed() -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	if _is_public_room_client_context():
		_return_to_public_server_lobby()
		return
	_reset_local_state_for_public_lobby()
	Network.leave_current_lobby()
	if main_menu:
		main_menu.show_landing()
		main_menu.show_menu()
	_set_hud_visible(false)
	_update_mouse_capture()


func _cancel_public_room_join_timeout() -> void:
	_public_room_join_timeout_token += 1


func _cancel_public_lobby_room_request_timeout() -> void:
	_public_lobby_room_request_token += 1


func _start_public_lobby_room_request_timeout(status_key: String = "join_status.public_room_not_ready") -> void:
	_cancel_public_lobby_room_request_timeout()
	var token := _public_lobby_room_request_token
	var timer := get_tree().create_timer(PUBLIC_LOBBY_ROOM_REQUEST_TIMEOUT_SEC)
	timer.timeout.connect(func():
		if token != _public_lobby_room_request_token:
			return
		if not main_menu or not main_menu.is_public_lobby_visible():
			return
		if str(main_menu.public_lobby_loading_text).is_empty():
			return
		main_menu.hide_public_lobby_loading()
		main_menu.show_public_lobby_status(I18n.t(status_key), true)
		Network.request_public_room_list()
		_set_hud_visible(false)
	)


func _start_public_room_join_timeout() -> void:
	_cancel_public_room_join_timeout()
	var token := _public_room_join_timeout_token
	var timer := get_tree().create_timer(PUBLIC_ROOM_JOIN_TIMEOUT_SEC)
	timer.timeout.connect(func():
		if token != _public_room_join_timeout_token:
			return
		if not pending_direct_join_waiting_for_sync:
			return
		_return_to_public_server_lobby("join_status.public_room_not_ready", true)
	)


func _is_public_room_client_context() -> bool:
	return multiplayer.multiplayer_peer != null and bool(Network.lobby_config.get("public_server", false)) and not bool(Network.lobby_config.get("public_lobby", false)) and not _is_multiplayer_server()


func _return_to_public_server_lobby(status_key: String = "", is_error: bool = false) -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = true
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	_reset_local_state_for_public_lobby()
	var nickname := str(Network.player_info.get("nick", ""))
	var skin := Network._skin_e_to_str(int(Network.player_info.get("skin", Network.SKIN_BLUE)))
	var role := int(Network.player_info.get("role", Network.Role.NONE))
	var character_model := str(Network.player_info.get("character_model", CharacterSkinCatalog.DEFAULT_ID))
	var error := Network.join_public_lobby(nickname, skin, MainMenuUI.PUBLIC_SERVER_TARGET, role, character_model)
	if error != OK:
		_returning_to_public_lobby = false
		if main_menu:
			main_menu.show_landing()
			main_menu.show_menu()
			main_menu.show_join_status(I18n.t("join_status.failed"), true)
		_set_hud_visible(false)
		return
	if main_menu:
		main_menu.show_public_lobby([], I18n.t("public_lobby.loading"))
		if not status_key.is_empty():
			main_menu.show_public_lobby_status(I18n.t(status_key), is_error)
		main_menu.show_menu()
	_set_hud_visible(false)
	_update_mouse_capture()


func _reset_local_state_for_public_lobby() -> void:
	game_state = GameState.LOBBY
	prep_remaining = 0.0
	skin_config_remaining = 0.0
	match_intro_remaining = 0.0
	match_remaining = 0.0
	gravity_event_remaining = 0.0
	low_gravity_check_remaining = 0.0
	party_monster_bounty_accessories.clear()
	party_monster_bounty_remaining = 0.0
	party_monster_bounty_next_timer = 0.0
	party_monster_bounty_marked_count = 0
	party_monster_bounty_clear_timer = 0.0
	chat_visible = false
	inventory_visible = false
	_known_player_names.clear()
	_hologram_flag_states.clear()
	_clear_local_hologram_flags()
	_clear_runtime_container_children("MapPropContainer")
	_clear_runtime_container_children("AmmoPackContainer")
	_clear_runtime_container_children("PartyMonsterAccessoryContainer")
	_clear_runtime_container_children("UnityDecorContainer")
	if players_container:
		for child in players_container.get_children():
			child.queue_free()
	if multiplayer_chat:
		multiplayer_chat.set_chat_visible(false)
	if inventory_ui:
		inventory_ui.close_inventory()
	_hide_character_setup_overlay()
	_hide_match_intro_overlay()
	_hide_quit_confirm_prompt()
	if skill_hud:
		skill_hud.clear_skills()
	if card_hud:
		card_hud.clear_cards()
	if health_hud:
		health_hud.clear()
	if world_nameplate_hud:
		world_nameplate_hud.clear()
	if map_ping_hud:
		map_ping_hud.clear()
	if match_status_hud:
		match_status_hud.clear()
	if party_monster_hunt_hud:
		party_monster_hunt_hud.clear()
	_release_game_mouse()


func _clear_runtime_container_children(container_name: String) -> void:
	var container := get_node_or_null(container_name)
	if not container:
		return
	for child in container.get_children():
		child.queue_free()


func _on_steam_lobby_created(success: bool, steam_lobby_id: String, message: String) -> void:
	_runtime_debug_log("[SteamBridge] ", message, " id=", steam_lobby_id)
	if success:
		Network.lobby_config["steam_lobby_id"] = steam_lobby_id
		_refresh_lobby_ui()


func _on_steam_lobby_lookup_completed(found: bool, address: String, room_name: String, lobby_password: String, steam_lobby_id: String, message: String, host_port: int = -1) -> void:
	_runtime_debug_log("[SteamBridge] ", message, " room=", room_name, " id=", steam_lobby_id)
	if pending_steam_join.is_empty():
		return
	var join_data := pending_steam_join.duplicate()
	pending_steam_join.clear()
	if found and not steam_lobby_id.is_empty():
		SteamBridge.join_lobby(steam_lobby_id)
	if found and host_port > 0:
		Network.server_port = host_port
	var join_address := address if found and not address.strip_edges().is_empty() else str(join_data.get("address", Network.SERVER_ADDRESS))
	_join_lobby_direct(
		str(join_data.get("nickname", "")),
		str(join_data.get("skin", "")),
		join_address,
		lobby_password if found else str(join_data.get("lobby_id", "")),
		int(join_data.get("role", Network.Role.NONE)),
		room_name if found else str(join_data.get("room_name", "")),
		str(join_data.get("character_model", CharacterSkinCatalog.DEFAULT_ID))
	)


func _on_server_disconnected() -> void:
	if Network.is_redirecting_to_public_room():
		return
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	if game_state == GameState.LOBBY and main_menu:
		main_menu.show_landing()
		main_menu.show_menu()
		main_menu.show_join_status(I18n.t("join_status.failed"), true)
		_set_hud_visible(false)


func _show_synced_client_lobby() -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	var synced_lobby_id := str(Network.lobby_config.get("lobby_id", pending_direct_join_lobby_id)).strip_edges().to_upper()
	if synced_lobby_id.is_empty():
		synced_lobby_id = pending_direct_join_lobby_id
	pending_direct_join_lobby_id = synced_lobby_id
	main_menu.show_lobby(synced_lobby_id, false)
	_set_hud_visible(false)


func _hide_menu_after_spawn() -> void:
	# 绛?2 甯х‘淇?player 鑺傜偣瀹屾垚 add_child + _ready
	await get_tree().process_frame
	await get_tree().process_frame
	if main_menu and is_instance_valid(main_menu):
		main_menu.hide_menu()
	_sync_menu_background_performance_state(true)
	_update_mouse_capture()


func _refresh_lobby_ui(_peer_id = null, _info = null) -> void:
	if main_menu and main_menu.is_menu_visible():
		_set_hud_visible(false)
		main_menu.update_lobby(Network.players, Network.lobby_config)


func _should_spawn_player_nodes() -> bool:
	return game_state == GameState.PREP or game_state == GameState.PLAY


# -----------------------------------------------------------------------------
# 鏈嶅姟鍣?鐜╁杩炴帴 / 瑙掕壊 / spawn
# -----------------------------------------------------------------------------
func _place_player_immediate(player_node: Node, next_position: Vector3) -> void:
	if player_node == null:
		return
	if player_node.has_method("set_global_position_immediate"):
		player_node.call("set_global_position_immediate", next_position)
	elif player_node is Node3D:
		var spatial := player_node as Node3D
		spatial.global_position = next_position
		if spatial.is_inside_tree():
			spatial.reset_physics_interpolation()


func _on_player_connected(peer_id, player_info):
	_handle_room_player_joined(int(peer_id), player_info)
	if _should_spawn_player_nodes():
		_add_player(peer_id, player_info)
	_refresh_lobby_ui()
	if _is_multiplayer_server():
		_server_sync_hologram_flags_to_peer(int(peer_id))


func _on_network_player_disconnected(peer_id: int) -> void:
	var nick := str(_known_player_names.get(peer_id, "Player"))
	_known_player_names.erase(peer_id)
	if peer_id != _local_peer_id():
		_push_room_event(I18n.tf("room_event.left", [nick]))
	_refresh_lobby_ui()


func _handle_room_player_joined(peer_id: int, info: Dictionary) -> void:
	var nick := _player_name_for_event(peer_id, info)
	_known_player_names[peer_id] = nick
	if peer_id == _local_peer_id():
		return
	_push_room_event(I18n.tf("room_event.joined", [nick]))


func _remember_synced_player_names() -> void:
	for pid in Network.players.keys():
		var peer_id := int(pid)
		var info: Dictionary = Network.players.get(pid, {})
		_known_player_names[peer_id] = _player_name_for_event(peer_id, info)


func _player_name_for_event(peer_id: int, info: Dictionary = {}) -> String:
	var nick := str(info.get("nick", "")).strip_edges()
	if nick.is_empty() and Network.players.has(peer_id):
		nick = str(Network.players[peer_id].get("nick", "")).strip_edges()
	if nick.is_empty() and _known_player_names.has(peer_id):
		nick = str(_known_player_names[peer_id])
	return nick if not nick.is_empty() else "Player"


func _push_room_event(message_text: String) -> void:
	_append_room_system_chat(message_text)
	if DisplayServer.get_name() == "headless":
		return
	_show_room_toast(message_text)


func _append_room_system_chat(message_text: String) -> void:
	var nick := I18n.t("room_event.system")
	if main_menu:
		main_menu.add_lobby_chat_message(nick, message_text)
	if multiplayer_chat:
		multiplayer_chat.add_message(nick, message_text)


func _ensure_room_toast_layer() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if room_toast_layer and is_instance_valid(room_toast_layer):
		return
	room_toast_layer = CanvasLayer.new()
	room_toast_layer.name = "RoomToastLayer"
	room_toast_layer.layer = 120
	add_child(room_toast_layer)

	var margin := MarginContainer.new()
	margin.name = "RoomToastMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -430.0
	margin.offset_top = 24.0
	margin.offset_right = -24.0
	margin.offset_bottom = 320.0
	room_toast_layer.add_child(margin)

	room_toast_stack = VBoxContainer.new()
	room_toast_stack.name = "RoomToastStack"
	room_toast_stack.alignment = BoxContainer.ALIGNMENT_END
	room_toast_stack.add_theme_constant_override("separation", 8)
	margin.add_child(room_toast_stack)


func _show_room_toast(message_text: String) -> void:
	_ensure_room_toast_layer()
	if not room_toast_stack or not is_instance_valid(room_toast_stack):
		return
	var panel := PanelContainer.new()
	panel.name = "RoomToast"
	panel.custom_minimum_size = Vector2(360.0, 48.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.070, 0.090, 0.94)
	style.border_color = Color(0.95, 0.74, 0.20, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.0
	room_toast_stack.add_child(panel)

	var label := Label.new()
	label.text = message_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		if panel and is_instance_valid(panel):
			panel.queue_free()
	)


func _on_public_room_redirect_requested(_address: String, _port: int, _room_name: String, lobby_id: String) -> void:
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_lobby_id = lobby_id.strip_edges().to_upper()
	pending_direct_join_waiting_for_sync = true
	_start_public_room_join_timeout()
	if main_menu and main_menu.is_public_lobby_visible():
		main_menu.show_public_lobby_status(I18n.t("join_status.connecting_room"), false)
		main_menu.show_public_lobby_loading(I18n.t("join_status.connecting_room"))
	_set_hud_visible(false)


func _on_public_room_join_failed(reason_key: String) -> void:
	_cancel_public_room_join_timeout()
	_cancel_public_lobby_room_request_timeout()
	_returning_to_public_lobby = false
	pending_direct_join_waiting_for_sync = false
	pending_direct_join_lobby_id = ""
	if main_menu:
		if main_menu.is_public_lobby_visible():
			main_menu.hide_public_lobby_loading()
			main_menu.show_public_lobby_status(I18n.t(reason_key), true)
			if reason_key == "join_status.wrong_password":
				main_menu.show_public_lobby_alert(I18n.t("public_lobby.password_problem"), true)
		else:
			main_menu.show_landing()
			main_menu.show_menu()
			main_menu.show_join_status(I18n.t(reason_key), true)
	_set_hud_visible(false)


func _on_players_synced(_all_players: Dictionary) -> void:
	if pending_direct_join_waiting_for_sync and game_state == GameState.LOBBY and not _is_multiplayer_server():
		_show_synced_client_lobby()
	_remember_synced_player_names()
	if _should_spawn_player_nodes():
		_ensure_player_nodes_from_network()
	_refresh_party_monster_bounty_marks()
	_refresh_lobby_ui()


func _ensure_player_nodes_from_network(reposition_existing: bool = false) -> void:
	if not players_container or not _should_spawn_player_nodes():
		return
	for pid in Network.players.keys():
		var player_id := int(pid)
		var synced_player_info: Dictionary = Network.players.get(pid, {})
		if synced_player_info.is_empty():
			synced_player_info = Network.players.get(player_id, {})
		if synced_player_info.is_empty():
			continue
		if players_container.has_node(str(player_id)):
			_sync_existing_player_node(player_id, synced_player_info)
			if reposition_existing:
				_try_reposition_player(player_id)
		else:
			_add_player(player_id, synced_player_info)


func _sync_existing_player_node(peer_id: int, player_info: Dictionary) -> void:
	var player_node = players_container.get_node_or_null(str(peer_id))
	if not player_node:
		return
	if player_node.has_method("_sync_role_from_network"):
		player_node._sync_role_from_network()
	if player_node.has_method("set_character_model"):
		player_node.set_character_model(str(player_info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	if player_node.has_method("set_party_monster_accessory_loadout"):
		player_node.set_party_monster_accessory_loadout(player_info.get("party_monster_accessories", {}))
	if player_node.has_method("apply_network_alive_state"):
		player_node.apply_network_alive_state(bool(player_info.get("alive", true)))


func _on_player_role_changed(peer_id: int, new_role: int):
	if not players_container.has_node(str(peer_id)):
		_ensure_player_nodes_from_network()
	# 鎵€鏈夌閮藉搷搴?server + client)
	var player_node = players_container.get_node_or_null(str(peer_id))
	if player_node and player_node.has_method("_sync_role_from_network"):
		player_node._sync_role_from_network()
	# 绔嬪嵆 reposition(鍏抽敭淇:涔嬪墠鍙湪 server 绔?reposition,client 绔笉鍔?
	_try_reposition_player(peer_id)
	_refresh_lobby_ui()
	_update_skill_hud()


func _on_player_life_state_changed(peer_id: int, alive: bool) -> void:
	var player_node = players_container.get_node_or_null(str(peer_id)) if players_container else null
	if player_node and player_node.has_method("apply_network_alive_state"):
		player_node.apply_network_alive_state(alive)
	_update_status_hud()
	_update_skill_hud()
	_update_card_hud()
	_update_mouse_capture()


func _on_roles_assigned():
	# 鎵€鏈夌閮?reposition(瑙掕壊鍒嗛厤瀹屾垚鍚庣粺涓€澶勭悊)
	_runtime_debug_log("[Level] Roles assigned, repositioning all players")
	_ensure_player_nodes_from_network()
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
	var spawn_position := get_spawn_point_for_role(int(player_info.get("role", Network.Role.NONE)), id)
	player.position = spawn_position
	players_container.add_child(player, true)
	_place_player_immediate(player, spawn_position)

	var nick = str(player_info.get("nick", "Player_" + str(id)))
	player.nickname.text = nick

	var skin_enum = player_info.get("skin", Network.SKIN_BLUE)
	player.set_player_skin(skin_enum)
	if player.has_method("set_character_model"):
		player.set_character_model(str(player_info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	if player.has_method("set_party_monster_accessory_loadout"):
		player.set_party_monster_accessory_loadout(player_info.get("party_monster_accessories", {}))
	if player.has_method("apply_network_alive_state"):
		player.apply_network_alive_state(bool(player_info.get("alive", true)))

	# 绔嬪嵆灏濊瘯鎸夎鑹插畾浣?瑙掕壊宸插垎閰嶇殑鎯呭喌)
	# 瀹㈡埛绔彲鑳藉湪鑺傜偣 spawn 鏃惰繕涓嶇煡閬撹鑹?role=NONE),鍚庣画閫氳繃 _on_player_role_changed 鍐嶆瀹氫綅
	_try_reposition_player(id)


func _try_reposition_player(pid: int) -> bool:
	"""鎸夎鑹叉妸 player 鏀惧埌姝ｇ‘浣嶇疆銆傛墍鏈夌閮界敓鏁?server + client)"""
	if not players_container.has_node(str(pid)):
		return false
	var player_node = players_container.get_node(str(pid))
	var info = Network.players.get(pid, {})
	if info.is_empty():
		info = Network.players.get(str(pid), {})
	var role = int(info.get("role", Network.Role.NONE))

	# 瑙掕壊鏈垎閰?涓嶅仛 reposition
	if role == Network.Role.NONE:
		return false

	var new_pos = get_spawn_point_for_role(role, pid)
	_place_player_immediate(player_node, new_pos)

	# Hunter 鍦?PREP 闃舵閿佸畾
	if player_node.has_method("set_match_intro_locked"):
		player_node.set_match_intro_locked(game_state == GameState.MATCH_INTRO)
	if role == Network.Role.HUNTER and game_state == GameState.PREP:
		if player_node.has_method("set_prep_locked"):
			player_node.set_prep_locked(true)
	elif role == Network.Role.HUNTER and player_node.has_method("set_prep_locked"):
		player_node.set_prep_locked(false)

	_runtime_debug_log("[Level] Reposition player ", pid, " to role=", Network.role_to_string(role), " pos=", new_pos)
	return true


func _reposition_player_by_role(pid: int):
	# 宸插簾寮?浣跨敤 _try_reposition_player
	_try_reposition_player(pid)


func get_spawn_point_for_role(role: int, pid: int) -> Vector3:
	match role:
		Network.Role.HUNTER:
			# 鍑嗗瀹や綅缃?鐩稿浜庝富鎴樺満)
			return _get_hunter_spawn_point(pid)
		Network.Role.CHAMELEON, Network.Role.STALKER:
			# 涓绘垬鍦哄嚭鐢熷尯
			var authored_prop_spawn := _get_authored_map_spawn_point(pid)
			if authored_prop_spawn.x < INF:
				return authored_prop_spawn
			return get_grounded_spawn_position(LevelLayout.prop_spawn_point(pid, Network.get_props()))
		_:
			pass
			# 鏈垎閰嶈鑹?鏆傛椂鏀句富鎴樺満涓績
			return get_grounded_spawn_position(Vector3.ZERO)


func _get_hunter_spawn_point(pid: int) -> Vector3:
	var slot_index := _get_hunter_slot_index(pid)
	var slots := _get_preparation_room_hunter_slots()
	if not slots.is_empty():
		var slot: Marker3D = slots[slot_index % slots.size()]
		var slot_position: Vector3 = preparation_room.global_transform * slot.position
		var overflow_round: int = floori(float(slot_index) / float(slots.size()))
		if overflow_round > 0:
			slot_position += Vector3(float((overflow_round % 3) - 1) * 1.35, 0.0, floorf(float(overflow_round) / 3.0) * 1.35)
		return slot_position
	return _get_fallback_hunter_spawn_point(pid)


func _get_preparation_room_hunter_slots() -> Array[Marker3D]:
	var slots: Array[Marker3D] = []
	if not preparation_room:
		return slots
	for child in preparation_room.get_children():
		if child is Marker3D and String(child.name).begins_with("HunterSlot"):
			slots.append(child as Marker3D)
	slots.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return _get_hunter_slot_number(a.name) < _get_hunter_slot_number(b.name)
	)
	return slots


func _get_hunter_slot_index(pid: int) -> int:
	var hunter_ids := Network.get_hunters()
	hunter_ids.sort()
	var found_index: int = hunter_ids.find(pid)
	if found_index >= 0:
		return found_index
	return absi(pid) % 16


func _get_hunter_slot_number(slot_name: StringName) -> int:
	var text := String(slot_name).replace("HunterSlot", "")
	if text.is_valid_int():
		return int(text)
	return 9999


func _get_fallback_hunter_spawn_point(pid: int) -> Vector3:
	var slot: int = absi(pid) % 8
	var angle: float = float(slot) * (TAU / 8.0)
	return HUNTER_ROOM_OFFSET + Vector3(cos(angle) * HUNTER_SPAWN_RADIUS, 0.0, sin(angle) * HUNTER_SPAWN_RADIUS)


func get_spawn_point() -> Vector3:
	return get_grounded_spawn_position(LevelLayout.random_default_spawn_point())


# Returns an authored in-map spawn position from the selected map's MapController
# (its native PlayerSpawnpoints markers), or Vector3.INF when the map ships none.
# This lets imported maps (e.g. TPS Demo) place players on their real interior
# floor instead of the origin-based Warehouse layout, which only fits the default
# arena and otherwise drops players onto whatever geometry sits over the origin.
func _get_authored_map_spawn_point(pid: int) -> Vector3:
	var environment := get_node_or_null("Environment") as Node
	if environment == null:
		return Vector3(INF, INF, INF)
	var map_root := environment.get_node_or_null("TankDemoMapRoot")
	if not (map_root is MapController):
		return Vector3(INF, INF, INF)
	var controller := map_root as MapController
	if not controller.has_authored_spawns():
		return Vector3(INF, INF, INF)
	var points := controller.get_player_spawn_points()
	if points.is_empty():
		return Vector3(INF, INF, INF)
	var base := points[absi(pid) % points.size()].origin
	# Deterministic small jitter so players sharing one marker do not stack.
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(pid) * 92821 + 4801
	var angle := rng.randf() * TAU
	var radius := rng.randf_range(0.0, 1.0)
	return base + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func get_grounded_spawn_position(base_position: Vector3) -> Vector3:
	if not is_inside_tree() or not get_world_3d():
		return base_position
	var terrain_hit := _raycast_ground_position(base_position, true)
	if not terrain_hit.is_empty():
		var terrain_position: Vector3 = terrain_hit.get("position", base_position)
		return Vector3(base_position.x, terrain_position.y, base_position.z)
	var support_ground_y := _get_selected_map_support_ground_y(base_position)
	if support_ground_y > -9999.0:
		return Vector3(base_position.x, support_ground_y, base_position.z)
	var any_hit := _raycast_ground_position(base_position, false)
	if not any_hit.is_empty():
		var hit_position: Vector3 = any_hit.get("position", base_position)
		return Vector3(base_position.x, hit_position.y, base_position.z)
	return base_position


func _raycast_ground_position(base_position: Vector3, exclude_support: bool) -> Dictionary:
	var from := base_position + Vector3.UP * GROUND_RAY_UP
	var to := base_position + Vector3.DOWN * GROUND_RAY_DOWN
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if exclude_support:
		var support := _get_selected_map_support_body()
		if support:
			query.exclude = [support.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _get_selected_map_support_body() -> StaticBody3D:
	var environment := get_node_or_null("Environment") as Node
	if environment == null:
		return null
	var map_root := environment.get_node_or_null("TankDemoMapRoot") as Node
	if map_root == null:
		return null
	# Any framework map (MapController) tags its fall-through guard floor with the
	# shared group, so spawn grounding works uniformly across maps.
	for node in map_root.find_children("*", "StaticBody3D", true, false):
		var grouped := node as StaticBody3D
		if grouped and grouped.is_in_group("map_gameplay_support"):
			return grouped
	# Back-compat: the polygon apocalypse support body predates the shared group.
	var generated := map_root.get_node_or_null("GeneratedPolygonApocalypseMap") as Node
	if generated == null:
		return null
	return generated.get_node_or_null("PolygonApocalypseGameplaySupport") as StaticBody3D


func _get_selected_map_support_ground_y(base_position: Vector3) -> float:
	var support := _get_selected_map_support_body()
	if support == null:
		return -10000.0
	var shape_node := support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return -10000.0
	var shape := shape_node.shape as BoxShape3D
	var half_x := shape.size.x * 0.5
	var half_z := shape.size.z * 0.5
	if base_position.x < support.global_position.x - half_x or base_position.x > support.global_position.x + half_x:
		return -10000.0
	if base_position.z < support.global_position.z - half_z or base_position.z > support.global_position.z + half_z:
		return -10000.0
	return support.global_position.y + shape.size.y * 0.5


func _remove_player(id):
	if _is_multiplayer_server():
		_server_remove_hologram_flag(int(id))
	if not _is_multiplayer_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()


func _on_quit_pressed() -> void:
	get_tree().quit()


# =============================================================================
# 鍑嗗闃舵绠＄悊(鏈嶅姟鍣?
# =============================================================================

func _server_schedule_prep_phase() -> void:
	if not _is_multiplayer_server():
		return
	if game_state != GameState.LOBBY:
		return

	# 5s 缂撳啿(绛夋墍鏈夌帺瀹跺氨缁?
	await get_tree().create_timer(5.0).timeout

	# v0.3.3 淇:鍏佽鍗曚汉 host 涔熻兘瑙﹀彂 prep phase(鐢ㄤ簬寮€鍙戞祴璇?
	if Network.players.size() < 1:
		_runtime_debug_log("[Level] No players, aborting prep phase")
		return
	if Network.players.size() == 1:
		_runtime_debug_log("[Level] Single player mode - proceeding with 1 player (dev test)")

	# 鎵ц 1:3 鑷姩鍒嗛厤
	Network.server_auto_balance_roles(true)
	await get_tree().process_frame

	# 杩涘叆鍑嗗闃舵
	await _server_start_loading_phase()


func _on_lobby_config_changed(config: Dictionary) -> void:
	Network.request_update_lobby_config(config)


func _on_auto_assign_pressed(config: Dictionary) -> void:
	Network.request_auto_assign_roles(config)
	await get_tree().process_frame
	_refresh_lobby_ui()


func _on_start_match_pressed(config: Dictionary) -> void:
	Network.request_update_lobby_config(config)
	if _is_multiplayer_server():
		await get_tree().process_frame
		await _server_start_from_lobby()
	else:
		Network.request_start_match()


func _server_start_from_lobby() -> void:
	if not _is_multiplayer_server():
		return
	if game_state != GameState.LOBBY:
		return
	if not Network.can_start_lobby_match():
		_runtime_debug_log("[Level] Lobby is not ready to start")
		return
	Network.server_auto_balance_roles(true)
	await get_tree().process_frame
	await _server_start_loading_phase()


func _server_start_card_draft_phase() -> void:
	if not _is_multiplayer_server():
		return
	_hide_loading_overlay()
	main_menu.hide_menu()
	game_state = GameState.CARD_DRAFT
	Network.server_start_card_drafts_for_match()
	_set_hud_visible(true)
	_update_card_hud()
	_update_mouse_capture()


func _server_start_skin_config_phase() -> void:
	if not _is_multiplayer_server():
		return
	game_state = GameState.SKIN_CONFIG
	skin_config_remaining = Network.SKIN_CONFIG_TOTAL_SECONDS
	match_intro_remaining = 0.0
	prep_remaining = 0.0
	_set_preparation_room_active(true)
	_set_hud_visible(true)
	_set_match_intro_locked(true)
	_ensure_hider_party_monster_defaults()
	_show_character_setup_overlay()
	_update_character_setup_ui()
	Network.server_broadcast_skin_config_started(skin_config_remaining)
	_update_mouse_capture()


func _server_start_match_intro_phase() -> void:
	if not _is_multiplayer_server():
		return
	game_state = GameState.MATCH_INTRO
	_hide_loading_overlay()
	_ensure_hider_party_monster_defaults()
	skin_config_remaining = 0.0
	match_intro_remaining = MATCH_INTRO_DURATION
	_set_preparation_room_active(true)
	_hide_character_setup_overlay()
	_set_hud_visible(true)
	_set_match_intro_locked(true)
	_update_match_intro_ui()
	Network.server_broadcast_match_intro_started(match_intro_remaining)
	_update_mouse_capture()


func _server_start_prep_phase() -> void:
	game_state = GameState.PREP
	match_intro_remaining = 0.0
	_set_preparation_room_active(true)
	_hide_character_setup_overlay()
	_hide_match_intro_overlay()
	_set_match_intro_locked(false)
	prep_remaining = float(Network.lobby_config.get("prep_duration_sec", 30))
	Network.server_reset_alive_states()
	_ensure_player_nodes_from_network(true)
	_set_preparation_gate_open(false)
	_server_spawn_map_props()
	_server_spawn_unity_decorations()
	_server_spawn_match_pickups_for_round()
	_set_match_pickups_active(false)
	_runtime_debug_log("[Level] SERVER: prep phase starting, remaining: ", prep_remaining, "s, hunters=", Network.get_hunters().size(), " props=", Network.get_props().size())

	# 閿佸畾鎵€鏈?Hunter
	for pid in Network.get_hunters():
		if players_container.has_node(str(pid)):
			var p = players_container.get_node(str(pid))
			if p.has_method("set_prep_locked"):
				p.set_prep_locked(true)
			# 绉诲姩鍒板噯澶囧浣嶇疆
			_place_player_immediate(p, get_spawn_point_for_role(Network.Role.HUNTER, pid))

	# 鍦?server 鏈湴绔嬪嵆鏇存柊 HUD
	_runtime_debug_log("[Level] SERVER: prep_timer_label = ", prep_timer_label)
	if prep_timer_label:
		prep_timer_label.visible = false
		_update_prep_ui()
		_runtime_debug_log("[Level] SERVER: PrepTimerLabel shown, text=", prep_timer_label.text)

	_runtime_debug_log("[Level] Prep phase started, remaining: ", prep_remaining, "s")
	Network.server_broadcast_prep_started(prep_remaining)


func _server_end_prep_phase() -> void:
	game_state = GameState.PLAY
	prep_remaining = 0.0
	_set_preparation_gate_open(true)

	# 瑙ｉ攣鎵€鏈?Hunter,绉诲姩鍒颁富鎴樺満鍏ュ彛
	var hunter_ids: Array = Network.get_hunters()
	hunter_ids.sort()
	for release_index in range(hunter_ids.size()):
		var pid: int = int(hunter_ids[release_index])
		if players_container.has_node(str(pid)):
			var p = players_container.get_node(str(pid))
			if p.has_method("set_prep_locked"):
				p.set_prep_locked(false)
			# 绉诲姩鍒颁富鎴樺満鍏ュ彛
			_place_player_immediate(p, get_grounded_spawn_position(LevelLayout.hunter_release_point(release_index, hunter_ids.size())))

	_set_preparation_room_active(false)

	_runtime_debug_log("[Level] Prep phase ended, match started")
	Network.server_broadcast_prep_ended()
	_server_start_match()


func _server_start_match() -> void:
	_set_preparation_room_active(false)
	match_remaining = float(Network.lobby_config.get("match_duration_sec", 600))
	_apply_configured_gravity()
	low_gravity_check_remaining = LOW_GRAVITY_CHECK_INTERVAL
	Network.server_broadcast_match_started()
	_ensure_match_pickups_spawned()
	_set_match_pickups_active(true)
	_server_reset_party_monster_bounty_cycle()


func _server_end_match() -> void:
	game_state = GameState.END
	match_remaining = 0.0
	_apply_configured_gravity()
	Network.server_clear_match_cards()
	_set_party_monster_bounty([], 0.0)
	_runtime_debug_log("[Level] Match ended")
	# TODO: 缁撶畻鑳滆礋(PoC-1 绠€鍖?鍚庣画 PoC 鍔?


# =============================================================================
# 寮硅嵂鍖呯敓鎴?鏈嶅姟鍣?PoC-2)
# =============================================================================

func _server_spawn_map_props() -> void:
	if not _is_multiplayer_server():
		return

	var total: int = max(Network.players.size(), 1)
	var prop_count: int = LevelLayout.map_prop_count(total)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var container: Node3D = _get_or_create_map_prop_container(true)
	_map_prop_sync_budget.reset()
	var used_positions: Array[Vector3] = []
	var spawn_data: Array = []

	for i in range(prop_count):
		var prop: Dictionary = FruitPropCatalog.random_entry(rng)
		var pos: Vector3 = _get_random_map_prop_position(used_positions, LevelLayout.MAP_PROP_MIN_DISTANCE, rng)
		var size_multiplier := rng.randf_range(MAP_PROP_MIN_SCALE_MULTIPLIER, MAP_PROP_MAX_SCALE_MULTIPLIER)
		var base_scale: Vector3 = prop.get("scale", Vector3.ONE)
		var data: Dictionary = {
			"name": "MapProp_%03d_%s" % [i, str(prop.get("id", "prop")).to_upper()],
			"id": str(prop.get("id", "apple")),
			"display_name": str(prop.get("name", "Prop")),
			"category": str(prop.get("category", "prop")),
			"scene": str(prop.get("scene", "res://Prefabs/Fruits/apple.tscn")),
			"material": str(prop.get("material", "res://Materials/M_fruit.tres")),
			"scale": base_scale * size_multiplier,
			"radius": clampf(0.055 * size_multiplier, MAP_PROP_MIN_COLLISION_RADIUS, MAP_PROP_MAX_COLLISION_RADIUS),
			"size_multiplier": size_multiplier,
			"position": pos,
			"rotation_y": rng.randf_range(-PI, PI),
		}
		spawn_data.append(data)
		used_positions.append(pos)

	_runtime_debug_log("[Level] Queueing map props: ", spawn_data.size())
	_queue_map_prop_spawn_batches(container, spawn_data, true)


func _get_random_map_prop_position(used: Array[Vector3], min_dist: float, rng: RandomNumberGenerator) -> Vector3:
	return get_grounded_spawn_position(LevelLayout.random_map_prop_position(used, min_dist, rng))


func _get_or_create_map_prop_container(clear_existing: bool = true) -> Node3D:
	var existing = get_node_or_null("MapPropContainer")
	if existing:
		if clear_existing:
			for child in existing.get_children():
				child.free()
		return existing
	var container := Node3D.new()
	container.name = "MapPropContainer"
	add_child(container)
	return container


func _queue_map_prop_spawn_batches(container: Node3D, spawn_data: Array, replicate_to_clients: bool) -> void:
	_map_prop_spawn_generation += 1
	_map_prop_spawn_queue = spawn_data.duplicate()
	_map_prop_spawn_container = container
	if replicate_to_clients:
		_rpc_prepare_map_props_spawn.rpc()
	_schedule_map_prop_spawn_batch(_map_prop_spawn_generation, replicate_to_clients, true)


func _schedule_map_prop_spawn_batch(generation: int, replicate_to_clients: bool, immediate: bool = false) -> void:
	if immediate or not is_inside_tree():
		_process_map_prop_spawn_batch.call_deferred(generation, replicate_to_clients)
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		_process_map_prop_spawn_batch.call_deferred(generation, replicate_to_clients)
		return
	var timer: SceneTreeTimer = tree.create_timer(MAP_PROP_SPAWN_BATCH_DELAY_SECONDS)
	timer.timeout.connect(_process_map_prop_spawn_batch.bind(generation, replicate_to_clients), CONNECT_ONE_SHOT)


func _process_map_prop_spawn_batch(generation: int, replicate_to_clients: bool) -> void:
	if generation != _map_prop_spawn_generation:
		return
	if _map_prop_spawn_container == null or not is_instance_valid(_map_prop_spawn_container):
		_map_prop_spawn_queue.clear()
		return
	var batch: Array = []
	var limit: int = mini(MAP_PROP_SPAWN_BATCH_SIZE, _map_prop_spawn_queue.size())
	for i in range(limit):
		var data: Dictionary = _map_prop_spawn_queue.pop_front()
		_spawn_one_map_prop(_map_prop_spawn_container, data)
		batch.append(data)
	if replicate_to_clients and not batch.is_empty():
		_rpc_spawn_map_props_batch.rpc(batch, _map_prop_spawn_queue.is_empty())
	if _map_prop_spawn_queue.is_empty():
		_request_match_performance_policy_refresh()
		return
	_schedule_map_prop_spawn_batch(generation, replicate_to_clients)


@rpc("authority", "call_remote", "reliable")
func _rpc_prepare_map_props_spawn() -> void:
	_get_or_create_map_prop_container(true)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_map_props_batch(spawn_data: Array, done: bool = false) -> void:
	var container = _get_or_create_map_prop_container(false)
	for data in spawn_data:
		_spawn_one_map_prop(container, data)
	if done:
		_request_match_performance_policy_refresh()


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_map_props(spawn_data: Array) -> void:
	var container = _get_or_create_map_prop_container(true)
	_queue_map_prop_spawn_batches(container, spawn_data, false)


func _spawn_one_map_prop(container: Node3D, data: Dictionary) -> void:
	var node := FruitProp.new()
	node.name = str(data.get("name", "MapProp"))
	node.set_multiplayer_authority(1)
	container.add_child(node, true)
	node.apply_data({
		"id": str(data.get("id", "apple")),
		"name": str(data.get("display_name", data.get("name", "Prop"))),
		"category": str(data.get("category", "prop")),
		"scene": str(data.get("scene", "res://Prefabs/Fruits/apple.tscn")),
		"material": str(data.get("material", "res://Materials/M_fruit.tres")),
		"scale": data.get("scale", Vector3.ONE),
		"radius": float(data.get("radius", 0.65)),
		"position": data.get("position", Vector3.ZERO),
		"rotation_y": float(data.get("rotation_y", 0.0)),
	})


func request_map_prop_impact(prop: FruitProp, player_velocity: Vector3, contact_point: Vector3, contact_normal: Vector3, disguised_player: bool, query_tick: int = -1) -> void:
	if not prop:
		return
	if _is_multiplayer_server():
		_server_apply_map_prop_impact(prop.name, player_velocity, contact_point, contact_normal, disguised_player, 0, query_tick)
	else:
		_request_map_prop_impact_rpc.rpc_id(1, prop.name, player_velocity, contact_point, contact_normal, disguised_player, query_tick)


@rpc("any_peer", "call_local", "reliable")
func _request_map_prop_impact_rpc(prop_name: String, player_velocity: Vector3, contact_point: Vector3, contact_normal: Vector3, disguised_player: bool, query_tick: int = -1) -> void:
	if not _is_multiplayer_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_apply_map_prop_impact(prop_name, player_velocity, contact_point, contact_normal, disguised_player, sender_id, query_tick)


func _server_apply_map_prop_impact(prop_name: String, player_velocity: Vector3, contact_point: Vector3, contact_normal: Vector3, disguised_player: bool, sender_id: int, query_tick: int = -1) -> void:
	if not _is_multiplayer_server():
		return
	var prop := _get_map_prop_by_name(prop_name)
	if not prop:
		return
	if sender_id != 0:
		if not Network.players.has(sender_id):
			return
		if not _server_player_was_near_map_prop_impact(sender_id, prop, contact_point, query_tick):
			return
	if not _should_accept_map_prop_impact(prop.name, sender_id):
		return
	var reported_velocity := player_velocity
	if reported_velocity.length() > FruitProp.CLIENT_MAX_REPORTED_IMPACT_SPEED:
		reported_velocity = reported_velocity.normalized() * FruitProp.CLIENT_MAX_REPORTED_IMPACT_SPEED
	prop._apply_player_impact_authoritative(reported_velocity, contact_point, contact_normal, disguised_player)


func _server_player_was_near_map_prop_impact(sender_id: int, prop: FruitProp, contact_point: Vector3, query_tick: int) -> bool:
	var check_position: Vector3 = contact_point if contact_point != Vector3.ZERO else prop.global_position
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree()) if is_inside_tree() else null
	if history != null and query_tick >= 0:
		return history.player_was_in_radius(sender_id, check_position, MAP_PROP_IMPACT_MAX_DISTANCE, query_tick)
	var player_node := players_container.get_node_or_null(str(sender_id)) if players_container else null
	return player_node is Node3D and (player_node as Node3D).global_position.distance_to(check_position) <= MAP_PROP_IMPACT_MAX_DISTANCE


func _should_accept_map_prop_impact(prop_name: String, sender_id: int) -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if _map_prop_impact_last_msec.size() > MAP_PROP_IMPACT_THROTTLE_MAX_ENTRIES:
		_prune_map_prop_impact_throttle(now_msec)
	var key: String = "%d:%s" % [sender_id, prop_name]
	var previous_msec: int = int(_map_prop_impact_last_msec.get(key, -MAP_PROP_IMPACT_SERVER_MIN_INTERVAL_MSEC))
	if now_msec - previous_msec < MAP_PROP_IMPACT_SERVER_MIN_INTERVAL_MSEC:
		Network.record_perf_event("map_prop.impact_throttled", 1)
		return false
	_map_prop_impact_last_msec[key] = now_msec
	return true


func _prune_map_prop_impact_throttle(now_msec: int) -> void:
	var stale_keys: Array = []
	for raw_key: Variant in _map_prop_impact_last_msec.keys():
		var last_msec: int = int(_map_prop_impact_last_msec.get(raw_key, 0))
		if now_msec - last_msec > MAP_PROP_IMPACT_THROTTLE_PRUNE_MSEC:
			stale_keys.append(raw_key)
	for raw_key: Variant in stale_keys:
		_map_prop_impact_last_msec.erase(raw_key)
	if _map_prop_impact_last_msec.size() > MAP_PROP_IMPACT_THROTTLE_MAX_ENTRIES * 2:
		_map_prop_impact_last_msec.clear()


func _server_publish_map_prop_state(prop: FruitProp, reliable: bool = false) -> void:
	if not _is_multiplayer_server() or not prop:
		return
	if reliable:
		_map_prop_sync_budget.queue_rest(prop.name, prop.global_transform, prop.linear_velocity, prop.angular_velocity, prop.sleeping)
	else:
		_map_prop_sync_budget.queue_motion(prop.name, prop.global_transform, prop.linear_velocity, prop.angular_velocity, prop.sleeping)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_map_prop_motion_states(states: Array) -> void:
	for raw_state: Variant in states:
		if not (raw_state is Array):
			continue
		var state: Array = raw_state as Array
		if state.size() < 5:
			continue
		if not (state[1] is Transform3D) or not (state[2] is Vector3) or not (state[3] is Vector3):
			continue
		var prop_name: String = str(state[0])
		var next_transform: Transform3D = state[1]
		var next_linear_velocity: Vector3 = state[2]
		var next_angular_velocity: Vector3 = state[3]
		var next_sleeping: bool = bool(state[4])
		_apply_map_prop_network_state(prop_name, next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_map_prop_rest_states(states: Array) -> void:
	for raw_state: Variant in states:
		if not (raw_state is Array):
			continue
		var state: Array = raw_state as Array
		if state.size() < 5:
			continue
		if not (state[1] is Transform3D) or not (state[2] is Vector3) or not (state[3] is Vector3):
			continue
		var prop_name: String = str(state[0])
		var next_transform: Transform3D = state[1]
		var next_linear_velocity: Vector3 = state[2]
		var next_angular_velocity: Vector3 = state[3]
		var next_sleeping: bool = bool(state[4])
		_apply_map_prop_network_state(prop_name, next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_map_prop_motion_state(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	_apply_map_prop_network_state(prop_name, next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_map_prop_rest_state(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	_apply_map_prop_network_state(prop_name, next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


func _apply_map_prop_network_state(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	var prop := _get_map_prop_by_name(prop_name)
	if not prop:
		return
	prop._apply_network_physics_state(next_transform, next_linear_velocity, next_angular_velocity, next_sleeping, true)


func _get_map_prop_by_name(prop_name: String) -> FruitProp:
	var container := get_node_or_null("MapPropContainer")
	if not container:
		return null
	var prop := container.get_node_or_null(prop_name)
	if prop is FruitProp:
		return prop as FruitProp
	return null


func request_place_hologram_flag(owner_id: int, flag_transform: Transform3D, model_id: String, accessory_loadout: Dictionary, skin_color: int, player_visual_height: float, intent_tick: int = -1, intent_sequence: int = 0) -> void:
	var resolved_tick: int = NetworkTime.tick if intent_tick < 0 else intent_tick
	var resolved_sequence: int = _next_hologram_flag_intent_sequence() if intent_sequence <= 0 else intent_sequence
	var state := _sanitize_hologram_flag_state(owner_id, flag_transform, model_id, accessory_loadout, skin_color, player_visual_height, resolved_tick, resolved_sequence)
	if _is_multiplayer_server():
		_server_place_hologram_flag(owner_id, state, 0)
	else:
		_request_place_hologram_flag_rpc.rpc_id(1, owner_id, flag_transform, model_id, accessory_loadout, skin_color, player_visual_height, resolved_tick, resolved_sequence)


@rpc("any_peer", "call_local", "reliable")
func _request_place_hologram_flag_rpc(owner_id: int, flag_transform: Transform3D, model_id: String, accessory_loadout: Dictionary, skin_color: int, player_visual_height: float, intent_tick: int = -1, intent_sequence: int = 0) -> void:
	if not _is_multiplayer_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != owner_id:
		push_warning("Peer " + str(sender_id) + " tried to place hologram flag for " + str(owner_id))
		return
	var state := _sanitize_hologram_flag_state(owner_id, flag_transform, model_id, accessory_loadout, skin_color, player_visual_height, intent_tick, intent_sequence)
	_server_place_hologram_flag(owner_id, state, sender_id)


func _server_place_hologram_flag(owner_id: int, state: Dictionary, sender_id: int) -> void:
	if not _is_multiplayer_server():
		return
	if not _is_valid_hologram_flag_state(owner_id, state):
		return
	_hologram_flag_states[owner_id] = state.duplicate(true)
	_rpc_place_hologram_flag.rpc(owner_id, state)


@rpc("authority", "call_local", "reliable")
func _rpc_place_hologram_flag(owner_id: int, state: Dictionary) -> void:
	var clean_state := state.duplicate(true)
	clean_state["owner_peer_id"] = owner_id
	_hologram_flag_states[owner_id] = clean_state
	_spawn_or_update_hologram_flag(owner_id, clean_state)


func _server_remove_hologram_flag(owner_id: int) -> void:
	if not _is_multiplayer_server():
		return
	if not _hologram_flag_states.has(owner_id):
		return
	_hologram_flag_states.erase(owner_id)
	_rpc_remove_hologram_flag.rpc(owner_id)


@rpc("authority", "call_local", "reliable")
func _rpc_remove_hologram_flag(owner_id: int) -> void:
	_hologram_flag_states.erase(owner_id)
	_remove_local_hologram_flag(owner_id)


func _server_sync_hologram_flags_to_peer(peer_id: int) -> void:
	if not _is_multiplayer_server() or _hologram_flag_states.is_empty():
		return
	var states: Array = []
	for state in _hologram_flag_states.values():
		states.append((state as Dictionary).duplicate(true))
	if peer_id == _local_peer_id():
		_rpc_sync_hologram_flags(states)
	elif multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id):
		_rpc_sync_hologram_flags.rpc_id(peer_id, states)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_hologram_flags(states: Array) -> void:
	_clear_local_hologram_flags()
	_hologram_flag_states.clear()
	for raw_state in states:
		if not raw_state is Dictionary:
			continue
		var state := (raw_state as Dictionary).duplicate(true)
		var owner_id := int(state.get("owner_peer_id", 0))
		if owner_id <= 0:
			continue
		_hologram_flag_states[owner_id] = state
		_spawn_or_update_hologram_flag(owner_id, state)


func _next_hologram_flag_intent_sequence() -> int:
	_hologram_flag_intent_sequence += 1
	if _hologram_flag_intent_sequence >= 0x7fffffff:
		_hologram_flag_intent_sequence = 1
	return _hologram_flag_intent_sequence


func _sanitize_hologram_flag_state(owner_id: int, flag_transform: Transform3D, model_id: String, accessory_loadout: Dictionary, skin_color: int, player_visual_height: float, intent_tick: int = -1, intent_sequence: int = 0) -> Dictionary:
	var normalized_model: String = CharacterSkinCatalog.normalize(model_id)
	var clean_accessory_loadout: Dictionary = PartyMonsterAccessoryCatalogScript.sanitize_loadout(accessory_loadout, normalized_model)
	return {
		"owner_peer_id": owner_id,
		"transform": flag_transform,
		"character_model_id": normalized_model,
		"party_monster_accessories": clean_accessory_loadout,
		"skin_color": clampi(skin_color, 0, 3),
		"player_height": clampf(player_visual_height, 0.8, 4.0),
		"intent_tick": intent_tick,
		"server_tick": NetworkTime.tick,
		"intent_sequence": intent_sequence,
	}


func _is_valid_hologram_flag_state(owner_id: int, state: Dictionary) -> bool:
	if owner_id <= 0:
		return false
	if not Network.players.has(owner_id) and not Network.players.has(str(owner_id)):
		return false
	var flag_transform: Transform3D = state.get("transform", Transform3D.IDENTITY)
	var player_node := players_container.get_node_or_null(str(owner_id)) if players_container else null
	if player_node is Node3D:
		var distance := (player_node as Node3D).global_position.distance_to(flag_transform.origin)
		if distance > HOLOGRAM_FLAG_MAX_PLACE_DISTANCE:
			return false
	return true


func _get_or_create_hologram_flag_container() -> Node3D:
	var existing := get_node_or_null("HologramFlagContainer") as Node3D
	if existing:
		return existing
	var container := Node3D.new()
	container.name = "HologramFlagContainer"
	add_child(container)
	return container


func _spawn_or_update_hologram_flag(owner_id: int, state: Dictionary) -> HologramFlag:
	var container := _get_or_create_hologram_flag_container()
	var node_name := _hologram_flag_node_name(owner_id)
	var existing := container.get_node_or_null(node_name)
	if existing:
		container.remove_child(existing)
		existing.free()
	var flag := HologramFlagScene.instantiate() as HologramFlag
	if not flag:
		push_warning("Hologram flag scene did not instantiate")
		return null
	flag.name = node_name
	container.add_child(flag, true)
	flag.configure(state)
	var flag_transform: Transform3D = state.get("transform", Transform3D.IDENTITY)
	flag.global_transform = flag_transform
	if flag.is_inside_tree():
		flag.reset_physics_interpolation()
	return flag


func _remove_local_hologram_flag(owner_id: int) -> void:
	var container := get_node_or_null("HologramFlagContainer") as Node3D
	if not container:
		return
	var existing := container.get_node_or_null(_hologram_flag_node_name(owner_id))
	if existing:
		container.remove_child(existing)
		existing.free()


func _clear_local_hologram_flags() -> void:
	var container := get_node_or_null("HologramFlagContainer") as Node3D
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _hologram_flag_node_name(owner_id: int) -> String:
	return "HologramFlag_%d" % owner_id


func get_hologram_flag_count_for_test() -> int:
	var container := get_node_or_null("HologramFlagContainer") as Node3D
	return container.get_child_count() if container else 0


func get_hologram_flag_state_for_test(owner_id: int) -> Dictionary:
	return (_hologram_flag_states.get(owner_id, {}) as Dictionary).duplicate(true)


func _server_spawn_unity_decorations() -> void:
	if not _is_multiplayer_server():
		return

	var total: int = max(Network.players.size(), 1)
	var decor_count: int = LevelLayout.unity_decor_count(total)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var container := _get_or_create_unity_decor_container(true)
	var used_positions: Array[Vector3] = []
	var spawn_data: Array = []

	for i in range(decor_count):
		var decor: Dictionary = UnityAssetCatalog.random_active_play_decoration(rng)
		var pos: Vector3 = get_grounded_spawn_position(LevelLayout.random_unity_decor_position(used_positions, LevelLayout.UNITY_DECOR_MIN_DISTANCE, rng))
		var data := {
			"name": "UnityDecor_%03d_%s" % [i, str(decor.get("id", "decor")).to_upper()],
			"id": str(decor.get("id", "decor")),
			"display_name": str(decor.get("name", "Decoration")),
			"scene": str(decor.get("scene", "")),
			"material": str(decor.get("material", "")),
			"force_material": bool(decor.get("force_material", false)),
			"node_materials": decor.get("node_materials", {}),
			"scale": decor.get("scale", Vector3.ONE),
			"position": pos,
			"rotation_y": rng.randf_range(-PI, PI),
		}
		spawn_data.append(data)
		used_positions.append(pos)

	_runtime_debug_log("[Level] Queueing Unity decorations: ", spawn_data.size())
	_queue_unity_decor_spawn_batches(container, spawn_data, true)


func _get_or_create_unity_decor_container(clear_existing: bool = true) -> Node3D:
	var existing = get_node_or_null("UnityDecorContainer")
	if existing:
		if clear_existing:
			for child in existing.get_children():
				child.free()
		return existing
	var container := Node3D.new()
	container.name = "UnityDecorContainer"
	add_child(container)
	return container


func _queue_unity_decor_spawn_batches(container: Node3D, spawn_data: Array, replicate_to_clients: bool) -> void:
	_unity_decor_spawn_generation += 1
	_unity_decor_spawn_queue = spawn_data.duplicate()
	_unity_decor_spawn_container = container
	if replicate_to_clients:
		_rpc_prepare_unity_decorations_spawn.rpc()
	_schedule_unity_decor_spawn_batch(_unity_decor_spawn_generation, replicate_to_clients, true)


func _schedule_unity_decor_spawn_batch(generation: int, replicate_to_clients: bool, immediate: bool = false) -> void:
	if immediate or not is_inside_tree():
		_process_unity_decor_spawn_batch.call_deferred(generation, replicate_to_clients)
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		_process_unity_decor_spawn_batch.call_deferred(generation, replicate_to_clients)
		return
	var timer: SceneTreeTimer = tree.create_timer(UNITY_DECOR_SPAWN_BATCH_DELAY_SECONDS)
	timer.timeout.connect(_process_unity_decor_spawn_batch.bind(generation, replicate_to_clients), CONNECT_ONE_SHOT)


func _process_unity_decor_spawn_batch(generation: int, replicate_to_clients: bool) -> void:
	if generation != _unity_decor_spawn_generation:
		return
	if _unity_decor_spawn_container == null or not is_instance_valid(_unity_decor_spawn_container):
		_unity_decor_spawn_queue.clear()
		return
	var batch: Array = []
	var limit: int = mini(UNITY_DECOR_SPAWN_BATCH_SIZE, _unity_decor_spawn_queue.size())
	for i in range(limit):
		var data: Dictionary = _unity_decor_spawn_queue.pop_front()
		_spawn_one_unity_decoration(_unity_decor_spawn_container, data)
		batch.append(data)
	if replicate_to_clients and not batch.is_empty():
		_rpc_spawn_unity_decorations_batch.rpc(batch, _unity_decor_spawn_queue.is_empty())
	if _unity_decor_spawn_queue.is_empty():
		_request_match_performance_policy_refresh()
		return
	_schedule_unity_decor_spawn_batch(generation, replicate_to_clients)


@rpc("authority", "call_remote", "reliable")
func _rpc_prepare_unity_decorations_spawn() -> void:
	_get_or_create_unity_decor_container(true)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unity_decorations_batch(spawn_data: Array, done: bool = false) -> void:
	var container := _get_or_create_unity_decor_container(false)
	for data in spawn_data:
		_spawn_one_unity_decoration(container, data)
	if done:
		_request_match_performance_policy_refresh()


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unity_decorations(spawn_data: Array) -> void:
	var container := _get_or_create_unity_decor_container(true)
	_queue_unity_decor_spawn_batches(container, spawn_data, false)


func _spawn_one_unity_decoration(container: Node3D, data: Dictionary) -> void:
	var scene_path := str(data.get("scene", ""))
	var packed: PackedScene = _load_cached_unity_decor_scene(scene_path)
	if packed == null:
		push_warning("Unity decoration scene did not load: " + scene_path)
		return

	var node := packed.instantiate() as Node3D
	if not node:
		push_warning("Unity decoration scene did not instantiate as Node3D: " + scene_path)
		return

	node.name = str(data.get("name", "UnityDecor"))
	container.add_child(node, true)
	node.add_to_group(RANDOM_DECOR_SHADOW_NOISE_GROUP)
	node.scale = data.get("scale", Vector3.ONE)
	node.rotation.y = float(data.get("rotation_y", 0.0))
	node.global_position = data.get("position", Vector3.ZERO)
	_apply_material_to_visual_tree(node, str(data.get("material", "")), bool(data.get("force_material", false)), false)
	_apply_named_material_overrides(node, data.get("node_materials", {}))
	_align_visual_bottom_to_ground(node, float(node.global_position.y))
	_apply_unity_decoration_runtime_policy(node)
	_disable_imported_collision_objects(node)
	_add_decoration_collision_body(container, node)


func _load_cached_unity_decor_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if _unity_decor_scene_cache.has(path):
		return _unity_decor_scene_cache[path] as PackedScene
	var resource: Resource = load(path)
	var packed: PackedScene = resource as PackedScene
	if packed != null:
		_unity_decor_scene_cache[path] = packed
	return packed


func _load_cached_unity_decor_material(path: String) -> Material:
	if path.is_empty():
		return null
	if _unity_decor_material_cache.has(path):
		return _unity_decor_material_cache[path] as Material
	var resource: Resource = load(path)
	var material: Material = resource as Material
	if material != null:
		_unity_decor_material_cache[path] = material
	return material


func _apply_material_to_visual_tree(node: Node, material_path: String, force_material: bool = false, disable_collisions: bool = false) -> void:
	var material: Material = null
	if not material_path.is_empty():
		material = _load_cached_unity_decor_material(material_path)
	if node is MeshInstance3D and material:
		var mesh_instance := node as MeshInstance3D
		if force_material or not _mesh_instance_has_material(mesh_instance):
			mesh_instance.material_override = material
	if disable_collisions:
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		elif node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = 0
			(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_apply_material_to_visual_tree(child, material_path, force_material, disable_collisions)


func _mesh_instance_has_material(mesh_instance: MeshInstance3D) -> bool:
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


func _apply_named_material_overrides(node: Node, node_materials) -> void:
	if node_materials is Dictionary and node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material_map: Dictionary = node_materials
		for node_name in material_map.keys():
			if mesh_instance.name.contains(str(node_name)):
				var material_path := str(material_map[node_name])
				var material: Material = _load_cached_unity_decor_material(material_path)
				if material != null:
					mesh_instance.material_override = material
				break
	for child in node.get_children():
		_apply_named_material_overrides(child, node_materials)


func _apply_unity_decoration_runtime_policy(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	if node is AnimationPlayer:
		var animation_player := node as AnimationPlayer
		animation_player.stop()
		animation_player.active = false
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
	elif node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
	if node is GeometryInstance3D:
		var instance := node as GeometryInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		instance.visibility_range_end = UNITY_DECOR_VISUAL_CULL_RANGE
		instance.visibility_range_end_margin = UNITY_DECOR_VISUAL_CULL_MARGIN
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		_set_property_if_present(instance, "lod_bias", 0.72)
	for child in node.get_children():
		_apply_unity_decoration_runtime_policy(child)


func _disable_imported_collision_objects(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_imported_collision_objects(child)


func _add_decoration_collision_body(container: Node3D, visual_node: Node3D) -> void:
	var bounds := _calculate_visual_bounds(visual_node)
	if bounds.size == Vector3.ZERO:
		return
	var body := StaticBody3D.new()
	body.name = visual_node.name + "_Collision"
	body.collision_layer = UNITY_DECOR_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group(RANDOM_DECOR_SHADOW_NOISE_GROUP)
	container.add_child(body, true)
	body.global_position = bounds.get_center()

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(bounds.size.x + UNITY_DECOR_COLLISION_PADDING.x, 0.25),
		maxf(bounds.size.y + UNITY_DECOR_COLLISION_PADDING.y, 0.25),
		maxf(bounds.size.z + UNITY_DECOR_COLLISION_PADDING.z, 0.25)
	)
	shape_node.shape = shape
	body.add_child(shape_node)


func _configure_match_lighting() -> void:
	var light := get_node_or_null("Environment/DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = Color(1.0, 0.91, 0.78, 1.0)
		light.light_energy = 0.90
		light.shadow_enabled = true
		light.shadow_blur = 1.35
		_set_property_if_present(light, "directional_shadow_max_distance", 80.0)
		_set_property_if_present(light, "directional_shadow_fade_start", 0.80)

	var world_environment := get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if not world_environment or not world_environment.environment:
		return
	var environment := world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.76, 0.88, 1.0)
	environment.ambient_light_energy = 0.74
	environment.ambient_light_sky_contribution = 0.12
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 2.2
	environment.glow_enabled = true
	environment.glow_strength = 0.10
	environment.glow_bloom = 0.025
	environment.glow_hdr_threshold = 0.72
	environment.fog_enabled = true
	environment.fog_density = 0.0016
	environment.fog_light_color = Color(0.32, 0.42, 0.55, 1.0)
	environment.fog_aerial_perspective = 0.18
	environment.fog_sky_affect = 0.10


func _ensure_fixed_shadow_cover() -> void:
	if get_node_or_null("FixedShadowCover"):
		return
	var parent := get_node_or_null("Environment")
	if not parent:
		parent = self
	var container := Node3D.new()
	container.name = "FixedShadowCover"
	parent.add_child(container)

	_add_fixed_shadow_canopy(container, "NorthShadeAwning", Vector3(-8.0, 0.0, -10.0), Vector3(7.2, 0.32, 5.6), deg_to_rad(18.0))
	_add_fixed_shadow_canopy(container, "CenterShadeRig", Vector3(5.5, 0.0, 4.5), Vector3(6.4, 0.32, 6.4), deg_to_rad(-22.0))
	_add_fixed_shadow_canopy(container, "EastShadeLeanTo", Vector3(13.0, 0.0, -1.5), Vector3(5.6, 0.32, 7.0), deg_to_rad(42.0))
	_add_fixed_shadow_canopy(container, "SouthShadeCrateRoof", Vector3(-2.5, 0.0, 13.5), Vector3(8.0, 0.30, 4.8), deg_to_rad(-8.0))


func _add_fixed_shadow_canopy(parent: Node, base_name: String, base_position: Vector3, roof_size: Vector3, yaw: float) -> void:
	var roof_height := 3.05
	_add_fixed_shadow_box(parent, base_name + "_Roof", base_position + Vector3(0.0, roof_height, 0.0), roof_size, yaw, FIXED_SHADOW_COVER_MATERIAL)
	_add_fixed_shadow_zone(parent, base_name + "_ShadowZone", base_position + Vector3(0.0, 1.05, 0.0), Vector3(roof_size.x * 1.55, 2.3, roof_size.z * 1.65), yaw)
	var post_offsets := [
		Vector3(-roof_size.x * 0.42, 1.35, -roof_size.z * 0.38),
		Vector3(roof_size.x * 0.42, 1.35, -roof_size.z * 0.38),
		Vector3(-roof_size.x * 0.42, 1.35, roof_size.z * 0.38),
		Vector3(roof_size.x * 0.42, 1.35, roof_size.z * 0.38),
	]
	for i in range(post_offsets.size()):
		_add_fixed_shadow_box(parent, "%s_Post_%d" % [base_name, i], base_position + post_offsets[i].rotated(Vector3.UP, yaw), Vector3(0.28, 2.7, 0.28), yaw, Color(0.16, 0.11, 0.075, 1.0))


func _add_fixed_shadow_zone(parent: Node, node_name: String, position: Vector3, size: Vector3, yaw: float) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.add_to_group(FIXED_SHADOW_ZONE_GROUP)
	area.position = position
	area.rotation.y = yaw
	parent.add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)


func _add_fixed_shadow_box(parent: Node, node_name: String, position: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = UNITY_DECOR_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group(FIXED_SHADOW_COVER_GROUP)
	body.position = position
	body.rotation.y = yaw
	parent.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_instance.material_override = material
	body.add_child(mesh_instance)


func _set_property_if_present(object: Object, property_name: String, value) -> void:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			object.set(property_name, value)
			return


func _align_visual_bottom_to_ground(node: Node3D, ground_y: float) -> void:
	var bounds := _calculate_visual_bounds(node)
	if bounds.size == Vector3.ZERO:
		return
	node.global_position.y += ground_y - bounds.position.y


func _calculate_visual_bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(root, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _find_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_mesh_instances(child, result)


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


func _match_pickups_are_active() -> bool:
	return game_state == GameState.PLAY


func _apply_match_pickups_active(active: bool) -> void:
	if not active:
		_match_pickup_activation_queue.clear()
		_match_pickup_activation_active = false
		for raw_pickup: Node in _collect_match_pickups():
			_apply_match_pickup_active_state(raw_pickup, false)
		return
	_match_pickup_activation_queue = _collect_match_pickups()
	_match_pickup_activation_active = not _match_pickup_activation_queue.is_empty()


func _collect_match_pickups() -> Array[Node]:
	var pickups: Array[Node] = []
	var tree := get_tree()
	if tree == null:
		return pickups
	for raw_pickup: Node in tree.get_nodes_in_group("ammo_pickups"):
		if raw_pickup != null and is_instance_valid(raw_pickup):
			pickups.append(raw_pickup)
	for raw_pickup: Node in tree.get_nodes_in_group("party_monster_accessory_pickups"):
		if raw_pickup != null and is_instance_valid(raw_pickup):
			pickups.append(raw_pickup)
	return pickups


func _process_match_pickup_activation_queue(max_to_process: int = MATCH_PICKUP_ACTIVATION_BATCH_SIZE) -> void:
	if not _match_pickup_activation_active:
		return
	if _match_pickup_activation_queue.is_empty():
		_match_pickup_activation_active = false
		return
	var processed: int = 0
	var budget: int = maxi(max_to_process, 1)
	while processed < budget and not _match_pickup_activation_queue.is_empty():
		var raw_pickup: Node = _match_pickup_activation_queue.pop_front() as Node
		if raw_pickup == null or not is_instance_valid(raw_pickup):
			continue
		_apply_match_pickup_active_state(raw_pickup, true)
		processed += 1
	if _match_pickup_activation_queue.is_empty():
		_match_pickup_activation_active = false


func _apply_match_pickup_active_state(raw_pickup: Node, active: bool) -> void:
	if raw_pickup != null and is_instance_valid(raw_pickup) and raw_pickup.has_method("set_match_active"):
		raw_pickup.call("set_match_active", active)


@rpc("authority", "call_local", "reliable")
func _rpc_set_match_pickups_active(active: bool) -> void:
	_apply_match_pickups_active(active)


func _set_match_pickups_active(active: bool) -> void:
	if _is_multiplayer_server() and _has_runtime_multiplayer_peer():
		_rpc_set_match_pickups_active.rpc(active)
	else:
		_apply_match_pickups_active(active)


func _has_spawned_match_pickups() -> bool:
	var ammo_container: Node = get_node_or_null("AmmoPackContainer")
	var accessory_container: Node = get_node_or_null("PartyMonsterAccessoryContainer")
	return ammo_container != null and ammo_container.get_child_count() > 0 and accessory_container != null and accessory_container.get_child_count() > 0


func _server_spawn_match_pickups_for_round() -> void:
	if not _is_multiplayer_server():
		return
	_server_spawn_ammo_packs()
	_server_spawn_party_monster_accessory_pickups()


func _ensure_match_pickups_spawned() -> void:
	if _has_spawned_match_pickups():
		return
	_server_spawn_match_pickups_for_round()


func _server_spawn_ammo_packs() -> void:
	if not _is_multiplayer_server():
		return

	var total = Network.players.size()
	var ammo_counts: Dictionary = LevelLayout.ammo_pack_counts(total)
	var small_n: int = int(ammo_counts.get("small", 0))
	var medium_n: int = int(ammo_counts.get("medium", 0))
	var large_n: int = int(ammo_counts.get("large", 0))

	_runtime_debug_log("[Level] Spawning ammo packs: ", small_n, " small, ", medium_n, " medium, ", large_n, " large")

	var ammo_scene = preload("res://scripts/ammo_pickup.gd")
	var container = _get_or_create_ammo_container()

	# 闅忔満鏁ｈ惤(閬垮厤閲嶅彔)
	var used_positions: Array[Vector3] = []
	var min_distance: float = LevelLayout.AMMO_PACK_MIN_DISTANCE
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

	_apply_match_pickups_active(_match_pickups_are_active())
	_rpc_spawn_ammo_packs.rpc(spawn_data)
	_request_match_performance_policy_refresh()


func _get_random_ammo_position(used: Array[Vector3], min_dist: float) -> Vector3:
	return get_grounded_spawn_position(LevelLayout.random_ammo_position(used, min_dist)) + Vector3.UP * 0.08


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
	_apply_match_pickups_active(_match_pickups_are_active())
	_request_match_performance_policy_refresh()


func _spawn_one_ammo(container: Node3D, ammo_script, data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var type: int = data.get("type", AmmoPickup.AmmoType.SMALL)
	var node: Area3D = Area3D.new()
	node.set_script(ammo_script)
	node.name = data.get("name", "AmmoPack_" + str(type))
	node.set("ammo_type", type)
	node.collision_layer = 4  # ammo layer

	# Visual marker.
	var marker_color: Color = AmmoPickup.AMMO_COLORS.get(type, Color.WHITE)
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh_inst.visibility_range_end = MATCH_PERFORMANCE_PICKUP_VISIBILITY_RANGE
	mesh_inst.visibility_range_end_margin = MATCH_PERFORMANCE_PICKUP_VISIBILITY_MARGIN
	mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh_inst.mesh = _make_runtime_ammo_mesh(type)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = marker_color
	mat.emission_enabled = true
	mat.emission = marker_color
	mat.emission_energy_multiplier = 0.5
	mat.roughness = 0.72
	mesh_inst.set_surface_override_material(0, mat)
	node.add_child(mesh_inst)

	# Floating pickup label.
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = str(AmmoPickup.AMMO_LABELS.get(type, "?"))
	label.position = Vector3(0, AmmoPickup.label_height_for_type(type), 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_modulate = marker_color
	label.visibility_range_end = MATCH_PERFORMANCE_PICKUP_LABEL_VISIBILITY_RANGE
	label.visibility_range_end_margin = MATCH_PERFORMANCE_PICKUP_VISIBILITY_MARGIN
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	node.add_child(label)

	# Pickup trigger shape.
	var coll: CollisionShape3D = CollisionShape3D.new()
	coll.name = "PickupTrigger"
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = AmmoPickup.collision_radius_for_type(type)
	coll.shape = sphere
	node.add_child(coll)

	container.add_child(node, true)
	node.position = pos
	node.set_deferred("ammo_type", type)
	if node.has_method("set_match_active"):
		node.call("set_match_active", _match_pickups_are_active())


func _make_runtime_ammo_mesh(type: int) -> Mesh:
	if type == AmmoPickup.AmmoType.SPECIAL:
		var cache_mesh: CylinderMesh = CylinderMesh.new()
		cache_mesh.top_radius = 0.24
		cache_mesh.bottom_radius = 0.24
		cache_mesh.height = 0.44
		cache_mesh.radial_segments = 12
		return cache_mesh
	var box_mesh: BoxMesh = BoxMesh.new()
	match type:
		AmmoPickup.AmmoType.MEDIUM:
			box_mesh.size = Vector3(0.54, 0.34, 0.34)
		AmmoPickup.AmmoType.LARGE:
			box_mesh.size = Vector3(0.72, 0.42, 0.46)
		_:
			box_mesh.size = Vector3(0.42, 0.26, 0.30)
	return box_mesh


func _server_spawn_party_monster_accessory_pickups() -> void:
	if not _is_multiplayer_server():
		return
	_party_monster_accessory_spawn_round += 1
	var total_players: int = max(Network.players.size(), 1)
	var pickup_count: int = clampi(total_players + 18, PARTY_MONSTER_ACCESSORY_MIN_PICKUPS, PARTY_MONSTER_ACCESSORY_MAX_PICKUPS)
	var spawn_seed: int = int(_party_monster_rng.randi() ^ (_party_monster_accessory_spawn_round * 4099) ^ Time.get_ticks_msec())
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = spawn_seed
	var accessory_ids: Array = PartyMonsterAccessoryCatalogScript.random_balanced_accessory_ids(spawn_seed, pickup_count, PARTY_MONSTER_ACCESSORY_MIN_PER_SLOT)
	var container: Node3D = _get_or_create_party_monster_accessory_container()
	var used_positions: Array[Vector3] = []
	var spawn_data: Array = []
	for index: int in range(accessory_ids.size()):
		var accessory_id: String = str(accessory_ids[index])
		var pos: Vector3 = _get_random_party_monster_accessory_position(used_positions, PARTY_MONSTER_ACCESSORY_MIN_DISTANCE, spawn_rng)
		var data: Dictionary = {
			"name": "PartyMonsterAccessory_%02d_%03d_%s" % [_party_monster_accessory_spawn_round, index, accessory_id],
			"accessory_id": accessory_id,
			"position": pos,
		}
		_spawn_one_party_monster_accessory(container, data)
		spawn_data.append(data)
		used_positions.append(pos)
	_apply_match_pickups_active(_match_pickups_are_active())
	_rpc_spawn_party_monster_accessories.rpc(spawn_data)
	_request_match_performance_policy_refresh()


func _get_random_party_monster_accessory_position(used: Array[Vector3], min_dist: float, rng: RandomNumberGenerator) -> Vector3:
	return get_grounded_spawn_position(LevelLayout.random_ammo_position_with_rng(used, min_dist, rng)) + Vector3.UP * 0.10


func _get_or_create_party_monster_accessory_container() -> Node3D:
	var existing: Node = get_node_or_null("PartyMonsterAccessoryContainer")
	if existing:
		for child: Node in existing.get_children():
			child.free()
		return existing as Node3D
	var container: Node3D = Node3D.new()
	container.name = "PartyMonsterAccessoryContainer"
	add_child(container)
	return container


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_party_monster_accessories(spawn_data: Array) -> void:
	var container: Node3D = _get_or_create_party_monster_accessory_container()
	for raw_data: Variant in spawn_data:
		var data: Dictionary = raw_data as Dictionary
		_spawn_one_party_monster_accessory(container, data)
	_apply_match_pickups_active(_match_pickups_are_active())
	_request_match_performance_policy_refresh()


func _spawn_one_party_monster_accessory(container: Node3D, data: Dictionary) -> void:
	var accessory_id: String = str(data.get("accessory_id", ""))
	if PartyMonsterAccessoryCatalogScript.get_accessory(accessory_id).is_empty():
		return
	var node: Area3D = Area3D.new()
	node.set_script(PartyMonsterAccessoryPickupScript)
	node.name = str(data.get("name", "PartyMonsterAccessory"))
	node.collision_layer = 4
	node.set("accessory_id", accessory_id)
	container.add_child(node, true)
	node.position = data.get("position", Vector3.ZERO)
	if node.has_method("set_match_active"):
		node.call("set_match_active", _match_pickups_are_active())


func _server_reset_party_monster_bounty_cycle() -> void:
	party_monster_bounty_next_timer = PARTY_MONSTER_BOUNTY_FIRST_DELAY
	party_monster_bounty_clear_timer = 0.0
	_set_party_monster_bounty([], 0.0)


func _server_process_party_monster_bounties(delta: float) -> void:
	if not _is_multiplayer_server():
		return
	if not party_monster_bounty_accessories.is_empty():
		party_monster_bounty_marked_count = _count_party_monster_bounty_marked_players()
		if party_monster_bounty_marked_count <= 0:
			party_monster_bounty_clear_timer = maxf(0.0, party_monster_bounty_clear_timer - delta)
			if party_monster_bounty_clear_timer <= 0.0:
				_set_party_monster_bounty([], 0.0)
				party_monster_bounty_next_timer = PARTY_MONSTER_BOUNTY_ESCAPE_REST_SECONDS
				return
		else:
			party_monster_bounty_clear_timer = PARTY_MONSTER_BOUNTY_CLEAR_GRACE
		if party_monster_bounty_remaining <= 0.0:
			_set_party_monster_bounty([], 0.0)
			party_monster_bounty_next_timer = PARTY_MONSTER_BOUNTY_REST_SECONDS
		return
	party_monster_bounty_next_timer = maxf(0.0, party_monster_bounty_next_timer - delta)
	if party_monster_bounty_next_timer <= 0.0:
		_server_start_new_party_monster_bounty()


func _server_start_new_party_monster_bounty() -> void:
	var target_count: int = 2 if _party_monster_rng.randf() < 0.55 else 1
	var carried_pool: Array = _party_monster_bounty_candidate_ids()
	var target_ids: Array = _pick_party_monster_bounty_ids(carried_pool, target_count, true)
	if target_ids.is_empty():
		target_ids = PartyMonsterAccessoryCatalogScript.random_accessory_ids(_party_monster_rng.randi(), target_count, true)
	if target_ids.is_empty():
		party_monster_bounty_next_timer = PARTY_MONSTER_BOUNTY_REST_SECONDS
		return
	_set_party_monster_bounty(target_ids, PARTY_MONSTER_BOUNTY_ACTIVE_SECONDS)


func _party_monster_bounty_candidate_ids() -> Array:
	var result: Array = []
	for raw_info: Variant in Network.players.values():
		var info: Dictionary = raw_info as Dictionary
		var role: int = int(info.get("role", Network.Role.NONE))
		if role != Network.Role.CHAMELEON and role != Network.Role.STALKER:
			continue
		if not bool(info.get("alive", true)):
			continue
		var model_id: String = CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
		if not CharacterSkinCatalog.is_party_monster(model_id):
			continue
		var loadout: Dictionary = PartyMonsterAccessoryCatalogScript.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
		for raw_id: Variant in loadout.values():
			var accessory_id: String = PartyMonsterAccessoryCatalogScript.normalize_accessory_id(str(raw_id))
			if accessory_id.is_empty() or result.has(accessory_id):
				continue
			result.append(accessory_id)
	return result


func _pick_party_monster_bounty_ids(accessory_ids: Array, count: int, unique_slots: bool) -> Array:
	var pool: Array = []
	for raw_id: Variant in accessory_ids:
		var accessory_id: String = PartyMonsterAccessoryCatalogScript.normalize_accessory_id(str(raw_id))
		if accessory_id.is_empty() or pool.has(accessory_id):
			continue
		pool.append(accessory_id)
	var result: Array = []
	var used_slots := {}
	while not pool.is_empty() and result.size() < count:
		var index: int = _party_monster_rng.randi_range(0, pool.size() - 1)
		var accessory_id: String = str(pool[index])
		pool.remove_at(index)
		var slot: String = PartyMonsterAccessoryCatalogScript.accessory_slot(accessory_id)
		if unique_slots and used_slots.has(slot):
			continue
		used_slots[slot] = true
		result.append(accessory_id)
	return result


func _set_party_monster_bounty(accessory_ids: Array, remaining: float) -> void:
	var clean_ids: Array = []
	for raw_id: Variant in accessory_ids:
		var accessory_id: String = PartyMonsterAccessoryCatalogScript.normalize_accessory_id(str(raw_id))
		if accessory_id.is_empty() or clean_ids.has(accessory_id):
			continue
		clean_ids.append(accessory_id)
	party_monster_bounty_clear_timer = PARTY_MONSTER_BOUNTY_CLEAR_GRACE if not clean_ids.is_empty() else 0.0
	_rpc_set_party_monster_bounty.rpc(clean_ids, maxf(remaining, 0.0))


@rpc("authority", "call_local", "reliable")
func _rpc_set_party_monster_bounty(accessory_ids: Array, remaining: float) -> void:
	party_monster_bounty_accessories = accessory_ids.duplicate()
	party_monster_bounty_remaining = maxf(remaining, 0.0)
	party_monster_bounty_clear_timer = PARTY_MONSTER_BOUNTY_CLEAR_GRACE if not party_monster_bounty_accessories.is_empty() else 0.0
	if party_monster_bounty_accessories.is_empty():
		party_monster_bounty_remaining = 0.0
	var label: String = PartyMonsterAccessoryCatalogScript.bounty_label(party_monster_bounty_accessories)
	if not party_monster_bounty_accessories.is_empty() and DisplayServer.get_name() != "headless":
		show_combat_feedback("BOUNTY: " + label, Color(1.0, 0.30, 0.95, 1.0), 1.6)
	_refresh_party_monster_bounty_marks()
	_update_status_hud()
	_update_party_monster_hunt_hud()


func _refresh_party_monster_bounty_marks() -> void:
	party_monster_bounty_marked_count = _count_party_monster_bounty_marked_players()
	if not players_container:
		return
	var label: String = PartyMonsterAccessoryCatalogScript.bounty_label(party_monster_bounty_accessories)
	for raw_player: Node in players_container.get_children():
		var player: Node = raw_player
		if not player.has_method("set_party_monster_bounty_marked"):
			continue
		var peer_id: int = int(str(player.name))
		var info: Dictionary = Network.players.get(peer_id, {})
		var marked: bool = _should_mark_party_monster_bounty_player(info)
		player.set_party_monster_bounty_marked(marked, party_monster_bounty_accessories, label)
	_refresh_party_monster_accessory_pickup_beacons()


func _refresh_party_monster_accessory_pickup_beacons() -> void:
	var tree := get_tree()
	if not tree:
		return
	tree.call_group("party_monster_accessory_pickups", "refresh_bounty_beacon_visibility")


func _count_party_monster_bounty_marked_players() -> int:
	var count := 0
	for raw_info: Variant in Network.players.values():
		var info: Dictionary = raw_info as Dictionary
		if _should_mark_party_monster_bounty_player(info):
			count += 1
	return count


func _should_mark_party_monster_bounty_player(info: Dictionary) -> bool:
	if party_monster_bounty_accessories.is_empty():
		return false
	var role: int = int(info.get("role", Network.Role.NONE))
	if role != Network.Role.CHAMELEON and role != Network.Role.STALKER:
		return false
	if not bool(info.get("alive", true)):
		return false
	var model_id: String = CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	if not CharacterSkinCatalog.is_party_monster(model_id):
		return false
	var loadout: Dictionary = PartyMonsterAccessoryCatalogScript.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
	return PartyMonsterAccessoryCatalogScript.loadout_has_any_accessory(loadout, party_monster_bounty_accessories)


# =============================================================================
# 瀹㈡埛绔?闃舵浜嬩欢鍥炶皟
# =============================================================================

func _on_skin_config_started(remaining: float) -> void:
	game_state = GameState.SKIN_CONFIG
	_hide_loading_overlay()
	skin_config_remaining = maxf(0.0, remaining)
	match_intro_remaining = 0.0
	prep_remaining = 0.0
	_set_preparation_room_active(true)
	_hide_match_intro_overlay()
	if main_menu:
		main_menu.hide_menu()
	_set_hud_visible(true)
	_show_character_setup_overlay()
	_update_card_hud()
	_update_mouse_capture()
	_runtime_debug_log("[Level] Client received: skin config starting, ", remaining, "s remaining")


func _on_match_intro_started(remaining: float) -> void:
	game_state = GameState.MATCH_INTRO
	_hide_loading_overlay()
	match_intro_remaining = maxf(0.0, remaining)
	skin_config_remaining = 0.0
	prep_remaining = 0.0
	_set_preparation_room_active(true)
	_hide_character_setup_overlay()
	if main_menu:
		main_menu.hide_menu()
	_set_hud_visible(true)
	_update_card_hud()
	_set_match_intro_locked(true)
	_update_match_intro_ui()
	_update_mouse_capture()
	_runtime_debug_log("[Level] Client received: match intro starting, ", remaining, "s remaining")


func _on_prep_phase_started(remaining: float) -> void:
	game_state = GameState.PREP
	_apply_match_pickups_active(false)
	_hide_loading_overlay()
	match_intro_remaining = 0.0
	_set_preparation_room_active(true)
	_hide_character_setup_overlay()
	_hide_match_intro_overlay()
	_set_match_intro_locked(false)
	prep_remaining = remaining
	_set_preparation_gate_open(false)
	if main_menu:
		main_menu.hide_menu()
	_set_hud_visible(true)
	_update_card_hud()
	_update_mouse_capture()
	_runtime_debug_log("[Level] Client received: prep phase started, ", remaining, "s remaining")
	# 鏄剧ず鍊掕鏃?HUD
	_runtime_debug_log("[Level] prep_timer_label = ", prep_timer_label, " is_inside_tree = ", prep_timer_label != null and prep_timer_label.is_inside_tree())
	if prep_timer_label:
		prep_timer_label.visible = false
		_update_prep_ui()
		_runtime_debug_log("[Level] PrepTimerLabel visible = ", prep_timer_label.visible, " text = ", prep_timer_label.text, " global_pos = ", prep_timer_label.global_position)
	else:
		_runtime_debug_log("[Level] WARNING: prep_timer_label is null - HUDCanvas/PrepTimerLabel node not found!")

	_ensure_player_nodes_from_network()
	for pid in Network.players.keys():
		_try_reposition_player(pid)


func _on_prep_phase_ended() -> void:
	game_state = GameState.PLAY
	_apply_match_pickups_active(true)
	_hide_loading_overlay()
	match_intro_remaining = 0.0
	_hide_match_intro_overlay()
	_set_match_intro_locked(false)
	_set_hud_visible(true)
	_update_card_hud()
	_set_preparation_gate_open(true)
	_set_preparation_room_active(false)
	# 闅愯棌鍊掕鏃?HUD
	if prep_timer_label:
		prep_timer_label.visible = false
	var hunter_ids: Array = Network.get_hunters()
	hunter_ids.sort()
	for release_index in range(hunter_ids.size()):
		var pid: int = int(hunter_ids[release_index])
		var player_node = players_container.get_node_or_null(str(pid))
		if player_node == null:
			continue
		if player_node.has_method("set_prep_locked"):
			player_node.set_prep_locked(false)
		# The Hunter is owned + client-predicted; the server-side release teleport alone
		# fights the owner's local prediction (still simulating from the prep room) and
		# produces the stuck-jitter / endless-jump desync. Re-anchor the LOCALLY-OWNED
		# Hunter's own predicted state to the same deterministic release point the server
		# uses (sorted hunter ids + index), so owner and server agree on the spawn.
		if player_node.has_method("_is_local_authority") and player_node.call("_is_local_authority") \
				and player_node.has_method("set_global_position_immediate"):
			player_node.call("set_global_position_immediate", get_grounded_spawn_position(LevelLayout.hunter_release_point(release_index, hunter_ids.size())))


func _on_match_started() -> void:
	game_state = GameState.PLAY
	_apply_match_pickups_active(true)
	_hide_loading_overlay()
	match_intro_remaining = 0.0
	_set_preparation_room_active(false)
	_hide_match_intro_overlay()
	_set_match_intro_locked(false)
	match_remaining = float(Network.lobby_config.get("match_duration_sec", 600))
	_apply_configured_gravity()
	low_gravity_check_remaining = LOW_GRAVITY_CHECK_INTERVAL
	_update_card_hud()


func _process_gravity_events(delta: float) -> void:
	if gravity_event_remaining > 0.0:
		gravity_event_remaining = max(0.0, gravity_event_remaining - delta)
		if gravity_event_remaining <= 0.0:
			gravity_event_label = ""
			_apply_configured_gravity()
	if not _is_multiplayer_server():
		return
	if not bool(Network.lobby_config.get("low_gravity_events", false)):
		return
	if str(Network.lobby_config.get("game_show", "None")) != "Chaos Show":
		return
	if gravity_event_remaining > 0.0:
		return
	low_gravity_check_remaining = max(0.0, low_gravity_check_remaining - delta)
	if low_gravity_check_remaining > 0.0:
		return
	low_gravity_check_remaining = LOW_GRAVITY_CHECK_INTERVAL
	if randf() <= LOW_GRAVITY_EVENT_CHANCE:
		_server_start_low_gravity_event()


func _server_start_low_gravity_event() -> void:
	if not _is_multiplayer_server():
		return
	var event_gravity := clampf(base_gravity_mps2 * LOW_GRAVITY_MULTIPLIER, 2.0, base_gravity_mps2)
	_apply_gravity_event.rpc(event_gravity, LOW_GRAVITY_EVENT_DURATION, I18n.t("gravity_event.low"))


@rpc("authority", "call_local", "reliable")
func _apply_gravity_event(gravity_value: float, duration: float, label: String) -> void:
	gravity_event_remaining = maxf(duration, 0.0)
	gravity_event_label = label
	_apply_gravity(gravity_value)
	show_combat_feedback(label, Color(0.45, 0.82, 1.0, 1.0), 1.6)


func _apply_configured_gravity() -> void:
	base_gravity_mps2 = clampf(float(Network.lobby_config.get("gravity_mps2", 9.8)), 2.0, 20.0)
	gravity_event_remaining = 0.0
	gravity_event_label = ""
	_apply_gravity(base_gravity_mps2)


func _apply_gravity(gravity_value: float) -> void:
	active_gravity_mps2 = clampf(gravity_value, 1.5, 24.0)
	ProjectSettings.set_setting("physics/3d/default_gravity", active_gravity_mps2)
	_apply_gravity_to_players()
	_apply_gravity_to_props()


func _apply_gravity_to_players() -> void:
	if not players_container:
		return
	for player in players_container.get_children():
		if _node_has_property(player, "gravity"):
			player.set("gravity", active_gravity_mps2)


func _apply_gravity_to_props() -> void:
	# Active rigid bodies read ProjectSettings gravity directly; waking every resting disguise prop causes a hunt-start physics spike.
	return


func _node_has_property(node: Object, property_name: String) -> bool:
	if not node:
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _update_prep_ui() -> void:
	if not prep_timer_label:
		return
	var secs = int(ceil(prep_remaining))
	var mins = secs / 60
	var sec = secs % 60
	prep_timer_label.text = "%s: %02d:%02d" % [I18n.t("prep_remaining"), mins, sec]
	# 鏈€鍚?10 绉掑彉绾㈣壊
	if secs <= 10:
		prep_timer_label.modulate = Color(1.5, 0.3, 0.3, 1)
	else:
		prep_timer_label.modulate = Color(1, 1, 1, 1)


func _sync_active_match_training_targets(force: bool = false) -> void:
	var should_suspend: bool = game_state == GameState.PLAY
	if not force and should_suspend == _training_targets_suspended_for_match:
		return
	_training_targets_suspended_for_match = should_suspend
	_set_training_targets_active(not should_suspend)


func _set_training_targets_active(active: bool) -> void:
	var training_targets: Node3D = get_node_or_null("TrainingTargets") as Node3D
	if training_targets == null:
		return
	training_targets.visible = active
	if active:
		if _training_targets_process_mode_before_suspend >= 0:
			training_targets.process_mode = _training_targets_process_mode_before_suspend as Node.ProcessMode
			_training_targets_process_mode_before_suspend = -1
	else:
		if _training_targets_process_mode_before_suspend < 0:
			_training_targets_process_mode_before_suspend = training_targets.process_mode
		training_targets.process_mode = Node.PROCESS_MODE_DISABLED
	var shapes: Array[Node] = training_targets.find_children("*", "CollisionShape3D", true, false)
	for node: Node in shapes:
		var shape: CollisionShape3D = node as CollisionShape3D
		if shape != null:
			shape.disabled = not active
	var animation_players: Array[Node] = training_targets.find_children("*", "AnimationPlayer", true, false)
	for node: Node in animation_players:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if animation_player != null:
			animation_player.active = active
			if not active:
				animation_player.stop()


func _set_preparation_room_active(active: bool) -> void:
	if not preparation_room:
		return
	preparation_room.visible = active
	_set_preparation_room_process_enabled(active)
	_set_preparation_room_collisions_enabled(active)
	if active:
		_set_preparation_gate_open(false)


func _set_preparation_room_process_enabled(enabled: bool) -> void:
	if not preparation_room:
		return
	if enabled:
		if _preparation_room_process_mode_before_suspend >= 0:
			preparation_room.process_mode = _preparation_room_process_mode_before_suspend as Node.ProcessMode
			_preparation_room_process_mode_before_suspend = -1
		return
	if _preparation_room_process_mode_before_suspend < 0:
		_preparation_room_process_mode_before_suspend = preparation_room.process_mode
	preparation_room.process_mode = Node.PROCESS_MODE_DISABLED


func _set_preparation_room_collisions_enabled(enabled: bool) -> void:
	if not preparation_room:
		return
	var shapes: Array[Node] = preparation_room.find_children("*", "CollisionShape3D", true, false)
	for node in shapes:
		var shape: CollisionShape3D = node as CollisionShape3D
		if shape == null:
			continue
		shape.disabled = (not enabled) or _is_legacy_preparation_wall_or_gate(shape)


func _is_legacy_preparation_wall_or_gate(shape: CollisionShape3D) -> bool:
	var current: Node = shape
	while current and current != preparation_room:
		var node_name: String = String(current.name)
		if node_name == "WallNorth" or node_name == "WallSouth" or node_name == "WallEast" or node_name == "WallWest" or node_name == "Gate":
			return true
		current = current.get_parent()
	return false


func _set_preparation_gate_open(open: bool) -> void:
	if not preparation_room:
		return
	var gate: Node = preparation_room.get_node_or_null("Gate")
	if not gate:
		return
	gate.visible = false
	for child in gate.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	_runtime_debug_log("[Level] Preparation gate ", "opened" if open else "closed", " (legacy gate collider disabled)")


func _ensure_debug_overlay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud: CanvasLayer = $HUDCanvas
	debug_overlay = hud.get_node_or_null("DebugOverlay") as DebugOverlay
	if not debug_overlay:
		debug_overlay = DebugOverlayScript.new() as DebugOverlay
		debug_overlay.name = "DebugOverlay"
		hud.add_child(debug_overlay)


func _ensure_status_hud() -> void:
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	status_label = hud.get_node_or_null("StatusLabel")
	if not status_label:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.position = Vector2(16, 16)
		status_label.add_theme_font_size_override("font_size", 20)
		status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		status_label.add_theme_constant_override("shadow_offset_x", 2)
		status_label.add_theme_constant_override("shadow_offset_y", 2)
		hud.add_child(status_label)
	status_label.position = Vector2(16, 138 if debug_overlay else 16)

	combat_feedback_label = hud.get_node_or_null("CombatFeedbackLabel")
	if not combat_feedback_label:
		combat_feedback_label = Label.new()
		combat_feedback_label.name = "CombatFeedbackLabel"
		combat_feedback_label.anchors_preset = Control.PRESET_CENTER_TOP
		combat_feedback_label.anchor_left = 0.5
		combat_feedback_label.anchor_right = 0.5
		combat_feedback_label.offset_left = -260
		combat_feedback_label.offset_top = 92
		combat_feedback_label.offset_right = 260
		combat_feedback_label.offset_bottom = 142
		combat_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combat_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		combat_feedback_label.add_theme_font_size_override("font_size", 28)
		combat_feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		combat_feedback_label.add_theme_constant_override("outline_size", 6)
		combat_feedback_label.visible = false
		hud.add_child(combat_feedback_label)
	match_status_hud = hud.get_node_or_null("MatchStatusHUD")
	if not match_status_hud and DisplayServer.get_name() != "headless":
		match_status_hud = preload("res://scripts/match_status_hud.gd").new()
		match_status_hud.name = "MatchStatusHUD"
		hud.add_child(match_status_hud)
	_update_status_hud()


func _ensure_skill_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	skill_hud = hud.get_node_or_null("SkillHUD")
	if not skill_hud:
		skill_hud = preload("res://scripts/skill_hud.gd").new()
		skill_hud.name = "SkillHUD"
		hud.add_child(skill_hud)
	_update_skill_hud()


func _ensure_card_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	card_hud = hud.get_node_or_null("CardHUD")
	if not card_hud:
		card_hud = preload("res://scripts/card_hud.gd").new()
		card_hud.name = "CardHUD"
		hud.add_child(card_hud)
		card_hud.draft_choice_selected.connect(_on_card_hud_draft_choice_selected)
		card_hud.card_slot_used.connect(_on_card_hud_slot_used)
	_update_card_hud()


func _ensure_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	health_hud = hud.get_node_or_null("PlayerHealthHUD")
	if not health_hud:
		health_hud = preload("res://scripts/player_health_hud.gd").new()
		health_hud.name = "PlayerHealthHUD"
		hud.add_child(health_hud)
	_update_health_hud()


func _ensure_world_nameplate_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	world_nameplate_hud = hud.get_node_or_null("WorldNameplateHUD")
	if not world_nameplate_hud:
		world_nameplate_hud = preload("res://scripts/world_nameplate_hud.gd").new()
		world_nameplate_hud.name = "WorldNameplateHUD"
		hud.add_child(world_nameplate_hud)


func _ensure_map_ping_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	map_ping_hud = hud.get_node_or_null("MapPingHUD")
	if not map_ping_hud:
		map_ping_hud = preload("res://scripts/map_ping_hud.gd").new()
		map_ping_hud.name = "MapPingHUD"
		hud.add_child(map_ping_hud)


func _ensure_party_monster_hunt_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	party_monster_hunt_hud = hud.get_node_or_null("PartyMonsterHuntHUD")
	if not party_monster_hunt_hud:
		party_monster_hunt_hud = PartyMonsterHuntHUDScript.new()
		party_monster_hunt_hud.name = "PartyMonsterHuntHUD"
		hud.add_child(party_monster_hunt_hud)
	_update_party_monster_hunt_hud()


func _update_party_monster_hunt_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not party_monster_hunt_hud:
		_ensure_party_monster_hunt_hud()
	if not party_monster_hunt_hud:
		return
	if main_menu and main_menu.is_menu_visible():
		party_monster_hunt_hud.clear()
		return
	var local_id: int = _local_peer_id()
	var local_info: Dictionary = Network.players.get(local_id, {})
	var local_model: String = CharacterSkinCatalog.normalize(str(local_info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	var local_is_party_monster := CharacterSkinCatalog.is_party_monster(local_model)
	var bounty_active := game_state == GameState.PLAY and not party_monster_bounty_accessories.is_empty()
	var should_show := game_state == GameState.PLAY and (bounty_active or local_is_party_monster)
	if not should_show:
		party_monster_hunt_hud.clear()
		return
	var loadout: Dictionary = PartyMonsterAccessoryCatalogScript.sanitize_loadout(local_info.get("party_monster_accessories", {}), local_model)
	var loadout_summary := PartyMonsterAccessoryCatalogScript.loadout_summary(loadout, 4) if local_is_party_monster else ""
	var local_player = _get_local_player()
	var marked := false
	if local_player and local_player.has_method("is_party_monster_bounty_marked"):
		marked = bool(local_player.is_party_monster_bounty_marked())
	var escape_hint := PartyMonsterAccessoryCatalogScript.bounty_escape_hint(loadout, party_monster_bounty_accessories) if marked else ""
	party_monster_hunt_hud.set_hunt_state(
		should_show,
		marked,
		PartyMonsterAccessoryCatalogScript.bounty_label(party_monster_bounty_accessories),
		party_monster_bounty_remaining,
		PARTY_MONSTER_BOUNTY_ACTIVE_SECONDS,
		party_monster_bounty_next_timer,
		party_monster_bounty_marked_count,
		loadout_summary,
		escape_hint
	)


func _ensure_character_setup_overlay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud := get_node_or_null("HUDCanvas") as CanvasLayer
	if not hud:
		return
	for child in hud.get_children():
		if child is CharacterSetupOverlay:
			character_setup_overlay = child as CharacterSetupOverlay
			break
	if not character_setup_overlay:
		character_setup_overlay = CharacterSetupOverlayScript.new() as CharacterSetupOverlay
		character_setup_overlay.name = "CharacterSetupOverlay"
		hud.add_child(character_setup_overlay)


func _show_character_setup_overlay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not character_setup_overlay:
		_ensure_character_setup_overlay()
	if character_setup_overlay:
		character_setup_overlay.show_setup(skin_config_remaining)


func _update_character_setup_ui() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if character_setup_overlay and game_state == GameState.SKIN_CONFIG:
		character_setup_overlay.set_remaining(skin_config_remaining)


func _hide_character_setup_overlay() -> void:
	if character_setup_overlay and is_instance_valid(character_setup_overlay):
		character_setup_overlay.hide_setup()


func _on_player_character_model_changed(peer_id: int, model_id: String) -> void:
	var player_node = players_container.get_node_or_null(str(peer_id)) if players_container else null
	if player_node and player_node.has_method("set_character_model"):
		player_node.set_character_model(model_id)
	if player_node and player_node.has_method("set_party_monster_accessory_loadout") and Network.players.has(peer_id):
		var info: Dictionary = Network.players.get(peer_id, {})
		player_node.set_party_monster_accessory_loadout(info.get("party_monster_accessories", {}))
	_refresh_party_monster_bounty_marks()
	_update_party_monster_hunt_hud()


func _on_player_party_monster_accessories_changed(peer_id: int, loadout: Dictionary) -> void:
	var player_node = players_container.get_node_or_null(str(peer_id)) if players_container else null
	if player_node and player_node.has_method("set_party_monster_accessory_loadout"):
		player_node.set_party_monster_accessory_loadout(loadout)
	_refresh_party_monster_bounty_marks()
	_update_party_monster_hunt_hud()


func _ensure_hider_party_monster_defaults() -> void:
	if not _is_multiplayer_server():
		return
	for pid in Network.players.keys():
		var info: Dictionary = Network.players.get(pid, {})
		var role := int(info.get("role", Network.Role.NONE))
		if role == Network.Role.HUNTER or role == Network.Role.SPECTATOR or role == Network.Role.NONE:
			continue
		var current_model := CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
		if CharacterSkinCatalog.is_party_monster(current_model):
			continue
		if current_model == CharacterSkinCatalog.DEFAULT_ID or current_model == CharacterSkinCatalog.HUNTER_SHOOTER_ID:
			Network.server_set_player_character_model(int(pid), CharacterSkinCatalog.party_monster_default_id())


func _ensure_match_intro_overlay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not has_node("HUDCanvas"):
		return
	var hud = $HUDCanvas
	match_intro_overlay = null
	for child in hud.get_children():
		if child is MatchIntroOverlay and String(child.name) == "MatchIntroOverlay":
			match_intro_overlay = child as MatchIntroOverlay
			break
	if not match_intro_overlay:
		match_intro_overlay = MatchIntroOverlayScript.new() as MatchIntroOverlay
		match_intro_overlay.name = "MatchIntroOverlay"
		hud.add_child(match_intro_overlay)
	if match_intro_overlay:
		if not match_intro_overlay.quit_confirmed.is_connected(_on_quit_confirmed):
			match_intro_overlay.quit_confirmed.connect(_on_quit_confirmed)
		if not match_intro_overlay.quit_cancelled.is_connected(_on_quit_cancelled):
			match_intro_overlay.quit_cancelled.connect(_on_quit_cancelled)
		if not match_intro_overlay.return_lobby_confirmed.is_connected(_on_return_lobby_confirmed):
			match_intro_overlay.return_lobby_confirmed.connect(_on_return_lobby_confirmed)


func _update_match_intro_ui() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not match_intro_overlay:
		_ensure_match_intro_overlay()
	if not match_intro_overlay:
		return
	if game_state != GameState.MATCH_INTRO:
		match_intro_overlay.hide_countdown()
		return
	if not match_intro_overlay.visible:
		match_intro_overlay.show_countdown(match_intro_remaining)
	else:
		match_intro_overlay.set_remaining(match_intro_remaining)


func _hide_match_intro_overlay() -> void:
	if match_intro_overlay and is_instance_valid(match_intro_overlay):
		match_intro_overlay.hide_countdown()


func _show_quit_confirm_prompt() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not match_intro_overlay:
		_ensure_match_intro_overlay()
	if not match_intro_overlay:
		return
	if not _is_quit_confirm_visible():
		_quit_confirm_previous_mouse_mode = Input.mouse_mode
	match_intro_overlay.show_quit_confirm(_is_public_room_client_context())
	_release_game_mouse()


func _hide_quit_confirm_prompt() -> void:
	if match_intro_overlay and is_instance_valid(match_intro_overlay):
		match_intro_overlay.hide_quit_confirm()
	_update_mouse_capture()


func _is_quit_confirm_visible() -> bool:
	return match_intro_overlay != null and is_instance_valid(match_intro_overlay) and match_intro_overlay.is_quit_confirm_visible()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_quit_cancelled() -> void:
	_hide_quit_confirm_prompt()


func _on_return_lobby_confirmed() -> void:
	_hide_quit_confirm_prompt()
	if _is_public_room_client_context():
		_return_to_public_server_lobby("public_lobby.loading", false)


func _set_match_intro_locked(locked: bool) -> void:
	if not players_container:
		return
	for player in players_container.get_children():
		if player.has_method("set_match_intro_locked"):
			player.set_match_intro_locked(locked)


func _set_hud_visible(visible_value: bool) -> void:
	if prep_timer_label:
		prep_timer_label.visible = false
	if status_label:
		status_label.visible = visible_value
	if combat_feedback_label:
		combat_feedback_label.visible = false
	if skill_hud:
		skill_hud.visible = visible_value and not main_menu.is_menu_visible()
	if card_hud:
		card_hud.visible = visible_value and not main_menu.is_menu_visible()
	if health_hud:
		if visible_value and not main_menu.is_menu_visible():
			_update_health_hud()
		else:
			health_hud.visible = false
	if world_nameplate_hud and not (visible_value and not main_menu.is_menu_visible()):
		world_nameplate_hud.clear()
	if match_status_hud:
		match_status_hud.visible = visible_value and (game_state == GameState.PREP or game_state == GameState.PLAY) and not main_menu.is_menu_visible()
	if party_monster_hunt_hud and not visible_value:
		party_monster_hunt_hud.clear()


func _update_status_hud() -> void:
	_update_match_status_hud()
	if not status_label:
		return
	status_label.visible = not (main_menu and main_menu.is_menu_visible())
	if not status_label.visible:
		return
	var role = Network.get_my_role()
	var phase_key = ["LOBBY", "LOADING", "CARD_DRAFT", "SKIN_CONFIG", "MATCH_INTRO", "PREP", "PLAY", "END"][game_state]
	var phase = I18n.t("phase." + phase_key)
	var lines := [
		"%s: %s" % [I18n.t("phase"), phase],
		"%s: %s" % [I18n.t("role"), _localized_role(role)],
		"FPS: %d" % int(round(Engine.get_frames_per_second())),
		"%s: %d | %s: %d | Props: %d" % [I18n.t("players"), Network.players.size(), I18n.t("role.hunter"), Network.get_hunters().size(), Network.get_props().size()],
	]
	if game_state == GameState.SKIN_CONFIG:
		lines.append("SKIN CONFIG: %ds" % int(ceil(skin_config_remaining)))
	elif game_state == GameState.PREP:
		lines.append("%s: %ds" % [I18n.t("prep_remaining"), int(ceil(prep_remaining))])
	elif game_state == GameState.PLAY:
		lines.append("%s: %ds" % [I18n.t("match_remaining"), int(ceil(match_remaining))])
		if not party_monster_bounty_accessories.is_empty():
			lines.append("BOUNTY: %s (%ds) | MARKED: %d" % [PartyMonsterAccessoryCatalogScript.bounty_label(party_monster_bounty_accessories), int(ceil(party_monster_bounty_remaining)), party_monster_bounty_marked_count])
		elif party_monster_bounty_next_timer > 0.0:
			lines.append("NEXT BOUNTY: %ds" % int(ceil(party_monster_bounty_next_timer)))
	lines.append("%s: %.1f m/s²" % [I18n.t("gravity_status"), active_gravity_mps2])
	if gravity_event_remaining > 0.0:
		lines.append("%s: %ds" % [gravity_event_label, int(ceil(gravity_event_remaining))])
	var local_player = _get_local_player()
	if local_player:
		if local_player.has_method("is_party_monster_bounty_marked") and local_player.is_party_monster_bounty_marked():
			lines.append("MARKED: swap a bounty accessory")
		if local_player.has_method("get_health"):
			lines.append("%s: %d" % [I18n.t("health"), int(local_player.get_health())])
		if local_player.has_node("WeaponSystem"):
			var weapon: WeaponSystem = local_player.get_node("WeaponSystem")
			lines.append("%s: %d / %d" % [I18n.t("ammo"), weapon.current_magazine, weapon.total_ammo])
	status_label.text = "\n".join(lines)


func _update_match_status_hud() -> void:
	if not match_status_hud:
		return
	var should_show := not (main_menu and main_menu.is_menu_visible()) and (game_state == GameState.PREP or game_state == GameState.PLAY)
	if not should_show:
		match_status_hud.clear()
		return
	var prop_counts := _alive_counts_for_roles([Network.Role.CHAMELEON, Network.Role.STALKER])
	var hunter_counts := _alive_counts_for_roles([Network.Role.HUNTER])
	var remaining := prep_remaining if game_state == GameState.PREP else match_remaining
	var phase_label := I18n.t("prep_remaining") if game_state == GameState.PREP else I18n.t("match_remaining")
	match_status_hud.set_match_state(
		int(prop_counts.get("alive", 0)),
		int(prop_counts.get("total", 0)),
		int(hunter_counts.get("alive", 0)),
		int(hunter_counts.get("total", 0)),
		remaining,
		phase_label
	)


func _alive_counts_for_roles(roles: Array) -> Dictionary:
	var total := 0
	var alive := 0
	for pid in Network.players.keys():
		var info: Dictionary = Network.players.get(pid, {})
		if not roles.has(int(info.get("role", Network.Role.NONE))):
			continue
		total += 1
		if bool(info.get("alive", true)):
			alive += 1
	return {"total": total, "alive": alive}


func _update_skill_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not skill_hud:
		_ensure_skill_hud()
	if not skill_hud:
		return
	if main_menu and main_menu.is_menu_visible():
		skill_hud.clear_skills()
		return
	if game_state == GameState.LOBBY or game_state == GameState.END:
		skill_hud.clear_skills()
		return
	var local_player = _get_local_player()
	if not local_player:
		skill_hud.clear_skills()
		return
	if local_player.has_method("is_dead") and local_player.is_dead():
		skill_hud.clear_skills()
		if skill_hud.has_method("set_passive_skills"):
			skill_hud.set_passive_skills([])
		return
	skill_hud.set_skills(_skill_hud_entries_for_player(local_player))
	if skill_hud.has_method("set_passive_skills"):
		skill_hud.set_passive_skills(_passive_skill_hud_entries_for_player(local_player))


func _update_card_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not card_hud:
		_ensure_card_hud()
	if not card_hud:
		return
	if game_state == GameState.LOBBY or game_state == GameState.END:
		card_hud.clear_cards()
		return
	var local_player = _get_local_player()
	if local_player and local_player.has_method("is_dead") and local_player.is_dead():
		card_hud.clear_cards()
		return
	card_hud.set_draft_state(Network.get_my_card_draft())
	card_hud.set_loadout(Network.get_my_card_loadout())
	if main_menu and main_menu.is_menu_visible():
		card_hud.visible = false


func _update_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not health_hud:
		_ensure_health_hud()
	if not health_hud:
		return
	# Only show the bar during active combat phases for a living combat role.
	if game_state == GameState.LOBBY or game_state == GameState.END or game_state == GameState.CARD_DRAFT:
		health_hud.clear()
		return
	if main_menu and main_menu.is_menu_visible():
		health_hud.visible = false
		return
	var local_player = _get_local_player()
	if not local_player:
		health_hud.clear()
		return
	if local_player.has_method("is_dead") and local_player.is_dead():
		health_hud.clear()
		return
	var maximum := 0.0
	if local_player.has_method("get_max_health"):
		maximum = local_player.get_max_health()
	var current := 0.0
	if local_player.has_method("get_health"):
		current = local_player.get_health()
	if local_player.has_method("get_display_name"):
		health_hud.set_player_name(local_player.get_display_name())
	health_hud.set_health(current, maximum)


# Builds the per-player snapshot the screen-space nameplate HUD renders each
# frame, then hands it the active camera for projection. Self is excluded (the
# bottom-left bar already shows the local player's own state).
func _update_world_nameplates() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not world_nameplate_hud:
		return
	var hide_all := game_state == GameState.LOBBY or game_state == GameState.END or game_state == GameState.CARD_DRAFT
	if hide_all or (main_menu and main_menu.is_menu_visible()):
		world_nameplate_hud.render([], null)
		return
	var camera := get_viewport().get_camera_3d()
	if not camera or not players_container:
		world_nameplate_hud.render([], null)
		return
	var local_id := _local_peer_id()
	# Hunters get a full-map beacon over every bountied prop.
	var viewer_is_hunter := false
	if players_container.has_node(str(local_id)):
		var local_view := players_container.get_node(str(local_id)) as Character
		if local_view and local_view.has_method("is_hunter"):
			viewer_is_hunter = local_view.is_hunter()
	var entries: Array = []
	for child in players_container.get_children():
		var p := child as Character
		if not p or not is_instance_valid(p):
			continue
		# Hand overhead text ownership to the 2D HUD (hides the world Label3D).
		if p.has_method("set_screen_nameplate_active"):
			p.set_screen_nameplate_active(true)
		var peer := int(str(p.name))
		if p.has_method("is_dead") and p.is_dead():
			continue
		var maximum := p.get_max_health() if p.has_method("get_max_health") else 0.0
		var ratio := (p.get_health() / maximum) if maximum > 0.0 else 0.0
		# Self is included so the local player can see their own bounty / low-health
		# icons above their head in third person (and to make console debugging
		# observable). Self never gets the enemy-damage reveal bar.
		entries.append({
			"peer": peer,
			"pos": p.get_overhead_anchor_position(),
			"name": p.get_display_name(),
			"name_visible": p.nameplate_should_show_for_local_viewer(),
			"is_self": peer == local_id,
			"is_ally": p.is_ally_of_local_viewer(),
			"bountied": p.is_party_monster_bounty_marked() if p.has_method("is_party_monster_bounty_marked") else false,
			"bounty_marker": viewer_is_hunter and peer != local_id and (p.is_party_monster_bounty_marked() if p.has_method("is_party_monster_bounty_marked") else false),
			"ratio": ratio,
		})
	world_nameplate_hud.render(entries, camera)


func _on_card_draft_updated(peer_id: int, _draft_state: Dictionary) -> void:
	if peer_id == _local_peer_id():
		if not _draft_state.is_empty() and not bool(_draft_state.get("complete", false)) and (game_state == GameState.LOBBY or game_state == GameState.LOADING):
			game_state = GameState.CARD_DRAFT
			_hide_loading_overlay()
			if main_menu:
				main_menu.hide_menu()
			_set_hud_visible(true)
		_update_card_hud()
		_update_mouse_capture()


func _on_card_loadout_updated(peer_id: int, _loadout: Array) -> void:
	if peer_id == _local_peer_id():
		_update_card_hud()


func _on_card_drafts_completed() -> void:
	if not _is_multiplayer_server():
		return
	if game_state != GameState.CARD_DRAFT:
		return
	_server_start_skin_config_phase()


func _on_card_activated(peer_id: int, card_id: String, slot_index: int) -> void:
	var player_node = players_container.get_node_or_null(str(peer_id)) if players_container else null
	if player_node and player_node.has_method("apply_card_effect"):
		player_node.apply_card_effect(card_id)
	if peer_id == _local_peer_id():
		show_combat_feedback("CARD %d" % (slot_index + 1), Color(0.62, 0.92, 1.0, 1.0), 0.75)
	_update_card_hud()


func _on_card_hud_draft_choice_selected(card_id: String) -> void:
	Network.request_keep_card(card_id)


func _on_card_hud_slot_used(slot_index: int) -> void:
	Network.request_use_card_slot(slot_index)


func _skill_hud_entries_for_player(local_player: Character) -> Array:
	match local_player.role:
		Network.Role.HUNTER:
			return _hunter_skill_hud_entries(local_player)
		Network.Role.CHAMELEON:
			return _chameleon_skill_hud_entries(local_player)
		Network.Role.STALKER:
			return _stalker_skill_hud_entries(local_player)
		_:
			return _placeholder_skill_hud_entries("ROLE")


func _passive_skill_hud_entries_for_player(local_player: Character) -> Array:
	if local_player.role != Network.Role.HUNTER:
		return []
	var sense_system = local_player.get_node_or_null("HunterPropSenseSystem")
	if not sense_system:
		return []
	var active := false
	var active_remaining := 0.0
	var cooldown_remaining := 0.0
	if sense_system.has_method("is_passive_active"):
		active = bool(sense_system.call("is_passive_active"))
	if sense_system.has_method("get_passive_active_remaining"):
		active_remaining = float(sense_system.call("get_passive_active_remaining"))
	if sense_system.has_method("get_passive_cooldown_remaining"):
		cooldown_remaining = float(sense_system.call("get_passive_cooldown_remaining"))
	return [
		{
			"icon": "detect",
			"active": active,
			"charge_ratio": clampf(active_remaining / 10.0, 0.0, 1.0) if active else (0.0 if cooldown_remaining > 0.0 else 1.0),
			"cooldown_remaining": cooldown_remaining,
			"cooldown_total": 45.0,
			"disabled": cooldown_remaining > 0.0,
		},
	]


func _hunter_skill_hud_entries(local_player: Character) -> Array:
	var flashlight = local_player.get_node_or_null("HunterFlashlightSystem")
	var battery_remaining := 15.0
	var battery_ratio := 1.0
	var cooldown_remaining := 0.0
	var active := false
	if flashlight:
		if flashlight.has_method("get_battery_remaining"):
			battery_remaining = float(flashlight.call("get_battery_remaining"))
		battery_ratio = clampf(battery_remaining / 15.0, 0.0, 1.0)
		if flashlight.has_method("get_cooldown_remaining"):
			cooldown_remaining = float(flashlight.call("get_cooldown_remaining"))
		if flashlight.has_method("is_flashlight_active"):
			active = bool(flashlight.call("is_flashlight_active"))
	return [
		{
			"title": "FLASH",
			"key": "F",
			"icon": "flashlight",
			"active": active,
			"charge_ratio": battery_ratio,
			"cooldown_remaining": cooldown_remaining,
			"cooldown_total": 45.0,
			"disabled": cooldown_remaining > 0.0 or battery_remaining <= 0.0,
		},
		{"title": "SCAN", "key": "2", "icon": "detect", "charge_ratio": 0.0, "disabled": true},
		{"title": "TRAP", "key": "3", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "DASH", "key": "4", "icon": "sprint", "charge_ratio": 0.0, "disabled": true},
	]


func _chameleon_skill_hud_entries(local_player: Character) -> Array:
	var shape_system = local_player.get_node_or_null("ShapeShiftSystem")
	var shape_cooldown := 0.0
	if shape_system and shape_system.has_method("get_cooldown_remaining"):
		shape_cooldown = float(shape_system.call("get_cooldown_remaining"))
	var camo_active := local_player.has_method("is_camouflage_brushing") and local_player.is_camouflage_brushing()
	return [
		{
			"title": "SHIFT",
			"key": "Q",
			"icon": "shape",
			"charge_ratio": 0.0 if shape_cooldown > 0.0 else 1.0,
			"cooldown_remaining": shape_cooldown,
			"cooldown_total": 6.0,
			"disabled": shape_cooldown > 0.0,
		},
		{"title": "CAMO", "key": "C", "icon": "camo", "active": camo_active, "charge_ratio": 1.0},
		{"title": "COPY", "key": "3", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "BLEND", "key": "4", "icon": "stealth", "charge_ratio": 0.0, "disabled": true},
	]


func _stalker_skill_hud_entries(local_player: Character) -> Array:
	var shadow_system = local_player.get_node_or_null("ShadowVisibilitySystem")
	var grapple_system = local_player.get_node_or_null("StalkerGrappleSystem")
	var shadow_alpha := 1.0
	var reveal_lockout := 0.0
	var grapple_cooldown := 0.0
	if local_player.has_method("get_stalker_visibility_alpha"):
		shadow_alpha = float(local_player.call("get_stalker_visibility_alpha"))
	elif shadow_system and shadow_system.has_method("get_visibility_alpha"):
		shadow_alpha = float(shadow_system.call("get_visibility_alpha"))
	if shadow_system and shadow_system.has_method("get_flashlight_reveal_lockout_remaining"):
		reveal_lockout = float(shadow_system.call("get_flashlight_reveal_lockout_remaining"))
	if grapple_system and grapple_system.has_method("get_cooldown_remaining"):
		grapple_cooldown = float(grapple_system.call("get_cooldown_remaining"))
	return [
		{
			"title": "SHADOW",
			"key": "AUTO",
			"icon": "stealth",
			"active": shadow_alpha < 0.99,
			"charge_ratio": 0.0 if reveal_lockout > 0.0 else 1.0,
			"cooldown_remaining": reveal_lockout,
			"cooldown_total": 20.0,
			"disabled": reveal_lockout > 0.0,
		},
		{
			"title": "HOOK",
			"key": "2",
			"icon": "grapple",
			"charge_ratio": 0.0 if grapple_cooldown > 0.0 else 1.0,
			"cooldown_remaining": grapple_cooldown,
			"cooldown_total": 45.0,
			"disabled": grapple_cooldown > 0.0,
		},
		{"title": "DECOY", "key": "3", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "BURST", "key": "4", "icon": "sprint", "charge_ratio": 0.0, "disabled": true},
	]


func _placeholder_skill_hud_entries(label: String) -> Array:
	return [
		{"title": label, "key": "1", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "SKILL", "key": "2", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "SKILL", "key": "3", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
		{"title": "SKILL", "key": "4", "icon": "locked", "charge_ratio": 0.0, "disabled": true},
	]


func show_combat_feedback(text: String, color: Color = Color(1, 0.86, 0.25, 1), duration: float = 0.85) -> void:
	if not combat_feedback_label:
		_ensure_status_hud()
	if not combat_feedback_label:
		return
	combat_feedback_label.text = text
	combat_feedback_label.modulate = color
	combat_feedback_label.visible = true
	var tween := create_tween()
	tween.tween_property(combat_feedback_label, "modulate:a", color.a, 0.01)
	tween.tween_interval(duration)
	tween.tween_property(combat_feedback_label, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func():
		if combat_feedback_label:
			combat_feedback_label.visible = false
			combat_feedback_label.modulate.a = color.a
	)


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


func _should_capture_mouse() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _is_network_console_visible():
		return false
	if _is_pause_menu_visible():
		return false
	if get_tree().get_node_count_in_group("active_radial_wheel") > 0:
		return false
	if _is_quit_confirm_visible():
		return false
	if main_menu and main_menu.is_menu_visible():
		return false
	if multiplayer_chat and multiplayer_chat.is_chat_visible():
		return false
	if inventory_visible:
		return false
	if card_hud and card_hud.has_method("is_drafting_active") and card_hud.is_drafting_active():
		return false
	if card_hud and card_hud.has_method("is_detail_visible") and card_hud.is_detail_visible():
		return false
	var local_player = _get_local_player()
	if local_player and local_player.has_method("is_camouflage_brushing") and local_player.is_camouflage_brushing():
		return false
	return game_state == GameState.PREP or game_state == GameState.PLAY


func _capture_game_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_game_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_mouse_capture() -> void:
	if _should_capture_mouse():
		_capture_game_mouse()
	else:
		_release_game_mouse()


# =============================================================================
# MULTIPLAYER CHAT(淇濈暀鍘熼€昏緫)
# =============================================================================

func toggle_chat():
	if main_menu.is_menu_visible():
		return
	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()
	_update_mouse_capture()


func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()


func _input(event):
	if event is InputEventMouseButton and event.pressed and _should_capture_mouse():
		_capture_game_mouse()
	if event.is_action_pressed("toggle_benchmark_mode"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		_set_benchmark_mode_enabled(not benchmark_mode_enabled)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if _handle_network_console_key(key_event):
			get_viewport().set_input_as_handled()
			return
		if _is_network_console_visible():
			# Console open: let the focused LineEdit consume typing (do NOT mark
			# the event handled, or the GUI text input is swallowed too) while
			# preventing game hotkeys below from firing as you type.
			return
		if key_event.keycode == KEY_ESCAPE and _handle_escape_pressed():
			get_viewport().set_input_as_handled()
			return
		if _handle_card_hotkeys(key_event):
			get_viewport().set_input_as_handled()
			return
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
		# Dev cheat:host 鍗曚汉鏃跺己鍒惰Е鍙?prep phase(鐢ㄤ簬 UI 娴嬭瘯)
		_debug_force_prep_phase()


func _handle_network_console_key(event: InputEventKey) -> bool:
	if _is_network_console_toggle_key(event):
		_set_network_console_visible(not _is_network_console_visible())
		return true
	if not _is_network_console_visible():
		return false
	if event.keycode == KEY_ESCAPE:
		_set_network_console_visible(false)
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_submit_network_console_command()
		return true
	if event.keycode == KEY_UP:
		_console_history_navigate(-1)
		return true
	if event.keycode == KEY_DOWN:
		_console_history_navigate(1)
		return true
	return false


# Recall previously entered commands with Up / Down (CS-style).
func _console_history_navigate(direction: int) -> void:
	if _console_history.is_empty() or not network_console_input:
		return
	_console_history_index = clampi(_console_history_index + direction, 0, _console_history.size())
	if _console_history_index >= _console_history.size():
		network_console_input.text = ""
	else:
		network_console_input.text = _console_history[_console_history_index]
	network_console_input.caret_column = network_console_input.text.length()


func _is_network_console_toggle_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.physical_keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_ASCIITILDE


func _is_network_console_visible() -> bool:
	return network_console_layer != null and is_instance_valid(network_console_layer) and network_console_layer.visible


func _set_network_console_visible(desired_visible: bool) -> void:
	if desired_visible:
		_ensure_network_console_ui()
		_layout_console_drawer()
		_network_console_previous_mouse_mode = Input.mouse_mode
		network_console_layer.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_console_player_locked(true)
		_animate_console_drawer(true)
		if network_console_input:
			network_console_input.grab_focus()
	else:
		_set_console_player_locked(false)
		_animate_console_drawer(false)
		Input.mouse_mode = _network_console_previous_mouse_mode as Input.MouseMode
		_update_mouse_capture()


# Slides the drawer down on open / up on close, hiding the layer when closed.
func _animate_console_drawer(opening: bool) -> void:
	if not network_console_panel or not is_instance_valid(network_console_panel):
		return
	var height := _console_drawer_height
	var from_y := -height if opening else 0.0
	var to_y := 0.0 if opening else -height
	_set_console_drawer_y(from_y)
	var tween := create_tween()
	tween.tween_method(_set_console_drawer_y, from_y, to_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not opening:
		tween.tween_callback(func() -> void:
			if network_console_layer and is_instance_valid(network_console_layer):
				network_console_layer.visible = false)


func _set_console_drawer_y(y: float) -> void:
	if not network_console_panel or not is_instance_valid(network_console_panel):
		return
	network_console_panel.offset_top = y
	network_console_panel.offset_bottom = y + _console_drawer_height


func _layout_console_drawer() -> void:
	if not network_console_panel or not is_instance_valid(network_console_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_console_drawer_width = maxf(360.0, viewport_size.x * 0.35)
	_console_drawer_height = maxf(220.0, viewport_size.y * 0.46)
	network_console_panel.offset_left = 0.0
	network_console_panel.offset_right = _console_drawer_width


# Freeze the local player's movement/camera while typing (reuses the match-intro
# lock so no new input gate is needed). Restores on close.
func _set_console_player_locked(locked: bool) -> void:
	if locked == _console_player_locked:
		return
	_console_player_locked = locked
	# Apply to every local-authority player so control is reliably restored on
	# close (pure input gate, no match-intro side effects).
	if not players_container:
		return
	for child in players_container.get_children():
		if child is Character:
			child.console_input_locked = locked
			# Re-arm input sampling — the input state stops processing while
			# locked and won't resume on its own when the console closes.
			if child.has_method("refresh_input_capture_policy"):
				child.refresh_input_capture_policy()


func _ensure_network_console_ui() -> void:
	if network_console_layer and is_instance_valid(network_console_layer):
		return
	network_console_layer = CanvasLayer.new()
	network_console_layer.name = "NetworkDiagnosticConsoleLayer"
	network_console_layer.layer = 120
	network_console_layer.visible = false
	add_child(network_console_layer)

	# Full-width top drawer (CS-style): dark translucent, slides down from the top.
	network_console_panel = PanelContainer.new()
	network_console_panel.name = "ConsoleDrawer"
	network_console_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	network_console_panel.offset_left = 0.0
	network_console_panel.offset_right = _console_drawer_width
	network_console_panel.offset_top = -_console_drawer_height
	network_console_panel.offset_bottom = 0.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.02, 0.028, 0.94)
	panel_style.border_color = Color(0.40, 0.58, 0.85, 0.85)
	panel_style.border_width_bottom = 3
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	network_console_panel.add_theme_stylebox_override("panel", panel_style)
	network_console_layer.add_child(network_console_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "ConsoleLayout"
	layout.add_theme_constant_override("separation", 6)
	network_console_panel.add_child(layout)

	var title := Label.new()
	title.name = "ConsoleTitle"
	title.text = "MONSTER & HUNTER CONSOLE   ·   ~ toggle   ·   type 'help'"
	title.add_theme_color_override("font_color", Color(0.55, 0.74, 1.0, 0.82))
	layout.add_child(title)

	network_console_output = RichTextLabel.new()
	network_console_output.name = "ConsoleOutput"
	network_console_output.bbcode_enabled = true
	network_console_output.scroll_following = true
	network_console_output.selection_enabled = true
	network_console_output.focus_mode = Control.FOCUS_NONE
	network_console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_console_output.add_theme_color_override("default_color", Color(0.82, 0.86, 0.92, 0.96))
	network_console_output.text = "[color=#7fb0ff]Monster & Hunter console ready.[/color]  type [b]help[/b]"
	layout.add_child(network_console_output)

	network_console_input = LineEdit.new()
	network_console_input.name = "ConsoleInput"
	network_console_input.placeholder_text = "take_damage 0.1   ·   heal   ·   bounty on   ·   players   ·   net.peers"
	network_console_input.caret_blink = true
	network_console_input.text_submitted.connect(_on_network_console_text_submitted)
	layout.add_child(network_console_input)


func _on_network_console_text_submitted(_text: String) -> void:
	_submit_network_console_command()


func _submit_network_console_command() -> void:
	if not network_console_input or not is_instance_valid(network_console_input):
		return
	var command: String = network_console_input.text.strip_edges()
	if command.is_empty():
		return
	if _console_history.is_empty() or _console_history[_console_history.size() - 1] != command:
		_console_history.append(command)
	_console_history_index = _console_history.size()
	_console_print("[color=#9fd0ff]> %s[/color]" % command)
	# Gameplay verbs are handled here (they need Level/player context); anything
	# else falls through to the existing network diagnostics console.
	var gameplay: Dictionary = _run_gameplay_console_command(command)
	if bool(gameplay.get("handled", false)):
		var out: String = String(gameplay.get("output", ""))
		if not out.is_empty():
			_console_print(out)
	else:
		var result: String = NetworkDiagnosticConsoleScript.execute(command)
		if not result.is_empty():
			_console_print(result)
	network_console_input.text = ""
	network_console_input.grab_focus()


# Append a (bbcode) line and keep the view pinned to the newest output.
func _console_print(line: String) -> void:
	if not network_console_output or not is_instance_valid(network_console_output):
		return
	if not network_console_output.text.is_empty():
		network_console_output.append_text("\n")
	network_console_output.append_text(line)
	network_console_output.scroll_to_line(maxi(network_console_output.get_line_count() - 1, 0))


# Returns {handled: bool, output: String}. handled=false means "not a gameplay
# command" so the caller delegates to the network console.
func _run_gameplay_console_command(command: String) -> Dictionary:
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return {"handled": false}
	var cmd: String = String(parts[0]).to_lower()
	match cmd:
		"help":
			return {"handled": true, "output": _gameplay_console_help()}
		"clear", "cls":
			if network_console_output and is_instance_valid(network_console_output):
				network_console_output.text = ""
			return {"handled": true, "output": ""}
		"players", "list":
			return {"handled": true, "output": _gameplay_console_players()}
		"take_damage", "damage", "hurt":
			return {"handled": true, "output": _console_cmd_take_damage(parts)}
		"heal":
			return {"handled": true, "output": _console_cmd_set_hp(parts, 1, 1.0)}
		"sethp", "set_health":
			return {"handled": true, "output": _console_cmd_set_hp(parts, 2, -1.0)}
		"kill":
			return {"handled": true, "output": _console_cmd_fixed_hp(parts, 0.0)}
		"revive":
			return {"handled": true, "output": _console_cmd_fixed_hp(parts, 1.0)}
		"bounty":
			return {"handled": true, "output": _console_cmd_bounty(parts)}
	return {"handled": false}


# token: "" / "self" / "me" -> local player; "all" / "*" -> everyone; else peer id.
func _console_resolve_targets(token: String) -> Array:
	var result: Array = []
	var key := token.strip_edges().to_lower()
	if key == "" or key == "self" or key == "me":
		var lp = _get_local_player()
		if lp:
			result.append(lp)
	elif key == "all" or key == "*":
		if players_container:
			for child in players_container.get_children():
				if child is Character:
					result.append(child)
	elif players_container and players_container.has_node(token):
		var node = players_container.get_node(token)
		if node is Character:
			result.append(node)
	return result


func _console_cmd_take_damage(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "[color=#ffd27f]usage: take_damage <0-1 fraction | amount> [self|all|<peerId>][/color]"
	var value := String(parts[1]).to_float()
	var targets := _console_resolve_targets(String(parts[2]) if parts.size() > 2 else "self")
	if targets.is_empty():
		return "[color=#ff8080]no matching target[/color]"
	var lines: Array[String] = []
	for t in targets:
		var character := t as Character
		if not character:
			continue
		var max_hp: float = character.get_max_health() if character.has_method("get_max_health") else 100.0
		var amount: float = value if value > 1.0 else value * max_hp
		if amount <= 0.0:
			continue
		character.take_damage.rpc_id(1, amount, 0)
		lines.append("  %s  [color=#ff9a9a]-%.0f HP[/color]" % [character.get_display_name(), amount])
	return "\n".join(lines) if not lines.is_empty() else "[color=#ffd27f]nothing applied[/color]"


# value_index: where the fraction arg is (heal: none -> default; sethp: parts[1]).
func _console_cmd_set_hp(parts: PackedStringArray, target_index: int, default_fraction: float) -> String:
	var fraction := default_fraction
	if default_fraction < 0.0:
		if parts.size() < 2:
			return "[color=#ffd27f]usage: sethp <0-1> [self|all|<peerId>][/color]"
		fraction = clampf(String(parts[1]).to_float(), 0.0, 1.0)
	var targets := _console_resolve_targets(String(parts[target_index]) if parts.size() > target_index else "self")
	return _apply_health_fraction(targets, fraction)


func _console_cmd_fixed_hp(parts: PackedStringArray, fraction: float) -> String:
	var targets := _console_resolve_targets(String(parts[1]) if parts.size() > 1 else "self")
	return _apply_health_fraction(targets, fraction)


func _apply_health_fraction(targets: Array, fraction: float) -> String:
	if targets.is_empty():
		return "[color=#ff8080]no matching target[/color]"
	var lines: Array[String] = []
	for t in targets:
		var character := t as Character
		if not character or not character.has_method("debug_set_health_fraction"):
			continue
		character.debug_set_health_fraction.rpc(fraction)
		lines.append("  %s  HP -> %d%%" % [character.get_display_name(), int(round(fraction * 100.0))])
	return "\n".join(lines) if not lines.is_empty() else "[color=#ffd27f]nothing applied (debug build only)[/color]"


func _console_cmd_bounty(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "[color=#ffd27f]usage: bounty <on|off> [self|all|<peerId>][/color]"
	var on := String(parts[1]).to_lower() in ["on", "1", "true", "yes"]
	var targets := _console_resolve_targets(String(parts[2]) if parts.size() > 2 else "self")
	if targets.is_empty():
		return "[color=#ff8080]no matching target[/color]"
	var lines: Array[String] = []
	for t in targets:
		var character := t as Character
		if not character or not character.has_method("debug_set_bounty"):
			continue
		character.debug_set_bounty.rpc(on)
		lines.append("  %s  bounty %s" % [character.get_display_name(), "ON" if on else "off"])
	return "\n".join(lines) if not lines.is_empty() else "[color=#ffd27f]nothing applied (debug build only)[/color]"


func _gameplay_console_players() -> String:
	if not players_container:
		return "[color=#ffd27f]no players[/color]"
	var lines: Array[String] = ["[b]peer        name              role        hp[/b]"]
	for child in players_container.get_children():
		var character := child as Character
		if not character:
			continue
		var role_text := Network.role_to_string(character.role) if Network.has_method("role_to_string") else str(character.role)
		var hp := int(round(character.get_health())) if character.has_method("get_health") else 0
		var max_hp := int(round(character.get_max_health())) if character.has_method("get_max_health") else 0
		lines.append("%-10s  %-16s  %-9s  %d/%d" % [str(character.name), character.get_display_name(), role_text, hp, max_hp])
	return "\n".join(lines)


func _gameplay_console_help() -> String:
	return "\n".join([
		"[b][color=#9fd0ff]Gameplay[/color][/b]",
		"  take_damage <0-1|amt> [self|all|id]   deal damage (0.1 = 10% of max)",
		"  heal [target]                         restore to full",
		"  sethp <0-1> [target]                  set HP to a fraction",
		"  kill [target]   ·   revive [target]",
		"  bounty <on|off> [target]              toggle bounty marker",
		"  players   ·   clear",
		"[b][color=#9fd0ff]Network[/color][/b]  net.mode · net.peers · net.rtt · net.room · net.noray",
		"[color=#8a96a8]target defaults to self; use a peer id (see 'players') or 'all'[/color]",
	])


func _handle_escape_pressed() -> bool:
	if _is_pause_menu_visible():
		_close_pause_menu()
		return true
	if _is_quit_confirm_visible():
		_hide_quit_confirm_prompt()
		return true
	if main_menu and main_menu.is_menu_visible() and (main_menu.settings_visible or main_menu.lobby_chat_visible):
		return false
	if multiplayer_chat and multiplayer_chat.is_chat_visible():
		return false
	if inventory_visible:
		return false
	if card_hud and card_hud.has_method("is_drafting_active") and card_hud.is_drafting_active():
		return false
	if card_hud and card_hud.has_method("is_detail_visible") and card_hud.is_detail_visible():
		return false
	# Plain main menu (lobby / landing) handles its own ESC.
	if main_menu and main_menu.is_menu_visible():
		return false
	_open_pause_menu()
	return true


# =============================================================================
# IN-GAME PAUSE MENU (ESC) — reusable vertical-button panel
# =============================================================================

func _ensure_pause_menu() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if game_pause_menu and is_instance_valid(game_pause_menu):
		return
	game_pause_menu = preload("res://scripts/game_pause_menu.gd").new()
	game_pause_menu.name = "GamePauseMenu"
	add_child(game_pause_menu)
	game_pause_menu.configure("PAUSED  ·  暂停", [
		{"id": "settings", "label": "设置  ·  SETTINGS"},
		{"id": "lobby", "label": "返回大厅  ·  RETURN TO LOBBY"},
		{"id": "quit", "label": "退出游戏  ·  QUIT GAME"},
	])
	game_pause_menu.option_selected.connect(_on_pause_option_selected)
	if main_menu and not main_menu.in_game_settings_closed.is_connected(_on_in_game_settings_closed):
		main_menu.in_game_settings_closed.connect(_on_in_game_settings_closed)


func _is_pause_menu_visible() -> bool:
	return game_pause_menu != null and is_instance_valid(game_pause_menu) and game_pause_menu.visible


func _open_pause_menu() -> void:
	if game_state != GameState.PREP and game_state != GameState.PLAY:
		return
	_ensure_pause_menu()
	if not game_pause_menu:
		return
	_pause_menu_active = true
	game_pause_menu.open()
	_set_console_player_locked(true)   # reuse the player input lock (mutually exclusive with the console)
	_update_mouse_capture()


func _close_pause_menu() -> void:
	_pause_menu_active = false
	if game_pause_menu and is_instance_valid(game_pause_menu):
		game_pause_menu.close()
	_set_console_player_locked(false)
	_update_mouse_capture()


func _on_pause_option_selected(option_id: String) -> void:
	match option_id:
		"settings":
			# Stay paused/locked; swap the pause panel for the settings overlay.
			if game_pause_menu and is_instance_valid(game_pause_menu):
				game_pause_menu.close()
			if main_menu:
				main_menu.open_in_game_settings()
			_update_mouse_capture()
		"lobby":
			_close_pause_menu()
			_pause_return_to_lobby()
		"quit":
			_close_pause_menu()
			_show_quit_confirm_prompt()


func _on_in_game_settings_closed() -> void:
	# Settings closed from the pause overlay -> return to the pause panel.
	if _pause_menu_active and game_pause_menu and is_instance_valid(game_pause_menu):
		game_pause_menu.open()
	_update_mouse_capture()


func _pause_return_to_lobby() -> void:
	if _is_public_room_client_context():
		_return_to_public_server_lobby("public_lobby.loading", false)
	else:
		Network.leave_current_lobby()
		get_tree().reload_current_scene()


func _handle_card_hotkeys(event: InputEventKey) -> bool:
	if not card_hud:
		return false
	if event.keycode == KEY_H and card_hud.has_method("toggle_detail_panel"):
		return card_hud.toggle_detail_panel()
	if card_hud.has_method("is_drafting_active") and card_hud.is_drafting_active():
		match event.keycode:
			KEY_1:
				return card_hud.choose_by_index(0)
			KEY_2:
				return card_hud.choose_by_index(1)
			KEY_3:
				return card_hud.choose_by_index(2)
		return false
	if main_menu and main_menu.is_menu_visible():
		return false
	if game_state != GameState.PREP and game_state != GameState.PLAY:
		return false
	var local_player = _get_local_player()
	if local_player and local_player.has_method("is_dead") and local_player.is_dead():
		return false
	match event.keycode:
		KEY_E:
			return card_hud.use_slot(0)
		KEY_R:
			return card_hud.use_slot(1)
	return false


func _on_chat_message_sent(message_text: String) -> void:
	_send_chat_message(message_text)


func _on_lobby_chat_message_sent(message_text: String) -> void:
	_send_chat_message(message_text)


func _send_chat_message(message_text: String) -> void:
	var trimmed_message = message_text.strip_edges()
	if trimmed_message == "":
		return
	var local_id := _local_peer_id()
	var nick = Network.players.get(local_id, {}).get("nick", "Player")
	rpc("msg_rpc", nick, trimmed_message)


@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	multiplayer_chat.add_message(nick, msg)
	if main_menu:
		main_menu.add_lobby_chat_message(str(nick), str(msg))


# =============================================================================
# INVENTORY(淇濈暀鍘熼€昏緫)
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
	_update_mouse_capture()


func is_inventory_visible() -> bool:
	return inventory_visible


func _notification(what):
	if what == NOTIFICATION_READY:
		_runtime_debug_log("=== Prop Hunt v0.3.3 ===")
		_runtime_debug_log("Controls:")
		_runtime_debug_log("  WASD - Move | Shift - Sprint | Space - Jump")
		_runtime_debug_log("  T - Toggle Chat | B - Toggle Inventory")
		_runtime_debug_log("  F1 - Add random test item (debug)")
		_runtime_debug_log("  F2 - Print inventory contents (debug)")
		_runtime_debug_log("Match: ", Network.lobby_config.get("match_duration_sec", 600) / 60, " min")
		_runtime_debug_log("Prep: ", Network.lobby_config.get("prep_duration_sec", 30), " s")
		_runtime_debug_log("Ratio: 1 Hunter : 3 Props")


func _on_inventory_closed():
	inventory_visible = false
	_update_mouse_capture()


func update_local_inventory_display():
	if inventory_ui:
		inventory_ui.refresh_display()


func _get_local_player() -> Character:
	var local_player_id = _local_peer_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id)) as Character
	return null


func _debug_add_item():
	var local_player = _get_local_player()
	if local_player:
		var test_items = ["iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"]
		var random_item = test_items[randi() % test_items.size()]
		_runtime_debug_log("Debug: Requesting to add ", random_item, " to player ", local_player.name)
		local_player.request_add_item.rpc_id(1, random_item, 1)
	else:
		_runtime_debug_log("Debug: No local player found!")


func _debug_print_inventory():
	var local_player = _get_local_player()
	if local_player and local_player.get_inventory():
		var inventory = local_player.get_inventory()
		_runtime_debug_log("=== Inventory Debug ===")
		for i in range(inventory.slots.size()):
			var slot = inventory.get_slot(i)
			if slot and not slot.is_empty():
				_runtime_debug_log("Slot ", i, ": ", slot.item_id, " x", slot.quantity)
		_runtime_debug_log("=====================")
	else:
		_runtime_debug_log("No inventory found for local player")


# Dev cheat:host 鍗曚汉鏃跺己鍒惰Е鍙?prep phase
func _debug_force_prep_phase() -> void:
	if not _is_multiplayer_server():
		_runtime_debug_log("[Debug] Only server can force prep phase")
		return
	if game_state != GameState.LOBBY:
		_runtime_debug_log("[Debug] Already in progress (game_state=", game_state, ")")
		return
	if Network.players.size() < 1:
		_runtime_debug_log("[Debug] No players yet")
		return
	_runtime_debug_log("[Debug] F5: Force start prep phase (skip 2-player check)")
	Network.server_auto_balance_roles(true)
	_server_start_card_draft_phase()
