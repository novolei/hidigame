extends Control

var _overlay: CharacterSetupOverlay = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay = CharacterSetupOverlay.new()
	add_child(_overlay)
	_overlay.show_setup(15.0)
