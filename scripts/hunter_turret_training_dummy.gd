@tool
class_name HunterTurretTrainingDummy
extends StaticBody3D

const DEFAULT_MODEL_ID := "party_monster_c01"
const BODY_HEIGHT := 1.85
const BODY_RADIUS := 0.42
const INFINITE_HEALTH := 1000000.0
const DEFAULT_AIM_HEIGHT := 1.08
const HIT_ACTIONS: Array[String] = ["get_hit", "hit", "defense_hit"]
const PARTY_MONSTER_SKIN_NAME := "PartyMonsterTrainingSkin"

@export var randomize_skin_on_ready := true
@export var configured_model_id := DEFAULT_MODEL_ID
@export_range(0.6, 1.6, 0.01, "or_greater") var aim_height := DEFAULT_AIM_HEIGHT
@export_range(100.0, 10000.0, 1.0, "or_greater") var auto_turret_priority := 2000.0

var hit_count := 0
var current_model_id := ""
var last_hit_action := ""
var last_hit_clip := ""

var _skin: Node3D = null
var _hit_tween: Tween = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("card_decoy_targets")
	add_to_group("hunter_turret_training_dummies")
	collision_layer = 1
	collision_mask = 0
	_ensure_collision()
	_choose_model_id()
	_ensure_skin()
	_play_idle()


func take_damage(_amount: float, _attacker_id: int, _is_headshot: bool = false) -> void:
	hit_count += 1
	_play_random_hit_reaction()
	_play_hit_pulse()


func get_health() -> float:
	return INFINITE_HEALTH


func is_prop() -> bool:
	return true


func is_card_decoy_target() -> bool:
	return true


func get_auto_turret_priority() -> float:
	return auto_turret_priority


func get_hunter_prop_sense_position() -> Vector3:
	return global_position + Vector3.UP * aim_height


func get_auto_turret_aim_point() -> Vector3:
	return get_hunter_prop_sense_position()


func get_hit_count_for_test() -> int:
	return hit_count


func get_character_model_id_for_test() -> String:
	return current_model_id


func get_last_hit_action_for_test() -> String:
	return last_hit_action


func get_last_hit_clip_for_test() -> String:
	return last_hit_clip


func has_party_monster_skin_for_test() -> bool:
	return _skin != null and is_instance_valid(_skin)


func _ensure_collision() -> void:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		add_child(shape_node)

	var capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		capsule.resource_local_to_scene = true
		shape_node.shape = capsule
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	shape_node.position = Vector3.UP * (BODY_HEIGHT * 0.5)


func _choose_model_id() -> void:
	if Engine.is_editor_hint() or not randomize_skin_on_ready:
		current_model_id = _party_monster_or_default(configured_model_id)
		return
	current_model_id = _random_party_monster_model_id()


func _ensure_skin() -> void:
	if _skin and is_instance_valid(_skin):
		return
	var scene: PackedScene = load(CharacterSkinCatalog.PARTY_MONSTER_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("Party Monster training dummy could not load skin scene: %s" % CharacterSkinCatalog.PARTY_MONSTER_SCENE_PATH)
		return
	_skin = scene.instantiate() as Node3D
	if _skin == null:
		push_warning("Party Monster training dummy skin did not instantiate as Node3D.")
		return
	_skin.name = PARTY_MONSTER_SKIN_NAME
	add_child(_skin)
	if _skin.has_method("set_character_model_id"):
		_skin.call("set_character_model_id", current_model_id)
	if _skin.has_method("_build_skin"):
		_skin.call("_build_skin")
	var model: Dictionary = CharacterSkinCatalog.get_model(current_model_id)
	_skin.scale = model.get("scale", Vector3.ONE)
	_skin.position = model.get("offset", Vector3.ZERO)


func _play_idle() -> void:
	if _skin and _skin.has_method("play_action"):
		_skin.call("play_action", "idle")


func _play_random_hit_reaction() -> void:
	_ensure_skin()
	if not _skin or not is_instance_valid(_skin):
		return
	last_hit_action = HIT_ACTIONS[_rng.randi_range(0, HIT_ACTIONS.size() - 1)]
	var played := false
	if last_hit_action == "get_hit" and _skin.has_method("play_hit_ragdoll"):
		_skin.call("play_hit_ragdoll", Vector3.ZERO, 1.0)
		played = true
	elif _skin.has_method("play_action"):
		played = bool(_skin.call("play_action", last_hit_action))
	if not played and _skin.has_method("get_hit"):
		_skin.call("get_hit")
	last_hit_clip = ""
	if _skin.has_method("get_current_animation_clip"):
		last_hit_clip = str(_skin.call("get_current_animation_clip"))


func _play_hit_pulse() -> void:
	if not _skin or not is_instance_valid(_skin) or not is_inside_tree():
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	var base_scale: Vector3 = _skin.scale
	_hit_tween = create_tween()
	_hit_tween.tween_property(_skin, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.96, base_scale.z * 1.05), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_skin, "scale", base_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _random_party_monster_model_id() -> String:
	var ids: PackedStringArray = PackedStringArray()
	var models: Array = CharacterSkinCatalog.all()
	for raw_model: Variant in models:
		if not raw_model is Dictionary:
			continue
		var model: Dictionary = raw_model as Dictionary
		var model_id: String = str(model.get("id", ""))
		if CharacterSkinCatalog.is_party_monster(model_id):
			ids.append(model_id)
	if ids.is_empty():
		return CharacterSkinCatalog.party_monster_default_id()
	return ids[_rng.randi_range(0, ids.size() - 1)]


func _party_monster_or_default(model_id: String) -> String:
	var normalized: String = CharacterSkinCatalog.normalize(model_id)
	if CharacterSkinCatalog.is_party_monster(normalized):
		return normalized
	return CharacterSkinCatalog.party_monster_default_id()
