extends Control
class_name PrivateServerBrowser

## LAN "Private Server" browser, styled to match the skin-config page (warm gradient,
## rounded glass cards, Saira type, soft shadows). Hosts a Create-Room form and a live
## list of rooms discovered on the local network (room name / host / players / lock).
## Double-clicking a room joins it. Pure peer-to-peer — no VPS, no Noray.

signal create_requested(room_name: String, password: String)
signal join_requested(room: Dictionary, password: String)
signal back_requested()

const TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const BODY_FONT_PATH := "res://assets/fonts/SairaCondensed-Medium.woff2"
const LOCK_ICON_PATH := "res://assets/ui/skills/locked.png"

const BG_TOP := Color(0.99, 0.69, 0.27, 1.0)
const BG_BOTTOM := Color(0.93, 0.51, 0.17, 1.0)
const GLOW_INNER := Color(1.0, 0.86, 0.58, 0.5)
const GLOW_OUTER := Color(1.0, 0.78, 0.40, 0.0)
const CARD_BG := Color(0.10, 0.07, 0.05, 0.46)
const CARD_SELECTED := Color(0.16, 0.10, 0.06, 0.66)
const ACCENT := Color(1.0, 0.78, 0.32, 1.0)
const GOLD := Color(0.97, 0.66, 0.20, 1.0)
const TEXT := Color(1.0, 0.99, 0.96, 1.0)
const TEXT_DIM := Color(1.0, 0.88, 0.66, 0.78)

var _title_font: Font = null
var _body_font: Font = null
var _lock_texture: Texture2D = null

var _name_input: LineEdit = null
var _password_input: LineEdit = null
var _create_button: Button = null
var _room_list_box: VBoxContainer = null
var _empty_label: Label = null
var _spinner: TextureRect = null
var _status_label: Label = null
var _count_label: Label = null

var _discovery: Node = null
var _rooms: Array = []
var _selected_uid := ""
var _elapsed := 0.0

# Inline password modal (for locked rooms).
var _modal: Control = null
var _modal_title: Label = null
var _modal_password: LineEdit = null
var _modal_room: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_parent()
	_title_font = _load_font(TITLE_FONT_PATH)
	_body_font = _load_font(BODY_FONT_PATH)
	var lock_res := load(LOCK_ICON_PATH)
	_lock_texture = lock_res if lock_res is Texture2D else null
	_discovery = preload("res://scripts/network/lan_room_discovery.gd").new()
	_discovery.name = "BrowseDiscovery"
	add_child(_discovery)
	_discovery.rooms_updated.connect(_on_rooms_updated)
	_build_ui()
	visible = false
	set_process(false)
	if I18n and not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		_fit_to_parent()


func _fit_to_parent() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Public API --------------------------------------------------------------

func open() -> void:
	visible = true
	set_process(true)
	if _name_input:
		_name_input.text = ""
	if _password_input:
		_password_input.text = ""
	_selected_uid = ""
	_update_create_enabled()
	set_status("", false)
	_render_rooms([])
	_close_modal()
	_discovery.start_browsing()


func close() -> void:
	visible = false
	set_process(false)
	if _discovery:
		_discovery.stop_browsing()


func set_status(text: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 1.0) if is_error else TEXT_DIM)


func populate_rooms_for_test(rooms: Array) -> void:
	_render_rooms(rooms)


func get_room_count_for_test() -> int:
	return _rooms.size()


# --- Discovery feed ----------------------------------------------------------

func _on_rooms_updated(rooms: Array) -> void:
	_render_rooms(rooms)


func _process(delta: float) -> void:
	_elapsed += delta
	if _spinner and _spinner.visible:
		_spinner.rotation += delta * 6.0


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	# Solid base guarantees the warm fill even if the gradient texture fails to draw.
	var base := ColorRect.new()
	base.name = "BaseFill"
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = BG_BOTTOM
	add_child(base)

	var bg := TextureRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = _vertical_gradient(BG_TOP, BG_BOTTOM)
	add_child(bg)

	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture = _radial_gradient(GLOW_INNER, GLOW_OUTER)
	add_child(glow)

	var center := CenterContainer.new()
	center.name = "Content"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1140.0, 0.0)
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_body())

	_build_status_bar()
	_build_modal()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0.0, 70.0)

	row.add_child(_make_back_button())

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	var title := _label("PRIVATE SERVER", 44, TEXT, _title_font)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.55, 0.2, 0.04, 0.8))
	titles.add_child(title)
	titles.add_child(_label(_subtitle_text(), 17, TEXT_DIM, _body_font))
	row.add_child(titles)

	var status_box := HBoxContainer.new()
	status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_box.add_theme_constant_override("separation", 8)
	_spinner = TextureRect.new()
	_spinner.custom_minimum_size = Vector2(22.0, 22.0)
	_spinner.size = Vector2(22.0, 22.0)
	_spinner.pivot_offset = Vector2(11.0, 11.0)
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.stretch_mode = TextureRect.STRETCH_SCALE
	_spinner.texture = _spinner_texture()
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(_spinner)
	_count_label = _label("", 16, TEXT_DIM, _body_font)
	status_box.add_child(_count_label)
	row.add_child(status_box)
	return row


