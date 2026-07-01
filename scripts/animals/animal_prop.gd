extends CharacterBody3D
class_name AnimalProp

## A per-round, server-authoritative animal that prop players can disguise as and
## hunters can shoot. Killing a REAL animal (not a disguised player) costs the
## hunter ANIMAL_KILL_PENALTY health — see _server_die().
##
## Behaviors (from AnimalCatalog):
##   - "wander": bounded idle/roam around a spawn anchor.
##   - "hunt_tracker" (deer, sabretooth): wander UNTIL a hunter enters the vision
##     cone (range + FOV + line-of-sight); then patrol gives way to tailing the
##     hunter (leashed to the patrol area), announced to every player. Adapted
##     from the Godot_4_AI_TEST patrol/search/chase pattern, but with simple
##     server-side steering instead of LimboAI + NavigationAgent3D (this project
##     ships neither a behavior-tree addon nor baked navmeshes).
##
## Animation: species whose model ships AnimationPlayer clips (deer, ice-age) play
## a real Walk clip while moving and Idle (or a frozen pose) while still. Clip-less
## wild animals fall back to node-level procedural "liveliness".
##
## Authority: only the server runs the FSM/vision/HP. Clients lerp toward the
## synced transform and drive animation from the synced state.

const WORLD_LAYER: int = 2          # static map geometry the animal stands on
const ANIMAL_LAYER: int = 4         # physics layer the hunter hitscan ray can hit
const GRAVITY: float = 18.0
const FLOOR_SNAP: float = 0.6
const ANIMAL_KILL_PENALTY: float = 100.0

const NET_SYNC_INTERVAL: float = 0.12
const NET_POS_EPSILON: float = 0.04
const NET_YAW_EPSILON: float = 0.03
const REMOTE_LERP_SPEED: float = 12.0
const REMOTE_SNAP_DISTANCE: float = 4.0

const IDLE_MIN_SECONDS: float = 2.0
const IDLE_MAX_SECONDS: float = 5.5
const WALK_MAX_SECONDS: float = 6.0
const ARRIVE_DISTANCE: float = 0.6
const TURN_RATE: float = 6.0

const VISION_INTERVAL: float = 0.3     # how often a hunt-tracker re-scans for hunters
const VISION_EYE_HEIGHT: float = 0.9   # ray origin lift so it clears the ground

const DEATH_DESPAWN_SECONDS: float = 0.7
const DEATH_DISSOLVE_SECONDS: float = 2.4
const DEATH_DISSOLVE_SHADER: Shader = preload("res://shaders/death_dissolve.gdshader")

enum WanderState { IDLE, WALK, CHASE }

static var _scene_cache: Dictionary = {}
static var _atlas_material_cache: Material = null

# --- configuration (set by apply_data) ---
var species_id: String = "wolf"
var display_name: String = "灰狼"
var scene_path: String = ""
var model_scale: float = 1.0
var wander_speed: float = 1.8
var body_radius: float = 0.4
var body_height: float = 1.0
var anchor: Vector3 = Vector3.ZERO
var wander_radius: float = 6.5
var health: float = AnimalCatalog.ANIMAL_HEALTH
var max_health: float = AnimalCatalog.ANIMAL_HEALTH
var texture_mode: String = "atlas"
var behavior: String = "wander"

# hunt-tracker tuning (only meaningful when behavior == "hunt_tracker")
var track_range: float = 18.0
var track_fov_cos: float = 0.2        # cos(half-FOV); higher = narrower cone
var track_speed: float = 3.2
var track_leash: float = 16.0
var track_give_up: float = 4.0
var track_follow_gap: float = 3.0

# --- runtime ---
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state: WanderState = WanderState.IDLE
var _state_timer: float = 0.0
var _target_point: Vector3 = Vector3.ZERO
var _facing_yaw: float = 0.0
var _is_dead: bool = false
var _death_timer: float = 0.0
var _dissolve_material: ShaderMaterial = null
var _dissolve_root: Node3D = null
var _dissolve_elapsed: float = 0.0

var _visual_root: Node3D = null
var _visual_rest_y: float = 0.0
var _collision_shape: CollisionShape3D = null
var _collision_half_height: float = 0.5
var _live_phase: float = 0.0

# animation
var _anim_player: AnimationPlayer = null
var _walk_clip: String = ""
var _idle_clip: String = ""
var _has_real_anim: bool = false

