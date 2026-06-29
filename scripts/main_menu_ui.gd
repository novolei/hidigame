extends Control
class_name MainMenuUI

signal host_pressed(nickname: String, skin: String, role: int, room_name: String, lobby_password: String, character_model: String)
signal join_pressed(nickname: String, skin: String, address: String, lobby_id: String, role: int, room_name: String, character_model: String)
signal public_server_pressed(nickname: String, skin: String, role: int, character_model: String)
signal public_room_create_pressed(room_name: String, lobby_password: String)
signal public_room_join_pressed(room_id: String, lobby_password: String)
signal public_lobby_refresh_pressed()
signal public_lobby_leave_pressed()
signal lobby_back_pressed()
signal lobby_leave_pressed()
signal quit_pressed
signal start_match_pressed(config: Dictionary)
signal auto_assign_pressed(config: Dictionary)
signal config_changed(config: Dictionary)
signal lobby_chat_message_sent(message_text: String)

const TEAM_UNASSIGNED := -1
const TEAM_SPECTATOR := 3
const PUBLIC_IP_ENDPOINTS := [
	"https://api.ipify.org",
	"https://icanhazip.com",
	"http://api.ipify.org",
]
const PUBLIC_IP_LOOKUP_TIMEOUT_SEC := 4.0
const PUBLIC_SERVER_TARGET := "%s:%d" % [Network.PUBLIC_SERVER_ADDRESS, Network.SERVER_PORT]
const PUBLIC_ROOM_LOCK_ICON := "res://addons/at-icons/control/lock.svg"
const SETTINGS_BACKGROUND_PATH := "res://assets/ui/settings_background.png"
const UI_CLICK_SOUND_PATH := "res://assets/audio/ui/ui_button_click.mp3"
const UI_SELECT_SOUND_PATH := "res://assets/audio/ui/ui_select_click.mp3"
const UI_SELECT_CLICK_META := "_ui_select_click"
const HotUpdateStoreScript := preload("res://scripts/hot_update/hot_update_store.gd")
const STARTUP_WORDMARK_FONT_PATH := "res://assets/fonts/startup/SairaStencil-ExtraBoldItalic.ttf"
const STARTUP_WORDMARK_GLYPH_SPACING := -3
const STARTUP_WORDMARK_SPACE_SPACING := -10
const SETTINGS_TAB_GENERAL := "general"
const SETTINGS_TAB_VIDEO := "video"
const SETTINGS_TAB_RENDER := "render"
const SETTINGS_TAB_GAMEPLAY := "gameplay"
const SETTINGS_TABS := [
	{"id": SETTINGS_TAB_GENERAL, "label": "GENERAL"},
	{"id": SETTINGS_TAB_VIDEO, "label": "VIDEO"},
	{"id": SETTINGS_TAB_RENDER, "label": "RENDER"},
	{"id": SETTINGS_TAB_GAMEPLAY, "label": "GAMEPLAY"},
]

var selected_role: int = Network.Role.CHAMELEON
var lobby_visible := false
var current_lobby_id := "----"
var is_host_lobby := false
var lobby_chat_visible := false
var lobby_chat_fading := false
var _lobby_chat_fade_token := 0
var settings_visible := false
var _in_game_settings := false   # settings opened as a standalone in-game overlay (pause menu)
var settings_active_tab := SETTINGS_TAB_GENERAL
var public_lobby_visible := false
var landing_action_panel_mode := ""
var public_lobby_rooms: Array = []
var selected_public_room_id := ""
var public_lobby_status_text := ""
var public_lobby_status_error := false
var public_lobby_loading_text := ""
var public_lobby_alert_text := ""
var public_lobby_alert_error := false
var _public_lobby_alert_token := 0
var public_room_create_name_text := ""
var public_room_create_password_text := ""
var public_room_join_password_text := ""
var lobby_chat_messages: Array[Dictionary] = []

var nick_input: LineEdit
var skin_input: LineEdit
var character_option: OptionButton

# Player-name profile panel (define on first run / change anytime via the chip).
var _name_panel_open := false
var _name_panel_prompted := false
var _name_panel_input: LineEdit = null
var room_name_input: LineEdit
var address_input: LineEdit
var join_lobby_input: LineEdit
var join_status_label: Label
var steam_status_label: Label
var public_server_button: Button
var public_lobby_status_label: Label
var public_room_create_name_input: LineEdit
var public_room_create_password_input: LineEdit
var public_room_join_password_input: LineEdit
var public_room_join_button: Button
var public_room_list_box: VBoxContainer
var host_button: Button
var join_button: Button
var language_option: OptionButton
var settings_panel: PanelContainer
var fov_slider: HSlider
var fov_value_label: Label
var landing_role_buttons: Array[Button] = []

var lobby_id_input: LineEdit
var public_address_input: LineEdit
var public_address_copy_button: Button
var players_hint_label: Label
var map_option: OptionButton
var variant_option: OptionButton
var condition_option: OptionButton
var game_show_option: OptionButton
var gravity_option: OptionButton
var duration_option: OptionButton
var prep_option: OptionButton
var hunter_count_option: OptionButton
var stalker_glass_option: OptionButton
var stalker_glass_material_option: OptionButton
var auto_turret_enabled_option: OptionButton
var auto_turret_range_option: OptionButton
var start_button: Button
var auto_assign_button: Button
var chat_panel: PanelContainer
var chat_log_box: VBoxContainer
var chat_input: LineEdit
var lobby_role_buttons: Array[Button] = []
var user_rows: Dictionary = {}
var team_lists: Dictionary = {}

var _styles := {}
var _font_heading: Font
var _font_body: Font
var _font_button: Font
var _font_menu: Font
var _font_wordmark: Font
var _icon_cache: Dictionary = {}
var _layout_bucket := Vector2i.ZERO
var _public_ip_request: HTTPRequest
var _public_ip_address := ""
var _public_ip_lookup_pending := false
var _public_ip_lookup_failed := false
var _public_ip_endpoint_index := 0
var _ui_click_player: AudioStreamPlayer
var _ui_select_player: AudioStreamPlayer


func _ready() -> void:
	_fit_to_viewport()
	_ensure_public_ip_request()
	_ensure_ui_click_player()
	_ensure_ui_select_player()
	_load_fonts()
	_build_styles()
	I18n.locale_changed.connect(_on_locale_changed)
	SteamBridge.availability_changed.connect(_on_steam_availability_changed)
	_select_role(Network.Role.CHAMELEON)
	show_landing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()
		var viewport_size := get_viewport_rect().size
		var bucket := Vector2i(roundi(viewport_size.x / 80.0), roundi(viewport_size.y / 60.0))
		if bucket != _layout_bucket:
			_layout_bucket = bucket
			call_deferred("_rebuild_after_resize")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and settings_visible:
			_set_settings_visible(false)
			accept_event()
			return
	if not lobby_visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if lobby_chat_visible and chat_panel and not chat_panel.get_global_rect().has_point(event.position):
			_set_lobby_chat_visible(false, true)
			accept_event()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and lobby_chat_visible:
			_on_lobby_back_pressed()
		elif event.keycode == KEY_T:
			_set_lobby_chat_visible(not lobby_chat_visible)
			accept_event()
		elif event.keycode == KEY_ESCAPE:
			_on_lobby_back_pressed()
		elif event.keycode == KEY_X:
			_on_lobby_leave_pressed()
		elif event.keycode == KEY_ENTER:
			if lobby_chat_visible and chat_input and chat_input.has_focus():
				_send_lobby_chat_message()
				accept_event()


func _fit_to_viewport() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	global_position = Vector2.ZERO
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0


func _rebuild_after_resize() -> void:
	if not is_inside_tree():
		return
	_icon_cache.clear()
	_build_styles()
	_build_ui()
	if public_lobby_visible:
		update_public_lobby(public_lobby_rooms)
	elif lobby_visible:
		update_lobby(Network.players, Network.lobby_config)


func _ui_scale() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var viewport_scale: float = minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	return clampf(viewport_scale, 0.78, 1.35)


func _s(value: float) -> int:
	return max(1, roundi(value * _ui_scale()))


func _sv(x: float, y: float) -> Vector2:
	return Vector2(_s(x), _s(y))


func _ensure_public_ip_request() -> void:
	if _public_ip_request and is_instance_valid(_public_ip_request):
		return
	_public_ip_request = HTTPRequest.new()
	_public_ip_request.name = "PublicIPRequest"
	_public_ip_request.timeout = PUBLIC_IP_LOOKUP_TIMEOUT_SEC
	_public_ip_request.body_size_limit = 256
	_public_ip_request.use_threads = true
	_public_ip_request.request_completed.connect(_on_public_ip_request_completed)
	add_child(_public_ip_request)


func _start_public_ip_lookup(force: bool = false) -> void:
	if _public_ip_lookup_pending:
		return
	if not force and not _public_ip_address.is_empty():
		_refresh_public_host_address_controls()
		return
	_ensure_public_ip_request()
	_public_ip_endpoint_index = 0
	_public_ip_lookup_failed = false
	_public_ip_lookup_pending = true
	_request_next_public_ip_endpoint()


func _cancel_public_ip_lookup(reset_address: bool = false) -> void:
	if _public_ip_request and is_instance_valid(_public_ip_request) and _public_ip_lookup_pending:
		_public_ip_request.cancel_request()
	_public_ip_lookup_pending = false
	_public_ip_endpoint_index = 0
	if reset_address:
		_public_ip_address = ""
		_public_ip_lookup_failed = false
	_refresh_public_host_address_controls()


func _request_next_public_ip_endpoint() -> void:
	if not _public_ip_request or not is_instance_valid(_public_ip_request):
		_public_ip_lookup_pending = false
		_public_ip_lookup_failed = true
		_refresh_public_host_address_controls()
		return
	while _public_ip_endpoint_index < PUBLIC_IP_ENDPOINTS.size():
		var endpoint: String = str(PUBLIC_IP_ENDPOINTS[_public_ip_endpoint_index])
		var error: int = _public_ip_request.request(endpoint)
		if error == OK:
			_refresh_public_host_address_controls()
			return
		_public_ip_endpoint_index += 1
	_public_ip_lookup_pending = false
	_public_ip_lookup_failed = true
	_refresh_public_host_address_controls()


func _on_public_ip_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _public_ip_lookup_pending:
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var address: String = body.get_string_from_utf8().strip_edges()
		if _looks_like_public_ip(address):
			_public_ip_address = address
			_public_ip_lookup_pending = false
			_public_ip_lookup_failed = false
			_refresh_public_host_address_controls()
			return
	_public_ip_endpoint_index += 1
	_request_next_public_ip_endpoint()


func _public_connection_target() -> String:
	if _public_ip_address.is_empty():
		return ""
	var port: int = int(Network.lobby_config.get("host_port", Network.server_port))
	if _public_ip_address.contains(":") and not _public_ip_address.begins_with("["):
		return "[%s]:%d" % [_public_ip_address, port]
	return "%s:%d" % [_public_ip_address, port]


func _public_host_target_text() -> String:
	var target: String = _public_connection_target()
	if not target.is_empty():
		return target
	if _public_ip_lookup_failed:
		return I18n.t("public_host_address_unavailable")
	return I18n.t("public_host_address_pending")


func _refresh_public_host_address_controls() -> void:
	if public_address_input and is_instance_valid(public_address_input):
		public_address_input.text = _public_host_target_text()
	if public_address_copy_button and is_instance_valid(public_address_copy_button):
		public_address_copy_button.disabled = _public_connection_target().is_empty()


func _looks_like_public_ip(value: String) -> bool:
	var target := value.strip_edges()
	if target.is_empty():
		return false
	if target.contains(" ") or target.contains("/") or target.contains("<"):
		return false
	if target == "localhost" or target == "127.0.0.1" or target == "::1":
		return false
	return target.contains(".") or target.contains(":")


func _responsive_width(ratio: float, min_width: float, max_width: float) -> int:
	var viewport_width := get_viewport_rect().size.x
	return clampi(roundi(viewport_width * ratio), _s(min_width), _s(max_width))


func show_menu() -> void:
	show()


func hide_menu() -> void:
	hide()


func is_menu_visible() -> bool:
	return visible


signal in_game_settings_closed


# Show ONLY the settings panel as an in-game overlay (no landing/lobby behind it),
# so players can change config mid-match via the pause menu. Closing it (back
# button or ESC) routes through _set_settings_visible(false) -> close_in_game_settings.
func open_in_game_settings() -> void:
	_in_game_settings = true
	settings_visible = true
	show()
	_build_ui()


func close_in_game_settings() -> void:
	if not _in_game_settings:
		return
	_in_game_settings = false
	settings_visible = false
	hide()
	in_game_settings_closed.emit()


func show_landing() -> void:
	lobby_visible = false
	public_lobby_visible = false
	landing_action_panel_mode = ""
	selected_public_room_id = ""
	public_lobby_status_text = ""
	public_lobby_loading_text = ""
	public_lobby_alert_text = ""
	_cancel_public_ip_lookup()
	_build_ui()


func show_lobby(lobby_id: String, host_mode: bool) -> void:
	lobby_visible = true
	public_lobby_visible = false
	selected_public_room_id = ""
	public_lobby_loading_text = ""
	public_lobby_alert_text = ""
	current_lobby_id = lobby_id
	is_host_lobby = host_mode
	var private_connection_mode: String = str(Network.lobby_config.get("private_connection_mode", "direct"))
	if is_host_lobby and not private_connection_mode.begins_with("noray"):
		_start_public_ip_lookup()
	else:
		_cancel_public_ip_lookup()
	_build_ui()
	update_lobby(Network.players, Network.lobby_config)


func show_public_lobby(rooms: Array = [], status_text: String = "") -> void:
	lobby_visible = false
	public_lobby_visible = true
	public_lobby_rooms = rooms.duplicate(true)
	if not status_text.is_empty():
		public_lobby_status_text = status_text
		public_lobby_status_error = false
	_cancel_public_ip_lookup()
	_build_ui()


