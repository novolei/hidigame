extends Control
class_name RadialWheelMenu

## Reusable Apex-style radial selector. Pure _draw() based, no .tscn dependency.
## A ring of equal wedges around a glass hub; the wedge under the cursor (by
## direction from centre) smoothly pops out and lights up in the accent colour,
## plays a soft hover tick, and the hub shows the menu title plus the hovered
## option's label.
##
## Interaction: hold the skill key to show, aim with the cursor, release to pick
## (select_hovered); also left-click to pick, number keys 1-N, right-click / Esc
## to cancel. Used by the Chameleon Shape-Shift (Q) and Environment-Blend (C).

signal option_chosen(index: int)
signal cancelled()

const FONT_TITLE := "res://assets/fonts/SairaCondensed-Bold.woff2"
const FONT_LABEL := "res://assets/fonts/SairaCondensed-Medium.woff2"
const HOVER_SOUND_PATH := "res://assets/audio/ui/ui_select_click.mp3"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)

# Geometry (design px, scaled to the viewport).
const OUTER_RADIUS := 300.0
const INNER_RADIUS := 146.0
const HOVER_POP := 16.0           # how far the hovered wedge expands outward
const WEDGE_GAP_RAD := 0.022      # gap between wedges (radians)
const DEADZONE := 0.46            # fraction of INNER below which nothing is hovered
const HOVER_ANIM_SPEED := 13.0    # pop/brighten easing speed

# Palette — dark glass with a warm amber accent (elegant, matches the mock).
const SCRIM_COLOR := Color(0.02, 0.03, 0.04, 0.55)
const WEDGE_IDLE := Color(0.09, 0.11, 0.14, 0.82)
const WEDGE_HOVER := Color(0.24, 0.16, 0.06, 0.96)
const WEDGE_DISABLED := Color(0.06, 0.07, 0.08, 0.70)
const RIM_IDLE := Color(0.52, 0.60, 0.70, 0.18)
const RIM_HOVER := Color(1.0, 0.72, 0.28, 0.98)
const HUB_COLOR := Color(0.03, 0.04, 0.055, 0.94)
const HUB_RIM := Color(0.45, 0.55, 0.66, 0.30)
const ACCENT := Color(1.0, 0.68, 0.22, 1.0)
const ICON_IDLE := Color(0.80, 0.85, 0.90, 0.92)
const LABEL_IDLE := Color(0.78, 0.83, 0.89, 0.92)
const TITLE_COLOR := Color(0.66, 0.74, 0.84, 0.85)

var _options: Array = []      # [{label:String, icon:Texture2D=null, enabled:bool}]
var _title := ""
var _footer := ""
var _hover := -1
var _preselect := -1
var _enable_keys := true
var _pop: PackedFloat32Array = PackedFloat32Array()   # per-wedge eased hover amount
var _title_font: Font = null
var _label_font: Font = null
var _hover_sound: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_font = _load_font(FONT_TITLE)
	_label_font = _load_font(FONT_LABEL)
	_ensure_hover_sound()
	set_process(false)
	visible = false


func open(options: Array, title: String, preselect: int = -1, enable_keys: bool = true) -> void:
	_options = options
	_title = title
	_preselect = preselect
	_hover = preselect
	_enable_keys = enable_keys
	_pop = PackedFloat32Array()
	_pop.resize(_options.size())
	visible = true
	add_to_group("active_radial_wheel")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := size * 0.5
	if center.x > 1.0:
		warp_mouse(center)
	set_process(true)
	queue_redraw()


func close() -> void:
	visible = false
	set_process(false)
	if is_inside_tree():
		remove_from_group("active_radial_wheel")
	queue_redraw()


func is_open() -> bool:
	return visible


# Pick the wedge the cursor is currently aiming at (used on key release), or
# cancel if the cursor is in the dead-zone / on a disabled wedge.
func select_hovered() -> void:
	if has_hovered_option():
		option_chosen.emit(_hover)
	else:
		cancelled.emit()


