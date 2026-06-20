extends Node

const OUTPUT_PATH := "res://.codex_lobby_chat.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	I18n.set_language_setting("en")
	_disable_boot_splash()
	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Bili.Waytoon", Network.Role.HUNTER),
		3: _player("Specter", Network.Role.STALKER),
		4: _player("Newcomer", Network.Role.NONE),
	}
	Network.lobby_config.merge({
		"lobby_id": "6KZ7",
		"map": "Street Block",
		"variant": "Fast Hunt",
		"condition": "Night",
		"game_show": "Chaos Show",
		"match_duration_sec": 900,
		"prep_duration_sec": 60,
		"host_hunter_count": 1,
	}, true)

	var ui_scene: PackedScene = load("res://scenes/ui/main_menu_ui.tscn")
	var ui: MainMenuUI = ui_scene.instantiate()
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.show_lobby("6KZ7", true)
	ui.update_lobby(Network.players, Network.lobby_config)
	ui.lobby_chat_messages.append({"nick": "Bili.Waytoon", "text": "hi"})
	ui._set_lobby_chat_visible(true)
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[LobbyChatSnapshot] saved ", OUTPUT_PATH)
	get_tree().quit(0)


func _disable_boot_splash() -> void:
	var splash := get_node_or_null("/root/BootSplashPlus")
	if splash:
		splash.queue_free()


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Character.SkinColor.BLUE,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
	}
