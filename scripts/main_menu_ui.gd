extends Control
class_name MainMenuUI

signal host_pressed(nickname: String, skin: String, role: int)
signal join_pressed(nickname: String, skin: String, address: String, lobby_id: String, role: int)
signal quit_pressed
signal start_match_pressed(config: Dictionary)
signal auto_assign_pressed(config: Dictionary)
signal config_changed(config: Dictionary)
signal lobby_chat_message_sent(message_text: String)

const TEAM_UNASSIGNED := -1
const TEAM_SPECTATOR := 3

var selected_role: int = Network.Role.CHAMELEON
var lobby_visible := false
var current_lobby_id := "----"
var is_host_lobby := false
var lobby_chat_visible := false
var lobby_chat_messages: Array[Dictionary] = []

var nick_input: LineEdit
var skin_input: LineEdit
var address_input: LineEdit
var join_lobby_input: LineEdit
var language_option: OptionButton
var landing_role_buttons: Array[Button] = []

var lobby_id_input: LineEdit
var players_hint_label: Label
var map_option: OptionButton
var variant_option: OptionButton
var condition_option: OptionButton
var game_show_option: OptionButton
var duration_option: OptionButton
var prep_option: OptionButton
var hunter_count_option: OptionButton
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
var _icon_cache: Dictionary = {}
var _layout_bucket := Vector2i.ZERO


func _ready() -> void:
	_fit_to_viewport()
	_load_fonts()
	_build_styles()
	I18n.locale_changed.connect(_on_locale_changed)
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
	if not lobby_visible or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and lobby_chat_visible:
			_set_lobby_chat_visible(false)
			accept_event()
		elif event.keycode == KEY_ENTER:
			if lobby_chat_visible and chat_input and chat_input.has_focus():
				_send_lobby_chat_message()
			else:
				_set_lobby_chat_visible(true)
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
	if lobby_visible:
		update_lobby(Network.players, Network.lobby_config)


func _ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var scale = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	return clamp(scale, 0.78, 1.35)


func _s(value: float) -> int:
	return max(1, roundi(value * _ui_scale()))


func _sv(x: float, y: float) -> Vector2:
	return Vector2(_s(x), _s(y))


func _responsive_width(ratio: float, min_width: float, max_width: float) -> int:
	var viewport_width := get_viewport_rect().size.x
	return clampi(roundi(viewport_width * ratio), _s(min_width), _s(max_width))


func show_menu() -> void:
	show()


func hide_menu() -> void:
	hide()


func is_menu_visible() -> bool:
	return visible


func show_landing() -> void:
	lobby_visible = false
	_build_ui()


func show_lobby(lobby_id: String, host_mode: bool) -> void:
	lobby_visible = true
	current_lobby_id = lobby_id
	is_host_lobby = host_mode
	_build_ui()
	update_lobby(Network.players, Network.lobby_config)


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
	return nick_input.text.strip_edges() if nick_input else ""


func get_skin() -> String:
	return skin_input.text.strip_edges().to_lower() if skin_input else ""


func get_address() -> String:
	return address_input.text.strip_edges() if address_input else ""


func _load_fonts() -> void:
	_font_heading = _load_font("res://assets/fonts/Saira-9.woff2")
	_font_body = _load_font("res://assets/fonts/SairaCondensed-Medium.woff2")
	_font_button = _load_font("res://assets/fonts/SairaCondensed-Bold.woff2")


func _load_font(path: String) -> Font:
	var resource = load(path)
	return resource if resource is Font else null


func _use_brand_font() -> bool:
	return I18n.current_locale != "zh"


func _build_styles() -> void:
	_styles.clear()
	_styles["panel"] = _style(Color(0.205, 0.222, 0.270, 0.96), Color(0.205, 0.222, 0.270, 0.96), 1, 8)
	_styles["panel_dark"] = _style(Color(0.090, 0.080, 0.100, 0.98), Color(0.090, 0.080, 0.100, 0.98), 1, 8)
	_styles["slot"] = _style(Color(0.335, 0.355, 0.405, 0.96), Color(0.260, 0.275, 0.320, 1), 1, 6)
	_styles["slot_active"] = _style(Color(0.960, 0.970, 0.990, 1), Color(0.575, 0.760, 1.0, 1), 1, 7)
	_styles["slot_focus"] = _style(Color(0.320, 0.340, 0.390, 0.98), Color(0.520, 0.720, 1.0, 1), 2, 7)
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
	for child in get_children():
		child.queue_free()
	landing_role_buttons.clear()
	lobby_role_buttons.clear()
	user_rows.clear()
	team_lists.clear()

	_build_stage_background()

	if lobby_visible:
		_build_lobby_ui()
	else:
		_build_landing_ui()
	_build_language_bar()


