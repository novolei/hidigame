@tool
extends Control
class_name StartupSplash

const NEXT_SCENE_PATH := "res://scenes/ui/intro_video.tscn"
const DEDICATED_SERVER_SCENE_PATH := "res://scenes/level/level.tscn"
const APP_NAME := "Monster & Hunter"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const MIN_DISPLAY_SECONDS := 4.2
const UPDATE_TIMEOUT_SECONDS := 40.0
const POST_READY_HOLD_SECONDS := 0.2
const WORDMARK_MONTAGE_SECONDS := 2.15
const LOGO_DROP_DELAY_SECONDS := 2.05
const LOGO_DROP_SECONDS := 1.75
const WORDMARK_WHOOSH_SECONDS := 0.58
const WORDMARK_WHOOSH_MIX_RATE := 22050.0
const WORDMARK_WHOOSH_VOLUME_DB := -18.0
const LOGO_IDLE_FIRST_WAIT := 0.08
const LOGO_IDLE_MIN_WAIT := 0.42
const LOGO_IDLE_MAX_WAIT := 1.05
const BACKGROUND_TOP_COLOR := Color8(45, 143, 252, 255)
const BACKGROUND_MID_COLOR := Color8(45, 143, 252, 255)
const BACKGROUND_BOTTOM_COLOR := Color8(45, 143, 252, 255)
const TEXT_DARK := Color(0.260, 0.280, 0.310, 0.88)
const TEXT_MUTED := Color(0.360, 0.380, 0.410, 0.60)
const TEXT_FAINT := Color(0.360, 0.380, 0.410, 0.46)
const VERSION_TEXT_COLOR := Color(1.0, 1.0, 1.0, 0.75)
const UPDATE_TEXT_COLOR := Color(1.0, 1.0, 1.0, 0.75)
const UPDATE_RING_PROGRESS_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const UPDATE_STATUS_TEXT_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const UPDATE_RING_TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const UPDATE_RING_HIGHLIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const UPDATE_RING_INNER_COLOR := Color(1.0, 1.0, 1.0, 0.12)

const STARTUP_TEXT := {
	"en": {
		"version": "Version %s",
		"route": "China Server - National Node",
		"hot_update_title": "Game Update",
		"update_checking": "Checking hot-update manifest",
		"update_downloading": "Downloading hot-update package",
		"update_installing": "Loading hot-update dynamic library",
		"update_switching": "Switching mirror distribution node",
		"update_installed": "Hot update installed",
		"update_ready": "Hot-update package ready",
		"update_current": "Local content is up to date",
		"update_local": "Using bundled local content",
		"update_manifest": "Reading hot-update manifest",
		"update_intro": "Entering startup animation",
		"perf_latency": "Latency N/A",
		"copyright": "© 2026 Source Technology",
	},
	"zh": {
		"version": "版本 %s",
		"route": "中国服务器 - 国服节点",
		"hot_update_title": "Game Update",
		"update_checking": "检查热更新清单",
		"update_downloading": "下载热更新分包",
		"update_installing": "加载热更新动态链接库",
		"update_switching": "切换备用分发节点",
		"update_installed": "热更新安装完成",
		"update_ready": "热更新分包已就绪",
		"update_current": "本地内容已是最新",
		"update_local": "使用本地客户端内容",
		"update_manifest": "读取热更新清单",
		"update_intro": "进入启动动画",
		"perf_latency": "延迟 N/A",
		"copyright": "© 2026 Source Technology",
	},
}


class RingProgress:
	extends Control

	var progress := 0.0
	var track_color := Color(0.320, 0.340, 0.370, 0.22)
	var progress_color := Color(0.260, 0.280, 0.310, 0.72)
	var highlight_color := Color(1.0, 1.0, 1.0, 0.16)
	var inner_shadow_color := Color(0.160, 0.170, 0.190, 0.22)
	var ring_width := 4.0
	var minimum_sweep := 0.0
	var inset := true

	func set_progress(value: float) -> void:
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := maxf(1.0, minf(size.x, size.y) * 0.5 - ring_width * 0.5)
		var start_angle := -PI * 0.5
		if inset:
			draw_arc(center + Vector2(0.0, 1.0), radius, start_angle, start_angle + TAU, 96, inner_shadow_color, ring_width + 1.0, true)
			draw_arc(center + Vector2(0.0, -1.0), radius, start_angle, start_angle + TAU, 96, highlight_color, maxf(1.0, ring_width * 0.45), true)
		draw_arc(center, radius, start_angle, start_angle + TAU, 96, track_color, ring_width, true)
		if progress <= 0.0:
			return
		var sweep := maxf(TAU * progress, TAU * minimum_sweep)
		draw_arc(center, radius, start_angle, start_angle + sweep, 96, progress_color, ring_width, true)


var _font_heading: Font
var _font_body: Font
var _font_button: Font
var _font_menu: Font
var _scene_load_requested := false
var _flow_finished := false
var _update_complete := false
var _update_failed := false
var _installing_update := false
var _restart_required := false
var _startup_elapsed := 0.0
var _manager: Node = null
var _i18n: Node = null
var _last_update_title := "CHECKING CONTENT"
var _last_update_detail := ""
var _last_update_progress := 0.09
var _brand_montage_started := false
var _brand_montage_finished := false
var _brand_scale_value := 1.0
var _wordmark_home_position := Vector2.ZERO
var _wordmark_start_position := Vector2.ZERO
var _logo_home_position := Vector2.ZERO
var _logo_start_position := Vector2.ZERO
var _logo_depth_layers: Array[TextureRect] = []
var _wordmark_trails: Array[TextureRect] = []
var _wordmark_glow: TextureRect
var _logo_idle_rng := RandomNumberGenerator.new()
var _logo_idle_time := 0.0
var _logo_idle_seed := 0.0
var _logo_wobble_wait := 0.0
var _logo_wobble_elapsed := 0.0
var _logo_wobble_duration := 0.0
var _logo_wobble_strength := 0.0
var _logo_wobble_frequency := 0.0
var _logo_wobble_rotation := 0.0
var _logo_wobble_offset := Vector2.ZERO

