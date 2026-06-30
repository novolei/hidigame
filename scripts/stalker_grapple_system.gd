extends Node3D
class_name StalkerGrappleSystem

const RANGE := 45.0
const COOLDOWN := 10.0
const TARGET_BACKOFF := 0.95
const TARGET_UP_OFFSET := 0.18
const GRAPPLE_REQUEST_APPROX_BYTES := 72

# Velocity-driven reel-in (replaces the old fixed-duration position lerp, which
# felt stiff and teleporty). The body actually FLIES toward the anchor through
# move_and_slide with an acceleration ramp, so it has a real launch/arc/flight
# feel and collides with the world. Cruise speed scales mildly with the pull
# distance so long pulls don't crawl. Driven by player._physics_process calling
# process_pull_movement() while is_grappling() yields the netfox motor.
const PULL_ACCEL := 130.0          # how fast velocity ramps to cruise (flight transition)
const PULL_SPEED_MIN := 18.0
const PULL_SPEED_MAX := 30.0
const PULL_SPEED_PER_M := 0.55     # extra cruise speed per metre of initial distance
const ARRIVE_RADIUS := 2.0         # finish the pull this far out (still moving fast)
const MAX_PULL_TIME := 1.6         # safety cap so a blocked pull always ends
const PULL_STUCK_TIME := 0.16      # end early if move_and_slide stops making progress

# Two-phase cast (per the reference): the hook/rope first FLIES to the surface,
# and only on contact does the reel-in begin. HOOK_FLIGHT_SPEED sets how fast the
# hook travels; the pull starts after that delay. Kept fast so it reads as a
# snap-throw, not a slow lob. Keep in sync with the visual's HOOK_SPEED.
const HOOK_FLIGHT_SPEED := 85.0
const HOOK_FLIGHT_MIN := 0.08
const HOOK_FLIGHT_MAX := 0.55

# Aim assist: a single thin raycast needs near-perfect aim, which is the main
# reason casts "miss". If the exact crosshair ray finds nothing, sample a small
# cone around it and snap to the nearest grappleable surface — a big hit-rate
# win. Applied to both owner prediction and the server check so they agree.
const AIM_ASSIST_ANGLES_DEG := [4.0, 8.0, 13.0]
const AIM_ASSIST_SAMPLES := 10

# Landing momentum: the reel-in ends while still moving, so we carry that flight
# velocity out (plus an upward pop) instead of stopping dead — the stalker keeps
# speed and flies an extra distance. The player's movement then decays it (low
# AIR_DECELERATION keeps the airborne carry, GROUND_DECELERATION brakes on land).
const EXIT_SPEED_RETAIN := 0.78    # fraction of flight speed carried out of the pull
const EXIT_MIN_HORIZONTAL := 11.0  # guarantee a fling even if we arrived slow
const EXIT_VERTICAL_BOOST := 3.6
# Hold-to-aim: holding the key shows a green 3D target marker at the predicted
# hit point (no cast); releasing fires. A quick tap (held < AIM_SHOW_DELAY) just
# casts on release without flashing the marker.
const AIM_SHOW_DELAY := 0.1
const AIM_READY_COLOR := Color(0.25, 1.0, 0.45, 1.0)
const AIM_BLOCKED_COLOR := Color(1.0, 0.5, 0.3, 1.0)
const GrappleVisualScript := preload("res://scripts/effects/stalker_grapple_visual.gd")

var stalker_owner: CharacterBody3D = null
var owner_camera: Camera3D = null
var cooldown_remaining := 0.0
var pulling := false

var _pull_elapsed := 0.0
var _pull_speed := 24.0
var _pull_stuck_time := 0.0
var _pull_start := Vector3.ZERO
var _pull_target := Vector3.ZERO
var _pull_last_position := Vector3.ZERO
var _hook_flying := false
var _hook_flight_remaining := 0.0
var _pending_pull_target := Vector3.ZERO
var _active_visual: Node3D = null
var _aiming := false
var _aim_held_time := 0.0
var _aim_marker: Node3D = null
var _aim_parts: Array[MeshInstance3D] = []


