extends Control
class_name CamouflageHUD

const STATUS_IDLE := "Camouflage ready"
const STATUS_ACTIVE := "Click scene color"
const STATUS_PAINT := "Paint with LMB"
const STATUS_NO_SURFACE := "Aim at your body"
const STATUS_PREPARING := "Preparing paint surface"
const LOBBY_HUD_STATUS_FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const LOBBY_HUD_VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const LOBBY_HUD_ITALIC_SKEW := -0.18
const CROSSHAIR_OUTLINE_WIDTH := 7.0
const CROSSHAIR_LINE_WIDTH := 3.6
const CROSSHAIR_TICK_WIDTH := 2.2
const CROSSHAIR_CENTER_RADIUS := 3.8
const CROSSHAIR_MIN_RADIUS := 24.0
const CROSSHAIR_MAX_RADIUS := 54.0
const CROSSHAIR_GAP_FACTOR := 0.32
const STATUS_FONT_SIZE := 24
const STATUS_VALUE_FONT_SIZE := 36
const STATUS_UNIT_FONT_SIZE := 17
const STATUS_CONTROL_FONT_SIZE := 14
const STATUS_CAPTION_FONT_SIZE := 13
const STATUS_CONTROL_CAPTION := "Z/X Roughness  F/G Metallic"
const STATUS_OFFSET := Vector2(34.0, -64.0)
const STATUS_PADDING := Vector2(22.0, 16.0)
const STATUS_MIN_SIZE := Vector2(520.0, 132.0)
const STATUS_MARGIN := 18.0
const STATUS_GAP := 12.0
const STATUS_PANEL_CUT := 14.0
const STATUS_PANEL_DEPTH := Vector2(6.0, 7.0)
const STATUS_PANEL_DEFAULT_COLOR := Color(0.25, 0.22, 0.18, 0.92)
const STATUS_PANEL_DEFAULT_ACCENT := Color(0.55, 0.72, 0.86, 1.0)
const STATUS_PANEL_HERO_ACCENT := Color(1.0, 0.58, 0.18, 1.0)
const STATUS_PANEL_ICON_SIZE := 52.0
const STATUS_PANEL_ICON_GAP := 16.0
const STATUS_PANEL_METER_SEGMENTS := 18
const STATUS_PANEL_METER_HEIGHT := 11.0
const STATUS_PANEL_METER_GAP := 3.0
const STATUS_PANEL_METER_SKEW := 5.0
const STATUS_PANEL_METER_MIN_RADIUS := 8.0
const STATUS_PANEL_METER_MAX_RADIUS := 96.0

var _skill_active := false
var _has_color := false
var _brush_color := Color(0.42, 0.95, 0.72, 1.0)
var _brush_radius := 22.0
var _brush_angle := 0.0
var _brush_screen_position := Vector2.ZERO
var _has_surface_lock := false
var _status := STATUS_IDLE
var _flash_time := 0.0
var _flash_color := Color.WHITE
var _status_font: Font
var _value_font: Font
var _exact_color_match := false
var _paint_roughness := 1.0
var _paint_metallic := 0.0


func _ready() -> void:
	_load_lobby_fonts()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	visible = false


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
	if _skill_active:
		queue_redraw()


func set_skill_active(active: bool, has_color: bool, color: Color, radius: float, angle: float) -> void:
	_skill_active = active
	_has_color = has_color
	_brush_color = color
	_brush_radius = radius
	_brush_angle = angle
	_status = STATUS_PAINT if has_color else STATUS_ACTIVE
	visible = active
	queue_redraw()


func set_sampled_color(color: Color) -> void:
	_has_color = true
	_brush_color = color
	_status = STATUS_PAINT
	_flash(color, 0.28)
	queue_redraw()


func set_brush(radius: float, angle: float) -> void:
	_brush_radius = radius
	_brush_angle = angle
	queue_redraw()


func set_brush_surface(screen_position: Vector2, locked: bool) -> void:
	_brush_screen_position = screen_position
	_has_surface_lock = locked
	if _skill_active:
		_status = STATUS_PAINT if locked and _has_color else STATUS_NO_SURFACE if _has_color else STATUS_ACTIVE
	queue_redraw()


func set_preparing_surface() -> void:
	if not _skill_active:
		return
	_status = STATUS_PREPARING
	_has_surface_lock = false
	visible = true
	queue_redraw()


