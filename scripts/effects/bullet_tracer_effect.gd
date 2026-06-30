extends Node3D
class_name BulletTracerEffect
# =============================================================================
# BulletTracerEffect — lightweight hitscan tracer + muzzle flash for the AK47.
#
# Replaces the old single ImmediateMesh line. Tuned for a 600 RPM weapon fired
# by up to 6 hunters, so it stays cheap: a glowing additive beam rod, one
# white-hot core that streaks down the line, and a camera-facing muzzle flash.
# No per-bullet lights or particles (those live in BulletImpactEffect, which
# only spawns on actual surface hits). Reuses the already-shipped HOVL textures.
#
# Authority note: only ever spawned on clients that should see the shot; the
# WeaponSystem gates this off on a dedicated headless server.
# =============================================================================

const _SELF_SCRIPT := preload("res://scripts/effects/bullet_tracer_effect.gd")
const FLASH_TEXTURE_PATH := "res://assets/effects/hovl_projectiles/textures/Flash5.png"

const CORE_COLOR := Color(1.0, 0.95, 0.62, 1.0)   # white-hot bullet head
const HEAT_COLOR := Color(1.0, 0.52, 0.14, 1.0)   # orange tracer glow
const FLASH_COLOR := Color(1.0, 0.78, 0.32, 1.0)  # muzzle flash tint

const TRAVEL_TIME := 0.045
const FADE_TIME := 0.07
const MUZZLE_FLASH_TIME := 0.06
const BEAM_RADIUS := 0.011   # half-width of the (thin) tracer dash
const DASH_LENGTH := 0.85    # discontinuous tracer: a dash...
const DASH_GAP := 0.7        # ...then a gap, repeated down the path

var _start := Vector3.ZERO
var _end := Vector3.ZERO


static func spawn(parent: Node, start: Vector3, end: Vector3) -> BulletTracerEffect:
	if parent == null:
		return null
	var effect: BulletTracerEffect = _SELF_SCRIPT.new()
	effect.name = "BulletTracerEffect"
	parent.add_child(effect)
	effect.configure(start, end)
	return effect


func configure(start: Vector3, end: Vector3) -> void:
	top_level = true
	_start = start
	_end = end
	var direction := end - start
	if direction.length_squared() <= 0.0001:
		queue_free()
		return
	global_position = Vector3.ZERO
	_build_beam(start, end)
	_build_core(start, end)
	_build_muzzle_flash(start)
	_schedule_cleanup()


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

func _build_beam(start: Vector3, end: Vector3) -> void:
	# Thin, DISCONTINUOUS tracer: one ImmediateMesh of short camera-facing dash
	# quads (a single node regardless of dash count, so it stays cheap at 600 RPM).
	var total := start.distance_to(end)
	if total < 0.02:
		return
	var dir := (end - start) / total
	var cam := _camera_position()
	var im := ImmediateMesh.new()
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = im
	var material := _make_additive_material(CORE_COLOR, 4.4)
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 0.0
	while d < total:
		var a := start + dir * d
		var b := start + dir * minf(d + DASH_LENGTH, total)
		_emit_dash_quad(im, a, b, cam)
		d += DASH_LENGTH + DASH_GAP
	im.surface_end()
	var tween := beam.create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _emit_dash_quad(im: ImmediateMesh, a: Vector3, b: Vector3, cam: Vector3) -> void:
	var seg := b - a
	if seg.length_squared() < 0.000001:
		return
	var seg_dir := seg.normalized()
	var mid := (a + b) * 0.5
	var side := seg_dir.cross(cam - mid)
	if side.length_squared() < 0.000001:
		side = seg_dir.cross(Vector3.UP)
	side = side.normalized() * BEAM_RADIUS
	im.surface_add_vertex(a - side)
	im.surface_add_vertex(a + side)
	im.surface_add_vertex(b + side)
	im.surface_add_vertex(a - side)
	im.surface_add_vertex(b + side)
	im.surface_add_vertex(b - side)


func _camera_position() -> Vector3:
	var viewport := get_viewport()
	if viewport:
		var cam := viewport.get_camera_3d()
		if cam:
			return cam.global_position
	return _start + Vector3(0.0, 3.0, 4.0)


func _build_core(start: Vector3, end: Vector3) -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	var mesh := SphereMesh.new()
	mesh.radius = BEAM_RADIUS * 3.0
	mesh.height = BEAM_RADIUS * 6.0
	mesh.radial_segments = 8
	mesh.rings = 4
	core.mesh = mesh
	core.material_override = _make_additive_material(CORE_COLOR, 5.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	core.global_position = start
	var tween := core.create_tween()
	tween.tween_property(core, "global_position", end, TRAVEL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "scale", Vector3.ZERO, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _build_muzzle_flash(start: Vector3) -> void:
	# Bright camera-facing flash card (HOVL flash texture) + a small core bloom.
	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	flash.mesh = quad
	var material := _make_additive_material(FLASH_COLOR, 4.2)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var texture := load(FLASH_TEXTURE_PATH)
	if texture is Texture2D:
		material.albedo_texture = texture
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = start
	flash.scale = Vector3.ONE * 0.35
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.25, MUZZLE_FLASH_TIME * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3.ZERO, MUZZLE_FLASH_TIME * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _schedule_cleanup() -> void:
	var lifetime := maxf(TRAVEL_TIME + FADE_TIME, MUZZLE_FLASH_TIME) + 0.05
	var tween := create_tween()
	tween.tween_interval(lifetime)
	tween.tween_callback(queue_free)


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
