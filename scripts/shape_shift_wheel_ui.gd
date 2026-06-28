extends Control
class_name ShapeShiftWheelUI
# =============================================================================
# ShapeShiftWheelUI — Chameleon shape-shift selector (Q)
#
# Now a thin adapter over the reusable RadialWheelMenu (Apex-style wheel). The
# public API (show_wheel / hide_wheel / is_wheel_visible / confirm_selection /
# cancel / update_cooldown and the preset_selected / wheel_closed_confirmed
# signals) is preserved so player.gd's call sites are unchanged.
# =============================================================================

const RadialWheelMenuScript := preload("res://scripts/radial_wheel_menu.gd")

signal preset_selected(preset_index: int)
signal wheel_closed_confirmed()

var shape_system: ShapeShiftSystem = null
var selected_index: int = -1
var _wheel: RadialWheelMenu = null
# Maps a radial option index back to its preset index (wheel-hidden presets such
# as the internal "解除伪装" revert state are skipped, so they differ).
var _option_to_preset: Array[int] = []


func _ready() -> void:
	# Drop the legacy .tscn grid/panel layout; the radial menu owns the visuals.
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel = RadialWheelMenuScript.new()
	_wheel.name = "RadialWheel"
	add_child(_wheel)
	_wheel.option_chosen.connect(_on_option_chosen)
	_wheel.cancelled.connect(_on_wheel_cancelled)
	visible = false


func show_wheel(system: ShapeShiftSystem) -> void:
	shape_system = system
	visible = true
	var options: Array = []
	_option_to_preset.clear()
	var preselect := -1
	for i in range(shape_system.get_preset_count()):
		var preset = shape_system.get_preset(i)
		if bool(preset.get("wheel_hidden", false)):
			continue
		if i == shape_system.current_preset_index:
			preselect = options.size()
		options.append({"label": str(preset.get("name", "Form %d" % (i + 1))), "enabled": true})
		_option_to_preset.append(i)
	selected_index = shape_system.current_preset_index
	_wheel.open(options, "SHAPE SHIFT", preselect)


func hide_wheel() -> void:
	visible = false
	if _wheel:
		_wheel.close()
	shape_system = null
	selected_index = -1


func is_wheel_visible() -> bool:
	return visible


# Called when the player releases Q: pick the wedge the cursor is aiming at
# (or cancel if none).
func release_select() -> void:
	if _wheel:
		_wheel.select_hovered()


func _on_option_chosen(index: int) -> void:
	var preset_index := _option_to_preset[index] if index >= 0 and index < _option_to_preset.size() else index
	selected_index = preset_index
	if shape_system:
		shape_system.try_shift(preset_index)
		preset_selected.emit(preset_index)
	hide_wheel()


func _on_wheel_cancelled() -> void:
	hide_wheel()
	wheel_closed_confirmed.emit()


# Kept for API compatibility (Enter-to-confirm callers).
func confirm_selection() -> void:
	if selected_index >= 0 and shape_system:
		shape_system.try_shift(selected_index)
		preset_selected.emit(selected_index)
	hide_wheel()


func cancel() -> void:
	hide_wheel()
	wheel_closed_confirmed.emit()


func update_cooldown(remaining: float) -> void:
	if not _wheel:
		return
	_wheel.set_footer("READY" if remaining <= 0.0 else "COOLDOWN %.1fs" % remaining)
