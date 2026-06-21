extends Area3D


func _ready() -> void:
	body_entered.connect(func (_body_that_entered: PhysicsBody3D) -> void:
		await get_tree().process_frame
		var events := get_node_or_null("/root/Events")
		if events and events.has_signal("kill_plane_touched"):
			events.kill_plane_touched.emit(_body_that_entered)
		elif _body_that_entered and _body_that_entered.has_method("_respawn"):
			_body_that_entered._respawn()
	)
