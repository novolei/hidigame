extends Control
class_name CharacterSetupOverlay

## Skin-selection overlay shown during the SKIN_CONFIG phase.
##
## Redesigned as a 3D carousel: a single SubViewport hosts a fixed pool of
## PartyMonsterSkin instances laid out as a depth ring (center large, neighbours
## smaller and pushed back on Z so perspective gives a real "3D distance" look).
## The pool is built once and never re-instantiated while scrolling — switching a
## skin only re-assigns a cheap variant id (visibility toggle), which is what keeps
## rapid wheel/arrow input from thrashing the loader and crashing the client.
##
## Public contract used by level.gd is preserved: show_setup / set_remaining /
## hide_setup / is_setup_visible / skin_selected.

signal skin_selected(model_id: String)

const TITLE_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const BODY_FONT_PATH := "res://assets/fonts/SairaCondensed-Medium.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const UI_CONFIRM_SOUND_PATH := "res://assets/audio/ui/ui_confirm_click.mp3"

# --- Carousel geometry -------------------------------------------------------
const SLOT_COUNT := 5            # center + 2 neighbours each side (outer pair recycles unseen)
const HALF := 2                  # SLOT_COUNT / 2 (integer)
const X_SPACING := 2.05          # world units between adjacent carousel slots
const Z_DEPTH := 1.5             # how far back each off-center step is pushed
const SIDE_FALLOFF := 0.66       # multiplicative scale per offset step (depth shrink)
const BASE_FIT_MULT := 1.34      # extra scale applied on top of AABB fit
const FADE_START := 1.45         # |offset| at which a slot starts fading out
const FADE_END := 2.35           # |offset| at which a slot is fully hidden (safe to recycle)
const PREVIEW_SURFACE_Y := 0.0   # ground plane Y inside a slot

# --- Motion / input tuning ---------------------------------------------------
const SCROLL_SMOOTH := 13.0      # exponential easing rate toward the target index
const STEP_COOLDOWN := 0.11      # min seconds between accepted step inputs (debounce)
const MAX_PENDING := 2.0         # cap on how many steps may be queued ahead of the view
const NETWORK_APPLY_DELAY := 0.28 # settle time before the choice is pushed to the server
const DRAG_SENSITIVITY := 0.012
const SPIN_INERTIA_DAMPING := 4.8
const SPIN_STOP_EPSILON := 0.01
const MAX_ANGULAR_VELOCITY := 9.0

# --- Countdown ---------------------------------------------------------------
const URGENCY_THRESHOLD := 8.0   # seconds below which the timer enters the "panic" state
const DEFAULT_TOTAL_SECONDS := 20.0

# --- Fitting -----------------------------------------------------------------
const FIT_TARGET_HEIGHT := 2.42
const FIT_TARGET_SIDE := 1.6

# --- Palette (warm, matches the reference screenshot) ------------------------
const BG_TOP := Color(0.99, 0.69, 0.27, 1.0)
const BG_BOTTOM := Color(0.93, 0.51, 0.17, 1.0)
const GLOW_INNER := Color(1.0, 0.86, 0.58, 0.55)
const GLOW_OUTER := Color(1.0, 0.78, 0.40, 0.0)
const AMBIENT_COLOR := Color(0.98, 0.82, 0.62, 1.0)
const COUNTDOWN_CALM := Color(1.0, 1.0, 1.0, 1.0)
const COUNTDOWN_PANIC := Color(1.0, 0.22, 0.16, 1.0)

var _title_font: Font = null
var _body_font: Font = null
var _value_font: Font = null

# Scene nodes -----------------------------------------------------------------
var _background: TextureRect = null
var _glow: TextureRect = null
var _edge_left: TextureRect = null
var _edge_right: TextureRect = null
var _preview_container: SubViewportContainer = null
var _preview_viewport: SubViewport = null
var _preview_stage: Node3D = null
var _carousel_root: Node3D = null
var _preview_camera: Camera3D = null
var _countdown_label: Label = null
var _countdown_ring: TextureProgressBar = null
var _name_label: Label = null
var _index_label: Label = null
var _hint_label: Label = null
var _left_arrow: Button = null
var _right_arrow: Button = null
var _spinner: TextureRect = null
var _confirm_click_player: AudioStreamPlayer = null

# Carousel slot pools (parallel arrays indexed 0..SLOT_COUNT-1) ----------------
var _slot_root: Array[Node3D] = []
var _slot_yaw: Array[Node3D] = []
var _slot_anchor: Array[Node3D] = []
var _slot_model: Array[Node] = []
var _slot_shadow: Array[MeshInstance3D] = []
var _slot_shadow_mat: Array[StandardMaterial3D] = []
var _slot_skin_id: Array[String] = []

