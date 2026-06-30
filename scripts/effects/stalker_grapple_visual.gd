extends Node3D
class_name StalkerGrappleVisual
# =============================================================================
# StalkerGrappleVisual — AAA energy grapple: flowing cable, biting claw, impact.
#
# Lifecycle (driven from a single phase timer so the rope tracks the moving
# shooter every frame):
#   1. EXTEND  — claw shoots out from the hand to the anchor; rope sags behind it
#                with a quick launch burst at the hand.
#   2. PULL    — claw bites (impact burst + clamp punch); the cable snaps taut,
#                vibrates under tension, and energy pulses reel toward the hand.
#   3. RETRACT — claw is yanked home; the cable fades out.
#
# The cable is a per-frame camera-facing ribbon (ImmediateMesh) using
# shaders/grapple_rope.gdshader. A moving light + HOVL-textured bursts give it
# the glow pop. Grapple is a rare ability (long cooldown, one per stalker), so a
# real light + particle bursts are affordable here. Only ever spawned on clients
# that should see it (WeaponSystem/grapple system gate dedicated servers).
# =============================================================================

# Self-preload so spawn() can instantiate without the global class_name registry.
# A class_name added after the shipped baseline is NOT in the baked registry, so
# bare StalkerGrappleVisual.new() fails when this file ships in a core_patch.
const _SELF_SCRIPT := preload("res://scripts/effects/stalker_grapple_visual.gd")
const HOOK_SCENE: PackedScene = preload("res://scenes/effects/stalker_grapple_hook.tscn")
const ROPE_SHADER: Shader = preload("res://shaders/grapple_rope.gdshader")

const TEXTURE_ROOT := "res://assets/effects/hovl_projectiles/textures/"
const FLOW_TEXTURE := "Noise35t.png"
const FLASH_TEXTURE := "Flash5.png"
const RING_TEXTURE := "Rays3.png"

const CORE_COLOR := Color(0.80, 0.94, 1.0, 1.0)   # white-hot energy core
const EDGE_COLOR := Color(0.12, 0.48, 1.0, 1.0)   # electric blue
const ACCENT_COLOR := Color(0.55, 0.85, 1.0, 1.0) # flashes / sparks / light

const RETRACT_DURATION := 0.16
const CLAW_SPIN_SPEED := 26.0
const ROPE_SEGMENTS := 16
const ROPE_WIDTH := 0.06
# Phase durations are derived from the cast distance so the visual matches the
# two-phase gameplay: the hook flies out (extend) at HOOK_SPEED, then the reel
# (pull) runs at PULL_REF_SPEED. Keep HOOK_SPEED == the grapple system's
# HOOK_FLIGHT_SPEED so the claw lands exactly when the pull begins.
const HOOK_SPEED := 85.0
const HOOK_MIN := 0.08
const HOOK_MAX := 0.55
const PULL_REF_SPEED := 24.0
const PULL_MIN := 0.18
const PULL_MAX := 1.4
const ANCHOR_RING_COLOR := Color(0.40, 1.0, 0.70, 1.0)  # green-cyan target marker
# Cast/impact SFX. No dedicated grapple sound ships yet, so reuse the closest
# existing clips (pitched) — swap these paths for bespoke grapple SFX later.
const CAST_SFX := "res://resources/audio/grapple_cast.mp3"     # hook launch (user-supplied)
const IMPACT_SFX := "res://assets/audio/player/robot_land.wav" # hook bite thunk

var _shooter: Node3D = null
var _anchor := Vector3.ZERO
var _extend_duration := 0.08
var _pull_duration := 0.28
var _total := 0.0
var _elapsed := 0.0
var _started := false
var _impact_done := false
var _missed := false

var _claw: Node3D = null
var _claw_halo: MeshInstance3D = null
var _rope: MeshInstance3D = null
var _rope_im: ImmediateMesh = null
var _rope_mat: ShaderMaterial = null
var _light: OmniLight3D = null
var _motes: Array[MeshInstance3D] = []
var _anchor_ring: MeshInstance3D = null


static func spawn(parent: Node, shooter: Node3D, muzzle_origin: Vector3, anchor: Vector3, pull_duration: float, is_miss: bool = false) -> StalkerGrappleVisual:
	if parent == null or shooter == null:
		return null
	var visual: StalkerGrappleVisual = _SELF_SCRIPT.new()
	visual.name = "StalkerGrappleVisual"
	parent.add_child(visual)
	visual.fire(shooter, muzzle_origin, anchor, pull_duration, is_miss)
	return visual