func initialize(owner_node: CharacterBody3D, camera_node: Camera3D = null) -> void:
	stalker_owner = owner_node
	owner_camera = camera_node
	set_multiplayer_authority(stalker_owner.get_multiplayer_authority() if stalker_owner else 1)


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	# Phase 1: the hook is flying to the surface. When it lands (flight time up),
	# phase 2 begins and the body is reeled in. Authority-only (drives movement).
	if _hook_flying and stalker_owner and stalker_owner.is_multiplayer_authority():
		_hook_flight_remaining -= delta
		if _hook_flight_remaining <= 0.0:
			_hook_flying = false
			_start_pull(_pending_pull_target)
	if _aiming and stalker_owner and stalker_owner.is_multiplayer_authority():
		_aim_held_time += delta
		_update_aim_preview()


# Driven every physics frame by the player while is_grappling() (the player
# yields the netfox motor during the pull). Velocity-based flight: accelerate
# toward the anchor, let the caller move_and_slide (real collisions + arc), and
# finish with carried momentum on arrival / timeout / when blocked.
func process_pull_movement(delta: float) -> void:
	if not pulling or not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_pull_elapsed += delta
	var pos: Vector3 = stalker_owner.global_position
	var to_target: Vector3 = _pull_target - pos
	var dist: float = to_target.length()

	# Stuck detection: move_and_slide blocked by geometry between us and the anchor.
	if _pull_elapsed > 0.03:
		if pos.distance_to(_pull_last_position) < 0.02:
			_pull_stuck_time += delta
		else:
			_pull_stuck_time = 0.0
	_pull_last_position = pos

	if dist <= ARRIVE_RADIUS or _pull_elapsed >= MAX_PULL_TIME or _pull_stuck_time >= PULL_STUCK_TIME:
		pulling = false
		_apply_exit_momentum()
		return

	var dir: Vector3 = to_target / maxf(dist, 0.0001)
	var desired: Vector3 = dir * _pull_speed
	# Ramp toward the flight velocity so the launch isn't an instant jerk; this
	# also bleeds entry/lateral momentum into a brief curve (the swing feel).
	stalker_owner.velocity = stalker_owner.velocity.move_toward(desired, PULL_ACCEL * delta)


func request_grapple() -> bool:
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return false
	if pulling or _hook_flying:
		return false  # already casting
	if cooldown_remaining > 0.0:
		_show_cast_feedback("钩索冷却 %.1fs" % cooldown_remaining, Color(0.62, 0.78, 1.0))
		return false
	var origin: Vector3 = _ray_origin()
	var direction: Vector3 = _ray_direction()
	var query_tick: int = _grapple_query_tick()
	var hit: Dictionary = _find_grapple_hit_from(origin, direction, query_tick, _owner_peer_id())
	if hit.is_empty():
		# Missed: show a dud cast so it reads as "fired but didn't catch" instead
		# of nothing happening. No cooldown is spent (see no-cooldown-on-miss).
		_show_miss_feedback(origin, direction)
		_show_cast_feedback("无可用钩点 (瞄准 %dm 内实心表面)" % int(RANGE), Color(1.0, 0.6, 0.35))
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var target: Vector3 = _pull_target_from_hit(origin, hit)
	_start_hook_flight(origin, target)
	_show_grapple_effect(origin, hit_position)
	_show_cast_feedback("钩索命中!", Color(0.4, 1.0, 0.7))
	cooldown_remaining = COOLDOWN
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_broadcast_grapple_effect_to_peers(origin, hit_position)
		else:
			Network.record_rpc_event("grapple.request", 1, GRAPPLE_REQUEST_APPROX_BYTES)
			_request_grapple.rpc_id(1, origin, direction, query_tick, target, hit_position)
	return true


func get_cooldown_remaining() -> float:
	return cooldown_remaining


func is_grappling() -> bool:
	return pulling


# Hold the key: enter aim mode (preview marker, no cast).
func begin_aim() -> void:
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_aiming = true
	_aim_held_time = 0.0


