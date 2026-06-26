extends Control
class_name MatchIntroOverlay

signal quit_confirmed
signal quit_cancelled
signal return_lobby_confirmed

enum OverlayMode {
	COUNTDOWN,
	QUIT_CONFIRM,
}

const START_COLOR := Color(0.18, 0.74, 1.0, 1.0)
const GO_COLOR := Color(0.42, 1.0, 0.62, 1.0)
const BAND_BG_COLOR := Color(0.015, 0.035, 0.07, 0.78)
const BAND_BORDER_COLOR := Color(0.40, 0.82, 1.0, 0.56)
const BUTTON_STRIP_BG_COLOR := Color(0.015, 0.035, 0.07, 0.52)
const BUTTON_STRIP_BORDER_COLOR := Color(0.40, 0.82, 1.0, 0.34)
const TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const COUNTDOWN_BEEP_SAMPLE_RATE := 44100

var _backdrop: ColorRect = null
var _band: PanelContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _count_label: Label = null
var _hint_label: Label = null
var _button_strip: PanelContainer = null
var _button_row: HBoxContainer = null
var _cancel_button: Button = null
var _return_lobby_button: Button = null
var _confirm_button: Button = null
var _overlay_mode: OverlayMode = OverlayMode.COUNTDOWN
var _return_lobby_available := false
var _remaining := 0.0
var _last_display := ""
var _played_countdown_sounds: Dictionary = {}
var _pulse_tween: Tween = null
var _blur_material: ShaderMaterial = null
var _title_font: Font = null
var _value_font: Font = null
var _audio_player: AudioStreamPlayer = null
var _count_beep_stream: AudioStreamWAV = null
var _go_beep_stream: AudioStreamWAV = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_fit_to_viewport()
	_load_hud_fonts()
	_build_ui()
	_setup_audio()
	visible = false
	var i18n: Node = _get_i18n()
	var locale_callable := Callable(self, "_on_locale_changed")
	if i18n and i18n.has_signal("locale_changed") and not i18n.is_connected("locale_changed", locale_callable):
		i18n.connect("locale_changed", locale_callable)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = viewport_size.x
	offset_bottom = viewport_size.y
	custom_minimum_size = viewport_size


func _load_hud_fonts() -> void:
	_title_font = _load_font(TITLE_FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)


func _load_font(path: String) -> Font:
	var resource: Resource = load(path)
	return resource if resource is Font else null


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_title_font()


func _get_i18n() -> Node:
	return get_node_or_null("/root/I18n")


func _tr(key: String) -> String:
	var i18n: Node = _get_i18n()
	if i18n and i18n.has_method("t"):
		return str(i18n.call("t", key))
	return key


func _setup_audio() -> void:
	_count_beep_stream = _make_start_cue_stream(620.0, 0.24, false)
	_go_beep_stream = _make_start_cue_stream(980.0, 0.42, true)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "MatchIntroCountdownSfx"
	_audio_player.volume_db = -4.5
	_audio_player.max_polyphony = 3
	_audio_player.bus = &"Master"
	add_child(_audio_player)


