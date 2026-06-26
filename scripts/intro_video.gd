extends Control
class_name IntroVideo

const NEXT_SCENE_PATH := "res://scenes/level/level.tscn"
const MAIN_MENU_TRANSITION_COVER_PATH := "res://assets/ui/main_menu_transition_cover.png"
const VIDEO_FAILSAFE_SECONDS := 8.0
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const BADGE_BASE_HEIGHT := 120.0
const BADGE_BASE_MARGIN := Vector2(18.0, 18.0)
const BADGE_BASE_PADDING := Vector2(5.0, 5.0)
const BADGE_BASE_CORNER_RADIUS := 8.0
const BADGE_MIN_SCALE := 0.70
const BADGE_MAX_SCALE := 1.10
const DEFAULT_BADGE_ASPECT := 274.0 / 419.0
const WATERMARK_COVER_BASE_POSITION := Vector2(0.0, 12.0)
const WATERMARK_COVER_BASE_SIZE := Vector2(600.0, 172.0)
const WATERMARK_COVER_MIN_SCALE := 0.78
const WATERMARK_COVER_MAX_SCALE := 1.10
const INTRO_FADE_OUT_SECONDS := 0.42
const MAIN_SCENE_FADE_IN_SECONDS := 0.28
const INTRO_PRE_EXIT_SECONDS := 0.36
const INTRO_TRANSITION_COLOR := Color(0.200, 0.549, 0.965, 1.0)
const INTRO_FADE_COLOR := Color(0.200, 0.549, 0.965, 0.72)
const TRANSITION_LOADING_DOT_COUNT := 3
const TRANSITION_LOADING_DOT_SIZE := 12.0
const TRANSITION_LOADING_DOT_SPACING := 10.0
const TRANSITION_LOADING_BASE_MARGIN := Vector2(44.0, 40.0)
const TRANSITION_LOADING_MIN_SCALE := 0.78
const TRANSITION_LOADING_MAX_SCALE := 1.12
const TRANSITION_LOADING_PULSE_SPEED := 4.8

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var watermark_cover: TextureRect = get_node_or_null("WatermarkCover") as TextureRect
@onready var transition_fade: ColorRect = get_node_or_null("TransitionFade") as ColorRect
@onready var transition_snapshot: TextureRect = get_node_or_null("TransitionSnapshot") as TextureRect
@onready var rating_badge_background: Panel = $RatingBadgeBackground
@onready var rating_badge: TextureRect = $RatingBadge

var _transitioning := false
var _next_scene_load_requested := false
var _badge_background_style: StyleBoxFlat = null
var transition_loading_indicator: Control = null
var _transition_loading_dots: Array[Panel] = []
var _transition_loading_elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_configure_video_player()
	_configure_watermark_cover()
	_configure_rating_badge()
	_configure_transition_fade()
	_configure_transition_snapshot()
	_configure_transition_loading_indicator()
	set_process(false)
	RenderingServer.set_default_clear_color(INTRO_TRANSITION_COLOR)
	_update_intro_overlay_layout()
	_request_next_scene_preload()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	if not video_player or video_player.stream == null:
		push_warning("IntroVideo: intro video stream is missing; continuing to main scene.")
		call_deferred("_finish_intro")
		return
	if not video_player.finished.is_connected(_finish_intro):
		video_player.finished.connect(_finish_intro)
	video_player.play()
	_start_pre_exit_timer()
	_start_failsafe_timer()


func _process(delta: float) -> void:
	if transition_loading_indicator == null or not transition_loading_indicator.visible:
		return
	_transition_loading_elapsed += delta
	_update_transition_loading_animation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish_intro()
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed:
		get_viewport().set_input_as_handled()
		return


func _configure_video_player() -> void:
	if not video_player:
		return
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.offset_left = 0.0
	video_player.offset_top = 0.0
	video_player.offset_right = 0.0
	video_player.offset_bottom = 0.0
	video_player.expand = true
	video_player.loop = false


func _configure_watermark_cover() -> void:
	if watermark_cover == null:
		watermark_cover = TextureRect.new()
		watermark_cover.name = "WatermarkCover"
		add_child(watermark_cover)
		if video_player:
			move_child(watermark_cover, min(video_player.get_index() + 1, get_child_count() - 1))
	watermark_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	watermark_cover.texture = _create_watermark_cover_texture()
	watermark_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watermark_cover.stretch_mode = TextureRect.STRETCH_SCALE
	watermark_cover.z_index = 8