func _build_stage_background() -> void:
	var base = ColorRect.new()
	base.color = Color(0.500, 0.560, 0.630, 1)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	var wash = ColorRect.new()
	wash.color = Color(0.430, 0.480, 0.550, 0.35)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.offset_top = _s(92)
	add_child(wash)


func _build_language_bar() -> void:
	var bar = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -_s(340)
	bar.offset_top = _s(8)
	bar.offset_right = -_s(18)
	bar.offset_bottom = _s(42)
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", _s(10))
	add_child(bar)

	var label = _label(I18n.t("language"), 14, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)

	language_option = _option_button()
	language_option.custom_minimum_size = _sv(170, 32)
	language_option.add_theme_stylebox_override("normal", _styles["language"])
	language_option.add_theme_stylebox_override("hover", _styles["field_hover"])
	language_option.add_theme_font_size_override("font_size", _s(14))
	for choice in I18n.get_language_choices():
		language_option.add_item(choice["label"])
		language_option.set_item_metadata(language_option.item_count - 1, choice["value"])
		if choice["value"] == I18n.language_setting:
			language_option.select(language_option.item_count - 1)
	_refresh_option_popup_checks(language_option)
	language_option.item_selected.connect(func(index):
		_refresh_option_popup_checks(language_option)
		I18n.set_language_setting(str(language_option.get_item_metadata(index)))
	)
	bar.add_child(language_option)


