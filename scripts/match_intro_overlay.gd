extends Control
class_name MatchIntroOverlay

const START_COLOR := Color(0.18, 0.74, 1.0, 1.0)
const GO_COLOR := Color(0.42, 1.0, 0.62, 1.0)
const TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const COUNTDOWN_BEEP_SAMPLE_RATE := 44100

var _backdrop: ColorRect = null
var _band: PanelContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _count_label: Label = null
var _hint_label: Label = null
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
	if I18n and not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)


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
	_remaining = maxf(0.0, remaining)
	_last_display = ""
	_played_countdown_sounds.clear()
	visible = true
	_update_labels(true)


func set_remaining(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
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


func is_countdown_visible() -> bool:
	return visible and _remaining > 0.0


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
	band_style.bg_color = Color(0.015, 0.035, 0.07, 0.78)
	band_style.border_color = Color(0.40, 0.82, 1.0, 0.56)
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


func _update_labels(force_pulse: bool) -> void:
	if not _title_label:
		return
	var display := _display_text()
	_title_label.text = I18n.t("match_intro.title")
	_subtitle_label.text = I18n.t("match_intro.subtitle")
	_hint_label.text = I18n.t("match_intro.hint")
	_count_label.text = display
	_count_label.add_theme_color_override("font_color", GO_COLOR if display == "GO" else Color(1.0, 1.0, 1.0, 1.0))
	_title_label.add_theme_color_override("font_color", GO_COLOR if display == "GO" else START_COLOR)
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