# Catalog / selection state ---------------------------------------------------
var _skin_ids: Array[String] = []
var _fit_cache: Dictionary = {}        # skin_id -> {"scale": float, "offset": Vector3}
var _shadow_texture: Texture2D = null

# Runtime state ---------------------------------------------------------------
var _scroll := 0.0                     # continuous carousel position (unbounded)
var _scroll_target := 0.0
var _last_base := 2147483647
var _last_center_logical := 2147483647
var _center_yaw := 0.0
var _center_angular_velocity := 0.0
var _dragging := false
var _elapsed := 0.0
var _last_step_at := -100.0
var _last_input_at := -100.0
var _network_dirty := false
var _last_applied_id := ""
var _remaining := 0.0
var _total_seconds := DEFAULT_TOTAL_SECONDS
var _warmup_pending: Array[int] = []
var _warmup_done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_fonts()
	_build_catalog()
	_ensure_confirm_click_player()
	_build_ui()
	visible = false
	set_process(false)
	if I18n and not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_fit_to_viewport()


# --- Public API (consumed by level.gd) --------------------------------------

func show_setup(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
	_total_seconds = maxf(_remaining, _skin_config_total_seconds())
	visible = true
	set_process(true)
	if _preview_viewport:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fit_to_viewport()

	# Show a random skin centered on open, but keep a returning player's explicit pick.
	var current_id := _current_network_model_id()
	var start_index := _index_of_skin(current_id)
	if not CharacterSkinCatalog.is_party_monster(current_id) or current_id == CharacterSkinCatalog.party_monster_default_id():
		if _skin_ids.size() > 1:
			start_index = randi() % _skin_ids.size()
	_scroll = float(start_index)
	_scroll_target = _scroll
	_last_base = 2147483647
	_last_center_logical = 2147483647
	_center_yaw = 0.0
	_center_angular_velocity = 0.0
	_dragging = false
	_network_dirty = false
	_last_applied_id = _skin_ids[wrapi(start_index, 0, _skin_ids.size())] if not _skin_ids.is_empty() else ""

	_begin_warmup()
	_refresh_carousel_assignments(true)
	_update_carousel_transforms()
	_update_chrome()


func set_remaining(remaining: float) -> void:
	_remaining = maxf(0.0, remaining)
	if _remaining > _total_seconds:
		_total_seconds = _remaining
	_update_countdown()


func hide_setup() -> void:
	visible = false
	set_process(false)
	_dragging = false
	if _preview_viewport:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_setup_visible() -> bool:
	return visible


# --- Test hooks --------------------------------------------------------------

func get_center_skin_id_for_test() -> String:
	return _center_skin_id()


func get_carousel_scroll_for_test() -> float:
	return _scroll


func get_center_yaw_for_test() -> float:
	return _center_yaw


func get_center_angular_velocity_for_test() -> float:
	return _center_angular_velocity


func is_warmup_complete_for_test() -> bool:
	return _warmup_done


func force_full_warmup_for_test() -> void:
	while not _warmup_pending.is_empty():
		_warmup_step()
	_refresh_carousel_assignments(true)


func step_carousel_for_test(direction: int) -> void:
	_last_step_at = -100.0
	_request_step(direction)


func simulate_preview_wheel_for_test(button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	_on_preview_gui_input(event)


func release_center_drag_with_velocity_for_test(angular_velocity: float) -> void:
	_dragging = false
	_center_angular_velocity = clampf(angular_velocity, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)


func advance_for_test(delta: float) -> void:
	_process(delta)


func get_countdown_urgency_for_test() -> float:
	return _countdown_urgency()


func get_visible_slot_count_for_test() -> int:
	var count := 0
	for slot in _slot_root:
		if slot and is_instance_valid(slot) and slot.visible:
			count += 1
	return count


# --- Main loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	_remaining = maxf(0.0, _remaining - delta)

	if not _warmup_pending.is_empty():
		_warmup_step()

	# Ease the continuous scroll toward the requested index.
	var diff := _scroll_target - _scroll
	if absf(diff) > 0.0008:
		_scroll = lerpf(_scroll, _scroll_target, 1.0 - exp(-SCROLL_SMOOTH * delta))
	else:
		_scroll = _scroll_target

	_refresh_carousel_assignments(false)
	_update_center_spin(delta)
	_update_carousel_transforms()
	_maybe_apply_to_network()
	_update_spinner(delta)
	_update_countdown()


func _is_settled() -> bool:
	return absf(_scroll_target - _scroll) < 0.02


func _center_skin_id() -> String:
	if _skin_ids.is_empty():
		return ""
	return _skin_ids[wrapi(roundi(_scroll), 0, _skin_ids.size())]


# --- Carousel ring -----------------------------------------------------------

func _refresh_carousel_assignments(force: bool) -> void:
	if _skin_ids.is_empty():
		return
	var base := roundi(_scroll) - HALF
	if not force and base == _last_base:
		return
	_last_base = base
	var count := _skin_ids.size()
	for k in range(SLOT_COUNT):
		var logical := base + k
		var skin_id := _skin_ids[wrapi(logical, 0, count)]
		if _slot_skin_id[k] == skin_id and _slot_model[k] != null:
			continue
		_slot_skin_id[k] = skin_id
		_assign_skin_to_slot(k, skin_id)


func _assign_skin_to_slot(k: int, skin_id: String) -> void:
	var model: Node = _slot_model[k]
	if model == null or not is_instance_valid(model):
		return  # warm-up will assign once the instance exists
	if model.has_method("set_character_model_id"):
		model.call("set_character_model_id", skin_id)
	_align_slot_model(k, skin_id)


func _update_center_spin(delta: float) -> void:
	if _dragging:
		return
	if absf(_center_angular_velocity) <= SPIN_STOP_EPSILON:
		_center_angular_velocity = 0.0
		return
	_center_yaw += _center_angular_velocity * delta
	_center_angular_velocity = move_toward(_center_angular_velocity, 0.0, SPIN_INERTIA_DAMPING * delta)


func _update_carousel_transforms() -> void:
	if _skin_ids.is_empty():
		return
	var base := roundi(_scroll) - HALF
	var center_logical := roundi(_scroll)

	# Reset spin + animation focus whenever the centered skin changes.
	if center_logical != _last_center_logical:
		_last_center_logical = center_logical
		_center_yaw = 0.0
		_center_angular_velocity = 0.0
		_refresh_animation_focus()
		_update_skin_text()
		_network_dirty = true

	for k in range(SLOT_COUNT):
		var slot: Node3D = _slot_root[k]
		if not slot or not is_instance_valid(slot):
			continue
		var logical := base + k
		var offset := float(logical) - _scroll
		var abs_off := absf(offset)

		var depth_scale := pow(SIDE_FALLOFF, abs_off)
		var fade := clampf((FADE_END - abs_off) / maxf(FADE_END - FADE_START, 0.001), 0.0, 1.0)
		fade = smoothstep(0.0, 1.0, fade)
		var final_scale := depth_scale * fade

		slot.position = Vector3(offset * X_SPACING, 0.0, -abs_off * Z_DEPTH)
		slot.scale = Vector3.ONE * maxf(final_scale, 0.0001)
		slot.visible = final_scale > 0.02

		# Only the centered slot carries the player's drag rotation; the rest face front.
		var yaw_node: Node3D = _slot_yaw[k]
		if yaw_node and is_instance_valid(yaw_node):
			var is_center := abs_off < 0.5
			var target_yaw := _center_yaw if is_center else 0.0
			yaw_node.rotation.y = target_yaw

		var shadow_mat: StandardMaterial3D = _slot_shadow_mat[k]
		if shadow_mat:
			shadow_mat.albedo_color.a = 0.42 * fade


func _refresh_animation_focus() -> void:
	# Centered model plays a live idle; off-center models hold a static pose to save cost.
	for k in range(SLOT_COUNT):
		var model: Node = _slot_model[k]
		if model == null or not is_instance_valid(model):
			continue
		var logical := (roundi(_scroll) - HALF) + k
		var is_center := logical == roundi(_scroll)
		if model.has_method("set_animation_paused"):
			model.call("set_animation_paused", not is_center)
		if is_center and model.has_method("idle"):
			model.call("idle")
		elif not is_center and model.has_method("apply_pose_now"):
			model.call("apply_pose_now", 0.35)


# --- Input -------------------------------------------------------------------

func _request_step(direction: int) -> void:
	if direction == 0 or _skin_ids.is_empty():
		return
	if _elapsed - _last_step_at < STEP_COOLDOWN:
		return  # debounce: drop inputs that arrive faster than the cooldown
	_last_step_at = _elapsed
	_last_input_at = _elapsed
	_scroll_target += float(direction)
	# Bound the queue so a flood of wheel ticks can't fling the view dozens of steps.
	_scroll_target = clampf(_scroll_target, _scroll - MAX_PENDING, _scroll + MAX_PENDING)
	_network_dirty = true
	_play_confirm_click_sound()


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_request_step(-1)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_request_step(1)
					accept_event()
			MOUSE_BUTTON_LEFT:
				# Dragging to inspect is only allowed once the carousel has settled.
				if mb.pressed and _is_settled():
					_dragging = true
					_center_angular_velocity = 0.0
				else:
					_dragging = false
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var yaw_delta := motion.relative.x * DRAG_SENSITIVITY
		_center_yaw += yaw_delta
		var frame_delta := maxf(get_process_delta_time(), 1.0 / 60.0)
		_center_angular_velocity = clampf(yaw_delta / frame_delta, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)
		_last_input_at = _elapsed
		accept_event()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_LEFT, KEY_A:
				_request_step(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_request_step(1)
				get_viewport().set_input_as_handled()


func _maybe_apply_to_network() -> void:
	if not _network_dirty:
		return
	if not _is_settled():
		return
	if _elapsed - _last_input_at < NETWORK_APPLY_DELAY:
		return
	_network_dirty = false
	var id := _center_skin_id()
	if id.is_empty():
		return
	if id == _last_applied_id:
		return
	_last_applied_id = id
	if Network and Network.has_method("request_set_character_model"):
		Network.request_set_character_model(id)
	skin_selected.emit(id)


# --- Warm-up (spread instancing across frames + spinner) ---------------------

func _begin_warmup() -> void:
	if _warmup_done:
		return
	_warmup_pending.clear()
	for k in range(SLOT_COUNT):
		if _slot_model[k] == null or not is_instance_valid(_slot_model[k]):
			_warmup_pending.append(k)
	if _warmup_pending.is_empty():
		_warmup_done = true
	if _spinner:
		_spinner.visible = not _warmup_pending.is_empty()


func _warmup_step() -> void:
	if _warmup_pending.is_empty():
		_warmup_done = true
		if _spinner:
			_spinner.visible = false
		_refresh_animation_focus()
		return
	var k: int = _warmup_pending.pop_front()
	_instantiate_slot_model(k)
	if _warmup_pending.is_empty():
		_warmup_done = true
		if _spinner:
			_spinner.visible = false
		_refresh_carousel_assignments(true)
		_refresh_animation_focus()


func _instantiate_slot_model(k: int) -> void:
	var anchor: Node3D = _slot_anchor[k]
	if not anchor or not is_instance_valid(anchor):
		return
	var skin_id := _slot_skin_id[k]
	if skin_id.is_empty():
		skin_id = _skin_ids[wrapi((roundi(_scroll) - HALF) + k, 0, _skin_ids.size())] if not _skin_ids.is_empty() else CharacterSkinCatalog.party_monster_default_id()
		_slot_skin_id[k] = skin_id
	var scene_path := CharacterSkinCatalog.scene_path_for(skin_id)
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.name = "SlotModel%d" % k
	if model.has_method("set_character_model_id"):
		model.call("set_character_model_id", skin_id)
	anchor.add_child(model)
	_slot_model[k] = model
	_align_slot_model(k, skin_id)


# --- Model fitting / alignment ----------------------------------------------

func _align_slot_model(k: int, skin_id: String) -> void:
	var anchor: Node3D = _slot_anchor[k]
	var model: Node = _slot_model[k]
	if not anchor or not is_instance_valid(anchor) or model == null or not is_instance_valid(model) or not model is Node3D:
		return
	var model3d := model as Node3D
	if model3d.has_method("apply_pose_now"):
		model3d.call("apply_pose_now", 0.0)
	elif model3d.has_method("idle"):
		model3d.call("idle")

	var fit: Dictionary = _fit_cache.get(skin_id, {})
	if fit.is_empty():
		var scale_value := _fit_model_scale(model3d)
		var center_offset := _model_ground_offset(model3d)
		fit = {"scale": scale_value, "offset": center_offset}
		_fit_cache[skin_id] = fit

	anchor.position = Vector3(0.0, PREVIEW_SURFACE_Y, 0.0)
	anchor.rotation = Vector3.ZERO
	anchor.scale = Vector3.ONE * (float(fit["scale"]) * BASE_FIT_MULT)
	model3d.scale = Vector3.ONE
	model3d.rotation = Vector3.ZERO
	model3d.position = fit["offset"]


func _fit_model_scale(model: Node3D) -> float:
	var bounds: Array = [false, AABB()]
	_accumulate_model_bounds(model, model, bounds)
	if not bool(bounds[0]):
		return 1.0
	var box: AABB = bounds[1] as AABB
	var bounds_size: Vector3 = box.size
	if bounds_size.length_squared() <= 0.0001:
		return 1.0
	var side_size := maxf(bounds_size.x, bounds_size.z)
	var height_scale := FIT_TARGET_HEIGHT / maxf(bounds_size.y, 0.001)
	var side_scale := FIT_TARGET_SIDE / maxf(side_size, 0.001)
	return clampf(minf(height_scale, side_scale), 0.01, 3.0)


func _model_ground_offset(model: Node3D) -> Vector3:
	# Center the visual on X/Z and rest the feet on the slot ground plane (Y=0).
	var saved_scale := model.scale
	var saved_pos := model.position
	var saved_rot := model.rotation
	model.scale = Vector3.ONE
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	var bounds: Array = [false, AABB()]
	_accumulate_model_bounds(model, model, bounds)
	model.scale = saved_scale
	model.position = saved_pos
	model.rotation = saved_rot
	if not bool(bounds[0]):
		return Vector3.ZERO
	var box: AABB = bounds[1] as AABB
	var center: Vector3 = box.position + (box.size * 0.5)
	return Vector3(-center.x, -box.position.y, -center.z)


func _accumulate_model_bounds(root_model: Node3D, node: Node, bounds: Array, parent_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var local_transform := parent_transform
	if node is Node3D and node != root_model:
		local_transform = parent_transform * (node as Node3D).transform
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		if visual.visible:
			var local_aabb := visual.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var transformed := _transform_aabb(local_aabb, local_transform)
				if bool(bounds[0]):
					bounds[1] = (bounds[1] as AABB).merge(transformed)
				else:
					bounds[1] = transformed
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
	var first := xform * points[0]
	var min_p := first
	var max_p := first
	for i in range(1, points.size()):
		var p := xform * points[i]
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		min_p.z = minf(min_p.z, p.z)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
		max_p.z = maxf(max_p.z, p.z)
	return AABB(min_p, max_p - min_p)


# --- Catalog -----------------------------------------------------------------

func _build_catalog() -> void:
	_skin_ids.clear()
	for model in CharacterSkinCatalog.all():
		var model_id := str(model.get("id", ""))
		if CharacterSkinCatalog.is_party_monster(model_id):
			_skin_ids.append(model_id)
	if _skin_ids.is_empty():
		_skin_ids.append(CharacterSkinCatalog.party_monster_default_id())


func _index_of_skin(skin_id: String) -> int:
	var normalized := CharacterSkinCatalog.normalize(skin_id)
	var found := _skin_ids.find(normalized)
	if found >= 0:
		return found
	return _skin_ids.find(CharacterSkinCatalog.party_monster_default_id()) if _skin_ids.has(CharacterSkinCatalog.party_monster_default_id()) else 0


func _current_network_model_id() -> String:
	var local_id := 1
	if multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	if Network and Network.players.has(local_id):
		return str(Network.players[local_id].get("character_model", CharacterSkinCatalog.party_monster_default_id()))
	if Network:
		return str(Network.player_info.get("character_model", CharacterSkinCatalog.party_monster_default_id()))
	return CharacterSkinCatalog.party_monster_default_id()


func _skin_config_total_seconds() -> float:
	if Network and "SKIN_CONFIG_TOTAL_SECONDS" in Network:
		return float(Network.SKIN_CONFIG_TOTAL_SECONDS)
	return DEFAULT_TOTAL_SECONDS


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	_fit_to_viewport()

	_background = TextureRect.new()
	_background.name = "Background"
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.texture = _make_linear_gradient(BG_TOP, BG_BOTTOM)
	add_child(_background)

	_glow = TextureRect.new()
	_glow.name = "CenterGlow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.texture = _make_radial_gradient(GLOW_INNER, GLOW_OUTER)
	add_child(_glow)

	_preview_container = SubViewportContainer.new()
	_preview_container.name = "CarouselViewport"
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.stretch = true
	_preview_container.mouse_target = true
	_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_container.gui_input.connect(_on_preview_gui_input)
	add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.size = Vector2i(1600, 900)
	_preview_viewport.transparent_bg = true
	_preview_viewport.own_world_3d = true
	_preview_viewport.msaa_3d = Viewport.MSAA_4X
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview_container.add_child(_preview_viewport)

	_build_preview_world()
	_build_edge_vignettes()
	_build_chrome()
	_fit_to_viewport()


func _build_preview_world() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "PreviewEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_BOTTOM
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 2.6
	environment.environment = env
	_preview_viewport.add_child(environment)

	_preview_stage = Node3D.new()
	_preview_stage.name = "PreviewStage"
	_preview_viewport.add_child(_preview_stage)

	_add_preview_lights()
	_add_preview_camera()

	_carousel_root = Node3D.new()
	_carousel_root.name = "CarouselRoot"
	_carousel_root.position = Vector3(0.0, -0.32, 0.0)  # drop the models so the countdown clears their heads
	_preview_stage.add_child(_carousel_root)

	_shadow_texture = _make_shadow_texture()
	for k in range(SLOT_COUNT):
		_build_slot(k)


func _build_slot(k: int) -> void:
	var slot := Node3D.new()
	slot.name = "Slot%d" % k
	_carousel_root.add_child(slot)

	# Contact shadow lives on the slot (not the yaw pivot) so it stays put while the model spins.
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_texture = _shadow_texture
	shadow_mat.albedo_color = Color(0.06, 0.03, 0.0, 0.42)
	shadow_mat.disable_receive_shadows = true
	shadow_mat.no_depth_test = false
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(2.3, 2.3)
	quad.material = shadow_mat
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = quad
	shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shadow.position = Vector3(0.0, 0.012, 0.18)
	slot.add_child(shadow)

	var yaw := Node3D.new()
	yaw.name = "Yaw"
	slot.add_child(yaw)

	var anchor := Node3D.new()
	anchor.name = "Anchor"
	yaw.add_child(anchor)

	_slot_root.append(slot)
	_slot_yaw.append(yaw)
	_slot_anchor.append(anchor)
	_slot_model.append(null)
	_slot_shadow.append(shadow)
	_slot_shadow_mat.append(shadow_mat)
	_slot_skin_id.append("")


func _add_preview_lights() -> void:
	# Fixed key/rim/fill rig — lives on the stage, never on the turntable, so the
	# lighting and the foot shadow stay locked while the model rotates.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.93, 0.82, 1.0)
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-42.0, -26.0, 0.0)
	key.shadow_enabled = false
	_preview_stage.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(1.0, 0.74, 0.46, 1.0)
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-8.0, 158.0, 0.0)
	_preview_stage.add_child(rim)

	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(1.0, 0.86, 0.66, 1.0)
	fill.light_energy = 0.5
	fill.omni_range = 9.0
	fill.omni_attenuation = 0.5
	fill.position = Vector3(-2.4, 2.2, 3.4)
	_preview_stage.add_child(fill)


func _add_preview_camera() -> void:
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.position = Vector3(0.0, 1.42, 5.7)
	_preview_camera.rotation_degrees = Vector3(-8.5, 0.0, 0.0)
	_preview_camera.fov = 34.0
	_preview_stage.add_child(_preview_camera)
	_preview_camera.current = true


func _build_edge_vignettes() -> void:
	_edge_left = TextureRect.new()
	_edge_left.name = "EdgeLeft"
	_edge_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge_left.stretch_mode = TextureRect.STRETCH_SCALE
	_edge_left.texture = _make_linear_gradient_h(Color(0.86, 0.44, 0.12, 0.55), Color(0.86, 0.44, 0.12, 0.0))
	add_child(_edge_left)

	_edge_right = TextureRect.new()
	_edge_right.name = "EdgeRight"
	_edge_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge_right.stretch_mode = TextureRect.STRETCH_SCALE
	_edge_right.texture = _make_linear_gradient_h(Color(0.86, 0.44, 0.12, 0.0), Color(0.86, 0.44, 0.12, 0.55))
	add_child(_edge_right)


func _build_chrome() -> void:
	# Countdown ring + number, top center.
	_countdown_ring = TextureProgressBar.new()
	_countdown_ring.name = "CountdownRing"
	_countdown_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_ring.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	_countdown_ring.min_value = 0.0
	_countdown_ring.max_value = 1.0
	_countdown_ring.step = 0.0
	_countdown_ring.value = 1.0
	_countdown_ring.texture_under = _make_ring_texture(Color(1.0, 1.0, 1.0, 0.16))
	_countdown_ring.texture_progress = _make_ring_texture(Color(1.0, 1.0, 1.0, 0.92))
	_countdown_ring.radial_initial_angle = 0.0
	_countdown_ring.radial_center_offset = Vector2.ZERO
	add_child(_countdown_ring)

	_countdown_label = _make_label("20", 60, COUNTDOWN_CALM, _title_font)
	_countdown_label.name = "Countdown"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_constant_override("outline_size", 6)
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.55, 0.20, 0.04, 0.85))
	add_child(_countdown_label)

	# Skin name + index, lower center.
	_name_label = _make_label("PARTY MONSTER", 30, Color(1.0, 0.99, 0.96, 1.0), _title_font)
	_name_label.name = "SkinName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_index_label = _make_label("01 / 36", 18, Color(1.0, 0.93, 0.82, 0.85), _body_font)
	_index_label.name = "SkinIndex"
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_index_label)

	_hint_label = _make_label(_hint_text(), 16, Color(1.0, 0.96, 0.90, 0.78), _body_font)
	_hint_label.name = "Hint"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_label)

	_left_arrow = _make_arrow_button("‹", false)
	add_child(_left_arrow)
	_left_arrow.pressed.connect(func() -> void: _request_step(-1))

	_right_arrow = _make_arrow_button("›", true)
	add_child(_right_arrow)
	_right_arrow.pressed.connect(func() -> void: _request_step(1))

	_spinner = TextureRect.new()
	_spinner.name = "Spinner"
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.stretch_mode = TextureRect.STRETCH_SCALE
	_spinner.texture = _make_spinner_texture()
	_spinner.pivot_offset = Vector2(36.0, 36.0)
	_spinner.custom_minimum_size = Vector2(72.0, 72.0)
	_spinner.size = Vector2(72.0, 72.0)
	_spinner.visible = false
	add_child(_spinner)


