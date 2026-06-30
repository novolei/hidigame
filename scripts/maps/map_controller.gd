extends Node3D
class_name MapController

# Shared preparation behavior for any prop-hunt map root. Attach this (or a
# subclass) to a map scene root so every map is grounded, collision-normalized,
# lit, and backed by a gameplay support floor through ONE code path instead of
# per-map special cases scattered across level.gd.
#
# Authority note: this runs on every peer that instantiates the map (it only
# mutates the local scene graph: collision layers, lighting, an invisible floor).
# It performs no networking and creates no audio/particles, so it is safe on the
# dedicated headless server as well.

const WORLD_LAYER: int = 2
# Optional child node (Node3D of Marker3D children) declaring authored in-map
# spawn positions, copied from the map's native design. When present, level.gd
# places in-map roles here instead of reusing the origin-based Warehouse layout.
const SPAWN_POINTS_NODE: StringName = &"PlayerSpawnpoints"
# Bodies/shapes carrying this group are recognized by level.gd as the map's
# fall-through guard + spawn-grounding reference, for any map (not just polygon).
const SUPPORT_GROUP: StringName = &"map_gameplay_support"
const SUPPORT_BODY_NAME: StringName = &"MapGameplaySupport"
const SUPPORT_SHAPE_NAME: StringName = &"GameplaySupportShape"
const SUPPORT_THICKNESS: float = 0.18
const GROUND_PROBE_TOP: float = 1200.0
const GROUND_PROBE_BOTTOM: float = -1200.0

@export var lighting_mode: MapProfile.Lighting = MapProfile.Lighting.STRIP_ALL
@export var collision_mode: MapProfile.Collision = MapProfile.Collision.ADAPT_LAYERS
@export var ground_align_mode: MapProfile.GroundAlign = MapProfile.GroundAlign.NONE
@export var ground_y: float = 0.0
@export var max_generated_collision_meshes: int = 768

@export_group("Gameplay Support Floor")
@export var add_support_floor: bool = true
@export var support_size: Vector2 = Vector2(110.0, 110.0)
@export var support_margin: float = 18.0

@export_group("Ground Probe")
@export var spawn_surface_probe_radius: float = 16.0
@export var spawn_surface_probe_rings: int = 2

var _prepared: bool = false
var _collision_generated: bool = false
var _playable_bounds: AABB = AABB()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_meta("map_controller", true)
	call_deferred("prepare")


# Idempotent: safe to call once from _ready or explicitly from the loader.
func prepare() -> void:
	if _prepared:
		return
	_prepared = true
	_apply_lighting_policy()
	_apply_collision_policy()
	# ProtonScatter (vegetation) raycasts onto the terrain collider; at _ready the physics space
	# isn't populated yet, so an authored scatter comes up empty. Rebuild it once physics is live.
	call_deferred("_rebuild_scatter_nodes")
	_playable_bounds = _compute_playable_bounds()
	if ground_align_mode == MapProfile.GroundAlign.BOTTOM:
		_align_bottom_to_ground()
		_playable_bounds = _compute_playable_bounds()
	if ground_align_mode == MapProfile.GroundAlign.SPAWN_SURFACE:
		call_deferred("_align_spawn_surface_then_support")
	elif add_support_floor:
		_ensure_support_floor()


func get_playable_bounds() -> AABB:
	return _playable_bounds


func get_support_body() -> StaticBody3D:
	return get_node_or_null(NodePath(SUPPORT_BODY_NAME)) as StaticBody3D


# True when the map ships authored in-map spawn markers (its native design),
# so the spawn system should use them instead of the Warehouse origin layout.
func has_authored_spawns() -> bool:
	var node := get_node_or_null(NodePath(SPAWN_POINTS_NODE))
	if node == null:
		return false
	for child in node.get_children():
		if child is Marker3D:
			return true
	return false


# World-space transforms of every authored Marker3D spawn point (empty if none).
func get_player_spawn_points() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var node := get_node_or_null(NodePath(SPAWN_POINTS_NODE))
	if node == null:
		return result
	for child in node.get_children():
		if child is Marker3D:
			result.append((child as Marker3D).global_transform)
	return result


# -- Lighting -----------------------------------------------------------------

func _apply_lighting_policy() -> void:
	if lighting_mode == MapProfile.Lighting.KEEP:
		return
	if lighting_mode == MapProfile.Lighting.STRIP_ALL:
		for node in find_children("*", "WorldEnvironment", true, false):
			var world_environment := node as WorldEnvironment
			if world_environment:
				world_environment.environment = null
	for node in find_children("*", "DirectionalLight3D", true, false):
		var directional := node as DirectionalLight3D
		if directional:
			directional.visible = false
			directional.light_energy = 0.0


# -- Collision ----------------------------------------------------------------

func _apply_collision_policy() -> void:
	match collision_mode:
		MapProfile.Collision.ADAPT_LAYERS:
			_adapt_collision_layers()
		MapProfile.Collision.GENERATE:
			_generate_trimesh_collision()
		_:
			pass


