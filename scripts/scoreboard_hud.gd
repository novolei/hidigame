class_name ScoreboardHUD
extends Control
# =============================================================================
# ScoreboardHUD — full-screen Tab scoreboard (Apex-style, three faction sections).
#
# Held-Tab overlay. Three faction sections — Hunters, Chameleon (Hider), Stalker —
# split by a "VS" divider (1 hunter side vs the 2 prop factions). Each section
# always shows at least DEFAULT_ROWS rows; empty slots render a "—" placeholder.
# Rows use a translucent dark band; the local player's row is highlighted. All text
# is localized (I18n) and uses Saira Extra Condensed. Pure _draw() — the headless
# server never instantiates it. Roster: Network.players; stats: synced snapshot.
# =============================================================================

const FONT_BOLD := "res://assets/fonts/SairaExtraCondensed-Bold.woff2"
const FONT_VALUE := "res://assets/fonts/SairaExtraCondensed-Regular.woff2"
const DEFAULT_ROWS := 3

# Numeric columns: i18n key (empty = literal label) + right-edge x fraction.
const COLUMNS := [
	{"key": "", "label": "E", "x": 0.47},
	{"key": "", "label": "A", "x": 0.53},
	{"key": "", "label": "D", "x": 0.59},
	{"key": "", "label": "R", "x": 0.65},
	{"key": "scoreboard.combat", "label": "COMBAT", "x": 0.77},
	{"key": "scoreboard.support", "label": "SUPPORT", "x": 0.88},
	{"key": "scoreboard.objective", "label": "OBJECTIVE", "x": 0.99},
]

const HUNTER_COLOR := Color(0.86, 0.30, 0.34, 1.0)
const CHAMELEON_COLOR := Color(0.36, 0.74, 0.46, 1.0)
const STALKER_COLOR := Color(0.58, 0.44, 0.88, 1.0)
const SPEC_COLOR := Color(0.50, 0.53, 0.60, 1.0)
const ROW_DARK := Color(0.07, 0.07, 0.09, 0.50)       # translucent dark-gray band
const ROW_DARK_ALT := Color(0.10, 0.10, 0.13, 0.42)   # alternating band
const ROW_HIGHLIGHT := Color(0.96, 0.96, 0.97, 0.97)  # local player's row (light)
const BADGE_W := 148.0
const COL_BOX := 160.0

var _snapshot: Dictionary = {}   # peer_id -> [pid, E, A, D, R, COMBAT, SUPPORT, OBJECTIVE]
var _font_bold: Font = null
var _font_value: Font = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_bold = _load_font(FONT_BOLD)
	_font_value = _load_font(FONT_VALUE)
	visible = false


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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.03, 0.62), true)

	var content_w: float = minf(vp.x * 0.9, 1520.0)
	var content_left := (vp.x - content_w) * 0.5

	var teams := _grouped_players()
	var hunters: Array = teams["hunters"]
	var chameleons: Array = teams["chameleons"]
	var stalkers: Array = teams["stalkers"]
	var specs: Array = teams["spectators"]

	var title_size := _scaled(30, vp)
	var header_size := _scaled(17, vp)
	var row_h := float(_scaled(34, vp))
	var label_size := _scaled(18, vp)
	var vs_size := _scaled(20, vp)
	var vs_h := float(vs_size) + 18.0
	var header_h := float(title_size) + 18.0

	# Each section is at least DEFAULT_ROWS tall.
	var hn := maxi(DEFAULT_ROWS, hunters.size())
	var cn := maxi(DEFAULT_ROWS, chameleons.size())
	var stn := maxi(DEFAULT_ROWS, stalkers.size())
	var sn := specs.size()
	var total := header_h + float(hn) * row_h + vs_h + float(cn + stn) * row_h + 8.0
	if sn > 0:
		total += vs_h * 0.6 + float(maxi(DEFAULT_ROWS, sn)) * row_h
	var y := clampf((vp.y - total) * 0.5, vp.y * 0.05, vp.y * 0.40)

	# Title + column headers.
	draw_string(_font_bold, Vector2(content_left, y + title_size), I18n.t("scoreboard.title"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.96, 0.97, 1.0, 0.97))
	for col in COLUMNS:
		var cx := content_left + content_w * float(col["x"])
		var label := str(col["label"]) if str(col["key"]).is_empty() else I18n.t(str(col["key"]))
		draw_string(_font_bold, Vector2(cx - COL_BOX, y + title_size), label, HORIZONTAL_ALIGNMENT_RIGHT, COL_BOX, header_size, Color(0.85, 0.88, 0.95, 0.9))
	y += header_h

	y = _draw_team(content_left, content_w, y, vp, row_h, label_size, I18n.t("role.hunter"), HUNTER_COLOR, hunters)
	_draw_vs(content_left, content_w, y, vs_size)
	y += vs_h
	y = _draw_team(content_left, content_w, y, vp, row_h, label_size, I18n.t("role.chameleon"), CHAMELEON_COLOR, chameleons)
	y += 4.0
	y = _draw_team(content_left, content_w, y, vp, row_h, label_size, I18n.t("role.stalker"), STALKER_COLOR, stalkers)
	if sn > 0:
		y += vs_h * 0.6
		y = _draw_team(content_left, content_w, y, vp, row_h, label_size, I18n.t("scoreboard.spectators"), SPEC_COLOR, specs)