func _make_arrow_button(glyph: String, is_right: bool) -> Button:
	var button := Button.new()
	button.name = "ArrowRight" if is_right else "ArrowLeft"
	button.text = glyph
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(76.0, 104.0)
	button.add_theme_font_override("font", _title_font if _title_font else ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 52)
	button.add_theme_color_override("font_color", Color(0.32, 0.45, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.22, 0.36, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.30, 0.64, 1.0))
	button.add_theme_stylebox_override("normal", _arrow_style(false))
	button.add_theme_stylebox_override("hover", _arrow_style(true))
	button.add_theme_stylebox_override("pressed", _arrow_style(true))
	button.add_theme_stylebox_override("focus", _arrow_style(false))
	return button


func _arrow_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.90, 0.94) if not hovered else Color(1.0, 0.99, 0.95, 1.0)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.4, 0.18, 0.02, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	return style


# --- Responsive layout -------------------------------------------------------

func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_apply_layout(_get_layout_size())


func _get_layout_size() -> Vector2:
	var layout_size := get_viewport_rect().size
	var window := get_window()
	if window != null:
		layout_size.x = maxf(layout_size.x, float(window.size.x))
		layout_size.y = maxf(layout_size.y, float(window.size.y))
	layout_size.x = maxf(layout_size.x, 640.0)
	layout_size.y = maxf(layout_size.y, 360.0)
	return layout_size


