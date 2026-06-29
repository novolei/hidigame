extends Node
class_name HunterPropSenseSystem

const AUDIO_RANGE := 28.0
const VISUAL_ENTER_RANGE := 18.0
const VISUAL_EXIT_RANGE := 20.0
const CHECK_INTERVAL := 0.15
const NEAR_BEEP_INTERVAL := 0.32
const FAR_BEEP_INTERVAL := 1.85
const ACTIVE_SECONDS := 10.0
const COOLDOWN_SECONDS := 45.0

var hunter_owner: CharacterBody3D = null
var _check_timer := 0.0
var _sensed_targets := {}
var _visual_targets := {}
var _active_remaining := 0.0
var _cooldown_remaining := 0.0


func _exit_tree() -> void:
	_clear_all_targets()


func initialize(owner_node: CharacterBody3D) -> void:
	hunter_owner = owner_node
	_check_timer = 0.0
	add_to_group("hunter_prop_sense_systems")
	force_scan()


func _process(delta: float) -> void:
	if not _is_local_hunter_active():
		_clear_all_targets()
		return
	_update_passive_timers(delta)
	if _cooldown_remaining > 0.0:
		_clear_all_targets()
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_try_scan_for_disguised_chameleons()


func force_scan() -> void:
	if _cooldown_remaining > 0.0:
		_clear_all_targets()
		return
	_try_scan_for_disguised_chameleons()


func get_sensed_target_count() -> int:
	return _sensed_targets.size()


func get_visual_target_count() -> int:
	return _visual_targets.size()


func is_target_sensed(target: Node) -> bool:
	return target != null and _sensed_targets.has(target.get_instance_id())


func is_target_visually_sensed(target: Node) -> bool:
	return target != null and _visual_targets.has(target.get_instance_id())


func is_passive_active() -> bool:
	return _active_remaining > 0.0


func get_passive_active_remaining() -> float:
	return _active_remaining


func get_passive_cooldown_remaining() -> float:
	return _cooldown_remaining


func _is_local_hunter_active() -> bool:
	if not hunter_owner or not is_instance_valid(hunter_owner) or not hunter_owner.is_inside_tree():
		return false
	if not hunter_owner.multiplayer.has_multiplayer_peer():
		return false
	return (
		hunter_owner.has_method("is_hunter")
		and bool(hunter_owner.call("is_hunter"))
		and hunter_owner.is_multiplayer_authority()
	)


func _update_passive_timers(delta: float) -> void:
	if _active_remaining > 0.0:
		_active_remaining = maxf(_active_remaining - delta, 0.0)
		if is_zero_approx(_active_remaining):
			_start_cooldown()
	elif _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func _start_cooldown() -> void:
	_active_remaining = 0.0
	_cooldown_remaining = COOLDOWN_SECONDS
	_clear_all_targets()


func _activate_passive() -> void:
	if _active_remaining <= 0.0 and _cooldown_remaining <= 0.0:
		_active_remaining = ACTIVE_SECONDS


func _try_scan_for_disguised_chameleons() -> void:
	var detected := _scan_for_disguised_chameleons()
	if detected:
		_activate_passive()


func _scan_for_disguised_chameleons() -> bool:
	if not _is_local_hunter_active():
		_clear_all_targets()
		return false

	var seen_audio := {}
	var seen_visual := {}
	var detected_audio := false
	var hunter_origin := hunter_owner.global_position
	var tree := hunter_owner.get_tree()
	if not tree:
		return false

	for node in tree.get_nodes_in_group("players"):
		if node == hunter_owner:
			continue
		if not _is_sense_candidate(node):
			_deactivate_target(node)
			continue

		var target := node as Node3D
		var target_origin := target.global_position
		if target.has_method("get_hunter_prop_sense_position"):
			target_origin = target.call("get_hunter_prop_sense_position")
		var distance := hunter_origin.distance_to(target_origin)
		var target_id := target.get_instance_id()
		if distance <= AUDIO_RANGE:
			var proximity := 1.0 - clampf(distance / AUDIO_RANGE, 0.0, 1.0)
			var interval := lerpf(FAR_BEEP_INTERVAL, NEAR_BEEP_INTERVAL, proximity)
			var already_visual := _visual_targets.has(target_id)
			var visual_range := VISUAL_EXIT_RANGE if already_visual else VISUAL_ENTER_RANGE
			var visual_active := distance <= visual_range
			detected_audio = true
			_sensed_targets[target_id] = target
			seen_audio[target_id] = true
			if visual_active:
				_visual_targets[target_id] = target
				seen_visual[target_id] = true
			else:
				_visual_targets.erase(target_id)
			target.call("set_hunter_prop_sense_revealed", true, proximity, interval, visual_active)
			if target.has_method("notify_owner_hunter_sense"):
				target.call("notify_owner_hunter_sense", proximity, interval, visual_active)
		else:
			_deactivate_target(target)

	for target_id in _sensed_targets.keys():
		if not seen_audio.has(target_id):
			var old_target = _sensed_targets[target_id]
			if old_target and is_instance_valid(old_target):
				old_target.call("set_hunter_prop_sense_revealed", false)
			_sensed_targets.erase(target_id)
			_visual_targets.erase(target_id)

	for target_id in _visual_targets.keys():
		if not seen_visual.has(target_id):
			_visual_targets.erase(target_id)
	return detected_audio


func _is_sense_candidate(node: Node) -> bool:
	return (
		node is Node3D
		and node.has_method("is_hunter_prop_sense_target")
		and node.has_method("set_hunter_prop_sense_revealed")
		and bool(node.call("is_hunter_prop_sense_target"))
	)


func _deactivate_target(node: Node) -> void:
	if not node:
		return
	var target_id := node.get_instance_id()
	if not _sensed_targets.has(target_id):
		return
	if node.has_method("set_hunter_prop_sense_revealed"):
		node.call("set_hunter_prop_sense_revealed", false)
	_sensed_targets.erase(target_id)
	_visual_targets.erase(target_id)


func _clear_all_targets() -> void:
	for target_id in _sensed_targets.keys():
		var target = _sensed_targets[target_id]
		if target and is_instance_valid(target) and target.has_method("set_hunter_prop_sense_revealed"):
			target.call("set_hunter_prop_sense_revealed", false)
	_sensed_targets.clear()
	_visual_targets.clear()
