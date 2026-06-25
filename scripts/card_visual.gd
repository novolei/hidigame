extends Button
class_name CardVisual

const CardDatabase := preload("res://scripts/card_database.gd")
const SHADER := preload("res://shaders/card_sheen_3d.gdshader")
const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const DRAFT_HOVER_TILT_X := 0.26
const DRAFT_HOVER_TILT_Y := 0.34
const DRAFT_PRESS_TILT_RELIEF := 0.08
const ICON_TEXTURE_PATHS := {
	"flashlight": "res://assets/ui/skills/flashlight.png",
	"stealth": "res://assets/ui/skills/stealth.png",
	"blink": "res://assets/ui/skills/blink.png",
	"detect": "res://assets/ui/skills/detect.png",
	"shape": "res://assets/ui/skills/shape.png",
	"camo": "res://assets/ui/skills/camo.png",
	"grapple": "res://assets/ui/skills/grapple.png",
	"sprint": "res://assets/ui/skills/sprint.png",
	"locked": "res://assets/ui/skills/locked.png",
}

var card_id := ""
var key_text := ""
var display_mode := "draft"
var used := false
var auto_card := false
var _title_font: Font = null
var _value_font: Font = null
var _icon_textures: Dictionary = {}
var _shader_material: ShaderMaterial = null
var _flash_phase := 0.0
var _hover_amount := 0.0
var _press_amount := 0.0


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_title_font = _load_font(FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = SHADER
	_apply_visual_mode()


func configure(next_card_id: String, next_key_text: String, mode: String, is_used: bool = false, is_auto: bool = false) -> void:
	card_id = next_card_id
	key_text = next_key_text
	display_mode = mode
	used = is_used
	auto_card = is_auto
	disabled = used or auto_card
	tooltip_text = "%s\n%s" % [CardDatabase.display_name_for_locale(card_id), CardDatabase.description_for_locale(card_id)]
	_apply_visual_mode()
	queue_redraw()


func _process(delta: float) -> void:
	if display_mode == "slot":
		return
	_flash_phase = fmod(_flash_phase + delta * (0.32 if display_mode == "slot" else 0.46), 1.0)
	var target_hover := 1.0 if is_hovered() and not disabled else 0.0
	_hover_amount = lerpf(_hover_amount, target_hover, minf(delta * 10.0, 1.0))
	_press_amount = lerpf(_press_amount, 1.0 if button_pressed else 0.0, minf(delta * 16.0, 1.0))
	if _shader_material:
		_shader_material.set_shader_parameter("flash_phase", _flash_phase)
		_shader_material.set_shader_parameter("hover_amount", _hover_amount)
		_shader_material.set_shader_parameter("flash_intensity", 0.92 + _hover_amount * 0.55)
		_shader_material.set_shader_parameter("outline_intensity", 0.78 + _hover_amount * 0.72)
		var pointer := _hover_pointer_offset()
		var fallback_tilt := 1.0 if _hover_amount > 0.01 and pointer.length_squared() < 0.08 else 0.0
		_shader_material.set_shader_parameter("tilt_x", ((-pointer.y + fallback_tilt) * _hover_amount * DRAFT_HOVER_TILT_X) - _press_amount * DRAFT_PRESS_TILT_RELIEF)
		_shader_material.set_shader_parameter("tilt_y", (pointer.x + fallback_tilt * 0.65) * _hover_amount * DRAFT_HOVER_TILT_Y)
	queue_redraw()


func _apply_visual_mode() -> void:
	if display_mode == "slot":
		material = null
		set_process(false)
		_flash_phase = 0.0
		_hover_amount = 0.0
		_press_amount = 0.0
		return
	if _shader_material:
		material = _shader_material
	set_process(true)


func _hover_pointer_offset() -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0 or not is_hovered() or disabled:
		return Vector2.ZERO
	var local := get_local_mouse_position()
	return Vector2(
		clampf((local.x / size.x - 0.5) * 2.0, -1.0, 1.0),
		clampf((local.y / size.y - 0.5) * 2.0, -1.0, 1.0)
	)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var card := CardDatabase.get_card(card_id)
	var is_slot := display_mode == "slot"
	var corner := 12.0 if is_slot else 24.0
	var accent := _accent_color(card)
	var disabled_alpha := 0.44 if disabled else 1.0
	var border_color := accent
	border_color.a = 0.96 * disabled_alpha
	var shadow_rect := rect.grow(-2.0)
	shadow_rect.position += Vector2(0.0, 4.0 if is_slot else 9.0)
	_draw_round_rect(shadow_rect, corner, Color(0.0, 0.0, 0.0, 0.28 * disabled_alpha), false, 0.0)
	var metal_outer := _metal_edge_color(card, 0.92 * disabled_alpha)
	_draw_round_rect(rect, corner, metal_outer, false, 0.0)
	_draw_metal_edge(rect.grow(-1.5), corner - 1.5, card, disabled_alpha)
	var inner := rect.grow(-3.0 if is_slot else -5.5)
	_draw_round_rect(inner, maxf(corner - 4.0, 6.0), Color(0.88, 0.94, 0.97, 0.98 * disabled_alpha), false, 0.0)

	_draw_card_image_area(inner, card, is_slot, accent, disabled_alpha)
	_draw_card_bottom(inner, card, is_slot, disabled_alpha)
	_draw_key_badge(inner, is_slot, disabled_alpha)
	if used:
		_draw_used_overlay(inner)
	elif auto_card:
		_draw_auto_badge(inner, disabled_alpha)


func _draw_card_image_area(inner: Rect2, card: Dictionary, is_slot: bool, accent: Color, alpha: float) -> void:
	var bottom_height := inner.size.y * (0.24 if is_slot else 0.20)
	var image_rect := Rect2(inner.position, Vector2(inner.size.x, inner.size.y - bottom_height))
	var inner_corner := maxf((12.0 if is_slot else 24.0) - 4.0, 6.0)
	var top := Color(0.92, 0.98, 1.0, 1.0 * alpha)
	var bottom := Color(0.74, 0.84, 0.90, 1.0 * alpha)
	_draw_round_rect_corners(image_rect, inner_corner, inner_corner, 0.0, 0.0, top, false, 0.0)
	for i in range(10):
		var t := float(i) / 9.0
		var stripe := Rect2(image_rect.position + Vector2(0.0, image_rect.size.y * t), Vector2(image_rect.size.x, image_rect.size.y / 10.0 + 1.0))
		_draw_rounded_content_strip(stripe, image_rect, inner_corner, inner_corner, 0.0, 0.0, top.lerp(bottom, t))
	if not is_slot:
		var glow_center := image_rect.position + Vector2(image_rect.size.x * 0.50, image_rect.size.y * 0.42)
		for r in range(5):
			var glow_alpha := (0.11 - float(r) * 0.018) * alpha
			_draw_rounded_content_circle(glow_center, image_rect.size.y * (0.46 + float(r) * 0.09), image_rect, inner_corner, inner_corner, 0.0, 0.0, Color(1.0, 1.0, 1.0, glow_alpha))
	else:
		var scan_color := accent
		scan_color.a = 0.08 * alpha
		for x in range(0, int(image_rect.size.x), 10):
			draw_line(Vector2(image_rect.position.x + x, image_rect.position.y), Vector2(image_rect.position.x + x + image_rect.size.y * 0.22, image_rect.position.y + image_rect.size.y), scan_color, 1.0)
	var icon_key := str(card.get("icon", "locked"))
	var icon := _get_icon_texture(icon_key)
	if icon:
		var icon_side := image_rect.size.y * (0.48 if is_slot else 0.44)
		var icon_rect := Rect2(image_rect.get_center() - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
		var icon_color := Color(0.05, 0.06, 0.07, 0.80 * alpha) if is_slot else _metal_edge_color(card, 0.88 * alpha)
		draw_texture_rect(icon, icon_rect, false, icon_color)
	var pill_height := 15.0 if is_slot else 26.0
	var pill_rect := Rect2(image_rect.position + Vector2(7.0, image_rect.size.y - pill_height - (4.0 if is_slot else 10.0)), Vector2(image_rect.size.x * (0.50 if is_slot else 0.46), pill_height))
	var pill_color := accent
	pill_color.a = 0.92 * alpha
	_draw_round_rect(pill_rect, pill_rect.size.y * 0.35, pill_color, false, 0.0)
	var label := str(card.get("category", "CARD")).to_upper()
	_draw_centered_text(_get_value_font(), pill_rect.position + Vector2(0.0, pill_rect.size.y * 0.72), pill_rect.size.x, label, 8 if is_slot else 15, Color.WHITE)


func _draw_card_bottom(inner: Rect2, card: Dictionary, is_slot: bool, alpha: float) -> void:
	var bottom_height := inner.size.y * (0.24 if is_slot else 0.20)
	var bottom_rect := Rect2(inner.position + Vector2(0.0, inner.size.y - bottom_height), Vector2(inner.size.x, bottom_height))
	var inner_corner := maxf((12.0 if is_slot else 24.0) - 4.0, 6.0)
	_draw_round_rect_corners(bottom_rect, 0.0, 0.0, inner_corner, inner_corner, Color(0.02, 0.018, 0.022, 0.96 * alpha), false, 0.0)
	var name := CardDatabase.display_name_for_locale(card_id)
	var code := str(card.get("code", ""))
	var title_size := 14 if is_slot else 34
	if name.length() > 5:
		title_size = 12 if is_slot else 30
	_draw_centered_text(_get_title_font(), bottom_rect.position + Vector2(0.0, bottom_rect.size.y * (0.62 if is_slot else 0.64)), bottom_rect.size.x, name, title_size, Color(0.98, 0.98, 1.0, alpha))
	if not is_slot:
		draw_string(_get_value_font(), bottom_rect.position + Vector2(12.0, bottom_rect.size.y - 13.0), code, HORIZONTAL_ALIGNMENT_LEFT, bottom_rect.size.x - 24.0, 19, Color(0.82, 0.92, 1.0, 0.78 * alpha))


func _draw_key_badge(inner: Rect2, is_slot: bool, alpha: float) -> void:
	if key_text.is_empty():
		return
	var radius := 13.5 if is_slot else 26.0
	var center := inner.position + Vector2(radius + (5.0 if is_slot else 8.0), radius + (5.0 if is_slot else 8.0))
	draw_circle(center + Vector2(2.0, 3.0), radius, Color(0.0, 0.0, 0.0, 0.34 * alpha))
	draw_circle(center, radius, Color(0.98, 0.98, 0.98, 0.95 * alpha))
	draw_arc(center, radius - 2.0, -PI * 0.5, PI * 1.5, 48, Color(0.35, 0.39, 0.42, 0.82 * alpha), 2.0 if is_slot else 3.0)
	_draw_centered_text(_get_value_font(), Vector2(center.x - radius, center.y + radius * 0.42), radius * 2.0, key_text, 17 if is_slot else 34, Color(0.42, 0.44, 0.46, alpha))


func _draw_used_overlay(inner: Rect2) -> void:
	draw_rect(inner, Color(0.0, 0.0, 0.0, 0.48), true)
	_draw_centered_text(_get_title_font(), inner.position + Vector2(0.0, inner.size.y * 0.55), inner.size.x, "USED", 26, Color(1.0, 1.0, 1.0, 0.88))


func _draw_auto_badge(inner: Rect2, alpha: float) -> void:
	var badge := Rect2(inner.position + Vector2(inner.size.x - 58.0, 9.0), Vector2(48.0, 24.0))
	_draw_round_rect(badge, 7.0, Color(0.92, 0.86, 0.42, 0.92 * alpha), false, 0.0)
	_draw_centered_text(_get_value_font(), badge.position + Vector2(0.0, 18.0), badge.size.x, "AUTO", 13, Color(0.02, 0.02, 0.02, alpha))


func _draw_round_rect(rect: Rect2, corner: float, color: Color, border: bool, width: float) -> void:
	_draw_round_rect_corners(rect, corner, corner, corner, corner, color, border, width)


func _draw_round_rect_corners(rect: Rect2, top_left: float, top_right: float, bottom_right: float, bottom_left: float, color: Color, border: bool, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT if border else color
	style.border_color = color if border else Color.TRANSPARENT
	style.border_width_left = int(width)
	style.border_width_top = int(width)
	style.border_width_right = int(width)
	style.border_width_bottom = int(width)
	style.corner_radius_top_left = int(top_left)
	style.corner_radius_top_right = int(top_right)
	style.corner_radius_bottom_left = int(bottom_left)
	style.corner_radius_bottom_right = int(bottom_right)
	draw_style_box(style, rect)


func _draw_rounded_content_strip(strip: Rect2, clip_rect: Rect2, top_left: float, top_right: float, bottom_right: float, bottom_left: float, color: Color) -> void:
	var y_mid := clampf(strip.get_center().y, clip_rect.position.y, clip_rect.end.y)
	var left_inset := _rounded_corner_inset_for_y(y_mid, clip_rect, top_left, bottom_left)
	var right_inset := _rounded_corner_inset_for_y(y_mid, Rect2(Vector2(clip_rect.position.x, clip_rect.position.y), clip_rect.size), top_right, bottom_right)
	var clipped := Rect2(strip.position + Vector2(left_inset, 0.0), Vector2(maxf(strip.size.x - left_inset - right_inset, 0.0), strip.size.y))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	draw_rect(clipped, color, true)


func _draw_rounded_content_circle(center: Vector2, radius: float, clip_rect: Rect2, top_left: float, top_right: float, bottom_right: float, bottom_left: float, color: Color) -> void:
	var steps := maxi(18, int(radius / 3.0))
	var strip_height := radius * 2.0 / float(steps)
	for i in range(steps):
		var y := center.y - radius + (float(i) + 0.5) * strip_height
		if y < clip_rect.position.y or y > clip_rect.end.y:
			continue
		var dy := y - center.y
		var half_width := sqrt(maxf(radius * radius - dy * dy, 0.0))
		var strip := Rect2(Vector2(center.x - half_width, y - strip_height * 0.5), Vector2(half_width * 2.0, strip_height + 0.75))
		var clipped_start := maxf(strip.position.x, clip_rect.position.x)
		var clipped_end := minf(strip.end.x, clip_rect.end.x)
		if clipped_end <= clipped_start:
			continue
		strip.position.x = clipped_start
		strip.size.x = clipped_end - clipped_start
		_draw_rounded_content_strip(strip, clip_rect, top_left, top_right, bottom_right, bottom_left, color)


func _rounded_corner_inset_for_y(y: float, rect: Rect2, top_radius: float, bottom_radius: float) -> float:
	var inset := 0.0
	if top_radius > 0.0 and y < rect.position.y + top_radius:
		var dy := rect.position.y + top_radius - y
		inset = maxf(inset, top_radius - sqrt(maxf(top_radius * top_radius - dy * dy, 0.0)))
	if bottom_radius > 0.0 and y > rect.end.y - bottom_radius:
		var dy_bottom := y - (rect.end.y - bottom_radius)
		inset = maxf(inset, bottom_radius - sqrt(maxf(bottom_radius * bottom_radius - dy_bottom * dy_bottom, 0.0)))
	return inset


func _draw_metal_edge(rect: Rect2, corner: float, card: Dictionary, alpha: float) -> void:
	var team := str(card.get("team", ""))
	var warm := team == CardDatabase.TEAM_HUNTER
	var bright := Color(1.0, 0.88, 0.50, 0.54 * alpha) if warm else Color(0.88, 0.98, 1.0, 0.62 * alpha)
	var low := Color(0.32, 0.36, 0.42, 0.42 * alpha) if warm else Color(0.45, 0.54, 0.60, 0.44 * alpha)
	_draw_round_rect(rect, corner, low, false, 0.0)
	var top_line := Rect2(rect.position + Vector2(corner * 0.45, 1.5), Vector2(rect.size.x - corner * 0.9, 1.4))
	var left_line := Rect2(rect.position + Vector2(1.5, corner * 0.62), Vector2(1.4, rect.size.y * 0.56))
	var right_line := Rect2(rect.position + Vector2(rect.size.x - 3.0, corner * 0.7), Vector2(1.2, rect.size.y * 0.42))
	draw_rect(top_line, bright, true)
	draw_rect(left_line, bright.darkened(0.08), true)
	draw_rect(right_line, Color(1.0, 1.0, 1.0, 0.28 * alpha), true)
	draw_arc(rect.position + Vector2(corner, corner), corner - 3.0, PI, PI * 1.5, 16, bright, 1.4)
	draw_arc(rect.position + Vector2(rect.size.x - corner, corner), corner - 3.0, PI * 1.5, PI * 2.0, 16, Color(1.0, 1.0, 1.0, 0.34 * alpha), 1.2)


func _draw_centered_text(font: Font, pos: Vector2, width: float, text_value: String, size_px: int, color: Color) -> void:
	draw_string(font, pos + Vector2(1.0, 1.0), text_value, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, Color(0.0, 0.0, 0.0, color.a * 0.58))
	draw_string(font, pos, text_value, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, color)


func _accent_color(card: Dictionary) -> Color:
	match str(card.get("team", "")):
		CardDatabase.TEAM_HUNTER:
			return Color(0.92, 0.28, 0.24, 1.0)
		_:
			return Color(0.92, 0.22, 0.60, 1.0)


func _metal_edge_color(card: Dictionary, alpha: float) -> Color:
	if str(card.get("team", "")) == CardDatabase.TEAM_HUNTER:
		return Color(0.92, 0.55, 0.38, alpha)
	return Color(0.78, 0.93, 1.0, alpha)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_title_font()


func _get_icon_texture(icon: String) -> Texture2D:
	var icon_key := icon if ICON_TEXTURE_PATHS.has(icon) else "locked"
	if _icon_textures.has(icon_key):
		return _icon_textures[icon_key] as Texture2D
	var texture := load(str(ICON_TEXTURE_PATHS[icon_key]))
	if not texture is Texture2D:
		if icon_key != "locked":
			return _get_icon_texture("locked")
		return null
	_icon_textures[icon_key] = texture
	return texture as Texture2D