# hunt-tracker runtime
var _vision_timer: float = 0.0
var _chase_target: Node3D = null
var _chase_target_id: int = 0
var _lost_timer: float = 0.0

# networking
var _net_elapsed: float = 0.0
var _net_initialized: bool = false
var _last_sent_pos: Vector3 = Vector3.ZERO
var _last_sent_yaw: float = 0.0
var _last_sent_state: int = 0
var _has_remote_target: bool = false
var _remote_pos: Vector3 = Vector3.ZERO
var _remote_yaw: float = 0.0


func _ready() -> void:
	_rng.randomize()
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_snap_length = FLOOR_SNAP
	collision_layer = ANIMAL_LAYER
	collision_mask = WORLD_LAYER
	add_to_group("animal_props")
	add_to_group("killable_animals")
	add_to_group("replicable_props")
	_apply_authority_processing()


func apply_data(data: Dictionary) -> void:
	species_id = String(data.get("id", species_id))
	display_name = String(data.get("name", data.get("display_name", display_name)))
	scene_path = String(data.get("scene", scene_path))
	# model_scale is NOT taken from data — models have wildly different native
	# sizes, so _auto_scale_visual() measures each one and scales it to body_height.
	wander_speed = float(data.get("speed", wander_speed))
	body_radius = float(data.get("radius", body_radius))   # FINAL collision metres
	body_height = float(data.get("height", body_height))   # FINAL standing metres
	wander_radius = float(data.get("wander_radius", wander_radius))
	max_health = float(data.get("health", max_health))
	health = max_health
	texture_mode = String(data.get("texture", texture_mode))
	behavior = String(data.get("behavior", behavior))
	_configure_tracking(data.get("track", {}))

	var spawn_position: Vector3 = data.get("position", global_position)
	global_position = spawn_position
	anchor = data.get("anchor", spawn_position)
	_facing_yaw = float(data.get("rotation_y", _facing_yaw))
	rotation.y = _facing_yaw
	_remote_pos = spawn_position
	_remote_yaw = _facing_yaw

	# Deterministic per-animal RNG so server wander is reproducible per name.
	_rng.seed = hash(name) ^ hash(species_id)

	_build_collision()
	if _should_build_visual():
		_build_visual()
	_enter_idle()
	_apply_authority_processing()


func _configure_tracking(track: Dictionary) -> void:
	if track.is_empty():
		return
	track_range = float(track.get("range", track_range))
	track_speed = float(track.get("speed", track_speed))
	track_leash = float(track.get("leash", track_leash))
	track_give_up = float(track.get("give_up", track_give_up))
	track_follow_gap = float(track.get("follow_gap", track_follow_gap))
	var half_fov: float = deg_to_rad(float(track.get("fov_deg", 78.0)) * 0.5)
	track_fov_cos = cos(clampf(half_fov, 0.05, PI - 0.05))


# Hunter hitscan resolves to this on the server. attacker_id is the shooter peer.
func take_damage(amount: float, attacker_id: int = 0, _is_headshot: bool = false) -> void:
	if not _is_server():
		return
	if _is_dead:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		_server_die(attacker_id)


func is_animal_target() -> bool:
	return not _is_dead


# Disguise preset consumed by ShapeShiftSystem / Character.apply_prop_disguise.
func get_disguise_preset() -> Dictionary:
	var visual_height: float = maxf(body_height * model_scale, 0.6)
	return {
		"id": "animal_" + species_id,
		"name": display_name,
		"mesh": "scene",
		"scene_path": scene_path,
		"material_path": AnimalCatalog.ATLAS_MATERIAL_PATH if texture_mode == "atlas" else "",
		"scale": Vector3(model_scale, model_scale, model_scale),
		"offset": Vector3.ZERO,
		"prop_height": visual_height,
		"collision_radius": clampf(body_radius * model_scale, 0.32, 1.25),
		"collision_height": clampf(visual_height, 0.45, 2.2),
		"drop_height": clampf(visual_height * 0.32, 1.1, 3.0),
		"rotation": Vector3.ZERO,
		"tags": ["#animal", "#" + species_id],
	}


# =============================================================================
# Simulation (server only)
# =============================================================================

