extends Node3D

@onready var spot_light: SpotLight3D = $SpotLight3D


func _ready() -> void:
	if spot_light:
		spot_light.shadow_enabled = false

	# Randomize the forklift model.
	randomize()
	var model_root := get_child(0)
	var children := model_root.get_children() if model_root else []
	var child_count := children.size()
	if child_count <= 0:
		return
	var which_enabled := randi() % child_count
	for i in range(child_count):
		var child := children[i] as Node3D
		if child:
			child.visible = i == which_enabled