func set_failed(message: String) -> void:
	_status = message
	_flash(Color(1.0, 0.28, 0.18, 1.0), 0.36)
	visible = true
	queue_redraw()


func set_material_controls(exact_color_match: bool, roughness: float, metallic: float) -> void:
	_exact_color_match = exact_color_match
	_paint_roughness = clampf(roughness, 0.0, 1.0)
	_paint_metallic = clampf(metallic, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if not _skill_active:
		return

	var center := _brush_screen_position if _has_surface_lock else get_viewport().get_mouse_position()
	if _should_draw_crosshair():
		_draw_pointer(center)
	_draw_status(center)


func _draw_pointer(center: Vector2) -> void:
	var color := _brush_color if _has_color else Color(0.8, 0.88, 1.0, 1.0)
	var radius := clampf(_brush_radius * 0.95, CROSSHAIR_MIN_RADIUS, CROSSHAIR_MAX_RADIUS)
	var gap := clampf(radius * CROSSHAIR_GAP_FACTOR, 8.0, 16.0)
	var tick := clampf(radius * 0.32, 9.0, 18.0)
	_draw_crosshair_segments(center + Vector2(2.0, 2.0), radius, gap, tick, Color(0.0, 0.0, 0.0, 0.68), CROSSHAIR_OUTLINE_WIDTH)
	_draw_crosshair_segments(center, radius, gap, tick, Color(color.r, color.g, color.b, 0.96), CROSSHAIR_LINE_WIDTH)
	draw_circle(center, CROSSHAIR_CENTER_RADIUS + 2.0, Color(0.0, 0.0, 0.0, 0.70))
	draw_circle(center, CROSSHAIR_CENTER_RADIUS, Color(color.r, color.g, color.b, 0.98))

	if _flash_time > 0.0:
		draw_arc(center, radius + 8.0, -PI * 0.45, PI * 1.45, 64, Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_time * 2.2), CROSSHAIR_LINE_WIDTH)