func update_public_lobby(rooms: Array) -> void:
	if not public_lobby_visible:
		return
	public_lobby_rooms = rooms.duplicate(true)
	if not _public_room_exists(selected_public_room_id):
		selected_public_room_id = ""
	_build_ui()


func show_public_lobby_status(text: String, is_error: bool = false) -> void:
	public_lobby_status_text = text
	public_lobby_status_error = is_error
	if is_error:
		public_lobby_loading_text = ""
	if public_lobby_status_label:
		public_lobby_status_label.text = text
		public_lobby_status_label.visible = not text.is_empty()
		public_lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.590, 0.220, 1) if is_error else Color(0.760, 0.850, 1.0, 1))


func show_public_lobby_loading(text: String) -> void:
	public_lobby_loading_text = text
	if public_lobby_visible:
		_build_ui()


func hide_public_lobby_loading() -> void:
	if public_lobby_loading_text.is_empty():
		return
	public_lobby_loading_text = ""
	if public_lobby_visible:
		_build_ui()


func _public_lobby_is_busy() -> bool:
	return public_lobby_visible and not public_lobby_loading_text.is_empty()


func show_public_lobby_alert(text: String, is_error: bool = true, duration_sec: float = 2.4) -> void:
	public_lobby_alert_text = text
	public_lobby_alert_error = is_error
	_public_lobby_alert_token += 1
	var alert_token := _public_lobby_alert_token
	if public_lobby_visible:
		_build_ui()
	var timer := get_tree().create_timer(maxf(0.1, duration_sec))
	timer.timeout.connect(func():
		if _public_lobby_alert_token != alert_token:
			return
		public_lobby_alert_text = ""
		if public_lobby_visible:
			_build_ui()
	)


func is_public_lobby_visible() -> bool:
	return public_lobby_visible


func _public_room_exists(room_id: String) -> bool:
	if room_id.strip_edges().is_empty():
		return false
	for raw_room in public_lobby_rooms:
		var room: Dictionary = raw_room
		if str(room.get("room_id", "")) == room_id:
			return true
	return false


func _selected_public_room() -> Dictionary:
	for raw_room in public_lobby_rooms:
		var room: Dictionary = raw_room
		if str(room.get("room_id", "")) == selected_public_room_id:
			return room
	return {}


func _public_room_server_info_text(config: Dictionary) -> String:
	if not bool(config.get("public_server", false)) or bool(config.get("public_lobby", false)):
		return ""
	var address: String = str(config.get("public_address", "")).strip_edges()
	if address.is_empty():
		address = Network.PUBLIC_SERVER_ADDRESS
	var port: int = int(config.get("host_port", Network.server_port))
	var server_code: String = str(config.get("public_server_code", "")).strip_edges()
	if server_code.is_empty():
		server_code = Network.public_server_code_for_address(address)
	return I18n.tf("public_lobby.connected_server", [server_code, address, port])


func update_lobby(players: Dictionary, config: Dictionary) -> void:
	if not lobby_visible:
		return
	current_lobby_id = str(config.get("lobby_id", current_lobby_id))
	if lobby_id_input:
		lobby_id_input.text = current_lobby_id
	_update_config_controls(config)
	_update_player_lists(players)
	_update_start_button(players)


func get_selected_role() -> int:
	return selected_role


func get_host_config() -> Dictionary:
	return _collect_lobby_config()


func get_nickname() -> String:
	var typed := nick_input.text.strip_edges() if nick_input else ""
	return typed if not typed.is_empty() else GameSettings.get_player_name()


func get_skin() -> String:
	return skin_input.text.strip_edges().to_lower() if skin_input else ""


func get_character_model() -> String:
	if character_option and character_option.selected >= 0:
		return CharacterSkinCatalog.normalize(str(character_option.get_item_metadata(character_option.selected)))
	return CharacterSkinCatalog.DEFAULT_ID


func get_room_name() -> String:
	return room_name_input.text.strip_edges() if room_name_input else ""


func get_address() -> String:
	var target := get_join_target()
	return target if _looks_like_network_address(target) else Network.SERVER_ADDRESS


func get_join_target() -> String:
	return address_input.text.strip_edges() if address_input else ""


func get_join_room_name() -> String:
	var target := get_join_target()
	return "" if _looks_like_network_address(target) else target


func get_lobby_password() -> String:
	return join_lobby_input.text.strip_edges().to_upper() if join_lobby_input else ""


func get_connection_summary() -> Dictionary:
	var target := get_join_target()
	return {
		"target": target,
		"address": get_address(),
		"room_name": get_join_room_name(),
		"lobby_id": get_lobby_password(),
		"uses_room_lookup": not _looks_like_network_address(target),
	}


func _load_fonts() -> void:
	_font_heading = _load_font("res://assets/fonts/Saira-9.woff2")
	_font_body = _load_font("res://assets/fonts/SairaCondensed-Medium.woff2")
	_font_button = _load_font("res://assets/fonts/SairaCondensed-Bold.woff2")
	_font_menu = _load_font("res://assets/fonts/SairaExtraCondensed-Bold.woff2")
	_font_wordmark = _load_startup_wordmark_font()


func _load_font(path: String) -> Font:
	var resource = load(path)
	return resource if resource is Font else null


func _load_startup_wordmark_font() -> Font:
	var resource := _load_font(STARTUP_WORDMARK_FONT_PATH)
	if resource == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = resource
	var text_server := TextServerManager.get_primary_interface()
	if text_server != null:
		variation.variation_opentype = { text_server.name_to_tag("wght"): 800 }
	variation.set_spacing(TextServer.SPACING_GLYPH, STARTUP_WORDMARK_GLYPH_SPACING)
	variation.set_spacing(TextServer.SPACING_SPACE, STARTUP_WORDMARK_SPACE_SPACING)
	return variation


func _display_version() -> String:
	var manifest_version := _current_manifest_version()
	if not manifest_version.is_empty():
		return manifest_version
	return _app_version()


func _current_manifest_version() -> String:
	var tree := get_tree()
	if tree != null:
		var manager: Node = tree.root.get_node_or_null("HotUpdate")
		if manager != null:
			var remote_value: Variant = manager.get("remote_manifest")
			if remote_value is Dictionary:
				var remote_manifest: Dictionary = remote_value as Dictionary
				var remote_version := _manifest_version_from_dict(remote_manifest)
				if not remote_version.is_empty():
					return remote_version
	var installed_manifest: Dictionary = HotUpdateStoreScript.load_installed_manifest()
	return _manifest_version_from_dict(installed_manifest)


func _manifest_version_from_dict(manifest: Dictionary) -> String:
	# Prefer content_version (carries version + date + commit) over the bare version.
	var content_version := str(manifest.get("content_version", "")).strip_edges()
	if not content_version.is_empty():
		return content_version
	return str(manifest.get("version", "")).strip_edges()


func _app_version() -> String:
	# build_info.json ships in the core_patch hot-update pack, so this reflects the
	# applied update + restart instead of the frozen bootstrap config/version.
	var stamped := BuildInfo.content_version().strip_edges()
	if not stamped.is_empty() and stamped != "0.0.0":
		return stamped
	var value := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return value if not value.is_empty() else "dev"


func _use_brand_font() -> bool:
	return I18n.current_locale != "zh"


func _build_styles() -> void:
	_styles.clear()
	_styles["panel"] = _style(Color(0.205, 0.222, 0.270, 0.96), Color(0.205, 0.222, 0.270, 0.96), 1, 8)
	_styles["panel_dark"] = _style(Color(0.090, 0.080, 0.100, 0.98), Color(0.090, 0.080, 0.100, 0.98), 1, 8)
	_styles["slot"] = _style(Color(0.335, 0.355, 0.405, 0.96), Color(0.260, 0.275, 0.320, 1), 1, 6)
	_styles["slot_active"] = _style(Color(0.960, 0.970, 0.990, 1), Color(0.575, 0.760, 1.0, 1), 1, 7)
	_styles["slot_focus"] = _style(Color(0.320, 0.340, 0.390, 0.98), Color(0.520, 0.720, 1.0, 1), 2, 7)
	_styles["room_slot_selected"] = _style(Color(0.160, 0.205, 0.285, 0.98), Color(0.610, 0.800, 1.0, 1), 2, 7)
	_styles["field"] = _style(Color(0.085, 0.075, 0.095, 0.98), Color(0.595, 0.620, 0.675, 1), 2, 8)
	_styles["field_hover"] = _style(Color(0.095, 0.085, 0.105, 0.98), Color(0.760, 0.840, 1.0, 1), 2, 8)
	_styles["field_focus"] = _style(Color(0.085, 0.075, 0.095, 0.98), Color(0.600, 0.780, 1.0, 1), 2, 8)
	_styles["button"] = _style(Color(0.805, 0.615, 0.205, 1), Color(0.805, 0.615, 0.205, 1), 1, 8)
	_styles["button_hover"] = _style(Color(0.980, 0.750, 0.235, 1), Color(1.0, 0.845, 0.340, 1), 1, 8)
	_styles["button_disabled"] = _style(Color(0.700, 0.560, 0.260, 1), Color(0.700, 0.560, 0.260, 1), 1, 8)
	_styles["button_dark"] = _style(Color(0.090, 0.080, 0.100, 0.98), Color(0.090, 0.080, 0.100, 0.98), 1, 8)
	_styles["button_dark_hover"] = _style(Color(0.165, 0.175, 0.215, 0.98), Color(0.420, 0.520, 0.680, 1), 1, 8)
	_styles["key"] = _style(Color(0.830, 0.850, 0.880, 1), Color(0.900, 0.920, 0.950, 1), 1, 6)
	_styles["language"] = _style(Color(0.165, 0.180, 0.220, 0.90), Color(0.355, 0.395, 0.470, 1), 1, 8)
	_styles["popup_panel"] = _style(Color(0.085, 0.080, 0.098, 0.99), Color(0.085, 0.080, 0.098, 0.99), 1, 8)
	_styles["popup_hover"] = _style(Color(0.140, 0.150, 0.190, 0.99), Color(1.0, 0.720, 0.120, 1), 2, 6)
	_styles["chat_panel"] = _style(Color(0.090, 0.080, 0.100, 0.96), Color(0.380, 0.390, 0.435, 0.95), 1, 9)
	_styles["chat_input"] = _style(Color(0.165, 0.155, 0.180, 0.98), Color(0.290, 0.285, 0.315, 1), 1, 0)
	_styles["chat_tab"] = _style(Color(0.085, 0.075, 0.095, 1), Color(0.085, 0.075, 0.095, 1), 1, 0)
	_styles["slot_active"].shadow_color = Color(0.500, 0.705, 1.0, 0.78)
	_styles["slot_active"].shadow_size = _s(12)
	_styles["slot_focus"].shadow_color = Color(0.500, 0.705, 1.0, 0.66)
	_styles["slot_focus"].shadow_size = _s(10)
	_styles["room_slot_selected"].shadow_color = Color(0.360, 0.590, 1.0, 0.55)
	_styles["room_slot_selected"].shadow_size = _s(8)
	_styles["field_focus"].shadow_color = Color(0.500, 0.705, 1.0, 0.78)
	_styles["field_focus"].shadow_size = _s(10)


func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = _s(radius)
	style.corner_radius_top_right = _s(radius)
	style.corner_radius_bottom_left = _s(radius)
	style.corner_radius_bottom_right = _s(radius)
	style.content_margin_left = _s(12)
	style.content_margin_right = _s(12)
	style.content_margin_top = _s(8)
	style.content_margin_bottom = _s(8)
	return style


func _build_ui() -> void:
	var discarded_index := 0
	for child in get_children():
		if _public_ip_request and is_instance_valid(_public_ip_request) and child == _public_ip_request:
			continue
		if _ui_click_player and is_instance_valid(_ui_click_player) and child == _ui_click_player:
			continue
		if _ui_select_player and is_instance_valid(_ui_select_player) and child == _ui_select_player:
			continue
		child.name = "_RebuildDiscarded%d" % discarded_index
		discarded_index += 1
		child.queue_free()
	landing_role_buttons.clear()
	lobby_role_buttons.clear()
	user_rows.clear()
	team_lists.clear()
	_ensure_ui_click_player()
	_ensure_ui_select_player()

	_build_stage_background()

	# In-game overlay: settings only, no landing/lobby/menus behind it.
	if _in_game_settings:
		settings_visible = true
		_build_settings_panel()
		return

	if public_lobby_visible:
		_build_public_lobby_ui()
	elif lobby_visible:
		_build_lobby_ui()
	else:
		_build_landing_ui()
	if settings_visible:
		_build_settings_panel()
	if public_lobby_visible:
		_build_public_lobby_loading_overlay()
		_build_public_lobby_alert_overlay()
	# Player-name chip on the landing page, plus a one-time prompt on first run.
	if not lobby_visible and not public_lobby_visible and not settings_visible:
		if not _name_panel_open and not _name_panel_prompted and not GameSettings.has_player_name():
			_name_panel_open = true
			_name_panel_prompted = true
		_build_player_name_chip()
	if _name_panel_open:
		_build_player_name_overlay()
	_connect_button_click_audio(self)


func _ensure_ui_click_player() -> void:
	if _ui_click_player and is_instance_valid(_ui_click_player):
		return
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.name = "UIClickAudio"
	_ui_click_player.bus = &"Master"
	_ui_click_player.volume_db = -7.0
	_ui_click_player.max_polyphony = 4
	var stream := load(UI_CLICK_SOUND_PATH)
	if stream is AudioStream:
		_ui_click_player.stream = stream
	add_child(_ui_click_player)


func _ensure_ui_select_player() -> void:
	if _ui_select_player and is_instance_valid(_ui_select_player):
		return
	_ui_select_player = AudioStreamPlayer.new()
	_ui_select_player.name = "UISelectAudio"
	_ui_select_player.bus = &"Master"
	_ui_select_player.volume_db = -8.0
	_ui_select_player.max_polyphony = 4
	var stream := load(UI_SELECT_SOUND_PATH)
	if stream is AudioStream:
		_ui_select_player.stream = stream
	add_child(_ui_select_player)