var _background: ColorRect
var _background_gradient: TextureRect
var _version_group: Control
var _version_label: Label
var _route_label: Label
var _perf_label: Label
var _corner_spinner: RingProgress
var _brand_group: Control
var _brand_logo_panel: Control
var _brand_logo_texture: TextureRect
var _brand_initials: Label
var _wordmark_container: Control
var _update_group: Control
var _update_ring: RingProgress
var _update_ring_label: Label
var _update_title_label: Label
var _update_status_label: Label
var _copyright_label: Label
var _whoosh_player: AudioStreamPlayer


func _ready() -> void:
	if _should_bypass_for_dedicated_server():
		call_deferred("_change_to_dedicated_server_scene")
		return

	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(BACKGROUND_TOP_COLOR)
	_logo_idle_rng.randomize()
	_logo_idle_seed = _logo_idle_rng.randf_range(0.0, TAU)
	_load_fonts()
	_bind_i18n()
	_build_screen()
	_refresh_localized_text()
	_layout_screen()
	_update_performance_label()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	if Engine.is_editor_hint():
		_set_update_state("CHECKING CONTENT", "Using TX primary distribution and AL mirror.", 0.09)
		return
	_prepare_brand_montage()
	_play_brand_montage()
	_bind_hot_update_manager()
	_request_next_scene_preload()
	set_process(true)
	_run_startup_flow()


func _process(delta: float) -> void:
	_startup_elapsed += delta
	_update_ring_motion(delta)
	_update_corner_spinner(delta)
	_update_logo_idle_wobble(delta)
	_update_performance_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_screen()


func _should_bypass_for_dedicated_server() -> bool:
	if Engine.is_editor_hint() or DisplayServer.get_name() != "headless":
		return false
	return _startup_cmd_arg_has("--maomao-public-server") \
		or _startup_cmd_arg_has("--public-server") \
		or _startup_cmd_arg_has("--maomao-room-server") \
		or OS.get_environment("MAOMAO_PUBLIC_SERVER") == "1" \
		or OS.get_environment("MAOMAO_ROOM_SERVER") == "1"


func _change_to_dedicated_server_scene() -> void:
	var error := get_tree().change_scene_to_file(DEDICATED_SERVER_SCENE_PATH)
	if error != OK:
		push_error("StartupSplash: dedicated server scene load failed: %s" % error_string(error))


func _startup_cmd_arg_has(arg_name: String) -> bool:
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg in args:
		if str(arg) == arg_name:
			return true
	return false


func _build_screen() -> void:
	_background = ColorRect.new()
	_background.name = "SoftGreyBase"
	_background.color = BACKGROUND_MID_COLOR
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_background_gradient = TextureRect.new()
	_background_gradient.name = "SoftGreyGradient"
	_background_gradient.texture = _create_background_texture()
	_background_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_background_gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_gradient)

	_build_version_block()
	_build_top_right_status()
	_build_center_brand()
	_build_hot_update_status()
	_build_footer()
	_build_audio_cues()


func _build_version_block() -> void:
	_version_group = Control.new()
	_version_group.name = "VersionGroup"
	_version_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version_group)

	_version_label = _label("", 24, VERSION_TEXT_COLOR, true, _font_button)
	_version_label.name = "VersionLabel"
	_version_group.add_child(_version_label)



func _build_top_right_status() -> void:
	_perf_label = _label("", 17, Color(0.840, 0.860, 0.890, 0.72), true, _font_body)
	_perf_label.name = "PerformanceStatus"
	_perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_perf_label)

	_corner_spinner = RingProgress.new()
	_corner_spinner.name = "CornerSpinner"
	_corner_spinner.progress_color = Color(0.280, 0.300, 0.330, 0.68)
	_corner_spinner.track_color = Color(0.280, 0.300, 0.330, 0.22)
	_corner_spinner.highlight_color = Color(1.0, 1.0, 1.0, 0.10)
	_corner_spinner.minimum_sweep = 0.30
	_corner_spinner.set_progress(0.74)
	_corner_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corner_spinner)


func _build_center_brand() -> void:
	_brand_group = Control.new()
	_brand_group.name = "CenterBrand"
	_brand_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brand_group)

	_brand_logo_panel = Control.new()
	_brand_logo_panel.name = "LogoDirect"
	_brand_logo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_logo_panel.clip_contents = false
	_brand_group.add_child(_brand_logo_panel)

	_logo_depth_layers.clear()
	var logo_texture := ResourceLoader.load("res://icon.png", "Texture2D") as Texture2D
	for index in range(3):
		var depth_layer := TextureRect.new()
		depth_layer.name = "LogoDepth%d" % (index + 1)
		depth_layer.texture = logo_texture
		depth_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		depth_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		depth_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		depth_layer.modulate = Color(0.100, 0.170, 0.340, 0.22 - float(index) * 0.045)
		depth_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_brand_logo_panel.add_child(depth_layer)
		_logo_depth_layers.append(depth_layer)

	_brand_logo_texture = TextureRect.new()
	_brand_logo_texture.name = "LogoTexture"
	_brand_logo_texture.texture = logo_texture
	_brand_logo_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_logo_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brand_logo_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_brand_logo_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_logo_panel.add_child(_brand_logo_texture)

	_brand_initials = _label("M&H", 64, TEXT_DARK, true, _font_menu)
	_brand_initials.name = "LogoFallbackText"
	_brand_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_brand_initials.visible = _brand_logo_texture.texture == null
	_brand_logo_panel.add_child(_brand_initials)

	_wordmark_container = StartupBrandRenderer.create_wordmark_container(StartupBrandRenderer.load_wordmark_font())
	_brand_group.add_child(_wordmark_container)