func _apply_layout(layout: Vector2) -> void:
	if _background:
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _glow:
		_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _preview_container:
		_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var edge_w := clampf(layout.x * 0.16, 140.0, 360.0)
	if _edge_left:
		_edge_left.position = Vector2.ZERO
		_edge_left.size = Vector2(edge_w, layout.y)
	if _edge_right:
		_edge_right.position = Vector2(layout.x - edge_w, 0.0)
		_edge_right.size = Vector2(edge_w, layout.y)

	var ring_size := clampf(layout.y * 0.16, 144.0, 184.0)  # min matches the ring texture's native size
	if _countdown_ring:
		_countdown_ring.size = Vector2(ring_size, ring_size)
		_countdown_ring.position = Vector2((layout.x - ring_size) * 0.5, clampf(layout.y * 0.022, 12.0, 34.0))
	if _countdown_label:
		_countdown_label.size = Vector2(ring_size, ring_size)
		_countdown_label.position = _countdown_ring.position if _countdown_ring else Vector2((layout.x - ring_size) * 0.5, 40.0)
		_countdown_label.pivot_offset = Vector2(ring_size * 0.5, ring_size * 0.5)

	var name_w := clampf(layout.x * 0.6, 360.0, 900.0)
	var name_y := layout.y - clampf(layout.y * 0.2, 120.0, 220.0)
	if _name_label:
		_name_label.size = Vector2(name_w, 40.0)
		_name_label.position = Vector2((layout.x - name_w) * 0.5, name_y)
	if _index_label:
		_index_label.size = Vector2(name_w, 26.0)
		_index_label.position = Vector2((layout.x - name_w) * 0.5, name_y + 42.0)
	if _hint_label:
		_hint_label.size = Vector2(name_w, 24.0)
		_hint_label.position = Vector2((layout.x - name_w) * 0.5, name_y + 74.0)

	var arrow_y := layout.y * 0.5 - 52.0
	if _left_arrow:
		_left_arrow.position = Vector2(clampf(layout.x * 0.03, 18.0, 64.0), arrow_y)
	if _right_arrow:
		_right_arrow.position = Vector2(layout.x - clampf(layout.x * 0.03, 18.0, 64.0) - 76.0, arrow_y)

	if _spinner:
		_spinner.position = Vector2((layout.x - 72.0) * 0.5, (layout.y - 72.0) * 0.5)


