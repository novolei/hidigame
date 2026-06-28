extends Control
class_name PlayerHealthHUD

## Bottom-left HP readout for the local player, styled after the in-game mock:
## a tight row of rounded segments with the current/max number above and the
## player's name below, the whole block tilted slightly up-to-the-right to echo
## the loadout cards (技能卡) sitting above it. Hunters carry 250 HP, props
## (Chameleon / Stalker) 200 HP; the strip is always 10 segments so both roles
## read the same length and only the number differs.
##
## Below 20% the bar enters a "critical" state: a one-shot red shockwave ring
## bursts outward, then the strip keeps trembling with a red afterimage so the
## player feels the danger in their peripheral vision.
##
## Pure _draw() based (no child nodes) so it costs nothing on the headless
## dedicated server, which never instantiates this HUD. Authority lives on the
## player; this view only renders values pushed in via set_health().

const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)

# Left anchor in design pixels (matches CardHUD.MARGIN.x so the bar lines up with
# the loadout column). BOTTOM_MARGIN is the gap from the screen bottom to the
# name line; the segment baseline sits one NAME_BLOCK above that.
const MARGIN_X := 28.0
const BOTTOM_MARGIN := 16.0

# Segment strip geometry (design pixels, scaled at draw time). Borderless and
# tight per the mock.
const SEGMENTS := 10
const SEG_SIZE := Vector2(24.0, 24.0)
const SEG_GAP := 3.0
const SEG_CORNER := 5.0

# Text blocks above (number) and below (name) the strip.
const CUR_FONT_SIZE := 22
const MAX_FONT_SIZE := 14
const NAME_FONT_SIZE := 17
const LABEL_GAP := 5.0
const NAME_GAP := 7.0

# Upward-right tilt. The loadout card row climbs at atan(14/81) ≈ 9.8°; the user
# wants the bar noticeably flatter, so we drop ~5° from that.
const HEALTH_SLANT_DEGREES := 4.8

# Scale mirrors CardHUD._get_slot_scale so HUD elements share one footprint.
const BASE_HUD_SCALE := 1.35
const MIN_HUD_SCALE := 0.82
const MAX_HUD_SCALE := 1.65

# Drain animation: constant ~0.32s slide regardless of role pool size.
const DRAIN_SECONDS := 0.32

# Critical-health feedback.
const LOW_HEALTH_RATIO := 0.20
const SHOCKWAVE_SECONDS := 0.55
const SHOCKWAVE_GROW := 16.0       # design px the ring expands outward
const TREMOR_AMPLITUDE := 2.2      # design px of bar jitter while critical
const LOW_HEALTH_FX_SECONDS := 5.0 # shockwave + tremor play this long, then settle

const FILLED_COLOR := Color(0.95, 0.96, 0.97, 0.98)
const EMPTY_COLOR := Color(0.17, 0.19, 0.22, 0.82)
const DAMAGE_TINT := Color(0.82, 0.28, 0.28, 1.0)
const LOW_HEALTH_COLOR := Color(0.88, 0.18, 0.18, 1.0)

var _max_health := 0.0
var _target_health := 0.0
var _display_health := 0.0
var _player_name := ""
var _has_data := false
var _damage_flash := 0.0
var _low_health := false
var _shockwave := 0.0
var _tremor_phase := 0.0
var _low_health_fx_remaining := 0.0
var _title_font: Font = null
var _value_font: Font = null
var _seg_style: StyleBoxFlat = null
var _wave_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_title_font = _load_font(FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)
	_seg_style = StyleBoxFlat.new()
	_seg_style.set_border_width_all(0)
	# Outline-only box used for the expanding shockwave ring.
	_wave_style = StyleBoxFlat.new()
	_wave_style.draw_center = false
	_wave_style.set_border_width_all(2)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	set_process(false)
	visible = false


