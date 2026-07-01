extends CanvasLayer

## Autoload "KillFeed": a minimal FPS-style kill feed pinned to the top-right of
## the screen, styled after a badge+name layout (a colored rounded role badge
## followed by the player name), with a skull glyph as the kill icon.
##
## Any peer calls report_* locally. The existing death replication already fans
## these events to every peer (Character._broadcast_death is call_local+reliable;
## AnimalProp._sync_death reaches every client and the server runs _begin_death
## directly), so no extra broadcast RPC is needed. A dedicated headless server
## builds no UI and every report_* call no-ops there.

const MAX_ENTRIES: int = 6
const ENTRY_LIFETIME: float = 6.0
const FADE_SECONDS: float = 0.7
const SKULL_PATH: String = "res://addons/at-icons/control/skull.svg"

# Team / role palette: hunters read red, prop roles read blue, animals orange.
const HUNTER_BADGE: Color = Color(0.86, 0.24, 0.28, 0.95)
const HUNTER_NAME: Color = Color(1.0, 0.52, 0.50, 1.0)
const CHAMELEON_BADGE: Color = Color(0.20, 0.50, 0.88, 0.95)
const CHAMELEON_NAME: Color = Color(0.60, 0.82, 1.0, 1.0)
const STALKER_BADGE: Color = Color(0.40, 0.40, 0.82, 0.95)
const STALKER_NAME: Color = Color(0.72, 0.74, 1.0, 1.0)
const NEUTRAL_BADGE: Color = Color(0.42, 0.46, 0.52, 0.95)
const NEUTRAL_NAME: Color = Color(0.82, 0.86, 0.92, 1.0)
const ANIMAL_BADGE: Color = Color(0.90, 0.55, 0.16, 0.95)
const ANIMAL_NAME: Color = Color(1.0, 0.80, 0.44, 1.0)

var _rows: VBoxContainer = null
var _skull_texture: Texture2D = null


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RuntimeMode.is_headless():
		return
	_skull_texture = load(SKULL_PATH) as Texture2D
	_build_ui()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "KillFeedRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rows.add_theme_constant_override("separation", 5)
	_rows.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rows.offset_left = -620.0
	_rows.offset_right = -18.0
	_rows.offset_top = 18.0
	_rows.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_rows)


# A player kill (or a killer-less death when killer_id <= 0).
func report_player_kill(killer_id: int, victim_id: int) -> void:
	if _rows == null:
		return
	var victim: Dictionary = _peer_descriptor(victim_id)
	var killer: Dictionary = _peer_descriptor(killer_id) if killer_id > 0 else {}
	_add_entry(killer, victim)


# A hunter shot a REAL animal — a costly mistake, announced to everyone.
func report_animal_kill(killer_id: int, animal_name: String) -> void:
	if _rows == null:
		return
	var killer: Dictionary = _peer_descriptor(killer_id)
	var victim: Dictionary = {"tag": "兽", "badge": ANIMAL_BADGE, "name": animal_name, "name_color": ANIMAL_NAME}
	_add_entry(killer, victim)


# A hunt-tracker animal started tailing a hunter — announced to everyone.
func report_animal_track(animal_name: String, hunter_id: int) -> void:
	if _rows == null:
		return
	var animal: Dictionary = {"tag": "兽", "badge": ANIMAL_BADGE, "name": animal_name, "name_color": ANIMAL_NAME}
	var hunter: Dictionary = _peer_descriptor(hunter_id)
	_add_entry(animal, hunter, _make_verb("尾随", ANIMAL_NAME))


func _make_verb(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _add_entry(killer: Dictionary, victim: Dictionary, middle: Control = null) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.55)
	style.set_corner_radius_all(5)
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	panel.add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	if not killer.is_empty():
		_add_actor(row, killer)
	row.add_child(middle if middle != null else _make_skull())
	_add_actor(row, victim)

	_rows.add_child(panel)
	_rows.move_child(panel, 0)

	while _rows.get_child_count() > MAX_ENTRIES:
		var oldest: Node = _rows.get_child(_rows.get_child_count() - 1)
		_rows.remove_child(oldest)
		oldest.queue_free()

	_schedule_fade(panel)


func _add_actor(row: HBoxContainer, actor: Dictionary) -> void:
	row.add_child(_make_badge(String(actor.get("tag", "?")), actor.get("badge", NEUTRAL_BADGE)))
	row.add_child(_make_name(String(actor.get("name", "玩家")), actor.get("name_color", NEUTRAL_NAME)))


func _make_badge(tag: String, color: Color) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	badge.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = tag
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	badge.add_child(label)
	return badge


func _make_name(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_skull() -> Control:
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _skull_texture
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _schedule_fade(panel: PanelContainer) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(ENTRY_LIFETIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)


func _peer_descriptor(peer_id: int) -> Dictionary:
	var role: int = -1
	if Network != null and Network.players.has(peer_id):
		role = int(Network.players[peer_id].get("role", -1))
	match role:
		Network.Role.HUNTER:
			return {"tag": "猎", "badge": HUNTER_BADGE, "name": _player_name(peer_id), "name_color": HUNTER_NAME}
		Network.Role.CHAMELEON:
			return {"tag": "藏", "badge": CHAMELEON_BADGE, "name": _player_name(peer_id), "name_color": CHAMELEON_NAME}
		Network.Role.STALKER:
			return {"tag": "潜", "badge": STALKER_BADGE, "name": _player_name(peer_id), "name_color": STALKER_NAME}
		_:
			return {"tag": "观", "badge": NEUTRAL_BADGE, "name": _player_name(peer_id), "name_color": NEUTRAL_NAME}


func _player_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "玩家"
	if Network != null and Network.players.has(peer_id):
		var nick: String = str(Network.players[peer_id].get("nick", "")).strip_edges()
		if not nick.is_empty():
			return nick
	return "玩家%d" % peer_id