func _physics_process(delta: float) -> void:
	if not _is_server():
		set_physics_process(false)
		return
	if _is_dead:
		velocity = Vector3.ZERO
		return

	if behavior == "hunt_tracker":
		_vision_timer -= delta
		if _vision_timer <= 0.0:
			_vision_timer = VISION_INTERVAL
			_update_hunter_vision()

	var horizontal: Vector3 = Vector3.ZERO
	_state_timer -= delta
	match _state:
		WanderState.CHASE:
			horizontal = _drive_chase(delta)
		WanderState.WALK:
			horizontal = _drive_walk(delta)
		_:
			if _state_timer <= 0.0:
				_enter_walk()

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	rotation.y = _facing_yaw
	move_and_slide()

	_net_elapsed += delta
	if _net_elapsed >= NET_SYNC_INTERVAL:
		_net_elapsed = 0.0
		if _should_broadcast():
			_broadcast_state()


func _drive_walk(delta: float) -> Vector3:
	var to_target: Vector3 = _target_point - global_position
	to_target.y = 0.0
	var planar: float = to_target.length()
	if planar <= ARRIVE_DISTANCE or _state_timer <= 0.0:
		_enter_idle()
		return Vector3.ZERO
	var dir: Vector3 = to_target / maxf(planar, 0.001)
	_face_direction(dir, delta)
	return dir * wander_speed


func _drive_chase(delta: float) -> Vector3:
	# Give up if the target is gone, dead, out of leash, or unseen for too long.
	_lost_timer += delta
	var valid: bool = _chase_target != null and is_instance_valid(_chase_target)
	if valid and global_position.distance_to(anchor) > track_leash + 2.0:
		valid = false  # dragged outside the patrol area — break off
	if not valid or _lost_timer > track_give_up:
		_end_chase()
		_enter_idle()
		return Vector3.ZERO
	var to_target: Vector3 = _chase_target.global_position - global_position
	to_target.y = 0.0
	var planar: float = to_target.length()
	var dir: Vector3 = to_target / maxf(planar, 0.001)
	_face_direction(dir, delta)
	# Tail the hunter: keep following but hold a short gap instead of ramming.
	if planar <= track_follow_gap:
		return Vector3.ZERO
	return dir * track_speed


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_facing_yaw = rotate_toward(_facing_yaw, atan2(dir.x, dir.z), TURN_RATE * delta)


func _enter_idle() -> void:
	_state = WanderState.IDLE
	_state_timer = _rng.randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)


func _enter_walk() -> void:
	_state = WanderState.WALK
	_state_timer = _rng.randf_range(WALK_MAX_SECONDS * 0.5, WALK_MAX_SECONDS)
	var angle: float = _rng.randf_range(-PI, PI)
	var radius: float = sqrt(_rng.randf()) * wander_radius
	_target_point = anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


# =============================================================================
# Hunt-tracker vision (server)
# =============================================================================

func _update_hunter_vision() -> void:
	var hunter: Node3D = _find_visible_hunter()
	if hunter != null:
		_chase_target = hunter
		_chase_target_id = int(str(hunter.name))
		_lost_timer = 0.0
		if _state != WanderState.CHASE:
			_begin_chase()


func _find_visible_hunter() -> Node3D:
	if not is_inside_tree():
		return null
	var eye: Vector3 = global_position + Vector3(0.0, VISION_EYE_HEIGHT, 0.0)
	var forward: Vector3 = Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw))
	var best: Node3D = null
	var best_dist: float = INF
	for raw: Node in get_tree().get_nodes_in_group("players"):
		if not raw is Node3D:
			continue
		var player: Node3D = raw as Node3D
		if not (player.has_method("is_hunter") and player.is_hunter()):
			continue
		var peer_id: int = int(str(player.name))
		if Network != null and Network.players.has(peer_id) and not bool(Network.players[peer_id].get("alive", true)):
			continue
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var dist: float = to_player.length()
		if dist > track_range or dist < 0.05:
			continue
		var flat_dir: Vector3 = to_player / dist
		if forward.dot(flat_dir) < track_fov_cos:
			continue  # outside the vision cone
		if not _has_line_of_sight(eye, player):
			continue
		if dist < best_dist:
			best_dist = dist
			best = player
	return best


func _has_line_of_sight(eye: Vector3, player: Node3D) -> bool:
	var target: Vector3 = player.global_position + Vector3(0.0, VISION_EYE_HEIGHT, 0.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target)
	query.collision_mask = WORLD_LAYER
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	# Clear LOS if nothing blocks, or the world hit is past the hunter.
	if hit.is_empty():
		return true
	var hit_pos: Vector3 = hit.get("position", target)
	return eye.distance_to(hit_pos) >= eye.distance_to(target) - 0.3


