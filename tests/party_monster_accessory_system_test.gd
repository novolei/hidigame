extends Node3D

const Catalog := preload("res://scripts/party_monster_accessory_catalog.gd")
const LEVEL_SCRIPT := preload("res://scripts/level.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUNT_HUD_SCRIPT := preload("res://scripts/party_monster_hunt_hud.gd")
const PICKUP_SCRIPT := preload("res://scripts/party_monster_accessory_pickup.gd")
const NetworkScript := preload("res://scripts/network.gd")
const PARTY_MONSTER_SCENE_PATH := "res://assets/characters/party_monster/party_monster_skin.tscn"
const PARTY_MONSTER_MODEL_ID := "party_monster_c01"
const ROLE_CHAMELEON := 0
const ROLE_STALKER := 1
const ROLE_HUNTER := 2

var party_monster_bounty_accessories: Array = []
var network: Node = null

class FakeMarkedPlayer:
	extends Node3D

	var marked := false
	var bounty_ids: Array = []

	func is_party_monster_bounty_marked() -> bool:
		return marked

	func get_party_monster_bounty_accessory_ids() -> Array:
		return bounty_ids.duplicate()


func _ready() -> void:
	var root_node: Window = get_tree().root
	network = root_node.get_node_or_null("Network")
	if network == null:
		network = NetworkScript.new()
		network.name = "Network"
		add_child(network)
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_run_catalog_tests(failures)
	_run_skin_visibility_tests(failures)
	_run_pickup_visual_tests(failures)
	_run_network_and_bounty_tests(failures)
	_run_hud_tests(failures)
	_finish(failures)


func _run_catalog_tests(failures: Array[String]) -> void:
	var default_loadout: Dictionary = Catalog.loadout_for_model_id(PARTY_MONSTER_MODEL_ID)
	_expect(not default_loadout.is_empty(), failures, "Party Monster default model should expose a derived accessory loadout")
	for slot in [Catalog.SLOT_EYES, Catalog.SLOT_MOUTH]:
		_expect(default_loadout.has(slot), failures, "Default Party Monster loadout should include slot: %s" % slot)
	for slot in [Catalog.SLOT_EYES, Catalog.SLOT_MOUTH, Catalog.SLOT_NOSE, Catalog.SLOT_HEAD]:
		_expect(Catalog.options_for_slot(slot).size() > 0, failures, "Catalog should expose options for slot: %s" % slot)
	var default_eye_id := str(default_loadout.get(Catalog.SLOT_EYES, ""))
	_expect(Catalog.loadout_summary(default_loadout, 4).contains("Eyes"), failures, "Catalog should summarize a Party Monster loadout for HUD use")
	_expect(Catalog.bounty_escape_hint(default_loadout, [default_eye_id]) == "Eyes", failures, "Catalog should name the slot that clears a matching bounty")
	var bounty_ids: Array = Catalog.random_accessory_ids(7719, 2, true)
	_expect(bounty_ids.size() == 2, failures, "Catalog should pick two bounty accessories")
	if bounty_ids.size() == 2:
		_expect(Catalog.accessory_slot(str(bounty_ids[0])) != Catalog.accessory_slot(str(bounty_ids[1])), failures, "Two-accessory bounties should prefer unique slots")
	var balanced_ids: Array = Catalog.random_balanced_accessory_ids(88521, 24, 3)
	_expect(balanced_ids.size() >= 24, failures, "Balanced accessory spawn pool should provide at least 24 pickups")
	var balanced_slots := {}
	for raw_balanced_id in balanced_ids:
		var balanced_slot: String = Catalog.accessory_slot(str(raw_balanced_id))
		balanced_slots[balanced_slot] = int(balanced_slots.get(balanced_slot, 0)) + 1
	for slot in Catalog.all_slots():
		_expect(int(balanced_slots.get(str(slot), 0)) >= 2, failures, "Balanced accessory pool should cover slot: %s" % str(slot))


func _run_skin_visibility_tests(failures: Array[String]) -> void:
	var loaded_scene: Variant = load(PARTY_MONSTER_SCENE_PATH)
	if not loaded_scene is PackedScene:
		failures.append("Party Monster scene should load for accessory tests")
		return
	var default_loadout: Dictionary = Catalog.loadout_for_model_id(PARTY_MONSTER_MODEL_ID)
	var default_eye_id := str(default_loadout.get(Catalog.SLOT_EYES, ""))
	var replacement: Dictionary = _first_option_not(Catalog.options_for_slot(Catalog.SLOT_EYES), default_eye_id)
	if replacement.is_empty():
		failures.append("Eye slot should have a replacement option")
		return
	var replacement_id := str(replacement.get("id", ""))
	var replacement_node_name := str(replacement.get("node_name", ""))
	var default_eye_node_name := str(Catalog.get_accessory(default_eye_id).get("node_name", ""))
	var skin: Node = (loaded_scene as PackedScene).instantiate()
	if skin == null:
		failures.append("Party Monster skin should instantiate")
		return
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", PARTY_MONSTER_MODEL_ID)
	if skin.has_method("_build_skin"):
		skin.call("_build_skin")
	var next_loadout := default_loadout.duplicate(true)
	next_loadout[Catalog.SLOT_EYES] = replacement_id
	if skin.has_method("set_accessory_loadout"):
		skin.call("set_accessory_loadout", next_loadout)
	else:
		failures.append("Party Monster skin should expose set_accessory_loadout")
	var replacement_node := _find_node_by_name(skin, replacement_node_name)
	_expect(replacement_node != null and _is_effectively_visible_3d(replacement_node), failures, "Replacement eye accessory should become visible: %s" % replacement_node_name)
	if not default_eye_node_name.is_empty() and default_eye_node_name != replacement_node_name:
		var default_eye_node := _find_node_by_name(skin, default_eye_node_name)
		_expect(default_eye_node != null and not _is_effectively_visible_3d(default_eye_node), failures, "Previous eye accessory should be hidden after replacement: %s" % default_eye_node_name)
	skin.free()

	var preview: Node = (loaded_scene as PackedScene).instantiate()
	if preview == null:
		failures.append("Party Monster preview skin should instantiate")
		return
	if preview.has_method("set_accessory_preview_id"):
		preview.call("set_accessory_preview_id", replacement_id)
	else:
		failures.append("Party Monster skin should expose set_accessory_preview_id")
	if preview.has_method("_build_skin"):
		preview.call("_build_skin")
	var preview_node := _find_node_by_name(preview, replacement_node_name)
	_expect(preview_node != null and _is_effectively_visible_3d(preview_node), failures, "Pickup preview should show the requested accessory")
	_expect(not _any_effectively_visible_prefix(preview, "MainBody"), failures, "Pickup preview should hide the full body and show only accessory context")
	preview.free()


func _run_pickup_visual_tests(failures: Array[String]) -> void:
	var default_loadout: Dictionary = Catalog.loadout_for_model_id(PARTY_MONSTER_MODEL_ID)
	var default_eye_id := str(default_loadout.get(Catalog.SLOT_EYES, ""))
	var replacement: Dictionary = _first_option_not(Catalog.options_for_slot(Catalog.SLOT_EYES), default_eye_id)
	if replacement.is_empty():
		failures.append("Eye slot should have a replacement option for pickup visual tests")
		return
	var replacement_id := str(replacement.get("id", ""))
	var pickup = PICKUP_SCRIPT.new()
	pickup.accessory_id = replacement_id
	add_child(pickup)
	_expect(_find_node_by_name(pickup, "AccessoryAura") == null, failures, "Pickup should not create the old duplicate ground disc")
	_expect(_find_node_by_name(pickup, "AccessoryLabel") == null, failures, "Pickup should not create the old global floating accessory label")
	_expect(_find_node_by_name(pickup, "AccessoryInteractPrompt") == null, failures, "Pickup should not create the old oversized world-space interaction prompt")
	_expect(_find_node_by_name(pickup, "AccessoryInteractionHUD") == null, failures, "Pickup interaction HUD should only be attached to the local player while nearby")
	var beacon := _find_node_by_name(pickup, "AccessoryBountyBeacon")
	_expect(beacon is Node3D and not (beacon as Node3D).visible, failures, "Pickup bounty beacon should exist but stay hidden until the local player is marked")
	var ribbon := _find_node_by_name(pickup, "BountyBeamRibbonA") as MeshInstance3D
	_expect(ribbon is MeshInstance3D and ribbon.mesh is QuadMesh, failures, "Pickup bounty beacon should use tall shader ribbons instead of short cylinders")
	if ribbon:
		var material := ribbon.material_override as ShaderMaterial
		_expect(material != null, failures, "Pickup bounty ribbon should use the energy beam shader material")
		if material:
			var beam_color: Color = material.get_shader_parameter("beam_color") as Color
			var accessory_color: Color = pickup.call("get_debug_accessory_color") as Color
			var top_fade: float = float(material.get_shader_parameter("top_fade"))
			var fade_start: float = float(material.get_shader_parameter("space_fade_start"))
			_expect(_colors_close(beam_color, accessory_color, 0.025), failures, "Pickup bounty ribbon should take its color from the preview accessory material")
			_expect(top_fade <= 0.025 and fade_start <= 0.05, failures, "Pickup bounty beam should fade into the upper atmosphere instead of ending as an opaque sky column")
	var impact := _find_node_by_name(pickup, "BountyBeamImpact")
	var impact_glow := _find_node_by_name(pickup, "BountyBeamImpactGlow") as MeshInstance3D
	var impact_core := _find_node_by_name(pickup, "BountyBeamImpactCore") as MeshInstance3D
	var sparks := _find_node_by_name(pickup, "BountyBeamSparks") as GPUParticles3D
	_expect(impact is Node3D and sparks is GPUParticles3D, failures, "Pickup bounty beacon should include a ground-impact particle effect")
	_expect(impact_glow is MeshInstance3D and impact_glow.mesh is CylinderMesh, failures, "Pickup beam impact should include a visible ground glow disc")
	_expect(impact_core is MeshInstance3D and impact_core.mesh is CylinderMesh, failures, "Pickup beam impact should include a bright core hit point")
	if sparks:
		_expect(sparks.amount >= 80, failures, "Pickup impact sparks should be dense enough to read in gameplay")
		_expect(sparks.draw_pass_1 is QuadMesh, failures, "Pickup impact sparks should use camera-facing quads for visibility")
		var process_material := sparks.process_material as ParticleProcessMaterial
		_expect(process_material != null, failures, "Pickup impact sparks should have a process material")
		if process_material:
			var accessory_color: Color = pickup.call("get_debug_accessory_color") as Color
			_expect(_colors_close(process_material.color, accessory_color, 0.025), failures, "Pickup impact sparks should match the accessory color")
	if pickup.has_method("get_debug_beacon_height"):
		_expect(float(pickup.call("get_debug_beacon_height")) >= 600.0, failures, "Pickup bounty beacon should read as an orbital beam cast from beyond the sky")
	else:
		failures.append("Pickup should expose debug beacon height for visual validation")
	_run_pickup_beacon_visibility_case(pickup, default_eye_id, replacement_id, failures)
	if pickup.has_method("get_debug_accessory_preview_size"):
		var preview_size := float(pickup.call("get_debug_accessory_preview_size"))
		_expect(preview_size >= 0.42 and preview_size <= 0.58, failures, "Pickup accessory preview should be normalized near 0.5m, got %.3f" % preview_size)
	else:
		failures.append("Pickup should expose debug preview size for visual validation")
	var pickup_source := FileAccess.get_file_as_string("res://scripts/party_monster_accessory_pickup.gd")
	_expect(pickup_source.contains("AccessoryInteractionHUD"), failures, "Pickup source should create the compact local interaction HUD")
	_expect(pickup_source.contains("get_active_material"), failures, "Pickup beam color should inspect the visible accessory material")
	_expect(pickup_source.contains("party_monster_accessory_beam.gdshader"), failures, "Pickup source should use the Party Monster energy beam shader")
	_expect(pickup_source.contains("dual_beam_offset"), failures, "Pickup source should configure the merged dual-beam shader shape")
	_expect(pickup_source.contains("BountyBeamImpactGlow"), failures, "Pickup source should create a visible beam ground glow")
	_expect(pickup_source.contains("BountyBeamSparks"), failures, "Pickup source should create beam ground-impact sparks")
	_expect(pickup_source.contains("role == Network.Role.HUNTER"), failures, "Pickup beacon visibility should broadcast current-bounty replacement beams to hunters")
	_expect(pickup_source.contains("is_party_monster_bounty_marked"), failures, "Pickup beacon visibility should check the local marked player state")
	_expect(pickup_source.contains("current_id == accessory_id"), failures, "Pickup beacon should hide same-accessory pickups because they cannot clear the mark")
	_expect(pickup_source.contains("get_party_monster_bounty_accessory_ids"), failures, "Pickup beacon should use the local marked player's replicated bounty ids as a reliable fallback")
	_expect(not pickup_source.contains("func _add_aura"), failures, "Pickup source should not recreate the old ground disc function")
	_expect(not pickup_source.contains("func _add_label"), failures, "Pickup source should not recreate the old global label function")
	var level_source := FileAccess.get_file_as_string("res://scripts/level.gd")
	_expect(level_source.contains("PARTY_MONSTER_ACCESSORY_MIN_PICKUPS := 24"), failures, "Level should spawn enough accessory pickups for replacement play")
	_expect(level_source.contains("random_balanced_accessory_ids"), failures, "Level should use a balanced accessory pool across slots")
	_expect(level_source.contains("_party_monster_accessory_spawn_round"), failures, "Level should advance accessory spawn positions each round")
	_expect(level_source.contains("random_ammo_position_with_rng"), failures, "Level should use a per-round RNG for accessory pickup positions")
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	_expect(player_source.contains("_refresh_party_monster_accessory_pickup_beacons"), failures, "Player bounty state changes should refresh accessory pickup beams")
	_expect(player_source.contains("LOCAL_FEEDBACK_TRANSFORM_INTERVAL"), failures, "Local feedback transforms should be budgeted instead of updating every frame")
	_expect(player_source.contains("_has_party_monster_bounty_visuals"), failures, "Party Monster bounty feedback should reuse existing visual nodes")
	_expect(player_source.contains("if not _should_render_local_feedback():\n\t\t_clear_party_monster_bounty_visuals()\n\t\treturn"), failures, "Dedicated public servers should skip Party Monster bounty visual feedback work")
	pickup.queue_free()


func _run_pickup_beacon_visibility_case(pickup: Node, equipped_id: String, replacement_id: String, failures: Array[String]) -> void:
	var local_id: int = multiplayer.get_unique_id()
	var had_local: bool = network.players.has(local_id)
	var previous_info: Dictionary = (network.players.get(local_id, {}) as Dictionary).duplicate(true) if had_local else {}
	var players_container := Node3D.new()
	players_container.name = "PlayersContainer"
	add_child(players_container)
	var fake_player := FakeMarkedPlayer.new()
	fake_player.name = str(local_id)
	fake_player.add_to_group("players")
	fake_player.set_multiplayer_authority(local_id)
	players_container.add_child(fake_player)
	party_monster_bounty_accessories = [equipped_id]
	network.players[local_id] = {
		"role": ROLE_CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: equipped_id},
	}
	pickup.call("configure", replacement_id)
	pickup.call("_on_body_entered", fake_player)
	var prompt_hud := _find_node_by_name(fake_player, "AccessoryInteractionHUD") as Node3D
	_expect(prompt_hud is Node3D and prompt_hud.visible and bool(pickup.call("get_debug_prompt_hud_visible")), failures, "Nearby local player should see a compact pickup HUD")
	if prompt_hud:
		_expect(prompt_hud.position.x < 0.0, failures, "Pickup HUD should sit on the player's left side")
		var action_label := _find_node_by_name(prompt_hud, "InteractPromptAction") as Label3D
		_expect(action_label is Label3D and action_label.text == "SWAP", failures, "Pickup HUD should show a compact SWAP action")
		if action_label:
			_expect(not action_label.fixed_size and action_label.pixel_size <= 0.004, failures, "Pickup HUD text should stay small and 3D-scaled")
	pickup.call("_update_local_hint_visibility")
	_expect(not bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Unmarked local players should not see bounty replacement beams")
	fake_player.marked = true
	fake_player.bounty_ids = [equipped_id]
	pickup.call("_update_local_hint_visibility")
	_expect(bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Marked local players should see same-slot replacement beams")
	party_monster_bounty_accessories = []
	pickup.call("_update_local_hint_visibility")
	_expect(bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Marked local players should still see beams from their replicated bounty ids when scene state is late")
	party_monster_bounty_accessories = [equipped_id]
	var sparks := _find_node_by_name(pickup, "BountyBeamSparks") as GPUParticles3D
	_expect(sparks is GPUParticles3D and bool(pickup.call("get_debug_beacon_impact_requested")), failures, "Bounty ground-impact sparks should be requested while the beam is visible")
	fake_player.marked = false
	network.players[local_id] = {
		"role": ROLE_HUNTER,
		"alive": true,
		"character_model": "hunter_shooter",
		"party_monster_accessories": {},
	}
	pickup.call("configure", replacement_id)
	pickup.call("_update_local_hint_visibility")
	_expect(bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Hunters should see all current-bounty replacement beams")
	pickup.call("configure", equipped_id)
	pickup.call("_update_local_hint_visibility")
	_expect(not bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Hunters should not see beams on the exact bounty accessory pickup because it cannot clear the target")
	network.players[local_id] = {
		"role": ROLE_CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: equipped_id},
	}
	fake_player.marked = true
	pickup.call("configure", equipped_id)
	pickup.call("_update_local_hint_visibility")
	_expect(not bool(pickup.call("get_debug_bounty_beacon_visible")), failures, "Marked local players should not see beams on same-accessory pickups")
	pickup.call("_on_body_exited", fake_player)
	party_monster_bounty_accessories = []
	if had_local:
		network.players[local_id] = previous_info
	else:
		network.players.erase(local_id)
	players_container.queue_free()


func _run_network_and_bounty_tests(failures: Array[String]) -> void:
	var default_loadout: Dictionary = Catalog.loadout_for_model_id(PARTY_MONSTER_MODEL_ID)
	var default_eye_id := str(default_loadout.get(Catalog.SLOT_EYES, ""))
	var replacement: Dictionary = _first_option_not(Catalog.options_for_slot(Catalog.SLOT_EYES), default_eye_id)
	if replacement.is_empty():
		return
	var replacement_id := str(replacement.get("id", ""))
	var clean: Dictionary = network.normalize_party_monster_accessories({Catalog.SLOT_EYES: replacement_id, "bad_slot": "Eye999"}, PARTY_MONSTER_MODEL_ID)
	_expect(clean.size() == 1 and str(clean.get(Catalog.SLOT_EYES, "")) == replacement_id, failures, "Network should sanitize Party Monster accessory loadouts")

	var level = LEVEL_SCRIPT.new()
	level.party_monster_bounty_accessories = [replacement_id]
	var marked_info := {
		"role": ROLE_CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: replacement_id},
	}
	_expect(level._should_mark_party_monster_bounty_player(marked_info), failures, "Level bounty should mark a prop carrying the target accessory")
	marked_info["party_monster_accessories"] = {Catalog.SLOT_EYES: default_eye_id}
	_expect(not level._should_mark_party_monster_bounty_player(marked_info), failures, "Level bounty should clear after the target accessory is replaced")
	marked_info["party_monster_accessories"] = {Catalog.SLOT_EYES: replacement_id}
	marked_info["role"] = ROLE_HUNTER
	_expect(not level._should_mark_party_monster_bounty_player(marked_info), failures, "Hunters should not be marked by prop accessory bounties")

	var tracked_peer := 770077
	network.players[tracked_peer] = {
		"role": ROLE_CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: replacement_id},
	}
	var candidate_ids: Array = level._party_monster_bounty_candidate_ids()
	_expect(candidate_ids.has(replacement_id), failures, "Bounty candidates should prefer accessories currently carried by live Party Monster props")
	level.party_monster_bounty_accessories = [replacement_id]
	_expect(level._count_party_monster_bounty_marked_players() >= 1, failures, "Level should count marked Party Monster bounty carriers")
	network.players.erase(tracked_peer)
	level.free()

	var player = PLAYER_SCRIPT.new()
	player.name = "77"
	player.role = ROLE_CHAMELEON
	player.character_model_id = PARTY_MONSTER_MODEL_ID
	network.players[77] = {"alive": true}
	player.set_party_monster_accessory_loadout({Catalog.SLOT_EYES: replacement_id})
	player._party_monster_bounty_marked = true
	player.set_party_monster_bounty_marked(true, [replacement_id], "Accessory Test")
	_expect(player.is_party_monster_bounty_marked(), failures, "Player should store active Party Monster bounty mark state")
	_expect(player.get_party_monster_bounty_outline_count() == 0, failures, "Bounty mark should not create full-body transparent outline meshes")
	_expect(_find_node_by_name(player, "PartyMonsterBountyOutline") == null, failures, "Bounty mark should not add a copied character mesh outline")
	_expect(_find_node_by_name(player, "PartyMonsterBountyGlow") is OmniLight3D, failures, "Bounty mark should keep the lightweight glow light")
	_expect(_find_node_by_name(player, "PartyMonsterBountyMarker") is Label3D, failures, "Bounty mark should keep the readable overhead marker")
	player.set_party_monster_bounty_marked(false, [], "")
	_expect(not player.is_party_monster_bounty_marked(), failures, "Player should clear Party Monster bounty mark state")
	network.players.erase(77)
	player.free()


func _run_hud_tests(failures: Array[String]) -> void:
	var hud = HUNT_HUD_SCRIPT.new()
	hud.set_hunt_state(true, true, "Eyes 02", 31.0, 78.0, 0.0, 2, "Eyes 02 / Mouth 01", "Eyes")
	var state: Dictionary = hud.get_debug_state()
	_expect(bool(state.get("visible", false)), failures, "Party Monster hunt HUD should show active hunt state")
	_expect(bool(state.get("marked", false)), failures, "Party Monster hunt HUD should expose marked state for verification")
	_expect(str(state.get("escape_hint", "")) == "Eyes", failures, "Party Monster hunt HUD should keep the escape hint")
	hud.set_hunt_state(false, false, "", 0.0, 78.0, 8.0, 0, "", "")
	state = hud.get_debug_state()
	_expect(not bool(state.get("visible", true)), failures, "Party Monster hunt HUD should clear when inactive")
	hud.free()


func _first_option_not(options: Array, accessory_id: String) -> Dictionary:
	for raw_option in options:
		var option: Dictionary = raw_option as Dictionary
		if str(option.get("id", "")) != accessory_id:
			return option
	return {}


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null or node_name.is_empty() or root.is_queued_for_deletion():
		return null
	if String(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found:
			return found
	return null


func _any_effectively_visible_prefix(root: Node, prefix: String) -> bool:
	if root == null:
		return false
	if String(root.name).begins_with(prefix) and _is_effectively_visible_3d(root):
		return true
	for child in root.get_children():
		if _any_effectively_visible_prefix(child, prefix):
			return true
	return false


func _is_effectively_visible_3d(node: Node) -> bool:
	var current: Node = node
	while current:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true


func _colors_close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func _expect(condition: bool, failures: Array[String], message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[PartyMonsterAccessorySystemTest] PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("[PartyMonsterAccessorySystemTest] " + failure)
	get_tree().quit(1)