func _connect_button_click_audio(root: Node) -> void:
	for child in root.get_children():
		if child == _ui_click_player or child == _ui_select_player or child == _public_ip_request:
			continue
		if child is Button:
			var button := child as Button
			if button.has_meta(UI_SELECT_CLICK_META):
				_connect_button_click_audio(child)
				continue
			var click_callable := Callable(self, "_play_ui_click_sound")
			if not button.pressed.is_connected(click_callable):
				button.pressed.connect(click_callable)
		_connect_button_click_audio(child)


func _play_ui_click_sound() -> void:
	if not _ui_click_player or not is_instance_valid(_ui_click_player):
		return
	if not _ui_click_player.stream:
		return
	_ui_click_player.pitch_scale = randf_range(0.985, 1.015)
	_ui_click_player.stop()
	_ui_click_player.play()


func _play_ui_select_sound() -> void:
	if not _ui_select_player or not is_instance_valid(_ui_select_player):
		return
	if not _ui_select_player.stream:
		return
	_ui_select_player.pitch_scale = randf_range(0.985, 1.015)
	_ui_select_player.stop()
	_ui_select_player.play()


func _mark_select_click_button(button: Button) -> void:
	button.set_meta(UI_SELECT_CLICK_META, true)


func _build_public_lobby_loading_overlay() -> void:
	if public_lobby_loading_text.is_empty():
		return
	var scrim := ColorRect.new()
	scrim.name = "PublicLobbyLoadingScrim"
	scrim.color = Color(0.045, 0.050, 0.065, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.name = "PublicLobbyLoadingCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PublicLobbyLoadingPanel"
	panel.custom_minimum_size = _sv(440, 132)
	panel.add_theme_stylebox_override("panel", _style(Color(0.090, 0.080, 0.105, 0.98), Color(0.620, 0.800, 1.0, 1), 2, 8))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", _s(10))
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(10))
	box.add_child(row)
	row.add_child(_icon("res://addons/at-icons/control/cloud.svg", 24, "#ffc94a"))
	var title := _label(public_lobby_loading_text, 24, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var hint := _muted_label(I18n.t("public_lobby.loading_hint"), 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _build_public_lobby_alert_overlay() -> void:
	if public_lobby_alert_text.is_empty():
		return
	var center := CenterContainer.new()
	center.name = "PublicLobbyAlertCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -_s(170)
	center.offset_bottom = -_s(170)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PublicLobbyAlertPanel"
	panel.custom_minimum_size = _sv(460, 76)
	var bg := Color(0.190, 0.075, 0.070, 0.98) if public_lobby_alert_error else Color(0.090, 0.080, 0.105, 0.98)
	var border := Color(1.0, 0.430, 0.260, 1) if public_lobby_alert_error else Color(0.620, 0.800, 1.0, 1)
	panel.add_theme_stylebox_override("panel", _style(bg, border, 2, 8))
	center.add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(10))
	panel.add_child(row)
	row.add_child(_icon(PUBLIC_ROOM_LOCK_ICON, 22, "#ffd17a"))
	var label := _label(public_lobby_alert_text, 20, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)


func _build_player_name_chip() -> void:
	var current_name := GameSettings.get_player_name()
	var chip := _button("", false)
	chip.name = "PlayerNameChip"
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.offset_left = -_s(238)
	chip.offset_top = _s(52)
	chip.offset_right = -_s(20)
	chip.offset_bottom = _s(88)
	chip.add_theme_stylebox_override("normal", _style(Color(0.10, 0.11, 0.15, 0.92), Color(0.62, 0.80, 1.0, 0.85), 2, 8))
	chip.add_theme_stylebox_override("hover", _style(Color(0.16, 0.18, 0.24, 0.97), Color(0.84, 0.92, 1.0, 1.0), 2, 8))
	chip.add_theme_font_size_override("font_size", _s(15))
	chip.text = current_name if not current_name.is_empty() else I18n.t("name_chip.unnamed")
	chip.tooltip_text = I18n.t("name_chip.edit")
	chip.pressed.connect(_open_name_panel)
	add_child(chip)


func _build_player_name_overlay() -> void:
	var scrim := ColorRect.new()
	scrim.name = "PlayerNameScrim"
	scrim.color = Color(0.03, 0.035, 0.05, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.name = "PlayerNameCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PlayerNamePanel"
	panel.custom_minimum_size = _sv(440, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.090, 0.085, 0.110, 0.99), Color(0.62, 0.80, 1.0, 1), 2, 12))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, _s(22))
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", _s(14))
	margin.add_child(col)

	var has_name := GameSettings.has_player_name()
	col.add_child(_label(I18n.t("name_panel.title_change" if has_name else "name_panel.title_define"), 26, true))
	col.add_child(_muted_label(I18n.t("name_panel.hint"), 15))

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", _s(8))
	col.add_child(input_row)
	_name_panel_input = _line_edit(I18n.t("name_panel.placeholder"))
	_name_panel_input.text = GameSettings.get_player_name()
	_name_panel_input.max_length = GameSettings.MAX_PLAYER_NAME_LENGTH
	_name_panel_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_panel_input.text_submitted.connect(func(_submitted: String) -> void: _on_name_confirm_pressed())
	input_row.add_child(_name_panel_input)
	var dice := _button("🎲", false)
	dice.name = "NameDiceButton"
	dice.custom_minimum_size = _sv(46, 40)
	dice.tooltip_text = I18n.t("name_panel.dice")
	dice.focus_mode = Control.FOCUS_NONE
	# Soft rounded styling (reuse the field styleboxes) so the die blends with the input.
	dice.add_theme_stylebox_override("normal", _styles["field"])
	dice.add_theme_stylebox_override("hover", _styles["field_hover"])
	dice.add_theme_stylebox_override("pressed", _styles["field_focus"])
	dice.add_theme_stylebox_override("focus", _styles["field"])
	dice.add_theme_font_size_override("font_size", _s(20))
	dice.add_theme_color_override("font_color", Color(0.92, 0.94, 0.99, 1))
	dice.pressed.connect(_roll_dice.bind(dice))
	input_row.add_child(dice)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", _s(10))
	col.add_child(button_row)
	if has_name:
		var cancel := _button(I18n.t("name_panel.cancel"), false)
		cancel.pressed.connect(_close_name_panel)
		button_row.add_child(cancel)
	var confirm := _button(I18n.t("name_panel.confirm"), true)
	confirm.pressed.connect(_on_name_confirm_pressed)
	button_row.add_child(confirm)
	_name_panel_input.call_deferred("grab_focus")


func _open_name_panel() -> void:
	_name_panel_open = true
	_build_ui()


func _close_name_panel() -> void:
	_name_panel_open = false
	_name_panel_input = null
	_build_ui()


func _on_name_dice_pressed() -> void:
	if _name_panel_input == null or not is_instance_valid(_name_panel_input):
		return
	_name_panel_input.text = PlayerNameGenerator.random_name(I18n.current_locale == "zh")
	_name_panel_input.caret_column = _name_panel_input.text.length()


# Roll a fresh name and play a quick spin + squash bounce on the die button.
func _roll_dice(button: Button) -> void:
	_on_name_dice_pressed()
	if button == null or not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	button.rotation = 0.0
	button.scale = Vector2.ONE
	var spin := create_tween()
	spin.tween_property(button, "rotation", TAU, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bounce := create_tween()
	bounce.tween_property(button, "scale", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(button, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_name_confirm_pressed() -> void:
	var entered := ""
	if _name_panel_input != null and is_instance_valid(_name_panel_input):
		entered = _name_panel_input.text
	var sanitized := GameSettings.sanitize_player_name(entered)
	if sanitized.is_empty():
		# Never let the player leave without a name — roll one in the active language.
		sanitized = PlayerNameGenerator.random_name(I18n.current_locale == "zh")
	GameSettings.set_player_name(sanitized)
	if nick_input != null and is_instance_valid(nick_input):
		nick_input.text = sanitized
	_close_name_panel()


func _build_stage_background() -> void:
	var background := TextureRect.new()
	background.name = "MainMenuBackground"
	background.texture = load("res://assets/ui/main_menu_background.png")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)



func _build_language_bar() -> void:
	var bar = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -_s(238)
	bar.offset_top = _s(12)
	bar.offset_right = -_s(20)
	bar.offset_bottom = _s(46)
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", _s(8))
	add_child(bar)

	language_option = _option_button()
	language_option.custom_minimum_size = _sv(154, 30)
	language_option.add_theme_stylebox_override("normal", _styles["language"])
	language_option.add_theme_stylebox_override("hover", _styles["field_hover"])
	language_option.add_theme_font_size_override("font_size", _s(13))
	for choice in I18n.get_language_choices():
		language_option.add_item(choice["label"])
		language_option.set_item_metadata(language_option.item_count - 1, choice["value"])
		if choice["value"] == I18n.language_setting:
			language_option.select(language_option.item_count - 1)
	_refresh_option_popup_checks(language_option)
	language_option.item_selected.connect(func(index):
		_play_ui_select_sound()
		_refresh_option_popup_checks(language_option)
		I18n.set_language_setting(str(language_option.get_item_metadata(index)))
	)
	bar.add_child(language_option)

	var settings_button = _icon_button("res://addons/at-icons/control/cog.svg")
	settings_button.custom_minimum_size = _sv(34, 30)
	settings_button.tooltip_text = I18n.t("settings")
	settings_button.pressed.connect(func(): _set_settings_visible(not settings_visible))
	bar.add_child(settings_button)


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = settings_visible
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.offset_left = 0.0
	settings_panel.offset_top = 0.0
	settings_panel.offset_right = 0.0
	settings_panel.offset_bottom = 0.0
	settings_panel.add_theme_stylebox_override("panel", _style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0))
	add_child(settings_panel)

	var canvas := Control.new()
	canvas.name = "SettingsCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_panel.add_child(canvas)
	_build_settings_background(canvas)

	var top_tabs := HBoxContainer.new()
	top_tabs.name = "SettingsTabs"
	top_tabs.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_tabs.offset_left = _s(44)
	top_tabs.offset_top = _s(28)
	top_tabs.offset_right = _s(760)
	top_tabs.offset_bottom = _s(82)
	top_tabs.add_theme_constant_override("separation", 0)
	canvas.add_child(top_tabs)
	for tab_config in SETTINGS_TABS:
		top_tabs.add_child(_settings_tab(str(tab_config.get("label", "")), str(tab_config.get("id", ""))))

	var title := _label(I18n.t("settings").to_upper(), 96, true)
	title.name = "SettingsTitle"
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = _s(58)
	title.offset_top = _s(118)
	title.offset_right = _s(470)
	title.offset_bottom = _s(232)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.70))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.075, 0.170, 0.18))
	title.add_theme_constant_override("outline_size", _s(2))
	canvas.add_child(title)

	var viewport_size: Vector2 = get_viewport_rect().size
	var scroll_left: int = mini(_s(650), roundi(viewport_size.x * 0.52))
	var scroll_top: int = _s(238)
	var scroll_right: int = mini(_s(1810), roundi(viewport_size.x) - _s(48))
	var scroll_bottom: int = maxi(scroll_top + _s(220), roundi(viewport_size.y) - _s(124))

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = scroll_left
	scroll.offset_top = scroll_top
	scroll.offset_right = scroll_right
	scroll.offset_bottom = scroll_bottom
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "SettingsRows"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _s(8))
	scroll.add_child(content)

	_build_settings_active_page(content)

	var footer := HBoxContainer.new()
	footer.name = "SettingsFooter"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -_s(650)
	footer.offset_top = -_s(82)
	footer.offset_right = -_s(48)
	footer.offset_bottom = -_s(34)
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", _s(14))
	canvas.add_child(footer)

	var reset_button := _button(I18n.t("reset").to_upper(), false)
	reset_button.custom_minimum_size = _sv(190, 42)
	reset_button.pressed.connect(func():
		GameSettings.reset_camera_fov()
		GameSettings.reset_graphics_settings()
		_build_ui()
	)
	footer.add_child(reset_button)
	var back_button := _button(I18n.t("back").to_upper(), true)
	back_button.custom_minimum_size = _sv(150, 42)
	back_button.pressed.connect(func(): _set_settings_visible(false))
	footer.add_child(back_button)


func _build_settings_background(canvas: Control) -> void:
	var texture_resource: Resource = load(SETTINGS_BACKGROUND_PATH)
	if texture_resource is Texture2D:
		var background := TextureRect.new()
		background.name = "SettingsBackground"
		background.texture = texture_resource as Texture2D
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
		canvas.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.name = "SettingsBackgroundFallback"
		fallback.color = Color(0.820, 0.900, 1.0, 0.68)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(fallback)

	var wash := ColorRect.new()
	wash.name = "SettingsBackgroundWash"
	wash.color = Color(0.900, 0.945, 1.0, 0.16)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.offset_left = 0.0
	wash.offset_top = 0.0
	wash.offset_right = 0.0
	wash.offset_bottom = 0.0
	canvas.add_child(wash)


func _settings_tab_exists(tab_id: String) -> bool:
	for tab_config in SETTINGS_TABS:
		if str(tab_config.get("id", "")) == tab_id:
			return true
	return false


func _set_settings_active_tab(tab_id: String) -> void:
	if not _settings_tab_exists(tab_id):
		tab_id = SETTINGS_TAB_GENERAL
	if settings_active_tab == tab_id:
		return
	settings_active_tab = tab_id
	_build_ui()
	if public_lobby_visible:
		update_public_lobby(public_lobby_rooms)
	elif lobby_visible:
		update_lobby(Network.players, Network.lobby_config)


func _build_settings_active_page(content: VBoxContainer) -> void:
	if not _settings_tab_exists(settings_active_tab):
		settings_active_tab = SETTINGS_TAB_GENERAL
	match settings_active_tab:
		SETTINGS_TAB_VIDEO:
			_build_settings_video_page(content)
		SETTINGS_TAB_RENDER:
			_build_settings_render_page(content)
		SETTINGS_TAB_GAMEPLAY:
			_build_settings_gameplay_page(content)
		_:
			_build_settings_general_page(content)


func _build_settings_general_page(content: VBoxContainer) -> void:
	content.add_child(_settings_section_label(I18n.t("settings.section.general")))
	_add_settings_language_row(content)


