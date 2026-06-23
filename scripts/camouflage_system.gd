extends Node
class_name CamouflageSystem

const CAMOUFLAGE_RANGE := 30.0
const TEXTURE_SIZE := 1024
const PATCH_COUNT := 26
const BRUSH_MIN_RADIUS := 10.0
const BRUSH_MAX_RADIUS := 160.0
const BRUSH_DEFAULT_RADIUS := 46.0
const BRUSH_RESIZE_PIXELS_TO_RADIUS := 0.20
const BRUSH_STROKE_INTERVAL := 0.025
const BRUSH_MIN_WORLD_SPACING := 0.015
const BRUSH_MAX_INTERPOLATED_STAMPS := 16
const SURFACE_LOCK_MOUSE_EPSILON := 0.35
const SURFACE_LOCK_EXACT_MOUSE_EPSILON := 0.001
const BRUSH_SCREEN_STAMP_SPACING_FACTOR := 0.42
const BRUSH_DAB_SAMPLE_SCREEN_FACTOR := 0.14
const BRUSH_DAB_TEXTURE_RADIUS_FACTOR := 0.32
const BRUSH_DAB_CENTER_TEXTURE_RADIUS_FACTOR := 1.0
const BRUSH_PRECISION_SAMPLE_MIN_RADIUS := 4.0
const BRUSH_DAB_MIN_SCREEN_RADIUS := 18.0
const BRUSH_DAB_DIAGONAL_MIN_SCREEN_RADIUS := 72.0
const BRUSH_DAB_MAX_LOCAL_DISTANCE_FACTOR := 2.50
const BRUSH_DAB_MIN_NORMAL_DOT := 0.05
const BRUSH_PRECISION_DAB_MAX_SAMPLES := 9
const BRUSH_LOCAL_UV_SAMPLE_MAX_BARY_EXTRAPOLATION := 0.75
const BRUSH_LOCAL_UV_SAMPLE_MAX_PIXEL_DISTANCE_FACTOR := 1.35
const BRUSH_LOCAL_UV_SAMPLE_MAX_CENTROID_DRIFT_FACTOR := 0.20
const BRUSH_SUBPIXEL_QUANTIZATION := 4.0
const BRUSH_PATCH_CACHE_LIMIT := 128
const BRUSH_TEXTURE_VERSION := 2
const BRUSH_USE_UV_TRIANGLE_CLIP := false
const BRUSH_USE_UV_FOOTPRINT_MASK := false
const BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS := 3.0
const BRUSH_UV_CLIP_MAX_TRIANGLES := 48
const BRUSH_UV_EDGE_FAN_LIMIT := 12
const HIT_CACHE_PREWARM_TRIANGLE_LIMIT := 120000
const SKINNED_POSE_SIGNATURE_QUANTIZATION := 10000.0
const COLOR_MATERIAL_SCREEN_MATCH_THRESHOLD := 0.32
const COLOR_MATERIAL_CALIBRATION_WEIGHT := 0.0
const PAINT_ROUGHNESS_DEFAULT := 1.0
const PAINT_METALLIC_DEFAULT := 0.0
const PAINT_SPECULAR_DEFAULT := 0.5
const PAINT_MATERIAL_STEP := 0.05
const SURFACE_PREVIEW_OFFSET := 0.012
const SURFACE_PREVIEW_SEGMENTS := 64
const SURFACE_PREVIEW_RING_INNER_RADIUS := 0.78
const SURFACE_PREVIEW_AXIS_HALF_WIDTH := 0.024
const BODY_MESH_PATHS := [
	"3DGodotRobot/RobotArmature/Skeleton3D/Bottom",
	"3DGodotRobot/RobotArmature/Skeleton3D/Chest",
	"3DGodotRobot/RobotArmature/Skeleton3D/Face",
	"3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head",
]

var camouflage_owner: CharacterBody3D = null
var camera: Camera3D = null
var skill_active := false
var has_sampled_color := false
var brush_radius := BRUSH_DEFAULT_RADIUS
var brush_angle := 0.0
var brush_color := Color(0.42, 0.95, 0.72, 1.0)
var current_color := Color(0.42, 0.95, 0.72, 1.0)
var last_confidence := 0.0
var paint_exact_color_match := false
var paint_roughness := PAINT_ROUGHNESS_DEFAULT
var paint_metallic := PAINT_METALLIC_DEFAULT
var paint_specular := PAINT_SPECULAR_DEFAULT
var paint_normal_texture: Texture2D = null
var paint_normal_scale := 1.0

var _stroke_wait := 0.0
var _resizing_brush := false
var _orbiting_camera := false
var _surface_lock := {}
var _mesh_hit_cache := {}
var _mesh_hit_build_jobs := {}
var _skinned_pose_signatures := {}
var _paintable_meshes_cache: Array = []
var _pose_hit_cache_generation := 0
var _last_stroke_world_position := Vector3(INF, INF, INF)
var _last_stroke_uv := Vector2(-1.0, -1.0)
var _last_stroke_screen_position := Vector2(-INF, -INF)
var _last_stroke_key := ""
var _last_stroke_mesh_path := ""
var _surface_lock_mouse_position := Vector2(-INF, -INF)
var _pending_forced_paint := false
var _pending_forced_paint_screen_position := Vector2.ZERO
var _pending_drag_paint := false
var _pending_drag_screen_position := Vector2.ZERO
var _performance_metrics := {}
var _hud: CamouflageHUD = null
var _surface_preview: MeshInstance3D = null
var _surface_preview_material: StandardMaterial3D = null
static var _shared_brush_patch_cache: Dictionary = {}
static var _shared_brush_patch_image_cache: Dictionary = {}

signal skill_activated
signal skill_deactivated
signal color_picked(color: Color, confidence: float)
signal pick_failed(reason: String)


func _exit_tree() -> void:
	_wait_for_mesh_hit_jobs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_wait_for_mesh_hit_jobs()


func _wait_for_mesh_hit_jobs() -> void:
	for value in _mesh_hit_build_jobs.values():
		var thread := value as Thread
		if thread:
			thread.wait_to_finish()
	_mesh_hit_build_jobs.clear()


func _advance_pose_hit_cache_generation() -> void:
	_pose_hit_cache_generation += 1
	_prune_stale_pose_hit_cache()


func _prune_stale_pose_hit_cache() -> void:
	var stale_keys: Array[String] = []
	for cache_key in _mesh_hit_cache.keys():
		var key := str(cache_key)
		if _is_pose_hit_cache_key(key) and _pose_generation_from_cache_key(key) != _pose_hit_cache_generation:
			stale_keys.append(key)
	for key in stale_keys:
		_mesh_hit_cache.erase(key)
	if not stale_keys.is_empty():
		_metric_add("mesh_hit_cache_pose_prunes", stale_keys.size())


func _is_pose_hit_cache_key(cache_key: String) -> bool:
	return cache_key.find(":pose:") >= 0


func _pose_generation_from_cache_key(cache_key: String) -> int:
	var marker := cache_key.find(":pose:")
	if marker < 0:
		return -1
	return int(cache_key.substr(marker + 6))


func _is_stale_pose_hit_cache_key(cache_key: String) -> bool:
	return _is_pose_hit_cache_key(cache_key) and _pose_generation_from_cache_key(cache_key) != _pose_hit_cache_generation


func _process(delta: float) -> void:
	if _stroke_wait > 0.0:
		_stroke_wait = maxf(0.0, _stroke_wait - delta)
	_finalize_mesh_hit_cache_jobs()
	if not skill_active:
		return

	if not has_sampled_color:
		_hide_surface_preview()
		return

	_update_surface_lock()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _try_flush_pending_drag_paint():
			_paint_at_mouse()
	else:
		_pending_drag_paint = false


func initialize(owner_node: CharacterBody3D, owner_camera: Camera3D) -> void:
	camouflage_owner = owner_node
	camera = owner_camera
	reset_performance_metrics()
	_ensure_hud()


func toggle_skill() -> bool:
	if skill_active:
		deactivate_skill()
	else:
		activate_skill()
	return true


func activate_skill() -> void:
	if skill_active:
		return
	skill_active = true
	if camouflage_owner and camouflage_owner.has_method("set_camouflage_brush_locked"):
		camouflage_owner.call("set_camouflage_brush_locked", true)
	reset_performance_metrics()
	_resizing_brush = false
	_orbiting_camera = false
	_advance_pose_hit_cache_generation()
	_paintable_meshes_cache.clear()
	_skinned_pose_signatures.clear()
	_surface_lock.clear()
	_surface_lock_mouse_position = Vector2(-INF, -INF)
	_last_stroke_world_position = Vector3(INF, INF, INF)
	_last_stroke_uv = Vector2(-1.0, -1.0)
	_last_stroke_screen_position = Vector2(-INF, -INF)
	_last_stroke_key = ""
	_last_stroke_mesh_path = ""
	_pending_forced_paint = false
	_pending_drag_paint = false
	_sync_paint_material_controls()
	if _hud:
		_hud.set_skill_active(true, has_sampled_color, brush_color, _current_brush_radius(), brush_angle)
		_update_hud_material_controls()
	_hide_surface_preview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	skill_activated.emit()


func deactivate_skill() -> void:
	if not skill_active:
		return
	skill_active = false
	_resizing_brush = false
	_orbiting_camera = false
	_advance_pose_hit_cache_generation()
	_paintable_meshes_cache.clear()
	_skinned_pose_signatures.clear()
	_surface_lock.clear()
	_surface_lock_mouse_position = Vector2(-INF, -INF)
	_last_stroke_world_position = Vector3(INF, INF, INF)
	_last_stroke_uv = Vector2(-1.0, -1.0)
	_last_stroke_screen_position = Vector2(-INF, -INF)
	_last_stroke_key = ""
	_last_stroke_mesh_path = ""
	_pending_forced_paint = false
	_pending_drag_paint = false
	if camouflage_owner and camouflage_owner.has_method("set_camouflage_brush_locked"):
		camouflage_owner.call("set_camouflage_brush_locked", false)
	if _hud:
		_hud.set_skill_active(false, has_sampled_color, brush_color, _current_brush_radius(), brush_angle)
	_hide_surface_preview()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skill_deactivated.emit()


func reset_performance_metrics() -> void:
	_performance_metrics = {
		"surface_projection_calls": 0,
		"targeted_surface_projection_calls": 0,
		"untargeted_surface_projection_calls": 0,
		"paintable_mesh_cache_hits": 0,
		"paintable_mesh_cache_rebuilds": 0,
		"mesh_intersection_calls": 0,
		"mesh_surface_tests": 0,
		"mesh_hit_cache_hits": 0,
		"mesh_hit_cache_misses": 0,
		"mesh_hit_cache_async_jobs": 0,
		"mesh_hit_cache_pose_prunes": 0,
		"brush_batches_submitted": 0,
		"brush_stamps_submitted": 0,
		"brush_precision_sample_attempts": 0,
		"brush_precision_sample_misses": 0,
		"brush_precision_sample_hits": 0,
		"brush_precision_sample_reject_mesh": 0,
		"brush_precision_sample_reject_surface": 0,
		"brush_precision_sample_reject_distance": 0,
		"brush_precision_sample_reject_normal": 0,
		"brush_precision_sample_accepted": 0,
		"brush_precision_local_samples": 0,
		"brush_precision_local_sample_reject_distribution": 0,
	}


func get_performance_metrics() -> Dictionary:
	if _performance_metrics.is_empty():
		reset_performance_metrics()
	return _performance_metrics.duplicate()


func _metric_add(name: String, amount: int = 1) -> void:
	if _performance_metrics.is_empty():
		reset_performance_metrics()
	_performance_metrics[name] = int(_performance_metrics.get(name, 0)) + amount


func try_absorb() -> bool:
	return toggle_skill()


func is_brush_mode() -> bool:
	return skill_active


func is_ready() -> bool:
	return true


func get_cooldown_remaining() -> float:
	return 0.0


func handle_brush_input(event: InputEvent) -> bool:
	if not skill_active:
		return false

	if event.is_action_pressed("camouflage_absorb"):
		deactivate_skill()
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_adjust_paint_roughness(-PAINT_MATERIAL_STEP)
			return true
		if event.keycode == KEY_X:
			_adjust_paint_roughness(PAINT_MATERIAL_STEP)
			return true
		if event.keycode == KEY_F:
			_adjust_paint_metallic(-PAINT_MATERIAL_STEP)
			return true
		if event.keycode == KEY_G:
			_adjust_paint_metallic(PAINT_MATERIAL_STEP)
			return true
		if event.keycode == KEY_ESCAPE:
			deactivate_skill()
			return true

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		match mouse_button.button_index:
			MOUSE_BUTTON_LEFT:
				if mouse_button.pressed:
					_handle_left_click(mouse_button.position)
				else:
					_flush_pending_drag_on_release(mouse_button.position)
				return true
			MOUSE_BUTTON_RIGHT:
				_resizing_brush = mouse_button.pressed
				if _hud:
					_hud.set_brush(_current_brush_radius(), brush_angle)
				return true
			MOUSE_BUTTON_MIDDLE:
				_orbiting_camera = mouse_button.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if mouse_button.pressed:
					_zoom_owner_camera(-1.0)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse_button.pressed:
					_zoom_owner_camera(1.0)
				return true

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _resizing_brush:
			_resize_brush(motion.relative)
			return true
		if _orbiting_camera:
			_orbit_owner_camera(motion.relative)
			return true
		if has_sampled_color and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint_at_mouse(false, motion.position)
			return true
		return true

	return true


