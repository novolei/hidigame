extends Control
class_name CharacterSetupOverlay

signal skin_selected(model_id: String)

const TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const BODY_FONT_PATH := "res://assets/fonts/SairaCondensed-Medium.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const UI_CONFIRM_SOUND_PATH := "res://assets/audio/ui/ui_confirm_click.mp3"
const PREVIEW_PLATFORM_SURFACE_Y := 0.064
const PREVIEW_MODEL_STAGE_Z := 0.0
const PREVIEW_MODEL_VISUAL_GROUND_OFFSET := 0.0
const PREVIEW_DEFAULT_SCALE_MULTIPLIER := 1.4
const PREVIEW_DRAG_SENSITIVITY := 0.012
const PREVIEW_SPIN_INERTIA_DAMPING := 4.8
const PREVIEW_SPIN_STOP_EPSILON := 0.01
const PREVIEW_MAX_ANGULAR_VELOCITY := 9.0
const THUMBNAIL_SIZE := Vector2i(128, 128)
const SETUP_BACKGROUND_COLOR := Color(0.76, 0.88, 0.98, 1.0)

var _title_font: Font = null
var _body_font: Font = null
var _value_font: Font = null
var _countdown_label: Label = null
var _skin_grid: GridContainer = null
var _left_rail: VBoxContainer = null
var _preview_container: SubViewportContainer = null
var _preview_viewport: SubViewport = null
var _preview_stage: Node3D = null
var _preview_turntable: Node3D = null
var _preview_pivot: Node3D = null
var _preview_model: Node3D = null
var _preview_camera: Camera3D = null
var _skin_card_buttons: Array[Button] = []
var _thumbnail_texture_cache: Dictionary = {}
var _preview_load_generation := 0
var _selected_id := ""
var _remaining := 0.0
var _dragging := false
var _preview_yaw := 0.0
var _preview_angular_velocity := 0.0
var _preview_base_scale := 1.0
var _last_layout_size := Vector2.ZERO
var _confirm_click_player: AudioStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_confirm_click_player()
	_load_fonts()
	_build_ui()
	visible = false
	set_process(false)
	if I18n and not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_fit_to_viewport()


