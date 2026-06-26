extends Control
class_name MatchStatusHUD

const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const MIN_SCALE := 0.78
const MAX_SCALE := 1.55
const ICON_GAP := 10.0
const ICON_WIDTH := 26.0
const ICON_HEIGHT := 26.0
const ALIVE_ICON_PATH := "res://addons/at-icons/node/heart.svg"
const DEAD_ICON_PATH := "res://addons/at-icons/node3d/ghost.svg"
const STOPWATCH_ICON_PATH := "res://addons/at-icons/node/stopwatch.svg"
const ALIVE_ICON_TEXTURE := preload("res://addons/at-icons/node/heart.svg")
const DEAD_ICON_TEXTURE := preload("res://addons/at-icons/node3d/ghost.svg")
const STOPWATCH_ICON_TEXTURE := preload("res://addons/at-icons/node/stopwatch.svg")

var props_total := 0
var props_alive := 0
var hunters_total := 0
var hunters_alive := 0
var remaining_seconds := 0.0
var phase_label := "MATCH"
var _title_font: Font = null
var _value_font: Font = null
var _state_icon_textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_title_font = _load_font(FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	visible = false


func set_match_state(
	next_props_alive: int,
	next_props_total: int,
	next_hunters_alive: int,
	next_hunters_total: int,
	next_remaining_seconds: float,
	next_phase_label: String
) -> void:
	props_alive = clampi(next_props_alive, 0, maxi(next_props_total, 0))
	props_total = maxi(next_props_total, 0)
	hunters_alive = clampi(next_hunters_alive, 0, maxi(next_hunters_total, 0))
	hunters_total = maxi(next_hunters_total, 0)
	remaining_seconds = maxf(next_remaining_seconds, 0.0)
	phase_label = next_phase_label
	visible = props_total > 0 or hunters_total > 0
	queue_redraw()


func clear() -> void:
	visible = false
	props_total = 0
	props_alive = 0
	hunters_total = 0
	hunters_alive = 0
	remaining_seconds = 0.0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var viewport_size := get_viewport_rect().size
	var scale := _get_hud_scale(viewport_size)
	var rect := _get_panel_rect(viewport_size)
	_draw_panel_background(rect, scale)
	_draw_team_icons(rect, scale, true)
	_draw_team_icons(rect, scale, false)
	_draw_timer(rect, scale)


func _draw_panel_background(rect: Rect2, scale: float) -> void:
	draw_rect(rect, Color(0.025, 0.035, 0.050, 0.62), true)


func _draw_team_icons(rect: Rect2, scale: float, props_side: bool) -> void:
	var total := props_total if props_side else hunters_total
	var alive := props_alive if props_side else hunters_alive
	if total <= 0:
		return
	var icon_step := (ICON_WIDTH + ICON_GAP) * scale
	var center_x := rect.position.x + rect.size.x * (0.27 if props_side else 0.73)
	var total_width := float(total) * ICON_WIDTH * scale + float(maxi(total - 1, 0)) * ICON_GAP * scale
	var start_x := center_x - total_width * 0.5
	var y := rect.position.y + 27.0 * scale
	for i in range(total):
		var is_alive := i < alive
		var pos := Vector2(start_x + float(i) * icon_step, y)
		_draw_state_icon(pos, scale, is_alive)
	var label := "PROPS" if props_side else "HUNTERS"
	var label_color := Color(0.80, 0.95, 1.0, 0.72) if props_side else Color(1.0, 0.48, 0.44, 0.72)
	_draw_centered_text(_get_title_font(), Vector2(center_x - 60.0 * scale, rect.position.y + 17.0 * scale), 120.0 * scale, label, int(12.0 * scale), label_color)


func _draw_state_icon(pos: Vector2, scale: float, alive: bool) -> void:
	var icon := _get_state_icon_texture(alive)
	if not icon:
		return
	var size := Vector2(ICON_WIDTH, ICON_HEIGHT) * scale
	var rect := Rect2(pos, size)
	draw_texture_rect(icon, Rect2(rect.position + Vector2(2.0, 2.0) * scale, rect.size), false, Color(0.0, 0.0, 0.0, 0.48))
	draw_texture_rect(icon, rect, false, Color.WHITE)


func _draw_timer(rect: Rect2, scale: float) -> void:
	var center_x := rect.position.x + rect.size.x * 0.5
	_draw_centered_text(_get_title_font(), Vector2(center_x - 76.0 * scale, rect.position.y + 17.0 * scale), 152.0 * scale, phase_label.to_upper(), int(12.0 * scale), Color(0.82, 0.92, 1.0, 0.78))
	var seconds := int(ceil(remaining_seconds))
	var time_text := "%02d:%02d" % [seconds / 60, seconds % 60]
	var icon_size := 24.0 * scale
	var icon_gap := 8.0 * scale
	var time_width := 76.0 * scale
	var group_width := icon_size + icon_gap + time_width
	var group_start_x := center_x - group_width * 0.5
	var row_center_y := rect.position.y + 55.0 * scale
	_draw_stopwatch_icon(Vector2(group_start_x + icon_size * 0.5, row_center_y), scale)
	_draw_centered_text_oblique(_get_value_font(), Vector2(group_start_x + icon_size + icon_gap, rect.position.y + 65.0 * scale), time_width, time_text, int(24.0 * scale), Color(1.0, 0.97, 0.88, 0.96), -0.16)


func _draw_stopwatch_icon(center: Vector2, scale: float) -> void:
	var icon := _get_stopwatch_texture()
	if not icon:
		return
	var size := Vector2(24.0, 24.0) * scale
	var rect := Rect2(center - size * 0.5, size)
	draw_texture_rect(icon, Rect2(rect.position + Vector2(2.0, 2.0) * scale, rect.size), false, Color(0.0, 0.0, 0.0, 0.48))
	draw_texture_rect(icon, rect, false, Color.WHITE)


func _get_panel_rect(viewport_size: Vector2) -> Rect2:
	var scale := _get_hud_scale(viewport_size)
	var icon_count := maxi(props_total + hunters_total, 8)
	var width := clampf(292.0 * scale + float(icon_count) * 22.0 * scale, 500.0 * scale, 760.0 * scale)
	var height := 78.0 * scale
	return Rect2(Vector2((viewport_size.x - width) * 0.5, 8.0 * scale), Vector2(width, height))


func _get_hud_scale(viewport_size: Vector2) -> float:
	var resolution_scale := minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	return clampf(resolution_scale, MIN_SCALE, MAX_SCALE)


func _draw_centered_text(font: Font, pos: Vector2, width: float, text: String, size: int, color: Color) -> void:
	draw_string(font, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.0, 0.0, 0.0, color.a * 0.58))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _draw_centered_text_oblique(font: Font, pos: Vector2, width: float, text: String, size: int, color: Color, skew: float) -> void:
	var pivot := pos + Vector2(width * 0.5, -float(size) * 0.45)
	var transform := Transform2D(Vector2(1.0, 0.0), Vector2(skew, 1.0), pivot)
	var local_pos := pos - pivot
	draw_set_transform_matrix(transform)
	draw_string(font, local_pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.0, 0.0, 0.0, color.a * 0.58))
	draw_string(font, local_pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_state_icon_texture(alive: bool) -> Texture2D:
	var key := "alive" if alive else "dead"
	if _state_icon_textures.has(key):
		return _state_icon_textures[key] as Texture2D
	var path := ALIVE_ICON_PATH if alive else DEAD_ICON_PATH
	var color_hex := "#ffffff" if alive else "#ff2828"
	var fallback_texture := ALIVE_ICON_TEXTURE if alive else DEAD_ICON_TEXTURE
	var texture := _load_tinted_svg_texture(path, color_hex, fallback_texture)
	if texture:
		_state_icon_textures[key] = texture
	return texture


func _get_stopwatch_texture() -> Texture2D:
	var key := "stopwatch"
	if _state_icon_textures.has(key):
		return _state_icon_textures[key] as Texture2D
	var texture := _load_tinted_svg_texture(STOPWATCH_ICON_PATH, "#fff2c8", STOPWATCH_ICON_TEXTURE)
	if texture:
		_state_icon_textures[key] = texture
	return texture


func _load_tinted_svg_texture(path: String, color_hex: String, fallback_texture: Texture2D = null) -> Texture2D:
	var svg := FileAccess.get_file_as_string(path)
	if svg.is_empty():
		return fallback_texture
	svg = svg.replace("#e0e0e0", color_hex)
	svg = svg.replace("#fc7f7f", color_hex)
	svg = svg.replace("fill=\"currentColor\"", "fill=\"" + color_hex + "\"")
	var image := Image.new()
	if image.load_svg_from_buffer(svg.to_utf8_buffer(), 2.0) != OK:
		return fallback_texture
	return ImageTexture.create_from_image(image)


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_title_font()


func _on_viewport_size_changed() -> void:
	queue_redraw()


func get_icon_counts_for_test() -> Dictionary:
	return {
		"props_total": props_total,
		"props_alive": props_alive,
		"hunters_total": hunters_total,
		"hunters_alive": hunters_alive,
	}


func get_state_icon_paths_for_test() -> Dictionary:
	return {
		"alive": ALIVE_ICON_PATH,
		"dead": DEAD_ICON_PATH,
		"timer": STOPWATCH_ICON_PATH,
	}


func has_state_icon_texture_for_test(alive: bool) -> bool:
	return _get_state_icon_texture(alive) != null


func has_timer_icon_texture_for_test() -> bool:
	return _get_stopwatch_texture() != null
