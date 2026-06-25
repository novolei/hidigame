@tool
extends RefCounted

const LEGACY_COLLIDER_PATHS: Array[String] = [
	"WallNorth/CollisionShape3D",
	"WallSouth/CollisionShape3D",
	"WallEast/CollisionShape3D",
	"WallWest/CollisionShape3D",
	"Gate/CollisionShape3D",
]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var disabled_count: int = 0
	for path: String in LEGACY_COLLIDER_PATHS:
		var shape: CollisionShape3D = root.get_node_or_null(path) as CollisionShape3D
		if shape == null:
			ctx.log("missing legacy collider=%s" % path)
			continue
		shape.disabled = true
		disabled_count += 1
	var gate: Node3D = root.get_node_or_null("Gate") as Node3D
	if gate != null:
		gate.visible = false
	ctx.log("disabled_legacy_preparation_colliders=%d" % disabled_count)
	ctx.mark_modified()