func show_setup(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
	visible = true
	set_process(true)
	if _preview_viewport:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fit_to_viewport()
	_populate_skins()
	var current_id := _current_network_model_id()
	if not CharacterSkinCatalog.is_party_monster(current_id):
		current_id = CharacterSkinCatalog.party_monster_default_id()
	_select_skin(current_id, true)
	_update_text()


func set_remaining(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
	_update_text()


func hide_setup() -> void:
	visible = false
	set_process(false)
	_preview_load_generation += 1
	_dragging = false
	if _preview_viewport:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_preview_model()


func is_setup_visible() -> bool:
	return visible


func get_preview_default_scale_multiplier_for_test() -> float:
	return PREVIEW_DEFAULT_SCALE_MULTIPLIER


func get_preview_model_scale_for_test() -> Vector3:
	if not _preview_pivot or not is_instance_valid(_preview_pivot):
		return Vector3.ZERO
	return _preview_pivot.scale


func get_preview_model_position_for_test() -> Vector3:
	if not _preview_model or not is_instance_valid(_preview_model):
		return Vector3(999.0, 999.0, 999.0)
	return _preview_model.position


func get_preview_turntable_yaw_for_test() -> float:
	return _preview_yaw


func get_preview_turntable_angular_velocity_for_test() -> float:
	return _preview_angular_velocity


func simulate_preview_wheel_for_test(button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	_on_preview_gui_input(event)


func get_preview_model_platform_anchor_error_for_test() -> Vector3:
	if not _preview_model or not is_instance_valid(_preview_model) or not _preview_pivot or not is_instance_valid(_preview_pivot) or not _preview_turntable or not is_instance_valid(_preview_turntable):
		return Vector3(999.0, 999.0, 999.0)
	var bounds: Array = [false, AABB()]
	_accumulate_model_bounds(_preview_model, _preview_model, bounds)
	if not bool(bounds[0]):
		return Vector3(999.0, 999.0, 999.0)
	var box: AABB = bounds[1] as AABB
	var center: Vector3 = box.position + (box.size * 0.5)
	var local_to_stage: Transform3D = _preview_turntable.transform * _preview_pivot.transform
	var center_stage: Vector3 = local_to_stage * (_preview_model.position + center)
	var bottom_stage: Vector3 = local_to_stage * (_preview_model.position + Vector3(center.x, box.position.y, center.z))
	return Vector3(center_stage.x, bottom_stage.y - PREVIEW_PLATFORM_SURFACE_Y, center_stage.z - PREVIEW_MODEL_STAGE_Z)


func get_preview_pivot_position_for_test() -> Vector3:
	if not _preview_pivot or not is_instance_valid(_preview_pivot):
		return Vector3(999.0, 999.0, 999.0)
	return _preview_pivot.position


func rotate_preview_yaw_for_test(delta: float) -> void:
	_preview_yaw += delta
	_apply_preview_turntable_yaw()


func release_preview_drag_with_velocity_for_test(angular_velocity: float) -> void:
	_dragging = false
	_preview_angular_velocity = clampf(angular_velocity, -PREVIEW_MAX_ANGULAR_VELOCITY, PREVIEW_MAX_ANGULAR_VELOCITY)


func advance_preview_spin_for_test(delta: float) -> void:
	_update_preview_spin_inertia(delta)
	_apply_preview_turntable_yaw()


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_update_text()
	var layout_size: Vector2 = _get_layout_size()
	if layout_size.distance_squared_to(_last_layout_size) > 1.0:
		_apply_responsive_layout(layout_size)
	_update_preview_spin_inertia(delta)
	_apply_preview_turntable_yaw()


func _update_preview_spin_inertia(delta: float) -> void:
	if _dragging:
		return
	if absf(_preview_angular_velocity) <= PREVIEW_SPIN_STOP_EPSILON:
		_preview_angular_velocity = 0.0
		return
	_preview_yaw += _preview_angular_velocity * delta
	_preview_angular_velocity = move_toward(_preview_angular_velocity, 0.0, PREVIEW_SPIN_INERTIA_DAMPING * delta)


func _apply_preview_turntable_yaw() -> void:
	if _preview_turntable and is_instance_valid(_preview_turntable):
		_preview_turntable.rotation.y = _preview_yaw


func _load_fonts() -> void:
	_title_font = _load_font(TITLE_FONT_PATH)
	_body_font = _load_font(BODY_FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)


func _load_font(path: String) -> Font:
	var resource: Resource = load(path)
	return resource if resource is Font else null


func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_apply_responsive_layout(_get_layout_size())


func _get_layout_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var window: Window = get_window()
	if window != null:
		var window_size := Vector2(float(window.size.x), float(window.size.y))
		viewport_size.x = maxf(viewport_size.x, window_size.x)
		viewport_size.y = maxf(viewport_size.y, window_size.y)
	viewport_size.x = maxf(viewport_size.x, 640.0)
	viewport_size.y = maxf(viewport_size.y, 360.0)
	return viewport_size


func _apply_responsive_layout(layout_size: Vector2) -> void:
	_last_layout_size = layout_size
	custom_minimum_size = Vector2.ZERO

	if not _left_rail or not _preview_container:
		return

	var margin := clampf(layout_size.x * 0.008, 10.0, 22.0)
	var top_margin := clampf(layout_size.y * 0.026, 18.0, 34.0)
	var bottom_margin := clampf(layout_size.y * 0.022, 16.0, 28.0)
	var rail_width := clampf(layout_size.x * 0.245, 312.0, 520.0)
	if layout_size.x < 1180.0:
		rail_width = clampf(layout_size.x * 0.34, 300.0, 410.0)

	_left_rail.anchor_left = 0.0
	_left_rail.anchor_top = 0.0
	_left_rail.anchor_right = 0.0
	_left_rail.anchor_bottom = 1.0
	_left_rail.offset_left = margin
	_left_rail.offset_top = top_margin
	_left_rail.offset_right = margin + rail_width
	_left_rail.offset_bottom = -bottom_margin

	_preview_container.anchor_left = 0.0
	_preview_container.anchor_top = 0.0
	_preview_container.anchor_right = 1.0
	_preview_container.anchor_bottom = 1.0
	_preview_container.offset_left = margin + rail_width + clampf(layout_size.x * 0.026, 24.0, 54.0)
	_preview_container.offset_top = 0.0
	_preview_container.offset_right = -margin
	_preview_container.offset_bottom = 0.0

	if _skin_grid:
		var columns := 3
		if rail_width < 382.0:
			columns = 2
		_skin_grid.columns = columns
		var separation := 12.0
		var card_width := floorf((rail_width - (separation * float(columns - 1))) / float(columns))
		var card_height := clampf(card_width * 1.14, 124.0, 170.0)
		for button in _skin_card_buttons:
			button.custom_minimum_size = Vector2(card_width, card_height)
			var thumb: Control = button.get_node_or_null("CardContent/Thumb") as Control
			if thumb:
				thumb.custom_minimum_size = Vector2(maxf(80.0, card_width - 18.0), maxf(78.0, card_height - 44.0))


func _build_ui() -> void:
	_fit_to_viewport()

	var backdrop := ColorRect.new()
	backdrop.name = "SetupBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = SETUP_BACKGROUND_COLOR
	add_child(backdrop)

	_preview_container = SubViewportContainer.new()
	_preview_container.name = "CharacterPreview"
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.stretch = true
	_preview_container.mouse_target = true
	_preview_container.gui_input.connect(_on_preview_gui_input)
	add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.size = Vector2i(1120, 1080)
	_preview_viewport.transparent_bg = true
	_preview_viewport.own_world_3d = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview_container.add_child(_preview_viewport)

	_build_preview_world()
	_build_skin_list()
	_fit_to_viewport()


func _build_skin_list() -> void:
	_left_rail = VBoxContainer.new()
	_left_rail.name = "SkinListRail"
	_left_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	_left_rail.add_theme_constant_override("separation", 10)
	add_child(_left_rail)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0.0, 56.0)
	header.add_theme_constant_override("separation", 14)
	_left_rail.add_child(header)

	var title := _make_label("SELECT SKIN", 30, Color(0.97, 0.99, 1.0, 0.96), _title_font)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_countdown_label = _make_label("20", 38, Color(1.0, 0.77, 0.15, 1.0), _value_font)
	_countdown_label.name = "Countdown"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown_label.custom_minimum_size = Vector2(78.0, 52.0)
	header.add_child(_countdown_label)

	var subtitle := _make_label("PARTY MONSTER LOADOUT", 18, Color(0.92, 0.97, 1.0, 0.68), _body_font)
	subtitle.name = "Subtitle"
	subtitle.custom_minimum_size = Vector2(0.0, 24.0)
	_left_rail.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.name = "SkinScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_left_rail.add_child(scroll)

	_skin_grid = GridContainer.new()
	_skin_grid.name = "SkinGrid"
	_skin_grid.columns = 3
	_skin_grid.add_theme_constant_override("h_separation", 12)
	_skin_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_skin_grid)


func _build_preview_world() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "PreviewEnvironment"
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = SETUP_BACKGROUND_COLOR
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.78, 0.90, 0.96, 1.0)
	environment_resource.ambient_light_energy = 0.58
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_resource.tonemap_exposure = 0.74
	environment_resource.tonemap_white = 2.85
	environment_resource.fog_enabled = false
	environment.environment = environment_resource
	_preview_viewport.add_child(environment)

	_preview_stage = Node3D.new()
	_preview_stage.name = "PreviewStage"
	_preview_viewport.add_child(_preview_stage)

	_preview_turntable = Node3D.new()
	_preview_turntable.name = "PreviewTurntable"
	_preview_stage.add_child(_preview_turntable)
	_apply_preview_turntable_yaw()

	_add_stage_platform()
	_add_preview_lights()
	_add_preview_camera()


