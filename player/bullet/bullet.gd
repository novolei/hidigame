extends CharacterBody3D

const BULLET_VELOCITY := 20.0
const DEFAULT_TIME_ALIVE := 5.0
const IMPACT_PARTICLE_SECONDS := 0.52
const IMPACT_SURFACE_OFFSET := 0.018
const TRACER_REFERENCE_DISTANCE := 8.0
const TRACER_MIN_LENGTH_SCALE := 0.78
const TRACER_MAX_LENGTH_SCALE := 1.45

var time_alive := DEFAULT_TIME_ALIVE
var hit := false
var _travel_direction := Vector3.FORWARD
var _travel_remaining := 0.0
var _impact_position := Vector3.ZERO
var _impact_normal := Vector3.UP
var _tracer_width_scale := 1.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var bullet_body: Node3D = $BulletBody
@onready var machine_gun_tracer: Node3D = get_node_or_null("MachineGunTracer") as Node3D
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var explosion_audio: AudioStreamPlayer3D = $ExplosionAudio


func _ready() -> void:
	_disable_runtime_collision()
	_disable_reference_audio()
	_configure_tracer_for_distance(TRACER_REFERENCE_DISTANCE, false)
	play_flight()
	set_physics_process(false)


func launch_visual(start_position: Vector3, impact_position: Vector3, impact_normal: Vector3 = Vector3.UP, hit_prop: bool = false) -> void:
	var direction := impact_position - start_position
	var distance := direction.length()
	if distance <= 0.001:
		destroy()
		return
	_travel_direction = direction / distance
	_travel_remaining = distance
	_impact_normal = impact_normal.normalized() if impact_normal.length_squared() > 0.0001 else -_travel_direction
	_impact_position = impact_position + _impact_normal * IMPACT_SURFACE_OFFSET
	_tracer_width_scale = 1.14 if hit_prop else 1.0
	time_alive = DEFAULT_TIME_ALIVE
	hit = false
	top_level = true
	global_position = start_position
	global_transform.basis = _basis_from_negative_z_axis(_travel_direction)
	scale = Vector3.ONE * (1.04 if hit_prop else 0.94)
	_configure_tracer_for_distance(distance, hit_prop)
	play_flight()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if hit:
		return
	time_alive -= delta
	if time_alive <= 0.0:
		play_impact()
		return
	if _travel_remaining <= 0.0:
		play_impact()
		return
	var step := minf(BULLET_VELOCITY * delta, _travel_remaining)
	global_position += _travel_direction * step
	_travel_remaining -= step
	if _travel_remaining <= 0.001:
		global_position = _impact_position
		play_impact()


func _disable_runtime_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.disabled = true
	if multiplayer_synchronizer and is_instance_valid(multiplayer_synchronizer):
		multiplayer_synchronizer.queue_free()


func _disable_reference_audio() -> void:
	if not explosion_audio:
		return
	explosion_audio.stop()
	explosion_audio.stream = null
	explosion_audio.autoplay = false
	explosion_audio.volume_db = -80.0


func play_flight() -> void:
	visible = true
	_stop_reference_flight_particles()
	_stop_impact_particles()
	if bullet_body:
		bullet_body.visible = false
	_set_visible_if_present("MeshInstance3D", false)
	_set_visible_if_present("MeshInstance2", false)
	_set_machine_gun_tracer_visible(true)
	if omni_light:
		omni_light.shadow_enabled = false
		omni_light.light_color = Color(1.0, 0.67, 0.15, 1.0)
		omni_light.light_energy = 2.35
		omni_light.omni_range = 2.15
	if animation_player and animation_player.has_animation("RESET"):
		animation_player.play("RESET")


func play_impact() -> void:
	if hit:
		return
	hit = true
	set_physics_process(false)
	_disable_runtime_collision()
	_stop_reference_flight_particles()
	_set_machine_gun_tracer_visible(false)
	if bullet_body:
		bullet_body.visible = false
	_set_visible_if_present("MeshInstance3D", false)
	_set_visible_if_present("MeshInstance2", false)
	if omni_light:
		omni_light.shadow_enabled = false
		omni_light.light_color = Color(1.0, 0.72, 0.24, 1.0)
		omni_light.light_energy = 0.85
		omni_light.omni_range = 0.92
	_emit_hit_particles()
	var tween := create_tween()
	tween.tween_interval(IMPACT_PARTICLE_SECONDS)
	tween.tween_callback(destroy)


@rpc("call_local")
func explode() -> void:
	play_impact()


func destroy() -> void:
	queue_free()


func _configure_tracer_for_distance(distance: float, hit_prop: bool) -> void:
	if not machine_gun_tracer:
		return
	var length_scale := clampf(distance / TRACER_REFERENCE_DISTANCE, TRACER_MIN_LENGTH_SCALE, TRACER_MAX_LENGTH_SCALE)
	var width_scale := (1.18 if hit_prop else _tracer_width_scale)
	machine_gun_tracer.scale = Vector3(width_scale, width_scale, length_scale)


func _set_machine_gun_tracer_visible(should_show: bool) -> void:
	if machine_gun_tracer:
		machine_gun_tracer.visible = should_show


func _stop_reference_flight_particles() -> void:
	_set_particle_emitting("BulletBody/MainBody", false)
	_set_particle_emitting("BulletBody/Trail", false)


func _emit_hit_particles() -> void:
	_stop_impact_particles()
	_configure_particle_amount("Blast/BlastSparks", 22, 0.20)
	_configure_particle_amount("Blast/Smoke", 14, 0.26)
	_configure_particle_amount("Blast/LightParticle", 7, 0.20)
	_set_particle_emitting("Blast/BlastSparks", true)
	_set_particle_emitting("Blast/Smoke", true)
	_set_particle_emitting("Blast/LightParticle", true)


func _stop_impact_particles() -> void:
	for path: NodePath in [
		"Blast/BlastParticle",
		"Blast/LightBlast",
		"Blast/BlastSparks",
		"Blast/Smoke",
		"Blast/LightParticle",
		"Blast/InnerBlastLight",
	]:
		_set_particle_emitting(path, false)


func _configure_particle_amount(path: NodePath, amount: int, lifetime: float) -> void:
	var node := get_node_or_null(path)
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.amount = amount
		particles.lifetime = lifetime


func _set_particle_emitting(path: NodePath, should_emit: bool) -> void:
	var node := get_node_or_null(path)
	if node is GPUParticles3D:
		var gpu_particles := node as GPUParticles3D
		if should_emit:
			gpu_particles.restart()
		gpu_particles.emitting = should_emit
	elif node is CPUParticles3D:
		var cpu_particles := node as CPUParticles3D
		if should_emit:
			cpu_particles.restart()
		cpu_particles.emitting = should_emit


func _set_visible_if_present(path: NodePath, should_show: bool) -> void:
	var node := get_node_or_null(path)
	if node is Node3D:
		(node as Node3D).visible = should_show


func _basis_from_negative_z_axis(axis: Vector3) -> Basis:
	var forward := axis.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	var z := -forward
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.96:
		up = Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()