# True when the cursor is aiming at a real, selectable wedge (not the dead-zone).
func has_hovered_option() -> bool:
	return _hover >= 0 and _hover < _options.size() and bool((_options[_hover] as Dictionary).get("enabled", true))


func set_footer(text: String) -> void:
	if text == _footer:
		return
	_footer = text
	if visible:
		queue_redraw()


func _process(delta: float) -> void:
	var dirty := false
	var amount := clampf(delta * HOVER_ANIM_SPEED, 0.0, 1.0)
	for i in range(_pop.size()):
		var target := 1.0 if i == _hover else 0.0
		var next := lerpf(_pop[i], target, amount)
		if absf(next - target) < 0.004:
			next = target
		if next != _pop[i]:
			_pop[i] = next
			dirty = true
	if dirty:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_update_hover(mb.position)
			_confirm()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()
			accept_event()


func _input(event: InputEvent) -> void:
	if not visible or not _enable_keys:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			cancelled.emit()
			get_viewport().set_input_as_handled()
			return
		var number := key.keycode - KEY_1
		if number >= 0 and number < _options.size():
			_hover = number
			_confirm()
			get_viewport().set_input_as_handled()


func _update_hover(pos: Vector2) -> void:
	var hud_scale := _scale()
	var center := size * 0.5
	var v := pos - center
	var dist := v.length()
	var new_hover := -1
	if dist >= INNER_RADIUS * hud_scale * DEADZONE and not _options.is_empty():
		new_hover = _angle_to_index(atan2(v.y, v.x))
	if new_hover != _hover:
		# Soft tick only when landing on a fresh, real wedge.
		if new_hover >= 0 and bool((_options[new_hover] as Dictionary).get("enabled", true)):
			_play_hover_sound()
		_hover = new_hover
		queue_redraw()


func _angle_to_index(ang: float) -> int:
	var count := _options.size()
	var step := TAU / float(count)
	var idx := int(round((ang + PI * 0.5) / step))
	return ((idx % count) + count) % count


func _confirm() -> void:
	if _hover < 0 or _hover >= _options.size():
		return
	if not bool((_options[_hover] as Dictionary).get("enabled", true)):
		return
	option_chosen.emit(_hover)


func _draw() -> void:
	if _options.is_empty():
		return
	var hud_scale := _scale()
	var center := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), SCRIM_COLOR)

	var count := _options.size()
	var step := TAU / float(count)
	var inner := INNER_RADIUS * hud_scale
	var outer := OUTER_RADIUS * hud_scale

	for i in range(count):
		var opt := _options[i] as Dictionary
		var enabled := bool(opt.get("enabled", true))
		var pop := _pop[i] if i < _pop.size() else 0.0
		var mid := -PI * 0.5 + step * float(i)
		var a0 := mid - step * 0.5 + WEDGE_GAP_RAD
		var a1 := mid + step * 0.5 - WEDGE_GAP_RAD
		var r_out := outer + HOVER_POP * hud_scale * pop
		var fill := WEDGE_DISABLED if not enabled else WEDGE_IDLE.lerp(WEDGE_HOVER, pop)
		var pts := _annulus_points(a0, a1, inner, r_out, center)
		draw_colored_polygon(pts, fill)
		var rim := RIM_IDLE.lerp(RIM_HOVER, pop) if enabled else RIM_IDLE
		_draw_arc_line(a0, a1, r_out, center, rim, lerpf(1.5, 2.6, pop) * hud_scale)
		_draw_wedge_content(opt, mid, inner, r_out, hud_scale, pop, enabled)

	draw_circle(center, inner - 6.0 * hud_scale, HUB_COLOR)
	_draw_ring(center, inner - 6.0 * hud_scale, HUB_RIM, 2.0 * hud_scale)
	_draw_hub_text(center, hud_scale)