func _add_stage_platform() -> void:
	var shadow_mat: StandardMaterial3D = _make_stage_material(Color(0.05, 0.07, 0.09, 0.38), 0.08, 0.84, Color(0.0, 0.0, 0.0, 1.0), 0.0)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_create_stage_disc("PlatformShadow", 1.08, 0.014, -0.122, shadow_mat)

	var base_mat: StandardMaterial3D = _make_stage_material(Color(0.145, 0.152, 0.158, 0.96), 0.86, 0.24, Color(0.06, 0.055, 0.046, 1.0), 0.03)
	_create_stage_disc("PlatformBase", 0.86, 0.14, -0.08, base_mat)

	var rim_mat: StandardMaterial3D = _make_stage_material(Color(0.58, 0.53, 0.42, 0.96), 0.92, 0.18, Color(0.50, 0.43, 0.30, 1.0), 0.12)
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_create_stage_disc("PlatformTitaniumRim", 0.91, 0.024, 0.004, rim_mat)

	var top_mat: StandardMaterial3D = _make_stage_material(Color(0.72, 0.70, 0.62, 0.34), 0.62, 0.16, Color(0.46, 0.42, 0.32, 1.0), 0.07)
	top_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_create_stage_disc("PlatformBrushedTop", 0.72, 0.018, 0.034, top_mat)
	_add_stage_glow_decal()


func _create_stage_disc(node_name: String, radius: float, height: float, y: float, stage_material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	mesh.rings = 1
	mesh.material = stage_material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = Vector3(0.0, y, 0.0)
	var parent: Node3D = _preview_turntable if _preview_turntable else _preview_stage
	parent.add_child(instance)
	return instance


func _add_stage_glow_decal() -> void:
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = Color(1.0, 0.18, 0.22, 0.88)
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.16, 0.18, 1.0)
	glow_material.emission_energy_multiplier = 0.62
	glow_material.no_depth_test = true
	glow_material.disable_receive_shadows = true
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.072
	mesh.outer_radius = 0.096
	mesh.rings = 80
	mesh.ring_segments = 8
	mesh.material = glow_material
	var marker := MeshInstance3D.new()
	marker.name = "PlatformCenterMarker"
	marker.mesh = mesh
	marker.position = Vector3(0.0, PREVIEW_PLATFORM_SURFACE_Y + 0.012, PREVIEW_MODEL_STAGE_Z)
	var parent: Node3D = _preview_turntable if _preview_turntable else _preview_stage
	parent.add_child(marker)