# Release the key (quick tap or after aiming): cast at the aimed point.
func release_aim_and_cast() -> void:
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_aiming = false
	_hide_aim_marker()
	request_grapple()


func _update_aim_preview() -> void:
	# A quick tap (held < AIM_SHOW_DELAY) just casts on release; only a real hold
	# shows the marker. Hide it while casting/reeling.
	if _aim_held_time < AIM_SHOW_DELAY or pulling or _hook_flying:
		_hide_aim_marker()
		return
	var origin: Vector3 = _ray_origin()
	var direction: Vector3 = _ray_direction()
	var hit: Dictionary = _find_grapple_hit_from(origin, direction, _grapple_query_tick(), _owner_peer_id())
	if hit.is_empty():
		_hide_aim_marker()
		return
	_ensure_aim_marker()
	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var y: Vector3 = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var x: Vector3 = y.cross(Vector3.RIGHT)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	_aim_marker.global_transform = Transform3D(Basis(x, y, z), pos + y * 0.03)
	_aim_marker.visible = true
	_set_aim_marker_color(AIM_BLOCKED_COLOR if cooldown_remaining > 0.0 else AIM_READY_COLOR)


func _ensure_aim_marker() -> void:
	# Owner-input-driven only (begin_aim comes from local input), so it never runs
	# on a headless dedicated server — no RuntimeMode guard needed here.
	if _aim_marker and is_instance_valid(_aim_marker):
		return
	_aim_marker = Node3D.new()
	_aim_marker.name = "GrappleAimMarker"
	_aim_marker.top_level = true
	add_child(_aim_marker)
	# Targeting reticle (per the reference): two concentric rings + four inward
	# cardinal ticks + a center chevron cluster, all flat on the surface.
	_aim_parts.clear()
	_add_reticle_part(_make_reticle_ring(0.70, 0.76, 2.2), "OuterRing")
	_add_reticle_part(_make_reticle_ring(0.33, 0.37, 2.2), "InnerRing")
	for i in range(4):
		var a: float = float(i) * PI * 0.5
		var tick: MeshInstance3D = _make_reticle_triangle(2.6, 1.0)
		tick.position = Vector3(sin(a), 0.0, cos(a)) * 0.55
		tick.rotation.y = a
		_add_reticle_part(tick, "Tick%d" % i)
	for i in range(4):
		var a: float = float(i) * PI * 0.5 + PI * 0.25
		var chev: MeshInstance3D = _make_reticle_triangle(3.0, 0.55)
		chev.position = Vector3(sin(a), 0.0, cos(a)) * 0.15
		chev.rotation.y = a
		_add_reticle_part(chev, "Center%d" % i)
	_aim_marker.visible = false


func _add_reticle_part(mi: MeshInstance3D, node_name: String) -> void:
	mi.name = node_name
	_aim_marker.add_child(mi)
	_aim_parts.append(mi)


