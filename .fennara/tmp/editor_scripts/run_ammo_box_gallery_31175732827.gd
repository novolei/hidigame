@tool
extends RefCounted

const ITEMS: Array[Dictionary] = [
	{"path": "res://assets/pickups/ammo_boxes/small_ammo_box_30.glb", "name": "SmallAmmoBox30", "label": "+30"},
	{"path": "res://assets/pickups/ammo_boxes/medium_ammo_crate_60.glb", "name": "MediumAmmoCrate60", "label": "+60"},
	{"path": "res://assets/pickups/ammo_boxes/large_ammo_supply_box_120.glb", "name": "LargeAmmoSupplyBox120", "label": "FULL"},
	{"path": "res://assets/pickups/ammo_boxes/special_ammo_cache.glb", "name": "SpecialAmmoCache", "label": "SPECIAL"},
]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	if not (root is Node3D):
		ctx.error("Root must be Node3D")
		return
	var root_3d: Node3D = root as Node3D
	ctx.clear_children(root_3d)

	var spacing: float = 2.8
	for index: int in range(ITEMS.size()):
		var item: Dictionary = ITEMS[index]
		var asset_path: String = String(item["path"])
		var node_name: String = String(item["name"])
		var x: float = (float(index) - 1.5) * spacing
		var instance: Node3D = ctx.instance_scene(root_3d, asset_path, node_name) as Node3D
		if instance == null:
			ctx.error("Failed to instance %s" % asset_path)
			return
		instance.position = Vector3(x, 0.0, 0.0)
		instance.rotation_degrees = Vector3(0.0, -18.0, 0.0)
		instance.scale = Vector3.ONE * 0.85

		var label: Label3D = Label3D.new()
		label.name = node_name + "Label"
		label.text = String(item["label"])
		label.font_size = 36
		label.pixel_size = 0.008
		label.position = Vector3(x, -0.85, 1.15)
		label.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
		label.modulate = Color(1.0, 0.92, 0.58, 1.0)
		root_3d.add_child(label)
		ctx.own(label)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 3.2
	root_3d.add_child(light)
	ctx.own(light)

	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "FillLight"
	fill.position = Vector3(0.0, 3.2, 4.0)
	fill.light_energy = 2.0
	fill.omni_range = 10.0
	root_3d.add_child(fill)
	ctx.own(fill)

	var camera: Camera3D = Camera3D.new()
	camera.name = "GalleryCamera"
	camera.position = Vector3(0.0, 3.4, 9.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.05, 0.0), Vector3.UP)
	camera.fov = 38.0
	camera.current = true
	root_3d.add_child(camera)
	ctx.own(camera)

	ctx.mark_modified()
	ctx.log("Updated AmmoBoxGallery framing with %d asset instances" % ITEMS.size())
