extends Node3D
class_name GardenMap

const WORLD_LAYER := 2
const COLLISION_ROOT_NAME := "GardenCollisionRoot"

@export var generate_collision := true
@export var max_collision_meshes := 512

var _collision_generated := false


func _ready() -> void:
	if generate_collision:
		call_deferred("_ensure_static_collision")


func _ensure_static_collision() -> void:
	if _collision_generated or get_node_or_null(COLLISION_ROOT_NAME):
		return
	_collision_generated = true

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)

	var collision_root := Node3D.new()
	collision_root.name = COLLISION_ROOT_NAME
	add_child(collision_root, true)

	var created := 0
	for mesh_instance in meshes:
		if created >= max_collision_meshes:
			break
		if not _mesh_should_collide(mesh_instance):
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if not shape:
			continue
		var body := StaticBody3D.new()
		body.name = _collision_name(mesh_instance)
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		collision_root.add_child(body, true)
		body.global_transform = mesh_instance.global_transform

		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		shape_node.shape = shape
		body.add_child(shape_node)
		created += 1

	if created == 0:
		_add_fallback_ground(collision_root)


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _mesh_should_collide(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance.mesh or not mesh_instance.visible:
		return false
	var bounds := mesh_instance.get_aabb()
	return bounds.size.length_squared() > 0.0001


func _collision_name(mesh_instance: MeshInstance3D) -> String:
	var clean_name := String(mesh_instance.name).replace("@", "").replace(":", "_")
	if clean_name.is_empty():
		clean_name = "Mesh"
	return clean_name + "_Collision"


func _add_fallback_ground(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GardenFallbackGround"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body, true)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 0.2, 120.0)
	shape_node.shape = shape
	shape_node.position.y = -0.1
	body.add_child(shape_node)