func _build_settings_video_page(content: VBoxContainer) -> void:
	content.add_child(_settings_section_label(I18n.t("settings.section.video")))
	_add_settings_option_row(content, "DisplayModeSettingRow", I18n.t("settings.display_mode"), "display_mode", [
		{"label": I18n.t("settings.display_mode.windowed"), "value": Window.MODE_WINDOWED},
		{"label": I18n.t("settings.display_mode.fullscreen"), "value": Window.MODE_FULLSCREEN},
		{"label": I18n.t("settings.display_mode.exclusive"), "value": Window.MODE_EXCLUSIVE_FULLSCREEN},
	])
	_add_settings_option_row(content, "VSyncSettingRow", I18n.t("settings.vsync"), "vsync", [
		{"label": I18n.t("settings.off"), "value": DisplayServer.VSYNC_DISABLED},
		{"label": I18n.t("settings.on"), "value": DisplayServer.VSYNC_ENABLED},
		{"label": I18n.t("settings.vsync.adaptive"), "value": DisplayServer.VSYNC_ADAPTIVE},
		{"label": I18n.t("settings.vsync.mailbox"), "value": DisplayServer.VSYNC_MAILBOX},
	])
	_add_settings_option_row(content, "MaxFpsSettingRow", I18n.t("settings.max_fps"), "max_fps", [
		{"label": "30", "value": 30},
		{"label": "60", "value": 60},
		{"label": "90", "value": 90},
		{"label": "120", "value": 120},
		{"label": "144", "value": 144},
		{"label": "160", "value": 160},
		{"label": "240", "value": 240},
		{"label": I18n.t("settings.unlimited"), "value": 0},
	])
	_add_settings_option_row(content, "ResolutionScaleSettingRow", I18n.t("settings.resolution_scale"), "resolution_scale", [
		{"label": I18n.t("settings.resolution_scale.ultra_performance"), "value": 1.0 / 3.0},
		{"label": I18n.t("settings.resolution_scale.performance"), "value": 0.5},
		{"label": I18n.t("settings.resolution_scale.balanced"), "value": 1.0 / 1.7},
		{"label": I18n.t("settings.resolution_scale.quality"), "value": 1.0 / 1.3},
		{"label": I18n.t("settings.resolution_scale.native"), "value": 1.0},
	])
	_add_settings_option_row(content, "ScaleFilterSettingRow", I18n.t("settings.scale_filter"), "scale_filter", [
		{"label": "BILINEAR", "value": Viewport.SCALING_3D_MODE_BILINEAR},
		{"label": "FSR 1", "value": Viewport.SCALING_3D_MODE_FSR},
		{"label": "FSR 2", "value": Viewport.SCALING_3D_MODE_FSR2},
	])


func _build_settings_render_page(content: VBoxContainer) -> void:
	content.add_child(_settings_section_label(I18n.t("settings.section.rendering")))
	_add_settings_option_row(content, "TaaSettingRow", "TAA", "taa", _settings_bool_items())
	_add_settings_option_row(content, "MsaaSettingRow", "MSAA", "msaa", [
		{"label": I18n.t("settings.off"), "value": Viewport.MSAA_DISABLED},
		{"label": "2X", "value": Viewport.MSAA_2X},
		{"label": "4X", "value": Viewport.MSAA_4X},
		{"label": "8X", "value": Viewport.MSAA_8X},
	])
	_add_settings_option_row(content, "FxaaSettingRow", "FXAA", "fxaa", _settings_bool_items())
	_add_settings_option_row(content, "ShadowSettingRow", I18n.t("settings.shadow_mapping"), "shadow_mapping", _settings_bool_items())
	_add_settings_option_row(content, "SsaoSettingRow", "SSAO", "ssao_quality", _settings_quality_items())
	_add_settings_option_row(content, "SsilSettingRow", "SSIL", "ssil_quality", _settings_quality_items())
	_add_settings_option_row(content, "BloomSettingRow", I18n.t("settings.bloom"), "bloom", _settings_bool_items())
	_add_settings_option_row(content, "VolumetricFogSettingRow", I18n.t("settings.volumetric_fog"), "volumetric_fog", _settings_bool_items())
	_add_settings_option_row(content, "GiSettingRow", I18n.t("settings.global_illumination"), "gi_quality", [
		{"label": I18n.t("settings.off"), "value": GameSettings.GIQuality.DISABLED},
		{"label": I18n.t("settings.quality.medium"), "value": GameSettings.GIQuality.LOW},
		{"label": I18n.t("settings.quality.high"), "value": GameSettings.GIQuality.HIGH},
	])


func _build_settings_gameplay_page(content: VBoxContainer) -> void:
	content.add_child(_settings_section_label(I18n.t("settings.section.gameplay")))
	_add_settings_fov_row(content)
	_add_settings_nameplate_row(content)


func _settings_tab(text: String, tab_id: String) -> Button:
	var active := settings_active_tab == tab_id
	var tab := Button.new()
	tab.name = "SettingsTab%s" % text.capitalize().replace(" ", "")
	tab.text = text
	tab.custom_minimum_size = _sv(174, 54)
	tab.focus_mode = Control.FOCUS_NONE
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.add_theme_font_size_override("font_size", _s(22))
	tab.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if active else Color(0.500, 0.820, 1.0, 0.92))
	var active_style := _style(Color(0.140, 0.585, 0.825, 0.94), Color(0.160, 0.900, 1.0, 0.95), 1, 1)
	var idle_style := _style(Color(0.085, 0.130, 0.220, 0.78), Color(0.230, 0.310, 0.430, 0.65), 1, 1)
	var hover_style := _style(Color(0.130, 0.250, 0.360, 0.88), Color(0.360, 0.700, 0.960, 0.82), 1, 1)
	tab.add_theme_stylebox_override("normal", active_style if active else idle_style)
	tab.add_theme_stylebox_override("hover", active_style if active else hover_style)
	tab.add_theme_stylebox_override("pressed", active_style)
	if not active:
		tab.pressed.connect(func(): _set_settings_active_tab(tab_id))
	return tab


func _settings_row_container(row_name: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = row_name
	row.custom_minimum_size = _sv(0, 54)
	row.add_theme_stylebox_override("panel", _style(Color(0.210, 0.240, 0.320, 0.60), Color(1.0, 1.0, 1.0, 0.22), 1, 1))
	return row


func _settings_row_label(text: String) -> Label:
	var label := _label(text.to_upper(), 22, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.940, 0.970, 1.0, 0.98))
	return label


func _settings_value_label(text: String) -> Label:
	var label := _label(text, 22, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	return label


func _settings_language_option() -> OptionButton:
	var option := _option_button()
	option.custom_minimum_size = _sv(320, 42)
	option.add_theme_stylebox_override("normal", _style(Color(0.160, 0.380, 0.565, 0.90), Color(0.330, 0.650, 0.920, 0.96), 1, 2))
	option.add_theme_stylebox_override("hover", _style(Color(0.205, 0.470, 0.660, 0.95), Color(0.560, 0.860, 1.0, 1.0), 1, 2))
	option.add_theme_font_size_override("font_size", _s(19))
	for choice in I18n.get_language_choices():
		option.add_item(choice["label"])
		option.set_item_metadata(option.item_count - 1, choice["value"])
		if choice["value"] == I18n.language_setting:
			option.select(option.item_count - 1)
	_refresh_option_popup_checks(option)
	option.item_selected.connect(func(index):
		_play_ui_select_sound()
		_refresh_option_popup_checks(option)
		I18n.set_language_setting(str(option.get_item_metadata(index)))
	)
	return option


func _settings_section_label(text: String) -> Label:
	var label := _label(text.to_upper(), 17, true)
	label.custom_minimum_size = _sv(0, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_color", Color(0.530, 0.900, 1.0, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.080, 0.160, 0.55))
	label.add_theme_constant_override("outline_size", _s(1))
	return label


func _add_settings_language_row(content: VBoxContainer) -> void:
	var row := _settings_row_container("LanguageSettingRow")
	var layout := _settings_row_layout(row)
	layout.add_child(_settings_row_label(I18n.t("language")))
	var option := _settings_language_option()
	option.size_flags_horizontal = Control.SIZE_SHRINK_END
	layout.add_child(option)
	content.add_child(row)


func _add_settings_nameplate_row(content: VBoxContainer) -> void:
	var row := _settings_row_container("NameplateSettingRow")
	var layout := _settings_row_layout(row)
	layout.add_child(_settings_row_label("Player Nameplates"))
	var toggle := CheckButton.new()
	toggle.name = "NameplateToggle"
	toggle.button_pressed = GameSettings.get_show_player_nameplates()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.toggled.connect(func(pressed: bool) -> void:
		_play_ui_select_sound()
		GameSettings.set_show_player_nameplates(pressed))
	layout.add_child(toggle)
	content.add_child(row)


func _add_settings_fov_row(content: VBoxContainer) -> void:
	var row := _settings_row_container("FovSettingRow")
	var layout := _settings_row_layout(row)
	layout.add_child(_settings_row_label(I18n.t("camera_fov")))
	fov_slider = HSlider.new()
	fov_slider.name = "FovSlider"
	fov_slider.min_value = GameSettings.MIN_FOV
	fov_slider.max_value = GameSettings.MAX_FOV
	fov_slider.step = 1.0
	fov_slider.value = GameSettings.camera_fov
	fov_slider.custom_minimum_size = _sv(280, 42)
	fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_slider.value_changed.connect(_on_fov_slider_changed)
	layout.add_child(fov_slider)
	fov_value_label = _settings_value_label("")
	fov_value_label.custom_minimum_size = _sv(102, 0)
	layout.add_child(fov_value_label)
	_update_fov_value_label()
	content.add_child(row)


func _add_settings_option_row(content: VBoxContainer, row_name: String, label_text: String, setting_key: String, items: Array) -> void:
	var row := _settings_row_container(row_name)
	var layout := _settings_row_layout(row)
	layout.add_child(_settings_row_label(label_text))
	var option := _settings_graphics_option(setting_key, items)
	layout.add_child(option)
	content.add_child(row)


func _settings_row_layout(row: PanelContainer) -> HBoxContainer:
	var layout := HBoxContainer.new()
	layout.name = "RowLayout"
	layout.add_theme_constant_override("separation", _s(14))
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(layout)
	var spacer := Control.new()
	spacer.custom_minimum_size = _sv(14, 0)
	layout.add_child(spacer)
	return layout


func _settings_graphics_option(setting_key: String, items: Array) -> OptionButton:
	var option := _option_button()
	option.name = "%sOption" % setting_key.capitalize().replace(" ", "")
	option.custom_minimum_size = _sv(300, 42)
	option.size_flags_horizontal = Control.SIZE_SHRINK_END
	var settings := GameSettings.graphics_settings()
	var current_value = settings.get(setting_key)
	for item in items:
		option.add_item(str(item.get("label", "")))
		option.set_item_metadata(option.item_count - 1, item.get("value"))
		if _settings_values_match(item.get("value"), current_value):
			option.select(option.item_count - 1)
	if option.selected < 0 and option.item_count > 0:
		option.select(0)
	_refresh_option_popup_checks(option)
	option.item_selected.connect(func(index):
		_play_ui_select_sound()
		_refresh_option_popup_checks(option)
		GameSettings.set_graphics_setting(setting_key, option.get_item_metadata(index))
	)
	return option


func _settings_bool_items() -> Array:
	return [
		{"label": I18n.t("settings.off"), "value": false},
		{"label": I18n.t("settings.on"), "value": true},
	]


func _settings_quality_items() -> Array:
	return [
		{"label": I18n.t("settings.off"), "value": -1},
		{"label": I18n.t("settings.quality.medium"), "value": RenderingServer.ENV_SSAO_QUALITY_MEDIUM},
		{"label": I18n.t("settings.quality.high"), "value": RenderingServer.ENV_SSAO_QUALITY_HIGH},
	]


func _settings_values_match(left, right) -> bool:
	if left is float or right is float:
		return is_equal_approx(float(left), float(right))
	return left == right


func _set_settings_visible(value: bool) -> void:
	# In the in-game overlay any "close settings" action returns to the pause menu.
	if not value and _in_game_settings:
		close_in_game_settings()
		return
	settings_visible = value
	if value and not lobby_visible and not public_lobby_visible:
		landing_action_panel_mode = ""
	_build_ui()
	if public_lobby_visible:
		update_public_lobby(public_lobby_rooms)
	elif lobby_visible:
		update_lobby(Network.players, Network.lobby_config)


func _on_fov_slider_changed(value: float) -> void:
	GameSettings.set_camera_fov(value)
	_update_fov_value_label()


func _update_fov_value_label() -> void:
	if fov_value_label:
		fov_value_label.text = I18n.tf("camera_fov_value", [roundi(GameSettings.camera_fov)])


func _build_landing_ui() -> void:
	var show_private_join_panel := landing_action_panel_mode == "private_join"
	_prepare_landing_inputs(show_private_join_panel)
	_build_landing_brand()

	var menu := VBoxContainer.new()
	menu.name = "LandingVerticalMenu"
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.offset_left = _s(64)
	menu.offset_top = _s(236)
	menu.offset_right = _s(900)
	menu.offset_bottom = _s(668)
	menu.add_theme_constant_override("separation", _s(0))
	add_child(menu)

	public_server_button = _landing_menu_button(I18n.t("menu.public_server"), false, true)
	public_server_button.tooltip_text = I18n.t("public_server_hint")
	public_server_button.pressed.connect(_on_public_server_pressed)
	menu.add_child(public_server_button)

	host_button = _landing_menu_button(I18n.t("menu.create_private_server"), false, true)
	host_button.pressed.connect(_on_host_pressed)
	menu.add_child(host_button)

	join_button = _landing_menu_button(I18n.t("menu.join_private_server"), show_private_join_panel, true)
	join_button.pressed.connect(_open_landing_private_join_panel)
	menu.add_child(join_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = _sv(0, 18)
	menu.add_child(spacer)

	var settings_menu_button := _landing_menu_button(I18n.t("menu.settings"), settings_visible, false)
	settings_menu_button.pressed.connect(func(): _set_settings_visible(not settings_visible))
	menu.add_child(settings_menu_button)

	var quit := _landing_menu_button(I18n.t("menu.exit_game"), false, false)
	quit.pressed.connect(func(): quit_pressed.emit())
	menu.add_child(quit)

	_build_landing_private_join_panel()
	_update_role_buttons(landing_role_buttons)


func _prepare_landing_inputs(show_private_join_panel: bool) -> void:
	nick_input = _line_edit(I18n.t("placeholder.nick"))
	nick_input.text = GameSettings.get_player_name()
	skin_input = _line_edit(I18n.t("placeholder.skin"))
	character_option = _character_option()
	room_name_input = _line_edit(I18n.t("placeholder.room_name"))
	address_input = _line_edit(I18n.t("placeholder.join_target"))
	join_lobby_input = _line_edit(I18n.t("placeholder.lobby"))
	skin_input.text = "blue"
	room_name_input.max_length = 32
	address_input.max_length = 64
	join_lobby_input.max_length = 8
	address_input.text_changed.connect(func(_text): _refresh_landing_join_state())
	join_lobby_input.text_changed.connect(_on_lobby_password_text_changed)

	var hidden_inputs := Control.new()
	hidden_inputs.name = "LandingHiddenInputs"
	hidden_inputs.visible = false
	hidden_inputs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hidden_inputs)
	hidden_inputs.add_child(nick_input)
	hidden_inputs.add_child(skin_input)
	hidden_inputs.add_child(character_option)
	hidden_inputs.add_child(room_name_input)
	if not show_private_join_panel:
		hidden_inputs.add_child(address_input)
		hidden_inputs.add_child(join_lobby_input)


func _build_landing_brand() -> void:
	var brand := VBoxContainer.new()
	brand.name = "LandingBrand"
	brand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	brand.offset_left = _s(62)
	brand.offset_top = _s(28)
	brand.offset_right = _s(1040)
	brand.offset_bottom = _s(150)
	brand.add_theme_constant_override("separation", _s(0))
	add_child(brand)

	var title := _label(I18n.t("app.title"), 76, true)
	if _font_wordmark:
		title.add_theme_font_override("font", _font_wordmark)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.99))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	title.add_theme_constant_override("outline_size", _s(4))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.070, 0.150, 0.86))
	title.add_theme_constant_override("shadow_offset_x", _s(3))
	title.add_theme_constant_override("shadow_offset_y", _s(3))
	brand.add_child(title)

	var subtitle := _muted_label(_display_version(), 17)
	subtitle.add_theme_color_override("font_color", Color(0.850, 0.930, 1.0, 0.88))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.060, 0.130, 0.78))
	subtitle.add_theme_constant_override("shadow_offset_x", _s(2))
	subtitle.add_theme_constant_override("shadow_offset_y", _s(2))
	brand.add_child(subtitle)


