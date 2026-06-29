class_name GamePauseMenu
extends CanvasLayer
# =============================================================================
# GamePauseMenu — reusable in-game overlay panel with a vertical button group.
#
# Generic on purpose: feed it a title + a list of {id, label} options via
# configure(); it emits option_selected(id) when a button is pressed. The host
# (level.gd) owns ESC routing, input locking, and what each option does. Built
# entirely in code so the headless server never instantiates it.
# =============================================================================

signal option_selected(id: String)

const FONT_BOLD := "res://assets/fonts/SairaCondensed-Bold.woff2"
const ACCENT := Color(0.55, 0.78, 1.0, 1.0)   # cool highlight (matches HUD accents)

var _vbox: VBoxContainer = null
var _title_label: Label = null
var _built := false


func _ready() -> void:
	layer = 125   # above HUD / console / toasts
	_build()
	visible = false


func _build() -> void:
	if _built:
		return
	_built = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", _font(FONT_BOLD))
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.96))
	_vbox.add_child(_title_label)

	var sep := ColorRect.new()
	sep.color = Color(1.0, 1.0, 1.0, 0.08)
	sep.custom_minimum_size = Vector2(0.0, 2.0)
	_vbox.add_child(sep)

	# Bottom-left "ESC CLOSE" hint, mirroring the reference layout.
	var hint := Label.new()
	hint.text = "ESC  ·  CLOSE / 关闭"
	hint.add_theme_font_override("font", _font(FONT_BOLD))
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 0.55))
	hint.position = Vector2(20.0, -34.0)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


# title: panel heading. options: Array of {id: String, label: String}.
func configure(title: String, options: Array) -> void:
	_build()
	_title_label.text = title
	for child in _vbox.get_children():
		if child is Button:
			child.queue_free()
	for raw_option in options:
		var option: Dictionary = raw_option as Dictionary
		_vbox.add_child(_make_button(str(option.get("id", "")), str(option.get("label", ""))))


func open() -> void:
	_build()
	visible = true


func close() -> void:
	visible = false


func _make_button(id: String, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.add_theme_font_override("font", _font(FONT_BOLD))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.11, 0.14, 0.85), Color(1.0, 1.0, 1.0, 0.06)))
	var hover_style := _button_style(Color(0.15, 0.18, 0.24, 0.95), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9))
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.10, 0.12, 0.95), Color(1.0, 0.4, 0.45, 0.9)))
	button.pressed.connect(func() -> void: option_selected.emit(id))
	# Hover highlights via focus, so mouse + keyboard navigation share one visual.
	button.mouse_entered.connect(func() -> void: button.grab_focus())
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.055, 0.07, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 20
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _font(path: String) -> Font:
	var font: Resource = load(path)
	return font as Font if font is Font else ThemeDB.fallback_font
