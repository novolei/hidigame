@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var body: Node3D = root.get_node_or_null("3DGodotRobot") as Node3D
	var offset: Node3D = root.get_node_or_null("SpringArmOffset") as Node3D
	var spring: SpringArm3D = root.get_node_or_null("SpringArmOffset/SpringArm3D") as SpringArm3D
	if body == null or offset == null or spring == null:
		ctx.error("Missing body, offset, or spring arm")
		return
	var original_body_rotation: Vector3 = body.rotation
	var original_offset_rotation: Vector3 = offset.rotation
	var original_spring_rotation: Vector3 = spring.rotation
	var length: float = 5.2
	var body_samples: Array[float] = [0.0, PI * 0.25, PI * 0.5, -PI * 0.5]
	for body_yaw: float in body_samples:
		body.rotation.y = body_yaw
		var candidate_yaws: Dictionary = {
			"fixed_zero": 0.0,
			"fixed_pi": PI,
			"body_yaw": body_yaw,
			"body_yaw_plus_pi": wrapf(body_yaw + PI, -PI, PI),
			"body_yaw_minus_pi": wrapf(body_yaw - PI, -PI, PI)
		}
		var body_origin: Vector3 = body.global_position
		var visual_forward: Vector3 = -body.global_transform.basis.z
		visual_forward.y = 0.0
		if visual_forward.length_squared() <= 0.0001:
			continue
		visual_forward = visual_forward.normalized()
		for label: String in candidate_yaws.keys():
			offset.rotation.y = float(candidate_yaws[label])
			spring.rotation.x = deg_to_rad(-3.0)
			var camera_side_direction: Vector3 = spring.global_transform.basis.z
			camera_side_direction.y = 0.0
			if camera_side_direction.length_squared() <= 0.0001:
				continue
			camera_side_direction = camera_side_direction.normalized()
			var front_dot: float = camera_side_direction.dot(visual_forward)
			ctx.log("body_yaw_deg=%0.1f candidate=%s yaw_deg=%0.1f front_dot=%0.3f" % [rad_to_deg(body_yaw), label, rad_to_deg(float(candidate_yaws[label])), front_dot])
	body.rotation = original_body_rotation
	offset.rotation = original_offset_rotation
	spring.rotation = original_spring_rotation
