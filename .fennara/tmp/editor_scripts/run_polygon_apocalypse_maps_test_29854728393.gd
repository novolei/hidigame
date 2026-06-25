@tool
extends RefCounted

func run(ctx) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var names: Array[String] = []
	for item: Dictionary in material.get_property_list():
		var property_name: String = str(item.get("name", ""))
		if property_name.contains("metallic") or property_name.contains("roughness") or property_name.contains("texture"):
			names.append(property_name)
	names.sort()
	ctx.log("properties=" + ",".join(names))