func _build_body() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0.0, 470.0)

	# Left: create panel
	var create_card := _card(true)
	create_card.custom_minimum_size = Vector2(380.0, 0.0)
	var create_col := VBoxContainer.new()
	create_col.add_theme_constant_override("separation", 12)
	create_card.add_child(create_col)
	create_col.add_child(_section_label("CREATE ROOM"))

	_name_input = _line_edit(_placeholder_name(), false)
	_name_input.max_length = 32
	_name_input.text_changed.connect(func(_text): _update_create_enabled())
	create_col.add_child(_name_input)

	_password_input = _line_edit(_placeholder_password(), true)
	_password_input.max_length = 16
	create_col.add_child(_password_input)

	_create_button = _button(_create_label(), true)
	_create_button.pressed.connect(_on_create_pressed)
	create_col.add_child(_create_button)

	create_col.add_child(_label(_create_hint(), 13, TEXT_DIM, _body_font))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_col.add_child(spacer)
	row.add_child(create_card)

	# Right: room list
	var list_card := _card(false)
	list_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 10)
	list_card.add_child(list_col)
	list_col.add_child(_section_label("ROOMS ON YOUR NETWORK"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_col.add_child(scroll)

	_room_list_box = VBoxContainer.new()
	_room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_room_list_box)

	_empty_label = _label(_searching_text(), 17, TEXT_DIM, _body_font)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(0.0, 120.0)
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_room_list_box.add_child(_empty_label)

	row.add_child(list_card)
	return row


func _make_back_button() -> Button:
	var back := Button.new()
	back.name = "BackButton"
	back.text = "‹"
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.custom_minimum_size = Vector2(62.0, 62.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", _title_font if _title_font else ThemeDB.fallback_font)
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.32, 0.45, 0.78, 1.0))
	back.add_theme_stylebox_override("normal", _round_style(Color(0.98, 0.96, 0.90, 0.94), 16, Color(0, 0, 0, 0), 0))
	back.add_theme_stylebox_override("hover", _round_style(Color(1.0, 0.99, 0.95, 1.0), 16, Color(0, 0, 0, 0), 0))
	back.add_theme_stylebox_override("pressed", _round_style(Color(0.95, 0.93, 0.86, 1.0), 16, Color(0, 0, 0, 0), 0))
	back.pressed.connect(func(): back_requested.emit())
	return back


func _build_status_bar() -> void:
	_status_label = _label("", 16, TEXT_DIM, _body_font)
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.offset_top = -52.0
	_status_label.offset_bottom = -24.0
	add_child(_status_label)


# --- Room list rendering -----------------------------------------------------

func _render_rooms(rooms: Array) -> void:
	_rooms = rooms.duplicate(true)
	if _room_list_box == null:
		return
	for child in _room_list_box.get_children():
		if child != _empty_label:
			child.queue_free()
	var has_rooms := not _rooms.is_empty()
	if _empty_label:
		_empty_label.visible = not has_rooms
	if _spinner:
		_spinner.visible = not has_rooms
	if _count_label:
		_count_label.text = (_found_text() % _rooms.size()) if has_rooms else _scanning_text()
	for room in _rooms:
		_room_list_box.add_child(_make_room_row(room as Dictionary))


func _make_room_row(room: Dictionary) -> Control:
	var uid := str(room.get("uid", ""))
	var selected := uid == _selected_uid
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = Vector2(0.0, 66.0)
	card.add_theme_stylebox_override("panel", _row_style(selected))
	card.gui_input.connect(func(event): _on_room_row_input(event, room))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var badge := _label(_initial_for(str(room.get("room_name", "?"))), 22, Color(0.15, 0.10, 0.05, 1.0), _title_font)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_constant_override("outline_size", 0)
	var badge_wrap := PanelContainer.new()
	badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_wrap.custom_minimum_size = Vector2(46.0, 46.0)
	badge_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_wrap.add_theme_stylebox_override("panel", _round_style(GOLD, 12, Color(0, 0, 0, 0), 0))
	badge_wrap.add_child(badge)
	row.add_child(badge_wrap)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 1)
	var name_label := _label(str(room.get("room_name", "Room")), 21, TEXT, _title_font)
	name_label.add_theme_constant_override("outline_size", 0)
	texts.add_child(name_label)
	texts.add_child(_label(_host_line() % str(room.get("host_name", "—")), 13, TEXT_DIM, _body_font))
	row.add_child(texts)

	if bool(room.get("locked", false)) and _lock_texture:
		var lock := TextureRect.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.custom_minimum_size = Vector2(22.0, 22.0)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.texture = _lock_texture
		lock.modulate = Color(1.0, 0.9, 0.7, 0.9)
		row.add_child(lock)

	var count := _label("%d / %d" % [int(room.get("player_count", 0)), int(room.get("max_players", 24))], 20, ACCENT, _title_font)
	count.add_theme_constant_override("outline_size", 0)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.custom_minimum_size = Vector2(78.0, 0.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)
	return card


