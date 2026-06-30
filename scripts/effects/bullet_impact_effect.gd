extends Node3D
class_name BulletImpactEffect
# =============================================================================
# BulletImpactEffect — AK47 bullet hitting world geometry / props.
#
# HOVL-style hot impact: a camera-facing flash, an expanding shockwave ring on
# the surface, a one-shot spark spray bounced off the surface, a couple of drift
# smoke puffs, and a scorch mark that fades. Player hits keep using the existing
# GreenBloodImpact; this is only for non-player surfaces.
#
# Kept lean (1 spark particle system + a handful of tween-driven meshes) because
# it can fire on every wall-bullet of a 600 RPM weapon. Reuses already-shipped
# HOVL textures. Never built on a dedicated headless server (WeaponSystem gate).
# =============================================================================

const _SELF_SCRIPT := preload("res://scripts/effects/bullet_impact_effect.gd")
const TEXTURE_ROOT := "res://assets/effects/hovl_projectiles/textures/"
const FLASH_TEXTURE := "Flash5.png"
const RING_TEXTURE := "Rays3.png"
const SMOKE_TEXTURE := "Smoke21.png"

const FLASH_COLOR := Color(1.0, 0.82, 0.36, 1.0)
const SPARK_COLOR := Color(1.0, 0.66, 0.18, 1.0)
const RING_COLOR := Color(1.0, 0.58, 0.2, 1.0)
const SMOKE_COLOR := Color(0.32, 0.3, 0.28, 0.5)
const SCORCH_COLOR := Color(0.05, 0.04, 0.035, 0.85)

const SPARK_COUNT := 20
const EMBER_COUNT := 14
const CLEANUP_SECONDS := 0.9

var _normal := Vector3.UP
var _spray_dir := Vector3.UP
var _sparks: GPUParticles3D = null
var _embers: GPUParticles3D = null


static func spawn(parent: Node, world_pos: Vector3, normal: Vector3, incoming_dir: Vector3 = Vector3.ZERO) -> BulletImpactEffect:
	if parent == null:
		return null
	var effect: BulletImpactEffect = _SELF_SCRIPT.new()
	effect.name = "BulletImpactEffect"
	parent.add_child(effect)
	effect.configure(world_pos, normal, incoming_dir)
	return effect


func configure(world_pos: Vector3, normal: Vector3, incoming_dir: Vector3 = Vector3.ZERO) -> void:
	top_level = true
	global_position = world_pos
	_normal = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	# Sparks bounce back off the surface: reflect the incoming direction, biased
	# along the surface normal so they spray away from the wall.
	if incoming_dir.length_squared() > 0.001:
		var reflected := incoming_dir.normalized().bounce(_normal)
		_spray_dir = (reflected + _normal * 0.6).normalized()
	else:
		_spray_dir = _normal
	_build_flash()
	_build_ring()
	_build_sparks()
	_build_embers()
	_build_smoke()
	_build_scorch()
	call_deferred("_play")


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

func _build_flash() -> void:
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	flash.mesh = quad
	var material := _make_additive_material(FLASH_COLOR, 4.4)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_apply_texture(material, FLASH_TEXTURE)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = _normal * 0.04
	add_child(flash)
	flash.scale = Vector3.ONE * 0.3
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.2, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ShockRing"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	ring.mesh = quad
	var material := _make_additive_material(RING_COLOR, 2.8)
	_apply_texture(material, RING_TEXTURE)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = _normal * 0.02
	_orient_to_normal(ring)
	ring.scale = Vector3.ONE * 0.25
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.6, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _build_sparks() -> void:
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = SPARK_COUNT
	sparks.lifetime = 0.45
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.emitting = false
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.direction = _spray_dir
	process.spread = 42.0
	process.gravity = Vector3(0.0, -9.0, 0.0)
	process.initial_velocity_min = 3.5
	process.initial_velocity_max = 7.5
	process.damping_min = 0.4
	process.damping_max = 1.4
	process.scale_min = 0.02
	process.scale_max = 0.06
	process.color = SPARK_COLOR
	sparks.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _make_additive_material(SPARK_COLOR, 3.6)
	sparks.draw_pass_1 = mesh
	add_child(sparks)
	_sparks = sparks


