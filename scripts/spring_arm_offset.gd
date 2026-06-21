extends Node3D
class_name SpringArmCharacter


const MOUSE_YAW_SENSIBILITY: float = 0.0068
const MOUSE_PITCH_SENSIBILITY: float = 0.0046
const PITCH_MIN: float = deg_to_rad(-68.0)
const PITCH_MAX: float = deg_to_rad(38.0)
const CAMERA_ZOOM_MIN: float = 3.6
const CAMERA_ZOOM_MAX: float = 7.0
const CAMERA_ZOOM_STEP: float = 0.45
const CAMERA_ZOOM_SMOOTHING: float = 12.0
const FOV_SMOOTHING: float = 10.0

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null

var _target_spring_length := 5.0
var _target_fov := 68.0
var _camera: Camera3D = null


func _ready() -> void:
	if _spring_arm:
		_target_spring_length = _spring_arm.spring_length
		_camera = _spring_arm.get_node_or_null("Camera3D") as Camera3D
	_target_fov = GameSettings.camera_fov
	if _camera:
		_camera.fov = _target_fov
	if not GameSettings.fov_changed.is_connected(_on_fov_changed):
		GameSettings.fov_changed.connect(_on_fov_changed)


func _process(delta: float) -> void:
	if not _spring_arm:
		return
	var smoothing := 1.0 - exp(-CAMERA_ZOOM_SMOOTHING * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _target_spring_length, smoothing)
	if _camera:
		var fov_smoothing := 1.0 - exp(-FOV_SMOOTHING * delta)
		_camera.fov = lerpf(_camera.fov, _target_fov, fov_smoothing)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not _spring_arm:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		rotate_y(-mouse_event.relative.x * MOUSE_YAW_SENSIBILITY)
		_spring_arm.rotate_x(-mouse_event.relative.y * MOUSE_PITCH_SENSIBILITY)
		_spring_arm.rotation.x = clampf(_spring_arm.rotation.x, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if not button_event.pressed:
			return
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_spring_length = max(CAMERA_ZOOM_MIN, _target_spring_length - CAMERA_ZOOM_STEP)
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_spring_length = min(CAMERA_ZOOM_MAX, _target_spring_length + CAMERA_ZOOM_STEP)


func _on_fov_changed(value: float) -> void:
	_target_fov = value