func _build_hot_update_status() -> void:
	_update_group = Control.new()
	_update_group.name = "HotUpdateStatus"
	_update_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_update_group)

	_update_ring = RingProgress.new()
	_update_ring.name = "HotUpdateRing"
	_update_ring.progress_color = UPDATE_RING_PROGRESS_COLOR
	_update_ring.track_color = UPDATE_RING_TRACK_COLOR
	_update_ring.highlight_color = UPDATE_RING_HIGHLIGHT_COLOR
	_update_ring.inner_shadow_color = UPDATE_RING_INNER_COLOR
	_update_ring.minimum_sweep = 0.0
	_update_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_group.add_child(_update_ring)

	_update_ring_label = _label("9", 11, UPDATE_TEXT_COLOR, true, _font_button)
	_update_ring_label.name = "HotUpdateRingLabel"
	_update_ring_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_ring_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_ring.add_child(_update_ring_label)

	_update_title_label = _label("", 23, UPDATE_TEXT_COLOR, true, _font_button)
	_update_title_label.name = "HotUpdateTitle"
	_update_group.add_child(_update_title_label)

	_update_status_label = _label("", 23, UPDATE_STATUS_TEXT_COLOR, true, _font_body)
	_update_status_label.name = "HotUpdateDetail"
	_update_group.add_child(_update_status_label)
	_set_update_progress(0.09)


func _build_footer() -> void:
	_copyright_label = _label("", 19, TEXT_FAINT, true, _font_body)
	_copyright_label.name = "Copyright"
	add_child(_copyright_label)


func _build_audio_cues() -> void:
	_whoosh_player = AudioStreamPlayer.new()
	_whoosh_player.name = "WordmarkWhoosh"
	_whoosh_player.volume_db = WORDMARK_WHOOSH_VOLUME_DB
	_whoosh_player.max_polyphony = 1
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = WORDMARK_WHOOSH_MIX_RATE
	generator.buffer_length = WORDMARK_WHOOSH_SECONDS + 0.18
	_whoosh_player.stream = generator
	add_child(_whoosh_player)


func _layout_screen() -> void:
	if _version_group == null or _brand_group == null or _update_group == null or _copyright_label == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT
	var scale_value := _ui_scale()
	_layout_version(scale_value)
	_layout_top_right(viewport_size, scale_value)
	_layout_brand(viewport_size, scale_value)
	_layout_updater(viewport_size, scale_value)
	_layout_footer(viewport_size, scale_value)


func _layout_version(scale_value: float) -> void:
	_version_group.position = Vector2(56.0, 46.0) * scale_value
	_version_group.size = Vector2(460.0, 34.0) * scale_value
	_version_label.position = Vector2.ZERO
	_version_label.size = Vector2(460.0, 30.0) * scale_value
	_apply_label_size(_version_label, 24, _font_button)


func _layout_top_right(viewport_size: Vector2, scale_value: float) -> void:
	var perf_size := Vector2(430.0, 24.0) * scale_value
	_perf_label.position = Vector2(viewport_size.x - perf_size.x - 58.0 * scale_value, 18.0 * scale_value)
	_perf_label.size = perf_size
	_apply_label_size(_perf_label, 17, _font_body)

	var spinner_size := Vector2(42.0, 42.0) * scale_value
	_corner_spinner.position = Vector2(viewport_size.x - spinner_size.x - 58.0 * scale_value, 55.0 * scale_value)
	_corner_spinner.size = spinner_size
	_corner_spinner.custom_minimum_size = spinner_size
	_corner_spinner.pivot_offset = spinner_size * 0.5
	_corner_spinner.ring_width = maxf(3.0, 5.0 * scale_value)


func _layout_brand(viewport_size: Vector2, scale_value: float) -> void:
	var logo_size := roundf(StartupBrandRenderer.LOGO_BASE_SIZE * scale_value)
	var gap_size := roundf(StartupBrandRenderer.GAP_BASE_SIZE * scale_value)
	var texture_size := StartupBrandRenderer.WORDMARK_BASE_SIZE
	var wordmark_height := logo_size
	var wordmark_width := roundf(wordmark_height * texture_size.x / maxf(1.0, texture_size.y))
	var total_width := logo_size + gap_size + wordmark_width
	var max_total_width := viewport_size.x * 0.68
	if total_width > max_total_width:
		var fit_scale := max_total_width / total_width
		logo_size = roundf(logo_size * fit_scale)
		gap_size = roundf(gap_size * fit_scale)
		wordmark_height = logo_size
		wordmark_width = roundf(wordmark_height * texture_size.x / maxf(1.0, texture_size.y))
		total_width = logo_size + gap_size + wordmark_width
	var brand_height := maxf(logo_size, wordmark_height)
	_brand_group.position = Vector2(roundf((viewport_size.x - total_width) * 0.5), roundf(viewport_size.y * 0.5 - brand_height * 0.5))
	_brand_group.size = Vector2(total_width, brand_height)

	_brand_scale_value = scale_value
	var logo_home_position := Vector2(0.0, roundf((brand_height - logo_size) * 0.5))
	var wordmark_home_position := Vector2(logo_size + gap_size, roundf((brand_height - wordmark_height) * 0.5))
	_brand_logo_panel.size = Vector2(logo_size, logo_size)
	_brand_logo_panel.pivot_offset = Vector2(logo_size * 0.5, logo_size * 0.88)
	for index in range(_logo_depth_layers.size()):
		var depth_layer := _logo_depth_layers[index]
		var depth_offset := Vector2(float(index + 1) * 2.0, float(index + 1) * 3.0) * scale_value
		depth_layer.position = depth_offset
		depth_layer.size = _brand_logo_panel.size
	_brand_logo_texture.position = Vector2.ZERO
	_brand_logo_texture.size = _brand_logo_panel.size
	_brand_initials.position = Vector2.ZERO
	_brand_initials.size = _brand_logo_panel.size
	_apply_label_size(_brand_initials, 48, _font_menu)

	_wordmark_container.size = Vector2(wordmark_width, wordmark_height)
	_wordmark_container.pivot_offset = _wordmark_container.size * 0.5
	StartupBrandRenderer.sync_wordmark_container(_wordmark_container)
	_wordmark_home_position = wordmark_home_position
	_logo_home_position = logo_home_position
	if _brand_montage_started and not _brand_montage_finished:
		_wordmark_start_position = Vector2(viewport_size.x - _brand_group.position.x + 180.0 * scale_value, _wordmark_home_position.y)
		_logo_start_position = Vector2(_logo_home_position.x, -_brand_group.position.y - _brand_logo_panel.size.y * 1.65)
	elif _brand_montage_finished:
		_finish_brand_montage()
	else:
		_brand_logo_panel.position = _logo_home_position
		_wordmark_container.position = _wordmark_home_position