func _build_embers() -> void:
	# Slower, lingering glowing motes for a richer particle cloud (on top of the
	# fast sparks). Lighter gravity + longer life so they drift and fade.
	var embers := GPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = EMBER_COUNT
	embers.lifetime = 0.8
	embers.one_shot = true
	embers.explosiveness = 0.85
	embers.local_coords = false
	embers.emitting = false
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.direction = _spray_dir
	process.spread = 75.0
	process.gravity = Vector3(0.0, -4.0, 0.0)
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 4.0
	process.damping_min = 0.6
	process.damping_max = 1.8
	process.scale_min = 0.012
	process.scale_max = 0.035
	process.color = SPARK_COLOR.lerp(Color(1.0, 0.85, 0.4, 1.0), 0.4)
	embers.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.material = _make_additive_material(SPARK_COLOR, 3.0)
	embers.draw_pass_1 = mesh
	add_child(embers)
	_embers = embers


func _build_smoke() -> void:
	for index in range(2):
		var puff := MeshInstance3D.new()
		puff.name = "Smoke%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		puff.mesh = quad
		var material := _make_blended_material(SMOKE_COLOR)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_apply_texture(material, SMOKE_TEXTURE)
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sideways := _normal.cross(Vector3.UP)
		if sideways.length_squared() <= 0.001:
			sideways = _normal.cross(Vector3.RIGHT)
		sideways = sideways.normalized() * (0.12 if index == 0 else -0.12)
		puff.position = _normal * 0.06 + sideways
		add_child(puff)
		puff.scale = Vector3.ONE * 0.2
		var drift := puff.position + _normal * 0.25 + Vector3.UP * 0.2
		var tween := puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position", drift, CLEANUP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.85, CLEANUP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var alpha_target := Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.0)
		tween.tween_property(material, "albedo_color", alpha_target, CLEANUP_SECONDS).set_delay(0.12)


func _build_scorch() -> void:
	var scorch := MeshInstance3D.new()
	scorch.name = "Scorch"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	scorch.mesh = quad
	var material := _make_blended_material(SCORCH_COLOR)
	_apply_texture(material, RING_TEXTURE)
	scorch.material_override = material
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scorch.position = _normal * 0.012
	add_child(scorch)
	_orient_to_normal(scorch)
	scorch.scale = Vector3.ONE * 0.4
	var tween := scorch.create_tween()
	tween.tween_interval(CLEANUP_SECONDS * 0.4)
	var fade := Color(SCORCH_COLOR.r, SCORCH_COLOR.g, SCORCH_COLOR.b, 0.0)
	tween.tween_property(material, "albedo_color", fade, CLEANUP_SECONDS * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# -----------------------------------------------------------------------------
# Play / cleanup
# -----------------------------------------------------------------------------

func _play() -> void:
	if _sparks and is_instance_valid(_sparks):
		_sparks.restart()
		_sparks.emitting = true
	if _embers and is_instance_valid(_embers):
		_embers.restart()
		_embers.emitting = true
	var cleanup := create_tween()
	cleanup.tween_interval(CLEANUP_SECONDS + 0.2)
	cleanup.tween_callback(queue_free)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _orient_to_normal(child: Node3D) -> void:
	# QuadMesh faces +Z; align +Z with the surface normal so the card lies flat.
	var forward := _normal
	var up := forward.cross(Vector3.RIGHT)
	if up.length_squared() <= 0.001:
		up = forward.cross(Vector3.FORWARD)
	up = up.normalized()
	var right := up.cross(forward).normalized()
	child.basis = Basis(right, up, forward).orthonormalized()


func _apply_texture(material: StandardMaterial3D, texture_name: String) -> void:
	var texture := load(TEXTURE_ROOT + texture_name)
	if texture is Texture2D:
		material.albedo_texture = texture


func _make_additive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_blended_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