func _draw_wedge_content(opt: Dictionary, mid: float, inner: float, r_out: float, hud_scale: float, pop: float, enabled: bool) -> void:
	var radius := (inner + r_out) * 0.5
	var pos := size * 0.5 + Vector2(cos(mid), sin(mid)) * radius
	var icon := opt.get("icon") as Texture2D
	var content_color := ICON_IDLE.lerp(ACCENT, pop)
	if not enabled:
		content_color.a = 0.4
	if icon:
		var icon_size := 64.0 * hud_scale * lerpf(1.0, 1.14, pop)
		draw_texture_rect(icon, Rect2(pos - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, content_color)
	else:
		var font := _get_label_font()
		var fsize := _scaled(int(round(lerpf(20.0, 23.0, pop))), hud_scale)
		var text := str(opt.get("label", ""))
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fsize)
		var label_color := LABEL_IDLE.lerp(ACCENT, pop)
		if not enabled:
			label_color.a = 0.4
		var baseline := pos + Vector2(-text_size.x * 0.5, text_size.y * 0.32)
		draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0.0, 0.0, 0.0, 0.6))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, label_color)


func _draw_hub_text(center: Vector2, hud_scale: float) -> void:
	var title_font := _get_title_font()
	var label_font := _get_label_font()
	draw_string(title_font, center + Vector2(-160.0 * hud_scale, -10.0 * hud_scale), _title, HORIZONTAL_ALIGNMENT_CENTER, 320.0 * hud_scale, _scaled(20, hud_scale), TITLE_COLOR)
	var hover_text := ""
	if _hover >= 0 and _hover < _options.size():
		hover_text = str((_options[_hover] as Dictionary).get("label", ""))
	if not hover_text.is_empty():
		draw_string(label_font, center + Vector2(-160.0 * hud_scale, 26.0 * hud_scale), hover_text, HORIZONTAL_ALIGNMENT_CENTER, 320.0 * hud_scale, _scaled(30, hud_scale), Color(0.97, 0.98, 1.0, 0.98))
	if not _footer.is_empty():
		draw_string(label_font, center + Vector2(-160.0 * hud_scale, 58.0 * hud_scale), _footer, HORIZONTAL_ALIGNMENT_CENTER, 320.0 * hud_scale, _scaled(16, hud_scale), Color(0.62, 0.70, 0.80, 0.85))


func _annulus_points(a0: float, a1: float, r_in: float, r_out: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(2, int((a1 - a0) / 0.10))
	for s in range(steps + 1):
		var a := lerpf(a0, a1, float(s) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * r_out)
	for s in range(steps + 1):
		var a := lerpf(a1, a0, float(s) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * r_in)
	return pts


func _draw_arc_line(a0: float, a1: float, radius: float, center: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps := maxi(2, int((a1 - a0) / 0.10))
	for s in range(steps + 1):
		var a := lerpf(a0, a1, float(s) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for s in range(49):
		var a := TAU * float(s) / 48.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)


func _ensure_hover_sound() -> void:
	_hover_sound = AudioStreamPlayer.new()
	_hover_sound.name = "WheelHoverSound"
	_hover_sound.bus = &"Master"
	_hover_sound.volume_db = -13.0
	_hover_sound.max_polyphony = 4
	var stream := load(HOVER_SOUND_PATH)
	if stream is AudioStream:
		_hover_sound.stream = stream
	add_child(_hover_sound)


func _play_hover_sound() -> void:
	if not _hover_sound or not _hover_sound.stream:
		return
	_hover_sound.pitch_scale = randf_range(1.04, 1.16)
	_hover_sound.play()


func _scale() -> float:
	var vp := size if size.x > 1.0 else get_viewport_rect().size
	return clampf(minf(vp.x / BASE_VIEWPORT.x, vp.y / BASE_VIEWPORT.y), 0.6, 1.45)


func _scaled(base_size: int, hud_scale: float) -> int:
	return maxi(8, int(round(float(base_size) * hud_scale)))


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_label_font() -> Font:
	return _label_font if _label_font else _get_title_font()
