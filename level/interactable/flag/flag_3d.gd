extends Node3D

@onready var _area_3d: Area3D = %Area3D


func _ready() -> void:
	_area_3d.body_entered.connect(func (_body_that_entered: PhysicsBody3D) -> void:
		var events := get_node_or_null("/root/Events")
		if events and events.has_signal("flag_reached"):
			events.flag_reached.emit()
	)