func _on_room_row_input(event: InputEvent, room: Dictionary) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_selected_uid = str(room.get("uid", ""))
	if mb.double_click:
		_attempt_join(room)
	else:
		_render_rooms(_rooms)  # repaint selection
	accept_event()


func _attempt_join(room: Dictionary) -> void:
	if bool(room.get("locked", false)):
		_open_modal(room)
	else:
		join_requested.emit(room, "")


# --- Locked-room password modal ---------------------------------------------

func _build_modal() -> void:
	_modal = Control.new()
	_modal.name = "JoinModal"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var panel := _card(true)
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	_modal_title = _label("", 22, TEXT, _title_font)
	col.add_child(_modal_title)
	_modal_password = _line_edit(_placeholder_password(), true)
	_modal_password.max_length = 16
	_modal_password.text_submitted.connect(func(_text): _confirm_modal())
	col.add_child(_modal_password)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var cancel := _button(_cancel_label(), false)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_modal)
	buttons.add_child(cancel)
	var join := _button(_join_label(), true)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.pressed.connect(_confirm_modal)
	buttons.add_child(join)


func _open_modal(room: Dictionary) -> void:
	_modal_room = room
	if _modal_title:
		_modal_title.text = _enter_password_text() % str(room.get("room_name", ""))
	if _modal_password:
		_modal_password.text = ""
		_modal_password.grab_focus()
	if _modal:
		_modal.visible = true


func _close_modal() -> void:
	if _modal:
		_modal.visible = false
	_modal_room = {}


func _confirm_modal() -> void:
	if _modal_room.is_empty():
		return
	var password := _modal_password.text if _modal_password else ""
	var room := _modal_room
	_close_modal()
	join_requested.emit(room, password)


# --- Create ------------------------------------------------------------------

func _on_create_pressed() -> void:
	var room_name := _name_input.text.strip_edges() if _name_input else ""
	if room_name.is_empty():
		set_status(_name_required_text(), true)
		if _name_input:
			_name_input.grab_focus()
		return
	var password := _password_input.text.strip_edges() if _password_input else ""
	create_requested.emit(room_name, password)


func _update_create_enabled() -> void:
	if _create_button == null:
		return
	var has_name := _name_input != null and not _name_input.text.strip_edges().is_empty()
	_create_button.disabled = not has_name
	_create_button.modulate = Color(1, 1, 1, 1) if has_name else Color(1, 1, 1, 0.5)


# --- Styling helpers ---------------------------------------------------------

func _card(emphasised: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.05, 0.52) if emphasised else CARD_BG
	style.set_corner_radius_all(20)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 4.0)
	if emphasised:
		style.border_width_left = 4
		style.border_color = ACCENT
	card.add_theme_stylebox_override("panel", style)
	return card


func _row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_SELECTED if selected else CARD_BG
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.border_width_left = 4
	style.border_color = ACCENT if selected else Color(1.0, 0.8, 0.4, 0.4)
	return style


