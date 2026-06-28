extends Control
class_name WorldNameplateHUD

## Screen-space overhead UI for every player: the redesigned nameplate (small,
## semi-transparent sky-blue name with a bounty marker and/or low-health icon
## left-aligned after it) plus the temporary "you damaged this enemy" HP bar.
##
## Data is pushed each frame by Level via render(): it owns the per-player facts
## (head position, name, team relation, bounty, health ratio, name visibility)
## while this node owns projection, layout and the 10s enemy-reveal timers. The
## node also joins the "world_nameplate_hud" group so player damage RPCs can call
## register_enemy_reveal() on it directly.
##
## Pure _draw() based (no child nodes); never instantiated on the headless server.

const FONT_PATH := "res://assets/fonts/SairaCondensed-Light.woff2"
const BOUNTY_ICON_PATH := "res://resources/ui/icons/bounty.svg"
const LOW_HEALTH_ICON_PATH := "res://resources/ui/icons/low_health.svg"
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)

# Distance falloff so far players read smaller; clamped so they never vanish or
# dominate the screen.
const REFERENCE_DISTANCE := 11.0
const MIN_DISTANCE_SCALE := 0.55
const MAX_DISTANCE_SCALE := 1.25

const NAME_FONT_SIZE := 14
const ICON_GAP := 4.0          # gap between name and first icon, and between icons
const ROW_LIFT := 4.0          # nudge the name row above the projected anchor
const LOW_HEALTH_RATIO := 0.20

# Enemy reveal HP bar (screenshot 1): compact segmented strip with the name below.
const REVEAL_SECONDS := 10.0
const REVEAL_SEGMENTS := 10
const REVEAL_SEG_SIZE := Vector2(11.0, 12.0)
const REVEAL_SEG_GAP := 2.0
const REVEAL_SEG_CORNER := 2.0
const REVEAL_NAME_FONT_SIZE := 16

const NAME_COLOR := Color(0.58, 0.81, 1.0, 0.80)        # semi-transparent sky blue
const NAME_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const BOUNTY_COLOR := Color(1.0, 0.84, 0.26, 0.96)      # theme yellow
const LOW_HEALTH_COLOR := Color(0.90, 0.20, 0.20, 0.98) # blood red
const REVEAL_FILLED := Color(0.95, 0.96, 0.97, 0.98)
const REVEAL_EMPTY := Color(0.16, 0.18, 0.21, 0.85)
const REVEAL_NAME_COLOR := Color(0.96, 0.97, 1.0, 0.95)

var _entries: Array = []
var _camera: Camera3D = null
var _reveals: Dictionary = {}   # peer_id -> expire msec
var _now_msec := 0
var _name_font: Font = null
var _bounty_icon: Texture2D = null
var _low_health_icon: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	add_to_group("world_nameplate_hud")
	_name_font = _load_font(FONT_PATH)
	_bounty_icon = _load_icon(BOUNTY_ICON_PATH)
	_low_health_icon = _load_icon(LOW_HEALTH_ICON_PATH)
	visible = false


# Pushed by Level every frame with the current player snapshot + active camera.
# Each entry: {pos: Vector3, name: String, name_visible: bool, is_self: bool,
#   is_ally: bool, bountied: bool, ratio: float, peer: int}
func render(entries: Array, camera: Camera3D) -> void:
	_entries = entries
	_camera = camera
	visible = not entries.is_empty() and camera != null
	queue_redraw()


func clear() -> void:
	_entries = []
	_reveals.clear()
	visible = false
	queue_redraw()


# Called via the "world_nameplate_hud" group from a player's damage RPC on the
# attacker's client; briefly reveals that enemy's HP bar.
func register_enemy_reveal(peer_id: int, _ratio: float) -> void:
	_reveals[peer_id] = Time.get_ticks_msec() + int(REVEAL_SECONDS * 1000.0)


func _draw() -> void:
	if _camera == null or not is_instance_valid(_camera) or _entries.is_empty():
		return
	_now_msec = Time.get_ticks_msec()
	var res_scale := _get_resolution_scale()
	var show_plates := _show_nameplates()
	var cam_pos := _camera.global_position
	for entry in _entries:
		var world_pos: Vector3 = entry.get("pos", Vector3.ZERO)
		if _camera.is_position_behind(world_pos):
			continue
		var screen := _camera.unproject_position(world_pos)
		var dist := cam_pos.distance_to(world_pos)
		var scale := res_scale * clampf(REFERENCE_DISTANCE / maxf(dist, 1.0), MIN_DISTANCE_SCALE, MAX_DISTANCE_SCALE)
		var peer := int(entry.get("peer", 0))
		var is_self := bool(entry.get("is_self", false))
		var is_ally := bool(entry.get("is_ally", false))
		var revealed := not is_self and not is_ally and _reveals.has(peer) and _now_msec < int(_reveals[peer])
		if revealed:
			_draw_enemy_reveal(screen, str(entry.get("name", "")), float(entry.get("ratio", 0.0)), scale)
		if show_plates and bool(entry.get("name_visible", false)):
			_draw_nameplate(screen, entry, is_self, is_ally, scale)


