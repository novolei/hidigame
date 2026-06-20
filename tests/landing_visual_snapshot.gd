extends Node

const OUTPUT_PATH := "res://.codex_landing_visual.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	I18n.set_language_setting("en")
	Network.lobby_config["room_name"] = "Bili Room"
	_disable_boot_splash()

	var ui_scene: PackedScene = load("res://scenes/ui/main_menu_ui.tscn")
	var ui: MainMenuUI = ui_scene.instantiate()
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	ui.nick_input.text = "Bili.Waytoon"
	ui.room_name_input.text = "Bili Room"
	ui.address_input.text = "Bili Room"
	ui.join_lobby_input.text = "6KZ7"
	ui._on_lobby_password_text_changed(ui.join_lobby_input.text)
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[LandingVisualSnapshot] saved ", OUTPUT_PATH)
	get_tree().quit(0)


func _disable_boot_splash() -> void:
	var splash := get_node_or_null("/root/BootSplashPlus")
	if splash:
		splash.queue_free()