func _draw_status(center: Vector2) -> void:
	var status_text := _status
	var control_text := "%s  R %.2f  M %.2f" % ["MATCH" if _exact_color_match else "LIT", _paint_roughness, _paint_metallic]
	var caption_text := STATUS_CONTROL_CAPTION
	var value_text := "%.0f" % _brush_radius
	var unit_text := "PX"
	var status_font := _get_status_font()
	var value_font := _get_value_font()
	var status_size := status_font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE)
	var control_size := status_font.get_string_size(control_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_CONTROL_FONT_SIZE)
	var caption_size := status_font.get_string_size(caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_CAPTION_FONT_SIZE)
	var value_size := value_font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_VALUE_FONT_SIZE)
	var unit_size := status_font.get_string_size(unit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_UNIT_FONT_SIZE)
	var value_width := value_size.x + 7.0 + unit_size.x
	var text_width := maxf(maxf(status_size.x, control_size.x), caption_size.x)
	var content_width := STATUS_PANEL_ICON_SIZE + STATUS_PANEL_ICON_GAP + text_width + STATUS_GAP + value_width
	var content_height := maxf(status_size.y + control_size.y + caption_size.y + 16.0, value_size.y) + STATUS_PANEL_METER_HEIGHT + 18.0
	var panel_size := Vector2(
		maxf(STATUS_MIN_SIZE.x, content_width + STATUS_PADDING.x * 2.0),
		maxf(STATUS_MIN_SIZE.y, content_height + STATUS_PADDING.y * 2.0)
	)
	var pos := center + STATUS_OFFSET
	var viewport_size := get_viewport_rect().size
	pos.x = clampf(pos.x, STATUS_MARGIN, maxf(STATUS_MARGIN, viewport_size.x - panel_size.x - STATUS_MARGIN))
	pos.y = clampf(pos.y, STATUS_MARGIN, maxf(STATUS_MARGIN, viewport_size.y - panel_size.y - STATUS_MARGIN))
	var rect := Rect2(pos, panel_size)
	var panel_color := _status_panel_color()
	var accent := _brush_color if _has_color else STATUS_PANEL_DEFAULT_ACCENT
	var text_color := _panel_text_color(panel_color)
	_draw_status_panel(rect, panel_color, accent)

	var icon_rect := Rect2(
		rect.position + Vector2(STATUS_PADDING.x, (rect.size.y - STATUS_PANEL_ICON_SIZE) * 0.5),
		Vector2(STATUS_PANEL_ICON_SIZE, STATUS_PANEL_ICON_SIZE)
	)
	_draw_status_emblem(icon_rect, panel_color, accent)

	var cursor_x := icon_rect.position.x + STATUS_PANEL_ICON_SIZE + STATUS_PANEL_ICON_GAP
	var status_baseline := rect.position.y + 45.0
	_draw_lobby_italic_string(status_font, Vector2(cursor_x + 1.0, status_baseline + 1.0), status_text, STATUS_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.32))
	_draw_lobby_italic_string(status_font, Vector2(cursor_x, status_baseline), status_text, STATUS_FONT_SIZE, text_color)
	var control_baseline := rect.position.y + 67.0
	_draw_lobby_italic_string(status_font, Vector2(cursor_x + 1.0, control_baseline + 1.0), control_text, STATUS_CONTROL_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.30))
	_draw_lobby_italic_string(status_font, Vector2(cursor_x, control_baseline), control_text, STATUS_CONTROL_FONT_SIZE, Color(text_color.r, text_color.g, text_color.b, 0.76))
	var caption_baseline := rect.position.y + 88.0
	_draw_lobby_italic_string(status_font, Vector2(cursor_x + 1.0, caption_baseline + 1.0), caption_text, STATUS_CAPTION_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.26))
	_draw_lobby_italic_string(status_font, Vector2(cursor_x, caption_baseline), caption_text, STATUS_CAPTION_FONT_SIZE, Color(text_color.r, text_color.g, text_color.b, 0.66))

	var value_x := rect.position.x + rect.size.x - STATUS_PADDING.x - value_width - 8.0
	var value_baseline := rect.position.y + 48.0
	_draw_lobby_italic_string(value_font, Vector2(value_x + 1.0, value_baseline + 1.0), value_text, STATUS_VALUE_FONT_SIZE, Color(0.0, 0.0, 0.0, 0.30))
	_draw_lobby_italic_string(value_font, Vector2(value_x, value_baseline), value_text, STATUS_VALUE_FONT_SIZE, text_color)
	_draw_lobby_italic_string(status_font, Vector2(value_x + value_size.x + 7.0, value_baseline - 1.0), unit_text, STATUS_UNIT_FONT_SIZE, Color(text_color.r, text_color.g, text_color.b, 0.82))

	var meter_left := cursor_x
	var meter_right := rect.position.x + rect.size.x - STATUS_PADDING.x - 8.0
	var meter_rect := Rect2(
		Vector2(meter_left, rect.position.y + rect.size.y - 30.0),
		Vector2(maxf(80.0, meter_right - meter_left), STATUS_PANEL_METER_HEIGHT)
	)
	_draw_status_meter(meter_rect, _brush_radius, panel_color)


func _should_draw_crosshair() -> bool:
	return _skill_active and not _has_surface_lock


func _load_lobby_fonts() -> void:
	_status_font = _load_font(LOBBY_HUD_STATUS_FONT_PATH)
	_value_font = _load_font(LOBBY_HUD_VALUE_FONT_PATH)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_status_font() -> Font:
	return _status_font if _status_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_status_font()


