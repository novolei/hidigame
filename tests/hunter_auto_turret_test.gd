extends Node3D

const CardDecoyTargetScript := preload("res://scripts/card_decoy_target.gd")
const HunterTurretTrainingDummyScene := preload("res://scenes/level/hunter_turret_training_dummy.tscn")

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
	turret = _ensure_current_auto_turret_script(hunter, turret)
	_expect(turret != null, "Hunter should attach HunterAutoTurretSystem")
	_test_weapon_visual_rpc_budget()
	_test_turret_visual_rpc_budget()
	_test_weapon_visual_rpc_relevance(hunter, chameleon, stalker)
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
		_expect(turret.get_tps_bullet_effect_count_for_test() >= 1, "Auto turret should spawn the TPS demo bullet scene for bullet flight and impact effects")
		var tps_effect_sources: Array[String] = turret.get_tps_bullet_effect_sources_for_test()
		_expect(tps_effect_sources.has("res://player/bullet/bullet.tscn"), "Auto turret should use the copied TPS bullet scene for machine-gun shots: " + str(tps_effect_sources))
		_expect(is_equal_approx(turret.get_tps_bullet_visual_speed_for_test(), 20.0), "Auto turret TPS bullets should keep the reference projectile speed instead of a compressed tracer speed")
		var bullet_source: String = FileAccess.get_file_as_string("res://player/bullet/bullet.gd")
		_expect(bullet_source.contains("func launch_visual"), "Copied TPS bullet scene should own its visual flight timing")
		_expect(bullet_source.contains("MachineGunTracer"), "Machine-gun bullet should use the bright rectangular tracer visual from the screenshot direction")
		_expect(not bullet_source.contains("_set_particle_emitting(\"BulletBody/Trail\", true)"), "Machine-gun bullet should not re-enable the old TPS flight trail particles")
		_expect(not bullet_source.contains("animation_player.play(\"explode\")"), "Machine-gun bullet impact should use small particles instead of the reference explosion animation")
		await _test_training_dummy_target(turret, hunter)

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
		Network.lobby_config["hunter_auto_turret_enabled"] = false
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == null, "Auto turret should stay disabled when the lobby room setting turns it off")
		Network.lobby_config["hunter_auto_turret_enabled"] = true
		Network.lobby_config["hunter_auto_turret_range"] = 18.0
		chameleon.position = Vector3(0.0, 0.0, -26.0)
		await get_tree().process_frame
		turret._process(0.0)
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == null, "Auto turret should respect a short lobby range setting")
		Network.lobby_config["hunter_auto_turret_range"] = 34.0
		await get_tree().process_frame
		turret._process(0.0)
		scan_target = turret.force_scan_for_test()
		_expect(scan_target == chameleon, "Auto turret should reacquire targets when the lobby range is extended")
		chameleon.position = Vector3(0.0, 0.0, -8.0)
		await get_tree().process_frame
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


func _test_training_dummy_target(turret: Node, hunter: Node3D) -> void:
	var dummy := HunterTurretTrainingDummyScene.instantiate() as Node3D
	_expect(dummy != null, "Hunter turret training dummy scene should instantiate")
	if dummy == null:
		return
	dummy.name = "HunterTurretTrainingDummyTest"
	add_child(dummy)
	dummy.global_position = hunter.global_position + Vector3(1.6, 0.0, -8.0)
	dummy.global_rotation = Vector3(0.0, PI, 0.0)
	await get_tree().process_frame
	await get_tree().physics_frame

	_expect(dummy.is_in_group("card_decoy_targets"), "Training dummy should register as a card decoy target for auto turret scans")
	_expect(dummy.has_method("is_card_decoy_target") and bool(dummy.call("is_card_decoy_target")), "Training dummy should expose the card decoy target contract")
	_expect(dummy.has_method("has_party_monster_skin_for_test") and bool(dummy.call("has_party_monster_skin_for_test")), "Training dummy should render through the Party Monster skin scene")
	var model_id: String = str(dummy.call("get_character_model_id_for_test")) if dummy.has_method("get_character_model_id_for_test") else ""
	_expect(CharacterSkinCatalog.is_party_monster(model_id), "Training dummy should pick a Party Monster character model: " + model_id)

	var scan_target = turret.force_scan_for_test()
	_expect(scan_target == dummy, "Auto turret should acquire the fixed Party Monster training dummy before player targets")

	var health_before: float = float(dummy.call("get_health")) if dummy.has_method("get_health") else 0.0
	var hit_count_before: int = int(dummy.call("get_hit_count_for_test")) if dummy.has_method("get_hit_count_for_test") else -1
	dummy.call("take_damage", 999999.0, 1, false)
	await get_tree().process_frame
	var health_after: float = float(dummy.call("get_health")) if dummy.has_method("get_health") else 0.0
	var hit_count_after: int = int(dummy.call("get_hit_count_for_test")) if dummy.has_method("get_hit_count_for_test") else -1
	var hit_action: String = str(dummy.call("get_last_hit_action_for_test")) if dummy.has_method("get_last_hit_action_for_test") else ""
	var allowed_hit_actions: Array[String] = ["get_hit", "hit", "defense_hit"]
	_expect(is_equal_approx(health_after, health_before) and health_after >= 999999.0, "Training dummy should keep infinite health after direct turret-scale damage")
	_expect(hit_count_after == hit_count_before + 1, "Training dummy should count incoming hits without dying")
	_expect(allowed_hit_actions.has(hit_action), "Training dummy should play a random Party Monster hit action: " + hit_action)
	dummy.queue_free()
	await get_tree().process_frame