func _build_landing_ui() -> void:
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = _sv(720, 560)
	center.offset_left = -_s(360)
	center.offset_top = -_s(280)
	center.offset_right = _s(360)
	center.offset_bottom = _s(280)
	center.add_theme_constant_override("separation", _s(14))
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var title = _label(I18n.t("app.title"), 74, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(title)

	var subtitle = _label(I18n.t("app.subtitle"), 30, true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.76, 0.13, 1))
	center.add_child(subtitle)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _styles["panel"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(card)

	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", _s(10))
	card.add_child(form)

	nick_input = _line_edit(I18n.t("placeholder.nick"))
	skin_input = _line_edit(I18n.t("placeholder.skin"))
	address_input = _line_edit(I18n.t("placeholder.ip"))
	join_lobby_input = _line_edit(I18n.t("placeholder.lobby"))
	form.add_child(_field_row(I18n.t("nickname"), nick_input))
	form.add_child(_field_row(I18n.t("skin"), skin_input))
	form.add_child(_field_row(I18n.t("server_ip"), address_input))
	form.add_child(_field_row(I18n.t("lobby_id"), join_lobby_input))

	var roles = HBoxContainer.new()
	roles.add_theme_constant_override("separation", _s(10))
	roles.alignment = BoxContainer.ALIGNMENT_CENTER
	for data in _role_data():
		var btn = _button(data["label"], false)
		btn.toggle_mode = true
		btn.custom_minimum_size = _sv(180, 44)
		var role_id: int = data["role"]
		btn.pressed.connect(func(): _select_role(role_id))
		roles.add_child(btn)
		landing_role_buttons.append(btn)
	form.add_child(roles)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", _s(12))
	form.add_child(buttons)

	var host = _button(I18n.t("host_lobby"), true)
	host.custom_minimum_size = _sv(180, 52)
	host.pressed.connect(_on_host_pressed)
	buttons.add_child(host)

	var join = _button(I18n.t("join_lobby"), false)
	join.custom_minimum_size = _sv(180, 52)
	join.pressed.connect(_on_join_pressed)
	buttons.add_child(join)

	var quit = _button(I18n.t("quit"), false)
	quit.custom_minimum_size = _sv(120, 52)
	quit.pressed.connect(func(): quit_pressed.emit())
	buttons.add_child(quit)
	_update_role_buttons(landing_role_buttons)


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

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", _s(12))
	main.add_child(columns)

	columns.add_child(_build_match_details_panel())
	columns.add_child(_build_users_panel())
	columns.add_child(_build_teams_panel())

	main.add_child(_build_lobby_footer())
	_build_lobby_chat_panel()


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

	players_hint_label = _muted_label(I18n.t("players_needed"), 16)
	box.add_child(players_hint_label)
	box.add_child(_thin_separator())

	map_option = _option(["Warehouse", "Street Block", "Training Yard"], "map")
	variant_option = _option(["Default", "Low Ammo", "Fast Hunt"], "variant")
	condition_option = _option(["Normal", "Rain", "Night"], "condition")
	game_show_option = _option(["None", "Airdrop Show", "Chaos Show"], "game_show")
	duration_option = _option([300, 600, 900], "duration")
	prep_option = _option([30, 60, 120], "prep")
	hunter_count_option = _option([-1, 1, 2, 3, 4, 5, 6, 7, 8], "hunters")

	box.add_child(_option_group(I18n.t("level"), map_option))
	box.add_child(_option_group(I18n.t("variant"), variant_option))
	box.add_child(_option_group(I18n.t("condition"), condition_option))
	box.add_child(_option_group(I18n.t("game_show"), game_show_option))
	box.add_child(_option_group(I18n.t("duration"), duration_option))
	box.add_child(_option_group(I18n.t("hunter_count"), hunter_count_option))
	box.add_child(_option_group(I18n.t("hide_prep"), prep_option))

	auto_assign_button = _button(I18n.t("auto_assign"), false)
	auto_assign_button.disabled = not is_host_lobby
	auto_assign_button.pressed.connect(func(): auto_assign_pressed.emit(_collect_lobby_config()))
	box.add_child(auto_assign_button)

	var roles = VBoxContainer.new()
	roles.add_theme_constant_override("separation", _s(8))
	roles.add_child(_section_label(I18n.t("choose_side")))
	for data in _role_data():
		var btn = _button(data["label"], false)
		btn.toggle_mode = true
		btn.custom_minimum_size = _sv(0, 42)
		var role_id: int = data["role"]
		btn.pressed.connect(func(): _select_role(role_id))
		roles.add_child(btn)
		lobby_role_buttons.append(btn)
	box.add_child(roles)
	_set_config_enabled(is_host_lobby)
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

	footer.add_child(_key_hint("ESC", I18n.t("close") if lobby_chat_visible else I18n.t("back")))
	var chat_hint = _key_hint("ENTER", I18n.t("chat"))
	chat_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chat_hint.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_lobby_chat_visible(true)
	)
	footer.add_child(chat_hint)
	footer.add_child(_key_hint("C", I18n.t("manage_lobby")))
	footer.add_child(_key_hint("X", I18n.t("leave_lobby")))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	start_button = _button(I18n.t("start_match"), true)
	start_button.custom_minimum_size = _sv(260, 42)
	start_button.disabled = not is_host_lobby
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


func _set_lobby_chat_visible(value: bool) -> void:
	lobby_chat_visible = value
	_build_ui()
	if lobby_visible:
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
	var local_id := _local_peer_id()
	row.text = "%s" % info.get("nick", "Player")
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = _sv(0, 37)
	row.add_theme_stylebox_override("normal", _styles["slot_active"] if pid == local_id else _styles["slot"])
	row.add_theme_stylebox_override("hover", _styles["slot_active"])
	row.add_theme_color_override("font_color", Color(0.075, 0.070, 0.085) if pid == local_id else Color.WHITE)
	row.add_theme_color_override("font_hover_color", Color(0.075, 0.070, 0.085))
	_apply_control_font(row, _font_button, 18)
	row.pressed.connect(func():
		if group >= 0:
			_select_role(group)
	)
	return row


func _empty_slot(group: int) -> Control:
	var row = Button.new()
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
		row.pressed.connect(func(): _select_role(group))
	return row