func _build_landing_private_join_panel() -> void:
	if landing_action_panel_mode != "private_join":
		return
	var panel := PanelContainer.new()
	panel.name = "PrivateJoinPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = _s(805)
	panel.offset_top = _s(330)
	panel.offset_right = _s(1248)
	panel.offset_bottom = _s(552)
	panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.042, 0.082, 0.30), Color(1.0, 0.780, 0.210, 0.70), 1, 14))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _s(8))
	panel.add_child(box)

	var title := _label(I18n.t("landing.private_join_title"), 24, true)
	title.add_theme_color_override("font_color", Color(1.0, 0.930, 0.620, 1.0))
	box.add_child(title)

	var hint := _muted_label(I18n.t("landing.private_join_hint"), 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(hint)
	box.add_child(_compact_field_row(I18n.t("join_target"), address_input))
	box.add_child(_compact_field_row(I18n.t("lobby_password"), join_lobby_input))

	join_status_label = _muted_label("", 14)
	join_status_label.visible = false
	box.add_child(join_status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", _s(8))
	box.add_child(actions)

	var back := _button(I18n.t("back"), false)
	back.custom_minimum_size = _sv(92, 36)
	back.pressed.connect(_hide_landing_private_join_panel)
	actions.add_child(back)

	var join := _button(I18n.t("landing.private_join_action"), true)
	join.custom_minimum_size = _sv(140, 36)
	join.pressed.connect(_on_join_pressed)
	actions.add_child(join)
	_refresh_landing_join_state()


func _compact_field_row(label_text: String, field: Control) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", _s(3))
	var label := _muted_label(label_text, 13)
	label.add_theme_color_override("font_color", Color(0.840, 0.875, 0.940, 0.92))
	row.add_child(label)
	field.custom_minimum_size = _sv(0, 34)
	row.add_child(field)
	return row


func _open_landing_private_join_panel() -> void:
	landing_action_panel_mode = "private_join"
	settings_visible = false
	_build_ui()
	if address_input:
		address_input.grab_focus()


func _hide_landing_private_join_panel() -> void:
	landing_action_panel_mode = ""
	_build_ui()


func _landing_menu_button(text: String, active: bool, large: bool) -> Button:
	var btn := Button.new()
	btn.text = text.to_upper()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = false
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = _sv(760, 74 if large else 46)
	var blank := _transparent_stylebox()
	btn.add_theme_stylebox_override("normal", blank)
	btn.add_theme_stylebox_override("hover", blank)
	btn.add_theme_stylebox_override("pressed", blank)
	btn.add_theme_stylebox_override("focus", blank)
	btn.add_theme_font_size_override("font_size", _s(60 if large else 36))
	btn.add_theme_constant_override("outline_size", _s(3 if large else 2))
	btn.add_theme_constant_override("shadow_offset_x", _s(3))
	btn.add_theme_constant_override("shadow_offset_y", _s(3))
	if _use_brand_font() and _font_menu:
		btn.add_theme_font_override("font", _font_menu)
	_set_landing_menu_button_state(btn, active, false)
	btn.mouse_entered.connect(func(): _set_landing_menu_button_state(btn, active, true))
	btn.mouse_exited.connect(func(): _set_landing_menu_button_state(btn, active, false))
	return btn


func _set_landing_menu_button_state(btn: Button, active: bool, hovered: bool) -> void:
	var is_hot := active or hovered
	var color := Color(1.0, 0.860, 0.230, 1.0) if is_hot else Color(1.0, 1.0, 1.0, 0.97)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_focus_color", color)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.720, 0.160, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.035, 0.085, 0.90 if is_hot else 0.74))
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.070, 0.160, 0.92 if is_hot else 0.82))
	btn.add_theme_constant_override("shadow_offset_x", _s(4 if is_hot else 3))
	btn.add_theme_constant_override("shadow_offset_y", _s(4 if is_hot else 3))


func _transparent_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _build_public_lobby_ui() -> void:
	var root = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", _s(42))
	root.add_theme_constant_override("margin_top", _s(18))
	root.add_theme_constant_override("margin_right", _s(42))
	root.add_theme_constant_override("margin_bottom", _s(24))
	add_child(root)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", _s(12))
	root.add_child(main)

	var header = HBoxContainer.new()
	header.custom_minimum_size = _sv(0, 62)
	header.add_theme_constant_override("separation", _s(14))
	main.add_child(header)

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", _s(12))
	header.add_child(title_row)
	title_row.add_child(_icon("res://addons/at-icons/control/cloud.svg", 44, "#ffffff"))
	var title = _label(I18n.t("public_lobby.title"), 46, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)

	var refresh_button = _button(I18n.t("public_lobby.refresh"), false)
	refresh_button.custom_minimum_size = _sv(140, 42)
	refresh_button.icon = _icon_texture("res://addons/at-icons/control/rotate.svg", "#ffffff", _s(20))
	refresh_button.pressed.connect(func():
		public_lobby_status_text = I18n.t("public_lobby.loading")
		public_lobby_status_error = false
		public_lobby_refresh_pressed.emit()
		show_public_lobby_status(public_lobby_status_text, false)
	)
	header.add_child(refresh_button)

	var back_button = _button(I18n.t("back"), false)
	back_button.custom_minimum_size = _sv(112, 42)
	back_button.icon = _icon_texture("res://addons/at-icons/control/arrow_left.svg", "#ffffff", _s(20))
	back_button.pressed.connect(func(): public_lobby_leave_pressed.emit())
	header.add_child(back_button)

	var subtitle = _muted_label(I18n.t("public_lobby.subtitle"), 18)
	main.add_child(subtitle)

	public_lobby_status_label = _muted_label(public_lobby_status_text, 16)
	public_lobby_status_label.visible = not public_lobby_status_text.is_empty()
	public_lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.590, 0.220, 1) if public_lobby_status_error else Color(0.760, 0.850, 1.0, 1))
	main.add_child(public_lobby_status_label)

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", _s(12))
	main.add_child(columns)
	columns.add_child(_build_public_room_create_panel())
	columns.add_child(_build_public_room_list_panel())