# --- Countdown + spinner animation ------------------------------------------

func _countdown_urgency() -> float:
	if _remaining >= URGENCY_THRESHOLD:
		return 0.0
	return clampf((URGENCY_THRESHOLD - _remaining) / URGENCY_THRESHOLD, 0.0, 1.0)


func _update_countdown() -> void:
	if _countdown_label == null:
		return
	_countdown_label.text = "%d" % int(ceil(_remaining))
	if _countdown_ring:
		_countdown_ring.value = clampf(_remaining / maxf(_total_seconds, 0.001), 0.0, 1.0)

	var urgency := _countdown_urgency()
	var color := COUNTDOWN_CALM.lerp(COUNTDOWN_PANIC, urgency)
	_countdown_label.add_theme_color_override("font_color", color)
	if _countdown_ring:
		_countdown_ring.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.0, 0.45, 0.4, 1.0), urgency)

	# Below the threshold the timer pulses and (deeper in) shakes to build pressure.
	var pulse := 1.0
	var shake := Vector2.ZERO
	if urgency > 0.0:
		var freq := lerpf(7.0, 15.0, urgency)
		pulse = 1.0 + sin(_elapsed * freq) * (0.06 + 0.12 * urgency)
		if urgency > 0.5:
			var amp := (urgency - 0.5) * 14.0
			shake = Vector2(sin(_elapsed * 47.0) * amp, cos(_elapsed * 41.0) * amp * 0.5)
		_countdown_label.add_theme_constant_override("outline_size", int(lerpf(6.0, 12.0, urgency)))
	else:
		_countdown_label.add_theme_constant_override("outline_size", 6)
	_countdown_label.scale = Vector2(pulse, pulse)
	var base_pos := _countdown_ring.position if _countdown_ring else _countdown_label.position
	_countdown_label.position = base_pos + shake