func _add_preview_lights() -> void:
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.light_color = Color(1.0, 0.86, 0.72, 1.0)
	light.light_energy = 0.62
	light.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	light.shadow_enabled = true
	light.shadow_blur = 1.25
	_preview_stage.add_child(light)

	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(0.55, 0.78, 0.76, 1.0)
	rim.light_energy = 0.20
	rim.rotation_degrees = Vector3(-10.0, 142.0, 0.0)
	_preview_stage.add_child(rim)

	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.78, 0.92, 0.86, 1.0)
	fill.light_energy = 0.38
	fill.omni_range = 6.2
	fill.omni_attenuation = 0.34
	fill.position = Vector3(-1.8, 1.9, 2.45)
	_preview_stage.add_child(fill)

	var face := OmniLight3D.new()
	face.name = "SoftFaceLight"
	face.light_color = Color(1.0, 0.82, 0.70, 1.0)
	face.light_energy = 0.20
	face.omni_range = 4.2
	face.omni_attenuation = 0.28
	face.position = Vector3(1.35, 1.22, 2.35)
	_preview_stage.add_child(face)

	var floor_glow := OmniLight3D.new()
	floor_glow.name = "PlatformGlow"
	floor_glow.light_color = Color(0.70, 0.54, 0.40, 1.0)
	floor_glow.light_energy = 0.045
	floor_glow.omni_range = 2.4
	floor_glow.omni_attenuation = 0.45
	floor_glow.position = Vector3(0.0, 0.22, 0.42)
	_preview_stage.add_child(floor_glow)


func _add_preview_camera() -> void:
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.position = Vector3(0.0, 1.36, 4.45)
	_preview_camera.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	_preview_camera.fov = 30.0
	_preview_stage.add_child(_preview_camera)
	_preview_camera.current = true


func _make_stage_material(albedo: Color, metallic: float, roughness: float, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var stage_material := StandardMaterial3D.new()
	stage_material.albedo_color = albedo
	stage_material.metallic = metallic
	stage_material.roughness = roughness
	if emission_energy > 0.0:
		stage_material.emission_enabled = true
		stage_material.emission = emission
		stage_material.emission_energy_multiplier = emission_energy
	return stage_material


func _make_label(text_value: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.42))
	label.add_theme_constant_override("outline_size", 3)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _populate_skins() -> void:
	if not _skin_grid or _skin_grid.get_child_count() > 0:
		return
	for model in CharacterSkinCatalog.all():
		var model_id := str(model.get("id", ""))
		if not CharacterSkinCatalog.is_party_monster(model_id):
			continue
		_skin_grid.add_child(_make_skin_button(model))
	_apply_responsive_layout(_get_layout_size())


func _make_skin_button(model: Dictionary) -> Button:
	var button := Button.new()
	var model_id := str(model.get("id", ""))
	var display_name := str(model.get("label", model_id)).replace("Party Monster ", "PM ").replace("Party Monster Tint ", "TINT ")
	button.name = "Skin_" + model_id
	button.text = ""
	button.set_meta("skin_id", model_id)
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _skin_button_style(false, false))
	button.add_theme_stylebox_override("hover", _skin_button_style(true, false))
	button.add_theme_stylebox_override("pressed", _skin_button_style(true, true))

	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 7.0
	content.offset_top = 7.0
	content.offset_right = -7.0
	content.offset_bottom = -8.0
	content.add_theme_constant_override("separation", 4)
	button.add_child(content)

	var thumb := TextureRect.new()
	thumb.name = "Thumb"
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = _thumbnail_texture_for(model_id)
	content.add_child(thumb)

	var label := _make_label(display_name, 15, Color(0.05, 0.07, 0.09, 0.98), _body_font)
	label.name = "CardLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 24.0)
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.30))
	label.add_theme_constant_override("outline_size", 1)
	content.add_child(label)

	button.pressed.connect(func(): _select_skin_from_ui(model_id))
	_skin_card_buttons.append(button)
	return button


func _ensure_confirm_click_player() -> void:
	if _confirm_click_player and is_instance_valid(_confirm_click_player):
		return
	_confirm_click_player = AudioStreamPlayer.new()
	_confirm_click_player.name = "ConfirmClickAudio"
	_confirm_click_player.bus = &"Master"
	_confirm_click_player.volume_db = -7.0
	_confirm_click_player.max_polyphony = 4
	var stream := load(UI_CONFIRM_SOUND_PATH)
	if stream is AudioStream:
		_confirm_click_player.stream = stream
	add_child(_confirm_click_player)