func _build_public_room_create_panel() -> Control:
	var panel = _panel(I18n.t("public_lobby.create_room"), "res://addons/at-icons/control/server.svg")
	panel.custom_minimum_size = Vector2(_responsive_width(0.30, 330, 470), 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := panel.get_child(0) as VBoxContainer

	public_room_create_name_input = _line_edit(I18n.t("placeholder.room_name"))
	public_room_create_name_input.max_length = 32
	public_room_create_name_input.text = public_room_create_name_text
	public_room_create_name_input.text_changed.connect(func(text): public_room_create_name_text = text)
	box.add_child(_field_row(I18n.t("room_name"), public_room_create_name_input))

	public_room_create_password_input = _line_edit(I18n.t("public_lobby.password_optional"))
	public_room_create_password_input.max_length = 8
	public_room_create_password_input.secret = true
	public_room_create_password_input.text = public_room_create_password_text
	public_room_create_password_input.text_changed.connect(func(text): public_room_create_password_text = text.to_upper())
	box.add_child(_field_row(I18n.t("lobby_password"), public_room_create_password_input))
	box.add_child(_muted_label(I18n.t("public_lobby.create_hint"), 16))

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var create_button = _button(I18n.t("public_lobby.create_room"), true)
	create_button.custom_minimum_size = _sv(0, 48)
	create_button.disabled = _public_lobby_is_busy()
	create_button.icon = _icon_texture("res://addons/at-icons/control/plus.svg", "#15110d", _s(21))
	create_button.pressed.connect(_on_public_room_create_pressed)
	box.add_child(create_button)
	return panel


func _build_public_room_list_panel() -> Control:
	var panel = _panel(I18n.t("public_lobby.active_rooms"), "res://addons/at-icons/control/globe.svg")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := panel.get_child(0) as VBoxContainer

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	public_room_list_box = VBoxContainer.new()
	public_room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_room_list_box.add_theme_constant_override("separation", _s(7))
	scroll.add_child(public_room_list_box)

	if public_lobby_rooms.is_empty():
		var empty = _muted_label(I18n.t("public_lobby.empty"), 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = _sv(0, 160)
		public_room_list_box.add_child(empty)
	else:
		for raw_room in public_lobby_rooms:
			public_room_list_box.add_child(_public_room_row(raw_room))

	box.add_child(_thin_separator())
	var selected_room := _selected_public_room()
	var selected_text := I18n.t("public_lobby.no_room_selected")
	if not selected_room.is_empty():
		selected_text = I18n.tf("public_lobby.selected", [str(selected_room.get("room_name", "Public Room"))])
	box.add_child(_muted_label(selected_text, 16))

	public_room_join_password_input = _line_edit(I18n.t("public_lobby.password_required"))
	public_room_join_password_input.max_length = 8
	public_room_join_password_input.secret = true
	public_room_join_password_input.text = public_room_join_password_text
	public_room_join_password_input.text_changed.connect(func(text): public_room_join_password_text = text.to_upper())
	box.add_child(_field_row(I18n.t("lobby_password"), public_room_join_password_input))

	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", _s(10))
	box.add_child(actions)

	public_room_join_button = _button(I18n.t("public_lobby.join_selected"), true)
	public_room_join_button.custom_minimum_size = _sv(190, 44)
	public_room_join_button.disabled = selected_public_room_id.is_empty() or _public_lobby_is_busy() or (not selected_room.is_empty() and not bool(selected_room.get("ready", true)))
	public_room_join_button.icon = _icon_texture("res://addons/at-icons/control/arrow_right.svg", "#15110d", _s(20))
	public_room_join_button.pressed.connect(_on_public_room_join_pressed)
	actions.add_child(public_room_join_button)
	return panel


func _public_room_row(raw_room) -> Control:
	var room: Dictionary = raw_room
	var room_id := str(room.get("room_id", ""))
	var is_selected := room_id == selected_public_room_id
	var is_locked := bool(room.get("locked", false))
	var is_ready := bool(room.get("ready", true))
	var row = Button.new()
	_mark_select_click_button(row)
	row.toggle_mode = true
	row.button_pressed = is_selected
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	row.custom_minimum_size = _sv(0, 52)
	row.clip_text = true
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if is_locked:
		row.icon = _icon_texture(PUBLIC_ROOM_LOCK_ICON, "#ffd17a" if not is_selected else "#ffffff", _s(18))
	var state_text := I18n.t("public_lobby.locked") if is_locked else I18n.t("public_lobby.open")
	if not is_ready:
		state_text = I18n.t("public_lobby.starting")
	var player_text := I18n.tf("public_lobby.players", [int(room.get("player_count", 0)), int(room.get("max_players", Network.MAX_PLAYERS))])
	var host_name := str(room.get("host_peer_name", "")).strip_edges()
	var host_suffix := "" if host_name.is_empty() else "  %s" % host_name
	row.text = "%s   %s   %s%s" % [str(room.get("room_name", "Public Room")), state_text, player_text, host_suffix]
	row.add_theme_stylebox_override("normal", _styles["room_slot_selected"] if is_selected else _styles["slot"])
	row.add_theme_stylebox_override("hover", _styles["room_slot_selected"] if is_selected else _styles["slot_focus"])
	row.add_theme_stylebox_override("pressed", _styles["room_slot_selected"])
	row.add_theme_color_override("font_color", Color.WHITE)
	row.add_theme_color_override("font_hover_color", Color.WHITE)
	row.add_theme_color_override("font_pressed_color", Color.WHITE)
	row.add_theme_color_override("font_focus_color", Color.WHITE)
	row.add_theme_color_override("icon_normal_color", Color.WHITE)
	row.add_theme_color_override("icon_hover_color", Color.WHITE)
	row.add_theme_constant_override("h_separation", _s(9))
	_apply_control_font(row, _font_button, 18)
	row.pressed.connect(func(): _select_public_room(room_id))
	row.gui_input.connect(func(event: InputEvent): _on_public_room_row_gui_input(event, room_id))
	return row


func _on_public_room_row_gui_input(event: InputEvent, room_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			if _public_lobby_is_busy():
				accept_event()
				return
			_select_public_room(room_id)
			call_deferred("_on_public_room_join_pressed")
			accept_event()


func _select_public_room(room_id: String) -> void:
	_play_ui_select_sound()
	selected_public_room_id = room_id
	public_lobby_status_text = ""
	public_lobby_status_error = false
	_build_ui()


func _on_public_room_create_pressed() -> void:
	if _public_lobby_is_busy():
		return
	var requested_room_name: String = public_room_create_name_input.text.strip_edges() if public_room_create_name_input else public_room_create_name_text.strip_edges()
	if requested_room_name.is_empty():
		public_room_create_name_text = ""
		show_public_lobby_status(I18n.t("public_lobby.room_name_required"), true)
		show_public_lobby_alert(I18n.t("public_lobby.room_name_required"), true)
		if public_room_create_name_input:
			public_room_create_name_input.grab_focus()
		return
	public_room_create_name_text = requested_room_name
	public_room_create_password_text = public_room_create_password_input.text.strip_edges().to_upper() if public_room_create_password_input else public_room_create_password_text.strip_edges().to_upper()
	public_lobby_status_text = I18n.t("public_lobby.creating")
	public_lobby_status_error = false
	public_lobby_alert_text = ""
	show_public_lobby_status(public_lobby_status_text, false)
	show_public_lobby_loading(public_lobby_status_text)
	public_room_create_pressed.emit(public_room_create_name_text, public_room_create_password_text)


func _on_public_room_join_pressed() -> void:
	if _public_lobby_is_busy():
		return
	if selected_public_room_id.is_empty():
		show_public_lobby_status(I18n.t("public_lobby.no_room_selected"), true)
		return
	var selected_room := _selected_public_room()
	if not bool(selected_room.get("ready", true)):
		show_public_lobby_status(I18n.t("join_status.public_room_not_ready"), true)
		return
	public_room_join_password_text = public_room_join_password_input.text.strip_edges().to_upper() if public_room_join_password_input else public_room_join_password_text.strip_edges().to_upper()
	if bool(selected_room.get("locked", false)) and public_room_join_password_text.is_empty():
		show_public_lobby_status(I18n.t("public_lobby.password_needed"), true)
		show_public_lobby_alert(I18n.t("public_lobby.password_needed"), true)
		if public_room_join_password_input:
			public_room_join_password_input.grab_focus()
		return
	public_lobby_status_text = I18n.t("join_status.connecting_room")
	public_lobby_status_error = false
	public_lobby_alert_text = ""
	show_public_lobby_status(public_lobby_status_text, false)
	show_public_lobby_loading(public_lobby_status_text)
	public_room_join_pressed.emit(selected_public_room_id, public_room_join_password_text)


func _build_lobby_ui() -> void:
	var root = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", _s(38))
	root.add_theme_constant_override("margin_top", _s(12))
	root.add_theme_constant_override("margin_right", _s(38))
	root.add_theme_constant_override("margin_bottom", _s(10))
	add_child(root)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", _s(10))
	root.add_child(main)

	var header = HBoxContainer.new()
	header.custom_minimum_size = _sv(0, 58)
	header.add_theme_constant_override("separation", _s(14))
	main.add_child(header)

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", _s(12))
	header.add_child(title_row)
	title_row.add_child(_icon("res://addons/at-icons/control/pyramid.svg", 44, "#ffffff"))
	var title = _label(I18n.t("private_match"), 46, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)

	var lobby_server_info: String = _public_room_server_info_text(Network.lobby_config)
	if not lobby_server_info.is_empty():
		header.add_child(_server_info_badge(lobby_server_info))

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", _s(12))
	main.add_child(columns)

	columns.add_child(_build_match_details_panel())
	columns.add_child(_build_users_panel())
	columns.add_child(_build_teams_panel())

	main.add_child(_build_lobby_footer())
	_build_lobby_chat_panel()


func _server_info_badge(text: String) -> Control:
	var badge := PanelContainer.new()
	badge.name = "LobbyServerInfoBadge"
	badge.custom_minimum_size = _sv(280, 42)
	badge.add_theme_stylebox_override("panel", _style(Color(0.060, 0.075, 0.120, 0.82), Color(0.560, 0.760, 1.0, 0.82), 1, 10))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _s(8))
	badge.add_child(row)

	row.add_child(_icon("res://addons/at-icons/control/cloud.svg", 20, "#93f7b1"))
	var label := _muted_label(text, 15)
	label.name = "LobbyServerInfoLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.880, 0.940, 1.0, 1.0))
	row.add_child(label)
	return badge


func _build_match_details_panel() -> Control:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styles["panel"])
	panel.custom_minimum_size = Vector2(_responsive_width(0.266, 322, 545), 0)
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", _s(8))
	panel.add_child(outer)
	outer.add_child(_label(I18n.t("match_details"), 24, true))

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", _s(6))
	scroll.add_child(box)

	box.add_child(_section_label(I18n.t("lobby_id")))
	var id_row = HBoxContainer.new()
	id_row.add_theme_constant_override("separation", _s(8))
	lobby_id_input = _line_edit(current_lobby_id)
	lobby_id_input.editable = false
	lobby_id_input.text = current_lobby_id
	id_row.add_child(lobby_id_input)
	var copy = _icon_button("res://addons/at-icons/control/clipboard.svg")
	copy.pressed.connect(func(): DisplayServer.clipboard_set(current_lobby_id))
	id_row.add_child(copy)
	box.add_child(id_row)

	var private_connection_mode: String = str(Network.lobby_config.get("private_connection_mode", "direct"))
	var private_connection_code: String = str(Network.lobby_config.get("private_connection_code", "")).strip_edges()
	var private_connection_server: String = str(Network.lobby_config.get("private_connection_server", "")).strip_edges()
	if private_connection_mode.begins_with("noray"):
		box.add_child(_section_label(I18n.t("noray_connection_code")))
		var noray_code_row: HBoxContainer = HBoxContainer.new()
		noray_code_row.add_theme_constant_override("separation", _s(8))
		var noray_code_input: LineEdit = _line_edit(I18n.t("noray_code_pending"))
		noray_code_input.editable = false
		noray_code_input.text = private_connection_code
		noray_code_row.add_child(noray_code_input)
		var copy_noray_code: Button = _icon_button("res://addons/at-icons/control/clipboard.svg")
		copy_noray_code.tooltip_text = I18n.t("copy")
		copy_noray_code.disabled = private_connection_code.is_empty()
		copy_noray_code.pressed.connect(func():
			if not private_connection_code.is_empty():
				DisplayServer.clipboard_set(private_connection_code)
		)
		noray_code_row.add_child(copy_noray_code)
		box.add_child(noray_code_row)
		if not private_connection_server.is_empty():
			box.add_child(_section_label(I18n.t("noray_server")))
			box.add_child(_muted_label("%s | %s" % [private_connection_server, private_connection_mode.to_upper()], 16))

	var public_server_info: String = _public_room_server_info_text(Network.lobby_config)
	if not public_server_info.is_empty():
		box.add_child(_section_label(I18n.t("public_lobby.title")))
		box.add_child(_muted_label(public_server_info, 16))

	if is_host_lobby and not private_connection_mode.begins_with("noray"):
		box.add_child(_section_label(I18n.t("host_address")))
		var address_row = HBoxContainer.new()
		address_row.add_theme_constant_override("separation", _s(8))
		var host_target := "%s:%d" % [Network.SERVER_ADDRESS, int(Network.lobby_config.get("host_port", Network.server_port))]
		var host_address_input = _line_edit(host_target)
		host_address_input.editable = false
		address_row.add_child(host_address_input)
		var copy_address = _icon_button("res://addons/at-icons/control/clipboard.svg")
		copy_address.tooltip_text = I18n.t("copy")
		copy_address.pressed.connect(func(): DisplayServer.clipboard_set(host_target))
		address_row.add_child(copy_address)
		box.add_child(address_row)

		box.add_child(_section_label(I18n.t("public_host_address")))
		var public_address_row = HBoxContainer.new()
		public_address_row.add_theme_constant_override("separation", _s(8))
		public_address_input = _line_edit(_public_host_target_text())
		public_address_input.editable = false
		public_address_input.tooltip_text = I18n.t("public_host_address_hint")
		public_address_row.add_child(public_address_input)
		public_address_copy_button = _icon_button("res://addons/at-icons/control/clipboard.svg")
		public_address_copy_button.tooltip_text = I18n.t("copy")
		public_address_copy_button.disabled = _public_connection_target().is_empty()
		public_address_copy_button.pressed.connect(func():
			var target: String = _public_connection_target()
			if not target.is_empty():
				DisplayServer.clipboard_set(target)
		)
		public_address_row.add_child(public_address_copy_button)
		box.add_child(public_address_row)

	players_hint_label = _muted_label(I18n.t("players_needed"), 16)
	box.add_child(players_hint_label)
	box.add_child(_thin_separator())

	map_option = _option(["Warehouse", "Street Block", "Training Yard", "Tank Demo Desert", "Tank Demo Jungle", "Tank Demo Moon", "TPS Demo Level", "garden", "Japanese Town Street", "Western Town Prop Hunt", "Polygon Apocalypse Bunker", "Polygon Apocalypse Interior", "Polygon Apocalypse City", "Polygon Apocalypse City URP", "Polygon Apocalypse City: Downtown Escape", "Polygon Apocalypse City: Quarantine Crossing", "Polygon Apocalypse City: Market Row", "Polygon Apocalypse City: Overpass Camp", "Polygon Apocalypse City: Warehouse Ward", "Polygon Apocalypse City URP: Downtown Escape", "Polygon Apocalypse City URP: Quarantine Crossing", "Polygon Apocalypse City URP: Market Row", "Polygon Apocalypse City URP: Overpass Camp", "Polygon Apocalypse City URP: Warehouse Ward"], "map")
	variant_option = _option(["Default", "Low Ammo", "Fast Hunt"], "variant")
	condition_option = _option(["Normal", "Rain", "Night"], "condition")
	game_show_option = _option(["None", "Airdrop Show", "Chaos Show"], "game_show")
	gravity_option = _option([4.9, 9.8, 14.7], "gravity")
	duration_option = _option([300, 600, 900], "duration")
	prep_option = _option([30, 60, 120], "prep")
	hunter_count_option = _option([-1, 1, 2, 3, 4, 5, 6, 7, 8], "hunters")
	stalker_glass_option = _option([0.07, 0.105, 0.125, 0.16], "stalker_glass")
	stalker_glass_material_option = _option(["classic", "liquid_glass"], "stalker_glass_material")
	auto_turret_enabled_option = _option([false, true], "auto_turret_enabled")
	auto_turret_range_option = _option([18, 26, 34, 42], "auto_turret_range")

	box.add_child(_option_group(I18n.t("level"), map_option))
	box.add_child(_option_group(I18n.t("variant"), variant_option))
	box.add_child(_option_group(I18n.t("condition"), condition_option))
	box.add_child(_option_group(I18n.t("game_show"), game_show_option))
	box.add_child(_option_group(I18n.t("gravity"), gravity_option))
	box.add_child(_option_group(I18n.t("duration"), duration_option))
	box.add_child(_option_group(I18n.t("hunter_count"), hunter_count_option))
	box.add_child(_option_group(I18n.t("stalker_glass"), stalker_glass_option))
	box.add_child(_option_group(I18n.t("stalker_glass_material"), stalker_glass_material_option))
	box.add_child(_option_group(I18n.t("auto_turret_enabled"), auto_turret_enabled_option))
	box.add_child(_option_group(I18n.t("auto_turret_range"), auto_turret_range_option))
	box.add_child(_option_group(I18n.t("hide_prep"), prep_option))

	var can_manage := _can_manage_lobby()
	auto_assign_button = _button(I18n.t("auto_assign"), false)
	auto_assign_button.disabled = not can_manage
	auto_assign_button.pressed.connect(func(): auto_assign_pressed.emit(_collect_lobby_config()))
	box.add_child(auto_assign_button)

	var roles = VBoxContainer.new()
	roles.add_theme_constant_override("separation", _s(8))
	roles.add_child(_section_label(I18n.t("choose_side")))
	for data in _role_data():
		var btn = _button(data["label"], false)
		btn.toggle_mode = true
		btn.custom_minimum_size = _sv(0, 42)
		_mark_select_click_button(btn)
		var role_id: int = data["role"]
		btn.pressed.connect(func(): _select_role_from_ui(role_id))
		roles.add_child(btn)
		lobby_role_buttons.append(btn)
	box.add_child(roles)
	_set_config_enabled(can_manage)
	_update_role_buttons(lobby_role_buttons)
	return panel


func _build_users_panel() -> Control:
	var panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", _s(12))

	var users = _panel(I18n.t("unassigned"))
	users.size_flags_vertical = Control.SIZE_EXPAND_FILL
	team_lists[TEAM_UNASSIGNED] = users.get_child(0)
	panel.add_child(users)

	var specs = _panel(I18n.t("spectators"))
	specs.custom_minimum_size = _sv(0, 190)
	team_lists[TEAM_SPECTATOR] = specs.get_child(0)
	specs.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	specs.gui_input.connect(func(event): _on_team_panel_input(event, TEAM_SPECTATOR))
	panel.add_child(specs)
	return panel


func _build_teams_panel() -> Control:
	var panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(_responsive_width(0.340, 410, 700), 0)
	panel.add_theme_constant_override("separation", _s(12))

	var teams = [
		{"title": I18n.t("team.chameleon"), "role": Network.Role.CHAMELEON, "icon": "res://addons/at-icons/control/shield.svg"},
		{"title": I18n.t("team.stalker"), "role": Network.Role.STALKER, "icon": "res://addons/at-icons/control/signal_wave.svg"},
		{"title": I18n.t("team.hunter"), "role": Network.Role.HUNTER, "icon": "res://addons/at-icons/control/star.svg"},
	]
	for team in teams:
		var card = _panel(team["title"], team["icon"])
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var role_id: int = team["role"]
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event): _on_team_panel_input(event, role_id))
		team_lists[team["role"]] = card.get_child(0)
		panel.add_child(card)
	return panel