func _update_spinner(delta: float) -> void:
	if _spinner == null or not _spinner.visible:
		return
	_spinner.rotation += delta * 6.5


func _update_chrome() -> void:
	_update_skin_text()
	_update_countdown()


func _update_skin_text() -> void:
	var id := _center_skin_id()
	if _name_label:
		_name_label.text = CharacterSkinCatalog.label_for(id).to_upper() if not id.is_empty() else "PARTY MONSTER"
	if _index_label and not _skin_ids.is_empty():
		var idx := wrapi(roundi(_scroll), 0, _skin_ids.size())
		_index_label.text = "%02d / %02d" % [idx + 1, _skin_ids.size()]


func _hint_text() -> String:
	if I18n and I18n.has_method("t"):
		var translated := str(I18n.call("t", "skin_select.hint"))
		if translated != "skin_select.hint" and not translated.is_empty():
			return translated
	return "拖动旋转 · 滚轮/箭头切换 · 倒计时结束自动选定"


# --- Texture generators ------------------------------------------------------

func _make_linear_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 8
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


func _make_linear_gradient_h(left: Color, right: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, left)
	gradient.set_color(1, right)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 8
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)
	return tex


func _make_radial_gradient(inner: Color, outer: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.56)
	tex.fill_to = Vector2(1.05, 0.56)
	return tex


