extends Control
class_name PartyMonsterHuntHUD

const WIDTH := 360.0
const HEIGHT := 218.0
const TOP_OFFSET := 118.0
const BOUNTY_TOTAL_FALLBACK := 78.0
const SAFE_ACCENT := Color(0.34, 0.90, 1.0, 1.0)
const WARNING_ACCENT := Color(1.0, 0.22, 0.78, 1.0)
const DIM_TEXT := Color(0.75, 0.84, 0.92, 0.92)

@export var qa_preview_state := false

var _panel: PanelContainer = null
var _title_label: Label = null
var _target_label: Label = null
var _timer_bar: ProgressBar = null
var _count_label: Label = null
var _loadout_label: Label = null
var _escape_label: Label = null
var _marked := false
var _pulse_time := 0.0
var _debug_state: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()
	if qa_preview_state:
		set_hunt_state(true, true, "Eyes 02 or Mouth 05", 31.0, 78.0, 0.0, 2, "Eyes 02 / Mouth 05 / Nose 01 / +2", "Eyes or Mouth")
	else:
		clear()


func _process(delta: float) -> void:
	if not visible or not _marked:
		return
	_pulse_time += delta
	var pulse := 0.88 + sin(_pulse_time * 7.2) * 0.12
	modulate = Color(1.0, pulse, pulse, 1.0)


func clear() -> void:
	_ensure_nodes()
	visible = false
	_marked = false
	modulate = Color.WHITE
	_debug_state = {"visible": false}


func set_hunt_state(active: bool, marked: bool, bounty_label: String, bounty_remaining: float, bounty_total: float, next_bounty_remaining: float, marked_count: int, loadout_summary: String, escape_hint: String) -> void:
	_ensure_nodes()
	if not active:
		clear()
		return

	visible = true
	_marked = marked
	if not marked:
		modulate = Color.WHITE
	var accent := WARNING_ACCENT if marked else SAFE_ACCENT
	_apply_panel_style(accent, marked)

	var has_bounty := not bounty_label.strip_edges().is_empty() and bounty_remaining > 0.0
	_title_label.text = "YOU ARE MARKED" if marked else "MONSTER HUNT"
	_title_label.add_theme_color_override("font_color", accent)

	if has_bounty:
		_target_label.text = "Target  %s" % bounty_label
		_count_label.text = "Marked  %d" % maxi(marked_count, 0)
	else:
		_target_label.text = "Next bounty  %ds" % int(ceil(maxf(next_bounty_remaining, 0.0)))
		_count_label.text = "Marked  0"

	var total: float = maxf(maxf(bounty_total, bounty_remaining), BOUNTY_TOTAL_FALLBACK)
	_timer_bar.visible = has_bounty
	_timer_bar.max_value = total
	_timer_bar.value = clampf(bounty_remaining, 0.0, total)
	_timer_bar.modulate = accent

	_loadout_label.visible = not loadout_summary.strip_edges().is_empty()
	_loadout_label.text = "Traits  %s" % loadout_summary
	_loadout_label.add_theme_color_override("font_color", Color.WHITE if not marked else Color(1.0, 0.94, 0.42, 1.0))

	_escape_label.visible = marked or not escape_hint.strip_edges().is_empty()
	_escape_label.text = "Swap  %s" % escape_hint if not escape_hint.strip_edges().is_empty() else "Swap target trait"
	_escape_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.32, 1.0))

	_debug_state = {
		"visible": visible,
		"marked": marked,
		"bounty_label": bounty_label,
		"bounty_remaining": bounty_remaining,
		"next_bounty_remaining": next_bounty_remaining,
		"marked_count": marked_count,
		"loadout_summary": loadout_summary,
		"escape_hint": escape_hint,
		"title": _title_label.text,
		"target": _target_label.text,
	}


func get_debug_state() -> Dictionary:
	return _debug_state.duplicate(true)


func _ensure_nodes() -> void:
	if _panel and is_instance_valid(_panel):
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_TOP_RIGHT
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -WIDTH - 18.0
	offset_top = TOP_OFFSET
	offset_right = -18.0
	offset_bottom = TOP_OFFSET + HEIGHT
	custom_minimum_size = Vector2(WIDTH, HEIGHT)

	_panel = PanelContainer.new()
	_panel.name = "HuntPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "HuntStack"
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	_title_label = _make_label("TitleLabel", 21, Color.WHITE)
	_title_label.uppercase = true
	stack.add_child(_title_label)

	_target_label = _make_label("TargetLabel", 17, Color.WHITE)
	stack.add_child(_target_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.name = "BountyTimerBar"
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(WIDTH - 42.0, 10.0)
	stack.add_child(_timer_bar)

	_count_label = _make_label("MarkedCountLabel", 15, DIM_TEXT)
	stack.add_child(_count_label)

	_loadout_label = _make_label("LoadoutLabel", 15, Color.WHITE)
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_label.custom_minimum_size = Vector2(WIDTH - 42.0, 0.0)
	stack.add_child(_loadout_label)

	_escape_label = _make_label("EscapeLabel", 16, Color(1.0, 0.94, 0.32, 1.0))
	_escape_label.uppercase = true
	stack.add_child(_escape_label)


func _make_label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _apply_panel_style(accent: Color, marked: bool) -> void:
	if not _panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.048, 0.78 if marked else 0.62)
	style.border_color = accent
	style.set_border_width_all(2 if marked else 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
