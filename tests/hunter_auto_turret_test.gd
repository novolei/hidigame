extends Node3D

const CardDecoyTargetScript := preload("res://scripts/card_decoy_target.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var hunter = player_scene.instantiate()
	hunter.name = "1"
	hunter.position = Vector3.ZERO
	add_child(hunter)

	var chameleon = player_scene.instantiate()
	chameleon.name = "2"
	chameleon.position = Vector3(0.0, 0.0, -8.0)
	add_child(chameleon)

	var stalker = player_scene.instantiate()
	stalker.name = "3"
	stalker.position = Vector3(80.0, 0.0, -80.0)
	add_child(stalker)

	await get_tree().process_frame
	await get_tree().physics_frame

	var turret = hunter.get_node_or_null("HunterAutoTurretSystem")
	_expect(turret != null, "Hunter should attach HunterAutoTurretSystem")
	_expect(hunter.is_hunter(), "Test player 1 should be Hunter")
	_expect(chameleon.is_chameleon(), "Test player 2 should be Chameleon")
	_expect(stalker.is_stalker(), "Test player 3 should be Stalker")

	if turret:
		_expect(is_equal_approx(turret.get_fire_interval(), 0.5), "Auto turret should fire at 120 rounds per minute")
		_expect(turret.get_target_scan_interval_for_test() >= 0.10 and turret.get_target_scan_interval_for_test() <= 0.13, "Auto turret target scans should stay budgeted near 8Hz instead of running every frame")
		_expect(is_equal_approx(turret.get_damage_per_bullet(), 10.0), "Auto turret should deal 10 damage so 10 hits kill a prop")
		_expect(is_equal_approx(turret.get_vision_half_angle_degrees(), 50.0), "Auto turret should scan 50 degrees left and right")
		_expect(turret.get_spread_degrees() > 1.0 and turret.get_spread_degrees() <= 2.5, "Auto turret should use a tighter spread so sustained fire can reliably threaten visible props")
		_expect(turret.get_target_range() >= 30.0, "Auto turret should have enough range to guard the Hunter shoulder")
		_expect(turret.get_model_scale() >= 0.45, "Combat drone model should be enlarged to at least 2.5x the previous shoulder size")
		_expect(turret.get_visual_mesh_count_for_test() > 0, "Combat drone visual should contain imported mesh nodes")
		_expect(turret.get_textured_visual_mesh_count_for_test() > 0, "Combat drone visual should preserve or restore textured materials")
		_expect(turret.get_shoulder_local_offset().x > 0.4 and turret.get_shoulder_local_offset().y > 1.2 and turret.get_shoulder_local_offset().y < 1.7, "Combat drone should hover near the Hunter's right shoulder instead of nameplate height")
		turret._process(0.0)
		_expect(turret.get_hover_anchor_position_for_test().y < hunter.global_position.y + 1.7, "Combat drone hover anchor should be below the Hunter nameplate height")
		_expect(turret.get_current_forward_for_test().dot(turret.get_default_forward_for_test()) > 0.96, "Combat drone default facing should align with the Hunter view direction")
		_expect(is_equal_approx(absf(turret.get_visual_model_yaw_offset_for_test()), PI), "Combat drone visual model should be flipped to face the Hunter view direction")
		_expect(turret.get_shots_before_overheat() == 200, "Auto turret should overheat after 200 sustained shots")
		_expect(is_equal_approx(turret.get_overheat_cooldown_seconds(), 8.5), "Auto turret overheat cooldown should be 8.5 seconds")
		_expect(turret.has_single_shot_audio_for_test(), "Auto turret should keep only the shot sound player")
		_expect(turret.get_shot_audio_length_for_test() > 0.0 and turret.get_shot_audio_length_for_test() < turret.get_fire_interval(), "Auto turret shot audio should be a short firing segment instead of the full gatling clip")
		_expect(turret.has_overheat_audio_for_test(), "Auto turret should use a separate overheat stop audio player")
		_expect(turret.get_overheat_audio_length_for_test() > turret.get_fire_interval(), "Auto turret overheat stop audio should keep the forced-stop tail separate from normal shots")
		_expect(not turret.has_extra_gatling_audio_for_test(), "Auto turret should not create a second looping gatling audio player")
		turret.trigger_visual_shot_for_test(Vector3.ZERO, Vector3(0.0, 0.0, -8.0))
		_expect(turret.get_recoil_offset_for_test().length() > 0.02, "Auto turret should kick with a visible recoil offset while firing")
		_expect(turret.get_recoil_rotation_for_test().length() > 0.01, "Auto turret should apply a small firing shake rotation")
		_expect(turret.get_muzzle_flash_count_for_test() >= 1, "Auto turret should spawn a cartoon muzzle flash while firing")
		_expect(turret.get_hovl_projectile_effect_count_for_test() >= 1, "Auto turret should layer a Hovl energy projectile over its machine-gun tracer")
		var hovl_effect_ids: Array[String] = turret.get_hovl_projectile_effect_ids_for_test()
		_expect(hovl_effect_ids.has("projectile_08_energy"), "Auto turret should use the Hovl energy projectile preset for machine-gun shots: " + str(hovl_effect_ids))

	chameleon.apply_prop_disguise({
		"id": "turret_test_crate",
		"name": "Turret Test Crate",
		"mesh": "box",
		"size": Vector3(1.2, 1.0, 1.2),
		"offset": Vector3(0.0, 0.52, 0.0),
		"color": Color(0.35, 0.30, 0.24, 1.0),
		"q_scene_prop_replica": true,
		"disguise_source": "nearby_scene_prop_q",
	})
	await get_tree().process_frame

	if turret:
		var scan_target = turret.force_scan_for_test()
		_expect(scan_target == null, "Auto turret should not acquire a disguised prop because Hunters cannot see the true prop model: " + str(turret.get_target_scan_debug_for_test(chameleon)))
		chameleon.clear_prop_disguise()
		await get_tree().process_frame
		var visual_root := chameleon.get_node_or_null("3DGodotRobot/RobotArmature") as Node3D
		if visual_root:
			visual_root.visible = false
		await get_tree().process_frame
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == null, "Auto turret should not acquire an invisible/hidden prop model")
		if visual_root:
			visual_root.visible = true
		await get_tree().process_frame
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == chameleon, "Auto turret should acquire only a truly visible prop model in its forward cone: " + str(turret.get_target_scan_debug_for_test(chameleon)))
		var decoy := CardDecoyTargetScript.new() as CardDecoyTarget
		decoy.name = "CardDecoyPriorityTest"
		add_child(decoy)
		decoy.configure(chameleon, 15.0, Vector3(0.0, 0.0, 1.8), false, 20.0)
		decoy.global_position = Vector3(0.0, 0.0, -5.5)
		await get_tree().process_frame
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == decoy, "Auto turret should prioritize active card decoys over visible real Props")
		turret.force_apply_hit_for_test(decoy)
		turret.force_apply_hit_for_test(decoy)
		await get_tree().process_frame
		_expect(not is_instance_valid(decoy) or decoy.get_health() <= 0.0, "Card decoy should be a damageable turret target")
		chameleon.apply_card_effect("prop_empty_bullet")
		_expect(turret.is_overheated(), "Empty Bullet should drain automatic turret resources into overheat")
		turret.overheat_cooldown = 0.0
		turret.heat_shots = 0
		for i in range(10):
			turret.force_apply_hit_for_test(chameleon)
		await get_tree().process_frame
		_expect(chameleon.get_health() <= 0.0, "Ten auto turret hits should kill the prop")
		_expect(not bool(Network.players.get(2, {}).get("alive", true)), "Killed prop should be marked dead in the authoritative Network player state")
		_expect(_find_tombstone_count() >= 1, "Prop death should spawn a tombstone at the death location")
		_expect(_find_node_count_with_prefix("PropDeathSmokeRise") >= 1, "Prop death should spawn a rising smoke vanish effect")
		if visual_root:
			_expect(not visual_root.visible, "The true prop model should be hidden immediately after death")
		var tombstone := _find_first_node_with_prefix("PropDeathTombstone")
		_expect(tombstone != null and tombstone.has_meta("death_rpc_synced"), "Tombstone effect should be spawned from the reliable death RPC path")
		_expect(tombstone != null and bool(tombstone.get_meta("starts_underground", false)), "Tombstone should begin underground before emerging")
		_expect(tombstone != null and float(tombstone.get_meta("apex_offset", 0.0)) >= 0.7, "Tombstone should pop above the floor before landing")
		await get_tree().create_timer(5.2).timeout
		_expect(chameleon.get_health() <= 0.0, "Killed prop should not auto-revive after the old 5 second respawn window")
		if visual_root:
			_expect(not visual_root.visible, "Killed prop visual should stay hidden until a future revive-card system explicitly revives it")

		hunter.global_position = Vector3.ZERO
		hunter.velocity = Vector3.ZERO
		stalker.position = Vector3(4.0, 0.0, -8.0)
		var stalker_shadow = stalker.get_node_or_null("ShadowVisibilitySystem")
		if stalker_shadow:
			stalker_shadow.set_process(false)
			stalker_shadow.call("_set_shadow_state", ShadowVisibilitySystem.ShadowLevel.FULL_SHADOW, 0.0, 5)
			stalker._refresh_stalker_visibility_view(true)
		turret._process(0.0)
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == null, "Auto turret should not acquire a hidden Stalker before flashlight/light reveal: " + str(turret.get_target_scan_debug_for_test(stalker)))
		if stalker_shadow:
			stalker_shadow.call("_set_shadow_state", ShadowVisibilitySystem.ShadowLevel.BRIGHT, 1.0, 0)
			stalker._refresh_stalker_visibility_view(true)
		turret._process(0.0)
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == stalker, "Auto turret should acquire a revealed Stalker as a visible Prop-team target: " + str(turret.get_target_scan_debug_for_test(stalker)))
		stalker.position = Vector3(80.0, 0.0, -80.0)
		turret.heat_shots = 0
		turret.fire_cooldown = 0.0

		for i in range(turret.get_shots_before_overheat()):
			turret.force_mark_shot_for_test()
		_expect(turret.is_overheated(), "Auto turret should enter overheat after 200 sustained shots")
		_expect(turret.get_overheat_remaining() > 8.4, "Auto turret should start an 8.5 second overheat cooldown")
		turret._process(8.6)
		_expect(not turret.is_overheated(), "Auto turret should recover after the overheat cooldown")
		_expect(turret.get_heat_shots() == 0, "Auto turret heat counter should reset after cooling")
		hunter.call("_client_card_screen_impairment", "PAINT", 1.0)
		_expect(hunter.has_card_screen_impairment_overlay_for_test(), "Paint/flash card effects should create a local screen impairment overlay")
		stalker.apply_card_effect("prop_emergency_conceal")
		_expect(stalker.has_card_stasis(), "Emergency Conceal should put the Prop into a stone stasis state")
		stalker.apply_card_effect("prop_extreme_immunity")
		stalker.position = Vector3(4.0, 0.0, -8.0)
		hunter.apply_card_effect("hunter_gravity_net")
		_expect(is_equal_approx(stalker.get_card_speed_multiplier_for_test(), 1.0), "Extreme Immunity should block Hunter control card slowdown")

	hunter.queue_free()
	chameleon.queue_free()
	stalker.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[HunterAutoTurretTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[HunterAutoTurretTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Network.players.clear()
	Network.players = {
		1: _player("Hunter", Network.Role.HUNTER),
		2: _player("Chameleon", Network.Role.CHAMELEON),
		3: _player("Stalker", Network.Role.STALKER),
	}


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": 0,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": "godot_robot",
	}


func _find_tombstone_count() -> int:
	return _find_node_count_with_prefix("PropDeathTombstone")


func _find_node_count_with_prefix(prefix: String) -> int:
	var count := 0
	for child in get_children():
		if str(child.name).begins_with(prefix):
			count += 1
	return count


func _find_first_node_with_prefix(prefix: String) -> Node:
	for child in get_children():
		if str(child.name).begins_with(prefix):
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
