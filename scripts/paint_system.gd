extends Node
class_name PaintSystem
# =============================================================================
# PaintSystem — 喷涂系统(v0.3.3)
#
# 设计:
#   - 藏匿者专用
#   - 无颜料限制(v0.3 取消颜料槽)
#   - 按住鼠标右键 → 从准星方向采样环境色 → 应用到玩家身体
#   - 模拟约束:只能涂装,不能复制物体本身
#
# 注意:
#   - 本系统是本地客户端逻辑(喷涂是即时视觉反馈)
#   - 服务器不需要同步喷涂状态(简化,所有端各自处理)
# =============================================================================

# -----------------------------------------------------------------------------
# 配置
# -----------------------------------------------------------------------------
const PAINT_RANGE: float = 30.0          # 喷涂射线最大距离
const PAINT_SAMPLE_RADIUS: float = 0.5  # 采样范围
const PAINT_DECAY_RATE: float = 0.5     # 褪色率(%/s,静置时)
const PAINT_RAIN_DECAY: float = 50.0    # 雨空投导致的瞬间褪色(%)

# 身体 mesh 路径(从 player.tscn 推断)
const BODY_MESH_PATHS := [
	"3DGodotRobot/RobotArmature/Skeleton3D/Bottom",
	"3DGodotRobot/RobotArmature/Skeleton3D/Chest",
	"3DGodotRobot/RobotArmature/Skeleton3D/Face",
	"3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head",
]

# -----------------------------------------------------------------------------
# 状态
# -----------------------------------------------------------------------------
var is_painting: bool = false
var paint_owner: CharacterBody3D = null
var camera: Camera3D = null
var current_paint_percent: float = 0.0  # 0.0 ~ 100.0(实际 v0.3 无限制,这里只用作褪色追踪)
var target_color: Color = Color.WHITE   # 当前喷涂目标色
var last_paint_time: float = 0.0        # 上次喷涂时间(用于褪色)

# 信号
signal paint_started
signal paint_stopped
signal paint_progress(percent: float)  # 0.0 ~ 100.0
signal paint_target_color_changed(color: Color)


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# 持续按住喷涂时,持续应用 target_color 到身体
	if is_painting and paint_owner:
		_apply_color_to_body(target_color, delta * 30.0)  # 每秒增加 30% 覆盖
		current_paint_percent = min(100.0, current_paint_percent + delta * 30.0)
		last_paint_time = Time.get_ticks_msec() / 1000.0
		paint_progress.emit(current_paint_percent)

	# 静置褪色(v0.3 仍然有,只是无颜料限制不代表不变色)
	if not is_painting and current_paint_percent > 0.0:
		var time_since_paint = Time.get_ticks_msec() / 1000.0 - last_paint_time
		if time_since_paint > 30.0:  # 静置 30s 后开始褪色
			current_paint_percent = max(0.0, current_paint_percent - PAINT_DECAY_RATE * delta)
			_decay_body_toward_white(delta * PAINT_DECAY_RATE)
			paint_progress.emit(current_paint_percent)


func initialize(owner_node: CharacterBody3D, owner_camera: Camera3D) -> void:
	paint_owner = owner_node
	camera = owner_camera


# =============================================================================
# 喷涂控制
# =============================================================================

func start_paint() -> void:
	# 按下右键时,从准星采样一次颜色
	if not paint_owner or not camera:
		return

	var sampled = _sample_environment_color()
	if sampled != null:
		target_color = sampled
		paint_target_color_changed.emit(target_color)

	is_painting = true
	paint_started.emit()
	print("[Paint] Started painting with color: ", target_color)


func stop_paint() -> void:
	is_painting = false
	last_paint_time = Time.get_ticks_msec() / 1000.0
	paint_stopped.emit()


# =============================================================================
# 环境采样(从准星射线)
# =============================================================================

func _sample_environment_color() -> Color:
	# 从 camera 中心发一条短射线,采样击中物体的颜色
	if not paint_owner or not camera:
		return Color.WHITE

	var space_state = paint_owner.get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * PAINT_RANGE

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [paint_owner.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if not result:
		return Color.WHITE

	# 击中物体,从其材质采样颜色
	var collider = result.collider
	if collider is MeshInstance3D:
		var mat = (collider as MeshInstance3D).get_surface_override_material(0)
		if mat == null:
			mat = (collider as MeshInstance3D).get_active_material(0)
		if mat and mat is StandardMaterial3D:
			return (mat as StandardMaterial3D).albedo_color

	# 默认返回基于碰撞点位置的环境色(简化:用 hit position 计算)
	return _sample_color_from_position(result.position)


func _sample_color_from_position(pos: Vector3) -> Color:
	# 简化版:基于位置返回区域颜色
	# 实际应该从 world environment 采样,这里用启发式
	var base = Color(0.5, 0.5, 0.5)
	# 不同区域给不同颜色(让玩家能区分)
	if abs(pos.x) < 5 and abs(pos.z) < 5:
		base = Color(0.4, 0.7, 0.4)  # 中央绿
	elif pos.z > 20:
		base = Color(0.7, 0.5, 0.3)  # 北橙
	elif pos.z < -20:
		base = Color(0.5, 0.5, 0.7)  # 南蓝
	elif pos.x > 20:
		base = Color(0.7, 0.6, 0.4)  # 东黄
	elif pos.x < -20:
		base = Color(0.6, 0.4, 0.6)  # 西紫
	return base


# =============================================================================
# 应用颜色到身体
# =============================================================================

func _apply_color_to_body(color: Color, strength: float) -> void:
	# 遍历所有身体 mesh,改 albedo_color(blend 到目标色)
	for path in BODY_MESH_PATHS:
		var mesh = paint_owner.get_node_or_null(path) as MeshInstance3D
		if not mesh:
			continue
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(i)
			if mat == null:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color.WHITE
				mesh.set_surface_override_material(i, mat)
			if mat is StandardMaterial3D:
				var current = (mat as StandardMaterial3D).albedo_color
				(mat as StandardMaterial3D).albedo_color = current.lerp(color, clamp(strength * 0.05, 0.0, 1.0))


func _decay_body_toward_white(strength: float) -> void:
	# 褪色:向白色 lerp
	for path in BODY_MESH_PATHS:
		var mesh = paint_owner.get_node_or_null(path) as MeshInstance3D
		if not mesh:
			continue
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				var current = (mat as StandardMaterial3D).albedo_color
				(mat as StandardMaterial3D).albedo_color = current.lerp(Color.WHITE, clamp(strength * 0.01, 0.0, 1.0))


# =============================================================================
# 外部 API
# =============================================================================

func reset_paint() -> void:
	current_paint_percent = 0.0
	target_color = Color.WHITE
	for path in BODY_MESH_PATHS:
		var mesh = paint_owner.get_node_or_null(path) as MeshInstance3D
		if not mesh:
			continue
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = Color.WHITE
	paint_progress.emit(0.0)


# 模拟雨空投:瞬间大量褪色
func apply_rain_decay() -> void:
	current_paint_percent = max(0.0, current_paint_percent - PAINT_RAIN_DECAY)
	for path in BODY_MESH_PATHS:
		var mesh = paint_owner.get_node_or_null(path) as MeshInstance3D
		if not mesh:
			continue
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				var current = (mat as StandardMaterial3D).albedo_color
				(mat as StandardMaterial3D).albedo_color = current.lerp(Color.WHITE, 0.5)
	paint_progress.emit(current_paint_percent)


func get_paint_percent() -> float:
	return current_paint_percent