func _make_shadow_texture() -> Texture2D:
	var tex_size := 192
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center := float(tex_size) * 0.5
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := (float(x) - center) / center
			var dy := (float(y) - center) / center
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.8)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(image)


func _make_ring_texture(color: Color) -> Texture2D:
	var tex_size := 144  # TextureProgressBar adopts this as its min size, so it doubles as the on-screen ring diameter
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := float(tex_size) * 0.5
	var outer := center - 4.0
	var inner := outer - 9.0
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := float(x) - center
			var dy := float(y) - center
			var r := sqrt(dx * dx + dy * dy)
			var edge := minf(r - inner, outer - r)
			var a := clampf(edge, 0.0, 1.5) / 1.5
			if r < inner or r > outer:
				a = 0.0
			if a > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	return ImageTexture.create_from_image(image)


func _make_spinner_texture() -> Texture2D:
	var tex_size := 96
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := float(tex_size) * 0.5
	var outer := center - 6.0
	var inner := outer - 12.0
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := float(x) - center
			var dy := float(y) - center
			var r := sqrt(dx * dx + dy * dy)
			if r < inner or r > outer:
				continue
			var ang := atan2(dy, dx) + PI  # 0..2PI
			var head := ang / TAU          # comet tail brightest at the head
			var a := clampf(head, 0.05, 1.0)
			var edge := minf(r - inner, outer - r)
			a *= clampf(edge, 0.0, 1.2) / 1.2
			image.set_pixel(x, y, Color(1.0, 0.98, 0.92, a))
	return ImageTexture.create_from_image(image)