func _play_confirm_click_sound() -> void:
	if not _confirm_click_player or not is_instance_valid(_confirm_click_player):
		return
	if not _confirm_click_player.stream:
		return
	_confirm_click_player.pitch_scale = randf_range(0.985, 1.015)
	_confirm_click_player.stop()
	_confirm_click_player.play()


func _select_skin_from_ui(model_id: String) -> void:
	_play_confirm_click_sound()
	_select_skin(model_id, true)


func _thumbnail_texture_for(model_id: String) -> Texture2D:
	if _thumbnail_texture_cache.has(model_id):
		return _thumbnail_texture_cache[model_id] as Texture2D
	var image: Image = Image.create(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_thumbnail_background(image)
	_draw_skin_thumbnail_variant(image, model_id)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_thumbnail_texture_cache[model_id] = texture
	return texture


func _draw_thumbnail_background(image: Image) -> void:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var top_color := Color(0.86, 0.94, 1.0, 1.0)
	var bottom_color := Color(0.74, 0.86, 0.96, 1.0)
	for y in range(height):
		var t: float = float(y) / float(maxi(1, height - 1))
		var line_color: Color = top_color.lerp(bottom_color, t)
		for x in range(width):
			image.set_pixel(x, y, line_color)
	_draw_filled_ellipse(image, Vector2(64.0, 110.0), Vector2(38.0, 9.0), Color(0.24, 0.40, 0.54, 0.16))


func _draw_skin_thumbnail_variant(image: Image, model_id: String) -> void:
	var palette: Dictionary = _skin_preview_palette(model_id)
	var body: Color = palette["body"]
	var accent: Color = palette["accent"]
	var glove: Color = palette["glove"]
	var face: Color = palette["face"]
	var dark: Color = palette["dark"]
	var index: int = _skin_preview_index(model_id)

	_draw_filled_ellipse(image, Vector2(43.0, 70.0), Vector2(12.0, 28.0), _shade_thumbnail_color(body, 0.94))
	_draw_filled_ellipse(image, Vector2(85.0, 70.0), Vector2(12.0, 28.0), _shade_thumbnail_color(body, 0.98))
	_draw_filled_ellipse(image, Vector2(39.0, 95.0), Vector2(10.0, 8.0), glove)
	_draw_filled_ellipse(image, Vector2(89.0, 95.0), Vector2(10.0, 8.0), glove)
	_draw_filled_ellipse(image, Vector2(55.0, 101.0), Vector2(7.0, 13.0), _shade_thumbnail_color(body, 0.86))
	_draw_filled_ellipse(image, Vector2(73.0, 101.0), Vector2(7.0, 13.0), _shade_thumbnail_color(body, 0.88))
	_draw_filled_ellipse(image, Vector2(64.0, 65.0), Vector2(27.0, 40.0), body)
	_draw_filled_ellipse(image, Vector2(64.0, 80.0), Vector2(20.0, 17.0), accent)
	_draw_filled_ellipse(image, Vector2(64.0, 43.0), Vector2(21.0, 20.0), face)
	_draw_filled_ellipse(image, Vector2(56.0, 43.0), Vector2(3.8, 5.8), dark)
	_draw_filled_ellipse(image, Vector2(72.0, 43.0), Vector2(3.8, 5.8), dark)
	_draw_thumbnail_smile(image, dark)

	if index % 5 == 1:
		_draw_filled_ellipse(image, Vector2(64.0, 26.0), Vector2(22.0, 5.0), _shade_thumbnail_color(accent, 0.90))
		_draw_filled_ellipse(image, Vector2(64.0, 20.0), Vector2(13.0, 8.0), _shade_thumbnail_color(accent, 1.08))
	elif index % 5 == 2:
		_draw_filled_ellipse(image, Vector2(48.0, 26.0), Vector2(6.0, 14.0), _shade_thumbnail_color(accent, 1.08))
		_draw_filled_ellipse(image, Vector2(80.0, 26.0), Vector2(6.0, 14.0), _shade_thumbnail_color(accent, 1.08))
	elif index % 5 == 3:
		_draw_filled_ellipse(image, Vector2(64.0, 23.0), Vector2(22.0, 7.0), _shade_thumbnail_color(glove, 1.16))
	elif index % 5 == 4:
		_draw_filled_ellipse(image, Vector2(46.0, 30.0), Vector2(7.0, 10.0), _shade_thumbnail_color(face, 1.08))
		_draw_filled_ellipse(image, Vector2(82.0, 30.0), Vector2(7.0, 10.0), _shade_thumbnail_color(face, 1.08))


func _thumbnail_smile_point(index: int, count: int) -> Vector2:
	var t: float = float(index) / float(maxi(1, count - 1))
	var x: float = lerpf(55.0, 73.0, t)
	var curve: float = sin(t * PI)
	return Vector2(x, 52.5 + curve * 4.2)


func _draw_thumbnail_smile(image: Image, color: Color) -> void:
	var count := 12
	for i in range(count):
		_draw_filled_ellipse(image, _thumbnail_smile_point(i, count), Vector2(2.2, 1.7), color)


func _skin_preview_palette(model_id: String) -> Dictionary:
	var palettes: Array[Dictionary] = [
		{"body": Color(0.94, 0.73, 0.28, 1.0), "accent": Color(0.36, 0.75, 0.95, 1.0), "glove": Color(0.10, 0.07, 0.06, 1.0), "face": Color(1.0, 0.84, 0.60, 1.0), "dark": Color(0.06, 0.05, 0.045, 1.0)},
		{"body": Color(0.40, 0.66, 0.90, 1.0), "accent": Color(0.16, 0.28, 0.70, 1.0), "glove": Color(0.08, 0.055, 0.05, 1.0), "face": Color(0.98, 0.78, 0.58, 1.0), "dark": Color(0.055, 0.045, 0.04, 1.0)},
		{"body": Color(0.80, 0.56, 0.92, 1.0), "accent": Color(0.95, 0.45, 0.70, 1.0), "glove": Color(0.13, 0.09, 0.08, 1.0), "face": Color(1.0, 0.82, 0.64, 1.0), "dark": Color(0.055, 0.045, 0.045, 1.0)},
		{"body": Color(0.55, 0.78, 0.42, 1.0), "accent": Color(0.96, 0.72, 0.28, 1.0), "glove": Color(0.12, 0.075, 0.055, 1.0), "face": Color(0.99, 0.82, 0.62, 1.0), "dark": Color(0.055, 0.045, 0.04, 1.0)},
		{"body": Color(0.92, 0.48, 0.64, 1.0), "accent": Color(0.64, 0.86, 0.98, 1.0), "glove": Color(0.11, 0.08, 0.075, 1.0), "face": Color(1.0, 0.84, 0.66, 1.0), "dark": Color(0.055, 0.045, 0.045, 1.0)},
		{"body": Color(0.93, 0.54, 0.34, 1.0), "accent": Color(0.20, 0.38, 0.82, 1.0), "glove": Color(0.11, 0.08, 0.06, 1.0), "face": Color(1.0, 0.82, 0.62, 1.0), "dark": Color(0.055, 0.045, 0.04, 1.0)},
	]
	var palette: Dictionary = palettes[_skin_preview_index(model_id) % palettes.size()].duplicate()
	if model_id.contains("masktint"):
		palette["body"] = (palette["body"] as Color).lerp(Color(0.72, 0.90, 0.98, 1.0), 0.20)
		palette["accent"] = (palette["accent"] as Color).lerp(Color(0.98, 0.78, 0.92, 1.0), 0.18)
	return palette


func _skin_preview_index(model_id: String) -> int:
	var digits := ""
	for i in range(model_id.length()):
		var character := model_id.substr(i, 1)
		if character.is_valid_int():
			digits += character
	if digits.is_empty():
		return 0
	return maxi(0, int(digits) - 1)


func _shade_thumbnail_color(color: Color, shade: float) -> Color:
	return Color(clampf(color.r * shade, 0.0, 1.0), clampf(color.g * shade, 0.0, 1.0), clampf(color.b * shade, 0.0, 1.0), color.a)


func _draw_filled_ellipse(image: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var min_x: int = clampi(int(floor(center.x - radius.x)), 0, image.get_width() - 1)
	var max_x: int = clampi(int(ceil(center.x + radius.x)), 0, image.get_width() - 1)
	var min_y: int = clampi(int(floor(center.y - radius.y)), 0, image.get_height() - 1)
	var max_y: int = clampi(int(ceil(center.y + radius.y)), 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx: float = (float(x) - center.x) / maxf(radius.x, 0.001)
			var dy: float = (float(y) - center.y) / maxf(radius.y, 0.001)
			var distance: float = (dx * dx) + (dy * dy)
			if distance <= 1.0:
				var light: float = clampf(1.09 - (float(y) - center.y + radius.y) / maxf(radius.y * 2.0, 0.001) * 0.18 - maxf(dx, 0.0) * 0.05, 0.76, 1.12)
				var shaded := _shade_thumbnail_color(color, light)
				_blend_thumbnail_pixel(image, x, y, shaded)


func _blend_thumbnail_pixel(image: Image, x: int, y: int, source: Color) -> void:
	var destination: Color = image.get_pixel(x, y)
	var alpha: float = source.a + destination.a * (1.0 - source.a)
	if alpha <= 0.001:
		image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		return
	var inv: float = 1.0 - source.a
	var blended := Color(
		(source.r * source.a + destination.r * destination.a * inv) / alpha,
		(source.g * source.a + destination.g * destination.a * inv) / alpha,
		(source.b * source.a + destination.b * destination.a * inv) / alpha,
		alpha
	)
	image.set_pixel(x, y, blended)


func _skin_button_style(hovered: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.84, 0.91, 0.97, 1.0) if not selected else Color(0.98, 0.74, 0.18, 1.0)
	if hovered:
		style.bg_color = Color(0.91, 0.96, 1.0, 1.0) if not selected else Color(1.0, 0.82, 0.25, 1.0)
	style.border_color = Color(1.0, 0.76, 0.16, 1.0) if selected else Color(0.96, 1.0, 1.0, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 7
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _select_skin(model_id: String, apply_to_network: bool) -> void:
	var normalized := CharacterSkinCatalog.normalize(model_id)
	if not CharacterSkinCatalog.is_party_monster(normalized):
		normalized = CharacterSkinCatalog.party_monster_default_id()
	_selected_id = normalized
	_update_skin_button_states()
	_request_preview_model_load(normalized)
	if apply_to_network:
		Network.request_set_character_model(normalized)
	skin_selected.emit(normalized)


func _update_skin_button_states() -> void:
	if not _skin_grid:
		return
	for child in _skin_grid.get_children():
		if not child is Button:
			continue
		var button := child as Button
		var model_id := str(button.get_meta("skin_id", ""))
		var selected := model_id == _selected_id
		button.add_theme_stylebox_override("normal", _skin_button_style(false, selected))
		button.add_theme_stylebox_override("hover", _skin_button_style(true, selected))
		button.add_theme_stylebox_override("pressed", _skin_button_style(true, true))


func _request_preview_model_load(model_id: String) -> void:
	_preview_load_generation += 1
	var generation := _preview_load_generation
	_clear_preview_model()
	call_deferred("_load_preview_model_deferred", model_id, generation)


func _load_preview_model_deferred(model_id: String, generation: int) -> void:
	await get_tree().process_frame
	if generation != _preview_load_generation or not visible:
		return
	_load_preview_model(model_id)


func _load_preview_model(model_id: String) -> void:
	_clear_preview_model()
	if not _preview_stage:
		return
	var scene_path := CharacterSkinCatalog.scene_path_for(model_id)
	var scene: PackedScene = load(scene_path)
	if not scene:
		return
	_preview_model = scene.instantiate() as Node3D
	if not _preview_model:
		return
	_preview_model.name = "PreviewModel"
	if _preview_model.has_method("set_character_model_id"):
		_preview_model.call("set_character_model_id", model_id)
	if not _preview_turntable or not is_instance_valid(_preview_turntable):
		_preview_turntable = Node3D.new()
		_preview_turntable.name = "PreviewTurntable"
		_preview_stage.add_child(_preview_turntable)
	_apply_preview_turntable_yaw()
	_preview_pivot = Node3D.new()
	_preview_pivot.name = "PreviewModelAnchor"
	_preview_pivot.position = Vector3(0.0, PREVIEW_PLATFORM_SURFACE_Y, PREVIEW_MODEL_STAGE_Z)
	_preview_pivot.rotation = Vector3.ZERO
	_preview_pivot.scale = Vector3.ONE
	_preview_turntable.add_child(_preview_pivot)
	_preview_model.scale = Vector3.ONE
	_preview_model.position = Vector3.ZERO
	_preview_model.rotation = Vector3.ZERO
	_preview_pivot.add_child(_preview_model)
	_prepare_preview_model_pose()
	_fit_preview_model_to_frame()
	if _preview_model.has_method("set_animation_paused"):
		_preview_model.call("set_animation_paused", true)
	call_deferred("_refit_preview_model_after_ready", _preview_load_generation)


func _refit_preview_model_after_ready(generation: int) -> void:
	await get_tree().process_frame
	if generation != _preview_load_generation or not _preview_model or not is_instance_valid(_preview_model):
		return
	_fit_preview_model_to_frame()


func _fit_preview_model_to_frame() -> void:
	if not _preview_model:
		return
	_prepare_preview_model_pose()
	_preview_base_scale = _fit_model_node_to_frame(_preview_model, 2.46, 1.54)
	_apply_preview_transform()


func _prepare_preview_model_pose() -> void:
	if not _preview_model or not is_instance_valid(_preview_model):
		return
	if _preview_model.has_method("apply_pose_now"):
		_preview_model.call("apply_pose_now", 0.0)
	elif _preview_model.has_method("idle"):
		_preview_model.call("idle")


func _fit_model_node_to_frame(model: Node3D, target_height: float, target_side: float) -> float:
	var bounds: Array = [false, AABB()]
	_accumulate_model_bounds(model, model, bounds)
	if not bool(bounds[0]):
		model.scale = Vector3.ONE
		model.position = Vector3.ZERO
		return 1.0
	var box: AABB = bounds[1] as AABB
	var bounds_size: Vector3 = box.size
	if bounds_size.length_squared() <= 0.0001:
		return 1.0
	var side_size: float = maxf(bounds_size.x, bounds_size.z)
	var height_scale: float = target_height / maxf(bounds_size.y, 0.001)
	var side_scale: float = target_side / maxf(side_size, 0.001)
	return clampf(minf(height_scale, side_scale), 0.01, 3.0)


func _apply_preview_transform() -> void:
	if not _preview_model or not is_instance_valid(_preview_model) or not _preview_pivot or not is_instance_valid(_preview_pivot):
		return
	var scaled_fit := _preview_base_scale * PREVIEW_DEFAULT_SCALE_MULTIPLIER
	_apply_preview_turntable_yaw()
	_preview_pivot.position = Vector3(0.0, PREVIEW_PLATFORM_SURFACE_Y, PREVIEW_MODEL_STAGE_Z)
	_preview_pivot.rotation = Vector3.ZERO
	_preview_pivot.scale = Vector3.ONE * scaled_fit
	_align_preview_model_on_pivot(_preview_model, PREVIEW_MODEL_VISUAL_GROUND_OFFSET)


func _align_preview_model_on_pivot(model: Node3D, visual_ground_offset: float = 0.0) -> void:
	model.scale = Vector3.ONE
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	var bounds: Array = [false, AABB()]
	_accumulate_model_bounds(model, model, bounds)
	if not bool(bounds[0]):
		model.position = Vector3(0.0, visual_ground_offset, 0.0)
		return
	var box: AABB = bounds[1] as AABB
	var center: Vector3 = box.position + (box.size * 0.5)
	model.position = Vector3(-center.x, visual_ground_offset - box.position.y, -center.z)


func _accumulate_model_bounds(root_model: Node3D, node: Node, bounds: Array, parent_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var local_transform := parent_transform
	if node is Node3D and node != root_model:
		local_transform = parent_transform * (node as Node3D).transform
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual.visible:
			var local_aabb: AABB = visual.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var transformed_aabb: AABB = _transform_aabb(local_aabb, local_transform)
				if bool(bounds[0]):
					bounds[1] = (bounds[1] as AABB).merge(transformed_aabb)
				else:
					bounds[1] = transformed_aabb
					bounds[0] = true
	for child in node.get_children():
		_accumulate_model_bounds(root_model, child, bounds, local_transform)


func _transform_aabb(box: AABB, xform: Transform3D) -> AABB:
	var base: Vector3 = box.position
	var box_size: Vector3 = box.size
	var points: Array[Vector3] = [
		base,
		base + Vector3(box_size.x, 0.0, 0.0),
		base + Vector3(0.0, box_size.y, 0.0),
		base + Vector3(0.0, 0.0, box_size.z),
		base + Vector3(box_size.x, box_size.y, 0.0),
		base + Vector3(box_size.x, 0.0, box_size.z),
		base + Vector3(0.0, box_size.y, box_size.z),
		base + box_size,
	]
	var first_point: Vector3 = xform * points[0]
	var min_point: Vector3 = first_point
	var max_point: Vector3 = first_point
	for i in range(1, points.size()):
		var point: Vector3 = xform * points[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	return AABB(min_point, max_point - min_point)


func _clear_preview_model() -> void:
	if _preview_pivot and is_instance_valid(_preview_pivot):
		_preview_pivot.queue_free()
	elif _preview_model and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_pivot = null
	_preview_model = null
	_preview_base_scale = 1.0


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button_event.pressed
			if _dragging:
				_preview_angular_velocity = 0.0
			accept_event()
			return
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var yaw_delta: float = motion.relative.x * PREVIEW_DRAG_SENSITIVITY
		_preview_yaw += yaw_delta
		var frame_delta: float = maxf(get_process_delta_time(), 1.0 / 60.0)
		_preview_angular_velocity = clampf(yaw_delta / frame_delta, -PREVIEW_MAX_ANGULAR_VELOCITY, PREVIEW_MAX_ANGULAR_VELOCITY)
		_apply_preview_turntable_yaw()
		accept_event()


func _current_network_model_id() -> String:
	var local_id: int = 1
	if multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	if Network.players.has(local_id):
		return str(Network.players[local_id].get("character_model", CharacterSkinCatalog.party_monster_default_id()))
	return str(Network.player_info.get("character_model", CharacterSkinCatalog.party_monster_default_id()))


func _update_text() -> void:
	if _countdown_label:
		_countdown_label.text = "%02d" % int(ceil(_remaining))


func _on_locale_changed(_locale: String) -> void:
	_update_text()
