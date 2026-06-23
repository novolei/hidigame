extends Control
class_name SkillHUD

const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const CARD_SIZE := Vector2(76.0, 76.0)
const CARD_GAP := 4.0
const STEP_Y := 10.0
const MARGIN := Vector2(26.0, 28.0)
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const BASE_HUD_SCALE := 1.35
const MIN_HUD_SCALE := 0.82
const MAX_HUD_SCALE := 2.15
const METER_SLANT_Y := 4.0
const KEY_FONT_SIZE := 22
const TITLE_FONT_SIZE := 13
const COOLDOWN_FONT_SIZE := 24
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

var _skills: Array = []
var _title_font: Font = null
var _value_font: Font = null
var _icon_textures: Dictionary = {}


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_skills(skills: Array) -> void:
	_skills = skills.duplicate(true)
	visible = not _skills.is_empty()
	queue_redraw()


func clear_skills() -> void:
	_skills.clear()
	visible = false
	queue_redraw()


func _draw() -> void:
	if _skills.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var hud_scale := _get_hud_scale(viewport_size)
	var card_size := CARD_SIZE * hud_scale
	var card_gap := CARD_GAP * hud_scale
	var step_y := STEP_Y * hud_scale
	var margin := MARGIN * hud_scale
	var total_width := float(_skills.size()) * card_size.x + float(maxi(_skills.size() - 1, 0)) * card_gap
	var start := Vector2(
		viewport_size.x - margin.x - total_width,
		viewport_size.y - margin.y - card_size.y - float(maxi(_skills.size() - 1, 0)) * step_y
	)
	for i in range(_skills.size()):
		var skill: Dictionary = _skills[i]
		var pos := start + Vector2(float(i) * (card_size.x + card_gap), float(i) * step_y)
		_draw_skill_card(skill, Rect2(pos, card_size), i, hud_scale)


func _draw_skill_card(skill: Dictionary, rect: Rect2, index: int, hud_scale: float) -> void:
	var active := bool(skill.get("active", false))
	var disabled := bool(skill.get("disabled", false))
	var cooldown_remaining := float(skill.get("cooldown_remaining", 0.0))
	var cooldown_total := maxf(float(skill.get("cooldown_total", 0.0)), 0.01)
	var charge_ratio := clampf(float(skill.get("charge_ratio", 1.0)), 0.0, 1.0)
	var accent := Color(1.0, 1.0, 1.0, 0.96)
	if active:
		accent = Color(1.0, 1.0, 1.0, 1.0)
	elif disabled or cooldown_remaining > 0.0:
		accent = Color(0.72, 0.76, 0.80, 0.66)

	var line_width := rect.size.x - 18.0 * hud_scale
	var slant_angle := atan2(METER_SLANT_Y * hud_scale, line_width)
	var icon_rect := rect.grow(-6.0 * hud_scale)
	icon_rect.position.y -= 1.0 * hud_scale
	icon_rect.size.y -= 8.0 * hud_scale
	_draw_icon(str(skill.get("icon", "locked")), icon_rect, accent, disabled or cooldown_remaining > 0.0, slant_angle)
	_draw_charge_meter(rect, charge_ratio, active, disabled, hud_scale)

	if cooldown_remaining > 0.0:
		var ratio := clampf(cooldown_remaining / cooldown_total, 0.0, 1.0)
		var overlay_rect := Rect2(icon_rect.position + Vector2(0.0, icon_rect.size.y * (1.0 - ratio)), Vector2(icon_rect.size.x, icon_rect.size.y * ratio))
		draw_rect(overlay_rect, Color(0.0, 0.0, 0.0, 0.42), true)
		_draw_centered_text(_get_value_font(), rect.position + Vector2(0.0, 48.0 * hud_scale), rect.size.x, "%.0fs" % ceil(cooldown_remaining), _scaled_font_size(COOLDOWN_FONT_SIZE, hud_scale), Color(1.0, 1.0, 1.0, 0.92))

	var key := str(skill.get("key", str(index + 1)))
	var key_y := rect.position.y + rect.size.y + 22.0 * hud_scale
	_draw_centered_text(_get_value_font(), Vector2(rect.position.x, key_y), rect.size.x, key, _scaled_font_size(KEY_FONT_SIZE, hud_scale), Color(1.0, 0.97, 0.90, 0.95))
	var title := str(skill.get("title", ""))
	if not title.is_empty():
		_draw_centered_text(_get_title_font(), Vector2(rect.position.x, rect.position.y - 6.0 * hud_scale), rect.size.x, title.to_upper(), _scaled_font_size(TITLE_FONT_SIZE, hud_scale), Color(0.80, 0.93, 1.0, 0.62))


func _draw_charge_meter(rect: Rect2, charge_ratio: float, active: bool, disabled: bool, hud_scale: float) -> void:
	var width := rect.size.x - 18.0 * hud_scale
	var y := rect.position.y + rect.size.y - 5.0 * hud_scale
	var x := rect.position.x + 9.0 * hud_scale
	var line_start := Vector2(x, y)
	var line_end := Vector2(x + width, y + METER_SLANT_Y * hud_scale)
	draw_line(line_start + Vector2(0.0, 2.0 * hud_scale), line_end + Vector2(0.0, 2.0 * hud_scale), Color(0.02, 0.05, 0.07, 0.82), 5.0 * hud_scale, true)
	if not disabled and charge_ratio > 0.0:
		var color := Color(0.62, 0.92, 1.0, 0.95) if not active else Color(1.0, 0.92, 0.48, 1.0)
		draw_line(line_start, line_start.lerp(line_end, charge_ratio), color, 4.0 * hud_scale, true)


func _draw_icon(icon: String, rect: Rect2, color: Color, muted: bool, slant_angle: float) -> void:
	var icon_color := Color(color.r, color.g, color.b, 0.38 if muted else color.a)
	var texture := _get_icon_texture(icon)
	if texture:
		var center := rect.get_center()
		draw_set_transform(center, slant_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-rect.size * 0.5, rect.size), false, icon_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_centered_text(font: Font, pos: Vector2, width: float, text: String, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.0, 0.0, 0.0, color.a * 0.48))
	draw_string(font, pos - Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_hud_scale(viewport_size: Vector2) -> float:
	var resolution_scale := BASE_HUD_SCALE * minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	return clampf(resolution_scale, MIN_HUD_SCALE, MAX_HUD_SCALE)


func _on_viewport_size_changed() -> void:
	queue_redraw()


func _scaled_font_size(base_size: int, hud_scale: float) -> int:
	return maxi(8, int(round(float(base_size) * hud_scale)))


func _get_icon_texture(icon: String) -> Texture2D:
	var icon_key := icon if ICON_TEXTURE_PATHS.has(icon) else "locked"
	if _icon_textures.has(icon_key):
		return _icon_textures[icon_key] as Texture2D
	var image := Image.new()
	var error := image.load(str(ICON_TEXTURE_PATHS[icon_key]))
	if error != OK:
		if icon_key != "locked":
			return _get_icon_texture("locked")
		return null
	var texture := ImageTexture.create_from_image(image)
	_icon_textures[icon_key] = texture
	return texture


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_title_font()
