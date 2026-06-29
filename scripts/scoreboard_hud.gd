class_name ScoreboardHUD
extends Control
# =============================================================================
# ScoreboardHUD — full-screen Tab scoreboard.
#
# Held-Tab overlay listing every player grouped into the two teams (Hunters vs
# Props), with E/A/D/R counters and the COMBAT/SUPPORT/OBJECTIVE point buckets.
# Pure _draw() (no child nodes) so the headless server never pays for it. Roster
# comes from Network.players; stats come from a snapshot the level syncs from the
# server-side MatchScoreTracker.
# =============================================================================

const FONT_BOLD := "res://assets/fonts/SairaCondensed-Bold.woff2"
const FONT_VALUE := "res://assets/fonts/Saira-9.woff2"

# Numeric column headers + their right-edge x as a fraction of the content width.
const COLUMNS := [
	{"label": "E", "x": 0.42},
	{"label": "A", "x": 0.49},
	{"label": "D", "x": 0.56},
	{"label": "R", "x": 0.63},
	{"label": "COMBAT", "x": 0.76},
	{"label": "SUPPORT", "x": 0.88},
	{"label": "OBJECTIVE", "x": 1.0},
]

const HUNTER_COLOR := Color(1.0, 0.42, 0.40, 1.0)
const PROP_COLOR := Color(0.45, 0.78, 1.0, 1.0)
const SPECTATOR_COLOR := Color(0.7, 0.72, 0.8, 1.0)

var _snapshot: Dictionary = {}   # peer_id -> [pid, E, A, D, R, COMBAT, SUPPORT, OBJECTIVE]
var _font_bold: Font = null
var _font_value: Font = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_bold = _load_font(FONT_BOLD)
	_font_value = _load_font(FONT_VALUE)
	visible = false


# snapshot: peer_id -> packed row (see MatchScoreTracker.snapshot_rows()).
func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if visible:
		queue_redraw()


func show_board() -> void:
	visible = true
	queue_redraw()


func hide_board() -> void:
	visible = false


func _draw() -> void:
	var vp := size
	if vp.x < 4.0:
		vp = get_viewport_rect().size
	# Dim backdrop.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.03, 0.62), true)

	var panel_w: float = minf(vp.x * 0.82, 1180.0)
	var panel_x := (vp.x - panel_w) * 0.5
	var content_left := panel_x + 26.0
	var content_w := panel_w - 52.0
	var y := vp.y * 0.12

	var title_size := _scaled(34, vp)
	draw_string(_font_bold, Vector2(content_left, y), "SCOREBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.95, 0.97, 1.0, 0.96))
	y += 14.0
	# Column headers.
	var header_size := _scaled(18, vp)
	for column in COLUMNS:
		var cx := content_left + content_w * float(column["x"])
		draw_string(_font_bold, Vector2(cx - 150.0, y + header_size), str(column["label"]), HORIZONTAL_ALIGNMENT_RIGHT, 150.0, header_size, Color(0.78, 0.84, 0.95, 0.85))
	y += header_size + 10.0
	draw_rect(Rect2(Vector2(content_left, y), Vector2(content_w, 2.0)), Color(1.0, 1.0, 1.0, 0.14), true)
	y += 12.0

	var teams := _grouped_players()
	y = _draw_team(content_left, content_w, y, vp, "HUNTERS  ·  猎人", HUNTER_COLOR, teams["hunters"])
	y += 14.0
	y = _draw_team(content_left, content_w, y, vp, "PROPS  ·  伪装者", PROP_COLOR, teams["props"])
	if not (teams["spectators"] as Array).is_empty():
		y += 14.0
		y = _draw_team(content_left, content_w, y, vp, "SPECTATORS", SPECTATOR_COLOR, teams["spectators"])


func _draw_team(content_left: float, content_w: float, y: float, vp: Vector2, team_label: String, accent: Color, rows: Array) -> float:
	var label_size := _scaled(20, vp)
	draw_rect(Rect2(Vector2(content_left, y - 2.0), Vector2(4.0, label_size + 6.0)), accent, true)
	draw_string(_font_bold, Vector2(content_left + 12.0, y + label_size), team_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, Color(accent.r, accent.g, accent.b, 0.95))
	y += label_size + 8.0
	var row_h := _scaled(30, vp)
	var name_size := _scaled(19, vp)
	var value_size := _scaled(19, vp)
	for row_data in rows:
		var entry: Dictionary = row_data as Dictionary
		var alive: bool = bool(entry.get("alive", true))
		var name_color := Color(0.92, 0.95, 1.0, 1.0) if alive else Color(0.55, 0.58, 0.66, 0.8)
		# Role tag + name on the left.
		var tag := str(entry.get("tag", "?"))
		draw_string(_font_bold, Vector2(content_left, y + name_size), tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, Color(accent.r, accent.g, accent.b, 0.9 if alive else 0.5))
		draw_string(_font_bold, Vector2(content_left + 30.0, y + name_size), str(entry.get("name", "Player")), HORIZONTAL_ALIGNMENT_LEFT, content_w * 0.36, name_size, name_color)
		var stats: Array = entry.get("stats", []) as Array
		for i in range(COLUMNS.size()):
			var cx := content_left + content_w * float(COLUMNS[i]["x"])
			var value: int = int(stats[i + 1]) if stats.size() > i + 1 else 0
			var text := _format_number(value) if i >= 4 else str(value)
			draw_string(_font_value, Vector2(cx - 150.0, y + value_size), text, HORIZONTAL_ALIGNMENT_RIGHT, 150.0, value_size, name_color)
		y += row_h
	if rows.is_empty():
		draw_string(_font_value, Vector2(content_left + 30.0, y + name_size), "—", HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, Color(0.5, 0.53, 0.6, 0.7))
		y += row_h
	return y


# Build display rows grouped into hunters / props / spectators, sorted by COMBAT.
func _grouped_players() -> Dictionary:
	var hunters: Array = []
	var props: Array = []
	var spectators: Array = []
	for peer_id in Network.players.keys():
		var info: Dictionary = Network.players.get(peer_id, {}) as Dictionary
		var role := int(info.get("role", Network.Role.NONE))
		var stats: Array = _snapshot.get(int(peer_id), [int(peer_id), 0, 0, 0, 0, 0, 0, 0]) as Array
		var entry := {
			"name": str(info.get("nick", "Player")),
			"tag": _role_tag(role),
			"alive": bool(info.get("alive", true)),
			"stats": stats,
			"combat": int(stats[5]) if stats.size() > 5 else 0,
		}
		match role:
			Network.Role.HUNTER:
				hunters.append(entry)
			Network.Role.CHAMELEON, Network.Role.STALKER:
				props.append(entry)
			_:
				spectators.append(entry)
	var sort_by_combat := func(a, b): return int(a["combat"]) > int(b["combat"])
	hunters.sort_custom(sort_by_combat)
	props.sort_custom(sort_by_combat)
	return {"hunters": hunters, "props": props, "spectators": spectators}


func _role_tag(role: int) -> String:
	match role:
		Network.Role.HUNTER:
			return "H"
		Network.Role.CHAMELEON:
			return "C"
		Network.Role.STALKER:
			return "S"
		Network.Role.SPECTATOR:
			return "·"
		_:
			return "?"


func _format_number(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if value < 0 else out


func _scaled(base_size: int, vp: Vector2) -> int:
	var factor: float = clampf(vp.y / 1080.0, 0.75, 1.4)
	return int(round(float(base_size) * factor))


func _load_font(path: String) -> Font:
	var font: Resource = load(path)
	return font as Font if font is Font else ThemeDB.fallback_font