func _begin_chase() -> void:
	_state = WanderState.CHASE
	_lost_timer = 0.0
	# Announce to every player that this animal is now tailing a hunter.
	_announce_track.rpc(_chase_target_id)


func _end_chase() -> void:
	_chase_target = null
	_chase_target_id = 0


@rpc("authority", "call_local", "reliable")
func _announce_track(hunter_id: int) -> void:
	if hunter_id > 0:
		KillFeed.report_animal_track(display_name, hunter_id)


# =============================================================================
# Networking
# =============================================================================

func _should_broadcast() -> bool:
	if not _net_initialized:
		return true
	if _last_sent_state != int(_state):
		return true
	if _last_sent_pos.distance_squared_to(global_position) > NET_POS_EPSILON * NET_POS_EPSILON:
		return true
	if absf(angle_difference(_last_sent_yaw, _facing_yaw)) > NET_YAW_EPSILON:
		return true
	return false


func _broadcast_state() -> void:
	_net_initialized = true
	_last_sent_pos = global_position
	_last_sent_yaw = _facing_yaw
	_last_sent_state = int(_state)
	_sync_motion.rpc(global_position, _facing_yaw, int(_state))


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_motion(next_position: Vector3, next_yaw: float, next_state: int) -> void:
	if _is_server():
		return
	_remote_pos = next_position
	_remote_yaw = next_yaw
	_has_remote_target = true
	_state = next_state as WanderState
	if global_position.distance_to(next_position) > REMOTE_SNAP_DISTANCE:
		global_position = next_position
		rotation.y = next_yaw


@rpc("authority", "call_remote", "reliable")
func _sync_death(killer_id: int) -> void:
	_begin_death(killer_id)


# =============================================================================
# Damage / death
# =============================================================================

func _server_die(attacker_id: int) -> void:
	if _is_dead:
		return
	_apply_hunter_penalty(attacker_id)
	_begin_death(attacker_id)
	_sync_death.rpc(attacker_id)


func _apply_hunter_penalty(attacker_id: int) -> void:
	if attacker_id <= 0:
		return
	if Network == null or not Network.players.has(attacker_id):
		return
	var role: int = int(Network.players[attacker_id].get("role", -1))
	if role != Network.Role.HUNTER:
		return
	var hunter: Node = _find_player_node(attacker_id)
	if hunter != null and hunter.has_method("apply_animal_kill_penalty"):
		hunter.apply_animal_kill_penalty(ANIMAL_KILL_PENALTY, species_id)


func _find_player_node(peer_id: int) -> Node:
	if not is_inside_tree():
		return null
	for raw_player: Node in get_tree().get_nodes_in_group("players"):
		if str(raw_player.name) == str(peer_id):
			return raw_player
	return null


func _begin_death(killer_id: int) -> void:
	if _is_dead:
		return
	_is_dead = true
	_death_timer = DEATH_DESPAWN_SECONDS
	_end_chase()
	# Runs on every peer (server direct + clients via _sync_death), so the kill
	# feed is announced globally: which hunter killed which animal.
	if killer_id > 0:
		KillFeed.report_animal_kill(killer_id, display_name)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_in_group("replicable_props"):
		remove_from_group("replicable_props")
	if is_in_group("killable_animals"):
		remove_from_group("killable_animals")
	set_physics_process(false)
	set_process(true)
	# Same vanish as a dying player: dissolve the visual away. No tombstone.
	if _visual_root != null:
		if _anim_player != null:
			_anim_player.stop()
		_spawn_death_dissolve()
		_visual_root.visible = false
		_death_timer = DEATH_DISSOLVE_SECONDS + 0.15


# =============================================================================
# Visual + animation (clients + listen-host; never on a dedicated headless server)
# =============================================================================

func _process(delta: float) -> void:
	if _is_dead:
		_death_timer -= delta
		if _dissolve_material != null and is_instance_valid(_dissolve_material):
			_dissolve_elapsed += delta
			var k: float = clampf(_dissolve_elapsed / DEATH_DISSOLVE_SECONDS, 0.0, 1.0)
			_dissolve_material.set_shader_parameter("t", 1.0 - cos(k * PI * 0.5))
		if _death_timer <= 0.0:
			if _dissolve_root != null and is_instance_valid(_dissolve_root):
				_dissolve_root.queue_free()
			queue_free()
		return

	if not _is_server() and _has_remote_target:
		_interpolate_remote(delta)
	if _visual_root == null:
		return
	if _has_real_anim:
		_drive_animation()
	else:
		_apply_liveliness(delta)


