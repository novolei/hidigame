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
const REPLICATE_RANGE: float = 4.5

# 伪装物件预设库(POC):先用程序化 mesh 做可玩的最小闭环。
const PRESET_LIBRARY := [
	{
		"id": "crate",
		"name": "木箱",
		"mesh": "box",
		"size": Vector3(1.25, 1.0, 1.25),
		"offset": Vector3(0.0, 0.52, 0.0),
		"color": Color(0.56, 0.36, 0.18, 1.0),
		"tags": ["#box", "#cover"],
	},
	{
		"id": "barrel",
		"name": "铁桶",
		"mesh": "cylinder",
		"size": Vector3(0.95, 1.35, 0.95),
		"offset": Vector3(0.0, 0.68, 0.0),
		"color": Color(0.26, 0.30, 0.35, 1.0),
		"tags": ["#round", "#metal"],
	},
	{
		"id": "ball",
		"name": "圆球",
		"mesh": "sphere",
		"size": Vector3(1.15, 1.15, 1.15),
		"offset": Vector3(0.0, 0.58, 0.0),
		"color": Color(0.86, 0.73, 0.27, 1.0),
		"tags": ["#round", "#small"],
	},
	{
		"id": "cactus",
		"name": "仙人掌",
		"mesh": "cactus",
		"size": Vector3(0.78, 1.75, 0.78),
		"offset": Vector3(0.0, 0.88, 0.0),
		"color": Color(0.18, 0.48, 0.29, 1.0),
		"tags": ["#plant", "#tall"],
	},
	{
		"id": "barricade",
		"name": "矮路障",
		"mesh": "box",
		"size": Vector3(1.8, 0.62, 0.5),
		"offset": Vector3(0.0, 0.32, 0.0),
		"color": Color(0.84, 0.50, 0.12, 1.0),
		"tags": ["#low", "#wide"],
	},
	{
		"id": "human",
		"name": "解除伪装",
		"mesh": "none",
		"size": Vector3.ONE,
		"offset": Vector3.ZERO,
		"color": Color.WHITE,
		"tags": ["#reset"],
	},
]

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
var shift_owner: CharacterBody3D = null
var current_preset_index: int = 5  # 默认解除伪装
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
	print("[ShapeShift] Shifting to prop ", preset["name"])

	_animate_to_preset(preset)
	return true


func has_nearby_replicable_prop() -> bool:
	return _find_nearest_replicable_prop() != null


func try_replicate_nearby_prop() -> bool:
	var prop = _find_nearest_replicable_prop()
	if not prop:
		shift_failed.emit("no_nearby_prop")
		return false
	if is_shifting:
		shift_failed.emit("already_shifting")
		return false
	if cooldown_remaining > 0.0:
		shift_failed.emit("cooldown")
		return false
	if not prop.has_method("get_disguise_preset"):
		shift_failed.emit("invalid_prop")
		return false

	var preset: Dictionary = prop.get_disguise_preset()
	current_preset_index = -1
	is_shifting = true
	shift_started.emit(current_preset_index, preset)
	print("[ShapeShift] Replicating nearby prop ", preset.get("name", "prop"))
	_animate_to_preset(preset)
	return true


func has_nearby_fruit() -> bool:
	return has_nearby_replicable_prop()


func try_shift_nearby_fruit() -> bool:
	return try_replicate_nearby_prop()


func _animate_to_preset(preset: Dictionary) -> void:
	if not shift_owner:
		is_shifting = false
		return

	if shift_owner.has_method("apply_prop_disguise"):
		shift_owner.apply_prop_disguise.rpc(preset)
	await shift_owner.get_tree().create_timer(SHIFT_TRANSITION_TIME).timeout

	is_shifting = false
	cooldown_remaining = SHIFT_COOLDOWN
	shift_completed.emit(current_preset_index, preset)
	print("[ShapeShift] Shift completed, CD=", SHIFT_COOLDOWN, "s")


func _apply_preset_immediate(preset_index: int) -> void:
	# 立即应用,无动画(初始化用)
	var preset = get_preset(preset_index)
	if not shift_owner:
		return
	if shift_owner.has_method("apply_prop_disguise"):
		shift_owner.apply_prop_disguise(preset)


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
	if current_preset_index < 0:
		return {"id": "map_prop", "name": "Prop Replica", "tags": ["#prop"]}
	return get_preset(current_preset_index)


func is_shift_ready() -> bool:
	return cooldown_remaining <= 0.0 and not is_shifting


func _find_nearest_replicable_prop() -> Node3D:
	if not shift_owner or not shift_owner.is_inside_tree():
		return null

	var nearest: Node3D = null
	var nearest_dist := INF
	var origin := shift_owner.global_position
	for node in shift_owner.get_tree().get_nodes_in_group("replicable_props"):
		if not node is Node3D:
			continue
		var dist := origin.distance_to((node as Node3D).global_position)
		if dist <= REPLICATE_RANGE and dist < nearest_dist:
			nearest = node
			nearest_dist = dist
	return nearest
