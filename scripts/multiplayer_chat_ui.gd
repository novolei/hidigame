extends Control
class_name MultiplayerChatUI

signal message_sent(message_text: String)

const FONT_HEADING_PATH := "res://assets/fonts/Saira-9.woff2"
const FONT_BODY_PATH := "res://assets/fonts/SairaCondensed-Medium.woff2"
const PLAYER_ICON_PATH := "res://addons/at-icons/control/human.svg"
const MAX_MESSAGES := 100

var message: LineEdit = null
var chat_visible := false

var _panel: PanelContainer = null
var _chat_log_box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _messages: Array[Dictionary] = []
var _styles := {}
var _font_heading: Font = null
var _font_body: Font = null
var _layout_bucket := Vector2i.ZERO
var _fade_tween: Tween = null
var _closing_with_fade := false


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_to_viewport()
	_load_fonts()
	_build_styles()
	_build_chat_panel()
	if not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()
		var viewport_size := get_viewport_rect().size
		var bucket := Vector2i(roundi(viewport_size.x / 80.0), roundi(viewport_size.y / 60.0))
		if bucket != _layout_bucket:
			_layout_bucket = bucket
			call_deferred("_rebuild_after_resize")


func toggle_chat() -> void:
	set_chat_visible(not chat_visible)


func set_chat_visible(value: bool) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	_closing_with_fade = false
	chat_visible = value
	visible = chat_visible
	if chat_visible:
		modulate.a = 1.0
		if _panel:
			_panel.modulate.a = 1.0
		await get_tree().process_frame
		if message:
			message.grab_focus()
	else:
		if message:
			message.text = ""
		get_viewport().set_input_as_handled()


func is_chat_visible() -> bool:
	return chat_visible


func close_with_fade() -> void:
	if not chat_visible or _closing_with_fade:
		return
	_closing_with_fade = true
	chat_visible = false
	if message:
		message.text = ""
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	var fade_target: CanvasItem = _panel if _panel else self
	_fade_tween.tween_property(fade_target, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _fade_tween.finished
	visible = false
	_closing_with_fade = false
	if _panel:
		_panel.modulate.a = 1.0
	modulate.a = 1.0
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not chat_visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _panel and not _panel.get_global_rect().has_point(event.position):
			close_with_fade()
			get_viewport().set_input_as_handled()


func add_message(nick: String, msg: String) -> void:
	var trimmed_text := msg.strip_edges()
	if trimmed_text.is_empty():
		return
	_messages.append({
		"nick": nick,
		"text": trimmed_text,
	})
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	_refresh_messages()


func clear_chat() -> void:
	_messages.clear()
	_refresh_messages()


func _on_send_pressed() -> void:
	if not message:
		return
	var message_text := message.text.strip_edges()
	if message_text.is_empty():
		return
	message_sent.emit(message_text)
	message.text = ""
	message.grab_focus()


func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	global_position = Vector2.ZERO
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _rebuild_after_resize() -> void:
	if not is_inside_tree():
		return
	_build_styles()
	_build_chat_panel()


func _build_chat_panel() -> void:
	for child in get_children():
		child.queue_free()

	_panel = PanelContainer.new()
	_panel.name = "GameChatPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _styles["chat_panel"])
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var width := _responsive_width(0.43, 520, 880)
	_panel.offset_left = _s(44)
	_panel.offset_right = _s(44) + width
	_panel.offset_top = -_s(306)
	_panel.offset_bottom = -_s(58)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_chat_log_box = VBoxContainer.new()
	_chat_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log_box.add_theme_constant_override("separation", _s(7))
	_scroll.add_child(_chat_log_box)
	_refresh_messages()

	var split := HSeparator.new()
	split.add_theme_color_override("separator", Color(0.420, 0.415, 0.455, 1))
	box.add_child(split)

	var input_row := HBoxContainer.new()
	input_row.custom_minimum_size = _sv(0, 58)
	input_row.add_theme_constant_override("separation", 0)
	box.add_child(input_row)

	var tab := PanelContainer.new()
	tab.custom_minimum_size = _sv(126, 58)
	tab.add_theme_stylebox_override("panel", _styles["chat_tab"])
	input_row.add_child(tab)

	var tab_label := _label(I18n.t("chat"), 18, true)
	tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_label.add_theme_color_override("font_color", Color(0.070, 0.820, 0.720, 1))
	tab.add_child(tab_label)

	message = LineEdit.new()
	message.name = "Message"
	message.placeholder_text = I18n.t("chat.placeholder")
	message.max_length = 100
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.add_theme_stylebox_override("normal", _styles["chat_input"])
	message.add_theme_stylebox_override("focus", _styles["chat_input"])
	message.add_theme_font_size_override("font_size", _s(19))
	message.add_theme_color_override("font_color", Color.WHITE)
	message.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.59, 1))
	if _use_brand_font() and _font_body:
		message.add_theme_font_override("font", _font_body)
	message.text_submitted.connect(func(_text): _on_send_pressed())
	input_row.add_child(message)


func _refresh_messages() -> void:
	if not _chat_log_box:
		return
	for child in _chat_log_box.get_children():
		child.queue_free()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log_box.add_child(spacer)
	for item in _messages:
		_chat_log_box.add_child(_chat_message_row(str(item.get("nick", "Player")), str(item.get("text", ""))))
	call_deferred("_scroll_to_bottom")


func _chat_message_row(nick: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(8))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.custom_minimum_size = _sv(22, 22)
	icon.texture = load(PLAYER_ICON_PATH)
	icon.modulate = Color(0.070, 0.820, 0.720, 1)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var nick_label := _label(nick, 18, false)
	nick_label.add_theme_color_override("font_color", Color(0.070, 0.820, 0.720, 1))
	row.add_child(nick_label)

	var msg_label := _label(text, 18, false)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg_label)
	return row


func _scroll_to_bottom() -> void:
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_locale_changed(_locale: String) -> void:
	_build_styles()
	_build_chat_panel()


func _load_fonts() -> void:
	_font_heading = _load_font(FONT_HEADING_PATH)
	_font_body = _load_font(FONT_BODY_PATH)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _use_brand_font() -> bool:
	return I18n.current_locale != "zh"


func _build_styles() -> void:
	_styles.clear()
	_styles["chat_panel"] = _style(Color(0.090, 0.080, 0.100, 0.96), Color(0.380, 0.390, 0.435, 0.95), 1, 9)
	_styles["chat_input"] = _style(Color(0.165, 0.155, 0.180, 0.98), Color(0.290, 0.285, 0.315, 1), 1, 0)
	_styles["chat_tab"] = _style(Color(0.085, 0.075, 0.095, 1), Color(0.085, 0.075, 0.095, 1), 1, 0)


func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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


func _label(text: String, size: int, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _s(size))
	label.add_theme_color_override("font_color", Color.WHITE)
	if _use_brand_font():
		var font := _font_heading if bold else _font_body
		if font:
			label.add_theme_font_override("font", font)
	else:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var scale := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	return clampf(scale, 0.78, 1.35)


func _s(value: float) -> int:
	return max(1, roundi(value * _ui_scale()))


func _sv(x: float, y: float) -> Vector2:
	return Vector2(_s(x), _s(y))


func _responsive_width(ratio: float, min_width: int, max_width: int) -> int:
	var viewport_width := get_viewport_rect().size.x
	return clampi(roundi(viewport_width * ratio), _s(min_width), _s(max_width))
