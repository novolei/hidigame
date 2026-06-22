extends Node3D

@export var material_override: Material
@export var disable_collision_objects := true
@export var force_material_override := true


func _ready() -> void:
	apply_to_tree(self)


func apply_to_tree(node: Node) -> void:
	if node is MeshInstance3D and material_override:
		var mesh_instance := node as MeshInstance3D
		if force_material_override or not _mesh_instance_has_material(mesh_instance):
			mesh_instance.material_override = material_override
	if disable_collision_objects:
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		elif node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = 0
			(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		apply_to_tree(child)


func _mesh_instance_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override:
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if mesh_instance.get_surface_override_material(i):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(i):
				return true
	return false
