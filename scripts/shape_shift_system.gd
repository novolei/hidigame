extends Node
class_name ShapeShiftSystem
# =============================================================================
# ShapeShiftSystem — 身体变形系统(v0.3.3, REFACTORED v0.3.1)
#
# 设计:
#   - 藏匿者专用
#   - 调整身体比例(身高 / 体重 / 头型),不是变成物体
#   - 6 秒 CD(v0.3 锁定)
#   - 2 秒平滑过渡动画
#   - v0.3.1 模拟约束:不能变具体物体,必须保持人形基本特征
# =============================================================================

# -----------------------------------------------------------------------------
# 配置
# -----------------------------------------------------------------------------
const SHIFT_COOLDOWN: float = 6.0       # v0.3 锁定
const SHIFT_TRANSITION_TIME: float = 2.0  # 平滑过渡时长

# 形态预设库(对应 GDD §3.6.1 的"参考物体")
# 注意:这些是身体参数,不是变成物体本身!
const PRESET_LIBRARY := [
	{
		"id": "tall_slim",
		"name": "瘦高 (路灯模拟)",
		"height": 1.5,
		"width": 0.4,
		"head": 0.3,
		"limb": 0.8,
		"tags": ["#tall", "#slim"],
	},
	{
		"id": "short_chubby",
		"name": "矮胖 (垃圾桶模拟)",
		"height": 0.6,
		"width": 1.4,
		"head": 1.2,
		"limb": 1.0,
		"tags": ["#short", "#chubby"],
	},
	{
		"id": "cube",
		"name": "立方 (纸箱模拟)",
		"height": 1.0,
		"width": 1.0,
		"head": 0.9,
		"limb": 0.7,
		"tags": ["#cube", "#box"],
	},
	{
		"id": "streamline",
		"name": "流线 (长椅模拟)",
		"height": 0.8,
		"width": 1.2,
		"head": 0.9,
		"limb": 0.9,
		"tags": ["#stream", "#low"],
	},
	{
		"id": "flat",
		"name": "扁平 (阴影模拟)",
		"height": 0.4,
		"width": 1.5,
		"head": 0.5,
		"limb": 0.6,
		"tags": ["#flat", "#low"],
	},
	{
		"id": "humanoid",
		"name": "标准人形",
		"height": 1.0,
		"width": 1.0,
		"head": 1.0,
		"limb": 1.0,
		"tags": ["#normal"],
	},
	{
		"id": "tall_humanoid",
		"name": "修长人形",
		"height": 1.2,
		"width": 0.9,
		"head": 0.9,
		"limb": 1.1,
		"tags": ["#tall"],
	},
	{
		"id": "wide_humanoid",
		"name": "宽厚人形",
		"height": 1.0,
		"width": 1.3,
		"head": 1.1,
		"limb": 1.0,
		"tags": ["#wide"],
	},
]

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
var shift_owner: CharacterBody3D = null
var current_preset_index: int = 5  # 默认 humanoid
var is_shifting: bool = false
var cooldown_remaining: float = 0.0
var wheel_open: bool = false

# 信号
signal shift_started(preset_index: int, preset_data: Dictionary)
signal shift_completed(preset_index: int, preset_data: Dictionary)
signal shift_failed(reason: String)
signal wheel_opened()
signal wheel_closed()
signal cooldown_updated(remaining: float)


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
		cooldown_updated.emit(cooldown_remaining)


func initialize(owner_node: CharacterBody3D) -> void:
	shift_owner = owner_node
	# 应用默认 preset
	_apply_preset_immediate(current_preset_index)


# =============================================================================
# 变形控制
# =============================================================================

func get_preset(index: int) -> Dictionary:
	if index < 0 or index >= PRESET_LIBRARY.size():
		return PRESET_LIBRARY[5]  # 默认 humanoid
	return PRESET_LIBRARY[index]


func get_preset_count() -> int:
	return PRESET_LIBRARY.size()


func try_shift(preset_index: int) -> bool:
	if is_shifting:
		shift_failed.emit("already_shifting")
		return false

	if cooldown_remaining > 0.0:
		shift_failed.emit("cooldown")
		return false

	if preset_index < 0 or preset_index >= PRESET_LIBRARY.size():
		shift_failed.emit("invalid_preset")
		return false

	var preset = PRESET_LIBRARY[preset_index]
	current_preset_index = preset_index
	is_shifting = true
	shift_started.emit(preset_index, preset)
	print("[ShapeShift] Shifting to ", preset["name"], " (h=", preset["height"], " w=", preset["width"], ")")

	# 平滑过渡动画
	_animate_to_preset(preset)
	return true


func _animate_to_preset(preset: Dictionary) -> void:
	if not shift_owner:
		is_shifting = false
		return

	# 创建 tween 做平滑变形(2s)
	var tween = shift_owner.create_tween()
	tween.set_parallel(true)

	# player.scale 的 x = width, y = height, z = width(对称宽度)
	var target_scale = Vector3(preset["width"], preset["height"], preset["width"])
	tween.tween_property(shift_owner, "scale", target_scale, SHIFT_TRANSITION_TIME)

	# 头/四肢缩放(简化为对 body 子节点生效)
	# 实际 player.tscn 的 body 是 _body 节点(Node3D)
	if shift_owner.has_node("_body"):
		var body_node = shift_owner.get_node("_body")
		var body_target_scale = Vector3(preset["limb"], preset["head"], preset["limb"])
		tween.tween_property(body_node, "scale", body_target_scale, SHIFT_TRANSITION_TIME)

	await tween.finished

	is_shifting = false
	cooldown_remaining = SHIFT_COOLDOWN
	shift_completed.emit(current_preset_index, preset)
	print("[ShapeShift] Shift completed, CD=", SHIFT_COOLDOWN, "s")


func _apply_preset_immediate(preset_index: int) -> void:
	# 立即应用,无动画(初始化用)
	var preset = get_preset(preset_index)
	if not shift_owner:
		return
	shift_owner.scale = Vector3(preset["width"], preset["height"], preset["width"])
	if shift_owner.has_node("_body"):
		var body_node = shift_owner.get_node("_body")
		body_node.scale = Vector3(preset["limb"], preset["head"], preset["limb"])


# =============================================================================
# 轮盘控制
# =============================================================================

func open_wheel() -> void:
	if wheel_open:
		return
	wheel_open = true
	wheel_opened.emit()


func close_wheel() -> void:
	if not wheel_open:
		return
	wheel_open = false
	wheel_closed.emit()


# =============================================================================
# 工具
# =============================================================================

func get_cooldown_remaining() -> float:
	return cooldown_remaining


func get_current_preset() -> Dictionary:
	return get_preset(current_preset_index)


func is_shift_ready() -> bool:
	return cooldown_remaining <= 0.0 and not is_shifting