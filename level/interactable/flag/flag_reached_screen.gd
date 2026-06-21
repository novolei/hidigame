extends CanvasLayer

@onready var _animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	var events := get_node_or_null("/root/Events")
	if not events or not events.has_signal("flag_reached"):
		return
	events.flag_reached.connect(func on_flag_reached() -> void:
		await get_tree().create_timer(2.0).timeout
		_animation_player.play("fade_in")
		await _animation_player.animation_finished
		get_tree().quit()
	)