func _round_style(bg: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	return style


func _line_edit(placeholder: String, secret: bool) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.custom_minimum_size = Vector2(0.0, 44.0)
	edit.add_theme_font_override("font", _body_font if _body_font else ThemeDB.fallback_font)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", TEXT)
	edit.add_theme_color_override("font_placeholder_color", Color(1.0, 0.92, 0.78, 0.45))
	edit.add_theme_color_override("caret_color", TEXT)
	edit.add_theme_stylebox_override("normal", _round_style(Color(0.0, 0.0, 0.0, 0.26), 12, Color(1.0, 0.85, 0.5, 0.35), 2))
	edit.add_theme_stylebox_override("focus", _round_style(Color(0.0, 0.0, 0.0, 0.34), 12, ACCENT, 2))
	return edit


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.add_theme_font_override("font", _title_font if _title_font else ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 22)
	if primary:
		button.add_theme_color_override("font_color", Color(0.18, 0.10, 0.03, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.12, 0.07, 0.02, 1.0))
		button.add_theme_stylebox_override("normal", _round_style(GOLD, 14, Color(0, 0, 0, 0), 0))
		button.add_theme_stylebox_override("hover", _round_style(Color(1.0, 0.74, 0.28, 1.0), 14, Color(0, 0, 0, 0), 0))
		button.add_theme_stylebox_override("pressed", _round_style(Color(0.88, 0.6, 0.18, 1.0), 14, Color(0, 0, 0, 0), 0))
		button.add_theme_stylebox_override("disabled", _round_style(Color(0.7, 0.55, 0.3, 0.5), 14, Color(0, 0, 0, 0), 0))
	else:
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_stylebox_override("normal", _round_style(Color(1.0, 1.0, 1.0, 0.14), 14, Color(1.0, 1.0, 1.0, 0.3), 1))
		button.add_theme_stylebox_override("hover", _round_style(Color(1.0, 1.0, 1.0, 0.22), 14, Color(1.0, 1.0, 1.0, 0.4), 1))
		button.add_theme_stylebox_override("pressed", _round_style(Color(1.0, 1.0, 1.0, 0.1), 14, Color(1.0, 1.0, 1.0, 0.3), 1))
	return button


func _section_label(text: String) -> Label:
	var label := _label(text, 16, Color(1.0, 1.0, 1.0, 0.74), _title_font)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.16, 0.02, 0.5))
	label.add_theme_constant_override("outline_size", 3)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _initial_for(room_name: String) -> String:
	var trimmed := room_name.strip_edges()
	return trimmed.substr(0, 1).to_upper() if not trimmed.is_empty() else "?"


func _vertical_gradient(top: Color, bottom: Color) -> Texture2D:
	var height := 256
	var image := Image.create(4, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var t := float(y) / float(height - 1)
		var line := top.lerp(bottom, t)
		for x in range(4):
			image.set_pixel(x, y, line)
	return ImageTexture.create_from_image(image)


func _radial_gradient(inner: Color, outer: Color) -> Texture2D:
	var tex_size := 256
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var cx := float(tex_size) * 0.5
	var cy := float(tex_size) * 0.42
	var radius := float(tex_size) * 0.6
	for y in range(tex_size):
		for x in range(tex_size):
			var d := Vector2(float(x) - cx, float(y) - cy).length() / radius
			var line := inner.lerp(outer, clampf(d, 0.0, 1.0))
			image.set_pixel(x, y, line)
	return ImageTexture.create_from_image(image)


func _spinner_texture() -> Texture2D:
	var s := 64
	var image := Image.create(s, s, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := float(s) * 0.5
	var outer := center - 4.0
	var inner := outer - 8.0
	for y in range(s):
		for x in range(s):
			var dx := float(x) - center
			var dy := float(y) - center
			var r := sqrt(dx * dx + dy * dy)
			if r < inner or r > outer:
				continue
			var ang := atan2(dy, dx) + PI
			var a := clampf(ang / TAU, 0.05, 1.0)
			image.set_pixel(x, y, Color(1.0, 0.98, 0.92, a))
	return ImageTexture.create_from_image(image)


func _load_font(path: String) -> Font:
	var resource: Resource = load(path)
	return resource if resource is Font else null


# --- Localized strings -------------------------------------------------------

func _t(key: String, fallback: String) -> String:
	if I18n and I18n.has_method("t"):
		var value := str(I18n.call("t", key))
		if value != key and not value.is_empty():
			return value
	return fallback


func _subtitle_text() -> String: return _t("private_server.subtitle", "LAN · 局域网联机 · 无需服务器")
func _placeholder_name() -> String: return _t("private_server.name_placeholder", "房间名称 *")
func _placeholder_password() -> String: return _t("private_server.password_placeholder", "密码（可选）")
func _create_label() -> String: return _t("private_server.create", "创建房间")
func _create_hint() -> String: return _t("private_server.create_hint", "必须填写房间名 · 同网络玩家可加入 · 最多 24 人")
func _searching_text() -> String: return _t("private_server.searching", "正在搜索同网络的房间…")
func _scanning_text() -> String: return _t("private_server.scanning", "扫描中…")
func _found_text() -> String: return _t("private_server.found", "%d 个房间")
func _host_line() -> String: return _t("private_server.host_line", "房主 %s")
func _name_required_text() -> String: return _t("private_server.name_required", "请先填写房间名称")
func _enter_password_text() -> String: return _t("private_server.enter_password", "输入「%s」的密码")
func _join_label() -> String: return _t("private_server.join", "加入")
func _cancel_label() -> String: return _t("private_server.cancel", "取消")


func _on_locale_changed(_locale: String) -> void:
	# Rebuild is heavy; just refresh the dynamic bits.
	if _name_input:
		_name_input.placeholder_text = _placeholder_name()
	if _password_input:
		_password_input.placeholder_text = _placeholder_password()
	if _create_button:
		_create_button.text = _create_label()
	if _empty_label:
		_empty_label.text = _searching_text()
	_render_rooms(_rooms)