func _ensure_current_auto_turret_script(hunter: Node, turret: Node) -> Node:
	if turret and turret.has_method("get_tps_bullet_effect_count_for_test") and turret.has_method("get_tps_bullet_visual_speed_for_test"):
		return turret
	if turret:
		hunter.remove_child(turret)
		turret.queue_free()

	# Compile from disk so this scene test is not fooled by an older in-memory turret script after hot edits.
	var turret_source := FileAccess.get_file_as_string("res://scripts/hunter_auto_turret_system.gd")
	if turret_source.is_empty():
		return null
	turret_source = turret_source.replace("class_name HunterAutoTurretSystem\n", "")
	var turret_script := GDScript.new()
	turret_script.source_code = turret_source
	if turret_script.reload() != OK:
		return null
	var refreshed_turret := turret_script.new() as Node
	if refreshed_turret == null:
		return null
	refreshed_turret.name = "HunterAutoTurretSystem"
	hunter.add_child(refreshed_turret)
	if refreshed_turret.has_method("initialize"):
		refreshed_turret.call("initialize", hunter)
	hunter.set("hunter_auto_turret_system", refreshed_turret)
	return refreshed_turret


func _test_weapon_visual_rpc_budget() -> void:
	var weapon_source: String = FileAccess.get_file_as_string("res://scripts/weapon_system.gd")
	var interest_source: String = FileAccess.get_file_as_string("res://scripts/network_interest.gd")
	_expect(interest_source.contains("class_name NetworkInterest"), "Shared network interest helper should be available for visual RPC relevance checks")
	_expect(weapon_source.contains("NetworkInterestScript.is_peer_relevant_to_segment"), "Weapon visual relevance should reuse the shared network interest helper")
	_expect(weapon_source.contains("@rpc(\"authority\", \"call_local\", \"unreliable_ordered\")\nfunc _broadcast_tracer"), "Weapon tracer is visual-only and should stay off the reliable RPC channel")
	_expect(weapon_source.contains("@rpc(\"authority\", \"call_local\", \"unreliable_ordered\")\nfunc _broadcast_green_blood_impact"), "Green blood impact is visual-only and should stay off the reliable RPC channel")
	_expect(weapon_source.contains("func _weapon_visual_recipient_ids"), "Weapon visual RPC should compute relevant recipients instead of broadcasting to every peer")
	_expect(weapon_source.contains("_broadcast_tracer.rpc_id"), "Weapon tracer visual should be fan-out targeted with rpc_id")
	_expect(weapon_source.contains("_broadcast_green_blood_impact.rpc_id"), "Green blood visual should be fan-out targeted with rpc_id")
	_expect(not weapon_source.contains("_broadcast_tracer.rpc("), "Weapon tracer visual should not broadcast to every peer")
	_expect(not weapon_source.contains("_broadcast_green_blood_impact.rpc("), "Green blood visual should not broadcast to every peer")
	_expect(weapon_source.contains("@rpc(\"authority\", \"call_local\", \"reliable\")\nfunc _sync_ammo"), "Weapon ammo state should remain reliable gameplay sync")
	_expect(weapon_source.contains("@rpc(\"authority\", \"call_local\", \"reliable\")\nfunc _broadcast_reload"), "Weapon reload state should remain reliable gameplay sync")
	_expect(weapon_source.contains("@rpc(\"authority\", \"call_local\", \"reliable\")\nfunc _client_weapon_feedback"), "Owner combat feedback should remain reliable and targeted")