func _draw_lobby_italic_string(font: Font, position: Vector2, text: String, font_size: int, color: Color) -> void:
	var transform := Transform2D(Vector2(1.0, 0.0), Vector2(LOBBY_HUD_ITALIC_SKEW, 1.0), position)
	draw_set_transform_matrix(transform)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_crosshair_segments(center: Vector2, radius: float, gap: float, tick: float, color: Color, width: float) -> void:
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(-gap, 0.0), color, width, true)
	draw_line(center + Vector2(gap, 0.0), center + Vector2(radius, 0.0), color, width, true)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -gap), color, width, true)
	draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, radius), color, width, true)
	var corner := radius * 0.72
	var inner := radius - tick
	draw_line(center + Vector2(-radius, -corner), center + Vector2(-inner, -corner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(-corner, -radius), center + Vector2(-corner, -inner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(radius, -corner), center + Vector2(inner, -corner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(corner, -radius), center + Vector2(corner, -inner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(-radius, corner), center + Vector2(-inner, corner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(-corner, radius), center + Vector2(-corner, inner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(radius, corner), center + Vector2(inner, corner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)
	draw_line(center + Vector2(corner, radius), center + Vector2(corner, inner), color, CROSSHAIR_TICK_WIDTH if width < CROSSHAIR_OUTLINE_WIDTH else width, true)


func _status_panel_color() -> Color:
	if _has_color:
		return Color(_brush_color.r, _brush_color.g, _brush_color.b, 0.96)
	return STATUS_PANEL_DEFAULT_COLOR


func _panel_text_color(panel_color: Color) -> Color:
	var luminance := panel_color.r * 0.2126 + panel_color.g * 0.7152 + panel_color.b * 0.0722
	return Color(0.04, 0.05, 0.055, 1.0) if luminance > 0.58 else Color(0.94, 1.0, 0.98, 1.0)


func _draw_status_panel(rect: Rect2, panel_color: Color, accent: Color) -> void:
	var front := _panel_points(rect, STATUS_PANEL_CUT)
	draw_colored_polygon(_panel_points(Rect2(rect.position + Vector2(5.0, 6.0), rect.size), STATUS_PANEL_CUT), Color(0.0, 0.0, 0.0, 0.32))
	draw_colored_polygon(_panel_right_depth_points(rect, STATUS_PANEL_DEPTH, STATUS_PANEL_CUT), panel_color.darkened(0.48))
	draw_colored_polygon(_panel_bottom_depth_points(rect, STATUS_PANEL_DEPTH, STATUS_PANEL_CUT), panel_color.darkened(0.62))
	draw_colored_polygon(_panel_points(rect, STATUS_PANEL_CUT), panel_color)
	var left_facet := PackedVector2Array([
		rect.position + Vector2(0.0, STATUS_PANEL_CUT),
		rect.position + Vector2(32.0, 0.0),
		rect.position + Vector2(68.0, 0.0),
		rect.position + Vector2(36.0, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y),
	])
	draw_colored_polygon(left_facet, Color(1.0, 1.0, 1.0, 0.08))
	var top_sheen := Rect2(rect.position + Vector2(STATUS_PANEL_CUT + 4.0, 6.0), Vector2(rect.size.x - STATUS_PANEL_CUT * 2.6, rect.size.y * 0.27))
	draw_colored_polygon(_panel_points(top_sheen, 7.0), Color(1.0, 1.0, 1.0, 0.14))
	var hero_accent := STATUS_PANEL_HERO_ACCENT.lerp(accent, 0.35)
	var leading_wedge := PackedVector2Array([
		rect.position + Vector2(STATUS_PANEL_CUT + 2.0, 0.0),
		rect.position + Vector2(STATUS_PANEL_CUT + 54.0, 0.0),
		rect.position + Vector2(STATUS_PANEL_CUT + 42.0, 5.0),
		rect.position + Vector2(STATUS_PANEL_CUT - 6.0, 5.0),
	])
	draw_colored_polygon(leading_wedge, Color(hero_accent.r, hero_accent.g, hero_accent.b, 0.68))
	var trailing_wedge := PackedVector2Array([
		rect.position + Vector2(rect.size.x - 86.0, rect.size.y - 5.0),
		rect.position + Vector2(rect.size.x - 28.0, rect.size.y - 5.0),
		rect.position + Vector2(rect.size.x - STATUS_PANEL_CUT, rect.size.y),
		rect.position + Vector2(rect.size.x - 76.0, rect.size.y),
	])
	draw_colored_polygon(trailing_wedge, Color(accent.r, accent.g, accent.b, 0.42))
	var inner_shadow := _panel_points(rect.grow(-6.0), maxf(2.0, STATUS_PANEL_CUT - 6.0))
	draw_polyline(_closed_points(inner_shadow), Color(0.0, 0.0, 0.0, 0.16), 3.0, true)
	var highlight := PackedVector2Array([front[0], front[1], front[2]])
	draw_polyline(highlight, Color(1.0, 1.0, 1.0, 0.18), 2.0, true)


func _draw_status_emblem(rect: Rect2, panel_color: Color, accent: Color) -> void:
	var glow_rect := rect.grow(12.0)
	draw_colored_polygon(_hex_points(glow_rect), Color(0.32, 0.75, 1.0, 0.15))
	draw_colored_polygon(_hex_points(rect.grow(5.0)), Color(accent.r, accent.g, accent.b, 0.24))
	draw_colored_polygon(_hex_points(rect), panel_color.lightened(0.10))
	draw_colored_polygon(_hex_points(rect.grow(-8.0)), Color(accent.r, accent.g, accent.b, 0.34))
	draw_colored_polygon(_hex_points(rect.grow(-15.0)), Color(1.0, 1.0, 1.0, 0.16))
	var glint := Rect2(rect.position + Vector2(15.0, 9.0), Vector2(rect.size.x - 30.0, 4.0))
	draw_colored_polygon(_panel_points(glint, 2.0), Color(1.0, 1.0, 1.0, 0.22))


func _draw_status_meter(rect: Rect2, radius: float, panel_color: Color) -> void:
	var normalized := clampf(
		(radius - STATUS_PANEL_METER_MIN_RADIUS) / maxf(1.0, STATUS_PANEL_METER_MAX_RADIUS - STATUS_PANEL_METER_MIN_RADIUS),
		0.0,
		1.0
	)
	var active_segments := clampi(ceili(normalized * float(STATUS_PANEL_METER_SEGMENTS)), 1, STATUS_PANEL_METER_SEGMENTS)
	var total_gap := STATUS_PANEL_METER_GAP * float(STATUS_PANEL_METER_SEGMENTS - 1)
	var segment_width := maxf(2.0, (rect.size.x - total_gap) / float(STATUS_PANEL_METER_SEGMENTS))
	var segment_color := _panel_text_color(panel_color)
	for index in range(STATUS_PANEL_METER_SEGMENTS):
		var segment_rect := Rect2(
			rect.position + Vector2(float(index) * (segment_width + STATUS_PANEL_METER_GAP), 0.0),
			Vector2(segment_width, rect.size.y)
		)
		var alpha := 0.78 if index < active_segments else 0.22
		draw_colored_polygon(_meter_segment_points(segment_rect, STATUS_PANEL_METER_SKEW), Color(segment_color.r, segment_color.g, segment_color.b, alpha))
	var flare_x := rect.position.x + (segment_width + STATUS_PANEL_METER_GAP) * float(active_segments - 1)
	draw_circle(Vector2(flare_x, rect.position.y + rect.size.y * 0.5), 5.0, Color(0.35, 0.72, 1.0, 0.34))


func _panel_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var clipped_cut := minf(cut, rect.size.y * 0.42)
	return PackedVector2Array([
		rect.position + Vector2(clipped_cut, 0.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y - clipped_cut),
		rect.position + Vector2(rect.size.x - clipped_cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y),
		rect.position + Vector2(0.0, clipped_cut),
	])


func _hex_points(rect: Rect2) -> PackedVector2Array:
	var cut := rect.size.x * 0.22
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		rect.position + Vector2(rect.size.x - cut, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y * 0.5),
		rect.position + Vector2(rect.size.x - cut, rect.size.y),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y * 0.5),
	])


func _meter_segment_points(rect: Rect2, skew: float) -> PackedVector2Array:
	var clipped_skew := minf(skew, rect.size.x * 0.45)
	return PackedVector2Array([
		rect.position + Vector2(clipped_skew, 0.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x - clipped_skew, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y),
	])


func _panel_right_depth_points(rect: Rect2, depth: Vector2, cut: float) -> PackedVector2Array:
	var clipped_cut := minf(cut, rect.size.y * 0.42)
	var top_right := rect.position + Vector2(rect.size.x, 0.0)
	var bevel_right := rect.position + Vector2(rect.size.x, rect.size.y - clipped_cut)
	var bottom_right := rect.position + Vector2(rect.size.x - clipped_cut, rect.size.y)
	return PackedVector2Array([
		top_right,
		top_right + depth,
		bevel_right + depth,
		bottom_right + depth,
		bottom_right,
		bevel_right,
	])


func _panel_bottom_depth_points(rect: Rect2, depth: Vector2, cut: float) -> PackedVector2Array:
	var clipped_cut := minf(cut, rect.size.y * 0.42)
	var bottom_left := rect.position + Vector2(0.0, rect.size.y)
	var bottom_right := rect.position + Vector2(rect.size.x - clipped_cut, rect.size.y)
	var bevel_right := rect.position + Vector2(rect.size.x, rect.size.y - clipped_cut)
	return PackedVector2Array([
		bottom_left,
		bottom_right,
		bevel_right,
		bevel_right + depth,
		bottom_right + depth,
		bottom_left + depth,
	])


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _flash(color: Color, duration: float) -> void:
	_flash_color = color
	_flash_time = duration