func _create_watermark_cover_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.54, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.060, 0.400, 0.890, 0.96),
		Color(0.080, 0.440, 0.910, 0.92),
		Color(0.110, 0.485, 0.925, 0.55),
		Color(0.150, 0.530, 0.940, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 160
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	texture.gradient = gradient
	return texture


func _configure_rating_badge() -> void:
	if rating_badge_background:
		rating_badge_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rating_badge_background.z_index = 9
		_badge_background_style = StyleBoxFlat.new()
		_badge_background_style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
		_badge_background_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		rating_badge_background.add_theme_stylebox_override("panel", _badge_background_style)
	if not rating_badge:
		return
	rating_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rating_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rating_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rating_badge.z_index = 10


func _configure_transition_fade() -> void:
	if transition_fade == null:
		transition_fade = ColorRect.new()
		transition_fade.name = "TransitionFade"
		add_child(transition_fade)
	transition_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_fade.offset_left = 0.0
	transition_fade.offset_top = 0.0
	transition_fade.offset_right = 0.0
	transition_fade.offset_bottom = 0.0
	transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_fade.color = INTRO_FADE_COLOR
	transition_fade.modulate.a = 0.0
	transition_fade.z_index = 20


func _configure_transition_snapshot() -> void:
	if transition_snapshot == null:
		transition_snapshot = TextureRect.new()
		transition_snapshot.name = "TransitionSnapshot"
		add_child(transition_snapshot)
	transition_snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_snapshot.offset_left = 0.0
	transition_snapshot.offset_top = 0.0
	transition_snapshot.offset_right = 0.0
	transition_snapshot.offset_bottom = 0.0
	transition_snapshot.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_snapshot.texture = _get_transition_cover_texture()
	transition_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition_snapshot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	transition_snapshot.modulate.a = 0.0
	transition_snapshot.visible = transition_snapshot.texture != null
	transition_snapshot.z_index = 21


func _configure_transition_loading_indicator() -> void:
	if transition_loading_indicator == null:
		transition_loading_indicator = Control.new()
		transition_loading_indicator.name = "TransitionLoading"
		add_child(transition_loading_indicator)
		_transition_loading_dots.clear()
		for index in range(TRANSITION_LOADING_DOT_COUNT):
			var dot: Panel = Panel.new()
			dot.name = "LoadingDot%d" % [index + 1]
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			transition_loading_indicator.add_child(dot)
			_transition_loading_dots.append(dot)
	transition_loading_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_loading_indicator.z_index = 22
	transition_loading_indicator.visible = false
	transition_loading_indicator.modulate.a = 0.0
	_update_transition_loading_layout()


func _set_transition_loading_visible(value: bool) -> void:
	if transition_loading_indicator == null:
		return
	transition_loading_indicator.visible = value
	_transition_loading_elapsed = 0.0
	set_process(value)
	if value:
		transition_loading_indicator.modulate.a = 0.0
		_update_transition_loading_layout()
		_update_transition_loading_animation()
	else:
		transition_loading_indicator.modulate.a = 0.0


func _update_transition_loading_layout() -> void:
	if transition_loading_indicator == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_value: float = minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	scale_value = clampf(scale_value, TRANSITION_LOADING_MIN_SCALE, TRANSITION_LOADING_MAX_SCALE)
	var dot_size: float = TRANSITION_LOADING_DOT_SIZE * scale_value
	var separation: float = TRANSITION_LOADING_DOT_SPACING * scale_value
	var dot_count: int = _transition_loading_dots.size()
	var total_width: float = dot_size * float(dot_count) + separation * float(maxi(0, dot_count - 1))
	var total_size: Vector2 = Vector2(total_width, dot_size)
	var margin: Vector2 = TRANSITION_LOADING_BASE_MARGIN * scale_value
	transition_loading_indicator.position = viewport_size - margin - total_size
	transition_loading_indicator.size = total_size
	for index in range(dot_count):
		var dot: Panel = _transition_loading_dots[index]
		dot.position = Vector2(float(index) * (dot_size + separation), 0.0)
		dot.size = Vector2(dot_size, dot_size)
		dot.pivot_offset = dot.size * 0.5
		dot.add_theme_stylebox_override("panel", _create_transition_loading_dot_style(dot_size, scale_value))


func _update_transition_loading_animation() -> void:
	var dot_count: int = _transition_loading_dots.size()
	for index in range(dot_count):
		var dot: Panel = _transition_loading_dots[index]
		var phase: float = fmod(_transition_loading_elapsed * TRANSITION_LOADING_PULSE_SPEED - float(index) * 0.72, PI * 2.0)
		var wave: float = (sin(phase) + 1.0) * 0.5
		dot.modulate.a = lerpf(0.36, 1.0, wave)
		var dot_scale: float = lerpf(0.78, 1.08, wave)
		dot.scale = Vector2(dot_scale, dot_scale)


func _create_transition_loading_dot_style(dot_size: float, scale_value: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.94)
	style.set_corner_radius_all(int(round(dot_size * 0.5)))
	style.shadow_color = Color(0.02, 0.12, 0.25, 0.22)
	style.shadow_size = int(round(5.0 * scale_value))
	style.shadow_offset = Vector2(0.0, 1.5 * scale_value)
	return style


func _is_transition_snapshot_ready() -> bool:
	return transition_snapshot != null and transition_snapshot.texture != null


func _get_transition_cover_texture() -> Texture2D:
	if not ResourceLoader.exists(MAIN_MENU_TRANSITION_COVER_PATH):
		return null
	return ResourceLoader.load(MAIN_MENU_TRANSITION_COVER_PATH, "Texture2D") as Texture2D


func _request_next_scene_preload() -> void:
	if _next_scene_load_requested:
		return
	var err := ResourceLoader.load_threaded_request(NEXT_SCENE_PATH, "PackedScene")
	if err == OK:
		_next_scene_load_requested = true
	else:
		push_warning("IntroVideo: threaded preload failed; falling back to direct scene load: %s" % NEXT_SCENE_PATH)


func _start_pre_exit_timer() -> void:
	if not video_player or video_player.stream == null:
		return
	var stream_length := video_player.get_stream_length()
	if stream_length <= INTRO_PRE_EXIT_SECONDS:
		return
	var timer := get_tree().create_timer(maxf(0.1, stream_length - INTRO_PRE_EXIT_SECONDS))
	timer.timeout.connect(func() -> void:
		if not _transitioning and video_player and video_player.is_playing():
			_finish_intro()
	)


func _start_failsafe_timer() -> void:
	var timer := get_tree().create_timer(VIDEO_FAILSAFE_SECONDS)
	timer.timeout.connect(func() -> void:
		if not _transitioning:
			_finish_intro()
	)


func _finish_intro() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _play_exit_transition()
	if video_player and video_player.is_playing():
		video_player.stop()
	await _change_to_next_scene()


func _change_to_next_scene() -> void:
	var packed_scene := _get_next_packed_scene()
	if packed_scene == null:
		push_error("IntroVideo: failed to load main scene: %s" % NEXT_SCENE_PATH)
		return
	var next_scene := packed_scene.instantiate()
	if next_scene == null:
		push_error("IntroVideo: failed to instantiate main scene: %s" % NEXT_SCENE_PATH)
		return
	var tree := get_tree()
	var root := tree.root
	var old_scene := tree.current_scene
	var root_cover: Control = _create_root_transition_cover()
	root.add_child(next_scene)
	root.add_child(root_cover)
	tree.current_scene = next_scene
	await tree.process_frame
	await tree.process_frame
	await _fade_out_root_transition_cover(root_cover)
	if old_scene and old_scene != next_scene and is_instance_valid(old_scene):
		old_scene.queue_free()


func _get_next_packed_scene() -> PackedScene:
	if _next_scene_load_requested:
		var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var threaded_scene := ResourceLoader.load_threaded_get(NEXT_SCENE_PATH) as PackedScene
			if threaded_scene:
				return threaded_scene
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("IntroVideo: threaded scene preload failed; falling back to direct scene load.")
	return ResourceLoader.load(NEXT_SCENE_PATH, "PackedScene") as PackedScene


func _create_root_transition_cover() -> Control:
	var texture: Texture2D = _get_transition_cover_texture()
	var cover: Control
	if texture:
		var image_cover: TextureRect = TextureRect.new()
		image_cover.texture = texture
		image_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover = image_cover
	else:
		var fallback_cover: Control = Control.new()
		var color_cover: ColorRect = ColorRect.new()
		color_cover.name = "BlueBackground"
		color_cover.color = INTRO_TRANSITION_COLOR
		color_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_cover.offset_left = 0.0
		color_cover.offset_top = 0.0
		color_cover.offset_right = 0.0
		color_cover.offset_bottom = 0.0
		fallback_cover.add_child(color_cover)
		_add_static_transition_loading_indicator(fallback_cover)
		cover = fallback_cover
	cover.name = "IntroSceneTransitionCover"
	cover.modulate.a = 1.0
	cover.z_index = 4096
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.offset_left = 0.0
	cover.offset_top = 0.0
	cover.offset_right = 0.0
	cover.offset_bottom = 0.0
	return cover


func _add_static_transition_loading_indicator(parent: Control) -> void:
	var loading: Control = Control.new()
	loading.name = "TransitionLoading"
	loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading.z_index = 1
	parent.add_child(loading)

	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_value: float = minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	scale_value = clampf(scale_value, TRANSITION_LOADING_MIN_SCALE, TRANSITION_LOADING_MAX_SCALE)
	var dot_size: float = TRANSITION_LOADING_DOT_SIZE * scale_value
	var separation: float = TRANSITION_LOADING_DOT_SPACING * scale_value
	var total_width: float = dot_size * float(TRANSITION_LOADING_DOT_COUNT) + separation * float(TRANSITION_LOADING_DOT_COUNT - 1)
	var total_size: Vector2 = Vector2(total_width, dot_size)
	var margin: Vector2 = TRANSITION_LOADING_BASE_MARGIN * scale_value
	loading.position = viewport_size - margin - total_size
	loading.size = total_size
	for index in range(TRANSITION_LOADING_DOT_COUNT):
		var dot: Panel = Panel.new()
		dot.name = "LoadingDot%d" % [index + 1]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(float(index) * (dot_size + separation), 0.0)
		dot.size = Vector2(dot_size, dot_size)
		dot.pivot_offset = dot.size * 0.5
		dot.scale = Vector2(0.92, 0.92)
		dot.modulate.a = lerpf(0.50, 1.0, float(index + 1) / float(TRANSITION_LOADING_DOT_COUNT))
		dot.add_theme_stylebox_override("panel", _create_transition_loading_dot_style(dot_size, scale_value))
		loading.add_child(dot)


func _fade_out_root_transition_cover(cover: Control) -> void:
	if cover == null or not is_instance_valid(cover):
		return
	cover.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(cover, "modulate:a", 0.0, MAIN_SCENE_FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(cover):
		cover.queue_free()


func _play_exit_transition() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var use_snapshot: bool = _is_transition_snapshot_ready()
	_set_transition_loading_visible(not use_snapshot)
	if use_snapshot:
		transition_snapshot.visible = true
		transition_snapshot.modulate.a = 0.0
		tween.tween_property(transition_snapshot, "modulate:a", 1.0, INTRO_FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif transition_fade:
		transition_fade.visible = true
		transition_fade.modulate.a = 0.0
		tween.tween_property(transition_fade, "modulate:a", 1.0, INTRO_FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if transition_loading_indicator:
			tween.tween_property(transition_loading_indicator, "modulate:a", 1.0, INTRO_FADE_OUT_SECONDS * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if video_player:
		tween.tween_property(video_player, "modulate:a", 0.0, INTRO_FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if watermark_cover:
		tween.tween_property(watermark_cover, "modulate:a", 0.0, INTRO_FADE_OUT_SECONDS * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if rating_badge:
		tween.tween_property(rating_badge, "modulate:a", 0.0, INTRO_FADE_OUT_SECONDS * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if rating_badge_background:
		tween.tween_property(rating_badge_background, "modulate:a", 0.0, INTRO_FADE_OUT_SECONDS * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _on_viewport_size_changed() -> void:
	_update_intro_overlay_layout()


func _update_intro_overlay_layout() -> void:
	_update_watermark_cover_layout()
	_update_rating_badge_layout()
	_update_transition_loading_layout()


func _update_watermark_cover_layout() -> void:
	if not watermark_cover:
		return
	var viewport_size := get_viewport_rect().size
	var scale_value := minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	scale_value = clampf(scale_value, WATERMARK_COVER_MIN_SCALE, WATERMARK_COVER_MAX_SCALE)
	watermark_cover.position = WATERMARK_COVER_BASE_POSITION * scale_value
	watermark_cover.size = WATERMARK_COVER_BASE_SIZE * scale_value


func _update_rating_badge_layout() -> void:
	if not rating_badge:
		return
	var viewport_size := get_viewport_rect().size
	var scale_value := minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	scale_value = clampf(scale_value, BADGE_MIN_SCALE, BADGE_MAX_SCALE)
	var margin := BADGE_BASE_MARGIN * scale_value
	var padding := BADGE_BASE_PADDING * scale_value
	var badge_height := BADGE_BASE_HEIGHT * scale_value
	var badge_size := Vector2(badge_height * _get_badge_aspect(), badge_height)
	var background_size := badge_size + padding * 2.0
	if rating_badge_background:
		rating_badge_background.position = margin
		rating_badge_background.size = background_size
		_update_badge_background_style(scale_value)
	rating_badge.position = margin + padding
	rating_badge.size = badge_size


func _get_badge_aspect() -> float:
	if rating_badge and rating_badge.texture:
		var texture_size := rating_badge.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			return texture_size.x / texture_size.y
	return DEFAULT_BADGE_ASPECT


func _update_badge_background_style(scale_value: float) -> void:
	if not _badge_background_style:
		return
	_badge_background_style.set_corner_radius_all(int(round(BADGE_BASE_CORNER_RADIUS * scale_value)))
	_badge_background_style.shadow_size = int(round(8.0 * scale_value))
	_badge_background_style.shadow_offset = Vector2(0.0, 2.0 * scale_value)


func get_rating_badge_layout_for_test() -> Dictionary:
	return {
		"aspect": _get_badge_aspect(),
		"badge_size": rating_badge.size if rating_badge else Vector2.ZERO,
		"background_size": rating_badge_background.size if rating_badge_background else Vector2.ZERO,
	}
