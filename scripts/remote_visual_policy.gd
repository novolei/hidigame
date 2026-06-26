extends RefCounted
class_name RemoteVisualPolicy

const DEFAULT_REMOTE_LOD_BIAS := 0.65


static func apply_to_remote(root: Node, is_local_authority: bool, lod_bias: float = DEFAULT_REMOTE_LOD_BIAS) -> void:
	if root == null or is_local_authority:
		return
	_apply_recursive(root, lod_bias)


static func apply_to_any(root: Node, lod_bias: float = DEFAULT_REMOTE_LOD_BIAS) -> void:
	if root == null:
		return
	_apply_recursive(root, lod_bias)


static func _apply_recursive(node: Node, lod_bias: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		geometry.lod_bias = minf(geometry.lod_bias, lod_bias)
	for child in node.get_children():
		if child is Node:
			_apply_recursive(child as Node, lod_bias)