func _layout_updater(viewport_size: Vector2, scale_value: float) -> void:
	var ring_size := Vector2(38.0, 38.0) * scale_value
	var group_left := 58.0 * scale_value
	var group_right := 58.0 * scale_value
	var group_size := Vector2(maxf(360.0 * scale_value, viewport_size.x - group_left - group_right), 46.0 * scale_value)
	_update_group.position = Vector2(group_left, viewport_size.y - group_size.y - 50.0 * scale_value)
	_update_group.size = group_size

	_update_ring.position = Vector2.ZERO
	_update_ring.size = ring_size
	_update_ring.custom_minimum_size = ring_size
	_update_ring.pivot_offset = ring_size * 0.5
	_update_ring.ring_width = maxf(3.0, 5.0 * scale_value)
	_update_ring_label.position = Vector2.ZERO
	_update_ring_label.size = ring_size
	_apply_label_size(_update_ring_label, 11, _font_button)
	_apply_label_size(_update_title_label, 23, _font_button)
	_apply_label_size(_update_status_label, 23, _font_body)

	var title_x := ring_size.x + 18.0 * scale_value
	var title_font := _update_title_label.get_theme_font("font")
	var title_font_size := _update_title_label.get_theme_font_size("font_size")
	var title_width := 150.0 * scale_value
	if title_font:
		title_width = ceilf(title_font.get_string_size(_update_title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size).x) + 4.0 * scale_value
	var status_gap := 8.0 * scale_value
	var status_x := title_x + title_width + status_gap
	_update_title_label.position = Vector2(title_x, 1.0 * scale_value)
	_update_title_label.size = Vector2(title_width, 38.0 * scale_value)
	_update_status_label.position = Vector2(status_x, 1.0 * scale_value)
	_update_status_label.size = Vector2(maxf(220.0 * scale_value, group_size.x - status_x), 38.0 * scale_value)
	_set_update_progress(_current_update_progress())


func _layout_footer(viewport_size: Vector2, scale_value: float) -> void:
	var label_size := Vector2(340.0, 30.0) * scale_value
	_copyright_label.position = Vector2(viewport_size.x - label_size.x - 72.0 * scale_value, viewport_size.y - 76.0 * scale_value)
	_copyright_label.size = label_size
	_copyright_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_label_size(_copyright_label, 19, _font_body)


func _prepare_brand_montage() -> void:
	if _brand_group == null or _wordmark_container == null or _brand_logo_panel == null:
		return
	_brand_montage_started = true
	_brand_montage_finished = false
	_wordmark_home_position = _wordmark_container.position
	_logo_home_position = _brand_logo_panel.position
	_wordmark_trails.clear()
	for index in range(1, 4):
		var trail := _wordmark_container.get_node_or_null("WordmarkTrail%d" % index) as TextureRect
		if trail != null:
			_wordmark_trails.append(trail)
	_wordmark_glow = _wordmark_container.get_node_or_null("WordmarkGlow") as TextureRect

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT
	_wordmark_start_position = Vector2(viewport_size.x - _brand_group.position.x + 180.0 * _brand_scale_value, _wordmark_home_position.y)
	_logo_start_position = Vector2(_logo_home_position.x, -_brand_group.position.y - _brand_logo_panel.size.y * 1.65)
	_apply_wordmark_intro(0.0)
	_apply_logo_drop(0.0)


func _play_brand_montage() -> void:
	_play_wordmark_whoosh()
	var wordmark_tween := create_tween()
	wordmark_tween.set_ignore_time_scale(true)
	wordmark_tween.tween_method(Callable(self, "_apply_wordmark_intro"), 0.0, 1.0, WORDMARK_MONTAGE_SECONDS)

	var logo_tween := create_tween()
	logo_tween.set_ignore_time_scale(true)
	logo_tween.tween_interval(LOGO_DROP_DELAY_SECONDS)
	logo_tween.tween_method(Callable(self, "_apply_logo_drop"), 0.0, 1.0, LOGO_DROP_SECONDS)
	logo_tween.tween_callback(Callable(self, "_finish_brand_montage"))