func _draw_nameplate(screen: Vector2, entry: Dictionary, is_self: bool, is_ally: bool, scale: float) -> void:
	var font := _get_name_font()
	var name_size := _scaled(NAME_FONT_SIZE, scale)
	var text := str(entry.get("name", ""))
	var ascent := font.get_ascent(name_size)
	# Left-aligned row anchored at the projected head x, lifted just above it.
	var origin := Vector2(screen.x, screen.y - ROW_LIFT * scale)
	draw_string(font, origin + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, NAME_SHADOW)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, NAME_COLOR)

	# Icons trail the name on the same line: bounty first, then low-health.
	var icon_size := float(name_size)
	var cursor_x := origin.x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x + ICON_GAP * scale
	var icon_top := origin.y - ascent + (ascent - icon_size) * 0.5
	if bool(entry.get("bountied", false)) and _get_bounty_icon():
		draw_texture_rect(_get_bounty_icon(), Rect2(Vector2(cursor_x, icon_top), Vector2(icon_size, icon_size)), false, BOUNTY_COLOR)
		cursor_x += icon_size + ICON_GAP * scale
	# Low-health icon only for self / allies; enemy health is never exposed here.
	var ratio := float(entry.get("ratio", 1.0))
	if (is_self or is_ally) and ratio > 0.0 and ratio < LOW_HEALTH_RATIO and _get_low_health_icon():
		draw_texture_rect(_get_low_health_icon(), Rect2(Vector2(cursor_x, icon_top), Vector2(icon_size, icon_size)), false, LOW_HEALTH_COLOR)


func _draw_enemy_reveal(screen: Vector2, enemy_name: String, ratio: float, scale: float) -> void:
	var seg := REVEAL_SEG_SIZE * scale
	var gap := REVEAL_SEG_GAP * scale
	var total_width := float(REVEAL_SEGMENTS) * seg.x + float(REVEAL_SEGMENTS - 1) * gap
	# Bar centered horizontally over the head, sitting at the anchor height.
	var bar_left := screen.x - total_width * 0.5
	var bar_top := screen.y - seg.y
	var style := StyleBoxFlat.new()
	style.set_border_width_all(0)
	style.set_corner_radius_all(int(round(REVEAL_SEG_CORNER * scale)))
	var fill_units := clampf(ratio, 0.0, 1.0) * float(REVEAL_SEGMENTS)
	for i in range(REVEAL_SEGMENTS):
		var cell_fill := clampf(fill_units - float(i), 0.0, 1.0)
		style.bg_color = REVEAL_EMPTY.lerp(REVEAL_FILLED, cell_fill)
		draw_style_box(style, Rect2(Vector2(bar_left + float(i) * (seg.x + gap), bar_top), seg))
	# Enemy name below the bar (screenshot 1), centered under it.
	var font := _get_name_font()
	var name_size := _scaled(REVEAL_NAME_FONT_SIZE, scale)
	var name_width := font.get_string_size(enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x
	var name_pos := Vector2(screen.x - name_width * 0.5, bar_top + seg.y + name_size + 2.0 * scale)
	draw_string(font, name_pos + Vector2(1.0, 1.0), enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, NAME_SHADOW)
	draw_string(font, name_pos, enemy_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, REVEAL_NAME_COLOR)


func _get_resolution_scale() -> float:
	var vp := get_viewport_rect().size
	return clampf(minf(vp.x / BASE_VIEWPORT.x, vp.y / BASE_VIEWPORT.y), 0.7, 1.6)


func _scaled(base_size: int, scale: float) -> int:
	return maxi(8, int(round(float(base_size) * scale)))


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null


# Player-facing toggle (Settings > General). Defaults to on if GameSettings is
# unavailable (e.g. isolated test scenes).
func _show_nameplates() -> bool:
	var gs := get_node_or_null("/root/GameSettings")
	if gs and "show_player_nameplates" in gs:
		return bool(gs.show_player_nameplates)
	return true


func _load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource if resource is Texture2D else null


func _get_name_font() -> Font:
	if not _name_font:
		_name_font = _load_font(FONT_PATH)
	return _name_font if _name_font else ThemeDB.fallback_font


# Icons are lazily retried in case they were imported after _ready().
func _get_bounty_icon() -> Texture2D:
	if not _bounty_icon:
		_bounty_icon = _load_icon(BOUNTY_ICON_PATH)
	return _bounty_icon


func _get_low_health_icon() -> Texture2D:
	if not _low_health_icon:
		_low_health_icon = _load_icon(LOW_HEALTH_ICON_PATH)
	return _low_health_icon
