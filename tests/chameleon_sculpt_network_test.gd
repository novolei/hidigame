extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var old_players := Network.players.duplicate(true)
	Network.players.clear()
	Network.players[1] = {
		"name": "HunterProbe",
		"role": Network.Role.HUNTER,
		"character_model": CharacterSkinCatalog.DEFAULT_ID,
	}

	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player = player_scene.instantiate()
	player.name = "1"
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame

	player.submit_sculpt_stroke_batch(
		PackedStringArray(["add"]),
		PackedVector3Array([Vector3(0.0, 1.0, 0.0)]),
		PackedFloat32Array([0.22]),
		PackedFloat32Array([1.0])
	)
	_expect(player.get_node_or_null("ChameleonSculptSystem") == null, "Non-Chameleon sculpt batches should be rejected without spawning a sculpt system")

	Network.players[1]["role"] = Network.Role.CHAMELEON
	player._on_role_changed(1, Network.Role.CHAMELEON)
	await get_tree().process_frame
	var system = player.get_node_or_null("ChameleonSculptSystem")
	_expect(system == null, "Chameleon sculpt system should stay lazy until the first sculpt batch")
	player.submit_sculpt_stroke_batch(
		PackedStringArray(["add", "stretch"]),
		PackedVector3Array([
			player.global_position + Vector3(0.36, 1.0, 0.0),
			player.global_position + Vector3(0.36, 1.05, 0.04),
		]),
		PackedFloat32Array([0.30, 0.24]),
		PackedFloat32Array([1.0, 0.8])
	)
	await get_tree().process_frame
	system = player.get_node_or_null("ChameleonSculptSystem")
	_expect(system != null, "First Chameleon sculpt batch should attach a sculpt system")
	if system:
		var summary: Dictionary = system.call("get_debug_summary")
		_expect(int(summary.get("stroke_count", 0)) == 2, "Chameleon local sculpt batch should apply Add and Stretch when no server peer is active")
		var shell := system.get("shell") as Node
		if shell:
			system.apply_sculpt_stroke_batch(
				PackedStringArray(["add"]),
				PackedVector3Array([shell.global_transform * Vector3(0.36, 0.95, 0.0)]),
				PackedFloat32Array([0.32]),
				PackedFloat32Array([1.0])
			)
			var reset_before := int(shell.call("get_vertex_checksum"))
			player.apply_chameleon_sculpt_counterplay_reset(
				shell.global_transform * Vector3(0.36, 0.95, 0.0),
				0.52,
				0.6
			)
			await get_tree().process_frame
			_expect(int(shell.call("get_vertex_checksum")) != reset_before, "Counterplay reset RPC path should soften the active freeform clay shell")

			system.apply_sculpt_stroke_batch(
				PackedStringArray(["add"]),
				PackedVector3Array([shell.global_transform * Vector3(0.36, 0.95, 0.0)]),
				PackedFloat32Array([0.32]),
				PackedFloat32Array([1.0])
			)
			var scan_before := int(shell.call("get_vertex_checksum"))
			var hunter := Node3D.new()
			hunter.name = "HunterScanProbe"
			add_child(hunter)
			hunter.global_position = player.global_position + Vector3(0.0, 0.0, 4.0)
			var weapon := WeaponSystem.new()
			hunter.add_child(weapon)
			weapon.initialize(hunter, null)
			weapon.call("_server_scan", 1)
			await get_tree().process_frame
			_expect(int(shell.call("get_vertex_checksum")) != scan_before, "Hunter scan should soft-reset a nearby active Chameleon clay shell")
			hunter.queue_free()

	player.queue_free()
	Network.players = old_players
	await get_tree().process_frame

	if failures.is_empty():
		print("[ChameleonSculptNetworkTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ChameleonSculptNetworkTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