func _play_wordmark_whoosh() -> void:
	if _whoosh_player == null or _whoosh_player.stream == null:
		return
	_whoosh_player.stop()
	_whoosh_player.play()
	var playback := _whoosh_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_capacity := playback.get_frames_available()
	if frame_capacity <= 0:
		return
	var frame_count := mini(int(WORDMARK_WHOOSH_SECONDS * WORDMARK_WHOOSH_MIX_RATE), frame_capacity)
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	var phase := 0.0
	var smoothed_noise := 0.0
	for frame_index in range(frame_count):
		var t := float(frame_index) / maxf(1.0, float(frame_count - 1))
		var attack := clampf(t / 0.08, 0.0, 1.0)
		var release := pow(1.0 - t, 1.65)
		var envelope := attack * release
		var frequency := lerpf(1680.0, 430.0, _ease_out_cubic(t))
		phase = fmod(phase + frequency / WORDMARK_WHOOSH_MIX_RATE, 1.0)
		smoothed_noise = lerpf(smoothed_noise, _logo_idle_rng.randf_range(-1.0, 1.0), 0.24)
		var tone := sin(phase * TAU) * 0.34
		var air := smoothed_noise * (0.58 + 0.22 * sin(t * PI))
		var sample := (tone + air) * envelope * 0.18
		frames[frame_index] = Vector2(sample, sample)
	playback.push_buffer(frames)


func _apply_wordmark_intro(value: float) -> void:
	if _wordmark_container == null:
		return
	var t := clampf(value, 0.0, 1.0)
	var squash := Vector2.ONE
	var local_offset := Vector2.ZERO
	if t < 0.70:
		var q := t / 0.70
		var e := _ease_out_expo(q)
		_wordmark_container.position = _wordmark_start_position.lerp(_wordmark_home_position + Vector2(-32.0 * _brand_scale_value, 0.0), e)
		squash = Vector2(1.28 - 0.20 * e, 0.72 + 0.23 * e)
		_wordmark_container.rotation_degrees = lerpf(-2.2, 0.8, e)
	elif t < 0.86:
		var q := (t - 0.70) / 0.16
		var e := _ease_out_cubic(q)
		_wordmark_container.position = (_wordmark_home_position + Vector2(-32.0 * _brand_scale_value, 0.0)).lerp(_wordmark_home_position + Vector2(14.0 * _brand_scale_value, 0.0), e)
		squash = Vector2(1.08 - 0.16 * e, 0.95 + 0.15 * e)
		_wordmark_container.rotation_degrees = lerpf(0.8, -0.35, e)
	else:
		var q := (t - 0.86) / 0.14
		var e := _ease_out_cubic(q)
		_wordmark_container.position = (_wordmark_home_position + Vector2(14.0 * _brand_scale_value, 0.0)).lerp(_wordmark_home_position, e)
		squash = Vector2(0.92 + 0.08 * e, 1.10 - 0.10 * e)
		_wordmark_container.rotation_degrees = lerpf(-0.35, 0.0, e)
	_wordmark_container.scale = squash
	_set_canvas_alpha(_wordmark_container, clampf(t * 2.8, 0.0, 1.0))
	if _wordmark_glow != null:
		_wordmark_glow.modulate = Color(0.760, 0.840, 1.0, 0.14 + 0.14 * _ease_out_cubic(t))
	for index in range(_wordmark_trails.size()):
		var trail := _wordmark_trails[index]
		var trail_strength := clampf((1.0 - t) * (0.22 - float(index) * 0.045), 0.0, 0.22)
		local_offset = Vector2(float(index + 1) * 34.0 * _brand_scale_value * (1.0 - t), 0.0)
		trail.position = local_offset
		trail.scale = Vector2(1.0 + 0.05 * float(index + 1) * (1.0 - t), 1.0)
		trail.modulate = Color(0.560, 0.660, 0.850, trail_strength)


func _apply_logo_drop(value: float) -> void:
	if _brand_logo_panel == null:
		return
	var t := clampf(value, 0.0, 1.0)
	var scale_value := Vector2.ONE
	if t < 0.66:
		var q := t / 0.66
		var e := q * q
		_brand_logo_panel.position = _logo_start_position.lerp(_logo_home_position + Vector2(0.0, 24.0 * _brand_scale_value), e)
		scale_value = Vector2(0.86 + 0.08 * e, 1.20 - 0.10 * e)
		_brand_logo_panel.rotation_degrees = lerpf(-8.0, 3.0, e)
		_set_canvas_alpha(_brand_logo_panel, clampf(q * 1.8, 0.0, 1.0))
		_sync_logo_depth_layers(1.35 - 0.20 * e)
	elif t < 0.78:
		var q := (t - 0.66) / 0.12
		var e := _ease_out_cubic(q)
		_brand_logo_panel.position = (_logo_home_position + Vector2(0.0, 24.0 * _brand_scale_value)).lerp(_logo_home_position + Vector2(0.0, 10.0 * _brand_scale_value), e)
		scale_value = Vector2(1.24 - 0.18 * e, 0.76 + 0.18 * e)
		_brand_logo_panel.rotation_degrees = lerpf(3.0, -1.2, e)
		_set_canvas_alpha(_brand_logo_panel, 1.0)
		_sync_logo_depth_layers(1.50)
	elif t < 0.91:
		var q := (t - 0.78) / 0.13
		var e := _ease_out_cubic(q)
		_brand_logo_panel.position = (_logo_home_position + Vector2(0.0, 10.0 * _brand_scale_value)).lerp(_logo_home_position + Vector2(0.0, -14.0 * _brand_scale_value), e)
		scale_value = Vector2(1.06 - 0.12 * e, 0.94 + 0.18 * e)
		_brand_logo_panel.rotation_degrees = lerpf(-1.2, 0.55, e)
		_sync_logo_depth_layers(1.18)
	else:
		var q := (t - 0.91) / 0.09
		var e := _ease_out_cubic(q)
		_brand_logo_panel.position = (_logo_home_position + Vector2(0.0, -14.0 * _brand_scale_value)).lerp(_logo_home_position, e)
		scale_value = Vector2(0.94 + 0.06 * e, 1.12 - 0.12 * e)
		_brand_logo_panel.rotation_degrees = lerpf(0.55, 0.0, e)
		_sync_logo_depth_layers(1.0)
	_brand_logo_panel.scale = scale_value