func _interpolate_remote(delta: float) -> void:
	var blend: float = clampf(1.0 - exp(-REMOTE_LERP_SPEED * maxf(delta, 0.0)), 0.0, 1.0)
	global_position = global_position.lerp(_remote_pos, blend)
	rotation.y = rotate_toward(rotation.y, _remote_yaw, TURN_RATE * delta)
	_facing_yaw = rotation.y


func _drive_animation() -> void:
	var moving: bool = _state == WanderState.WALK or _state == WanderState.CHASE
	if moving and not _walk_clip.is_empty():
		if _anim_player.current_animation != _walk_clip:
			_anim_player.play(_walk_clip)
		_anim_player.speed_scale = 1.4 if _state == WanderState.CHASE else 1.0
	elif not moving:
		if not _idle_clip.is_empty():
			if _anim_player.current_animation != _idle_clip:
				_anim_player.play(_idle_clip)
			_anim_player.speed_scale = 1.0
		elif _anim_player.is_playing():
			_anim_player.pause()  # no idle clip (deer) — freeze the walk pose


func _apply_liveliness(delta: float) -> void:
	# No skeletal anim clips exist, so suggest life with subtle node motion.
	var moving: bool = _state != WanderState.IDLE
	_live_phase += delta * (8.0 if moving else 2.4)
	if moving:
		var bob: float = sin(_live_phase) * 0.045 * model_scale
		_visual_root.position.y = _visual_rest_y + maxf(bob, -_visual_rest_y)
		_visual_root.rotation.z = sin(_live_phase * 0.5) * 0.05
	else:
		_visual_root.position.y = _visual_rest_y
		_visual_root.rotation.z = 0.0
		_visual_root.scale = Vector3(model_scale, model_scale * (1.0 + sin(_live_phase) * 0.02), model_scale)


func _should_build_visual() -> bool:
	return not RuntimeMode.is_headless()


func _build_visual() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		_visual_root = null
	if scene_path.is_empty():
		return
	var packed: PackedScene = _load_cached_scene(scene_path)
	if packed == null:
		push_warning("AnimalProp visual scene missing: " + scene_path)
		return
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		return
	instance.name = "AnimalVisual"
	add_child(instance)
	_visual_root = instance
	if texture_mode == "atlas":
		_apply_atlas(instance)
	_disable_nested_collisions(instance)
	_setup_animation(instance)
	_auto_scale_visual()
	_ground_visual()


# Models ship at wildly different native sizes (a raw mammoth is hundreds of
# metres). Measure the real in-tree AABB at scale 1 and scale uniformly so the
# standing height matches body_height. Drives both the visual and the disguise
# preset scale (get_disguise_preset reads model_scale).
func _auto_scale_visual() -> void:
	if _visual_root == null:
		return
	_visual_root.scale = Vector3.ONE
	var raw: AABB = _calculate_visual_bounds()
	if raw.size.y > 0.0001:
		model_scale = clampf(body_height / raw.size.y, 0.00001, 10000.0)
	_visual_root.scale = Vector3(model_scale, model_scale, model_scale)


func _setup_animation(node: Node) -> void:
	_anim_player = _find_animation_player(node)
	if _anim_player == null:
		_has_real_anim = false
		return
	var clips: PackedStringArray = _anim_player.get_animation_list()
	var single: String = ""
	var non_reset_count: int = 0
	for clip: String in clips:
		if clip == "RESET":
			continue
		non_reset_count += 1
		single = clip
		var lower: String = clip.to_lower()
		if _walk_clip.is_empty() and (lower.contains("walk") or lower.contains("run")):
			_walk_clip = clip
		if _idle_clip.is_empty() and lower.contains("idle"):
			_idle_clip = clip
	# Deer ship a single unnamed action — treat it as the walk cycle.
	if _walk_clip.is_empty() and non_reset_count >= 1:
		_walk_clip = single
	_has_real_anim = not _walk_clip.is_empty() or not _idle_clip.is_empty()
	# Make the walk/idle loop instead of playing once.
	for clip: String in [_walk_clip, _idle_clip]:
		if clip.is_empty():
			continue
		var anim: Animation = _anim_player.get_animation(clip)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _ground_visual() -> void:
	if _visual_root == null:
		return
	var bounds: AABB = _calculate_visual_bounds()
	if bounds.size != Vector3.ZERO:
		_visual_root.position.y = -bounds.position.y
	_visual_rest_y = _visual_root.position.y