func _adapt_collision_layers() -> void:
	# Add the world layer to already-authored colliders so players and props (which mask the
	# world layer) collide with the map. We ADD it rather than replace, so a collider's original
	# layer survives — e.g. terrain stays on layer 1 where ProtonScatter raycasts its vegetation.
	# Area3D triggers and explicitly-disabled (layer 0) bodies are left untouched.
	for node in find_children("*", "CollisionObject3D", true, false):
		var collision := node as CollisionObject3D
		if collision == null or collision is Area3D:
			continue
		if collision.collision_layer == 0:
			continue
		collision.collision_layer |= WORLD_LAYER


func _generate_trimesh_collision() -> void:
	if _collision_generated:
		return
	_collision_generated = true
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	var collision_root := Node3D.new()
	collision_root.name = "GeneratedMapCollision"
	add_child(collision_root, true)
	var created: int = 0
	for mesh_instance in meshes:
		if created >= max_generated_collision_meshes:
			break
		if not _mesh_is_solid(mesh_instance):
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = String(mesh_instance.name).replace("@", "").replace(":", "_") + "_Collision"
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		collision_root.add_child(body, true)
		body.global_transform = mesh_instance.global_transform
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		shape_node.shape = shape
		body.add_child(shape_node)
		created += 1


# -- Vegetation ---------------------------------------------------------------

# Rebuild ProtonScatter vegetation once physics is live. Scene-authored scatter raycasts onto the
# terrain collider in its project_on_geometry modifier, but at _ready the physics space isn't
# populated yet (and the migrated scene ships no baked output), so it comes up empty. One rebuild
# after a couple of physics frames re-projects the grass/palms onto the now-collidable terrain.
# Visual-only, so it is skipped on a dedicated headless server.
func _rebuild_scatter_nodes() -> void:
	if not is_inside_tree():
		return
	if RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config):
		return
	# Delay past boot/world init before triggering the rebuild. ProtonScatter runs its
	# project_on_geometry physics raycasts on a worker thread, which deadlocks against the engine's
	# physics setup during the first frames; once the world is live the same threaded rebuild runs
	# safely. The synchronous (dbg_disable_thread) path does not actually run the modifier stack, so
	# the threaded path is required to generate any output.
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	for node in find_children("*", "Node3D", true, false):
		if node != self and node.has_method("full_rebuild"):
			node.call("full_rebuild")


# -- Grounding ----------------------------------------------------------------

func _align_bottom_to_ground() -> void:
	var bounds := _compute_playable_bounds()
	if bounds.size == Vector3.ZERO:
		return
	global_position.y += ground_y - bounds.position.y


func _align_spawn_surface_then_support() -> void:
	await get_tree().physics_frame
	_align_spawn_surface_to_ground()
	if add_support_floor:
		_ensure_support_floor()


func _align_spawn_surface_to_ground() -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var heights: Array[float] = []
	for point in _spawn_surface_probe_points():
		var from := Vector3(point.x, GROUND_PROBE_TOP, point.z)
		var to := Vector3(point.x, GROUND_PROBE_BOTTOM, point.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		heights.append((hit.get("position", Vector3.ZERO) as Vector3).y)
	if heights.is_empty():
		return
	heights.sort()
	@warning_ignore("integer_division")
	var mid: int = heights.size() / 2
	var surface_y := heights[mid]
	if heights.size() % 2 == 0:
		surface_y = (heights[mid - 1] + heights[mid]) * 0.5
	var delta_y := ground_y - surface_y
	if is_zero_approx(delta_y):
		return
	global_position.y += delta_y
	_playable_bounds = _compute_playable_bounds()


func _spawn_surface_probe_points() -> Array[Vector3]:
	var points: Array[Vector3] = [Vector3.ZERO]
	var rings: int = maxi(spawn_surface_probe_rings, 1)
	for ring in range(1, rings + 1):
		var radius := spawn_surface_probe_radius * float(ring) / float(rings)
		var samples: int = 8
		for i in range(samples):
			var angle := TAU * float(i) / float(samples)
			points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return points


# -- Support floor ------------------------------------------------------------

func _ensure_support_floor() -> void:
	if get_support_body() != null:
		return
	# Centered on the origin spawn coordinate system (LevelLayout is origin-based),
	# with a fixed size. Deriving center/size from mesh bounds is unsafe for
	# sprawling maps whose far canyon/background geometry pollutes the AABB.
	var center := Vector3(0.0, ground_y, 0.0)
	var size_xz := support_size
	var body := StaticBody3D.new()
	body.name = SUPPORT_BODY_NAME
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.add_to_group(SUPPORT_GROUP)
	body.set_meta("support_size_xz", size_xz)
	body.set_meta("support_top_y", ground_y)
	add_child(body, true)
	body.global_position = Vector3(center.x, ground_y - SUPPORT_THICKNESS * 0.5, center.z)
	var shape_node := CollisionShape3D.new()
	shape_node.name = SUPPORT_SHAPE_NAME
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_xz.x, SUPPORT_THICKNESS, size_xz.y)
	shape_node.shape = shape
	body.add_child(shape_node)


# -- Bounds helpers -----------------------------------------------------------

func _compute_playable_bounds() -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	var has_bounds: bool = false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not _mesh_is_solid(mesh_instance):
			continue
		var transformed := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = transformed
			has_bounds = true
		else:
			bounds = bounds.merge(transformed)
	return bounds if has_bounds else AABB()


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _mesh_is_solid(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null or not mesh_instance.visible:
		return false
	return mesh_instance.get_aabb().size.length_squared() > 0.0001


func _transform_aabb(xform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := xform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
