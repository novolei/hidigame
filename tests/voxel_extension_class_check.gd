extends Node

const REQUIRED_CLASSES := [
	"VoxelTerrain",
	"VoxelTool",
	"VoxelMesherTransvoxel",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for voxel_class in REQUIRED_CLASSES:
		if not ClassDB.class_exists(voxel_class):
			failures.append("Missing voxel extension class: " + voxel_class)

	if failures.is_empty():
		print("[VoxelExtensionClassCheck] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[VoxelExtensionClassCheck] " + failure)
		get_tree().quit(1)