func _apply_atlas(node: Node) -> void:
	var material: Material = _get_atlas_material()
	if material == null:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_atlas(child)


func _disable_nested_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_disable_nested_collisions(child)


# =============================================================================
# Death vanish (dissolve, mirrors the player death effect; no tombstone)
# =============================================================================

func _spawn_death_dissolve() -> void:
	if _visual_root == null or not is_inside_tree():
		return
	var scene_parent: Node = get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_parent()
	if scene_parent == null:
		return
	var clone: Node3D = _visual_root.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if clone == null:
		return
	clone.name = "AnimalDeathDissolve"
	clone.top_level = true
	scene_parent.add_child(clone)
	clone.global_transform = _visual_root.global_transform
	var material: ShaderMaterial = _make_dissolve_material()
	if _apply_dissolve_material(clone, material) <= 0:
		clone.queue_free()
		return
	_dissolve_root = clone
	_dissolve_material = material
	_dissolve_elapsed = 0.0


func _make_dissolve_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = DEATH_DISSOLVE_SHADER
	material.set_shader_parameter("t", 0.0)
	material.set_shader_parameter("albedo_and_emissive_color", Color(1.0, 1.0, 1.0, 1.0))
	material.set_shader_parameter("edge_color", Color(0.62, 1.0, 0.25, 1.0))
	material.set_shader_parameter("noise_scale", 1.65)
	material.set_shader_parameter("edge_width", 0.055)
	var noise: NoiseTexture2D = NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fast_noise: FastNoiseLite = FastNoiseLite.new()
	fast_noise.seed = _rng.randi()
	fast_noise.frequency = 0.038
	fast_noise.fractal_octaves = 4
	noise.noise = fast_noise
	material.set_shader_parameter("noise_tex", noise)
	return material


func _apply_dissolve_material(node: Node, material: ShaderMaterial) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		count += 1
	for child in node.get_children():
		count += _apply_dissolve_material(child, material)
	return count


# =============================================================================
# Helpers
# =============================================================================

func _build_collision() -> void:
	if _collision_shape == null or not is_instance_valid(_collision_shape):
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "AnimalBody"
		add_child(_collision_shape)
	var r: float = maxf(body_radius, 0.12)
	var h: float = maxf(body_height, 0.2)
	var shape: Shape3D
	if h <= r * 2.0 + 0.02:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = maxf(r, h * 0.5)
		_collision_half_height = sphere.radius
		shape = sphere
	else:
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = r
		capsule.height = h
		_collision_half_height = h * 0.5
		shape = capsule
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, _collision_half_height, 0.0)


func _apply_authority_processing() -> void:
	var server: bool = _is_server()
	set_physics_process(server and not _is_dead)
	set_process(true)


func _is_server() -> bool:
	if not is_inside_tree():
		return true
	return RuntimeMode.is_multiplayer_server(multiplayer) or multiplayer.multiplayer_peer == null


func _get_atlas_material() -> Material:
	if _atlas_material_cache != null:
		return _atlas_material_cache
	var resource: Resource = load(AnimalCatalog.ATLAS_MATERIAL_PATH)
	if resource is Material:
		_atlas_material_cache = resource as Material
		return _atlas_material_cache
	var texture: Texture2D = load(AnimalCatalog.ATLAS_PATH) as Texture2D
	if texture == null:
		return null
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	_atlas_material_cache = material
	return _atlas_material_cache


static func _load_cached_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	var resource: Resource = load(path)
	var scene: PackedScene = resource as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene


func _calculate_visual_bounds() -> AABB:
	if _visual_root == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_visual_root, meshes)
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var local: AABB = _transform_aabb(global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.mesh.get_aabb())
		if not has_bounds:
			bounds = local
			has_bounds = true
		else:
			bounds = bounds.merge(local)
	return bounds if has_bounds else AABB()


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _transform_aabb(source_transform: Transform3D, box: AABB) -> AABB:
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point: Vector3 = box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed: Vector3 = source_transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