func fire(shooter: Node3D, _muzzle_origin: Vector3, anchor: Vector3, _pull_duration_hint: float, is_miss: bool = false) -> void:
	_shooter = shooter
	_anchor = anchor
	_missed = is_miss
	# Derive both phase times from the cast distance so the claw lands exactly
	# when the gameplay pull begins (hook flight), then reels in (pull). A miss
	# skips the pull phase entirely: the hook flies out and retracts.
	var span: float = _hand_point().distance_to(anchor)
	_extend_duration = clampf(span / HOOK_SPEED, HOOK_MIN, HOOK_MAX)
	_pull_duration = 0.0 if is_miss else clampf(span / PULL_REF_SPEED, PULL_MIN, PULL_MAX)
	_total = _extend_duration + _pull_duration + RETRACT_DURATION
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build()
	_spawn_launch_burst(_hand_point())
	_update_visual(0.0)
	_started = true


func _process(delta: float) -> void:
	if not _started:
		return
	if _shooter == null or not is_instance_valid(_shooter):
		queue_free()
		return
	_elapsed += delta
	# Spin only while the claw is in flight; a biting claw shouldn't keep spinning.
	if _claw and is_instance_valid(_claw) and _elapsed < _extend_duration:
		_claw.rotate_object_local(Vector3.FORWARD, CLAW_SPIN_SPEED * delta)
	_update_visual(_elapsed)
	if _elapsed >= _total:
		queue_free()


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

func _build() -> void:
	_claw = HOOK_SCENE.instantiate()
	_claw.name = "Claw"
	add_child(_claw)

	# Soft additive halo around the claw head; flashes on the bite.
	_claw_halo = MeshInstance3D.new()
	_claw_halo.name = "ClawHalo"
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.22
	halo_mesh.height = 0.44
	halo_mesh.radial_segments = 10
	halo_mesh.rings = 6
	_claw_halo.mesh = halo_mesh
	_claw_halo.material_override = _make_additive_material(ACCENT_COLOR, 2.4)
	_claw_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_claw.add_child(_claw_halo)

	_rope_mat = ShaderMaterial.new()
	_rope_mat.shader = ROPE_SHADER
	_rope_mat.set_shader_parameter("core_color", Vector3(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b))
	_rope_mat.set_shader_parameter("edge_color", Vector3(EDGE_COLOR.r, EDGE_COLOR.g, EDGE_COLOR.b))
	_rope_mat.set_shader_parameter("energy", 3.2)
	_rope_mat.set_shader_parameter("tiling", 5.0)
	_rope_mat.set_shader_parameter("alpha_mul", 0.0)
	var flow_tex := load(TEXTURE_ROOT + FLOW_TEXTURE)
	if flow_tex is Texture2D:
		_rope_mat.set_shader_parameter("flow_tex", flow_tex)

	_rope_im = ImmediateMesh.new()
	_rope = MeshInstance3D.new()
	_rope.name = "Rope"
	_rope.mesh = _rope_im
	_rope.material_override = _rope_mat
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.extra_cull_margin = 16.0
	add_child(_rope)

	_light = OmniLight3D.new()
	_light.name = "GrappleLight"
	_light.light_color = ACCENT_COLOR
	_light.light_energy = 3.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)

	# Target-lock ring at the anchor (like the reference): a glowing torus that
	# faces the camera, spins, and fades out on retract.
	_anchor_ring = MeshInstance3D.new()
	_anchor_ring.name = "AnchorRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.26
	ring_mesh.outer_radius = 0.40
	_anchor_ring.mesh = ring_mesh
	_anchor_ring.material_override = _make_additive_material(ANCHOR_RING_COLOR, 3.4)
	_anchor_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anchor_ring.visible = false
	add_child(_anchor_ring)

	# Energy pulses that reel from the anchor back to the hand during the pull.
	for index in range(3):
		var mote := MeshInstance3D.new()
		mote.name = "ReelMote%d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.1
		mesh.radial_segments = 8
		mesh.rings = 4
		mote.mesh = mesh
		mote.material_override = _make_additive_material(CORE_COLOR, 4.5)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.visible = false
		add_child(mote)
		_motes.append(mote)


# -----------------------------------------------------------------------------
# Per-frame update
# -----------------------------------------------------------------------------