func _draw_team(content_left: float, content_w: float, y: float, vp: Vector2, row_h: float, label_size: int, team_name: String, color: Color, rows: Array) -> float:
	var visible_rows := maxi(DEFAULT_ROWS, rows.size())
	var block_h := float(visible_rows) * row_h
	var rows_left := content_left + BADGE_W + 6.0
	var rows_w := content_w - BADGE_W - 6.0

	# Team badge (colored block: localized name + count).
	draw_rect(Rect2(Vector2(content_left, y), Vector2(BADGE_W - 4.0, block_h)), Color(color.r, color.g, color.b, 0.92), true)
	var badge_cy := y + block_h * 0.5
	draw_string(_font_bold, Vector2(content_left + 8.0, badge_cy - 2.0), team_name, HORIZONTAL_ALIGNMENT_CENTER, BADGE_W - 16.0, label_size, Color(1, 1, 1, 0.98))
	draw_string(_font_value, Vector2(content_left + 8.0, badge_cy + float(label_size) + 2.0), str(rows.size()), HORIZONTAL_ALIGNMENT_CENTER, BADGE_W - 16.0, _scaled(13, vp), Color(1, 1, 1, 0.78))

	var local_id := _local_peer_id()
	var name_size := _scaled(18, vp)
	for i in range(visible_rows):
		var ry := y + float(i) * row_h
		var has_player := i < rows.size()
		var entry: Dictionary = rows[i] as Dictionary if has_player else {}
		var is_local := has_player and int(entry.get("peer", 0)) == local_id
		var band := ROW_HIGHLIGHT if is_local else (ROW_DARK if i % 2 == 0 else ROW_DARK_ALT)
		draw_rect(Rect2(Vector2(rows_left, ry + 1.0), Vector2(rows_w, row_h - 2.0)), band, true)
		var ty := ry + (row_h + float(name_size)) * 0.5 - 4.0

		if not has_player:
			draw_string(_font_value, Vector2(rows_left + 46.0, ty), "—", HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, Color(0.55, 0.57, 0.63, 0.55))
			continue

		var alive := bool(entry.get("alive", true))
		var text_col := Color(0.10, 0.07, 0.08, 1.0)
		if not is_local:
			text_col = Color(0.95, 0.96, 1.0, 1.0) if alive else Color(0.60, 0.62, 0.68, 0.85)
		var tag_col := text_col if is_local else Color(color.r, color.g, color.b, 1.0)

		draw_string(_font_bold, Vector2(rows_left + 12.0, ty), str(entry.get("tag", "?")), HORIZONTAL_ALIGNMENT_LEFT, 30.0, name_size, tag_col)
		var player_name := str(entry.get("name", "Player"))
		var name_box := rows_w * 0.40
		draw_string(_font_bold, Vector2(rows_left + 46.0, ty), player_name, HORIZONTAL_ALIGNMENT_LEFT, name_box, name_size, text_col)
		var name_px: float = minf(_font_bold.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x, name_box)
		draw_circle(Vector2(rows_left + 46.0 + name_px + 12.0, ry + row_h * 0.5), 5.0, Color(text_col.r, text_col.g, text_col.b, 0.5))

		var stats: Array = entry.get("stats", []) as Array
		for c in range(COLUMNS.size()):
			var cx := content_left + content_w * float(COLUMNS[c]["x"])
			var value: int = int(stats[c + 1]) if stats.size() > c + 1 else 0
			var text := _format_number(value) if c >= 4 else str(value)
			draw_string(_font_value, Vector2(cx - COL_BOX, ty), text, HORIZONTAL_ALIGNMENT_RIGHT, COL_BOX, name_size, text_col)

	return y + block_h


func _draw_vs(content_left: float, content_w: float, y: float, vs_size: int) -> void:
	var cy := y + float(vs_size) * 0.5 + 6.0
	draw_rect(Rect2(Vector2(content_left, cy), Vector2(content_w * 0.46, 1.0)), Color(1, 1, 1, 0.16), true)
	draw_rect(Rect2(Vector2(content_left + content_w * 0.54, cy), Vector2(content_w * 0.46, 1.0)), Color(1, 1, 1, 0.16), true)
	draw_string(_font_bold, Vector2(content_left + content_w * 0.5 - 30.0, cy + float(vs_size) * 0.4), I18n.t("scoreboard.vs"), HORIZONTAL_ALIGNMENT_CENTER, 60.0, vs_size, Color(0.95, 0.96, 1.0, 0.85))


# hunters / chameleons / stalkers / spectators, each sorted by COMBAT desc.
func _grouped_players() -> Dictionary:
	var hunters: Array = []
	var chameleons: Array = []
	var stalkers: Array = []
	var spectators: Array = []
	for peer_id in Network.players.keys():
		var info: Dictionary = Network.players.get(peer_id, {}) as Dictionary
		var role := int(info.get("role", Network.Role.NONE))
		var stats: Array = _snapshot.get(int(peer_id), [int(peer_id), 0, 0, 0, 0, 0, 0, 0]) as Array
		var entry := {
			"peer": int(peer_id),
			"name": str(info.get("nick", "Player")),
			"tag": _role_tag(role),
			"alive": bool(info.get("alive", true)),
			"stats": stats,
			"combat": int(stats[5]) if stats.size() > 5 else 0,
		}
		match role:
			Network.Role.HUNTER:
				hunters.append(entry)
			Network.Role.CHAMELEON:
				chameleons.append(entry)
			Network.Role.STALKER:
				stalkers.append(entry)
			_:
				spectators.append(entry)
	var by_combat := func(a, b): return int(a["combat"]) > int(b["combat"])
	hunters.sort_custom(by_combat)
	chameleons.sort_custom(by_combat)
	stalkers.sort_custom(by_combat)
	return {"hunters": hunters, "chameleons": chameleons, "stalkers": stalkers, "spectators": spectators}


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


func _local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


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
