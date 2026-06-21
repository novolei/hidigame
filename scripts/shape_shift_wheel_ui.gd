extends Control
class_name ShapeShiftWheelUI
# =============================================================================
# ShapeShiftWheelUI — 变形轮盘 UI(v0.3.3)
#
# 设计:
#   - 游戏中按 Q 打开/关闭
#   - 8 个形态预设,鼠标点击 / 数字键 1-8 / 滚轮选择
#   - 显示当前 CD
#   - 退出后应用选中的形态
# =============================================================================

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/MarginContainer/GridContainer
@onready var cooldown_label: Label = $Panel/MarginContainer/Header/CooldownLabel

var shape_system: ShapeShiftSystem = null
var preset_buttons: Array[Button] = []
var selected_index: int = -1

# 信号
signal preset_selected(preset_index: int)
signal wheel_closed_confirmed()


func _ready():
	visible = false


# =============================================================================
# 显示控制
# =============================================================================

func show_wheel(system: ShapeShiftSystem) -> void:
	shape_system = system
	visible = true
	_populate_buttons()
	# 默认选中当前 preset
	selected_index = shape_system.current_preset_index
	_highlight_selected()


func hide_wheel() -> void:
	visible = false
	shape_system = null
	selected_index = -1


func is_wheel_visible() -> bool:
	return visible


# =============================================================================
# 构建按钮
# =============================================================================

func _populate_buttons() -> void:
	# 清空现有
	for child in grid.get_children():
		child.queue_free()
	preset_buttons.clear()

	if not shape_system:
		return

	for i in range(shape_system.get_preset_count()):
		var preset = shape_system.get_preset(i)
		var btn = Button.new()
		var tags: String = " ".join(PackedStringArray(preset.get("tags", [])))
		btn.text = "[%d] %s\n%s" % [i + 1, preset["name"], tags]
		btn.custom_minimum_size = Vector2(190, 64)
		btn.focus_mode = Control.FOCUS_NONE
		var idx = i
		btn.pressed.connect(func(): _on_preset_clicked(idx))
		grid.add_child(btn)
		preset_buttons.append(btn)


func _highlight_selected() -> void:
	for i in range(preset_buttons.size()):
		var btn = preset_buttons[i]
		if i == selected_index:
			btn.modulate = Color(1.2, 1.2, 0.5, 1)  # 黄色高亮
		else:
			btn.modulate = Color(1, 1, 1, 1)


# =============================================================================
# 交互
# =============================================================================

func _on_preset_clicked(preset_index: int) -> void:
	selected_index = preset_index
	_highlight_selected()


func confirm_selection() -> void:
	if selected_index >= 0 and shape_system:
		shape_system.try_shift(selected_index)
		preset_selected.emit(selected_index)
	hide_wheel()


func cancel() -> void:
	hide_wheel()
	wheel_closed_confirmed.emit()


# =============================================================================
# 输入处理(由 level 调用)
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# 数字键 1-8 快速选择
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _on_preset_clicked(0)
			KEY_2: _on_preset_clicked(1)
			KEY_3: _on_preset_clicked(2)
			KEY_4: _on_preset_clicked(3)
			KEY_5: _on_preset_clicked(4)
			KEY_6: _on_preset_clicked(5)
			KEY_7: _on_preset_clicked(6)
			KEY_8: _on_preset_clicked(7)
			KEY_ENTER: confirm_selection()
			KEY_ESCAPE: cancel()

	# Enter / Esc 也支持
	if event.is_action_pressed("ui_accept"):
		confirm_selection()


func update_cooldown(remaining: float) -> void:
	if cooldown_label:
		if remaining > 0.0:
			cooldown_label.text = "冷却: %.1fs" % remaining
			cooldown_label.modulate = Color(1, 0.5, 0.5, 1)
		else:
			cooldown_label.text = "冷却: 就绪"
			cooldown_label.modulate = Color(0.5, 1, 0.5, 1)
