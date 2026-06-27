class_name CardDecoyTarget
extends StaticBody3D

const DEFAULT_HEALTH := 35.0
const DEFAULT_HEIGHT := 1.8
const DEFAULT_RADIUS := 0.36

var source_owner: Node3D = null
var follow_owner := false
var follow_local_offset := Vector3.ZERO
var health := DEFAULT_HEALTH
var _expires_after := 0.0
var _age := 0.0
var _visual: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("card_decoy_targets")
	collision_layer = 1
	collision_mask = 0
	_ensure_collision()
	_ensure_visual()


func configure(next_owner: Node3D, duration: float, local_offset: Vector3 = Vector3.ZERO, should_follow := false, max_health := DEFAULT_HEALTH) -> void:
	source_owner = next_owner
	follow_owner = should_follow
	follow_local_offset = local_offset
	_expires_after = maxf(duration, 0.1)
	health = maxf(max_health, 1.0)
	if source_owner and is_instance_valid(source_owner):
		global_position = _target_position()
		global_rotation.y = source_owner.global_rotation.y
		if is_inside_tree():
			reset_physics_interpolation()
	_ensure_collision()
	_ensure_visual()


func _process(delta: float) -> void:
	_age += delta
	if follow_owner and source_owner and is_instance_valid(source_owner):
		global_position = global_position.lerp(_target_position(), clampf(delta * 8.0, 0.0, 1.0))
		global_rotation.y = lerp_angle(global_rotation.y, source_owner.global_rotation.y, clampf(delta * 6.0, 0.0, 1.0))
		_apply_idle_motion()
	if _expires_after > 0.0 and _age >= _expires_after:
		_despawn(false)


func take_damage(amount: float, _attacker_id: int, _is_headshot: bool = false) -> void:
	health = maxf(0.0, health - maxf(amount, 0.0))
	_flash_hit()
	if health <= 0.0:
		_despawn(true)


func get_health() -> float:
	return health


func is_prop() -> bool:
	return true


func is_card_decoy_target() -> bool:
	return true


func get_auto_turret_priority() -> float:
	return 1000.0


func get_hunter_prop_sense_position() -> Vector3:
	return global_position + Vector3.UP * (DEFAULT_HEIGHT * 0.5)


func get_auto_turret_aim_point() -> Vector3:
	return get_hunter_prop_sense_position()


func _target_position() -> Vector3:
	if not source_owner or not is_instance_valid(source_owner):
		return global_position
	return source_owner.global_position + source_owner.global_transform.basis * follow_local_offset + Vector3.UP * 0.9


func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D"):
		return
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = DEFAULT_RADIUS
	shape.height = DEFAULT_HEIGHT
	shape_node.shape = shape
	shape_node.position = Vector3.UP * (DEFAULT_HEIGHT * 0.5)
	add_child(shape_node)


func _ensure_visual() -> void:
	if _visual and is_instance_valid(_visual):
		return
	_visual = MeshInstance3D.new()
	_visual.name = "CardDecoyVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = DEFAULT_RADIUS
	mesh.height = DEFAULT_HEIGHT
	mesh.radial_segments = 16
	mesh.rings = 8
	_visual.mesh = mesh
	_visual.position = Vector3.UP * (DEFAULT_HEIGHT * 0.5)
	_material = StandardMaterial3D.new()
	_material.resource_local_to_scene = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.50, 0.86, 1.0, 0.42)
	_material.emission_enabled = true
	_material.emission = Color(0.14, 0.60, 1.0, 1.0)
	_material.emission_energy_multiplier = 0.82
	_visual.material_override = _material
	add_child(_visual)


func _apply_idle_motion() -> void:
	if not _visual:
		return
	var pulse := 1.0 + sin((_age * 4.8) + float(get_instance_id() % 13)) * 0.035
	_visual.scale = Vector3(pulse, 1.0 + sin(_age * 3.1) * 0.025, pulse)


func _flash_hit() -> void:
	if not _material:
		return
	_material.albedo_color = Color(0.95, 1.0, 1.0, 0.68)
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", Color(0.50, 0.86, 1.0, 0.42), 0.16)


func _despawn(destroyed: bool) -> void:
	if not is_inside_tree():
		queue_free()
		return
	set_process(false)
	collision_layer = 0
	var tween := create_tween()
	var final_scale := Vector3.ONE * (1.35 if destroyed else 0.78)
	tween.parallel().tween_property(self, "scale", final_scale, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _material:
		tween.parallel().tween_property(_material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(queue_free)