func _make_reticle_ring(inner_r: float, outer_r: float, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 48        # main-circle resolution: keep high so the ring is ROUND
	torus.ring_segments = 6 # thin flat tube cross-section — low is fine, saves polys
	mi.mesh = torus
	mi.material_override = _make_marker_material(AIM_READY_COLOR, 0.9, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_reticle_triangle(energy: float, scale_mul: float) -> MeshInstance3D:
	# Flat inward-pointing triangle (tip toward local -Z) in the XZ plane.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(0.0, 0.0, -0.075) * scale_mul)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(-0.05, 0.0, 0.04) * scale_mul)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(0.05, 0.0, 0.04) * scale_mul)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _make_marker_material(AIM_READY_COLOR, 0.95, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _set_aim_marker_color(color: Color) -> void:
	for part: MeshInstance3D in _aim_parts:
		if part and is_instance_valid(part) and part.material_override is StandardMaterial3D:
			var m := part.material_override as StandardMaterial3D
			m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)
			m.emission = color


func _hide_aim_marker() -> void:
	if _aim_marker and is_instance_valid(_aim_marker):
		_aim_marker.visible = false


func _make_marker_material(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	return material


func _find_grapple_hit() -> Dictionary:
	return _find_grapple_hit_from(_ray_origin(), _ray_direction(), _grapple_query_tick(), _owner_peer_id())


func _find_grapple_hit_from(origin: Vector3, direction: Vector3, query_tick: int, excluded_peer_id: int = 0) -> Dictionary:
	if direction.length_squared() <= 0.0001:
		return {}
	var aim: Vector3 = direction.normalized()
	# Try the exact aim first (precise point/normal), then fall back to a cone.
	var direct: Dictionary = _query_grapple_segment(origin, aim, query_tick, excluded_peer_id)
	if not direct.is_empty():
		return direct
	var up_ref: Vector3 = Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var right: Vector3 = aim.cross(up_ref).normalized()
	var up: Vector3 = right.cross(aim).normalized()
	var best: Dictionary = {}
	var best_dist: float = INF
	for angle_deg: float in AIM_ASSIST_ANGLES_DEG:
		var s: float = sin(deg_to_rad(angle_deg))
		var c: float = cos(deg_to_rad(angle_deg))
		for i in range(AIM_ASSIST_SAMPLES):
			var roll: float = TAU * float(i) / float(AIM_ASSIST_SAMPLES)
			var tilt: Vector3 = right * cos(roll) + up * sin(roll)
			var cone_dir: Vector3 = (aim * c + tilt * s).normalized()
			var h: Dictionary = _query_grapple_segment(origin, cone_dir, query_tick, excluded_peer_id)
			if h.is_empty():
				continue
			var d: float = origin.distance_to(h.get("position", origin))
			if d < best_dist:
				best = h
				best_dist = d
	return best


func _query_grapple_segment(origin: Vector3, direction: Vector3, query_tick: int, excluded_peer_id: int = 0) -> Dictionary:
	if not stalker_owner or not stalker_owner.get_world_3d():
		return {}
	if direction.length_squared() <= 0.0001:
		return {}
	var clean_direction: Vector3 = direction.normalized()
	var space: PhysicsDirectSpaceState3D = stalker_owner.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + clean_direction * RANGE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [stalker_owner.get_rid()]
	query.collision_mask = 0x7FFFFFFF
	var world_hit: Dictionary = space.intersect_ray(query)
	if not world_hit.is_empty() and world_hit.get("collider", null) == stalker_owner:
		world_hit = {}
	var rewind_hit: Dictionary = {}
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree())
	if history != null:
		rewind_hit = history.find_player_hit_on_segment(origin, clean_direction, RANGE, query_tick, excluded_peer_id)
	if rewind_hit.is_empty():
		return world_hit
	if world_hit.is_empty():
		return rewind_hit
	var world_distance: float = origin.distance_to(world_hit.get("position", origin))
	var rewind_distance: float = float(rewind_hit.get("distance", INF))
	return rewind_hit if rewind_distance < world_distance else world_hit


func _pull_target_from_hit(origin: Vector3, hit: Dictionary) -> Vector3:
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	var direction: Vector3 = (hit_position - origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = _ray_direction()
	return hit_position - direction * TARGET_BACKOFF + hit_normal.normalized() * TARGET_UP_OFFSET


func _owner_peer_id() -> int:
	if stalker_owner and stalker_owner.has_method("get_multiplayer_authority"):
		return int(stalker_owner.call("get_multiplayer_authority"))
	return 1


func _grapple_query_tick() -> int:
	if stalker_owner and stalker_owner.has_method("get_network_input_tick"):
		return int(stalker_owner.call("get_network_input_tick"))
	return NetworkTime.tick


@rpc("any_peer", "call_local", "reliable")
func _request_grapple(origin: Vector3, direction: Vector3, query_tick: int, client_target: Vector3, client_hit_position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != _owner_peer_id():
		return
	_server_accept_grapple(sender_id, origin, direction, query_tick, client_target, client_hit_position)


func _server_accept_grapple(sender_id: int, origin: Vector3, direction: Vector3, query_tick: int, client_target: Vector3, client_hit_position: Vector3) -> void:
	if sender_id != _owner_peer_id():
		return
	if cooldown_remaining > 0.0:
		_reject_grapple.rpc_id(sender_id)
		return
	var hit: Dictionary = _find_grapple_hit_from(origin, direction, query_tick, sender_id)
	var hit_position: Vector3
	var target: Vector3
	if not hit.is_empty():
		hit_position = hit.get("position", Vector3.ZERO)
		target = _pull_target_from_hit(origin, hit)
	elif origin.distance_to(client_target) <= RANGE + 3.0:
		# The server re-raycast disagreed with the client (RPCs are handled on a
		# different frame / physics-space state than the client's input-time cast).
		# Grapple is a movement-only ability and the client already owns its own
		# movement, so trust the client's predicted target after a range sanity
		# check instead of rejecting a legitimate cast.
		target = client_target
		hit_position = client_hit_position
	else:
		_reject_grapple.rpc_id(sender_id)
		return
	cooldown_remaining = COOLDOWN
	_show_grapple_effect(origin, hit_position)
	_broadcast_grapple_effect_to_peers(origin, hit_position)
	_apply_grapple_correction.rpc_id(sender_id, target)


func _broadcast_grapple_effect_to_peers(origin: Vector3, hit_position: Vector3) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var peers: PackedInt32Array = multiplayer.get_peers()
	if peers.is_empty():
		return
	Network.record_rpc_event("grapple.effect", peers.size(), 48)
	for peer_id: int in peers:
		_show_grapple_effect.rpc_id(peer_id, origin, hit_position)


@rpc("any_peer", "call_remote", "reliable")
func _apply_grapple_correction(target: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		return
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_pending_pull_target = target
	# If the predicted hook is still flying, it reels to the corrected target when
	# it lands; if the flight already finished, begin the pull now.
	if not _hook_flying and not pulling:
		_start_pull(target)
	cooldown_remaining = COOLDOWN


@rpc("any_peer", "call_remote", "reliable")
func _reject_grapple() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		return
	pulling = false
	_hook_flying = false
	# A rejected/failed cast must NOT consume the cooldown; clear the predicted
	# hook visual so it doesn't dangle.
	cooldown_remaining = 0.0
	_clear_visual()
	_show_cast_feedback("钩索校验失败 (服务器未命中)", Color(1.0, 0.55, 0.35))


# Phase 1: begin the hook flight. The body does NOT move yet — _process counts
# down the flight time and calls _start_pull() when the hook reaches the surface.
func _start_hook_flight(origin: Vector3, target: Vector3) -> void:
	_hook_flying = true
	pulling = false
	_pending_pull_target = target
	_pull_start = stalker_owner.global_position
	var span: float = origin.distance_to(target)
	_hook_flight_remaining = clampf(span / HOOK_FLIGHT_SPEED, HOOK_FLIGHT_MIN, HOOK_FLIGHT_MAX)


func _start_pull(target: Vector3) -> void:
	pulling = true
	_hook_flying = false
	_pull_elapsed = 0.0
	_pull_stuck_time = 0.0
	_pull_start = stalker_owner.global_position
	_pull_target = target
	_pull_last_position = stalker_owner.global_position
	var initial_dist: float = _pull_start.distance_to(target)
	_pull_speed = clampf(PULL_SPEED_MIN + initial_dist * PULL_SPEED_PER_M, PULL_SPEED_MIN, PULL_SPEED_MAX)
	# Lift off into the flight: drop any downward fall velocity (keep lateral
	# momentum so the ramp curves it), then let process_pull_movement take over.
	if stalker_owner.velocity.y < 0.0:
		stalker_owner.velocity.y = 0.0
	if stalker_owner.has_method("_play_body_jump"):
		stalker_owner.call("_play_body_jump", "Jump")


func _ray_origin() -> Vector3:
	if owner_camera:
		return owner_camera.global_position
	if stalker_owner:
		return stalker_owner.global_position + Vector3.UP * 1.35
	return global_position


func _ray_direction() -> Vector3:
	if owner_camera:
		return -owner_camera.global_transform.basis.z.normalized()
	if stalker_owner:
		return -stalker_owner.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


# The reel-in ends while still moving, so carry that flight velocity out (plus
# an upward pop) for a seamless transition into a momentum glide — the stalker
# flies an extra distance and skids to a stop on landing instead of stopping
# dead. Runs on the movement authority (owner); netfox replicates the result.
func _apply_exit_momentum() -> void:
	if not stalker_owner:
		return
	var v: Vector3 = stalker_owner.velocity
	var horizontal := Vector3(v.x, 0.0, v.z) * EXIT_SPEED_RETAIN
	if horizontal.length() < EXIT_MIN_HORIZONTAL:
		# Arrived slow (short or near-vertical pull): guarantee a forward fling.
		horizontal = _exit_fallback_direction() * EXIT_MIN_HORIZONTAL
	var launch := horizontal + Vector3.UP * EXIT_VERTICAL_BOOST
	stalker_owner.velocity = launch
	# Seed the netfox movement motor directly so the rollback simulation carries
	# the launch from this tick. The motor mirrors player.velocity each physics
	# frame anyway, but seeding it here (like teleport_to does) avoids a one-tick
	# lag and a possible stale re-sim overwriting the fling on prediction.
	var motor := stalker_owner.get_node_or_null("MovementMotor") as PlayerMovementMotor
	if motor != null:
		motor.simulated_velocity = launch
		motor.simulated_grounded = false


func _exit_fallback_direction() -> Vector3:
	var travel := _pull_target - _pull_start
	var horizontal := Vector3(travel.x, 0.0, travel.z)
	if horizontal.length_squared() > 0.04:
		return horizontal.normalized()
	var aim := _ray_direction()
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		return aim.normalized()
	if stalker_owner:
		var facing := -stalker_owner.global_transform.basis.z
		facing.y = 0.0
		if facing.length_squared() > 0.0001:
			return facing.normalized()
	return Vector3.FORWARD


@rpc("any_peer", "call_local", "reliable")
func _show_grapple_effect(origin: Vector3, target: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender_id: int = multiplayer.get_remote_sender_id()
		if sender_id != 0 and sender_id != 1:
			return
	_spawn_grapple_visual(origin, target)


func _spawn_grapple_visual(origin: Vector3, target: Vector3) -> void:
	if stalker_owner == null or not is_instance_valid(stalker_owner):
		return
	# Never build meshes on a dedicated headless server (Runtime Authority Contract).
	if RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config):
		return
	_clear_visual()
	# Visual derives its own flight time from the hand->anchor distance.
	_active_visual = GrappleVisualScript.spawn(self, stalker_owner, origin, target, 0.0)


func _show_cast_feedback(text: String, color: Color) -> void:
	# Owner-only HUD note explaining the cast outcome (uses the level's combat
	# feedback banner, same as the weapon). Helps see WHY a grapple did/didn't fire.
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	var scene: Node = get_tree().get_current_scene() if is_inside_tree() else null
	if scene and scene.has_method("show_combat_feedback"):
		scene.call("show_combat_feedback", text, color, 0.85)


func _show_miss_feedback(origin: Vector3, direction: Vector3) -> void:
	# Local-only: fire a dud hook out along the aim and let it retract, so a miss
	# is visible/audible. No cooldown, no RPC — a miss affects only the caster.
	if stalker_owner == null or not is_instance_valid(stalker_owner):
		return
	if RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config):
		return
	var aim: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else _ray_direction()
	var miss_point: Vector3 = origin + aim * RANGE
	_clear_visual()
	_active_visual = GrappleVisualScript.spawn(self, stalker_owner, origin, miss_point, 0.0, true)


func _clear_visual() -> void:
	if _active_visual and is_instance_valid(_active_visual):
		_active_visual.queue_free()
	_active_visual = null