# Push the latest authoritative values. max <= 0 hides the bar (spectator / no
# combat role). The displayed value eases toward the target so a hit drains the
# strip from the right instead of snapping.
func set_health(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		clear()
		return
	var was_data := _has_data
	_max_health = maximum
	var clamped := clampf(current, 0.0, maximum)
	if was_data and clamped < _target_health - 0.01:
		_damage_flash = 1.0
	_target_health = clamped
	if not was_data:
		_display_health = clamped
	_has_data = true
	visible = true
	set_process(true)
	queue_redraw()


func set_player_name(value: String) -> void:
	if value == _player_name:
		return
	_player_name = value
	queue_redraw()


func clear() -> void:
	_has_data = false
	_max_health = 0.0
	_target_health = 0.0
	_display_health = 0.0
	_damage_flash = 0.0
	_low_health = false
	_shockwave = 0.0
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var dirty := false
	if not is_equal_approx(_display_health, _target_health):
		var speed := maxf(_max_health, 1.0) / DRAIN_SECONDS
		_display_health = move_toward(_display_health, _target_health, speed * delta)
		dirty = true
	if _damage_flash > 0.0:
		_damage_flash = maxf(0.0, _damage_flash - delta / 0.45)
		dirty = true
	# Critical-health detection runs off the displayed value so the shockwave
	# fires exactly when the draining bar crosses 20%.
	var ratio := _display_health / _max_health if _max_health > 0.0 else 0.0
	var low := ratio > 0.0 and ratio < LOW_HEALTH_RATIO
	if low and not _low_health:
		# Entering critical: kick off a one-shot 5s shockwave + tremor burst.
		_shockwave = 1.0
		_low_health_fx_remaining = LOW_HEALTH_FX_SECONDS
	_low_health = low
	if not low:
		_low_health_fx_remaining = 0.0
	if _shockwave > 0.0:
		_shockwave = maxf(0.0, _shockwave - delta / SHOCKWAVE_SECONDS)
		dirty = true
	if _low_health_fx_remaining > 0.0:
		# Active burst window: keep trembling and redrawing.
		_low_health_fx_remaining = maxf(0.0, _low_health_fx_remaining - delta)
		_tremor_phase += delta
		dirty = true
	if dirty:
		queue_redraw()
	else:
		set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if not _has_data or _max_health <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	var hud_scale := _get_hud_scale(viewport_size)
	var seg := SEG_SIZE * hud_scale
	var gap := SEG_GAP * hud_scale
	var total_width := float(SEGMENTS) * seg.x + float(SEGMENTS - 1) * gap

	# Reserve a name block below the strip so the whole readout clears the screen
	# bottom edge, then rotate the block (number + strip + name) as one unit.
	var name_block := (NAME_GAP + float(NAME_FONT_SIZE) + 6.0) * hud_scale
	var base_origin := Vector2(MARGIN_X * hud_scale, viewport_size.y - BOTTOM_MARGIN * hud_scale - name_block)
	var angle := -deg_to_rad(HEALTH_SLANT_DEGREES)

	# Tremor + trailing red afterimage only during the 5s burst; afterwards the
	# bar settles to a steady (non-animating) red tint so it isn't perpetually moving.
	var fx_active := _low_health and _low_health_fx_remaining > 0.0
	var shake := Vector2.ZERO
	if fx_active:
		var amp := TREMOR_AMPLITUDE * hud_scale
		shake = Vector2(sin(_tremor_phase * 41.0), sin(_tremor_phase * 53.0 + 1.7)) * amp
		draw_set_transform(base_origin - shake * 1.6, angle, Vector2.ONE)
		_draw_segments(seg, gap, hud_scale, 0.32, 1.0)

	draw_set_transform(base_origin + shake, angle, Vector2.ONE)
	var red_amount := 0.0
	if _low_health:
		red_amount = (0.55 + 0.25 * (0.5 + 0.5 * sin(_tremor_phase * 9.0))) if fx_active else 0.62
	_draw_segments(seg, gap, hud_scale, 1.0, red_amount)
	_draw_number(seg, hud_scale)
	_draw_name(hud_scale)
	if _shockwave > 0.0:
		_draw_shockwave(seg, total_width, hud_scale)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_segments(seg: Vector2, gap: float, hud_scale: float, alpha_mul: float, red_amount: float) -> void:
	var ratio := clampf(_display_health / _max_health, 0.0, 1.0)
	var fill_units := ratio * float(SEGMENTS)
	_seg_style.set_corner_radius_all(int(round(SEG_CORNER * hud_scale)))
	# Segments sit above the baseline (local y in [-seg.y, 0]).
	for i in range(SEGMENTS):
		var cell_rect := Rect2(Vector2(float(i) * (seg.x + gap), -seg.y), seg)
		var cell_fill := clampf(fill_units - float(i), 0.0, 1.0)
		var fill_color := EMPTY_COLOR.lerp(FILLED_COLOR, cell_fill)
		if _damage_flash > 0.0 and cell_fill > 0.0:
			fill_color = fill_color.lerp(DAMAGE_TINT, _damage_flash * 0.5)
		if red_amount > 0.0 and cell_fill > 0.0:
			fill_color = fill_color.lerp(LOW_HEALTH_COLOR, red_amount * cell_fill)
		fill_color.a *= alpha_mul
		_seg_style.bg_color = fill_color
		draw_style_box(_seg_style, cell_rect)


func _draw_shockwave(seg: Vector2, total_width: float, hud_scale: float) -> void:
	var grow := (1.0 - _shockwave) * SHOCKWAVE_GROW * hud_scale
	var ring := Rect2(Vector2(0.0, -seg.y), Vector2(total_width, seg.y)).grow(grow)
	_wave_style.set_corner_radius_all(int(round((SEG_CORNER + grow) * 0.6)))
	_wave_style.set_border_width_all(maxi(1, int(round(2.0 * hud_scale))))
	_wave_style.border_color = Color(LOW_HEALTH_COLOR.r, LOW_HEALTH_COLOR.g, LOW_HEALTH_COLOR.b, _shockwave)
	draw_style_box(_wave_style, ring)


func _draw_number(seg: Vector2, hud_scale: float) -> void:
	var font := _get_value_font()
	var cur_size := _scaled_font_size(CUR_FONT_SIZE, hud_scale)
	var max_size := _scaled_font_size(MAX_FONT_SIZE, hud_scale)
	var cur_text := str(int(round(_display_health)))
	var max_text := " /%d" % int(round(_max_health))
	# Baseline just above the strip, left-aligned with segment 0.
	var baseline := Vector2(0.0, -seg.y - LABEL_GAP * hud_scale)
	var cur_color := Color(0.97, 0.98, 1.0, 0.98)
	if _low_health:
		cur_color = cur_color.lerp(LOW_HEALTH_COLOR, 0.6)
	if _damage_flash > 0.0:
		cur_color = cur_color.lerp(DAMAGE_TINT, _damage_flash * 0.7)
	draw_string(font, baseline + Vector2(1.5, 1.5), cur_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, cur_size, Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, baseline, cur_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, cur_size, cur_color)
	var cur_width := font.get_string_size(cur_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, cur_size).x
	var max_pos := baseline + Vector2(cur_width, 0.0)
	draw_string(font, max_pos, max_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, max_size, Color(0.74, 0.78, 0.82, 0.82))


func _draw_name(hud_scale: float) -> void:
	if _player_name.is_empty():
		return
	var font := _get_title_font()
	var name_size := _scaled_font_size(NAME_FONT_SIZE, hud_scale)
	# Baseline just below the strip, left-aligned with segment 0.
	var baseline := Vector2(0.0, NAME_GAP * hud_scale + float(name_size))
	draw_string(font, baseline + Vector2(1.5, 1.5), _player_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, baseline, _player_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, Color(0.95, 0.97, 1.0, 0.95))


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


func _get_hud_scale(viewport_size: Vector2) -> float:
	var resolution_scale := BASE_HUD_SCALE * minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	return clampf(resolution_scale, MIN_HUD_SCALE, MAX_HUD_SCALE)


func _scaled_font_size(base_size: int, hud_scale: float) -> int:
	return maxi(8, int(round(float(base_size) * hud_scale)))


func _get_title_font() -> Font:
	return _title_font if _title_font else ThemeDB.fallback_font


func _get_value_font() -> Font:
	return _value_font if _value_font else _get_title_font()


func _on_viewport_size_changed() -> void:
	queue_redraw()
