extends Node3D
# Single-player preview for the AK47 VFX (muzzle flash + tracer + surface impact,
# plus an occasional green-blood "organic hit"). No match, role, or ammo needed —
# just open scenes/effects/bullet_vfx_preview.tscn and press F6 (Run Current
# Scene). It auto-builds a camera/light/ground/target wall and loops the effects
# so you can eyeball and tune them. This is an authoring/preview tool, not part
# of the shipped game.

const TracerScript := preload("res://scripts/effects/bullet_tracer_effect.gd")
const ImpactScript := preload("res://scripts/effects/bullet_impact_effect.gd")

const WALL_Z := -3.0
const FIRE_INTERVAL := 0.14

var _muzzle := Vector3(-2.2, 1.35, 4.5)
var _elapsed := 0.0


func _ready() -> void:
	_build_environment()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= FIRE_INTERVAL:
		_elapsed = 0.0
		_fire_once()


func _fire_once() -> void:
	var target := Vector3(randf_range(-3.2, 3.2), randf_range(0.7, 3.3), WALL_Z + 0.26)
	var dir := (target - _muzzle).normalized()
	TracerScript.spawn(self, _muzzle, target)
	ImpactScript.spawn(self, target, Vector3.BACK, dir)


func _build_environment() -> void:
	var cam := Camera3D.new()
	cam.name = "PreviewCamera"
	cam.current = true
	cam.position = Vector3(0.0, 2.0, 7.5)
	cam.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	add_child(cam)

	var light := DirectionalLight3D.new()
	light.name = "PreviewSun"
	light.rotation_degrees = Vector3(-52.0, -40.0, 0.0)
	light.light_energy = 1.1
	add_child(light)

	# Glow so the additive tracer/impact VFX bloom like they do in-game.
	var world_env := WorldEnvironment.new()
	world_env.name = "PreviewEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.25
	world_env.environment = env
	add_child(world_env)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(40.0, 40.0)
	ground.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.18, 0.2, 0.23)
	ground.material_override = ground_mat
	add_child(ground)

	var wall := MeshInstance3D.new()
	wall.name = "TargetWall"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(9.0, 5.0, 0.5)
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 2.0, WALL_Z)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.34, 0.32, 0.3)
	wall.material_override = wall_mat
	add_child(wall)