func _update_visual(elapsed: float) -> void:
	var hand: Vector3 = _hand_point()
	var claw_pos: Vector3 = _anchor
	var sag := 0.0
	var whip := 0.0
	var alpha := 1.0
	var motes_active := false
	var reel_t := 0.0

	var span := hand.distance_to(_anchor)
	var sag_base: float = clampf(span * 0.13, 0.0, 1.1)

	if elapsed < _extend_duration:
		var t := clampf(elapsed / _extend_duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		claw_pos = hand.lerp(_anchor, eased)
		sag = sag_base * eased
		alpha = t
	elif elapsed < _extend_duration + _pull_duration:
		claw_pos = _anchor
		if not _impact_done:
			_impact_done = true
			_spawn_anchor_impact(_anchor)
			_punch_claw()
		var pull_t: float = clampf((elapsed - _extend_duration) / _pull_duration, 0.0, 1.0)
		sag = sag_base * 0.18 * (1.0 - pull_t)   # snaps taut
		whip = (1.0 - pull_t) * 0.07             # tension vibration, damping out
		alpha = 1.0
		motes_active = true
		reel_t = pull_t
	else:
		var t: float = clampf((elapsed - _extend_duration - _pull_duration) / RETRACT_DURATION, 0.0, 1.0)
		var eased := t * t
		claw_pos = _anchor.lerp(hand, eased)
		alpha = 1.0 - eased

	if _claw and is_instance_valid(_claw):
		_claw.global_position = claw_pos
		var travel := claw_pos - hand
		if travel.length_squared() > 0.0004:
			_claw.look_at(claw_pos + travel.normalized(), Vector3.UP)

	if _light and is_instance_valid(_light):
		_light.global_position = claw_pos
		_light.light_energy = 3.0 * alpha

	if _rope_mat:
		_rope_mat.set_shader_parameter("alpha_mul", alpha)
	_rebuild_rope(hand, claw_pos, sag, whip)
	_update_motes(hand, claw_pos, motes_active, reel_t)
	_update_anchor_ring(alpha)


func _rebuild_rope(hand: Vector3, claw_pos: Vector3, sag: float, whip: float) -> void:
	if _rope_im == null:
		return
	_rope_im.clear_surfaces()
	var dir := claw_pos - hand
	var length := dir.length()
	if length < 0.02:
		return
	dir /= length
	var cam := _camera_position()
	var mid := (hand + claw_pos) * 0.5
	var whip_perp := dir.cross((cam - mid))
	if whip_perp.length_squared() < 0.0001:
		whip_perp = dir.cross(Vector3.UP)
	whip_perp = whip_perp.normalized()

	_rope_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(ROPE_SEGMENTS + 1):
		var t := float(i) / float(ROPE_SEGMENTS)
		var p := _rope_point(hand, claw_pos, t, sag, whip, whip_perp)
		var t_next := minf(t + 0.04, 1.0)
		var tangent := _rope_point(hand, claw_pos, t_next, sag, whip, whip_perp) - p
		if tangent.length_squared() < 0.000001:
			tangent = dir
		tangent = tangent.normalized()
		var view := cam - p
		var side := tangent.cross(view)
		if side.length_squared() < 0.000001:
			side = whip_perp
		side = side.normalized() * (ROPE_WIDTH * (1.0 - 0.4 * t))
		_rope_im.surface_set_uv(Vector2(t, 0.0))
		_rope_im.surface_add_vertex(p - side)
		_rope_im.surface_set_uv(Vector2(t, 1.0))
		_rope_im.surface_add_vertex(p + side)
	_rope_im.surface_end()


func _rope_point(hand: Vector3, claw_pos: Vector3, t: float, sag: float, whip: float, whip_perp: Vector3) -> Vector3:
	var base := hand.lerp(claw_pos, t)
	var arc := sin(PI * t)
	base += Vector3.DOWN * (sag * arc)
	if whip > 0.0:
		base += whip_perp * (whip * arc * sin(t * 16.0 + _elapsed * 34.0))
	return base


func _update_motes(hand: Vector3, claw_pos: Vector3, active: bool, reel_t: float) -> void:
	for index in range(_motes.size()):
		var mote := _motes[index]
		if mote == null or not is_instance_valid(mote):
			continue
		if not active:
			mote.visible = false
			continue
		mote.visible = true
		var phase: float = fposmod(reel_t * 2.4 + float(index) / float(_motes.size()), 1.0)
		# Energy travels anchor -> hand (reel-in).
		mote.global_position = claw_pos.lerp(hand, phase)
		var fade: float = sin(PI * phase)
		mote.scale = Vector3.ONE * (0.5 + 0.8 * fade)


func _update_anchor_ring(alpha: float) -> void:
	if _anchor_ring == null or not is_instance_valid(_anchor_ring):
		return
	if _missed:
		_anchor_ring.visible = false  # no "target locked" ring on a miss
		return
	var a: float = clampf(alpha, 0.0, 1.0)
	_anchor_ring.visible = a > 0.01
	if not _anchor_ring.visible:
		return
	# Face the camera (the torus disc faces along its local +Y) and spin slowly.
	var cam := _camera_position()
	var look := cam - _anchor
	if look.length() > 0.001:
		var y := look.normalized()
		var x := y.cross(Vector3.UP)
		if x.length_squared() < 0.0001:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		var z := x.cross(y).normalized()
		var b := Basis(x, y, z).rotated(y, _elapsed * 2.2)
		_anchor_ring.global_transform = Transform3D(b, _anchor)
	else:
		_anchor_ring.global_position = _anchor
	_anchor_ring.scale = Vector3.ONE * (0.6 + 0.4 * a)
	var mat := _anchor_ring.material_override as StandardMaterial3D
	if mat:
		mat.emission_energy_multiplier = 3.4 * a
		mat.albedo_color = Color(ANCHOR_RING_COLOR.r, ANCHOR_RING_COLOR.g, ANCHOR_RING_COLOR.b, a)


# -----------------------------------------------------------------------------
# Bursts
# -----------------------------------------------------------------------------

func _spawn_launch_burst(pos: Vector3) -> void:
	_play_sound(CAST_SFX, pos, -2.0, 1.0)  # hook fires out
	var flash := _make_billboard_flash("LaunchFlash", pos, FLASH_TEXTURE, ACCENT_COLOR, 0.32, 3.6)
	var t := flash.create_tween()
	t.tween_property(flash, "scale", Vector3.ONE * 0.9, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "scale", Vector3.ZERO, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(flash.queue_free)
	_spawn_spark_burst(pos, 8, 2.4, 4.5, 0.34)


func _spawn_anchor_impact(pos: Vector3) -> void:
	_play_sound(IMPACT_SFX, pos, -3.0, 0.92)  # hook bite

	# White-hot core pop — the initial punch.
	var core := MeshInstance3D.new()
	core.name = "ImpactCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	core.mesh = core_mesh
	core.material_override = _make_additive_material(Color(1.0, 1.0, 1.0, 1.0), 6.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	core.global_position = pos
	core.scale = Vector3.ONE * 0.2
	var ct := core.create_tween()
	ct.tween_property(core, "scale", Vector3.ONE * 1.15, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(core, "scale", Vector3.ZERO, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ct.tween_callback(core.queue_free)

	# Big camera-facing flash.
	var flash := _make_billboard_flash("ImpactFlash", pos, FLASH_TEXTURE, CORE_COLOR, 0.55, 5.6)
	var ft := flash.create_tween()
	ft.tween_property(flash, "scale", Vector3.ONE * 1.85, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ft.tween_property(flash, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ft.tween_callback(flash.queue_free)

	# Layered double shockwave (wide accent ring + tighter white ring).
	_spawn_shock_ring(pos, RING_TEXTURE, ACCENT_COLOR, 0.35, 2.7, 3.2, 0.32)
	_spawn_shock_ring(pos, RING_TEXTURE, CORE_COLOR, 0.25, 1.7, 2.6, 0.22)

	# Two spark bursts: fast hot sparks + slower chunky debris.
	_spawn_spark_burst(pos, 24, 4.5, 9.5, 0.45)
	_spawn_debris_burst(pos, 12, 2.0, 4.5, 0.75)

	# Lingering anchor glow that fades out.
	var glow := MeshInstance3D.new()
	glow.name = "ImpactGlow"
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.5
	glow_mesh.height = 1.0
	glow.mesh = glow_mesh
	var glow_mat := _make_additive_material(ACCENT_COLOR, 2.0)
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow.global_position = pos
	glow.scale = Vector3.ONE * 0.55
	var gt := glow.create_tween()
	gt.set_parallel(true)
	gt.tween_property(glow, "scale", Vector3.ONE * 1.5, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	gt.tween_property(glow_mat, "emission_energy_multiplier", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	gt.chain().tween_callback(glow.queue_free)

	# Punchy light flash.
	var light := OmniLight3D.new()
	light.name = "ImpactLight"
	light.light_color = ACCENT_COLOR
	light.light_energy = 7.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = pos
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	lt.tween_callback(light.queue_free)


func _spawn_shock_ring(pos: Vector3, texture_name: String, color: Color, start_scale: float, end_scale: float, energy: float, dur: float) -> void:
	var ring := _make_billboard_flash("ImpactShock", pos, texture_name, color, 0.5, energy)
	ring.scale = Vector3.ONE * start_scale
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3.ONE * end_scale, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var mat := ring.material_override as StandardMaterial3D
	if mat:
		t.tween_property(mat, "emission_energy_multiplier", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(ring.queue_free)


func _spawn_debris_burst(pos: Vector3, count: int, vel_min: float, vel_max: float, lifetime: float) -> void:
	var debris := GPUParticles3D.new()
	debris.name = "GrappleDebris"
	debris.amount = count
	debris.lifetime = lifetime
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.local_coords = false
	debris.emitting = false
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debris.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.gravity = Vector3(0.0, -13.0, 0.0)
	process.initial_velocity_min = vel_min
	process.initial_velocity_max = vel_max
	process.damping_min = 0.3
	process.damping_max = 1.0
	process.scale_min = 0.04
	process.scale_max = 0.1
	process.color = ACCENT_COLOR.lerp(Color(0.7, 0.85, 1.0, 1.0), 0.5)
	debris.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	mesh.material = _make_additive_material(ACCENT_COLOR, 2.6)
	debris.draw_pass_1 = mesh
	add_child(debris)
	debris.global_position = pos
	debris.restart()
	debris.emitting = true
	var cleanup := debris.create_tween()
	cleanup.tween_interval(lifetime + 0.2)
	cleanup.tween_callback(debris.queue_free)


func _play_sound(stream_path: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	var stream := load(stream_path)
	if not (stream is AudioStream):
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "GrappleSfx"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.96, 1.05)
	player.unit_size = 6.0
	player.max_distance = 42.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.bus = &"Master"
	add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()


func _punch_claw() -> void:
	if _claw == null or not is_instance_valid(_claw):
		return
	_claw.scale = Vector3.ONE
	var t := _claw.create_tween()
	t.tween_property(_claw, "scale", Vector3.ONE * 1.4, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_claw, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _claw_halo and is_instance_valid(_claw_halo):
		var halo_mat := _claw_halo.material_override as StandardMaterial3D
		if halo_mat:
			halo_mat.emission_energy_multiplier = 5.0
			var ht := _claw_halo.create_tween()
			ht.tween_property(halo_mat, "emission_energy_multiplier", 2.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _spawn_spark_burst(pos: Vector3, count: int, vel_min: float, vel_max: float, lifetime: float) -> void:
	var sparks := GPUParticles3D.new()
	sparks.name = "GrappleSparks"
	sparks.amount = count
	sparks.lifetime = lifetime
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.emitting = false
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.gravity = Vector3(0.0, -7.0, 0.0)
	process.initial_velocity_min = vel_min
	process.initial_velocity_max = vel_max
	process.damping_min = 0.5
	process.damping_max = 1.6
	process.scale_min = 0.02
	process.scale_max = 0.05
	process.color = ACCENT_COLOR
	sparks.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.028
	mesh.height = 0.056
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _make_additive_material(ACCENT_COLOR, 3.4)
	sparks.draw_pass_1 = mesh
	add_child(sparks)
	sparks.global_position = pos
	sparks.restart()
	sparks.emitting = true
	var cleanup := sparks.create_tween()
	cleanup.tween_interval(lifetime + 0.2)
	cleanup.tween_callback(sparks.queue_free)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _hand_point() -> Vector3:
	if _shooter == null or not is_instance_valid(_shooter):
		return _anchor
	var xform_basis := _shooter.global_transform.basis
	var forward := -xform_basis.z
	var right := xform_basis.x
	# Approximate the shooter's hand: up the torso, slightly forward and to the side.
	return _shooter.global_position + Vector3.UP * 1.2 + forward * 0.28 + right * 0.22


func _camera_position() -> Vector3:
	var viewport := get_viewport()
	if viewport:
		var cam := viewport.get_camera_3d()
		if cam:
			return cam.global_position
	if _shooter and is_instance_valid(_shooter):
		return _shooter.global_position + Vector3(0.0, 3.0, 4.0)
	return _anchor + Vector3(0.0, 3.0, 4.0)


func _make_billboard_flash(node_name: String, pos: Vector3, texture_name: String, color: Color, size: float, energy: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	node.mesh = quad
	var material := _make_additive_material(color, energy)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var texture := load(TEXTURE_ROOT + texture_name)
	if texture is Texture2D:
		material.albedo_texture = texture
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = pos
	node.scale = Vector3.ONE * 0.3
	return node


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