func _pick_color_at_mouse(screen_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var viewport := get_viewport()
	var mouse_position := screen_position
	if mouse_position.x < 0.0 or mouse_position.y < 0.0:
		mouse_position = viewport.get_mouse_position() if viewport else Vector2.ZERO
	var hud_was_visible := false
	if _hud:
		hud_was_visible = _hud.visible
		_hud.visible = false
	await RenderingServer.frame_post_draw
	if _hud:
		_hud.visible = hud_was_visible
	if not skill_active:
		return

	var color := _sample_mouse_viewport_color(mouse_position)
	var material_profile := _sample_mouse_material_profile(mouse_position)
	var material_color: Color = material_profile.get("color", Color(0, 0, 0, 0))
	if material_color.a > 0.0:
		color = _blend_material_and_screen_color(material_color, color)
	if color.a <= 0.0:
		_fail("No screen color")
		return

	color.a = 1.0
	brush_color = color
	current_color = color
	if bool(material_profile.get("has_response", false)):
		paint_roughness = clampf(float(material_profile.get("roughness", paint_roughness)), 0.0, 1.0)
		paint_metallic = clampf(float(material_profile.get("metallic", paint_metallic)), 0.0, 1.0)
		paint_specular = clampf(float(material_profile.get("specular", paint_specular)), 0.0, 1.0)
		paint_normal_texture = material_profile.get("normal_texture", null) as Texture2D
		paint_normal_scale = clampf(float(material_profile.get("normal_scale", paint_normal_scale)), 0.0, 2.0)
		_sync_paint_material_controls()
		_sync_paint_material_profile()
	has_sampled_color = true
	last_confidence = 1.0
	_last_stroke_world_position = Vector3(INF, INF, INF)
	_last_stroke_uv = Vector2(-1.0, -1.0)
	_last_stroke_screen_position = Vector2(-INF, -INF)
	_last_stroke_key = ""
	_last_stroke_mesh_path = ""
	_pending_forced_paint = false
	_pending_drag_paint = false

	if _hud:
		_hud.set_sampled_color(brush_color)
		_hud.set_skill_active(true, true, brush_color, _current_brush_radius(), brush_angle)
		_update_hud_material_controls()
	_request_paintable_mesh_cache_warmup()
	color_picked.emit(brush_color, last_confidence)


func _handle_left_click(screen_position: Vector2) -> void:
	var mouse_position := _resolve_screen_position(screen_position)
	if not has_sampled_color:
		_pick_color_at_mouse(mouse_position)
		return
	var surface := _get_surface_lock(true, mouse_position)
	if surface.is_empty():
		if _has_pending_mesh_hit_jobs():
			_queue_pending_paint_request(mouse_position)
			if _hud and _hud.has_method("set_preparing_surface"):
				_hud.call("set_preparing_surface")
		else:
			_pick_color_at_mouse(mouse_position)
		return
	_paint_surface(surface, true)


func _paint_at_mouse(force: bool = false, screen_position: Vector2 = Vector2(-INF, -INF)) -> void:
	if not has_sampled_color:
		_fail("Click scene to pick color")
		return
	if not camouflage_owner:
		return

	var mouse_position := _resolve_screen_position(screen_position)
	if not force and _stroke_wait > 0.0:
		_queue_pending_drag_paint(mouse_position)
		return
	var surface := _get_surface_lock(force, screen_position)
	if surface.is_empty():
		if _has_pending_mesh_hit_jobs():
			if force:
				_queue_pending_paint_request(mouse_position)
			if _hud and _hud.has_method("set_preparing_surface"):
				_hud.call("set_preparing_surface")
		elif _hud:
			_hud.set_brush_surface(mouse_position, false)
		return
	_paint_surface(surface, force)


func _paint_surface(surface: Dictionary, force: bool = false) -> void:
	var world_position: Vector3 = surface.get("position", Vector3.ZERO)
	if not force and _last_stroke_world_position.x < INF:
		var spacing := maxf(BRUSH_MIN_WORLD_SPACING, _current_brush_radius() / float(TEXTURE_SIZE) * 0.10)
		if _last_stroke_world_position.distance_to(world_position) < spacing:
			return

	var uv: Vector2 = surface.get("uv", Vector2(0.5, 0.5))
	var world_normal: Vector3 = surface.get("normal", Vector3.UP)
	var target_mesh_path := str(surface.get("mesh_path", ""))
	var target_surface := int(surface.get("surface", 0))
	var target_key := "%s:%d" % [target_mesh_path, target_surface]
	var fallback_angle := float(surface.get("angle", brush_angle))
	var stroke_angle := fallback_angle
	var stamp_count := 1
	var viewport := get_viewport()
	var current_screen: Vector2 = surface.get("screen", viewport.get_mouse_position() if viewport else Vector2.ZERO)
	var same_mesh_stroke := not target_mesh_path.is_empty() and (
		_last_stroke_mesh_path == target_mesh_path
		or _last_stroke_key == target_key
		or _last_stroke_key.begins_with(target_mesh_path + ":")
	)
	var can_interpolate := not force and _last_stroke_screen_position.x > -INF and (_last_stroke_key == target_key or same_mesh_stroke)
	if can_interpolate:
		var screen_delta := current_screen - _last_stroke_screen_position
		if screen_delta.length_squared() > 0.25:
			stroke_angle = atan2(screen_delta.y, screen_delta.x)
			var stamp_spacing := maxf(2.0, _current_brush_radius() * BRUSH_SCREEN_STAMP_SPACING_FACTOR)
			stamp_count = clampi(int(ceil(screen_delta.length() / stamp_spacing)), 1, BRUSH_MAX_INTERPOLATED_STAMPS)
	brush_angle = stroke_angle

	var stroke_groups := {}
	for stamp_index in range(stamp_count):
		var t := 1.0
		if can_interpolate and stamp_count > 1:
			t = float(stamp_index + 1) / float(stamp_count)
		var stamp_surface := surface
		if can_interpolate and stamp_count > 1 and stamp_index < stamp_count - 1:
			var stamp_screen := _last_stroke_screen_position.lerp(current_screen, t)
			stamp_surface = _project_screen_to_body_surface(stamp_screen, true, target_mesh_path, -1 if same_mesh_stroke else target_surface)
			if stamp_surface.is_empty():
				continue
		var full_dab := stamp_index == stamp_count - 1
		var use_precision_samples := full_dab
		_append_surface_brush_dab(stroke_groups, stamp_surface, full_dab, use_precision_samples)
	for group in stroke_groups.values():
		_submit_brush_stroke_batch(
			group.get("uvs", PackedVector2Array()),
			brush_angle,
			group.get("positions", PackedVector3Array()),
			group.get("normal", world_normal),
			str(group.get("mesh_path", "")),
			int(group.get("surface", 0)),
			group.get("radii", PackedFloat32Array()),
			group.get("uv_clip_triangles", PackedVector2Array()),
			group.get("uv_clip_triangle_counts", PackedInt32Array()),
			group.get("uv_footprint_metrics", PackedFloat32Array())
		)
	_last_stroke_world_position = world_position
	_last_stroke_uv = uv
	_last_stroke_screen_position = current_screen
	_last_stroke_key = target_key
	_last_stroke_mesh_path = target_mesh_path
	_stroke_wait = BRUSH_STROKE_INTERVAL
	if _hud:
		_hud.set_brush(_current_brush_radius(), brush_angle)


func _queue_pending_paint_request(screen_position: Vector2) -> void:
	_pending_forced_paint = true
	_pending_forced_paint_screen_position = screen_position


func _queue_pending_drag_paint(screen_position: Vector2) -> void:
	_pending_drag_paint = true
	_pending_drag_screen_position = screen_position


func _try_flush_pending_drag_paint() -> bool:
	if not _pending_drag_paint or _stroke_wait > 0.0 or not skill_active or not has_sampled_color:
		return false
	var screen_position := _pending_drag_screen_position
	_pending_drag_paint = false
	_paint_at_mouse(false, screen_position)
	return true


func _flush_pending_drag_on_release(screen_position: Vector2) -> void:
	var release_position := _resolve_screen_position(screen_position)
	if not _pending_drag_paint:
		if _last_stroke_screen_position.x <= -INF:
			return
		if _last_stroke_screen_position.distance_to(release_position) <= SURFACE_LOCK_MOUSE_EPSILON:
			return
		_stroke_wait = 0.0
		_paint_at_mouse(false, release_position)
		return
	_pending_drag_screen_position = release_position
	_stroke_wait = 0.0
	_try_flush_pending_drag_paint()


func _try_flush_pending_paint_request() -> void:
	if not _pending_forced_paint or not skill_active or not has_sampled_color:
		return
	var surface := _project_screen_to_body_surface(_pending_forced_paint_screen_position, true)
	if surface.is_empty():
		if not _has_pending_mesh_hit_jobs():
			_pending_forced_paint = false
		return
	_pending_forced_paint = false
	_surface_lock = surface
	_surface_lock_mouse_position = _pending_forced_paint_screen_position
	_update_surface_preview(surface)
	if _hud:
		_hud.set_brush_surface(surface.get("screen", _pending_forced_paint_screen_position), true)
	_paint_surface(surface, true)


func _append_surface_stamp(stroke_groups: Dictionary, surface: Dictionary) -> void:
	var mesh_path := str(surface.get("mesh_path", ""))
	var target_surface := int(surface.get("surface", 0))
	var key := "%s:%d" % [mesh_path, target_surface]
	if not stroke_groups.has(key):
		stroke_groups[key] = {
			"mesh_path": mesh_path,
			"surface": target_surface,
			"normal": surface.get("normal", Vector3.UP),
			"uvs": PackedVector2Array(),
			"positions": PackedVector3Array(),
			"radii": PackedFloat32Array(),
			"uv_clip_triangles": PackedVector2Array(),
			"uv_clip_triangle_counts": PackedInt32Array(),
			"uv_footprint_metrics": PackedFloat32Array(),
		}
	var group := stroke_groups[key] as Dictionary
	var uvs: PackedVector2Array = group.get("uvs", PackedVector2Array())
	var positions: PackedVector3Array = group.get("positions", PackedVector3Array())
	var radii: PackedFloat32Array = group.get("radii", PackedFloat32Array())
	var uv_clip_triangles: PackedVector2Array = group.get("uv_clip_triangles", PackedVector2Array())
	var uv_clip_triangle_counts: PackedInt32Array = group.get("uv_clip_triangle_counts", PackedInt32Array())
	var uv_footprint_metrics: PackedFloat32Array = group.get("uv_footprint_metrics", PackedFloat32Array())
	uvs.append(surface.get("uv", Vector2(0.5, 0.5)))
	positions.append(surface.get("position", Vector3.ZERO))
	radii.append(float(surface.get("texture_radius", _current_brush_radius())))
	if BRUSH_USE_UV_FOOTPRINT_MASK:
		var uv_footprint_metric: PackedFloat32Array = surface.get("uv_footprint_metric", PackedFloat32Array())
		if uv_footprint_metric.size() == 3:
			for value in uv_footprint_metric:
				uv_footprint_metrics.append(value)
		else:
			uv_footprint_metrics.append(0.0)
			uv_footprint_metrics.append(0.0)
			uv_footprint_metrics.append(0.0)
	if BRUSH_USE_UV_TRIANGLE_CLIP:
		var local_clip_triangles: PackedVector2Array = surface.get("uv_clip_triangles", PackedVector2Array())
		if not local_clip_triangles.is_empty():
			for clip_uv in local_clip_triangles:
				uv_clip_triangles.append(clip_uv)
			uv_clip_triangle_counts.append(int(local_clip_triangles.size() / 3))
		elif surface.has("face_uv0") and surface.has("face_uv1") and surface.has("face_uv2"):
			uv_clip_triangles.append(surface.get("face_uv0", Vector2.ZERO))
			uv_clip_triangles.append(surface.get("face_uv1", Vector2.ZERO))
			uv_clip_triangles.append(surface.get("face_uv2", Vector2.ZERO))
			uv_clip_triangle_counts.append(1)
		else:
			uv_clip_triangle_counts.append(0)
	group["uvs"] = uvs
	group["positions"] = positions
	group["radii"] = radii
	group["uv_clip_triangles"] = uv_clip_triangles
	group["uv_clip_triangle_counts"] = uv_clip_triangle_counts
	group["uv_footprint_metrics"] = uv_footprint_metrics


func _append_surface_brush_dab(
	stroke_groups: Dictionary,
	center_surface: Dictionary,
	full_dab: bool = true,
	use_precision_samples: bool = false
) -> void:
	if center_surface.is_empty():
		return
	var center_copy := center_surface.duplicate()
	var center_texture_radius := float(center_surface.get("texture_radius", _current_brush_radius()))
	center_copy["texture_radius"] = center_texture_radius * BRUSH_DAB_CENTER_TEXTURE_RADIUS_FACTOR
	_append_surface_stamp(stroke_groups, center_copy)
	if not full_dab or not use_precision_samples:
		return
	var screen_radius := _current_brush_radius()
	if screen_radius < BRUSH_DAB_MIN_SCREEN_RADIUS:
		return
	var center_screen: Vector2 = center_surface.get("screen", Vector2.ZERO)
	var mesh_path := str(center_surface.get("mesh_path", ""))
	if mesh_path.is_empty():
		return
	var target_surface := int(center_surface.get("surface", 0))
	var sample_distance := maxf(3.0, screen_radius * BRUSH_DAB_SAMPLE_SCREEN_FACTOR)
	var include_diagonals := screen_radius >= BRUSH_DAB_DIAGONAL_MIN_SCREEN_RADIUS
	var max_local_distance := _brush_screen_radius_to_world(center_surface.get("position", Vector3.ZERO), screen_radius) * BRUSH_DAB_MAX_LOCAL_DISTANCE_FACTOR
	var sample_radius := maxf(BRUSH_PRECISION_SAMPLE_MIN_RADIUS, center_texture_radius * BRUSH_DAB_TEXTURE_RADIUS_FACTOR)
	if center_texture_radius <= BRUSH_MIN_RADIUS * 1.8:
		_append_center_precision_anchor_samples(stroke_groups, center_surface, sample_radius)
		return
	var local_sample_count := _append_local_uv_precision_samples(
		stroke_groups,
		center_surface,
		sample_distance,
		sample_radius,
		include_diagonals
	)
	if local_sample_count != 0:
		return
	var samples_added := 1
	for offset in _brush_dab_screen_offsets(sample_distance, include_diagonals):
		if samples_added >= BRUSH_PRECISION_DAB_MAX_SAMPLES:
			break
		_metric_add("brush_precision_sample_attempts")
		var sample_surface := _project_screen_to_body_surface(center_screen + offset, true, mesh_path, target_surface)
		if sample_surface.is_empty():
			_metric_add("brush_precision_sample_misses")
			continue
		_metric_add("brush_precision_sample_hits")
		var rejection_reason := _brush_dab_sample_rejection_reason(center_surface, sample_surface, max_local_distance)
		if not rejection_reason.is_empty():
			_metric_add("brush_precision_sample_reject_" + rejection_reason)
			continue
		var sample_copy := sample_surface.duplicate()
		sample_copy["texture_radius"] = sample_radius
		_append_surface_stamp(stroke_groups, sample_copy)
		_metric_add("brush_precision_sample_accepted")
		samples_added += 1


func _append_local_uv_precision_samples(
	stroke_groups: Dictionary,
	center_surface: Dictionary,
	sample_screen_distance: float,
	sample_texture_radius: float,
	include_diagonals: bool
) -> int:
	if not center_surface.has("world_v0") or not center_surface.has("world_v1") or not center_surface.has("world_v2"):
		return 0
	if not center_surface.has("face_uv0") or not center_surface.has("face_uv1") or not center_surface.has("face_uv2"):
		return 0
	var center_position: Vector3 = center_surface.get("position", Vector3.ZERO)
	var center_normal: Vector3 = center_surface.get("normal", Vector3.UP)
	if center_normal.length_squared() <= 0.001:
		return 0
	var world_v0: Vector3 = center_surface.get("world_v0", Vector3.ZERO)
	var world_v1: Vector3 = center_surface.get("world_v1", Vector3.ZERO)
	var world_v2: Vector3 = center_surface.get("world_v2", Vector3.ZERO)
	var uv0: Vector2 = center_surface.get("face_uv0", Vector2.ZERO)
	var uv1: Vector2 = center_surface.get("face_uv1", Vector2.ZERO)
	var uv2: Vector2 = center_surface.get("face_uv2", Vector2.ZERO)
	if (world_v1 - world_v0).cross(world_v2 - world_v0).length_squared() <= 0.0000001:
		return 0
	if absf((uv1 - uv0).cross(uv2 - uv0)) <= 0.0000001:
		return 0
	var basis := _basis_from_surface_normal(center_normal.normalized())
	var axis_x := basis.x.normalized()
	var axis_y := basis.z.normalized()
	var sample_world_distance := _brush_screen_radius_to_world(center_position, sample_screen_distance)
	var center_uv: Vector2 = center_surface.get("uv", Vector2(0.5, 0.5))
	var candidate_samples: Array[Dictionary] = []
	for offset_pair in _brush_dab_screen_offset_pairs(sample_world_distance, include_diagonals):
		if candidate_samples.size() + 2 >= BRUSH_PRECISION_DAB_MAX_SAMPLES:
			break
		var pair_samples: Array[Dictionary] = []
		var pair_valid := true
		for offset in offset_pair:
			var offset_vec: Vector2 = offset
			_metric_add("brush_precision_sample_attempts")
			var sample_position: Vector3 = center_position + axis_x * offset_vec.x + axis_y * offset_vec.y
			var sample_bary := _barycentric_from_point(sample_position, world_v0, world_v1, world_v2)
			if not _is_reasonable_local_uv_sample_barycentric(sample_bary):
				_metric_add("brush_precision_sample_misses")
				pair_valid = false
				break
			var sample_uv := uv0 * sample_bary.x + uv1 * sample_bary.y + uv2 * sample_bary.z
			if sample_uv.x < 0.0 or sample_uv.x > 1.0 or sample_uv.y < 0.0 or sample_uv.y > 1.0:
				_metric_add("brush_precision_sample_misses")
				pair_valid = false
				break
			_metric_add("brush_precision_sample_hits")
			pair_samples.append({
				"uv": sample_uv,
				"position": sample_position,
				"barycentric": sample_bary,
			})
		if not pair_valid or pair_samples.size() != 2:
			continue
		if not _local_uv_precision_sample_pair_is_balanced(center_uv, pair_samples, sample_texture_radius):
			_metric_add("brush_precision_local_sample_reject_distribution")
			continue
		candidate_samples.append_array(pair_samples)
	if candidate_samples.is_empty():
		_metric_add("brush_precision_local_sample_reject_distribution")
		return -1
	if not _local_uv_precision_samples_are_centered(center_uv, candidate_samples, sample_texture_radius):
		_metric_add("brush_precision_local_sample_reject_distribution")
		return -1
	for candidate in candidate_samples:
		_metric_add("brush_precision_sample_accepted")
		_metric_add("brush_precision_local_samples")
		var sample_surface := center_surface.duplicate()
		sample_surface["uv"] = candidate.get("uv", center_uv)
		sample_surface["position"] = candidate.get("position", center_position)
		sample_surface["texture_radius"] = sample_texture_radius
		sample_surface["barycentric"] = candidate.get("barycentric", Vector3.ZERO)
		_append_surface_stamp(stroke_groups, sample_surface)
	return candidate_samples.size()


func _append_center_precision_anchor_samples(stroke_groups: Dictionary, center_surface: Dictionary, sample_texture_radius: float) -> void:
	for _index in range(4):
		_metric_add("brush_precision_sample_attempts")
		_metric_add("brush_precision_sample_hits")
		_metric_add("brush_precision_sample_accepted")
		_metric_add("brush_precision_local_samples")
		var sample_surface := center_surface.duplicate()
		sample_surface["texture_radius"] = sample_texture_radius
		_append_surface_stamp(stroke_groups, sample_surface)


static func _local_uv_precision_samples_are_centered(center_uv: Vector2, candidate_samples: Array[Dictionary], sample_texture_radius: float) -> bool:
	if candidate_samples.size() < 2:
		return false
	var center_pixel := _brush_uv_to_pixel_center_float(center_uv)
	var max_distance := maxf(BRUSH_MIN_RADIUS, sample_texture_radius * BRUSH_LOCAL_UV_SAMPLE_MAX_PIXEL_DISTANCE_FACTOR)
	var max_centroid_drift := maxf(1.5, sample_texture_radius * BRUSH_LOCAL_UV_SAMPLE_MAX_CENTROID_DRIFT_FACTOR)
	var centroid := Vector2.ZERO
	for candidate in candidate_samples:
		var sample_uv: Vector2 = candidate.get("uv", center_uv)
		var sample_pixel := _brush_uv_to_pixel_center_float(sample_uv)
		var delta := sample_pixel - center_pixel
		if delta.length() > max_distance:
			return false
		centroid += delta
	centroid /= float(candidate_samples.size())
	return centroid.length() <= max_centroid_drift


static func _local_uv_precision_sample_pair_is_balanced(center_uv: Vector2, pair_samples: Array[Dictionary], sample_texture_radius: float) -> bool:
	if pair_samples.size() != 2:
		return false
	var center_pixel := _brush_uv_to_pixel_center_float(center_uv)
	var first_pixel := _brush_uv_to_pixel_center_float(pair_samples[0].get("uv", center_uv))
	var second_pixel := _brush_uv_to_pixel_center_float(pair_samples[1].get("uv", center_uv))
	var first_delta := first_pixel - center_pixel
	var second_delta := second_pixel - center_pixel
	var midpoint_drift := (first_delta + second_delta) * 0.5
	var max_midpoint_drift := maxf(0.75, sample_texture_radius * 0.08)
	var max_length_delta := maxf(1.25, sample_texture_radius * 0.24)
	return midpoint_drift.length() <= max_midpoint_drift and absf(first_delta.length() - second_delta.length()) <= max_length_delta


func _is_reasonable_local_uv_sample_barycentric(barycentric: Vector3) -> bool:
	var min_value := minf(barycentric.x, minf(barycentric.y, barycentric.z))
	var max_value := maxf(barycentric.x, maxf(barycentric.y, barycentric.z))
	return min_value >= -BRUSH_LOCAL_UV_SAMPLE_MAX_BARY_EXTRAPOLATION and max_value <= 1.0 + BRUSH_LOCAL_UV_SAMPLE_MAX_BARY_EXTRAPOLATION


func _is_local_brush_dab_sample(center_surface: Dictionary, sample_surface: Dictionary, max_local_distance: float) -> bool:
	return _brush_dab_sample_rejection_reason(center_surface, sample_surface, max_local_distance).is_empty()


func _brush_dab_sample_rejection_reason(center_surface: Dictionary, sample_surface: Dictionary, max_local_distance: float) -> String:
	if str(sample_surface.get("mesh_path", "")) != str(center_surface.get("mesh_path", "")):
		return "mesh"
	if int(sample_surface.get("surface", 0)) != int(center_surface.get("surface", 0)):
		return "surface"
	var center_position: Vector3 = center_surface.get("position", Vector3.ZERO)
	var sample_position: Vector3 = sample_surface.get("position", Vector3.ZERO)
	if center_position.distance_to(sample_position) > maxf(max_local_distance, BRUSH_MIN_WORLD_SPACING):
		return "distance"
	var center_normal: Vector3 = center_surface.get("normal", Vector3.UP)
	var sample_normal: Vector3 = sample_surface.get("normal", Vector3.UP)
	if center_normal.length_squared() > 0.001 and sample_normal.length_squared() > 0.001:
		if center_normal.normalized().dot(sample_normal.normalized()) < BRUSH_DAB_MIN_NORMAL_DOT:
			return "normal"
	return ""


static func _brush_dab_screen_offsets(distance: float, include_diagonals: bool = false) -> PackedVector2Array:
	var offsets := PackedVector2Array()
	offsets.append(Vector2(distance, 0.0))
	offsets.append(Vector2(-distance, 0.0))
	offsets.append(Vector2(0.0, distance))
	offsets.append(Vector2(0.0, -distance))
	if include_diagonals:
		var diagonal := distance * 0.70710678
		offsets.append(Vector2(diagonal, diagonal))
		offsets.append(Vector2(-diagonal, diagonal))
		offsets.append(Vector2(diagonal, -diagonal))
		offsets.append(Vector2(-diagonal, -diagonal))
	return offsets


static func _brush_dab_screen_offset_pairs(distance: float, include_diagonals: bool = false) -> Array:
	var pairs := []
	pairs.append([Vector2(distance, 0.0), Vector2(-distance, 0.0)])
	pairs.append([Vector2(0.0, distance), Vector2(0.0, -distance)])
	if include_diagonals:
		var diagonal := distance * 0.70710678
		pairs.append([Vector2(diagonal, diagonal), Vector2(-diagonal, -diagonal)])
		pairs.append([Vector2(-diagonal, diagonal), Vector2(diagonal, -diagonal)])
	return pairs


func _resize_brush(relative: Vector2) -> void:
	brush_radius = clampf(
		brush_radius + relative.x * BRUSH_RESIZE_PIXELS_TO_RADIUS,
		BRUSH_MIN_RADIUS,
		BRUSH_MAX_RADIUS
	)
	if _hud:
		_hud.set_brush(_current_brush_radius(), brush_angle)


func _submit_brush_stroke(
	uv: Vector2,
	angle: float,
	world_position: Vector3,
	world_normal: Vector3,
	target_mesh_path: String,
	target_surface: int
) -> void:
	if not camouflage_owner or not camouflage_owner.has_method("submit_camouflage_brush_stroke"):
		return
	camouflage_owner.call(
		"submit_camouflage_brush_stroke",
		uv,
		brush_color,
		_current_brush_radius(),
		angle,
		world_position,
		world_normal,
		target_mesh_path,
		target_surface,
		paint_roughness,
		paint_metallic,
		paint_specular
	)


func _submit_brush_stroke_batch(
	uvs: PackedVector2Array,
	angle: float,
	world_positions: PackedVector3Array,
	world_normal: Vector3,
	target_mesh_path: String,
	target_surface: int,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if not camouflage_owner:
		return
	_metric_add("brush_batches_submitted")
	_metric_add("brush_stamps_submitted", uvs.size())
	if camouflage_owner.has_method("submit_camouflage_brush_stroke_batch"):
		camouflage_owner.call(
			"submit_camouflage_brush_stroke_batch",
			uvs,
			brush_color,
			_current_brush_radius(),
			angle,
			world_positions,
			world_normal,
			target_mesh_path,
			target_surface,
			brush_radii,
			uv_clip_triangles,
			uv_clip_triangle_counts,
			uv_footprint_metrics,
			paint_roughness,
			paint_metallic,
			paint_specular
		)
		return
	for index in range(uvs.size()):
		var position := world_positions[index] if index < world_positions.size() else Vector3.ZERO
		_submit_brush_stroke(uvs[index], angle, position, world_normal, target_mesh_path, target_surface)


func _orbit_owner_camera(relative: Vector2) -> void:
	if relative.length_squared() < 0.01 or not camouflage_owner:
		return
	if camouflage_owner.has_method("adjust_camouflage_camera_orbit"):
		camouflage_owner.call("adjust_camouflage_camera_orbit", relative)


func _zoom_owner_camera(step_count: float) -> void:
	if not camouflage_owner:
		return
	if camouflage_owner.has_method("adjust_camouflage_camera_zoom"):
		camouflage_owner.call("adjust_camouflage_camera_zoom", step_count)


func _set_exact_color_match(enabled: bool) -> void:
	paint_exact_color_match = enabled
	_sync_paint_material_controls()
	_update_hud_material_controls()


func _adjust_paint_roughness(delta: float) -> void:
	paint_roughness = clampf(paint_roughness + delta, 0.0, 1.0)
	_sync_paint_material_controls()
	_update_hud_material_controls()


func _adjust_paint_metallic(delta: float) -> void:
	paint_metallic = clampf(paint_metallic + delta, 0.0, 1.0)
	_sync_paint_material_controls()
	_update_hud_material_controls()


func _sync_paint_material_controls() -> void:
	if camouflage_owner and camouflage_owner.has_method("set_camouflage_paint_material_controls"):
		camouflage_owner.call("set_camouflage_paint_material_controls", paint_exact_color_match, paint_roughness, paint_metallic, paint_specular)


func _sync_paint_material_profile() -> void:
	if not camouflage_owner or not camouflage_owner.has_method("set_camouflage_paint_material_profile"):
		return
	camouflage_owner.call("set_camouflage_paint_material_profile", {
		"roughness": paint_roughness,
		"metallic": paint_metallic,
		"specular": paint_specular,
		"normal_texture": paint_normal_texture,
		"normal_scale": paint_normal_scale,
	})


func _update_hud_material_controls() -> void:
	if _hud and _hud.has_method("set_material_controls"):
		_hud.set_material_controls(paint_exact_color_match, paint_roughness, paint_metallic)


func _current_brush_radius() -> float:
	return brush_radius


func _update_surface_lock(screen_position: Vector2 = Vector2(-INF, -INF)) -> void:
	var mouse := _resolve_screen_position(screen_position)
	_surface_lock = _project_screen_to_body_surface(mouse, true)
	_surface_lock_mouse_position = mouse
	if not _hud:
		return
	if _surface_lock.is_empty():
		_hide_surface_preview()
		if _has_pending_mesh_hit_jobs() and _hud.has_method("set_preparing_surface"):
			_hud.call("set_preparing_surface")
		else:
			_hud.set_brush_surface(mouse, false)
	else:
		_update_surface_preview(_surface_lock)
		_hud.set_brush_surface(_surface_lock.get("screen", mouse), true)


func _get_surface_lock(force_refresh: bool = false, screen_position: Vector2 = Vector2(-INF, -INF)) -> Dictionary:
	var mouse := _resolve_screen_position(screen_position)
	var mouse_moved := _surface_lock_mouse_position.distance_to(mouse) > SURFACE_LOCK_MOUSE_EPSILON
	var exact_mouse_match := _surface_lock_mouse_position.distance_to(mouse) <= SURFACE_LOCK_EXACT_MOUSE_EPSILON
	if force_refresh and not _surface_lock.is_empty() and exact_mouse_match:
		return _surface_lock
	if force_refresh or _surface_lock.is_empty() or mouse_moved:
		_update_surface_lock(mouse)
	return _surface_lock


func _resolve_screen_position(screen_position: Vector2 = Vector2(-INF, -INF)) -> Vector2:
	if screen_position.x > -INF and screen_position.x < INF and screen_position.y > -INF and screen_position.y < INF:
		return screen_position
	var viewport := get_viewport()
	return viewport.get_mouse_position() if viewport else Vector2.ZERO


func _project_mouse_to_body_surface() -> Dictionary:
	var viewport := get_viewport()
	if not viewport:
		return {}
	return _project_screen_to_body_surface(viewport.get_mouse_position(), true)


func _project_screen_to_body_surface(
	screen_position: Vector2,
	allow_async_build: bool = true,
	target_mesh_path: String = "",
	target_surface: int = -1
) -> Dictionary:
	if not camera or not camouflage_owner:
		return {}
	_metric_add("surface_projection_calls")
	_metric_add("targeted_surface_projection_calls" if not target_mesh_path.is_empty() else "untargeted_surface_projection_calls")
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_dir := camera.project_ray_normal(screen_position).normalized()
	if not target_mesh_path.is_empty():
		var target_mesh := camouflage_owner.get_node_or_null(target_mesh_path) as MeshInstance3D
		if not target_mesh or not target_mesh.mesh or not _is_mesh_paintable_visible(target_mesh):
			return {}
		var targeted_hit := _intersect_mesh_triangles(target_mesh, target_mesh_path, ray_origin, ray_dir, allow_async_build, target_surface, screen_position)
		if targeted_hit.is_empty():
			targeted_hit = _intersect_mesh_screen_projection(target_mesh, target_mesh_path, screen_position, target_surface)
		return targeted_hit
	var best := {}
	var best_distance := INF
	for mesh_data in _get_paintable_meshes():
		var mesh := mesh_data.get("mesh") as MeshInstance3D
		var path := str(mesh_data.get("path", ""))
		if not mesh or not mesh.mesh or not _is_mesh_paintable_visible(mesh):
			continue
		var hit := _intersect_mesh_triangles(mesh, path, ray_origin, ray_dir, allow_async_build, -1, screen_position)
		if hit.is_empty():
			hit = _intersect_mesh_screen_projection(mesh, path, screen_position, -1)
		if hit.is_empty():
			continue
		var distance: float = hit.get("distance", INF)
		if distance < best_distance:
			best = hit
			best_distance = distance
	return best


func _get_paintable_meshes() -> Array:
	if skill_active and not _paintable_meshes_cache.is_empty() and _is_paintable_mesh_cache_valid():
		_metric_add("paintable_mesh_cache_hits")
		return _paintable_meshes_cache
	_metric_add("paintable_mesh_cache_rebuilds")
	var meshes: Array = []
	var seen := {}
	if camouflage_owner:
		for path in BODY_MESH_PATHS:
			var mesh := camouflage_owner.get_node_or_null(path) as MeshInstance3D
			if _is_mesh_paintable_visible(mesh) and not seen.has(mesh.get_instance_id()):
				meshes.append({"mesh": mesh, "path": path})
				seen[mesh.get_instance_id()] = true
		if meshes.is_empty():
			_collect_visible_meshes(camouflage_owner, meshes, seen)
	if skill_active:
		_paintable_meshes_cache = meshes
	return meshes


func _is_paintable_mesh_cache_valid() -> bool:
	for mesh_data in _paintable_meshes_cache:
		if not mesh_data is Dictionary:
			return false
		var mesh := (mesh_data as Dictionary).get("mesh") as MeshInstance3D
		if not mesh or not is_instance_valid(mesh) or not _is_mesh_paintable_visible(mesh):
			return false
	return true


func _is_mesh_paintable_visible(mesh: MeshInstance3D) -> bool:
	if not mesh or not mesh.visible:
		return false
	return not mesh.is_inside_tree() or mesh.is_visible_in_tree()


func _collect_visible_meshes(node: Node, meshes: Array, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if _is_mesh_paintable_visible(mesh) and not seen.has(mesh.get_instance_id()):
			meshes.append({"mesh": mesh, "path": str(camouflage_owner.get_path_to(mesh))})
			seen[mesh.get_instance_id()] = true
	for child in node.get_children():
		_collect_visible_meshes(child, meshes, seen)


func _intersect_mesh_triangles(
	mesh_instance: MeshInstance3D,
	mesh_path: String,
	ray_origin: Vector3,
	ray_dir: Vector3,
	allow_async_build: bool = false,
	target_surface: int = -1,
	screen_position: Vector2 = Vector2(INF, INF)
) -> Dictionary:
	_metric_add("mesh_intersection_calls")
	var mesh := mesh_instance.mesh
	if not mesh:
		return {}
	var inverse := mesh_instance.global_transform.affine_inverse()
	var local_origin: Vector3 = inverse * ray_origin
	var local_dir: Vector3 = (inverse.basis * ray_dir).normalized()
	var uses_skinned_pose := _mesh_instance_uses_skinning(mesh_instance)
	if not uses_skinned_pose and _intersect_local_aabb(mesh.get_aabb(), local_origin, local_dir).is_empty():
		return {}
	var best := {}
	var best_world_distance := INF
	var surface_start := 0
	var surface_end := mesh.get_surface_count()
	if target_surface >= 0:
		if target_surface >= surface_end:
			return {}
		surface_start = target_surface
		surface_end = target_surface + 1
	for surface in range(surface_start, surface_end):
		_metric_add("mesh_surface_tests")
		var hit_data := _get_mesh_instance_surface_hit_data(mesh_instance, surface, not allow_async_build)
		if hit_data.is_empty():
			continue
		if uses_skinned_pose and hit_data.has("aabb") and _intersect_local_aabb(hit_data.get("aabb", AABB()), local_origin, local_dir).is_empty():
			continue
		var triangle_mesh := hit_data.get("triangle_mesh") as TriangleMesh
		if not triangle_mesh:
			continue
		var triangle_hit := triangle_mesh.intersect_ray(local_origin, local_dir)
		if triangle_hit.is_empty():
			continue
		var local_hit: Vector3 = triangle_hit.get("position", Vector3.ZERO)
		var world_hit := mesh_instance.global_transform * local_hit
		var world_distance := ray_origin.distance_to(world_hit)
		if world_distance < 0.0 or world_distance >= best_world_distance:
			continue
		var face_index := int(triangle_hit.get("face_index", -1))
		var face_offset := face_index * 3
		var faces: PackedVector3Array = hit_data.get("faces", PackedVector3Array())
		var face_uvs: PackedVector2Array = hit_data.get("uvs", PackedVector2Array())
		if face_index < 0 or face_offset + 2 >= faces.size() or face_offset + 2 >= face_uvs.size():
			continue
		var v0 := faces[face_offset]
		var v1 := faces[face_offset + 1]
		var v2 := faces[face_offset + 2]
		var uv0 := face_uvs[face_offset]
		var uv1 := face_uvs[face_offset + 1]
		var uv2 := face_uvs[face_offset + 2]
		var bary := _barycentric_from_point(local_hit, v0, v1, v2)
		var uv := uv0 * bary.x + uv1 * bary.y + uv2 * bary.z
		uv = Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
		var local_normal: Vector3 = triangle_hit.get("normal", (v1 - v0).cross(v2 - v0).normalized())
		if local_normal.length_squared() <= 0.001:
			continue
		var world_v0 := mesh_instance.global_transform * v0
		var world_v1 := mesh_instance.global_transform * v1
		var world_v2 := mesh_instance.global_transform * v2
		var world_normal := (mesh_instance.global_transform.basis * local_normal.normalized()).normalized()
		var world_radius := _brush_screen_radius_to_world(world_hit, _current_brush_radius())
		var texture_radius := _estimate_texture_radius_from_triangle(world_radius, world_v0, world_v1, world_v2, uv0, uv1, uv2)
		var uv_footprint_metric := _uv_footprint_metric_from_triangle(world_radius, world_v0, world_v1, world_v2, uv0, uv1, uv2)
		if uv_footprint_metric.is_empty():
			uv_footprint_metric = _fallback_uv_footprint_metric(texture_radius)
		else:
			uv_footprint_metric = _clamp_uv_footprint_metric_to_texture_radius(uv_footprint_metric, texture_radius)
		var uv_clip_triangles := _collect_uv_clip_triangles_for_brush(hit_data, face_index, uv, texture_radius)
		best_world_distance = world_distance
		best = {
			"uv": uv,
			"screen": screen_position if screen_position.x < INF and screen_position.y < INF else (camera.unproject_position(world_hit) if camera else Vector2.ZERO),
			"position": world_hit,
			"normal": world_normal,
			"angle": _surface_normal_to_brush_angle(world_normal),
			"distance": world_distance,
			"mesh_path": mesh_path,
			"surface": surface,
			"face_index": face_index,
			"face_uv0": uv0,
			"face_uv1": uv1,
			"face_uv2": uv2,
			"world_v0": world_v0,
			"world_v1": world_v1,
			"world_v2": world_v2,
			"barycentric": bary,
			"texture_radius": texture_radius,
			"uv_footprint_metric": uv_footprint_metric,
			"uv_clip_triangles": uv_clip_triangles,
		}
	return best


func _intersect_mesh_screen_projection(
	mesh_instance: MeshInstance3D,
	mesh_path: String,
	screen_position: Vector2,
	target_surface: int = -1
) -> Dictionary:
	if not camera or not mesh_instance or not mesh_instance.mesh:
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var surface_start := 0
	var surface_end := mesh_instance.mesh.get_surface_count()
	if target_surface >= 0:
		if target_surface >= surface_end:
			return {}
		surface_start = target_surface
		surface_end = target_surface + 1
	var best := {}
	var best_screen_distance := maxf(6.0, _current_brush_radius() * 0.5)
	var best_world_distance := INF
	for surface in range(surface_start, surface_end):
		var hit_data := _get_mesh_instance_surface_hit_data(mesh_instance, surface, true)
		if hit_data.is_empty():
			continue
		var faces: PackedVector3Array = hit_data.get("faces", PackedVector3Array())
		var face_uvs: PackedVector2Array = hit_data.get("uvs", PackedVector2Array())
		var triangle_count := mini(int(faces.size() / 3), int(face_uvs.size() / 3))
		for face_index in range(triangle_count):
			var face_offset := face_index * 3
			var v0 := faces[face_offset]
			var v1 := faces[face_offset + 1]
			var v2 := faces[face_offset + 2]
			var world_v0 := mesh_instance.global_transform * v0
			var world_v1 := mesh_instance.global_transform * v1
			var world_v2 := mesh_instance.global_transform * v2
			if camera.is_position_behind(world_v0) and camera.is_position_behind(world_v1) and camera.is_position_behind(world_v2):
				continue
			var screen_v0 := camera.unproject_position(world_v0)
			var screen_v1 := camera.unproject_position(world_v1)
			var screen_v2 := camera.unproject_position(world_v2)
			var screen_distance := _distance_to_screen_triangle(screen_position, screen_v0, screen_v1, screen_v2)
			if screen_distance > best_screen_distance + 0.001:
				continue
			var bary := _barycentric_from_screen_point(screen_position, screen_v0, screen_v1, screen_v2)
			if bary.x < -0.001 or bary.y < -0.001 or bary.z < -0.001:
				var closest := _closest_point_on_screen_triangle(screen_position, screen_v0, screen_v1, screen_v2)
				bary = _barycentric_from_screen_point(closest, screen_v0, screen_v1, screen_v2)
			bary = Vector3(maxf(0.0, bary.x), maxf(0.0, bary.y), maxf(0.0, bary.z))
			var bary_sum := bary.x + bary.y + bary.z
			if bary_sum <= 0.000001:
				continue
			bary /= bary_sum
			var world_hit := world_v0 * bary.x + world_v1 * bary.y + world_v2 * bary.z
			var world_distance := ray_origin.distance_to(world_hit)
			if absf(screen_distance - best_screen_distance) <= 0.001 and world_distance >= best_world_distance:
				continue
			var uv0 := face_uvs[face_offset]
			var uv1 := face_uvs[face_offset + 1]
			var uv2 := face_uvs[face_offset + 2]
			var uv := uv0 * bary.x + uv1 * bary.y + uv2 * bary.z
			uv = Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
			var world_normal := (world_v1 - world_v0).cross(world_v2 - world_v0).normalized()
			if world_normal.length_squared() <= 0.001:
				continue
			var world_radius := _brush_screen_radius_to_world(world_hit, _current_brush_radius())
			var texture_radius := _estimate_texture_radius_from_triangle(world_radius, world_v0, world_v1, world_v2, uv0, uv1, uv2)
			var uv_footprint_metric := _uv_footprint_metric_from_triangle(world_radius, world_v0, world_v1, world_v2, uv0, uv1, uv2)
			if uv_footprint_metric.is_empty():
				uv_footprint_metric = _fallback_uv_footprint_metric(texture_radius)
			else:
				uv_footprint_metric = _clamp_uv_footprint_metric_to_texture_radius(uv_footprint_metric, texture_radius)
			best_screen_distance = screen_distance
			best_world_distance = world_distance
			best = {
				"uv": uv,
				"screen": screen_position,
				"position": world_hit,
				"normal": world_normal,
				"angle": _surface_normal_to_brush_angle(world_normal),
				"distance": world_distance,
				"mesh_path": mesh_path,
				"surface": surface,
				"face_index": face_index,
				"face_uv0": uv0,
				"face_uv1": uv1,
				"face_uv2": uv2,
				"world_v0": world_v0,
				"world_v1": world_v1,
				"world_v2": world_v2,
				"barycentric": bary,
				"texture_radius": texture_radius,
				"uv_footprint_metric": uv_footprint_metric,
				"uv_clip_triangles": _collect_uv_clip_triangles_for_brush(hit_data, face_index, uv, texture_radius),
			}
	return best


func _request_paintable_mesh_cache_warmup() -> void:
	for mesh_data in _get_paintable_meshes():
		var mesh_instance := mesh_data.get("mesh") as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			if not _should_prewarm_surface(mesh_instance.mesh, surface):
				continue
			_get_mesh_instance_surface_hit_data(mesh_instance, surface, false)


func _finalize_mesh_hit_cache_jobs() -> void:
	if _mesh_hit_build_jobs.is_empty():
		return
	var completed_keys: Array[String] = []
	var completed_current_keys: Array[String] = []
	for cache_key in _mesh_hit_build_jobs.keys():
		var thread := _mesh_hit_build_jobs[cache_key] as Thread
		if not thread or thread.is_alive():
			continue
		var data = thread.wait_to_finish()
		if _is_stale_pose_hit_cache_key(str(cache_key)):
			_metric_add("mesh_hit_cache_pose_prunes")
		else:
			_mesh_hit_cache[cache_key] = data if data is Dictionary else {}
			completed_current_keys.append(str(cache_key))
		completed_keys.append(cache_key)
	for cache_key in completed_keys:
		_mesh_hit_build_jobs.erase(cache_key)
	if not completed_current_keys.is_empty():
		_try_flush_pending_paint_request()


func _has_pending_mesh_hit_jobs() -> bool:
	for cache_key in _mesh_hit_build_jobs.keys():
		if not _is_stale_pose_hit_cache_key(str(cache_key)):
			return true
	return false


func _get_mesh_surface_hit_data(mesh: Mesh, surface: int, build_synchronously: bool = true) -> Dictionary:
	var cache_key := "%d:%d" % [mesh.get_instance_id(), surface]
	if _mesh_hit_cache.has(cache_key):
		_metric_add("mesh_hit_cache_hits")
		return _mesh_hit_cache[cache_key]
	_metric_add("mesh_hit_cache_misses")
	if _mesh_hit_build_jobs.has(cache_key):
		if not build_synchronously:
			return {}
		var thread := _mesh_hit_build_jobs[cache_key] as Thread
		var data = thread.wait_to_finish() if thread else {}
		_mesh_hit_cache[cache_key] = data if data is Dictionary else {}
		_mesh_hit_build_jobs.erase(cache_key)
		return _mesh_hit_cache[cache_key]

	if not build_synchronously:
		var thread := Thread.new()
		var start_error := thread.start(Callable(CamouflageSystem, "_build_surface_hit_data_from_mesh").bind(mesh, surface))
		if start_error == OK:
			_mesh_hit_build_jobs[cache_key] = thread
			_metric_add("mesh_hit_cache_async_jobs")
			return {}

	var arrays := _get_mesh_surface_arrays(mesh, surface)
	if arrays.is_empty():
		_mesh_hit_cache[cache_key] = {}
		return {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.is_empty() or uvs.size() != vertices.size():
		_mesh_hit_cache[cache_key] = {}
		return {}

	var indices := _packed_int_array_from(arrays[Mesh.ARRAY_INDEX])
	var triangle_count := int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
	if triangle_count <= 0:
		_mesh_hit_cache[cache_key] = {}
		return {}

	var data := CamouflageSystem._build_surface_hit_data_from_arrays(vertices, uvs, indices, triangle_count)
	_mesh_hit_cache[cache_key] = data
	return data


func _get_mesh_instance_surface_hit_data(
	mesh_instance: MeshInstance3D,
	surface: int,
	build_synchronously: bool = true
) -> Dictionary:
	if _mesh_instance_uses_skinning(mesh_instance):
		return _get_skinned_mesh_surface_hit_data(mesh_instance, surface, build_synchronously)
	return _get_mesh_surface_hit_data(mesh_instance.mesh, surface, build_synchronously)


func _get_skinned_mesh_surface_hit_data(
	mesh_instance: MeshInstance3D,
	surface: int,
	build_synchronously: bool = true
) -> Dictionary:
	_sync_skinned_pose_hit_cache_generation(mesh_instance)
	var cache_key := "%d:%d:pose:%d" % [mesh_instance.get_instance_id(), surface, _pose_hit_cache_generation]
	if _mesh_hit_cache.has(cache_key):
		_metric_add("mesh_hit_cache_hits")
		return _mesh_hit_cache[cache_key]
	_metric_add("mesh_hit_cache_misses")
	if _mesh_hit_build_jobs.has(cache_key):
		if not build_synchronously:
			return {}
		var pending_thread := _mesh_hit_build_jobs[cache_key] as Thread
		var pending_data = pending_thread.wait_to_finish() if pending_thread else {}
		_mesh_hit_cache[cache_key] = pending_data if pending_data is Dictionary else {}
		_mesh_hit_build_jobs.erase(cache_key)
		return _mesh_hit_cache[cache_key]

	var snapshot := _create_skinned_surface_snapshot(mesh_instance, surface)
	if snapshot.is_empty():
		_mesh_hit_cache[cache_key] = {}
		return {}

	if not build_synchronously:
		var thread := Thread.new()
		var start_error := thread.start(Callable(CamouflageSystem, "_build_skinned_surface_hit_data_from_snapshot").bind(snapshot))
		if start_error == OK:
			_mesh_hit_build_jobs[cache_key] = thread
			_metric_add("mesh_hit_cache_async_jobs")
		return {}

	var data := CamouflageSystem._build_skinned_surface_hit_data_from_snapshot(snapshot)
	_mesh_hit_cache[cache_key] = data
	return data


func _sync_skinned_pose_hit_cache_generation(mesh_instance: MeshInstance3D) -> void:
	var signature := _skinned_pose_signature(mesh_instance)
	if signature == 0:
		return
	var key := str(mesh_instance.get_instance_id())
	if not _skinned_pose_signatures.has(key):
		_skinned_pose_signatures[key] = signature
		return
	if int(_skinned_pose_signatures.get(key, 0)) == signature:
		return
	_skinned_pose_signatures[key] = signature
	_advance_pose_hit_cache_generation()


func _skinned_pose_signature(mesh_instance: MeshInstance3D) -> int:
	if not _mesh_instance_uses_skinning(mesh_instance):
		return 0
	var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
	var skin := mesh_instance.skin
	if not skeleton or not skin:
		return 0
	var values: Array[int] = []
	values.append(skeleton.get_instance_id())
	values.append(mesh_instance.get_instance_id())
	values.append(skeleton.get_bone_count())
	values.append(skin.get_bind_count())
	_append_transform_signature_values(values, skeleton.global_transform.affine_inverse() * mesh_instance.global_transform)
	for bind_index in range(skin.get_bind_count()):
		var bone_index := int(skin.get_bind_bone(bind_index))
		if bone_index < 0:
			var bind_name := str(skin.get_bind_name(bind_index))
			bone_index = skeleton.find_bone(bind_name) if not bind_name.is_empty() else -1
		values.append(bone_index)
		if bone_index < 0 or bone_index >= skeleton.get_bone_count():
			continue
		_append_transform_signature_values(values, skeleton.get_bone_global_pose(bone_index))
	var signature := hash(values)
	return signature if signature != 0 else 1


func _append_transform_signature_values(values: Array[int], transform: Transform3D) -> void:
	_append_vector3_signature_values(values, transform.basis.x)
	_append_vector3_signature_values(values, transform.basis.y)
	_append_vector3_signature_values(values, transform.basis.z)
	_append_vector3_signature_values(values, transform.origin)


func _append_vector3_signature_values(values: Array[int], vector: Vector3) -> void:
	values.append(roundi(vector.x * SKINNED_POSE_SIGNATURE_QUANTIZATION))
	values.append(roundi(vector.y * SKINNED_POSE_SIGNATURE_QUANTIZATION))
	values.append(roundi(vector.z * SKINNED_POSE_SIGNATURE_QUANTIZATION))


func _mesh_instance_uses_skinning(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance or not mesh_instance.mesh or not mesh_instance.skin:
		return false
	if mesh_instance.skeleton.is_empty():
		return false
	return mesh_instance.get_node_or_null(mesh_instance.skeleton) is Skeleton3D


func _create_skinned_surface_snapshot(mesh_instance: MeshInstance3D, surface: int) -> Dictionary:
	if not _mesh_instance_uses_skinning(mesh_instance):
		return {}
	var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
	var skin := mesh_instance.skin
	if not skeleton or not skin:
		return {}

	var skeleton_from_mesh := skeleton.global_transform.affine_inverse() * mesh_instance.global_transform
	var mesh_from_skeleton := skeleton_from_mesh.affine_inverse()
	var bone_transforms: Array[Transform3D] = []
	var bind_count := skin.get_bind_count()
	bone_transforms.resize(bind_count)
	for bind_index in range(bind_count):
		var bone_index := int(skin.get_bind_bone(bind_index))
		if bone_index < 0:
			var bind_name := str(skin.get_bind_name(bind_index))
			bone_index = skeleton.find_bone(bind_name) if not bind_name.is_empty() else -1
		if bone_index < 0 or bone_index >= skeleton.get_bone_count():
			bone_transforms[bind_index] = Transform3D.IDENTITY
			continue
		var pose := skeleton.get_bone_global_pose(bone_index)
		var inverse_bind := skin.get_bind_pose(bind_index)
		bone_transforms[bind_index] = mesh_from_skeleton * pose * inverse_bind * skeleton_from_mesh

	return {
		"mesh": mesh_instance.mesh,
		"surface": surface,
		"bone_transforms": bone_transforms,
	}


func _should_prewarm_surface(mesh: Mesh, surface: int) -> bool:
	var triangle_count := _get_mesh_surface_triangle_count_estimate(mesh, surface)
	return triangle_count > 0 and triangle_count <= HIT_CACHE_PREWARM_TRIANGLE_LIMIT


func _get_mesh_surface_triangle_count_estimate(mesh: Mesh, surface: int) -> int:
	if not mesh:
		return 0
	if mesh is PrimitiveMesh:
		var primitive_arrays := (mesh as PrimitiveMesh).get_mesh_arrays()
		if primitive_arrays.is_empty():
			return 0
		var primitive_indices: PackedInt32Array = primitive_arrays[Mesh.ARRAY_INDEX]
		if not primitive_indices.is_empty():
			return int(primitive_indices.size() / 3)
		var primitive_vertices: PackedVector3Array = primitive_arrays[Mesh.ARRAY_VERTEX]
		return int(primitive_vertices.size() / 3)
	var arrays := _get_mesh_surface_arrays(mesh, surface)
	if not arrays.is_empty():
		var indices := _packed_int_array_from(arrays[Mesh.ARRAY_INDEX])
		if not indices.is_empty():
			return int(indices.size() / 3)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		return int(vertices.size() / 3)
	if mesh.has_method("surface_get_array_index_len"):
		var index_len := int(mesh.call("surface_get_array_index_len", surface))
		if index_len > 0:
			return int(index_len / 3)
	if mesh.has_method("surface_get_array_len"):
		var array_len := int(mesh.call("surface_get_array_len", surface))
		if array_len > 0:
			return int(array_len / 3)
	return 0


static func _build_surface_hit_data_from_arrays(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	triangle_count: int
) -> Dictionary:
	var faces := PackedVector3Array()
	var face_uvs := PackedVector2Array()
	faces.resize(triangle_count * 3)
	face_uvs.resize(triangle_count * 3)
	var write_index := 0
	var has_bounds := false
	var min_point := Vector3.ZERO
	var max_point := Vector3.ZERO
	for triangle in range(triangle_count):
		var i0 := int(indices[triangle * 3]) if not indices.is_empty() else triangle * 3
		var i1 := int(indices[triangle * 3 + 1]) if not indices.is_empty() else triangle * 3 + 1
		var i2 := int(indices[triangle * 3 + 2]) if not indices.is_empty() else triangle * 3 + 2
		if i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
			continue
		faces[write_index] = vertices[i0]
		faces[write_index + 1] = vertices[i1]
		faces[write_index + 2] = vertices[i2]
		for point in [vertices[i0], vertices[i1], vertices[i2]]:
			if not has_bounds:
				min_point = point
				max_point = point
				has_bounds = true
			else:
				min_point = Vector3(
					minf(min_point.x, point.x),
					minf(min_point.y, point.y),
					minf(min_point.z, point.z)
				)
				max_point = Vector3(
					maxf(max_point.x, point.x),
					maxf(max_point.y, point.y),
					maxf(max_point.z, point.z)
				)
		face_uvs[write_index] = uvs[i0]
		face_uvs[write_index + 1] = uvs[i1]
		face_uvs[write_index + 2] = uvs[i2]
		write_index += 3
	if write_index <= 0:
		return {}
	if write_index < faces.size():
		faces.resize(write_index)
		face_uvs.resize(write_index)

	var triangle_mesh: TriangleMesh = null
	triangle_mesh = TriangleMesh.new()
	if not triangle_mesh.create_from_faces(faces):
		return {}
	var data := {
		"triangle_mesh": triangle_mesh,
		"faces": faces,
		"uvs": face_uvs,
		"uv_neighbors": CamouflageSystem._build_uv_triangle_neighbors(face_uvs) if BRUSH_USE_UV_TRIANGLE_CLIP else [],
		"triangle_count": int(faces.size() / 3),
		"aabb": AABB(min_point, max_point - min_point),
	}
	return data


static func _build_skinned_surface_hit_data_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = snapshot.get("vertices", PackedVector3Array())
	var uvs: PackedVector2Array = snapshot.get("uvs", PackedVector2Array())
	var indices: PackedInt32Array = snapshot.get("indices", PackedInt32Array())
	var bones = snapshot.get("bones", PackedInt32Array())
	var weights = snapshot.get("weights", PackedFloat32Array())
	var bone_transforms: Array = snapshot.get("bone_transforms", [])
	var influences_per_vertex := int(snapshot.get("influences_per_vertex", 0))
	var triangle_count := int(snapshot.get("triangle_count", 0))
	if vertices.is_empty():
		var mesh := snapshot.get("mesh", null) as Mesh
		var surface := int(snapshot.get("surface", 0))
		var arrays := CamouflageSystem._get_mesh_surface_arrays_static(mesh, surface)
		if arrays.is_empty():
			return {}
		vertices = arrays[Mesh.ARRAY_VERTEX]
		uvs = arrays[Mesh.ARRAY_TEX_UV]
		indices = _packed_int_array_from(arrays[Mesh.ARRAY_INDEX])
		bones = _packed_int_array_from(arrays[Mesh.ARRAY_BONES])
		weights = _packed_float_array_from(arrays[Mesh.ARRAY_WEIGHTS])
		if bones != null and vertices.size() > 0 and bones.size() % vertices.size() == 0:
			influences_per_vertex = int(bones.size() / vertices.size())
		triangle_count = int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
	if vertices.is_empty() or uvs.size() != vertices.size() or influences_per_vertex <= 0 or triangle_count <= 0:
		return {}
	if bones == null or weights == null or bones.size() != weights.size() or bones.size() < vertices.size() * influences_per_vertex:
		return {}
	var skinned_vertices := PackedVector3Array()
	skinned_vertices.resize(vertices.size())
	for vertex_index in range(vertices.size()):
		var source := vertices[vertex_index]
		var weighted := Vector3.ZERO
		var weight_sum := 0.0
		var influence_offset := vertex_index * influences_per_vertex
		for influence in range(influences_per_vertex):
			var weight := float(weights[influence_offset + influence])
			if weight <= 0.00001:
				continue
			var bind_index := int(bones[influence_offset + influence])
			if bind_index < 0 or bind_index >= bone_transforms.size():
				continue
			var transform := bone_transforms[bind_index] as Transform3D
			weighted += (transform * source) * weight
			weight_sum += weight
		if weight_sum > 0.00001:
			skinned_vertices[vertex_index] = weighted / weight_sum
		else:
			skinned_vertices[vertex_index] = source
	return CamouflageSystem._build_surface_hit_data_from_arrays(skinned_vertices, uvs, indices, triangle_count)


static func _build_uv_triangle_neighbors(face_uvs: PackedVector2Array) -> Array:
	var triangle_count := int(face_uvs.size() / 3)
	var neighbor_sets: Array[Dictionary] = []
	neighbor_sets.resize(triangle_count)
	for triangle in range(triangle_count):
		neighbor_sets[triangle] = {}
	var edge_map := {}
	for triangle in range(triangle_count):
		var offset := triangle * 3
		var triangle_uvs := [
			face_uvs[offset],
			face_uvs[offset + 1],
			face_uvs[offset + 2],
		]
		for edge in range(3):
			var edge_a: Vector2 = triangle_uvs[edge]
			var edge_b: Vector2 = triangle_uvs[(edge + 1) % 3]
			if edge_a.distance_squared_to(edge_b) <= 0.0000000001:
				continue
			var key := CamouflageSystem._uv_edge_key(edge_a, edge_b)
			if not edge_map.has(key):
				edge_map[key] = PackedInt32Array()
			var triangles: PackedInt32Array = edge_map[key]
			triangles.append(triangle)
			edge_map[key] = triangles
	for triangles in edge_map.values():
		var edge_triangles := triangles as PackedInt32Array
		if edge_triangles.size() < 2:
			continue
		if edge_triangles.size() > BRUSH_UV_EDGE_FAN_LIMIT:
			continue
		for left_index in range(edge_triangles.size()):
			for right_index in range(left_index + 1, edge_triangles.size()):
				var left := int(edge_triangles[left_index])
				var right := int(edge_triangles[right_index])
				(neighbor_sets[left] as Dictionary)[right] = true
				(neighbor_sets[right] as Dictionary)[left] = true
	var neighbors: Array[PackedInt32Array] = []
	neighbors.resize(triangle_count)
	for triangle in range(triangle_count):
		var packed := PackedInt32Array()
		for neighbor in (neighbor_sets[triangle] as Dictionary).keys():
			packed.append(int(neighbor))
		neighbors[triangle] = packed
	return neighbors


static func _uv_edge_key(a: Vector2, b: Vector2) -> String:
	var ai := Vector2i(roundi(a.x * 100000.0), roundi(a.y * 100000.0))
	var bi := Vector2i(roundi(b.x * 100000.0), roundi(b.y * 100000.0))
	if ai.x > bi.x or (ai.x == bi.x and ai.y > bi.y):
		var swap := ai
		ai = bi
		bi = swap
	return "%d,%d:%d,%d" % [ai.x, ai.y, bi.x, bi.y]


static func _build_surface_hit_data_from_mesh(mesh: Mesh, surface: int) -> Dictionary:
	var arrays := CamouflageSystem._get_mesh_surface_arrays_static(mesh, surface)
	if arrays.is_empty():
		return {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.is_empty() or uvs.size() != vertices.size():
		return {}
	var indices := _packed_int_array_from(arrays[Mesh.ARRAY_INDEX])
	var triangle_count := int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
	if triangle_count <= 0:
		return {}
	return CamouflageSystem._build_surface_hit_data_from_arrays(vertices, uvs, indices, triangle_count)


func _get_mesh_surface_arrays(mesh: Mesh, surface: int) -> Array:
	return CamouflageSystem._get_mesh_surface_arrays_static(mesh, surface)


static func _get_mesh_surface_arrays_static(mesh: Mesh, surface: int) -> Array:
	if not mesh:
		return []
	if mesh is PrimitiveMesh:
		if surface != 0:
			return []
		return (mesh as PrimitiveMesh).get_mesh_arrays()
	if mesh.has_method("surface_get_primitive_type"):
		var primitive_type := int(mesh.call("surface_get_primitive_type", surface))
		if primitive_type != Mesh.PRIMITIVE_TRIANGLES:
			return []
	if mesh.has_method("surface_get_arrays"):
		return mesh.call("surface_get_arrays", surface)
	return []


func _barycentric_from_point(point: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> Vector3:
	var edge0 := v1 - v0
	var edge1 := v2 - v0
	var point_edge := point - v0
	var d00 := edge0.dot(edge0)
	var d01 := edge0.dot(edge1)
	var d11 := edge1.dot(edge1)
	var d20 := point_edge.dot(edge0)
	var d21 := point_edge.dot(edge1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 0.000001:
		return Vector3(1.0, 0.0, 0.0)
	var bary_y := (d11 * d20 - d01 * d21) / denom
	var bary_z := (d00 * d21 - d01 * d20) / denom
	var bary_x := 1.0 - bary_y - bary_z
	return Vector3(bary_x, bary_y, bary_z)


static func _barycentric_from_screen_point(point: Vector2, v0: Vector2, v1: Vector2, v2: Vector2) -> Vector3:
	var edge0 := v1 - v0
	var edge1 := v2 - v0
	var point_edge := point - v0
	var d00 := edge0.dot(edge0)
	var d01 := edge0.dot(edge1)
	var d11 := edge1.dot(edge1)
	var d20 := point_edge.dot(edge0)
	var d21 := point_edge.dot(edge1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 0.000001:
		return Vector3(1.0, 0.0, 0.0)
	var bary_y := (d11 * d20 - d01 * d21) / denom
	var bary_z := (d00 * d21 - d01 * d20) / denom
	var bary_x := 1.0 - bary_y - bary_z
	return Vector3(bary_x, bary_y, bary_z)


static func _packed_int_array_from(value) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value
	return PackedInt32Array()


static func _packed_float_array_from(value) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value
	return PackedFloat32Array()


static func _distance_to_screen_triangle(point: Vector2, v0: Vector2, v1: Vector2, v2: Vector2) -> float:
	var bary := _barycentric_from_screen_point(point, v0, v1, v2)
	if bary.x >= -0.00001 and bary.y >= -0.00001 and bary.z >= -0.00001:
		return 0.0
	return minf(
		_distance_to_segment_2d(point, v0, v1),
		minf(_distance_to_segment_2d(point, v1, v2), _distance_to_segment_2d(point, v2, v0))
	)


static func _closest_point_on_screen_triangle(point: Vector2, v0: Vector2, v1: Vector2, v2: Vector2) -> Vector2:
	var bary := _barycentric_from_screen_point(point, v0, v1, v2)
	if bary.x >= -0.00001 and bary.y >= -0.00001 and bary.z >= -0.00001:
		return point
	var closest := _closest_point_on_segment_2d(point, v0, v1)
	var closest_distance := point.distance_squared_to(closest)
	var candidate := _closest_point_on_segment_2d(point, v1, v2)
	var candidate_distance := point.distance_squared_to(candidate)
	if candidate_distance < closest_distance:
		closest = candidate
		closest_distance = candidate_distance
	candidate = _closest_point_on_segment_2d(point, v2, v0)
	candidate_distance = point.distance_squared_to(candidate)
	if candidate_distance < closest_distance:
		closest = candidate
	return closest


func _collect_uv_clip_triangles_for_brush(
	hit_data: Dictionary,
	face_index: int,
	uv_center: Vector2,
	texture_radius: float
) -> PackedVector2Array:
	if not BRUSH_USE_UV_TRIANGLE_CLIP:
		return PackedVector2Array()
	if face_index < 0:
		return PackedVector2Array()
	var face_uvs: PackedVector2Array = hit_data.get("uvs", PackedVector2Array())
	var triangle_count := int(face_uvs.size() / 3)
	if face_index >= triangle_count:
		return PackedVector2Array()
	var neighbors: Array = hit_data.get("uv_neighbors", [])
	var uv_radius := texture_radius / float(TEXTURE_SIZE) + BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS / float(TEXTURE_SIZE)
	var result := PackedVector2Array()
	var visited := {}
	var queue := PackedInt32Array([face_index])
	var queue_index := 0
	while queue_index < queue.size() and int(result.size() / 3) < BRUSH_UV_CLIP_MAX_TRIANGLES:
		var triangle := int(queue[queue_index])
		queue_index += 1
		if visited.has(triangle) or triangle < 0 or triangle >= triangle_count:
			continue
		visited[triangle] = true
		var offset := triangle * 3
		var uv0 := face_uvs[offset]
		var uv1 := face_uvs[offset + 1]
		var uv2 := face_uvs[offset + 2]
		if not _uv_triangle_intersects_circle(uv0, uv1, uv2, uv_center, uv_radius):
			continue
		result.append(uv0)
		result.append(uv1)
		result.append(uv2)
		if triangle < neighbors.size():
			var triangle_neighbors: PackedInt32Array = neighbors[triangle]
			for neighbor in triangle_neighbors:
				if not visited.has(int(neighbor)):
					queue.append(int(neighbor))
	return result


static func _uv_triangle_intersects_circle(
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2,
	center: Vector2,
	radius: float
) -> bool:
	if _uv_point_inside_triangle_or_margin(center, uv0, uv1, uv2, 0.0):
		return true
	if uv0.distance_to(center) <= radius or uv1.distance_to(center) <= radius or uv2.distance_to(center) <= radius:
		return true
	return (
		_distance_to_segment_2d(center, uv0, uv1) <= radius
		or _distance_to_segment_2d(center, uv1, uv2) <= radius
		or _distance_to_segment_2d(center, uv2, uv0) <= radius
	)


func _intersect_local_aabb(aabb: AABB, origin: Vector3, direction: Vector3) -> Dictionary:
	var min_point := aabb.position
	var max_point := aabb.position + aabb.size
	var tmin := -INF
	var tmax := INF
	var normal := Vector3.ZERO
	for axis in range(3):
		var origin_axis := origin[axis]
		var direction_axis := direction[axis]
		var min_axis := min_point[axis]
		var max_axis := max_point[axis]
		if absf(direction_axis) < 0.000001:
			if origin_axis < min_axis or origin_axis > max_axis:
				return {}
			continue
		var inv_dir := 1.0 / direction_axis
		var t1 := (min_axis - origin_axis) * inv_dir
		var t2 := (max_axis - origin_axis) * inv_dir
		var axis_normal := Vector3.ZERO
		axis_normal[axis] = -signf(direction_axis)
		if t1 > t2:
			var swap_t := t1
			t1 = t2
			t2 = swap_t
			axis_normal[axis] = signf(direction_axis)
		if t1 > tmin:
			tmin = t1
			normal = axis_normal
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return {}
	var t := tmin if tmin >= 0.0 else tmax
	if t < 0.0:
		return {}
	return {
		"position": origin + direction * t,
		"normal": normal if normal.length_squared() > 0.001 else Vector3.UP,
	}


func _surface_normal_to_brush_angle(world_normal: Vector3) -> float:
	if not camera:
		return brush_angle
	var camera_normal := camera.global_transform.basis.inverse() * world_normal
	return atan2(camera_normal.x, camera_normal.y)


static func _estimate_texture_radius_from_triangle(
	world_radius: float,
	world_v0: Vector3,
	world_v1: Vector3,
	world_v2: Vector3,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2
) -> float:
	var world_edge_u := world_v1 - world_v0
	var world_edge_v := world_v2 - world_v0
	var tangent_x := world_edge_u
	if tangent_x.length_squared() <= 0.0000001:
		return clampf(world_radius * float(TEXTURE_SIZE), BRUSH_MIN_RADIUS, BRUSH_MAX_RADIUS)
	tangent_x = tangent_x.normalized()
	var normal := world_edge_u.cross(world_edge_v)
	if normal.length_squared() <= 0.0000001:
		return clampf(world_radius * float(TEXTURE_SIZE), BRUSH_MIN_RADIUS, BRUSH_MAX_RADIUS)
	var tangent_y := normal.normalized().cross(tangent_x).normalized()
	var w00 := world_edge_u.dot(tangent_x)
	var w01 := world_edge_v.dot(tangent_x)
	var w10 := world_edge_u.dot(tangent_y)
	var w11 := world_edge_v.dot(tangent_y)
	var det := w00 * w11 - w01 * w10
	if absf(det) <= 0.0000001:
		return clampf(world_radius * float(TEXTURE_SIZE), BRUSH_MIN_RADIUS, BRUSH_MAX_RADIUS)
	var inv00 := w11 / det
	var inv01 := -w01 / det
	var inv10 := -w10 / det
	var inv11 := w00 / det
	var uv_edge_u := (uv1 - uv0) * float(TEXTURE_SIZE)
	var uv_edge_v := (uv2 - uv0) * float(TEXTURE_SIZE)
	var j00 := uv_edge_u.x * inv00 + uv_edge_v.x * inv10
	var j01 := uv_edge_u.x * inv01 + uv_edge_v.x * inv11
	var j10 := uv_edge_u.y * inv00 + uv_edge_v.y * inv10
	var j11 := uv_edge_u.y * inv01 + uv_edge_v.y * inv11
	var a := j00 * j00 + j10 * j10
	var b := j00 * j01 + j10 * j11
	var d := j01 * j01 + j11 * j11
	var trace := a + d
	var discriminant := maxf(0.0, (a - d) * (a - d) + 4.0 * b * b)
	var largest_eigenvalue := (trace + sqrt(discriminant)) * 0.5
	var pixels_per_world := sqrt(maxf(largest_eigenvalue, 0.0))
	return clampf(world_radius * pixels_per_world, BRUSH_MIN_RADIUS, BRUSH_MAX_RADIUS)


static func _uv_footprint_metric_from_triangle(
	world_radius: float,
	world_v0: Vector3,
	world_v1: Vector3,
	world_v2: Vector3,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2
) -> PackedFloat32Array:
	if world_radius <= 0.0001:
		return PackedFloat32Array()
	var world_edge_u := world_v1 - world_v0
	var world_edge_v := world_v2 - world_v0
	var tangent_x := world_edge_u
	if tangent_x.length_squared() <= 0.0000001:
		return PackedFloat32Array()
	tangent_x = tangent_x.normalized()
	var normal := world_edge_u.cross(world_edge_v)
	if normal.length_squared() <= 0.0000001:
		return PackedFloat32Array()
	var tangent_y := normal.normalized().cross(tangent_x).normalized()
	var w00 := world_edge_u.dot(tangent_x)
	var w01 := world_edge_v.dot(tangent_x)
	var w10 := world_edge_u.dot(tangent_y)
	var w11 := world_edge_v.dot(tangent_y)
	var uv_edge_u := uv1 - uv0
	var uv_edge_v := uv2 - uv0
	var det := uv_edge_u.x * uv_edge_v.y - uv_edge_v.x * uv_edge_u.y
	if absf(det) <= 0.0000001:
		return PackedFloat32Array()
	var inv00 := uv_edge_v.y / det
	var inv01 := -uv_edge_v.x / det
	var inv10 := -uv_edge_u.y / det
	var inv11 := uv_edge_u.x / det
	var a00 := w00 * inv00 + w01 * inv10
	var a01 := w00 * inv01 + w01 * inv11
	var a10 := w10 * inv00 + w11 * inv10
	var a11 := w10 * inv01 + w11 * inv11
	var inv_radius_sq := 1.0 / (world_radius * world_radius)
	return PackedFloat32Array([
		(a00 * a00 + a10 * a10) * inv_radius_sq,
		(a00 * a01 + a10 * a11) * inv_radius_sq,
		(a01 * a01 + a11 * a11) * inv_radius_sq,
	])


static func _fallback_uv_footprint_metric(texture_radius: float) -> PackedFloat32Array:
	var radius_uv := clampf(texture_radius / float(TEXTURE_SIZE), 0.0001, 1.0)
	var value := 1.0 / (radius_uv * radius_uv)
	return PackedFloat32Array([value, 0.0, value])


static func _clamp_uv_footprint_metric_to_texture_radius(footprint_metric: PackedFloat32Array, texture_radius: float) -> PackedFloat32Array:
	if not _has_uv_footprint_metric(footprint_metric):
		return _fallback_uv_footprint_metric(texture_radius)
	var radius_uv := clampf(texture_radius / float(TEXTURE_SIZE), 0.0001, 1.0)
	var max_allowed_eigenvalue := 1.0 / (radius_uv * radius_uv)
	var a := maxf(0.0, footprint_metric[0])
	var b := footprint_metric[1]
	var d := maxf(0.0, footprint_metric[2])
	var trace := a + d
	var discriminant := maxf(0.0, (a - d) * (a - d) + 4.0 * b * b)
	var largest_eigenvalue := (trace + sqrt(discriminant)) * 0.5
	if largest_eigenvalue <= max_allowed_eigenvalue or largest_eigenvalue <= 0.000001:
		return PackedFloat32Array([a, b, d])
	var scale := max_allowed_eigenvalue / largest_eigenvalue
	return PackedFloat32Array([a * scale, b * scale, d * scale])


func _update_surface_preview(surface: Dictionary) -> void:
	if surface.is_empty() or not skill_active:
		_hide_surface_preview()
		return
	var position: Vector3 = surface.get("position", Vector3.ZERO)
	var normal: Vector3 = surface.get("normal", Vector3.UP)
	if normal.length_squared() <= 0.001:
		_hide_surface_preview()
		return
	_ensure_surface_preview()
	if not _surface_preview:
		return
	var clean_normal := normal.normalized()
	var preview_position := position + clean_normal * SURFACE_PREVIEW_OFFSET
	var radius := _brush_screen_radius_to_world(position, _current_brush_radius())
	var basis := _basis_from_surface_normal(clean_normal).scaled(Vector3(radius, radius, radius))
	_surface_preview.global_transform = Transform3D(basis, preview_position)
	_surface_preview.visible = true
	if _surface_preview_material:
		var color := brush_color if has_sampled_color else Color(0.78, 0.88, 1.0, 1.0)
		_surface_preview_material.albedo_color = Color(color.r, color.g, color.b, 0.82)


func _hide_surface_preview() -> void:
	if _surface_preview and is_instance_valid(_surface_preview):
		_surface_preview.visible = false


func _ensure_surface_preview() -> void:
	if _surface_preview and is_instance_valid(_surface_preview):
		return
	if not camouflage_owner:
		return
	var preview := MeshInstance3D.new()
	preview.name = "CamouflageSurfacePreview"
	preview.top_level = true
	preview.mesh = _create_surface_preview_mesh()
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.albedo_color = Color(0.42, 0.95, 0.72, 0.82)
	preview.material_override = material
	camouflage_owner.add_child(preview)
	_surface_preview = preview
	_surface_preview_material = material


func _brush_screen_radius_to_world(world_position: Vector3, screen_radius: float) -> float:
	if not camera:
		return maxf(0.025, screen_radius / float(TEXTURE_SIZE))
	var viewport := get_viewport()
	var viewport_height := float(viewport.get_visible_rect().size.y) if viewport else 720.0
	viewport_height = maxf(viewport_height, 1.0)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return maxf(0.01, screen_radius / viewport_height * camera.size)
	var distance := maxf(0.05, camera.global_position.distance_to(world_position))
	var visible_height := 2.0 * tan(deg_to_rad(camera.fov) * 0.5) * distance
	return clampf(screen_radius / viewport_height * visible_height, 0.01, 2.5)


static func _basis_from_surface_normal(normal: Vector3) -> Basis:
	var y_axis := normal.normalized()
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func _create_surface_preview_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(SURFACE_PREVIEW_SEGMENTS):
		var current := float(index) / float(SURFACE_PREVIEW_SEGMENTS) * TAU
		var next := float(index + 1) / float(SURFACE_PREVIEW_SEGMENTS) * TAU
		var base := vertices.size()
		vertices.append(Vector3(cos(current), 0.0, sin(current)))
		vertices.append(Vector3(cos(next), 0.0, sin(next)))
		vertices.append(Vector3(cos(next) * SURFACE_PREVIEW_RING_INNER_RADIUS, 0.0, sin(next) * SURFACE_PREVIEW_RING_INNER_RADIUS))
		vertices.append(Vector3(cos(current) * SURFACE_PREVIEW_RING_INNER_RADIUS, 0.0, sin(current) * SURFACE_PREVIEW_RING_INNER_RADIUS))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	_append_surface_preview_bar(vertices, indices, Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), SURFACE_PREVIEW_AXIS_HALF_WIDTH)
	_append_surface_preview_bar(vertices, indices, Vector3(0.0, 0.0, -0.64), Vector3(0.0, 0.0, 0.64), SURFACE_PREVIEW_AXIS_HALF_WIDTH)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _append_surface_preview_bar(vertices: PackedVector3Array, indices: PackedInt32Array, start: Vector3, end: Vector3, half_width: float) -> void:
	var direction := end - start
	if direction.length_squared() <= 0.000001:
		return
	direction = direction.normalized()
	var perpendicular := Vector3(-direction.z, 0.0, direction.x) * half_width
	var base := vertices.size()
	vertices.append(start + perpendicular)
	vertices.append(end + perpendicular)
	vertices.append(end - perpendicular)
	vertices.append(start - perpendicular)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _sample_mouse_environment_color() -> Color:
	if not camera or not camouflage_owner or not camouflage_owner.get_world_3d():
		return Color(0, 0, 0, 0)
	var viewport := get_viewport()
	if not viewport:
		return Color(0, 0, 0, 0)
	var mouse := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse).normalized() * CAMOUFLAGE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [camouflage_owner.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := camouflage_owner.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Color(0, 0, 0, 0)
	return _color_from_hit(hit)


func _sample_mouse_material_color(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> Color:
	return _sample_mouse_material_profile(mouse_position).get("color", Color(0, 0, 0, 0)) as Color


func _sample_mouse_material_profile(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> Dictionary:
	if not camera or not camouflage_owner or not camouflage_owner.get_world_3d():
		return {}
	var viewport := get_viewport()
	if not viewport:
		return {}
	var mouse := mouse_position
	if mouse.x < 0.0 or mouse.y < 0.0:
		mouse = viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse).normalized()
	var to := from + direction * CAMOUFLAGE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [camouflage_owner.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := camouflage_owner.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var mesh := _find_visual_mesh(hit.get("collider"))
	if mesh and mesh.mesh:
		var mesh_hit := _intersect_mesh_triangles(mesh, "", from, direction)
		if not mesh_hit.is_empty():
			var surface := int(mesh_hit.get("surface", 0))
			var uv: Vector2 = mesh_hit.get("uv", Vector2.ZERO)
			var profile := _material_profile_from_material(_get_mesh_surface_material(mesh, surface), uv)
			if (profile.get("color", Color(0, 0, 0, 0)) as Color).a > 0.0:
				return profile
		var fallback := _material_profile_from_material(_get_mesh_material(mesh), Vector2(0.5, 0.5))
		if (fallback.get("color", Color(0, 0, 0, 0)) as Color).a > 0.0:
			return fallback
	var hit_color := _color_from_hit(hit)
	if hit_color.a <= 0.0:
		return {}
	return {
		"color": hit_color,
		"roughness": paint_roughness,
		"metallic": paint_metallic,
		"has_response": false,
	}


func _sample_mouse_viewport_color(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> Color:
	var viewport := get_viewport()
	if not viewport:
		return Color(0, 0, 0, 0)
	var texture := viewport.get_texture()
	if not texture:
		return Color(0, 0, 0, 0)
	var image := texture.get_image()
	if not image:
		return Color(0, 0, 0, 0)
	var image_size := Vector2(image.get_width(), image.get_height())
	var visible_size := Vector2(viewport.get_visible_rect().size)
	if image_size.x <= 0.0 or image_size.y <= 0.0 or visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return Color(0, 0, 0, 0)
	var mouse := mouse_position
	if mouse.x < 0.0 or mouse.y < 0.0:
		mouse = viewport.get_mouse_position()
	var pixel := Vector2i(
		clampi(roundi(mouse.x / visible_size.x * image_size.x), 0, int(image_size.x) - 1),
		clampi(roundi(mouse.y / visible_size.y * image_size.y), 0, int(image_size.y) - 1)
	)
	var color := image.get_pixelv(pixel)
	color.a = 1.0
	return color


func _color_from_hit(hit: Dictionary) -> Color:
	var collider = hit.get("collider")
	var mesh := _find_visual_mesh(collider)
	if mesh:
		var material := _get_mesh_material(mesh)
		var material_color := _color_from_material(material)
		if material_color.a > 0.0:
			return material_color

	var position: Vector3 = hit.get("position", camouflage_owner.global_position)
	return _sample_color_from_position(position)


func _blend_material_and_screen_color(material_color: Color, screen_color: Color) -> Color:
	material_color.a = 1.0
	if screen_color.a <= 0.0:
		return material_color
	screen_color.a = 1.0
	if COLOR_MATERIAL_CALIBRATION_WEIGHT <= 0.0:
		return screen_color
	if _rgb_color_distance(material_color, screen_color) > COLOR_MATERIAL_SCREEN_MATCH_THRESHOLD:
		return screen_color
	var calibrated := screen_color.lerp(material_color, COLOR_MATERIAL_CALIBRATION_WEIGHT)
	calibrated.a = 1.0
	return calibrated


static func _rgb_color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _find_visual_mesh(collider) -> MeshInstance3D:
	if collider is MeshInstance3D:
		return collider as MeshInstance3D
	if collider is Node:
		var node := collider as Node
		var child_mesh := _find_first_mesh(node)
		if child_mesh:
			return child_mesh
		var parent := node.get_parent()
		while parent:
			if parent is MeshInstance3D:
				return parent as MeshInstance3D
			child_mesh = _find_first_mesh(parent)
			if child_mesh:
				return child_mesh
			parent = parent.get_parent()
	return null


func _find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var nested := _find_first_mesh(child)
		if nested:
			return nested
	return null


func _get_mesh_material(mesh: MeshInstance3D) -> Material:
	var material := mesh.get_surface_override_material(0)
	if not material:
		material = mesh.material_override
	if not material:
		material = mesh.get_active_material(0)
	return material


func _get_mesh_surface_material(mesh: MeshInstance3D, surface: int) -> Material:
	if not mesh:
		return null
	var material := mesh.get_surface_override_material(surface)
	if not material:
		material = mesh.material_override
	if not material and mesh.mesh and surface < mesh.mesh.get_surface_count():
		material = mesh.mesh.surface_get_material(surface)
	if not material:
		material = mesh.get_active_material(0)
	return material


func _color_from_material(material: Material) -> Color:
	if not material:
		return Color(0, 0, 0, 0)
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		var color := standard.albedo_color
		if standard.albedo_texture:
			var texture_color := _sample_texture_color(standard.albedo_texture, Vector2(0.5, 0.5))
			if texture_color.a <= 0.0:
				texture_color = _average_texture_color(standard.albedo_texture)
			if texture_color.a > 0.0:
				color = color.lerp(texture_color, 0.72)
		color.a = 1.0
		return color
	if material is ShaderMaterial:
		return _color_from_shader_material_at_uv(material as ShaderMaterial, Vector2(0.5, 0.5))
	return Color(0, 0, 0, 0)


func _color_from_material_at_uv(material: Material, uv: Vector2) -> Color:
	if not material:
		return Color(0, 0, 0, 0)
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		var color := standard.albedo_color
		if standard.albedo_texture:
			var texture_color := _sample_texture_color(standard.albedo_texture, uv)
			if texture_color.a > 0.0:
				color = color * texture_color
		color.a = 1.0
		return color
	if material is ShaderMaterial:
		return _color_from_shader_material_at_uv(material as ShaderMaterial, uv)
	return _color_from_material(material)


func _material_profile_from_material(material: Material, uv: Vector2) -> Dictionary:
	var color := _color_from_material_at_uv(material, uv)
	var profile := {
		"color": color,
		"roughness": paint_roughness,
		"metallic": paint_metallic,
		"specular": paint_specular,
		"has_response": false,
	}
	if not material:
		return profile

	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		var roughness := _variant_to_unit_float(standard.get("roughness"), PAINT_ROUGHNESS_DEFAULT)
		var metallic := _variant_to_unit_float(standard.get("metallic"), PAINT_METALLIC_DEFAULT)
		var specular := _variant_to_unit_float(standard.get("metallic_specular"), PAINT_SPECULAR_DEFAULT)
		var roughness_texture := standard.get("roughness_texture") as Texture2D
		if roughness_texture:
			roughness *= _sample_texture_scalar(roughness_texture, uv, 1.0)
		var metallic_texture := standard.get("metallic_texture") as Texture2D
		if metallic_texture:
			metallic *= _sample_texture_scalar(metallic_texture, uv, 1.0)
		var orm_texture := standard.get("orm_texture") as Texture2D
		if orm_texture:
			var orm_color := _sample_texture_color(orm_texture, uv)
			if orm_color.a > 0.0:
				roughness *= clampf(orm_color.g, 0.0, 1.0)
				metallic *= clampf(orm_color.b, 0.0, 1.0)
		profile["roughness"] = clampf(roughness, 0.0, 1.0)
		profile["metallic"] = clampf(metallic, 0.0, 1.0)
		profile["specular"] = clampf(specular, 0.0, 1.0)
		profile["normal_texture"] = standard.get("normal_texture") as Texture2D
		profile["normal_scale"] = _variant_to_unit_float(standard.get("normal_scale"), 1.0)
		profile["has_response"] = true
		return profile

	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var roughness := _shader_unit_parameter(
			shader_material,
			["roughness", "material_roughness", "surface_roughness", "paint_roughness"],
			PAINT_ROUGHNESS_DEFAULT
		)
		var metallic := _shader_unit_parameter(
			shader_material,
			["metallic", "metalness", "material_metallic", "surface_metallic", "paint_metallic"],
			PAINT_METALLIC_DEFAULT
		)
		var specular := _shader_unit_parameter(
			shader_material,
			["specular", "material_specular", "surface_specular", "paint_specular"],
			PAINT_SPECULAR_DEFAULT
		)
		var roughness_texture := _shader_texture_parameter(shader_material, ["roughness_texture", "texture_roughness", "roughness_map"])
		if roughness_texture:
			roughness *= _sample_texture_scalar(roughness_texture, uv, 1.0)
		var metallic_texture := _shader_texture_parameter(shader_material, ["metallic_texture", "metalness_texture", "texture_metallic", "metallic_map"])
		if metallic_texture:
			metallic *= _sample_texture_scalar(metallic_texture, uv, 1.0)
		var orm_texture := _shader_texture_parameter(shader_material, ["orm_texture", "texture_orm", "orm_map"])
		if orm_texture:
			var orm_color := _sample_texture_color(orm_texture, uv)
			if orm_color.a > 0.0:
				roughness *= clampf(orm_color.g, 0.0, 1.0)
				metallic *= clampf(orm_color.b, 0.0, 1.0)
		profile["roughness"] = clampf(roughness, 0.0, 1.0)
		profile["metallic"] = clampf(metallic, 0.0, 1.0)
		profile["specular"] = clampf(specular, 0.0, 1.0)
		profile["normal_texture"] = _shader_texture_parameter(shader_material, ["normal_texture", "texture_normal", "normal_map"])
		profile["normal_scale"] = _shader_unit_parameter(shader_material, ["normal_scale", "normal_map_scale", "paint_normal_scale"], 1.0)
		profile["has_response"] = true
	return profile


func _shader_unit_parameter(material: ShaderMaterial, names: Array[String], fallback: float) -> float:
	for parameter_name in names:
		var value = material.get_shader_parameter(parameter_name)
		var parsed := _variant_to_unit_float(value, -1.0)
		if parsed >= 0.0:
			return parsed
	return clampf(fallback, 0.0, 1.0)


func _shader_texture_parameter(material: ShaderMaterial, names: Array[String]) -> Texture2D:
	for parameter_name in names:
		var value = material.get_shader_parameter(parameter_name)
		if value is Texture2D:
			return value as Texture2D
	return null


func _variant_to_unit_float(value, fallback: float) -> float:
	if value == null:
		return fallback
	if value is int or value is float:
		return clampf(float(value), 0.0, 1.0)
	if value is Color:
		var color := value as Color
		return clampf(color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722, 0.0, 1.0)
	return fallback


func _sample_texture_scalar(texture: Texture2D, uv: Vector2, fallback: float) -> float:
	var color := _sample_texture_color(texture, uv)
	if color.a <= 0.0:
		return fallback
	return clampf(color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722, 0.0, 1.0)


func _color_from_shader_material_at_uv(material: ShaderMaterial, uv: Vector2) -> Color:
	var tint := Color.WHITE
	for color_name in ["albedo", "albedo_color", "base_color", "color", "tint", "modulate"]:
		var color_value = material.get_shader_parameter(color_name)
		if color_value is Color:
			tint = color_value as Color
			break
	for texture_name in ["albedo_texture", "texture_albedo", "base_texture", "color_texture", "diffuse_texture", "main_texture", "tex", "texture"]:
		var texture_value = material.get_shader_parameter(texture_name)
		if texture_value is Texture2D:
			var texture_color := _sample_texture_color(texture_value as Texture2D, uv)
			if texture_color.a > 0.0:
				var color := tint * texture_color
				color.a = 1.0
				return color
	tint.a = 1.0
	return tint if tint != Color.WHITE else Color(0, 0, 0, 0)


func _sample_texture_color(texture: Texture2D, uv: Vector2) -> Color:
	var image := _get_readable_image(texture)
	if not image:
		return Color(0, 0, 0, 0)
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return Color(0, 0, 0, 0)
	var wrapped_uv := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0))
	var pixel := Vector2i(
		clampi(roundi(wrapped_uv.x * float(width - 1)), 0, width - 1),
		clampi(roundi(wrapped_uv.y * float(height - 1)), 0, height - 1)
	)
	var color := image.get_pixelv(pixel)
	color.a = 1.0
	return color


func _average_texture_color(texture: Texture2D) -> Color:
	var image := _get_readable_image(texture)
	if not image:
		return Color(0, 0, 0, 0)
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return Color(0, 0, 0, 0)
	var step_x: int = max(1, int(width / 8.0))
	var step_y: int = max(1, int(height / 8.0))
	var total := Color.BLACK
	var count := 0
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var pixel := image.get_pixel(x, y)
			total.r += pixel.r
			total.g += pixel.g
			total.b += pixel.b
			count += 1
	if count <= 0:
		return Color(0, 0, 0, 0)
	total.r /= float(count)
	total.g /= float(count)
	total.b /= float(count)
	total.a = 1.0
	return total


func _sample_color_from_position(position: Vector3) -> Color:
	if position.y < 0.2:
		return Color(0.46, 0.55, 0.39, 1.0)
	if position.z > 18.0:
		return Color(0.68, 0.52, 0.34, 1.0)
	if position.z < -18.0:
		return Color(0.40, 0.48, 0.64, 1.0)
	if position.x > 18.0:
		return Color(0.64, 0.58, 0.40, 1.0)
	if position.x < -18.0:
		return Color(0.48, 0.42, 0.56, 1.0)
	return Color(0.44, 0.62, 0.44, 1.0)


static func create_camouflage_texture(palette: Array, seed: int = 0) -> Texture2D:
	var clean_palette := _sanitize_palette(palette)
	var drawable := _create_drawable_canvas(clean_palette[0], true)
	if drawable:
		_draw_palette_patches(drawable, clean_palette, seed)
		drawable.call("generate_mipmaps")
		return drawable as Texture2D
	return ImageTexture.create_from_image(_build_palette_image(clean_palette, seed))


static func create_brush_canvas(base_color: Color) -> Texture2D:
	var clean := base_color
	clean.a = 1.0
	var drawable := _create_drawable_canvas(clean, false)
	if drawable:
		return drawable as Texture2D
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(clean)
	return ImageTexture.create_from_image(image)


static func create_paint_layer_canvas() -> Texture2D:
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	var drawable := _create_drawable_canvas(transparent, false)
	if drawable:
		return drawable as Texture2D
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(transparent)
	return ImageTexture.create_from_image(image)


static func create_brush_canvas_from_source(base_color: Color, source_texture: Texture2D = null) -> Texture2D:
	var clean := base_color
	clean.a = 1.0
	var drawable := _create_drawable_canvas(clean, false)
	if drawable:
		if source_texture:
			drawable.call(
				"blit_rect",
				Rect2i(Vector2i.ZERO, Vector2i(TEXTURE_SIZE, TEXTURE_SIZE)),
				source_texture,
				Color.WHITE,
				0,
				null
			)
		return drawable as Texture2D

	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(clean)
	if source_texture:
		var source_image := _get_readable_image(source_texture)
		if source_image:
			source_image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			image.blit_rect(source_image, Rect2i(Vector2i.ZERO, source_image.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(image)


static func paint_brush_on_texture(texture: Texture2D, uv: Vector2, color: Color, brush_radius: float, angle: float) -> Texture2D:
	var uvs := PackedVector2Array()
	uvs.append(uv)
	return paint_brush_strokes_on_texture(texture, uvs, color, brush_radius, angle)


static func paint_brush_strokes_on_texture(
	texture: Texture2D,
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array()
) -> Texture2D:
	if uvs.is_empty():
		return texture
	var fallback_radius: int = clampi(int(round(brush_radius)), int(BRUSH_MIN_RADIUS), int(BRUSH_MAX_RADIUS))
	var use_variable_radii := brush_radii.size() == uvs.size()
	var uv_clip_offsets := _uv_clip_offsets_for_counts(uv_clip_triangle_counts, uv_clip_triangles.size(), uvs.size())
	var use_uv_clip_triangles := uv_clip_offsets.size() == uvs.size()
	var use_uv_footprint_metrics := uv_footprint_metrics.size() == uvs.size() * 3
	var patch_cache := {}
	var patch_image_cache := {}
	if texture and texture.is_class("DrawableTexture2D"):
		for index in range(uvs.size()):
			var uv := uvs[index]
			var radius := _brush_radius_for_stroke(index, fallback_radius, brush_radii, use_variable_radii)
			var target := _brush_pixel_target_for_uv(uv)
			radius = _brush_radius_clamped_to_texture_bounds(radius, target)
			var patch_size := radius * 2 + 1
			var patch := _brush_patch_from_cache(patch_cache, radius, color, angle, target.get("offset", Vector2.ZERO))
			var placement := _brush_patch_placement(target.get("base_pixel", Vector2i.ZERO), radius, patch_size)
			if placement.is_empty():
				continue
			var dest_rect: Rect2i = placement.get("dest", Rect2i())
			var src_rect: Rect2i = placement.get("src", Rect2i())
			var source_patch := patch
			var clip_range := _uv_clip_triangle_range_for_stroke(index, radius, uv_clip_triangle_counts, uv_clip_offsets, use_uv_clip_triangles)
			var footprint_metric := _uv_footprint_metric_for_stroke(index, uv_footprint_metrics, use_uv_footprint_metrics)
			if not clip_range.is_empty() or not footprint_metric.is_empty():
				var patch_image := _brush_patch_image_from_cache(patch_image_cache, patch, radius, color, angle, target.get("offset", Vector2.ZERO))
				if patch_image:
					var payload := _make_masked_patch_payload(patch_image, dest_rect, src_rect, uv_clip_triangles, int(clip_range.get("offset", 0)), int(clip_range.get("count", 0)), uv, footprint_metric)
					if payload.is_empty():
						continue
					var masked_image := payload.get("image") as Image
					if not masked_image:
						continue
					source_patch = ImageTexture.create_from_image(masked_image)
					dest_rect = payload.get("dest", dest_rect)
				else:
					source_patch = _make_masked_patch(patch, dest_rect, src_rect, uv_clip_triangles, int(clip_range.get("offset", 0)), int(clip_range.get("count", 0)), uv, footprint_metric)
			elif src_rect.position != Vector2i.ZERO or src_rect.size != Vector2i(patch_size, patch_size):
				source_patch = _crop_texture_patch(patch, src_rect)
			texture.call("blit_rect", dest_rect, source_patch, Color.WHITE, 0, null)
		if bool(texture.call("get_use_mipmaps")):
			texture.call("generate_mipmaps")
		return texture

	var image := texture.get_image() if texture else Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	if not image:
		image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(color.darkened(0.22))
	for index in range(uvs.size()):
		var uv := uvs[index]
		var radius := _brush_radius_for_stroke(index, fallback_radius, brush_radii, use_variable_radii)
		var target := _brush_pixel_target_for_uv(uv)
		radius = _brush_radius_clamped_to_texture_bounds(radius, target)
		var patch_size := radius * 2 + 1
		var patch := _brush_patch_from_cache(patch_cache, radius, color, angle, target.get("offset", Vector2.ZERO))
		var patch_image := _brush_patch_image_from_cache(patch_image_cache, patch, radius, color, angle, target.get("offset", Vector2.ZERO))
		if not patch_image:
			continue
		var placement := _brush_patch_placement(target.get("base_pixel", Vector2i.ZERO), radius, patch_size)
		if placement.is_empty():
			continue
		var dest_rect: Rect2i = placement.get("dest", Rect2i())
		var src_rect: Rect2i = placement.get("src", Rect2i())
		var clip_range := _uv_clip_triangle_range_for_stroke(index, radius, uv_clip_triangle_counts, uv_clip_offsets, use_uv_clip_triangles)
		var footprint_metric := _uv_footprint_metric_for_stroke(index, uv_footprint_metrics, use_uv_footprint_metrics)
		var source_image := patch_image
		var source_rect := src_rect
		if not clip_range.is_empty() or not footprint_metric.is_empty():
			var payload := _make_masked_patch_payload(patch_image, dest_rect, src_rect, uv_clip_triangles, int(clip_range.get("offset", 0)), int(clip_range.get("count", 0)), uv, footprint_metric)
			if payload.is_empty():
				continue
			source_image = payload.get("image") as Image
			if not source_image:
				continue
			dest_rect = payload.get("dest", dest_rect)
			source_rect = Rect2i(Vector2i.ZERO, dest_rect.size)
		for py in range(dest_rect.size.y):
			for px in range(dest_rect.size.x):
				var dst := Vector2i(dest_rect.position.x + px, dest_rect.position.y + py)
				if dst.x < 0 or dst.y < 0 or dst.x >= TEXTURE_SIZE or dst.y >= TEXTURE_SIZE:
					continue
				var src := source_image.get_pixel(source_rect.position.x + px, source_rect.position.y + py)
				if src.a <= 0.001:
					continue
				var base := image.get_pixel(dst.x, dst.y)
				image.set_pixel(dst.x, dst.y, _alpha_over(src, base))
	return _update_image_texture_or_create(texture, image)


static func _uv_clip_offsets_for_counts(
	uv_clip_triangle_counts: PackedInt32Array,
	uv_clip_triangle_uv_count: int,
	stamp_count: int
) -> PackedInt32Array:
	var offsets := PackedInt32Array()
	if uv_clip_triangle_counts.size() != stamp_count:
		return offsets
	offsets.resize(stamp_count)
	var read_offset := 0
	for index in range(stamp_count):
		var count := int(uv_clip_triangle_counts[index])
		if count < 0 or count > BRUSH_UV_CLIP_MAX_TRIANGLES:
			return PackedInt32Array()
		offsets[index] = read_offset
		read_offset += count * 3
	if read_offset != uv_clip_triangle_uv_count:
		return PackedInt32Array()
	return offsets


static func _uv_clip_triangle_range_for_stroke(
	index: int,
	radius: int,
	uv_clip_triangle_counts: PackedInt32Array,
	uv_clip_offsets: PackedInt32Array,
	use_uv_clip_triangles: bool
) -> Dictionary:
	if not use_uv_clip_triangles:
		return {}
	if index < 0 or index >= uv_clip_triangle_counts.size() or index >= uv_clip_offsets.size():
		return {}
	var triangle_count := int(uv_clip_triangle_counts[index])
	if triangle_count <= 0:
		return {}
	if triangle_count >= BRUSH_UV_CLIP_MAX_TRIANGLES:
		return {}
	return {
		"offset": int(uv_clip_offsets[index]),
		"count": triangle_count,
	}


static func _make_masked_patch(
	patch: Texture2D,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	clip_triangles: PackedVector2Array,
	triangle_offset: int,
	triangle_count: int,
	center_uv: Vector2,
	footprint_metric: PackedFloat32Array
) -> Texture2D:
	var source_image := patch.get_image()
	if not source_image:
		return patch
	var clipped := _make_masked_patch_image(source_image, dest_rect, src_rect, clip_triangles, triangle_offset, triangle_count, center_uv, footprint_metric)
	return ImageTexture.create_from_image(clipped)


static func _make_masked_patch_image(
	source_image: Image,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	clip_triangles: PackedVector2Array,
	triangle_offset: int,
	triangle_count: int,
	center_uv: Vector2,
	footprint_metric: PackedFloat32Array
) -> Image:
	var clipped := Image.create(dest_rect.size.x, dest_rect.size.y, false, Image.FORMAT_RGBA8)
	clipped.fill(Color(0.0, 0.0, 0.0, 0.0))
	var payload := _make_masked_patch_payload(source_image, dest_rect, src_rect, clip_triangles, triangle_offset, triangle_count, center_uv, footprint_metric)
	if payload.is_empty():
		return clipped
	var payload_image := payload.get("image") as Image
	if not payload_image:
		return clipped
	var payload_dest: Rect2i = payload.get("dest", Rect2i())
	var local_dest := payload_dest.position - dest_rect.position
	clipped.blit_rect(payload_image, Rect2i(Vector2i.ZERO, payload_image.get_size()), local_dest)
	return clipped


static func _make_masked_patch_payload(
	source_image: Image,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	clip_triangles: PackedVector2Array,
	triangle_offset: int,
	triangle_count: int,
	center_uv: Vector2,
	footprint_metric: PackedFloat32Array
) -> Dictionary:
	if not source_image:
		return {}
	var has_triangles := triangle_count > 0 and triangle_offset >= 0 and triangle_offset + triangle_count * 3 <= clip_triangles.size()
	var has_footprint := _has_uv_footprint_metric(footprint_metric)
	if not has_triangles and not has_footprint:
		return {}
	var margin_pixels := int(ceil(BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS))
	var footprint_bounds := _uv_footprint_pixel_bounds(center_uv, footprint_metric, dest_rect, margin_pixels) if has_footprint else dest_rect
	var payload_rect := _masked_patch_payload_bounds(dest_rect, clip_triangles, triangle_offset, triangle_count, center_uv, has_triangles, footprint_bounds, margin_pixels)
	if payload_rect.size.x <= 0 or payload_rect.size.y <= 0:
		return {}
	var clipped := Image.create(payload_rect.size.x, payload_rect.size.y, false, Image.FORMAT_RGBA8)
	clipped.fill(Color(0.0, 0.0, 0.0, 0.0))
	if not has_triangles:
		for y in range(payload_rect.position.y, payload_rect.position.y + payload_rect.size.y):
			for x in range(payload_rect.position.x, payload_rect.position.x + payload_rect.size.x):
				var dst := Vector2i(x, y)
				if not _texture_pixel_inside_uv_footprint(dst, center_uv, footprint_metric):
					continue
				_copy_masked_patch_pixel_with_footprint_falloff(clipped, source_image, dest_rect, src_rect, dst, center_uv, footprint_metric, payload_rect)
		_copy_masked_patch_center_pixels(clipped, source_image, dest_rect, src_rect, center_uv, payload_rect)
		return {"image": clipped, "dest": payload_rect}
	for triangle in range(triangle_count):
		var offset := triangle_offset + triangle * 3
		var uv0 := clip_triangles[offset]
		var uv1 := clip_triangles[offset + 1]
		var uv2 := clip_triangles[offset + 2]
		if absf((uv1 - uv0).cross(uv2 - uv0)) < 0.0000001:
			continue
		var p0 := _uv_to_texture_pixel_float(uv0)
		var p1 := _uv_to_texture_pixel_float(uv1)
		var p2 := _uv_to_texture_pixel_float(uv2)
		var min_x := maxi(dest_rect.position.x, int(floor(minf(p0.x, minf(p1.x, p2.x)))) - margin_pixels)
		var max_x := mini(dest_rect.position.x + dest_rect.size.x - 1, int(ceil(maxf(p0.x, maxf(p1.x, p2.x)))) + margin_pixels)
		var min_y := maxi(dest_rect.position.y, int(floor(minf(p0.y, minf(p1.y, p2.y)))) - margin_pixels)
		var max_y := mini(dest_rect.position.y + dest_rect.size.y - 1, int(ceil(maxf(p0.y, maxf(p1.y, p2.y)))) + margin_pixels)
		if has_footprint:
			min_x = maxi(min_x, footprint_bounds.position.x)
			max_x = mini(max_x, footprint_bounds.position.x + footprint_bounds.size.x - 1)
			min_y = maxi(min_y, footprint_bounds.position.y)
			max_y = mini(max_y, footprint_bounds.position.y + footprint_bounds.size.y - 1)
		min_x = maxi(min_x, payload_rect.position.x)
		max_x = mini(max_x, payload_rect.position.x + payload_rect.size.x - 1)
		min_y = maxi(min_y, payload_rect.position.y)
		max_y = mini(max_y, payload_rect.position.y + payload_rect.size.y - 1)
		if min_x > max_x or min_y > max_y:
			continue
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var dst := Vector2i(x, y)
				if not _texture_pixel_inside_uv_triangle(dst, uv0, uv1, uv2):
					continue
				if has_footprint and not _texture_pixel_inside_uv_footprint(dst, center_uv, footprint_metric):
					continue
				_copy_masked_patch_pixel_with_footprint_falloff(clipped, source_image, dest_rect, src_rect, dst, center_uv, footprint_metric, payload_rect)
	_copy_masked_patch_center_pixels(clipped, source_image, dest_rect, src_rect, center_uv, payload_rect)
	return {"image": clipped, "dest": payload_rect}


static func _masked_patch_payload_bounds(
	dest_rect: Rect2i,
	clip_triangles: PackedVector2Array,
	triangle_offset: int,
	triangle_count: int,
	center_uv: Vector2,
	has_triangles: bool,
	footprint_bounds: Rect2i,
	margin_pixels: int
) -> Rect2i:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	if not has_triangles:
		bounds = _intersect_texture_rects(dest_rect, footprint_bounds)
	else:
		for triangle in range(triangle_count):
			var offset := triangle_offset + triangle * 3
			if offset < 0 or offset + 2 >= clip_triangles.size():
				continue
			var uv0 := clip_triangles[offset]
			var uv1 := clip_triangles[offset + 1]
			var uv2 := clip_triangles[offset + 2]
			if absf((uv1 - uv0).cross(uv2 - uv0)) < 0.0000001:
				continue
			var p0 := _uv_to_texture_pixel_float(uv0)
			var p1 := _uv_to_texture_pixel_float(uv1)
			var p2 := _uv_to_texture_pixel_float(uv2)
			var min_x := maxi(dest_rect.position.x, int(floor(minf(p0.x, minf(p1.x, p2.x)))) - margin_pixels)
			var max_x := mini(dest_rect.position.x + dest_rect.size.x - 1, int(ceil(maxf(p0.x, maxf(p1.x, p2.x)))) + margin_pixels)
			var min_y := maxi(dest_rect.position.y, int(floor(minf(p0.y, minf(p1.y, p2.y)))) - margin_pixels)
			var max_y := mini(dest_rect.position.y + dest_rect.size.y - 1, int(ceil(maxf(p0.y, maxf(p1.y, p2.y)))) + margin_pixels)
			if footprint_bounds.size.x > 0 and footprint_bounds.size.y > 0:
				min_x = maxi(min_x, footprint_bounds.position.x)
				max_x = mini(max_x, footprint_bounds.position.x + footprint_bounds.size.x - 1)
				min_y = maxi(min_y, footprint_bounds.position.y)
				max_y = mini(max_y, footprint_bounds.position.y + footprint_bounds.size.y - 1)
			if min_x > max_x or min_y > max_y:
				continue
			var triangle_rect := Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
			bounds = _union_texture_rects(bounds, triangle_rect)
	var center_rect := _center_pixel_payload_bounds(center_uv, dest_rect)
	bounds = _union_texture_rects(bounds, center_rect)
	return _intersect_texture_rects(dest_rect, bounds)


static func _center_pixel_payload_bounds(center_uv: Vector2, dest_rect: Rect2i) -> Rect2i:
	var center_pixel := _brush_uv_to_pixel_center(center_uv)
	var center_rect := Rect2i(center_pixel - Vector2i(1, 1), Vector2i(3, 3))
	return _intersect_texture_rects(dest_rect, center_rect)


static func _copy_masked_patch_center_pixels(
	target_image: Image,
	source_image: Image,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	center_uv: Vector2,
	target_rect: Rect2i = Rect2i()
) -> void:
	var write_rect := _target_write_rect(target_rect, dest_rect)
	var center_pixel := _brush_uv_to_pixel_center(center_uv)
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var dst := center_pixel + Vector2i(ox, oy)
			if dst.x < dest_rect.position.x or dst.y < dest_rect.position.y:
				continue
			if dst.x >= dest_rect.position.x + dest_rect.size.x or dst.y >= dest_rect.position.y + dest_rect.size.y:
				continue
			if dst.x < write_rect.position.x or dst.y < write_rect.position.y:
				continue
			if dst.x >= write_rect.position.x + write_rect.size.x or dst.y >= write_rect.position.y + write_rect.size.y:
				continue
			_copy_masked_patch_pixel(target_image, source_image, dest_rect, src_rect, dst, write_rect)


static func _copy_masked_patch_pixel(
	target_image: Image,
	source_image: Image,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	dst: Vector2i,
	target_rect: Rect2i = Rect2i()
) -> void:
	var write_rect := _target_write_rect(target_rect, dest_rect)
	var source_local := dst - dest_rect.position
	var target_local := dst - write_rect.position
	var source := src_rect.position + source_local
	if source.x < 0 or source.y < 0 or source.x >= source_image.get_width() or source.y >= source_image.get_height():
		return
	if target_local.x < 0 or target_local.y < 0 or target_local.x >= target_image.get_width() or target_local.y >= target_image.get_height():
		return
	target_image.set_pixel(target_local.x, target_local.y, source_image.get_pixel(source.x, source.y))


static func _copy_masked_patch_pixel_with_footprint_falloff(
	target_image: Image,
	source_image: Image,
	dest_rect: Rect2i,
	src_rect: Rect2i,
	dst: Vector2i,
	center_uv: Vector2,
	footprint_metric: PackedFloat32Array,
	target_rect: Rect2i = Rect2i()
) -> void:
	var write_rect := _target_write_rect(target_rect, dest_rect)
	var source_local := dst - dest_rect.position
	var target_local := dst - write_rect.position
	var source := src_rect.position + source_local
	if source.x < 0 or source.y < 0 or source.x >= source_image.get_width() or source.y >= source_image.get_height():
		return
	if target_local.x < 0 or target_local.y < 0 or target_local.x >= target_image.get_width() or target_local.y >= target_image.get_height():
		return
	var pixel := source_image.get_pixel(source.x, source.y)
	if _has_uv_footprint_metric(footprint_metric):
		var value := _uv_footprint_value_for_pixel(dst, center_uv, footprint_metric)
		if value > 1.0:
			var feather := maxf(_uv_footprint_margin_value(footprint_metric), 0.0001)
			pixel.a *= clampf(1.0 - (value - 1.0) / feather, 0.0, 1.0)
	if pixel.a <= 0.001:
		return
	target_image.set_pixel(target_local.x, target_local.y, pixel)


static func _target_write_rect(target_rect: Rect2i, fallback_rect: Rect2i) -> Rect2i:
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		return fallback_rect
	return target_rect


static func _uv_to_texture_pixel_float(uv: Vector2) -> Vector2:
	return Vector2(
		clampf(clampf(uv.x, 0.0, 1.0) * float(TEXTURE_SIZE) - 0.5, 0.0, float(TEXTURE_SIZE - 1)),
		clampf(clampf(uv.y, 0.0, 1.0) * float(TEXTURE_SIZE) - 0.5, 0.0, float(TEXTURE_SIZE - 1))
	)


static func _texture_pixel_inside_uv_triangle(pixel: Vector2i, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> bool:
	var uv := _texture_pixel_to_uv(pixel)
	var margin := BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS / float(TEXTURE_SIZE)
	return _uv_point_inside_triangle_or_margin(uv, uv0, uv1, uv2, margin)


static func _texture_pixel_inside_uv_footprint(pixel: Vector2i, center_uv: Vector2, footprint_metric: PackedFloat32Array) -> bool:
	if not _has_uv_footprint_metric(footprint_metric):
		return true
	return _uv_footprint_value_for_pixel(pixel, center_uv, footprint_metric) <= 1.0 + _uv_footprint_margin_value(footprint_metric)


static func _texture_pixel_to_uv(pixel: Vector2i) -> Vector2:
	return Vector2(
		clampf((float(pixel.x) + 0.5) / float(TEXTURE_SIZE), 0.0, 1.0),
		clampf((float(pixel.y) + 0.5) / float(TEXTURE_SIZE), 0.0, 1.0)
	)


static func _uv_footprint_value_for_pixel(pixel: Vector2i, center_uv: Vector2, footprint_metric: PackedFloat32Array) -> float:
	if not _has_uv_footprint_metric(footprint_metric):
		return 0.0
	var delta := _texture_pixel_to_uv(pixel) - center_uv
	return delta.x * delta.x * footprint_metric[0] + 2.0 * delta.x * delta.y * footprint_metric[1] + delta.y * delta.y * footprint_metric[2]


static func _uv_footprint_margin_value(footprint_metric: PackedFloat32Array) -> float:
	if not _has_uv_footprint_metric(footprint_metric):
		return 0.0
	var largest_eigenvalue := _largest_symmetric_2x2_eigenvalue(footprint_metric[0], footprint_metric[1], footprint_metric[2])
	if largest_eigenvalue <= 0.000001:
		return 0.0
	var uv_margin := BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS / float(TEXTURE_SIZE)
	var normalized_margin := uv_margin * sqrt(largest_eigenvalue)
	return (1.0 + normalized_margin) * (1.0 + normalized_margin) - 1.0


static func _uv_footprint_pixel_bounds(center_uv: Vector2, footprint_metric: PackedFloat32Array, dest_rect: Rect2i, margin_pixels: int) -> Rect2i:
	if not _has_uv_footprint_metric(footprint_metric):
		return dest_rect
	var a := maxf(0.0, footprint_metric[0])
	var b := footprint_metric[1]
	var d := maxf(0.0, footprint_metric[2])
	var det := a * d - b * b
	if det <= 0.000001:
		return dest_rect
	var radius_u_pixels := sqrt(maxf(d / det, 0.0)) * float(TEXTURE_SIZE)
	var radius_v_pixels := sqrt(maxf(a / det, 0.0)) * float(TEXTURE_SIZE)
	var center := _uv_to_texture_pixel_float(center_uv)
	var margin := float(maxi(margin_pixels, 0) + 1)
	var bounds := Rect2i(
		Vector2i(
			floori(center.x - radius_u_pixels - margin),
			floori(center.y - radius_v_pixels - margin)
		),
		Vector2i(
			ceili(radius_u_pixels * 2.0 + margin * 2.0) + 1,
			ceili(radius_v_pixels * 2.0 + margin * 2.0) + 1
		)
	)
	return _intersect_texture_rects(dest_rect, bounds)


static func _union_texture_rects(a: Rect2i, b: Rect2i) -> Rect2i:
	if a.size.x <= 0 or a.size.y <= 0:
		return b
	if b.size.x <= 0 or b.size.y <= 0:
		return a
	var min_x := mini(a.position.x, b.position.x)
	var min_y := mini(a.position.y, b.position.y)
	var max_x := maxi(a.position.x + a.size.x, b.position.x + b.size.x)
	var max_y := maxi(a.position.y + a.size.y, b.position.y + b.size.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x, max_y - min_y))


static func _intersect_texture_rects(a: Rect2i, b: Rect2i) -> Rect2i:
	var min_x := maxi(a.position.x, b.position.x)
	var min_y := maxi(a.position.y, b.position.y)
	var max_x := mini(a.position.x + a.size.x, b.position.x + b.size.x)
	var max_y := mini(a.position.y + a.size.y, b.position.y + b.size.y)
	if max_x <= min_x or max_y <= min_y:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x, max_y - min_y))


static func _has_uv_footprint_metric(footprint_metric: PackedFloat32Array) -> bool:
	return footprint_metric.size() == 3 and (absf(footprint_metric[0]) > 0.000001 or absf(footprint_metric[1]) > 0.000001 or absf(footprint_metric[2]) > 0.000001)


static func _largest_symmetric_2x2_eigenvalue(a: float, b: float, d: float) -> float:
	var trace := a + d
	var discriminant := maxf(0.0, (a - d) * (a - d) + 4.0 * b * b)
	return (trace + sqrt(discriminant)) * 0.5


static func _uv_point_inside_triangle_or_margin(
	point: Vector2,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2,
	margin: float
) -> bool:
	var edge0 := uv1 - uv0
	var edge1 := uv2 - uv0
	var point_edge := point - uv0
	var d00 := edge0.dot(edge0)
	var d01 := edge0.dot(edge1)
	var d11 := edge1.dot(edge1)
	var d20 := point_edge.dot(edge0)
	var d21 := point_edge.dot(edge1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 0.0000001:
		return false
	var bary_y := (d11 * d20 - d01 * d21) / denom
	var bary_z := (d00 * d21 - d01 * d20) / denom
	var bary_x := 1.0 - bary_y - bary_z
	if bary_x >= -0.00001 and bary_y >= -0.00001 and bary_z >= -0.00001:
		return true
	return (
		_distance_to_segment_2d(point, uv0, uv1) <= margin
		or _distance_to_segment_2d(point, uv1, uv2) <= margin
		or _distance_to_segment_2d(point, uv2, uv0) <= margin
	)


static func _distance_to_segment_2d(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(_closest_point_on_segment_2d(point, start, end))


static func _closest_point_on_segment_2d(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0000001:
		return start
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * t


static func _brush_patch_placement(center: Vector2i, radius: int, patch_size: int) -> Dictionary:
	var raw_x: int = center.x - radius
	var raw_y: int = center.y - radius
	var dest_x: int = maxi(raw_x, 0)
	var dest_y: int = maxi(raw_y, 0)
	var src_x: int = dest_x - raw_x
	var src_y: int = dest_y - raw_y
	var width: int = mini(patch_size - src_x, TEXTURE_SIZE - dest_x)
	var height: int = mini(patch_size - src_y, TEXTURE_SIZE - dest_y)
	if width <= 0 or height <= 0:
		return {}
	return {
		"dest": Rect2i(Vector2i(dest_x, dest_y), Vector2i(width, height)),
		"src": Rect2i(Vector2i(src_x, src_y), Vector2i(width, height)),
	}


static func _brush_radius_for_stroke(
	index: int,
	fallback_radius: int,
	brush_radii: PackedFloat32Array,
	use_variable_radii: bool
) -> int:
	if not use_variable_radii or index < 0 or index >= brush_radii.size():
		return fallback_radius
	return clampi(int(round(brush_radii[index])), int(BRUSH_PRECISION_SAMPLE_MIN_RADIUS), int(BRUSH_MAX_RADIUS))


static func _brush_radius_clamped_to_texture_bounds(radius: int, target: Dictionary) -> int:
	var center: Vector2 = target.get("center", Vector2(float(TEXTURE_SIZE - 1), float(TEXTURE_SIZE - 1)) * 0.5)
	var edge_distance := floori(minf(center.x, minf(center.y, minf(float(TEXTURE_SIZE - 1) - center.x, float(TEXTURE_SIZE - 1) - center.y))))
	if edge_distance <= 0:
		return 1
	return clampi(radius, 1, edge_distance)


static func _uv_footprint_metric_for_stroke(
	index: int,
	uv_footprint_metrics: PackedFloat32Array,
	use_uv_footprint_metrics: bool
) -> PackedFloat32Array:
	if not use_uv_footprint_metrics:
		return PackedFloat32Array()
	var offset := index * 3
	if offset < 0 or offset + 2 >= uv_footprint_metrics.size():
		return PackedFloat32Array()
	var metric := PackedFloat32Array([
		maxf(0.0, uv_footprint_metrics[offset]),
		uv_footprint_metrics[offset + 1],
		maxf(0.0, uv_footprint_metrics[offset + 2]),
	])
	if not _has_uv_footprint_metric(metric):
		return PackedFloat32Array()
	return metric


static func _brush_patch_from_cache(cache: Dictionary, radius: int, color: Color, angle: float, subpixel_offset: Vector2 = Vector2.ZERO) -> Texture2D:
	var key := _brush_patch_cache_key(radius, color, angle, subpixel_offset)
	if cache.has(key):
		return cache[key] as Texture2D
	if _shared_brush_patch_cache.has(key):
		var shared_patch := _shared_brush_patch_cache[key] as Texture2D
		if shared_patch:
			cache[key] = shared_patch
			return shared_patch
	var patch := _make_rotated_brush_texture(radius * 2 + 1, color, angle, subpixel_offset)
	cache[key] = patch
	_store_limited_cache_value(_shared_brush_patch_cache, key, patch)
	return patch


static func _brush_patch_image_from_cache(cache: Dictionary, patch: Texture2D, radius: int, color: Color, angle: float, subpixel_offset: Vector2 = Vector2.ZERO) -> Image:
	var key := _brush_patch_cache_key(radius, color, angle, subpixel_offset)
	if cache.has(key):
		return cache[key] as Image
	if _shared_brush_patch_image_cache.has(key):
		var shared_image := _shared_brush_patch_image_cache[key] as Image
		if shared_image:
			cache[key] = shared_image
			return shared_image
	var image := patch.get_image() if patch else null
	if image:
		cache[key] = image
		_store_limited_cache_value(_shared_brush_patch_image_cache, key, image)
	return image


static func _brush_patch_cache_key(radius: int, color: Color, angle: float, subpixel_offset: Vector2 = Vector2.ZERO) -> String:
	var quantized_angle := roundf(angle * 128.0) / 128.0
	var quantized_offset := _quantize_subpixel_offset(subpixel_offset)
	return "%d:%d:%.3f:%.3f:%.3f:%s" % [BRUSH_TEXTURE_VERSION, radius, quantized_angle, quantized_offset.x, quantized_offset.y, str(color)]


static func _store_limited_cache_value(cache: Dictionary, key: String, value: Variant) -> void:
	if cache.size() >= BRUSH_PATCH_CACHE_LIMIT and not cache.has(key):
		cache.clear()
	cache[key] = value


static func _update_image_texture_or_create(texture: Texture2D, image: Image) -> Texture2D:
	if texture and texture is ImageTexture and texture.has_method("update"):
		texture.call("update", image)
		return texture
	return ImageTexture.create_from_image(image)


static func _crop_texture_patch(texture: Texture2D, source_rect: Rect2i) -> Texture2D:
	var source_image := texture.get_image()
	if not source_image:
		return texture
	var cropped := Image.create(source_rect.size.x, source_rect.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(source_image, source_rect, Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


static func _alpha_over(src: Color, dst: Color) -> Color:
	var out_alpha := src.a + dst.a * (1.0 - src.a)
	if out_alpha <= 0.0001:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(
		(src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / out_alpha,
		(src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / out_alpha,
		(src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / out_alpha,
		out_alpha
	)


static func _brush_uv_to_pixel_center(uv: Vector2) -> Vector2i:
	var center := _brush_uv_to_pixel_center_float(uv)
	return Vector2i(
		clampi(roundi(center.x), 0, TEXTURE_SIZE - 1),
		clampi(roundi(center.y), 0, TEXTURE_SIZE - 1)
	)


static func _brush_uv_to_pixel_center_float(uv: Vector2) -> Vector2:
	return _uv_to_texture_pixel_float(uv)


static func _brush_pixel_target_for_uv(uv: Vector2) -> Dictionary:
	var center := _brush_uv_to_pixel_center_float(uv)
	var base_x := floori(center.x)
	var base_y := floori(center.y)
	var offset := Vector2(center.x - float(base_x), center.y - float(base_y))
	offset = _quantize_subpixel_offset(offset)
	if offset.x >= 1.0:
		base_x += 1
		offset.x = 0.0
	if offset.y >= 1.0:
		base_y += 1
		offset.y = 0.0
	base_x = clampi(base_x, 0, TEXTURE_SIZE - 1)
	base_y = clampi(base_y, 0, TEXTURE_SIZE - 1)
	return {
		"base_pixel": Vector2i(base_x, base_y),
		"offset": offset,
		"center": center,
	}


static func _quantize_subpixel_offset(offset: Vector2) -> Vector2:
	return Vector2(
		clampf(roundf(offset.x * BRUSH_SUBPIXEL_QUANTIZATION) / BRUSH_SUBPIXEL_QUANTIZATION, 0.0, 1.0),
		clampf(roundf(offset.y * BRUSH_SUBPIXEL_QUANTIZATION) / BRUSH_SUBPIXEL_QUANTIZATION, 0.0, 1.0)
	)


static func _create_drawable_canvas(base_color: Color, use_mipmaps: bool = false) -> Object:
	if not _can_use_drawable_texture():
		return null
	var drawable = ClassDB.instantiate("DrawableTexture2D")
	if not drawable:
		return null
	var format := 1
	if ClassDB.class_has_integer_constant("DrawableTexture2D", "DRAWABLE_FORMAT_RGBA8_SRGB"):
		format = ClassDB.class_get_integer_constant("DrawableTexture2D", "DRAWABLE_FORMAT_RGBA8_SRGB")
	drawable.call("setup", TEXTURE_SIZE, TEXTURE_SIZE, format, base_color, use_mipmaps)
	return drawable


static func _get_readable_image(texture: Texture2D) -> Image:
	if not texture:
		return null
	var image := texture.get_image()
	if not image:
		return null
	if image.is_compressed():
		var decompress_error := image.decompress()
		if decompress_error != OK:
			return null
	return image


static func _make_rotated_brush_texture(size: int, color: Color, angle: float, subpixel_offset: Vector2 = Vector2.ZERO) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1), float(size - 1)) * 0.5 + _quantize_subpixel_offset(subpixel_offset)
	var major := maxf(float(size) * 0.50, 1.0)
	var minor := maxf(float(size) * 0.38, 1.0)
	for y in range(size):
		for x in range(size):
			var local := (Vector2(x, y) - center).rotated(-angle)
			var ellipse := (local.x * local.x) / (major * major) + (local.y * local.y) / (minor * minor)
			var coverage := clampf(1.0 - ellipse, 0.0, 1.0)
			var falloff := pow(coverage, 0.34)
			var lane := 0.94 + sin(local.y * 0.34 + sin(local.x * 0.04) * 0.9) * 0.045
			var stroke_grain := 0.96 + absf(sin(local.x * 0.15 + local.y * 0.06)) * 0.04
			var alpha := falloff
			if ellipse < 0.58:
				alpha = maxf(alpha, 0.76)
			if ellipse < 0.30:
				alpha = maxf(alpha, 0.96)
			var pixel := color
			pixel = pixel.lightened((stroke_grain - 0.96) * 0.20).darkened(maxf(0.0, 1.0 - lane) * 0.04)
			if ellipse < 0.16:
				pixel = color
				alpha = 1.0
			pixel.a = clampf(alpha, 0.0, 0.96)
			if ellipse < 0.16:
				pixel.a = 1.0
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


static func _draw_palette_patches(drawable: Object, palette: Array, seed: int) -> void:
	for i in range(PATCH_COUNT):
		var color: Color = palette[i % palette.size()]
		var patch_size := 20 + int(absf(sin(float(i + seed) * 1.41)) * 44.0)
		var x := int(absf(sin(float(i + 3 + seed) * 12.9898)) * float(TEXTURE_SIZE - patch_size))
		var y := int(absf(sin(float(i + 7 + seed) * 78.233)) * float(TEXTURE_SIZE - patch_size))
		var patch := _make_patch_texture(patch_size, color, i + seed)
		drawable.call("blit_rect", Rect2i(Vector2i(x, y), Vector2i(patch_size, patch_size)), patch, Color.WHITE, 0, null)


static func _make_patch_texture(size: int, color: Color, seed: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := maxf(float(size) * 0.52, 1.0)
	for y in range(size):
		for x in range(size):
			var point := Vector2(x, y)
			var distance := point.distance_to(center) / radius
			var noise := absf(sin(float((x + 1) * 37 + (y + 1) * 17 + seed * 13) * 0.093))
			var alpha := clampf((1.0 - distance) * 0.58 + noise * 0.16, 0.0, 0.70)
			var pixel := color.lightened(noise * 0.08)
			pixel.a = alpha
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


static func _build_palette_image(palette: Array, seed: int) -> Image:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var n := absf(sin(float((x + seed) * 19 + y * 31) * 0.021))
			var band := int(floor(n * float(palette.size()))) % palette.size()
			var color: Color = palette[band]
			image.set_pixel(x, y, color.lightened(n * 0.08).darkened((1.0 - n) * 0.06))
	return image


static func _sanitize_palette(palette: Array) -> Array:
	var clean: Array[Color] = []
	for value in palette:
		if value is Color:
			var color := value as Color
			color.a = 1.0
			clean.append(color)
	if clean.is_empty():
		clean.append(Color(0.5, 0.58, 0.48, 1.0))
	while clean.size() < 4:
		var base: Color = clean[0]
		clean.append(base.lightened(0.12 * float(clean.size())))
	return clean.slice(0, 4)


static func _can_use_drawable_texture() -> bool:
	return ClassDB.class_exists("DrawableTexture2D") and ClassDB.can_instantiate("DrawableTexture2D")


func _fail(reason: String) -> void:
	pick_failed.emit(reason)
	if _hud:
		_hud.set_failed(reason)


func _ensure_hud() -> void:
	if _hud or DisplayServer.get_name() == "headless":
		return
	var scene := get_tree().get_current_scene() if get_tree() else null
	if not scene:
		return
	var parent: Node = scene.get_node_or_null("HUDCanvas")
	if not parent:
		var layer := CanvasLayer.new()
		layer.name = "CamouflageHUDLayer"
		scene.add_child(layer)
		parent = layer
	_hud = preload("res://scripts/camouflage_hud.gd").new()
	_hud.name = "CamouflageHUD"
	parent.add_child(_hud)
	_update_hud_material_controls()