func _build_lobby_footer() -> Control:
	var footer = HBoxContainer.new()
	footer.custom_minimum_size = _sv(0, 44)
	footer.add_theme_constant_override("separation", _s(16))

	footer.add_child(_key_action_hint("ESC", I18n.t("close") if lobby_chat_visible else I18n.t("back"), Callable(self, "_on_lobby_back_pressed")))
	footer.add_child(_key_action_hint("T", I18n.t("chat"), Callable(self, "_on_lobby_chat_toggle_pressed")))
	footer.add_child(_key_action_hint("X", I18n.t("leave_lobby"), Callable(self, "_on_lobby_leave_pressed")))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	start_button = _button(I18n.t("start_match"), true)
	start_button.custom_minimum_size = _sv(260, 42)
	start_button.disabled = not _can_manage_lobby()
	start_button.pressed.connect(func(): start_match_pressed.emit(_collect_lobby_config()))
	footer.add_child(start_button)
	return footer


func _build_lobby_chat_panel() -> void:
	chat_panel = PanelContainer.new()
	chat_panel.name = "LobbyChatPanel"
	chat_panel.visible = lobby_chat_visible
	chat_panel.add_theme_stylebox_override("panel", _styles["chat_panel"])
	chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var width := _responsive_width(0.43, 520, 880)
	chat_panel.offset_left = _s(44)
	chat_panel.offset_right = _s(44) + width
	chat_panel.offset_top = -_s(306)
	chat_panel.offset_bottom = -_s(58)
	add_child(chat_panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	chat_panel.add_child(box)

	var messages = ScrollContainer.new()
	messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(messages)

	chat_log_box = VBoxContainer.new()
	chat_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log_box.add_theme_constant_override("separation", _s(7))
	messages.add_child(chat_log_box)
	_refresh_lobby_chat_messages()

	var split = HSeparator.new()
	split.add_theme_color_override("separator", Color(0.420, 0.415, 0.455, 1))
	box.add_child(split)

	var input_row = HBoxContainer.new()
	input_row.custom_minimum_size = _sv(0, 58)
	input_row.add_theme_constant_override("separation", 0)
	box.add_child(input_row)

	var tab = PanelContainer.new()
	tab.custom_minimum_size = _sv(126, 58)
	tab.add_theme_stylebox_override("panel", _styles["chat_tab"])
	input_row.add_child(tab)

	var tab_label = _label(I18n.t("chat.scope_lobby"), 18, true)
	tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_label.add_theme_color_override("font_color", Color(0.070, 0.820, 0.720, 1))
	tab.add_child(tab_label)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = I18n.t("chat.placeholder")
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.add_theme_stylebox_override("normal", _styles["chat_input"])
	chat_input.add_theme_stylebox_override("focus", _styles["chat_input"])
	chat_input.add_theme_font_size_override("font_size", _s(19))
	chat_input.add_theme_color_override("font_color", Color.WHITE)
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.59, 1))
	if _use_brand_font() and _font_body:
		chat_input.add_theme_font_override("font", _font_body)
	chat_input.text_submitted.connect(func(_text): _send_lobby_chat_message())
	input_row.add_child(chat_input)


func _refresh_lobby_chat_messages() -> void:
	if not chat_log_box:
		return
	for child in chat_log_box.get_children():
		child.queue_free()
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log_box.add_child(spacer)
	for message in lobby_chat_messages:
		chat_log_box.add_child(_chat_message_row(str(message.get("nick", "Player")), str(message.get("text", ""))))


func _chat_message_row(nick: String, text: String) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(8))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_icon("res://addons/at-icons/control/human.svg", 22, "#12d1be"))
	var nick_label = _label(nick, 18, false)
	nick_label.add_theme_color_override("font_color", Color(0.070, 0.820, 0.720, 1))
	row.add_child(nick_label)
	var msg_label = _label(text, 18, false)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg_label)
	return row


func _set_lobby_chat_visible(value: bool, fade: bool = false) -> void:
	if value:
		_lobby_chat_fade_token += 1
		lobby_chat_fading = false
	if not value and fade and chat_panel and chat_panel.visible:
		_lobby_chat_fade_token += 1
		var fade_token := _lobby_chat_fade_token
		lobby_chat_visible = false
		lobby_chat_fading = true
		var tween := create_tween()
		tween.tween_property(chat_panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		if fade_token != _lobby_chat_fade_token or lobby_chat_visible:
			return
		lobby_chat_fading = false
		_build_ui()
		if lobby_visible:
			update_lobby(Network.players, Network.lobby_config)
		return
	lobby_chat_visible = value
	lobby_chat_fading = false
	_build_ui()
	if public_lobby_visible:
		update_public_lobby(public_lobby_rooms)
	elif lobby_visible:
		update_lobby(Network.players, Network.lobby_config)
	if lobby_chat_visible and chat_input:
		chat_input.grab_focus()


func _send_lobby_chat_message() -> void:
	if not chat_input:
		return
	var text := chat_input.text.strip_edges()
	if text.is_empty():
		return
	chat_input.clear()
	lobby_chat_message_sent.emit(text)


func add_lobby_chat_message(nick: String, text: String) -> void:
	var trimmed_text := text.strip_edges()
	if trimmed_text.is_empty():
		return
	lobby_chat_messages.append({
		"nick": nick,
		"text": trimmed_text,
	})
	while lobby_chat_messages.size() > 40:
		lobby_chat_messages.pop_front()
	_refresh_lobby_chat_messages()


func _local_player_nick() -> String:
	var local_id := _local_peer_id()
	if Network.players.has(local_id):
		return str(Network.players[local_id].get("nick", "Player"))
	var nick := get_nickname()
	return nick if not nick.is_empty() else "Player"


func _panel(title: String, icon_path: String = "") -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styles["panel"])
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", _s(7))
	panel.add_child(box)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", _s(8))
	box.add_child(title_row)
	if not icon_path.is_empty():
		title_row.add_child(_icon(icon_path, 19, "#ffffff"))
	var title_label = _label(title, 24, true)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_label)
	return panel


func _update_player_lists(players: Dictionary) -> void:
	for container in team_lists.values():
		var box = container as VBoxContainer
		for i in range(box.get_child_count() - 1, 0, -1):
			box.get_child(i).queue_free()

	var grouped := {
		TEAM_UNASSIGNED: [],
		TEAM_SPECTATOR: [],
		Network.Role.CHAMELEON: [],
		Network.Role.STALKER: [],
		Network.Role.HUNTER: [],
	}

	for pid in players.keys():
		var info = players[pid]
		var role = info.get("role", Network.Role.NONE)
		if role == Network.Role.NONE:
			grouped[TEAM_UNASSIGNED].append(pid)
		else:
			grouped[role].append(pid)

	for group in grouped.keys():
		var box = team_lists.get(group)
		if not box:
			continue
		var ids: Array = grouped[group]
		if ids.is_empty():
			box.add_child(_empty_slot(group))
			box.add_child(_empty_slot(group))
			box.add_child(_empty_slot(group))
			continue
		for pid in ids:
			box.add_child(_player_row(pid, players[pid], group))
		while box.get_child_count() < 4:
			box.add_child(_empty_slot(group))


func _player_row(pid: int, info: Dictionary, group: int) -> Control:
	var row = Button.new()
	_mark_select_click_button(row)
	var local_id := _local_peer_id()
	row.text = "%s" % info.get("nick", "Player")
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = _sv(0, 37)
	row.add_theme_stylebox_override("normal", _styles["slot_active"] if pid == local_id else _styles["slot"])
	row.add_theme_stylebox_override("hover", _styles["slot_active"])
	row.add_theme_color_override("font_color", Color(0.075, 0.070, 0.085) if pid == local_id else Color.WHITE)
	row.add_theme_color_override("font_hover_color", Color(0.075, 0.070, 0.085))
	_apply_control_font(row, _font_button, 18)
	# Crown the room host (lobby_config.host_peer_id) — works for both the private
	# listen-server host (peer 1) and a public-room host player.
	if pid == int(Network.lobby_config.get("host_peer_id", 0)):
		var crown := load("res://resources/ui/icons/host_crown.svg") as Texture2D
		if crown:
			row.icon = crown
			row.expand_icon = false
			row.add_theme_color_override("icon_normal_color", Color(1.0, 0.84, 0.26))
			row.add_theme_color_override("icon_hover_color", Color(0.075, 0.070, 0.085))
	row.pressed.connect(func():
		if group >= 0:
			_select_role_from_ui(group)
	)
	return row


func _empty_slot(group: int) -> Control:
	var row = Button.new()
	_mark_select_click_button(row)
	row.text = "---"
	row.custom_minimum_size = _sv(0, 36)
	row.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_stylebox_override("normal", _styles["slot"])
	row.add_theme_stylebox_override("hover", _styles["slot_focus"])
	row.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 1))
	_apply_control_font(row, _font_body, 18)
	row.disabled = group < 0
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if group >= 0 else Control.CURSOR_ARROW
	if group >= 0:
		row.pressed.connect(func(): _select_role_from_ui(group))
	return row


func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func _can_manage_lobby() -> bool:
	return is_host_lobby or Network.can_local_peer_manage_lobby()


func _on_team_panel_input(event: InputEvent, role: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_role_from_ui(role)


func _update_start_button(players: Dictionary) -> void:
	if players_hint_label:
		players_hint_label.text = I18n.t(Network.lobby_start_hint_key(players))
	if start_button:
		start_button.disabled = not _can_manage_lobby() or not Network.can_start_lobby_match(players)
		start_button.text = I18n.tf("start_match_count", [players.size(), int(Network.lobby_config.get("max_players", 24))])


func _update_config_controls(config: Dictionary) -> void:
	_set_option_by_value(map_option, str(config.get("map", "Warehouse")), 0)
	_set_option_by_value(variant_option, str(config.get("variant", "Default")), 0)
	_set_option_by_value(condition_option, str(config.get("condition", "Normal")), 0)
	_set_option_by_value(game_show_option, str(config.get("game_show", "None")), 0)
	_set_option_by_value(gravity_option, float(config.get("gravity_mps2", 9.8)), 1)
	_set_option_by_value(duration_option, int(config.get("match_duration_sec", 600)), 1)
	_set_option_by_value(prep_option, int(config.get("prep_duration_sec", 30)), 0)
	_set_option_by_value(hunter_count_option, int(config.get("host_hunter_count", -1)), 0)
	_set_option_by_value(stalker_glass_option, float(config.get("stalker_glass_alpha_max", 0.125)), 2)
	_set_option_by_value(stalker_glass_material_option, str(config.get("stalker_glass_material", "classic")), 0)
	_set_option_by_value(auto_turret_enabled_option, bool(config.get("hunter_auto_turret_enabled", false)), 0)
	_set_option_by_value(auto_turret_range_option, int(round(float(config.get("hunter_auto_turret_range", 34.0)))), 2)


func _collect_lobby_config() -> Dictionary:
	return {
		"lobby_id": current_lobby_id,
		"room_name": str(Network.lobby_config.get("room_name", get_room_name())),
		"map": _get_option_value(map_option, "Warehouse"),
		"variant": _get_option_value(variant_option, "Default"),
		"condition": _get_option_value(condition_option, "Normal"),
		"game_show": _get_option_value(game_show_option, "None"),
		"gravity_mps2": float(_get_option_value(gravity_option, 9.8)),
		"low_gravity_events": _get_option_value(game_show_option, "None") == "Chaos Show",
		"match_duration_sec": int(_get_option_value(duration_option, 600)),
		"prep_duration_sec": int(_get_option_value(prep_option, 30)),
		"host_hunter_count": int(_get_option_value(hunter_count_option, -1)),
		"stalker_glass_alpha_max": float(_get_option_value(stalker_glass_option, 0.125)),
		"stalker_glass_material": str(_get_option_value(stalker_glass_material_option, "classic")),
		"hunter_auto_turret_enabled": bool(_get_option_value(auto_turret_enabled_option, false)),
		"hunter_auto_turret_range": float(_get_option_value(auto_turret_range_option, 34)),
	}


func _on_config_changed() -> void:
	if lobby_visible and _can_manage_lobby():
		config_changed.emit(_collect_lobby_config())


func _on_host_pressed() -> void:
	_set_join_status("")
	_cancel_public_ip_lookup(true)
	host_pressed.emit(get_nickname(), get_skin(), selected_role, get_room_name(), get_lobby_password(), get_character_model())


func _on_public_server_pressed() -> void:
	if address_input:
		address_input.text = PUBLIC_SERVER_TARGET
	_set_join_status(I18n.t("join_status.connecting_public"), false)
	public_lobby_status_text = I18n.t("public_lobby.loading")
	public_lobby_status_error = false
	public_server_pressed.emit(get_nickname(), get_skin(), selected_role, get_character_model())


func _on_join_pressed() -> void:
	if not _validate_join_request():
		return
	_set_join_status(I18n.t("join_status.connecting"), false)
	join_pressed.emit(get_nickname(), get_skin(), get_address(), get_lobby_password(), selected_role, get_join_room_name(), get_character_model())


func _refresh_landing_join_state() -> void:
	if not join_status_label:
		return
	if get_join_target().is_empty() and get_lobby_password().is_empty():
		_set_join_status("")
	elif get_join_target().is_empty():
		_set_join_status(I18n.t("join_status.need_target"), true)
	else:
		var target: String = get_join_target()
		var key: String = "join_status.ready_noray" if Network.is_noray_join_target(target) else ("join_status.ready_address" if _looks_like_network_address(target) else "join_status.ready_room")
		_set_join_status(I18n.t(key), false)


func _refresh_steam_status() -> void:
	if not steam_status_label:
		return
	var text_key := "steam_status.ready" if SteamBridge.is_available() else "steam_status.offline"
	steam_status_label.text = I18n.t(text_key)
	steam_status_label.add_theme_color_override("font_color", Color(0.650, 0.820, 1.0, 1) if SteamBridge.is_available() else Color(0.78, 0.79, 0.84, 1))


func _on_steam_availability_changed(_available: bool, _message: String) -> void:
	_refresh_steam_status()


func _on_lobby_password_text_changed(text: String) -> void:
	var normalized := text.to_upper()
	if text != normalized and join_lobby_input:
		var caret := join_lobby_input.caret_column
		join_lobby_input.text = normalized
		join_lobby_input.caret_column = min(caret, normalized.length())
	_refresh_landing_join_state()


func _validate_join_request() -> bool:
	if get_join_target().is_empty():
		_set_join_status(I18n.t("join_status.need_target"), true)
		if address_input:
			address_input.grab_focus()
		return false
	return true


func show_join_status(text: String, is_error: bool = false) -> void:
	_set_join_status(text, is_error)


# Drive the create-private-server button's "connecting" state. Gives an immediate, obvious
# response to the click (the ~8s Noray attempt otherwise looked like nothing happened, which
# read as "the button does nothing") and blocks a duplicate attempt from a second click. The
# host flow re-enables it on success or failure.
func set_private_host_connecting(connecting: bool) -> void:
	if not host_button or not is_instance_valid(host_button):
		return
	host_button.disabled = connecting
	var key: String = "menu.creating_private_server" if connecting else "menu.create_private_server"
	host_button.text = I18n.t(key).to_upper()
	host_button.add_theme_color_override("font_disabled_color", Color(1.0, 0.860, 0.230, 0.55))


func _set_join_status(text: String, is_error: bool = false) -> void:
	if not join_status_label:
		return
	join_status_label.text = text
	join_status_label.visible = not text.is_empty()
	join_status_label.add_theme_color_override("font_color", Color(1.0, 0.590, 0.220, 1) if is_error else Color(0.760, 0.850, 1.0, 1))


func _looks_like_network_address(value: String) -> bool:
	var target := value.strip_edges().to_lower()
	if target.is_empty():
		return false
	if target == "localhost" or target == "127.0.0.1" or target == "::1":
		return true
	return target.contains(".") or target.contains(":")


func _select_role(role: int) -> void:
	selected_role = role
	_update_role_buttons(landing_role_buttons)
	_update_role_buttons(lobby_role_buttons)
	if lobby_visible:
		Network.request_set_role(role)


func _select_role_from_ui(role: int) -> void:
	_play_ui_select_sound()
	_select_role(role)


func _update_role_buttons(buttons: Array[Button]) -> void:
	for i in range(buttons.size()):
		var role_for_btn = [Network.Role.CHAMELEON, Network.Role.STALKER, Network.Role.HUNTER][i]
		buttons[i].button_pressed = role_for_btn == selected_role


func _role_data() -> Array:
	return [
		{"role": Network.Role.CHAMELEON, "label": I18n.t("role.chameleon")},
		{"role": Network.Role.STALKER, "label": I18n.t("role.stalker")},
		{"role": Network.Role.HUNTER, "label": I18n.t("role.hunter")},
	]


func _field_row(label_text: String, field: Control) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(12))
	var label = _label(label_text, 22, true)
	label.custom_minimum_size = _sv(150, 0)
	row.add_child(label)
	row.add_child(field)
	return row


