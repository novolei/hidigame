extends Node

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	Network.server_port = 19120
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var synced_players := {
		1: _player("Host", Network.Role.HUNTER),
		2: _player("StalkerClient", Network.Role.STALKER),
	}
	Network._broadcast_full_sync(synced_players, Network.lobby_config.duplicate())
	await get_tree().process_frame

	var players_container: Node = level.get_node("PlayersContainer")
	_expect(not players_container.has_node("2"), "Full sync should not spawn player nodes while still in lobby")

	level.game_state = level.GameState.SKIN_CONFIG
	level._ensure_player_nodes_from_network()
	await get_tree().process_frame
	_expect(not players_container.has_node("2"), "Skin selection should not spawn player nodes")

	level.game_state = level.GameState.MATCH_INTRO
	level._ensure_player_nodes_from_network()
	await get_tree().process_frame
	_expect(not players_container.has_node("2"), "Match intro countdown should not spawn player nodes")

	level._on_prep_phase_started(30.0)
	await get_tree().process_frame
	_expect(players_container.has_node("2"), "Prep start should spawn player nodes after skin selection and intro countdown")

	var tracked_player := players_container.get_node_or_null("2") as Node3D
	if tracked_player:
		var preserved_position := Vector3(12.5, 1.25, -7.75)
		tracked_player.global_position = preserved_position
		Network.players[2]["character_model"] = "party_monster_c01"
		Network.players[2]["party_monster_accessories"] = {"eyes": "Eye02"}
		Network._broadcast_full_sync(Network.players.duplicate(true), Network.lobby_config.duplicate(true))
		await get_tree().process_frame
		_expect(tracked_player.global_position.distance_to(preserved_position) < 0.001, "Accessory full sync should not reposition an existing player node")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	_reset_network_state()
	Network.server_port = Network.SERVER_PORT

	if failures.is_empty():
		print("[PlayerSpawnGateTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[PlayerSpawnGateTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.players.clear()
	Network.card_drafts.clear()
	Network.card_loadouts.clear()
	Network.lobby_config["role_locked"] = false


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Character.SkinColor.BLUE,
		"character_model": CharacterSkinCatalog.DEFAULT_ID,
		"role": role,
		"alive": true,
		"role_locked": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