func _finish_brand_montage() -> void:
	_brand_montage_finished = true
	if _wordmark_container != null:
		_wordmark_container.position = _wordmark_home_position
		_wordmark_container.scale = Vector2.ONE
		_wordmark_container.rotation_degrees = 0.0
		_set_canvas_alpha(_wordmark_container, 1.0)
	if _wordmark_glow != null:
		_wordmark_glow.modulate = Color(0.760, 0.840, 1.0, 0.26)
	for trail in _wordmark_trails:
		trail.position = Vector2.ZERO
		trail.scale = Vector2.ONE
		trail.modulate = Color(0.560, 0.660, 0.850, 0.0)
	if _brand_logo_panel != null:
		_brand_logo_panel.position = _logo_home_position
		_brand_logo_panel.scale = Vector2.ONE
		_brand_logo_panel.rotation_degrees = 0.0
		_set_canvas_alpha(_brand_logo_panel, 1.0)
	_sync_logo_depth_layers(1.0)
	_prime_logo_idle_wobble()


func _prime_logo_idle_wobble() -> void:
	_logo_idle_time = 0.0
	_logo_wobble_duration = 0.0
	_logo_wobble_elapsed = 0.0
	_logo_wobble_wait = LOGO_IDLE_FIRST_WAIT


func _start_logo_idle_wobble() -> void:
	_logo_wobble_elapsed = 0.0
	_logo_wobble_duration = _logo_idle_rng.randf_range(0.36, 0.62)
	_logo_wobble_strength = _logo_idle_rng.randf_range(0.018, 0.040)
	if _logo_idle_rng.randf_range(0.0, 1.0) < 0.5:
		_logo_wobble_strength *= -1.0
	_logo_wobble_frequency = _logo_idle_rng.randf_range(3.0, 4.7)
	_logo_wobble_rotation = _logo_idle_rng.randf_range(-1.35, 1.35)
	_logo_wobble_offset = Vector2(
		_logo_idle_rng.randf_range(-2.4, 2.4),
		_logo_idle_rng.randf_range(-1.2, 1.8)
	) * _brand_scale_value


func _update_logo_idle_wobble(delta: float) -> void:
	if _brand_logo_panel == null or not _brand_montage_finished or _flow_finished:
		return
	_logo_idle_time += delta
	if _logo_wobble_duration <= 0.0:
		_logo_wobble_wait -= delta
		if _logo_wobble_wait <= 0.0:
			_start_logo_idle_wobble()
	if _logo_wobble_duration > 0.0:
		_logo_wobble_elapsed += delta
		var t := clampf(_logo_wobble_elapsed / maxf(_logo_wobble_duration, 0.001), 0.0, 1.0)
		var decay := pow(1.0 - t, 2.1)
		var elastic := sin(t * TAU * _logo_wobble_frequency)
		var squash := _logo_wobble_strength * decay * elastic
		var drift := sin((_logo_idle_time + _logo_idle_seed) * 2.2) * 0.003
		_brand_logo_panel.position = _logo_home_position + _logo_wobble_offset * decay * sin(t * TAU * 1.35)
		_brand_logo_panel.scale = Vector2(1.0 + squash * 0.72 + drift, 1.0 - squash * 0.52 - drift * 0.55)
		_brand_logo_panel.rotation_degrees = _logo_wobble_rotation * decay * sin(t * TAU * (_logo_wobble_frequency * 0.72))
		_sync_logo_depth_layers(1.0 + absf(squash) * 0.42)
		if _logo_wobble_elapsed < _logo_wobble_duration:
			return
		_logo_wobble_duration = 0.0
		_logo_wobble_wait = _logo_idle_rng.randf_range(LOGO_IDLE_MIN_WAIT, LOGO_IDLE_MAX_WAIT)
	var settle := clampf(delta * 8.0, 0.0, 1.0)
	var idle_squash := sin((_logo_idle_time + _logo_idle_seed) * 2.0) * 0.003
	_brand_logo_panel.position = _brand_logo_panel.position.lerp(_logo_home_position, settle)
	_brand_logo_panel.scale = _brand_logo_panel.scale.lerp(Vector2(1.0 + idle_squash, 1.0 - idle_squash * 0.6), settle)
	_brand_logo_panel.rotation_degrees = lerpf(_brand_logo_panel.rotation_degrees, 0.0, settle)
	_sync_logo_depth_layers(1.0)


func _reset_logo_idle_pose() -> void:
	_logo_wobble_duration = 0.0
	_logo_wobble_elapsed = 0.0
	_logo_wobble_wait = 0.0
	if _brand_logo_panel == null:
		return
	_brand_logo_panel.position = _logo_home_position
	_brand_logo_panel.scale = Vector2.ONE
	_brand_logo_panel.rotation_degrees = 0.0
	_sync_logo_depth_layers(1.0)


func _sync_logo_depth_layers(depth_strength: float) -> void:
	for index in range(_logo_depth_layers.size()):
		var depth_layer := _logo_depth_layers[index]
		var depth_offset := Vector2(float(index + 1) * 2.0, float(index + 1) * 3.0) * _brand_scale_value * depth_strength
		depth_layer.position = depth_offset
		depth_layer.size = _brand_logo_panel.size if _brand_logo_panel != null else depth_layer.size


func _set_canvas_alpha(item: CanvasItem, alpha: float) -> void:
	if item == null:
		return
	var color := item.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	item.modulate = color


