extends RefCounted
class_name PlayerCardEffectController

const CardDatabaseScript := preload("res://scripts/card_database.gd")

var _owner: Node = null


func initialize(owner: Node) -> void:
	_owner = owner


func apply_card_effect(card_id: String) -> void:
	if not _has_owner():
		return
	if _is_owner_dead():
		_feedback_to_owner("SPECTATING", Color(0.72, 0.86, 1.0, 1.0), 0.55)
		return

	var card: Dictionary = CardDatabaseScript.get_card(card_id)
	var duration: float = float(card.get("duration", 0.0))
	match card_id:
		"prop_chromatic_burst":
			_call_owner("_card_apply_stealth", [maxf(duration, 1.0)])
		"prop_micro_form":
			_call_owner("_card_apply_scale", [0.25, maxf(duration, 15.0)])
		"prop_flashbang":
			_call_owner("_card_apply_vision_impairment_to_role", [Network.Role.HUNTER, float(card.get("radius", 10.0)), duration, "FLASH"])
		"prop_decoy_echo":
			_call_owner("_card_spawn_decoy", [maxf(duration, 15.0), Vector3.ZERO])
		"prop_portal_step":
			_call_owner("_card_portal_step")
		"prop_static_aura":
			_call_owner("_card_apply_prop_aura_status", ["damage_immunity", float(card.get("radius", 8.0)), maxf(duration, 8.0)])
		"prop_emergency_conceal":
			_call_owner("_card_apply_emergency_conceal", [duration])
		"prop_paint_bomb":
			_call_owner("_card_apply_vision_impairment_to_role", [Network.Role.HUNTER, float(card.get("radius", 20.0)), duration, "PAINT"])
		"prop_time_stop":
			_call_owner("_card_apply_role_speed_multiplier", [Network.Role.HUNTER, float(card.get("radius", 10.0)), 0.5, maxf(duration, 8.0)])
		"prop_mist_clones":
			_call_owner("_card_spawn_mist_clones", [maxf(duration, 8.0)])
		"prop_sense":
			_call_owner("_card_apply_visible_hunter_scale", [35.0, 0.5, maxf(duration, 8.0)])
		"prop_empty_bullet":
			_call_owner("_card_clear_hunter_ammo")
		"prop_silent_steps":
			_call_owner("_card_apply_status", ["silent_steps", maxf(duration, 18.0)])
		"prop_extreme_immunity":
			_call_owner("_card_apply_status", ["damage_immunity", maxf(duration, 25.0)])
			_call_owner("_card_apply_status", ["hunter_skill_immunity", maxf(duration, 25.0)])
			_call_owner("_card_tint_for_duration", [Color(0.55, 0.98, 0.82, 1.0), maxf(duration, 25.0)])
		"prop_revival":
			_feedback_to_owner("REVIVAL READY", Color(0.62, 1.0, 0.74, 1.0), 0.9)
		"hunter_pulse_scan":
			_call_owner("_card_reveal_props", [float(card.get("radius", 24.0)), maxf(duration, 6.0)])
		"hunter_blacklight":
			_call_owner("_card_reveal_props", [float(card.get("radius", 18.0)), maxf(duration, 8.0)])
		"hunter_overclock_rounds":
			_call_owner("_card_refill_weapon", [60])
			_call_owner("_card_apply_status", ["speed_multiplier_1_2", maxf(duration, 8.0)])
		"hunter_gravity_net":
			_call_owner("_card_apply_role_speed_multiplier", [Network.Role.CHAMELEON, float(card.get("radius", 10.0)), 0.55, maxf(duration, 8.0)])
			_call_owner("_card_apply_role_speed_multiplier", [Network.Role.STALKER, float(card.get("radius", 10.0)), 0.55, maxf(duration, 8.0)])
		"hunter_echo_marker":
			_call_owner("_card_mark_nearest_prop", [float(card.get("radius", 35.0)), maxf(duration, 5.0)])
		"hunter_light_cage":
			_call_owner("_card_reveal_props", [float(card.get("radius", 12.0)), maxf(duration, 7.0)])
			_call_owner("_card_apply_role_speed_multiplier", [Network.Role.CHAMELEON, float(card.get("radius", 12.0)), 0.72, maxf(duration, 7.0)])
			_call_owner("_card_apply_role_speed_multiplier", [Network.Role.STALKER, float(card.get("radius", 12.0)), 0.72, maxf(duration, 7.0)])
		"hunter_turret_overdrive":
			_call_owner("_card_overdrive_turret", [maxf(duration, 10.0)])
		"hunter_ammo_cache":
			_call_owner("_card_refill_weapon", [WeaponSystem.MAX_TOTAL_AMMO])
		"hunter_adrenaline":
			_call_owner("_card_apply_status", ["speed_multiplier_1_45", maxf(duration, 6.0)])
		"hunter_signal_jammer":
			_call_owner("_card_apply_vision_impairment_to_role", [Network.Role.CHAMELEON, float(card.get("radius", 14.0)), maxf(duration, 6.0), "JAMMED"])
			_call_owner("_card_apply_vision_impairment_to_role", [Network.Role.STALKER, float(card.get("radius", 14.0)), maxf(duration, 6.0), "JAMMED"])
		_:
			_feedback_to_owner("CARD", Color(0.62, 0.92, 1.0, 1.0), 0.5)


func _has_owner() -> bool:
	return _owner != null and is_instance_valid(_owner)


func _is_owner_dead() -> bool:
	if not _has_owner():
		return true
	return bool(_owner.get("_is_dead"))


func _feedback_to_owner(text: String, color: Color, duration: float) -> void:
	_call_owner("_card_feedback_to_owner", [text, color, duration])


func _call_owner(method_name: String, args: Array = []) -> Variant:
	if not _has_owner() or not _owner.has_method(method_name):
		return null
	return _owner.callv(method_name, args)