func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func _on_team_panel_input(event: InputEvent, role: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_role(role)


func _update_start_button(players: Dictionary) -> void:
	if players_hint_label:
		players_hint_label.text = I18n.t("players_needed") if players.size() < 2 else I18n.t("teams_ready")
	if start_button:
		var assigned = Network.get_hunters().size() > 0 and Network.get_props().size() > 0
		start_button.disabled = not is_host_lobby or players.size() < 2 or not assigned
		start_button.text = I18n.tf("start_match_count", [players.size(), int(Network.lobby_config.get("max_players", 24))])


func _update_config_controls(config: Dictionary) -> void:
	_set_option_by_value(map_option, str(config.get("map", "Warehouse")), 0)
	_set_option_by_value(variant_option, str(config.get("variant", "Default")), 0)
	_set_option_by_value(condition_option, str(config.get("condition", "Normal")), 0)
	_set_option_by_value(game_show_option, str(config.get("game_show", "None")), 0)
	_set_option_by_value(duration_option, int(config.get("match_duration_sec", 600)), 1)
	_set_option_by_value(prep_option, int(config.get("prep_duration_sec", 120)), 2)
	_set_option_by_value(hunter_count_option, int(config.get("host_hunter_count", -1)), 0)


func _collect_lobby_config() -> Dictionary:
	return {
		"lobby_id": current_lobby_id,
		"map": _get_option_value(map_option, "Warehouse"),
		"variant": _get_option_value(variant_option, "Default"),
		"condition": _get_option_value(condition_option, "Normal"),
		"game_show": _get_option_value(game_show_option, "None"),
		"match_duration_sec": int(_get_option_value(duration_option, 600)),
		"prep_duration_sec": int(_get_option_value(prep_option, 120)),
		"host_hunter_count": int(_get_option_value(hunter_count_option, -1)),
	}


func _on_config_changed() -> void:
	if lobby_visible:
		config_changed.emit(_collect_lobby_config())


func _on_host_pressed() -> void:
	host_pressed.emit(get_nickname(), get_skin(), selected_role)


func _on_join_pressed() -> void:
	join_pressed.emit(get_nickname(), get_skin(), get_address(), join_lobby_input.text.strip_edges(), selected_role)


func _select_role(role: int) -> void:
	selected_role = role
	_update_role_buttons(landing_role_buttons)
	_update_role_buttons(lobby_role_buttons)
	if lobby_visible:
		Network.request_set_role(role)


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


func _field_row(label_text: String, field: LineEdit) -> Control:
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
	var options = [map_option, variant_option, condition_option, game_show_option, duration_option, prep_option, hunter_count_option]
	for option in options:
		if option:
			option.disabled = not enabled


func _line_edit(placeholder: String) -> LineEdit:
	var field = LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = _sv(0, 38)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_stylebox_override("normal", _styles["field"])
	field.add_theme_font_size_override("font_size", _s(17))
	field.add_theme_color_override("font_color", Color.WHITE)
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


func _icon(path: String, size: int, color_hex: String) -> TextureRect:
	var icon = TextureRect.new()
	var scaled_size := _s(size)
	icon.texture = _icon_texture(path, color_hex, scaled_size)
	icon.custom_minimum_size = Vector2(scaled_size, scaled_size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _icon_texture(path: String, color_hex: String, size: int) -> Texture2D:
	var key := "%s:%s:%s" % [path, color_hex, size]
	if _icon_cache.has(key):
		return _icon_cache[key]

	var texture: Texture2D
	var svg := FileAccess.get_file_as_string(path)
	if not svg.is_empty():
		svg = svg.replace("#8eef97", color_hex)
		var image := Image.new()
		var scale = max(1.0, float(size) / 16.0)
		if image.load_svg_from_buffer(svg.to_utf8_buffer(), scale) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		texture = load(path)

	_icon_cache[key] = texture
	return texture


func _label(text: String, size: int, bold: bool) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _s(size))
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


func _muted_label(text: String, size: int) -> Label:
	var label = _label(text, size, false)
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


func _apply_control_font(control: Control, font: Font, size: int) -> void:
	control.add_theme_font_size_override("font_size", _s(size))
	if _use_brand_font() and font:
		control.add_theme_font_override("font", font)


func _on_locale_changed(_locale: String) -> void:
	var was_lobby := lobby_visible
	var host_mode := is_host_lobby
	var lobby_id := current_lobby_id
	lobby_visible = was_lobby
	is_host_lobby = host_mode
	current_lobby_id = lobby_id
	_build_ui()
	_select_role(selected_role)
	if was_lobby:
		update_lobby(Network.players, Network.lobby_config)