func _ease_out_expo(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _bind_i18n() -> void:
	var tree := get_tree()
	if tree:
		_i18n = tree.root.get_node_or_null("I18n")
	if _i18n and _i18n.has_signal("locale_changed"):
		var callable := Callable(self, "_on_locale_changed")
		if not _i18n.is_connected("locale_changed", callable):
			_i18n.connect("locale_changed", callable)


func _bind_hot_update_manager() -> void:
	var tree := get_tree()
	if tree:
		_manager = tree.root.get_node_or_null("HotUpdate")
	if _manager == null:
		_update_failed = true
		_update_complete = true
		_set_update_state("LOCAL CLIENT READY", "Hot update service is unavailable in this build.", 1.0)
		return
	_connect_manager_signal("status_changed", Callable(self, "_on_hot_update_status_changed"))
	_connect_manager_signal("manifest_ready", Callable(self, "_on_hot_update_manifest_ready"))
	_connect_manager_signal("update_failed", Callable(self, "_on_hot_update_failed"))
	_connect_manager_signal("update_installed", Callable(self, "_on_hot_update_installed"))
	_set_update_state("CHECKING CONTENT", "Contacting TX primary manifest.", 0.09)
	if _manager.has_method("check_for_updates"):
		var ok := bool(_manager.call("check_for_updates"))
		if not ok:
			_update_failed = true
			_update_complete = true
			_set_update_state("LOCAL CLIENT READY", "Update check did not start; continuing with bundled content.", 1.0)
	else:
		_update_failed = true
		_update_complete = true
		_set_update_state("LOCAL CLIENT READY", "Update manager is missing check_for_updates().", 1.0)


func _connect_manager_signal(signal_name: String, callable: Callable) -> void:
	if _manager == null or not _manager.has_signal(signal_name):
		return
	if not _manager.is_connected(signal_name, callable):
		_manager.connect(signal_name, callable)


func _on_hot_update_status_changed(message: String) -> void:
	var progress := _progress_from_message(message)
	var title := "CHECKING CONTENT"
	if message.begins_with("Downloading"):
		title = "DOWNLOADING PATCH"
	elif message.contains("Trying mirror"):
		title = "SWITCHING MIRROR"
	elif message.contains("installed"):
		title = "PATCH INSTALLED"
	elif message.contains("manifest checked"):
		title = "MANIFEST READY"
	_set_update_state(title, message, progress if progress >= 0.0 else _current_update_progress())


func _on_hot_update_manifest_ready(_manifest: Dictionary, pending_packages: Array) -> void:
	if pending_packages.is_empty():
		_update_complete = true
		_set_update_state("CONTENT UP TO DATE", "No required package download is needed.", 1.0)
		return
	_installing_update = true
	_set_update_state("INSTALLING PATCH", "%d required package(s) will be verified before launch." % pending_packages.size(), maxf(_current_update_progress(), 0.18))
	if _manager and _manager.has_method("install_pending_updates"):
		_manager.call_deferred("install_pending_updates")
	else:
		_update_failed = true
		_update_complete = true
		_set_update_state("LOCAL CLIENT READY", "Install command is unavailable; continuing with bundled content.", 1.0)


func _on_hot_update_failed(message: String) -> void:
	_update_failed = true
	_update_complete = true
	_set_update_state("LOCAL CLIENT READY", "Update failed: %s" % message, 1.0)


func _on_hot_update_installed(restart_required: bool) -> void:
	_restart_required = restart_required
	_update_complete = true
	_installing_update = false
	if _restart_required:
		_set_update_state("PATCH INSTALLED", "Content will be active on next launch.", 1.0)
	else:
		_set_update_state("PATCH READY", "Installed update packages are ready.", 1.0)


func _run_startup_flow() -> void:
	var started_msec := Time.get_ticks_msec()
	while not _flow_finished:
		var elapsed := float(Time.get_ticks_msec() - started_msec) / 1000.0
		var minimum_done := elapsed >= MIN_DISPLAY_SECONDS
		var update_done := _update_complete or elapsed >= UPDATE_TIMEOUT_SECONDS
		var scene_ready := _is_next_scene_ready()
		if minimum_done and update_done and scene_ready:
			break
		await get_tree().process_frame
	if not _update_complete:
		_update_failed = true
		_update_complete = true
		_set_update_state("LOCAL CLIENT READY", "Update check is still running; continuing with bundled content.", 1.0)
	await get_tree().create_timer(POST_READY_HOLD_SECONDS).timeout
	await _transition_to_intro_scene()


func _transition_to_intro_scene() -> void:
	_flow_finished = true
	_reset_logo_idle_pose()
	_set_update_state("LOADING INTRO", "Starting studio intro sequence.", 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_brand_group, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_version_group, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_update_group, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_perf_label, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_corner_spinner, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_copyright_label, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade.finished
	var packed_scene := _get_next_packed_scene()
	if packed_scene == null:
		push_error("StartupSplash: failed to load next scene: %s" % NEXT_SCENE_PATH)
		return
	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("StartupSplash: change_scene_to_packed failed: %s" % error_string(error))


func _request_next_scene_preload() -> void:
	if _scene_load_requested:
		return
	var error := ResourceLoader.load_threaded_request(NEXT_SCENE_PATH, "PackedScene")
	if error == OK:
		_scene_load_requested = true
	else:
		push_warning("StartupSplash: threaded preload failed; direct load will be used: %s" % NEXT_SCENE_PATH)


func _is_next_scene_ready() -> bool:
	if not _scene_load_requested:
		return true
	var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE_PATH)
	return status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED


func _get_next_packed_scene() -> PackedScene:
	if _scene_load_requested:
		var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var threaded_scene := ResourceLoader.load_threaded_get(NEXT_SCENE_PATH) as PackedScene
			if threaded_scene:
				return threaded_scene
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("StartupSplash: threaded scene preload failed; falling back to direct scene load.")
	return ResourceLoader.load(NEXT_SCENE_PATH, "PackedScene") as PackedScene


func _update_ring_motion(_delta: float) -> void:
	if _update_ring == null:
		return
	_update_ring.rotation = 0.0
	if _update_complete and not _update_failed:
		_update_ring.progress_color = UPDATE_RING_PROGRESS_COLOR
		_update_ring.set_progress(1.0)
	else:
		_update_ring.progress_color = UPDATE_RING_PROGRESS_COLOR
		_update_ring.queue_redraw()


func _update_corner_spinner(delta: float) -> void:
	if _corner_spinner == null:
		return
	_corner_spinner.rotation += delta * 0.72
	_corner_spinner.queue_redraw()


func _update_performance_label() -> void:
	if _perf_label == null:
		return
	var fps := "N/A" if Engine.is_editor_hint() else str(Engine.get_frames_per_second())
	_perf_label.text = "FPS %s  |  GPU --  |  CPU --  |  %s" % [fps, _startup_text("perf_latency")]


func _refresh_localized_text() -> void:
	if _version_label:
		_version_label.text = _startup_text("version") % _app_version()
	if _route_label:
		_route_label.text = _startup_text("route")
	if _update_title_label:
		_update_title_label.text = _startup_text("hot_update_title")
	if _update_status_label:
		_update_status_label.text = _localized_update_status(_last_update_title, _last_update_detail)
	if _copyright_label:
		_copyright_label.text = _startup_text("copyright")
	_update_performance_label()


func _set_update_state(title: String, detail: String, progress: float) -> void:
	_last_update_title = title
	_last_update_detail = detail
	_last_update_progress = progress
	if _update_status_label:
		_update_status_label.text = _localized_update_status(title, detail)
	_set_update_progress(progress)


func _localized_update_status(title: String, detail: String) -> String:
	match title:
		"DOWNLOADING PATCH":
			return _startup_text("update_downloading")
		"INSTALLING PATCH":
			return _startup_text("update_installing")
		"SWITCHING MIRROR":
			return _startup_text("update_switching")
		"PATCH INSTALLED":
			return _startup_text("update_installed")
		"PATCH READY":
			return _startup_text("update_ready")
		"CONTENT UP TO DATE":
			return _startup_text("update_current")
		"LOCAL CLIENT READY":
			return _startup_text("update_local")
		"MANIFEST READY":
			return _startup_text("update_manifest")
		"LOADING INTRO":
			return _startup_text("update_intro")
		_:
			if detail.begins_with("Contacting") or detail.contains("manifest"):
				return _startup_text("update_checking")
			return _startup_text("update_installing")


func _set_update_progress(value: float) -> void:
	if _update_ring == null:
		return
	var clamped := clampf(value, 0.0, 1.0)
	_update_ring.set_meta("progress", clamped)
	_update_ring.set_progress(clamped)
	if _update_ring_label:
		_update_ring_label.text = "OK" if clamped >= 0.995 else str(clampi(roundi(clamped * 100.0), 1, 99))


func _current_update_progress() -> float:
	if _update_ring == null or not _update_ring.has_meta("progress"):
		return _last_update_progress
	return float(_update_ring.get_meta("progress"))


func _progress_from_message(message: String) -> float:
	var percent_index := message.find("%")
	if percent_index <= 0:
		return -1.0
	var start := percent_index - 1
	while start >= 0:
		var code := message.unicode_at(start)
		if code < 48 or code > 57:
			break
		start -= 1
	var digits := message.substr(start + 1, percent_index - start - 1)
	if digits.is_empty() or not digits.is_valid_int():
		return -1.0
	return clampf(float(digits.to_int()) / 100.0, 0.0, 1.0)


func _create_background_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.70, 1.0])
	gradient.colors = PackedColorArray([
		BACKGROUND_TOP_COLOR,
		BACKGROUND_MID_COLOR,
		BACKGROUND_MID_COLOR,
		BACKGROUND_BOTTOM_COLOR,
	])
	var texture := GradientTexture2D.new()
	texture.width = 16
	texture.height = 1024
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture


func _startup_text(key: String) -> String:
	var locale := _startup_locale()
	var table: Dictionary = STARTUP_TEXT.get(locale, STARTUP_TEXT["en"])
	return str(table.get(key, STARTUP_TEXT["en"].get(key, key)))


func _startup_locale() -> String:
	if _i18n and _i18n.get("current_locale") != null:
		var locale := str(_i18n.get("current_locale"))
		return "zh" if locale.begins_with("zh") else "en"
	var os_lang := OS.get_locale_language().to_lower()
	return "zh" if os_lang.begins_with("zh") else "en"


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_text()
	_layout_screen()


func _label(text: String, font_size: int, color: Color, bold: bool, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.10))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _apply_label_size(label: Label, base_size: int, font: Font) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", max(9, roundi(float(base_size) * _ui_scale())))
	if font:
		label.add_theme_font_override("font", font)


func _load_fonts() -> void:
	_font_heading = _load_font("res://assets/fonts/Saira-9.woff2")
	_font_body = _load_font("res://assets/fonts/SairaCondensed-Medium.woff2")
	_font_button = _load_font("res://assets/fonts/SairaCondensed-Bold.woff2")
	_font_menu = _load_font("res://assets/fonts/SairaExtraCondensed-Bold.woff2")


func _load_font(path: String) -> Font:
	var resource := ResourceLoader.load(path)
	return resource if resource is Font else null


func _app_version() -> String:
	# Prefer the running build's stamped version. build_info.json ships inside the
	# core_patch hot-update pack, so this label updates after an incremental update
	# (+ restart) instead of being frozen at the bootstrap's config/version.
	var stamped := BuildInfo.content_version().strip_edges()
	if not stamped.is_empty() and stamped != "0.0.0":
		return stamped
	var value := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return value if not value.is_empty() else "dev"


func _ui_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y), 0.72, 1.55)


func _on_viewport_size_changed() -> void:
	_layout_screen()