# --- Small helpers -----------------------------------------------------------

func _load_fonts() -> void:
	_title_font = _load_font(TITLE_FONT_PATH)
	_body_font = _load_font(BODY_FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)


func _load_font(path: String) -> Font:
	var resource: Resource = load(path)
	return resource if resource is Font else null


func _make_label(text_value: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.16, 0.02, 0.5))
	label.add_theme_constant_override("outline_size", 3)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _ensure_confirm_click_player() -> void:
	if _confirm_click_player and is_instance_valid(_confirm_click_player):
		return
	_confirm_click_player = AudioStreamPlayer.new()
	_confirm_click_player.name = "ConfirmClickAudio"
	_confirm_click_player.bus = &"Master"
	_confirm_click_player.volume_db = -8.0
	_confirm_click_player.max_polyphony = 4
	var stream := load(UI_CONFIRM_SOUND_PATH)
	if stream is AudioStream:
		_confirm_click_player.stream = stream
	add_child(_confirm_click_player)


func _play_confirm_click_sound() -> void:
	if not _confirm_click_player or not is_instance_valid(_confirm_click_player) or not _confirm_click_player.stream:
		return
	_confirm_click_player.pitch_scale = randf_range(0.985, 1.03)
	_confirm_click_player.stop()
	_confirm_click_player.play()


func _on_locale_changed(_locale: String) -> void:
	if _hint_label:
		_hint_label.text = _hint_text()
	_update_skin_text()
	_update_countdown()
