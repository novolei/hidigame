@tool
extends RefCounted

const ASSETS: Array[String] = [
	"res://assets/pickups/ammo_boxes/small_ammo_box_30.glb",
	"res://assets/pickups/ammo_boxes/medium_ammo_crate_60.glb",
	"res://assets/pickups/ammo_boxes/large_ammo_supply_box_120.glb",
	"res://assets/pickups/ammo_boxes/special_ammo_cache.glb",
]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("probe_scene=%s root=%s" % [ctx.get_scene_path(), String(root.get_name())])
	for asset_path: String in ASSETS:
		var resource: Resource = ResourceLoader.load(asset_path)
		if resource == null:
			ctx.error("failed_load=%s" % asset_path)
			return
		if not (resource is PackedScene):
			ctx.error("not_packed_scene=%s class=%s" % [asset_path, resource.get_class()])
			return
		var packed: PackedScene = resource as PackedScene
		if not packed.can_instantiate():
			ctx.error("cannot_instantiate=%s" % asset_path)
			return
		var instance: Node = packed.instantiate()
		if instance == null:
			ctx.error("instantiate_null=%s" % asset_path)
			return
		var stats: Dictionary = _collect_stats(instance)
		ctx.log("asset=%s root_class=%s mesh_instances=%d surfaces=%d bounds_pos=%s bounds_size=%s" % [asset_path, instance.get_class(), int(stats["mesh_count"]), int(stats["surface_count"]), str(stats["bounds_pos"]), str(stats["bounds_size"])])
		instance.free()

func _collect_stats(node: Node) -> Dictionary:
	var mesh_count: int = 0
	var surface_count: int = 0
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh_instance: MeshInstance3D = current as MeshInstance3D
			mesh_count += 1
			if mesh_instance.mesh != null:
				surface_count += mesh_instance.mesh.get_surface_count()
				var local_aabb: AABB = mesh_instance.get_aabb()
				if not has_bounds:
					bounds = local_aabb
					has_bounds = true
				else:
					bounds = bounds.merge(local_aabb)
		var children: Array[Node] = current.get_children()
		for child: Node in children:
			stack.append(child)
	return {
		"mesh_count": mesh_count,
		"surface_count": surface_count,
		"bounds_pos": bounds.position,
		"bounds_size": bounds.size,
	}