func _make_start_cue_stream(base_frequency: float, duration: float, final_cue: bool) -> AudioStreamWAV:
	var sample_count: int = int(float(COUNTDOWN_BEEP_SAMPLE_RATE) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(COUNTDOWN_BEEP_SAMPLE_RATE)
		var progress: float = float(i) / maxf(1.0, float(sample_count - 1))
		var attack: float = clampf(progress / 0.045, 0.0, 1.0)
		var release: float = clampf((1.0 - progress) / (0.38 if final_cue else 0.24), 0.0, 1.0)
		var body_envelope: float = attack * release
		var transient_envelope: float = maxf(0.0, 1.0 - progress * (9.0 if final_cue else 13.0))
		var sweep_frequency: float = lerpf(base_frequency * (0.78 if final_cue else 1.08), base_frequency * (1.78 if final_cue else 0.94), progress)
		var low_punch: float = sin(TAU * (86.0 + 32.0 * progress) * t) * exp(-progress * 11.0)
		var body: float = sin(TAU * sweep_frequency * t) + 0.26 * sin(TAU * sweep_frequency * 1.5 * t)
		var edge: float = (1.0 if sin(TAU * base_frequency * 0.5 * t) >= 0.0 else -1.0) * 0.12
		var shimmer: float = sin(TAU * (base_frequency * 2.65 + 520.0 * progress) * t) * transient_envelope
		var noise_hash: float = fposmod(sin(float(i) * 12.9898 + base_frequency) * 43758.5453, 1.0)
		var noise: float = (noise_hash * 2.0 - 1.0) * transient_envelope * 0.10
		var final_lift: float = 0.0
		if final_cue:
			final_lift = sin(TAU * (sweep_frequency * 1.9) * t) * clampf((progress - 0.18) / 0.72, 0.0, 1.0) * release * 0.20
		var wave: float = low_punch * 0.72 + body * body_envelope * 0.62 + edge * body_envelope + shimmer * 0.34 + noise + final_lift
		var sample: int = int(clampf(wave * 14200.0, -32768.0, 32767.0))
		if sample < 0:
			sample += 65536
		data[i * 2] = sample & 0xff
		data[i * 2 + 1] = (sample >> 8) & 0xff
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = COUNTDOWN_BEEP_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


func show_countdown(remaining: float) -> void:
	_overlay_mode = OverlayMode.COUNTDOWN
	_remaining = maxf(0.0, remaining)
	_last_display = ""
	_played_countdown_sounds.clear()
	_apply_countdown_layout()
	visible = true
	_update_labels(true)


func set_remaining(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
	if _overlay_mode == OverlayMode.COUNTDOWN:
		_update_labels(false)


func hide_countdown() -> void:
	set_process(false)
	visible = false
	_remaining = 0.0
	_last_display = ""
	_played_countdown_sounds.clear()
	if _audio_player:
		_audio_player.stop()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()


func show_quit_confirm(return_lobby_available: bool = false) -> void:
	_overlay_mode = OverlayMode.QUIT_CONFIRM
	_return_lobby_available = return_lobby_available
	_remaining = 0.0
	_last_display = ""
	_played_countdown_sounds.clear()
	if _audio_player:
		_audio_player.stop()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	set_process(false)
	_apply_quit_confirm_layout()
	visible = true
	_update_quit_confirm_labels()
	if _cancel_button:
		_cancel_button.grab_focus()


func hide_quit_confirm() -> void:
	if _overlay_mode == OverlayMode.QUIT_CONFIRM:
		visible = false


func is_countdown_visible() -> bool:
	return visible and _overlay_mode == OverlayMode.COUNTDOWN and _remaining > 0.0


func is_quit_confirm_visible() -> bool:
	return visible and _overlay_mode == OverlayMode.QUIT_CONFIRM


func get_quit_confirm_button_texts_for_test() -> PackedStringArray:
	var texts := PackedStringArray([
		_cancel_button.text if _cancel_button else "",
	])
	if _return_lobby_button and _return_lobby_available:
		texts.append(_return_lobby_button.text)
	texts.append(_confirm_button.text if _confirm_button else "")
	return texts


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_update_labels(false)


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "MatchIntroBlurBackdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength = 5.5;
uniform vec4 tint : source_color = vec4(0.02, 0.04, 0.08, 0.72);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_strength;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.28;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)) * 0.14;
	color += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)) * 0.14;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)) * 0.14;
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)) * 0.14;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, px.y)) * 0.08;
	color += texture(screen_texture, SCREEN_UV - vec2(px.x, px.y)) * 0.08;
	COLOR = mix(color, tint, tint.a);
}
"""
	_blur_material.shader = shader
	_backdrop.material = _blur_material
	add_child(_backdrop)

	var dim_top := ColorRect.new()
	dim_top.name = "TopDim"
	dim_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_top.color = Color(0.0, 0.0, 0.0, 0.18)
	add_child(dim_top)

	_band = PanelContainer.new()
	_band.name = "MatchIntroBand"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.5
	_band.anchor_bottom = 0.5
	_band.offset_left = 0.0
	_band.offset_right = 0.0
	_band.offset_top = -155.0
	_band.offset_bottom = 155.0
	var band_style := StyleBoxFlat.new()
	band_style.bg_color = BAND_BG_COLOR
	band_style.border_color = BAND_BORDER_COLOR
	band_style.border_width_top = 2
	band_style.border_width_bottom = 2
	band_style.content_margin_left = 44.0
	band_style.content_margin_right = 44.0
	band_style.content_margin_top = 26.0
	band_style.content_margin_bottom = 26.0
	_band.add_theme_stylebox_override("panel", band_style)
	add_child(_band)

	var content := VBoxContainer.new()
	content.name = "MatchIntroContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(900.0, 250.0)
	content.add_theme_constant_override("separation", 8)
	_band.add_child(content)

	_title_label = _make_label(46, START_COLOR, 8, _get_title_font())
	_title_label.name = "Title"
	content.add_child(_title_label)

	_subtitle_label = _make_label(21, Color(0.88, 0.94, 1.0, 0.86), 4, _get_value_font())
	_subtitle_label.name = "Subtitle"
	content.add_child(_subtitle_label)

	_count_label = _make_label(112, Color(1.0, 1.0, 1.0, 1.0), 12, _get_value_font())
	_count_label.name = "CountdownNumber"
	_count_label.custom_minimum_size = Vector2(0.0, 125.0)
	content.add_child(_count_label)

	_hint_label = _make_label(18, Color(0.72, 0.84, 0.92, 0.82), 3, _get_value_font())
	_hint_label.name = "Hint"
	content.add_child(_hint_label)

	_button_strip = PanelContainer.new()
	_button_strip.name = "QuitConfirmButtonStrip"
	_button_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	_button_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_strip.custom_minimum_size = Vector2(900.0, 64.0)
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = BUTTON_STRIP_BG_COLOR
	strip_style.border_color = BUTTON_STRIP_BORDER_COLOR
	strip_style.border_width_top = 1
	strip_style.border_width_bottom = 1
	strip_style.content_margin_left = 36.0
	strip_style.content_margin_right = 36.0
	strip_style.content_margin_top = 10.0
	strip_style.content_margin_bottom = 10.0
	_button_strip.add_theme_stylebox_override("panel", strip_style)
	content.add_child(_button_strip)

	_button_row = HBoxContainer.new()
	_button_row.name = "QuitConfirmButtons"
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_row.add_theme_constant_override("separation", 22)
	_button_strip.add_child(_button_row)

	_cancel_button = _make_quit_button(_tr("quit_confirm.cancel"), false)
	_cancel_button.name = "CancelQuitButton"
	_cancel_button.pressed.connect(_on_cancel_quit_pressed)
	_button_row.add_child(_cancel_button)

	_return_lobby_button = _make_quit_button(_tr("quit_confirm.return_lobby"), true)
	_return_lobby_button.name = "ReturnLobbyButton"
	_return_lobby_button.pressed.connect(_on_return_lobby_pressed)
	_button_row.add_child(_return_lobby_button)

	_confirm_button = _make_quit_button(_tr("quit_confirm.confirm"), true)
	_confirm_button.name = "ConfirmQuitButton"
	_confirm_button.pressed.connect(_on_confirm_quit_pressed)
	_button_row.add_child(_confirm_button)
	_button_strip.visible = false


func _make_label(font_size: int, color: Color, outline_size: int, font: Font) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(820.0, 0.0)
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _make_quit_button(text: String, highlighted: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250.0 if highlighted else 180.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _get_value_font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.02, 0.06, 0.07, 1.0) if highlighted else Color(0.86, 0.94, 1.0, 0.94))
	button.add_theme_color_override("font_hover_color", Color(0.01, 0.04, 0.05, 1.0) if highlighted else Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.01, 0.04, 0.05, 1.0) if highlighted else Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(highlighted, false, false))
	button.add_theme_stylebox_override("hover", _make_button_style(highlighted, true, false))
	button.add_theme_stylebox_override("pressed", _make_button_style(highlighted, false, true))
	button.add_theme_stylebox_override("focus", _make_button_style(true, true, false, true))
	return button


func _make_button_style(highlighted: bool, hover: bool, pressed: bool, focus: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if highlighted:
		style.bg_color = GO_COLOR
		if hover:
			style.bg_color = Color(0.56, 1.0, 0.78, 1.0)
		if pressed:
			style.bg_color = Color(0.26, 0.82, 0.56, 1.0)
		style.border_color = Color(0.95, 1.0, 1.0, 0.95) if focus else Color(0.72, 1.0, 0.92, 0.82)
	else:
		style.bg_color = Color(0.02, 0.05, 0.09, 0.82)
		if hover:
			style.bg_color = Color(0.04, 0.12, 0.18, 0.90)
		if pressed:
			style.bg_color = Color(0.01, 0.03, 0.06, 0.96)
		style.border_color = Color(0.40, 0.82, 1.0, 0.46)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	if focus:
		style.shadow_color = Color(0.55, 0.78, 1.0, 0.82)
		style.shadow_size = 8
	return style


func _apply_countdown_layout() -> void:
	if not _band:
		return
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.offset_top = -155.0
	_band.offset_bottom = 155.0
	_set_band_style(BAND_BG_COLOR, BAND_BORDER_COLOR, 2, 2, 26.0, 26.0)
	_title_label.visible = true
	_subtitle_label.visible = true
	_count_label.visible = true
	_hint_label.visible = true
	_button_strip.visible = false
	_title_label.add_theme_font_size_override("font_size", 46)
	_subtitle_label.add_theme_font_size_override("font_size", 21)
	_count_label.custom_minimum_size = Vector2(0.0, 125.0)


func _apply_quit_confirm_layout() -> void:
	if not _band:
		return
	_apply_countdown_layout()
	_band.mouse_filter = Control.MOUSE_FILTER_STOP
	_count_label.visible = false
	_hint_label.visible = false
	_button_strip.visible = true
	if _return_lobby_button:
		_return_lobby_button.visible = _return_lobby_available
	_title_label.add_theme_font_size_override("font_size", 50)
	_subtitle_label.add_theme_font_size_override("font_size", 23)
	_subtitle_label.custom_minimum_size = Vector2(820.0, 38.0)


func _set_band_style(bg_color: Color, border_color: Color, top_border: int, bottom_border: int, top_margin: float, bottom_margin: float) -> void:
	var band_style := StyleBoxFlat.new()
	band_style.bg_color = bg_color
	band_style.border_color = border_color
	band_style.border_width_top = top_border
	band_style.border_width_bottom = bottom_border
	band_style.content_margin_left = 44.0
	band_style.content_margin_right = 44.0
	band_style.content_margin_top = top_margin
	band_style.content_margin_bottom = bottom_margin
	_band.add_theme_stylebox_override("panel", band_style)


func _update_quit_confirm_labels() -> void:
	if not _title_label:
		return
	_title_label.text = _tr("quit_confirm.room_title") if _return_lobby_available else _tr("quit_confirm.title")
	_subtitle_label.text = _tr("quit_confirm.room_subtitle") if _return_lobby_available else _tr("quit_confirm.subtitle")
	_title_label.add_theme_color_override("font_color", START_COLOR)
	_subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.86))
	_cancel_button.text = _tr("quit_confirm.cancel")
	if _return_lobby_button:
		_return_lobby_button.text = _tr("quit_confirm.return_lobby")
	_confirm_button.text = _tr("quit_confirm.confirm")


func _update_labels(force_pulse: bool) -> void:
	if not _title_label:
		return
	if _overlay_mode == OverlayMode.QUIT_CONFIRM:
		_update_quit_confirm_labels()
		return
	var display := _display_text()
	_title_label.text = _tr("match_intro.title")
	_subtitle_label.text = _tr("match_intro.subtitle")
	_hint_label.text = _tr("match_intro.hint")
	_count_label.text = display
	_count_label.add_theme_color_override("font_color", GO_COLOR if display == "GO" else Color(1.0, 1.0, 1.0, 1.0))
	_title_label.add_theme_color_override("font_color", GO_COLOR if display == "GO" else START_COLOR)
	_subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.86))
	if force_pulse or display != _last_display:
		_last_display = display
		_pulse_count_label()
		_play_countdown_sound(display)


func _play_countdown_sound(display: String) -> void:
	if not _audio_player:
		return
	if _played_countdown_sounds.has(display):
		return
	_played_countdown_sounds[display] = true
	if display == "GO":
		_audio_player.stream = _go_beep_stream
		_audio_player.pitch_scale = 1.0
	else:
		_audio_player.stream = _count_beep_stream
		var number: int = int(display)
		_audio_player.pitch_scale = 0.92 + float(3 - number) * 0.08
	_audio_player.play()


func _display_text() -> String:
	if _remaining <= 0.05:
		return "GO"
	return str(clampi(int(ceil(_remaining)), 1, 3))


func _on_cancel_quit_pressed() -> void:
	emit_signal("quit_cancelled")


func _on_return_lobby_pressed() -> void:
	emit_signal("return_lobby_confirmed")


func _on_confirm_quit_pressed() -> void:
	emit_signal("quit_confirmed")


func _pulse_count_label() -> void:
	if not _count_label:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_count_label.scale = Vector2(1.16, 1.16)
	_count_label.modulate.a = 0.0
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_property(_count_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_count_label, "modulate:a", 1.0, 0.12)


func _on_locale_changed(_locale: String) -> void:
	_update_labels(false)
