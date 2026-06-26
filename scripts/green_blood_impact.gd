extends Node3D
class_name GreenBloodImpact

const GRASS_BLOOD_COLOR := Color(0.35, 0.96, 0.20, 1.0)
const CLEANUP_SECONDS := 1.35
const DROPLET_COUNT := 14
const SPRAY_COUNT := 30

var _impact_normal := Vector3.UP
var _spray_direction := Vector3.UP
var _particles: GPUParticles3D = null

static func spawn(parent: Node, position: Vector3, normal: Vector3, shooter_direction: Vector3 = Vector3.ZERO) -> GreenBloodImpact:
	if parent == null:
		return null
	var effect := GreenBloodImpact.new()
	effect.name = "GreenBloodImpact"
	parent.add_child(effect)
	effect.configure(position, normal, shooter_direction)
	return effect


func configure(position: Vector3, normal: Vector3, shooter_direction: Vector3 = Vector3.ZERO) -> void:
	top_level = true
	global_position = position
	_impact_normal = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	_spray_direction = _impact_normal
	if shooter_direction.length_squared() > 0.001:
		_spray_direction = (-shooter_direction.normalized() + _impact_normal * 0.75).normalized()
	_build_effect()
	call_deferred("_play")


func _build_effect() -> void:
	_spawn_particle_spray()
	_spawn_mesh_droplets()
	_spawn_impact_splat()


func _spawn_particle_spray() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Spray"
	particles.amount = SPRAY_COUNT
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = _spray_direction
	process_material.spread = 34.0
	process_material.gravity = Vector3(0.0, -6.6, 0.0)
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 4.7
	process_material.damping_min = 0.35
	process_material.damping_max = 1.2
	process_material.scale_min = 0.035
	process_material.scale_max = 0.095
	process_material.color = GRASS_BLOOD_COLOR
	particles.process_material = process_material
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _make_blood_material(0.95)
	particles.draw_pass_1 = mesh
	add_child(particles)
	_particles = particles


func _spawn_mesh_droplets() -> void:
	for index in range(DROPLET_COUNT):
		var droplet := MeshInstance3D.new()
		droplet.name = "Droplet%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.025, 0.065)
		mesh.height = mesh.radius * 1.8
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = _make_blood_material(0.92)
		droplet.mesh = mesh
		droplet.position = _impact_normal * 0.045
		add_child(droplet)
		var tangent_a := _impact_normal.cross(Vector3.UP)
		if tangent_a.length_squared() <= 0.001:
			tangent_a = _impact_normal.cross(Vector3.RIGHT)
		tangent_a = tangent_a.normalized()
		var tangent_b := _impact_normal.cross(tangent_a).normalized()
		var angle := randf() * TAU
		var sideways := tangent_a * cos(angle) + tangent_b * sin(angle)
		var travel := (_spray_direction * randf_range(0.45, 1.25) + sideways * randf_range(0.1, 0.55) + Vector3.UP * randf_range(0.0, 0.35)).normalized()
		var target := droplet.position + travel * randf_range(0.35, 1.15)
		var tween := droplet.create_tween()
		tween.set_parallel(true)
		tween.tween_property(droplet, "position", target, randf_range(0.42, 0.78)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(droplet, "scale", Vector3.ZERO, randf_range(0.72, CLEANUP_SECONDS)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _spawn_impact_splat() -> void:
	var splat := MeshInstance3D.new()
	splat.name = "ImpactSplat"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.18
	mesh.height = 0.012
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = _make_blood_material(0.74)
	splat.mesh = mesh
	splat.position = _impact_normal * 0.018
	add_child(splat)
	_orient_child_to_normal(splat)
	var tween := splat.create_tween()
	tween.set_parallel(true)
	tween.tween_property(splat, "scale", Vector3(1.55, 0.18, 1.55), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(splat, "scale", Vector3.ZERO, CLEANUP_SECONDS).set_delay(0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _orient_child_to_normal(child: Node3D) -> void:
	var up := _impact_normal
	var forward := up.cross(Vector3.RIGHT)
	if forward.length_squared() <= 0.001:
		forward = up.cross(Vector3.FORWARD)
	forward = forward.normalized()
	var right := forward.cross(up).normalized()
	child.basis = Basis(right, up, forward).orthonormalized()


func _make_blood_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(GRASS_BLOOD_COLOR.r, GRASS_BLOOD_COLOR.g, GRASS_BLOOD_COLOR.b, alpha)
	material.emission_enabled = true
	material.emission = GRASS_BLOOD_COLOR
	material.emission_energy_multiplier = 0.45
	material.roughness = 0.42
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _play() -> void:
	if _particles and is_instance_valid(_particles):
		_particles.restart()
		_particles.emitting = true
	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(CLEANUP_SECONDS)
	cleanup_tween.tween_callback(queue_free)
