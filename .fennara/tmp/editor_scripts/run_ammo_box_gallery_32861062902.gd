@tool
extends RefCounted

const AmmoPickupScript: Script = preload("res://scripts/ammo_pickup.gd")

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s" % String(root.name))
	var items: Array[Dictionary] = [
		{"node":"SmallAmmoBox30", "label":"SmallAmmoBox30Label", "type": AmmoPickupScript.AmmoType.SMALL, "x": -1.35},
		{"node":"MediumAmmoCrate60", "label":"MediumAmmoCrate60Label", "type": AmmoPickupScript.AmmoType.MEDIUM, "x": -0.45},
		{"node":"LargeAmmoSupplyBox120", "label":"LargeAmmoSupplyBox120Label", "type": AmmoPickupScript.AmmoType.LARGE, "x": 0.45},
		{"node":"SpecialAmmoCache", "label":"SpecialAmmoCacheLabel", "type": AmmoPickupScript.AmmoType.SPECIAL, "x": 1.35},
	]
	var changed: int = 0
	for item: Dictionary in items:
		var node_name: String = str(item["node"])
		var label_name: String = str(item["label"])
		var ammo_type: int = int(item["type"])
		var x_pos: float = float(item["x"])
		var visual: Node3D = root.get_node_or_null(node_name) as Node3D
		if visual == null:
			ctx.error("Missing visual " + node_name)
			return
		visual.position = Vector3(x_pos, 0.0, 0.0)
		visual.scale = AmmoPickupScript.visual_scale_for_type(ammo_type)
		ctx.log("%s scale=%s" % [node_name, str(visual.scale)])
		var label: Label3D = root.get_node_or_null(label_name) as Label3D
		if label != null:
			label.position = Vector3(x_pos, AmmoPickupScript.label_height_for_type(ammo_type), 0.0)
			label.pixel_size = 0.003
		changed += 1
	var camera: Camera3D = root.get_node_or_null("GalleryCamera") as Camera3D
	if camera != null:
		camera.position = Vector3(0.0, 1.35, 3.1)
		camera.look_at_from_position(camera.position, Vector3(0.0, 0.25, 0.0), Vector3.UP)
		camera.fov = 35.0
	ctx.log("updated=%d" % changed)
	ctx.mark_modified()
