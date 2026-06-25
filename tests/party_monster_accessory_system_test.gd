extends Node3D

const Catalog := preload("res://scripts/party_monster_accessory_catalog.gd")
const LEVEL_SCRIPT := preload("res://scripts/level.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUNT_HUD_SCRIPT := preload("res://scripts/party_monster_hunt_hud.gd")
const PARTY_MONSTER_SCENE_PATH := "res://assets/characters/party_monster/party_monster_skin.tscn"
const PARTY_MONSTER_MODEL_ID := "party_monster_c01"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_run_catalog_tests(failures)
	_run_skin_visibility_tests(failures)
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


func _run_network_and_bounty_tests(failures: Array[String]) -> void:
	var default_loadout: Dictionary = Catalog.loadout_for_model_id(PARTY_MONSTER_MODEL_ID)
	var default_eye_id := str(default_loadout.get(Catalog.SLOT_EYES, ""))
	var replacement: Dictionary = _first_option_not(Catalog.options_for_slot(Catalog.SLOT_EYES), default_eye_id)
	if replacement.is_empty():
		return
	var replacement_id := str(replacement.get("id", ""))
	var clean: Dictionary = Network.normalize_party_monster_accessories({Catalog.SLOT_EYES: replacement_id, "bad_slot": "Eye999"}, PARTY_MONSTER_MODEL_ID)
	_expect(clean.size() == 1 and str(clean.get(Catalog.SLOT_EYES, "")) == replacement_id, failures, "Network should sanitize Party Monster accessory loadouts")

	var level = LEVEL_SCRIPT.new()
	level.party_monster_bounty_accessories = [replacement_id]
	var marked_info := {
		"role": Network.Role.CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: replacement_id},
	}
	_expect(level._should_mark_party_monster_bounty_player(marked_info), failures, "Level bounty should mark a prop carrying the target accessory")
	marked_info["party_monster_accessories"] = {Catalog.SLOT_EYES: default_eye_id}
	_expect(not level._should_mark_party_monster_bounty_player(marked_info), failures, "Level bounty should clear after the target accessory is replaced")
	marked_info["party_monster_accessories"] = {Catalog.SLOT_EYES: replacement_id}
	marked_info["role"] = Network.Role.HUNTER
	_expect(not level._should_mark_party_monster_bounty_player(marked_info), failures, "Hunters should not be marked by prop accessory bounties")

	var tracked_peer := 770077
	Network.players[tracked_peer] = {
		"role": Network.Role.CHAMELEON,
		"alive": true,
		"character_model": PARTY_MONSTER_MODEL_ID,
		"party_monster_accessories": {Catalog.SLOT_EYES: replacement_id},
	}
	var candidate_ids: Array = level._party_monster_bounty_candidate_ids()
	_expect(candidate_ids.has(replacement_id), failures, "Bounty candidates should prefer accessories currently carried by live Party Monster props")
	level.party_monster_bounty_accessories = [replacement_id]
	_expect(level._count_party_monster_bounty_marked_players() >= 1, failures, "Level should count marked Party Monster bounty carriers")
	Network.players.erase(tracked_peer)
	level.free()

	var player = PLAYER_SCRIPT.new()
	player.name = "77"
	player.role = Network.Role.CHAMELEON
	player.character_model_id = PARTY_MONSTER_MODEL_ID
	Network.players[77] = {"alive": true}
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
	Network.players.erase(77)
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
	if root == null or node_name.is_empty():
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
