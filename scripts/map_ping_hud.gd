extends Control
class_name MapPingHUD

## Screen-space world pings (middle-click). Each ping projects a world point to
## the screen and draws a floating amber "!" disc with the distance and a beam
## down to the ground point, fading out after a few seconds. Team-filtered at the
## network layer (player._map_ping); this node just renders whatever it's given.
##
## Pure _draw() based; joins the "map_ping_hud" group so player ping RPCs can call
## register_ping() on it.

const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const PING_SOUND_PATH := "res://assets/audio/ui/ui_confirm_click.mp3"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const PING_SECONDS := 7.0
const FADE_SECONDS := 0.8
const MAX_PINGS := 12
const MARKER_LIFT := 1.7              # metres the disc floats above the ground point
const ACCENT := Color(1.0, 0.82, 0.30, 1.0)
const BEAM_COLOR := Color(1.0, 0.82, 0.30, 0.55)
const DISC_BG := Color(0.05, 0.06, 0.08, 0.72)

var _pings: Array = []   # [{pos: Vector3, expire: int}]
var _font: Font = null
var _sound: AudioStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	add_to_group("map_ping_hud")
	var resource := load(FONT_PATH)
	_font = resource if resource is Font else null
	_sound = AudioStreamPlayer.new()
	_sound.name = "PingSound"
	_sound.bus = &"Master"
	_sound.volume_db = -8.0
	_sound.max_polyphony = 3
	var stream := load(PING_SOUND_PATH)
	if stream is AudioStream:
		_sound.stream = stream
	add_child(_sound)
	set_process(false)
	visible = false


func register_ping(world_pos: Vector3) -> void:
	_pings.append({"pos": world_pos, "expire": Time.get_ticks_msec() + int(PING_SECONDS * 1000.0)})
	if _pings.size() > MAX_PINGS:
		_pings.pop_front()
	if _sound and _sound.stream:
		_sound.pitch_scale = randf_range(1.0, 1.08)
		_sound.play()
	visible = true
	set_process(true)
	queue_redraw()


func clear() -> void:
	_pings.clear()
	visible = false
	set_process(false)
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for i in range(_pings.size() - 1, -1, -1):
		if now >= int((_pings[i] as Dictionary).get("expire", 0)):
			_pings.remove_at(i)
	if _pings.is_empty():
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _pings.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var hud_scale := clampf(minf(size.x / BASE_VIEWPORT.x, size.y / BASE_VIEWPORT.y), 0.6, 1.4)
	var now := Time.get_ticks_msec()
	var cam_pos := camera.global_position
	for entry in _pings:
		var ground: Vector3 = (entry as Dictionary).get("pos", Vector3.ZERO)
		if camera.is_position_behind(ground):
			continue
		var top := ground + Vector3.UP * MARKER_LIFT
		var screen_top := camera.unproject_position(top)
		var screen_ground := camera.unproject_position(ground)
		var remaining := float(int((entry as Dictionary).get("expire", 0)) - now) / 1000.0
		var fade := clampf(remaining / FADE_SECONDS, 0.0, 1.0)
		var col := ACCENT
		col.a *= fade
		var beam := BEAM_COLOR
		beam.a *= fade
		draw_line(screen_top, screen_ground, beam, maxf(1.5, 2.0 * hud_scale), true)
		var radius := 16.0 * hud_scale
		draw_circle(screen_top, radius, Color(DISC_BG.r, DISC_BG.g, DISC_BG.b, DISC_BG.a * fade))
		_draw_ring(screen_top, radius, col, maxf(1.5, 2.5 * hud_scale))
		var font := _font if _font else ThemeDB.fallback_font
		var mark_size := maxi(10, int(round(22.0 * hud_scale)))
		var mark_w := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, mark_size).x
		draw_string(font, screen_top + Vector2(-mark_w * 0.5, mark_size * 0.36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, mark_size, col)
		var dist_text := "%.1fm" % cam_pos.distance_to(ground)
		var dist_size := maxi(8, int(round(15.0 * hud_scale)))
		var dpos := screen_top + Vector2(-60.0 * hud_scale, -radius - 6.0 * hud_scale)
		draw_string(font, dpos + Vector2(1.0, 1.0), dist_text, HORIZONTAL_ALIGNMENT_CENTER, 120.0 * hud_scale, dist_size, Color(0.0, 0.0, 0.0, 0.5 * fade))
		draw_string(font, dpos, dist_text, HORIZONTAL_ALIGNMENT_CENTER, 120.0 * hud_scale, dist_size, col)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for s in range(33):
		var a := TAU * float(s) / 32.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)
