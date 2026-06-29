class_name GamePauseMenu
extends CanvasLayer
# =============================================================================
# GamePauseMenu — reusable in-game pause overlay (Apex-style).
#
# A full-height dark column spanning half the window width, with a brand mark at
# the top and a vertical, full-bleed button list (flat rows + separators, blue
# glow on hover/focus). Generic: configure(title, options) + option_selected(id).
# Built in code so the headless server never instantiates it.
# =============================================================================

signal option_selected(id: String)

const FONT_BOLD := "res://assets/fonts/SairaCondensed-Bold.woff2"
const ACCENT := Color(0.40, 0.72, 1.0, 1.0)          # cool glow accent
const COLUMN_BG := Color(0.055, 0.06, 0.075, 0.98)
const COLUMN_FRACTION := 0.5                          # column width = half the window

var _root: Control = null
var _backdrop: Control = null
var _vbox: VBoxContainer = null
var _font: Font = null
var _built := false


func _ready() -> void:
	layer = 125
	_font = _load_font(FONT_BOLD)
	_build()
	visible = false
	get_viewport().size_changed.connect(_relayout)


# Inner backdrop: draws the dark column, the brand mark and the ESC hint.
class _Backdrop extends Control:
	var accent: Color = Color.WHITE
	var font: Font = null

	func _draw() -> void:
		var vp := size
		var col_w := vp.x * 0.5
		var col_x := (vp.x - col_w) * 0.5
		draw_rect(Rect2(Vector2(col_x, 0.0), Vector2(col_w, vp.y)), GamePauseMenu.COLUMN_BG, true)
		# Faint vertical edge lines for definition.
		draw_rect(Rect2(Vector2(col_x, 0.0), Vector2(2.0, vp.y)), Color(1, 1, 1, 0.06), true)
		draw_rect(Rect2(Vector2(col_x + col_w - 2.0, 0.0), Vector2(2.0, vp.y)), Color(1, 1, 1, 0.06), true)
		_draw_brand(Vector2(col_x + col_w * 0.5, vp.y * 0.17), minf(col_w * 0.16, 96.0))
		if font:
			draw_string(font, Vector2(col_x + 26.0, vp.y - 26.0), "ESC  ·  CLOSE / 关闭", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.82, 0.87, 0.95, 0.5))

	# Layered upward chevrons forming the brand "A".
	func _draw_brand(center: Vector2, s: float) -> void:
		var thick := maxf(4.0, s * 0.17)
		var outer := PackedVector2Array([
			center + Vector2(-s, s * 0.62), center + Vector2(0.0, -s * 0.72), center + Vector2(s, s * 0.62)])
		draw_polyline(outer, Color(0.95, 0.97, 1.0, 0.97), thick, true)
		var inner := PackedVector2Array([
			center + Vector2(-s * 0.42, s * 0.62), center + Vector2(0.0, -s * 0.02), center + Vector2(s * 0.42, s * 0.62)])
		draw_polyline(inner, Color(0.95, 0.97, 1.0, 0.97), thick, true)


func _build() -> void:
	if _built:
		return
	_built = true

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks outside the column
	add_child(_root)

	_backdrop = _Backdrop.new()
	_backdrop.accent = ACCENT
	_backdrop.font = _font
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 0)
	_root.add_child(_vbox)

	_relayout()


# title kept for API compatibility (the brand mark replaces a text title).
func configure(_title: String, options: Array) -> void:
	_build()
	for child in _vbox.get_children():
		child.queue_free()
	for raw_option in options:
		var option: Dictionary = raw_option as Dictionary
		_vbox.add_child(_make_button(str(option.get("id", "")), str(option.get("label", ""))))
	_relayout()


func open() -> void:
	_build()
	visible = true
	_relayout()


func close() -> void:
	visible = false


func _relayout() -> void:
	if not _built:
		return
	var vp := get_viewport().get_visible_rect().size
	_root.size = vp
	_backdrop.size = vp
	_backdrop.queue_redraw()
	var col_w := vp.x * COLUMN_FRACTION
	var col_x := (vp.x - col_w) * 0.5
	_vbox.position = Vector2(col_x, vp.y * 0.42)
	_vbox.custom_minimum_size = Vector2(col_w, 0.0)
	_vbox.size = Vector2(col_w, 0.0)


func _make_button(id: String, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0.0, 66.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_stylebox_override("normal", _row_style())
	var glow := _glow_style()
	button.add_theme_stylebox_override("hover", glow)
	button.add_theme_stylebox_override("focus", glow)
	button.add_theme_stylebox_override("pressed", _glow_style(true))
	button.pressed.connect(func() -> void: option_selected.emit(id))
	button.mouse_entered.connect(func() -> void: button.grab_focus())
	return button


# Flat full-width row with a thin bottom separator.
func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.08)
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


# Selected/hovered row: subtle dark fill, accent border, soft accent glow.
func _glow_style(pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.19, 0.92) if not pressed else Color(0.18, 0.07, 0.09, 0.95)
	style.set_corner_radius_all(5)
	style.set_border_width_all(2)
	style.border_color = ACCENT
	style.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	style.shadow_size = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _load_font(path: String) -> Font:
	var font: Resource = load(path)
	return font as Font if font is Font else ThemeDB.fallback_font