func _test_turret_visual_rpc_budget() -> void:
	var turret_source: String = FileAccess.get_file_as_string("res://scripts/hunter_auto_turret_system.gd")
	_expect(turret_source.contains("func _send_turret_shot_visual"), "Auto turret shot visuals should flow through a targeted fan-out helper")
	_expect(turret_source.contains("NetworkInterestScript.is_peer_relevant_to_segment"), "Auto turret shot visuals should use shared segment relevance")
	_expect(turret_source.contains("_broadcast_turret_shot.rpc_id"), "Auto turret shot visual should be fan-out targeted with rpc_id")
	_expect(not turret_source.contains("_broadcast_turret_shot.rpc("), "Auto turret shot visual should not broadcast to every peer")
	_expect(turret_source.contains("Network.record_rpc_event(\"turret.shot\", recipients.size(), 72)"), "Auto turret shot telemetry should record actual recipient counts")


func _test_weapon_visual_rpc_relevance(hunter: Node3D, chameleon: Node3D, stalker: Node3D) -> void:
	hunter.add_to_group("players")
	chameleon.add_to_group("players")
	stalker.add_to_group("players")
	hunter.global_position = Vector3.ZERO
	chameleon.global_position = Vector3(0.0, 0.0, -8.0)
	stalker.global_position = Vector3(80.0, 0.0, -80.0)

	var weapon: WeaponSystem = WeaponSystem.new()
	weapon.name = "WeaponVisualRelevanceProbe"
	weapon.owner_peer_id = 1
	add_child(weapon)

	var segment_start: Vector3 = hunter.global_position + Vector3.UP
	var segment_end: Vector3 = segment_start + Vector3(0.0, 0.0, -16.0)
	var near_relevant: bool = weapon._is_peer_relevant_to_weapon_visual(2, segment_start, segment_end)
	var far_relevant: bool = weapon._is_peer_relevant_to_weapon_visual(3, segment_start, segment_end)
	var unknown_relevant: bool = weapon._is_peer_relevant_to_weapon_visual(99, segment_start, segment_end)
	var far_distance_sq: float = weapon._point_segment_distance_squared(stalker.global_position + Vector3.UP, segment_start, segment_end)
	var recipients: PackedInt32Array = PackedInt32Array()
	weapon._append_visual_recipient_id(recipients, 2)
	weapon._append_visual_recipient_id(recipients, 2)
	weapon._append_visual_recipient_id(recipients, 0)
	weapon._append_visual_recipient_id(recipients, 3)

	_expect(near_relevant, "Weapon visual relevance should include observers near the bullet segment")
	_expect(not far_relevant, "Weapon visual relevance should exclude distant observers from cosmetic fan-out")
	_expect(unknown_relevant, "Weapon visual relevance should include unknown peers conservatively")
	_expect(far_distance_sq > WeaponSystem.VISUAL_RPC_RELEVANCE_RADIUS * WeaponSystem.VISUAL_RPC_RELEVANCE_RADIUS, "Weapon visual relevance should measure distance to the shot segment")
	_expect(recipients.size() == 2 and recipients[0] == 2 and recipients[1] == 3, "Weapon visual recipient helper should deduplicate peer ids")

	weapon.queue_free()


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
	Network.lobby_config = {
		"max_players": 24,
		"lobby_id": "",
		"room_name": "Private Match",
		"steam_lobby_id": "",
		"host_port": Network.SERVER_PORT,
		"map": "Warehouse",
		"variant": "Default",
		"condition": "Normal",
		"game_show": "None",
		"gravity_mps2": 9.8,
		"low_gravity_events": true,
		"match_duration_sec": 600,
		"prep_duration_sec": 30,
		"host_hunter_count": -1,
		"host_stalker_count": -1,
		"stalker_glass_alpha_max": 0.125,
		"stalker_glass_material": "classic",
		"hunter_auto_turret_enabled": true,
		"hunter_auto_turret_range": 34.0,
		"auto_balance": true,
		"public_server": false,
		"public_lobby": false,
		"public_room_id": "",
		"public_address": "",
		"host_peer_id": 1,
		"host_peer_name": "",
		"role_locked": false,
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