func _option_group(label_text: String, option: OptionButton) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", _s(3))
	box.add_child(_section_label(label_text))
	box.add_child(option)
	return box


func _option(items: Array, group: String) -> OptionButton:
	var option = _option_button()
	for item in items:
		option.add_item(I18n.option_text(group, item))
		option.set_item_metadata(option.item_count - 1, item)
	_refresh_option_popup_checks(option)
	option.item_selected.connect(func(_idx):
		_play_ui_select_sound()
		_refresh_option_popup_checks(option)
		_on_config_changed()
	)
	return option


func _option_button() -> OptionButton:
	var option = OptionButton.new()
	option.custom_minimum_size = _sv(0, 36)
	option.add_theme_stylebox_override("normal", _styles["field"])
	option.add_theme_stylebox_override("hover", _styles["field_hover"])
	option.add_theme_stylebox_override("pressed", _styles["field_focus"])
	option.add_theme_stylebox_override("focus", _styles["field_focus"])
	option.add_theme_font_size_override("font_size", _s(17))
	option.add_theme_color_override("font_color", Color.WHITE)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_pressed_color", Color.WHITE)
	option.add_theme_color_override("icon_normal_color", Color(0.88, 0.90, 0.94, 1))
	option.add_theme_color_override("icon_hover_color", Color.WHITE)
	option.add_theme_color_override("icon_pressed_color", Color.WHITE)
	option.add_theme_icon_override("arrow", _icon_texture("res://assets/ui/chevron_down.svg", "#f3f5fb", _s(17)))
	option.add_theme_constant_override("arrow_margin", _s(16))
	if _use_brand_font() and _font_body:
		option.add_theme_font_override("font", _font_body)
	_configure_option_popup(option)
	return option


func _character_option() -> OptionButton:
	var option := _option_button()
	for model in CharacterSkinCatalog.all():
		var label_key := str(model.get("label_key", ""))
		var translated := I18n.t(label_key)
		var label := translated if translated != label_key else str(model.get("label", ""))
		option.add_item(label)
		option.set_item_metadata(option.item_count - 1, model.get("id", CharacterSkinCatalog.DEFAULT_ID))
		if model.get("id", CharacterSkinCatalog.DEFAULT_ID) == CharacterSkinCatalog.DEFAULT_ID:
			option.select(option.item_count - 1)
	_refresh_option_popup_checks(option)
	option.item_selected.connect(func(_idx):
		_play_ui_select_sound()
		_refresh_option_popup_checks(option)
	)
	return option


func _configure_option_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	popup.add_theme_stylebox_override("panel", _styles["popup_panel"])
	popup.add_theme_stylebox_override("hover", _styles["popup_hover"])
	popup.add_theme_font_size_override("font_size", _s(20))
	popup.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 1))
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.52, 0.53, 0.58, 1))
	popup.add_theme_color_override("font_separator_color", Color(0.48, 0.50, 0.56, 1))
	popup.add_theme_constant_override("v_separation", _s(8))
	popup.add_theme_constant_override("item_start_padding", _s(22))
	popup.add_theme_constant_override("item_end_padding", _s(52))
	popup.add_theme_icon_override("checked", _icon_texture("res://addons/at-icons/control/checkmark.svg", "#ffc529", _s(28)))
	popup.add_theme_icon_override("radio_checked", _icon_texture("res://addons/at-icons/control/checkmark.svg", "#ffc529", _s(28)))
	if _use_brand_font() and _font_body:
		popup.add_theme_font_override("font", _font_body)
	popup.about_to_popup.connect(func():
		_refresh_option_popup_checks(option)
		call_deferred("_fit_option_popup_to_button", option)
	)


func _fit_option_popup_to_button(option: OptionButton) -> void:
	if not is_instance_valid(option):
		return
	var popup := option.get_popup()
	if not is_instance_valid(popup):
		return
	var width := roundi(option.size.x)
	if width <= 0:
		width = roundi(option.custom_minimum_size.x)
	if width <= 0:
		return
	popup.size = Vector2i(width, popup.size.y)


func _refresh_option_popup_checks(option: OptionButton) -> void:
	var popup := option.get_popup()
	for i in range(popup.item_count):
		popup.set_item_as_checkable(i, true)
		popup.set_item_checked(i, i == option.selected)


func _set_option_by_value(option: OptionButton, value, fallback_index: int) -> void:
	if not option:
		return
	for i in range(option.item_count):
		if str(option.get_item_metadata(i)) == str(value):
			option.select(i)
			return
	option.select(clamp(fallback_index, 0, option.item_count - 1))


func _get_option_value(option: OptionButton, fallback):
	if not option or option.selected < 0:
		return fallback
	return option.get_item_metadata(option.selected)


func _set_config_enabled(enabled: bool) -> void:
	var options = [map_option, variant_option, condition_option, game_show_option, gravity_option, duration_option, prep_option, hunter_count_option, stalker_glass_option, stalker_glass_material_option, auto_turret_enabled_option, auto_turret_range_option]
	for option in options:
		if option:
			option.disabled = not enabled


func _line_edit(placeholder: String) -> LineEdit:
	var field = LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = _sv(0, 38)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_stylebox_override("normal", _styles["field"])
	# Override the focus + read-only styleboxes too, otherwise Godot draws its default
	# square focus outline outside our rounded box when the field is focused.
	field.add_theme_stylebox_override("focus", _styles["field_focus"])
	field.add_theme_stylebox_override("read_only", _styles["field"])
	field.add_theme_font_size_override("font_size", _s(17))
	field.add_theme_color_override("font_color", Color.WHITE)
	field.add_theme_color_override("caret_color", Color(0.78, 0.88, 1.0, 1))
	field.add_theme_color_override("font_placeholder_color", Color(0.72, 0.72, 0.76, 1))
	if _use_brand_font() and _font_body:
		field.add_theme_font_override("font", _font_body)
	return field


func _button(text: String, primary: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = _sv(150, 44)
	btn.add_theme_stylebox_override("normal", _styles["button"] if primary else _styles["button_dark"])
	btn.add_theme_stylebox_override("hover", _styles["button_hover"] if primary else _styles["button_dark_hover"])
	btn.add_theme_stylebox_override("pressed", _styles["button_hover"] if primary else _styles["button_dark_hover"])
	btn.add_theme_stylebox_override("disabled", _styles["button_disabled"] if primary else _styles["button_dark"])
	btn.add_theme_font_size_override("font_size", _s(20))
	btn.add_theme_color_override("font_color", Color(0.05, 0.045, 0.055, 1) if primary else Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.58, 0.52, 0.45, 1))
	if _use_brand_font() and _font_button:
		btn.add_theme_font_override("font", _font_button)
	return btn


func _icon_button(path: String) -> Button:
	var btn = _button("", false)
	btn.custom_minimum_size = _sv(42, 42)
	btn.icon = _icon_texture(path, "#ffffff", _s(24))
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	return btn


func _icon(path: String, icon_size: int, color_hex: String) -> TextureRect:
	var icon = TextureRect.new()
	var scaled_size: int = _s(icon_size)
	icon.texture = _icon_texture(path, color_hex, scaled_size)
	icon.custom_minimum_size = Vector2(scaled_size, scaled_size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _icon_texture(path: String, color_hex: String, icon_size: int) -> Texture2D:
	var key := "%s:%s:%s" % [path, color_hex, icon_size]
	if _icon_cache.has(key):
		return _icon_cache[key]

	var texture: Texture2D
	var svg := FileAccess.get_file_as_string(path)
	if not svg.is_empty():
		svg = svg.replace("#8eef97", color_hex)
		var image := Image.new()
		var svg_scale: float = maxf(1.0, float(icon_size) / 16.0)
		if image.load_svg_from_buffer(svg.to_utf8_buffer(), svg_scale) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		texture = load(path)

	_icon_cache[key] = texture
	return texture


func _label(text: String, font_size: int, bold: bool) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _s(font_size))
	label.add_theme_color_override("font_color", Color.WHITE)
	if _use_brand_font():
		var font = _font_heading if bold else _font_body
		if font:
			label.add_theme_font_override("font", font)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
		label.add_theme_constant_override("shadow_offset_x", _s(1))
		label.add_theme_constant_override("shadow_offset_y", _s(1))
	return label


func _section_label(text: String) -> Label:
	var label = _label(text, 18, true)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1))
	return label


func _muted_label(text: String, font_size: int) -> Label:
	var label = _label(text, font_size, false)
	label.add_theme_color_override("font_color", Color(0.78, 0.79, 0.84, 1))
	return label


func _thin_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.custom_minimum_size = _sv(0, 8)
	return sep


func _key_hint(key: String, label: String) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(7))
	var key_label = _label(key, 15, true)
	key_label.custom_minimum_size = _sv(36 if key.length() <= 1 else 52, 28)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_stylebox_override("normal", _styles["key"])
	key_label.add_theme_color_override("font_color", Color(0.365, 0.385, 0.430, 1))
	row.add_child(key_label)
	var action_label = _label(label, 16, true)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(action_label)
	return row


func _key_action_hint(key: String, label: String, action: Callable) -> Control:
	var row := _key_hint(key, label)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_play_ui_click_sound()
			action.call()
			accept_event()
	)
	return row


func _on_lobby_chat_toggle_pressed() -> void:
	_set_lobby_chat_visible(not lobby_chat_visible)
	accept_event()


func _on_lobby_back_pressed() -> void:
	if lobby_chat_visible:
		_set_lobby_chat_visible(false, true)
	else:
		lobby_back_pressed.emit()
	accept_event()


func _on_lobby_leave_pressed() -> void:
	lobby_leave_pressed.emit()
	accept_event()


func _apply_control_font(control: Control, font: Font, font_size: int) -> void:
	control.add_theme_font_size_override("font_size", _s(font_size))
	if _use_brand_font() and font:
		control.add_theme_font_override("font", font)


func _on_locale_changed(_locale: String) -> void:
	var was_lobby := lobby_visible
	var was_public_lobby := public_lobby_visible
	var host_mode := is_host_lobby
	var lobby_id := current_lobby_id
	lobby_visible = was_lobby
	public_lobby_visible = was_public_lobby
	is_host_lobby = host_mode
	current_lobby_id = lobby_id
	_build_ui()
	_select_role(selected_role)
	if was_public_lobby:
		update_public_lobby(public_lobby_rooms)
	elif was_lobby:
		update_lobby(Network.players, Network.lobby_config)
