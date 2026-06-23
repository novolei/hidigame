extends RefCounted
class_name CharacterSkinCatalog

const BASIC_HUMANOID_ID := "basic_humanoid"
const HUNTER_SHOOTER_ID := "hunter_shooter"
const GODOT_ROBOT_ID := "godot_robot"
const BUD_ID := "bud"
const WALKALL_ID := "walkall"
const CUTE_ICE_CREAM_ID := "cute_ice_cream"
const DEFAULT_ID := BASIC_HUMANOID_ID

const MODELS := [
	{
		"id": GODOT_ROBOT_ID,
		"label": "Godot Robot",
		"label_key": "character.godot_robot",
		"scene": "",
		"scale": Vector3.ONE,
		"offset": Vector3.ZERO,
	},
	{
		"id": "gdbot",
		"label": "GDBot",
		"label_key": "character.gdbot",
		"scene": "res://addons/gdquest_gdbot/gdbot_skin.tscn",
		"scale": Vector3(0.62, 0.62, 0.62),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": "sophia",
		"label": "Sophia",
		"label_key": "character.sophia",
		"scene": "res://addons/gdquest_sophia/sophia_skin.tscn",
		"scale": Vector3(0.72, 0.72, 0.72),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": "gobot",
		"label": "Gobot",
		"label_key": "character.gobot",
		"scene": "res://addons/gdquest_gobot/gobot_skin.tscn",
		"scale": Vector3(0.72, 0.72, 0.72),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": "round_bat",
		"label": "Round Bat",
		"label_key": "character.round_bat",
		"scene": "res://addons/gdquest_round_bat/round_bat_skin.tscn",
		"scale": Vector3(0.74, 0.74, 0.74),
		"offset": Vector3(0, 0.05, 0),
	},
	{
		"id": "bee_bot",
		"label": "Bee Bot",
		"label_key": "character.bee_bot",
		"scene": "res://addons/gdquest_bee_bot/bee_bot_skin.tscn",
		"scale": Vector3(0.80, 0.80, 0.80),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": "beetle_bot",
		"label": "Beetle Bot",
		"label_key": "character.beetle_bot",
		"scene": "res://addons/gdquest_beetle_bot/beetle_bot_skin.tscn",
		"scale": Vector3(0.80, 0.80, 0.80),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": "gingerbread",
		"label": "Gingerbread",
		"label_key": "character.gingerbread",
		"scene": "res://assets/characters/gingerbread/gingerbread_animated_skin.tscn",
		"scale": Vector3(0.90, 0.90, 0.90),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": BASIC_HUMANOID_ID,
		"label": "Basic Humanoid",
		"label_key": "character.basic_humanoid",
		"scene": "res://assets/characters/basic/basic_humanoid_skin.tscn",
		"scale": Vector3(0.56, 0.56, 0.56),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": HUNTER_SHOOTER_ID,
		"label": "Hunter Shooter",
		"label_key": "character.hunter_shooter",
		"scene": "res://assets/characters/hunter_shooter/hunter_shooter_skin.tscn",
		"scale": Vector3(1.0, 1.0, 1.0),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": BUD_ID,
		"label": "Bud",
		"label_key": "character.bud",
		"scene": "res://assets/characters/bud/bud_skin.tscn",
		"scale": Vector3(1.65, 1.65, 1.65),
		"offset": Vector3(0, 0.16, 0),
	},
	{
		"id": WALKALL_ID,
		"label": "Walkall",
		"label_key": "character.walkall",
		"scene": "res://assets/characters/walkall/walkall_skin.tscn",
		"scale": Vector3(16.5, 16.5, 16.5),
		"offset": Vector3(0, 0.0, 0),
	},
	{
		"id": CUTE_ICE_CREAM_ID,
		"label": "Cute Ice Cream",
		"label_key": "character.cute_ice_cream",
		"scene": "res://assets/characters/cute_ice_cream/cute_ice_cream_skin.tscn",
		"scale": Vector3(0.34, 0.34, 0.34),
		"offset": Vector3(0, 0.0, 0),
	},
]


static func all() -> Array:
	return MODELS


static func normalize(id: String) -> String:
	var normalized := id.strip_edges().to_lower()
	for model in MODELS:
		if str(model.get("id", "")) == normalized:
			return normalized
	return DEFAULT_ID


static func get_model(id: String) -> Dictionary:
	var normalized := normalize(id)
	for model in MODELS:
		if str(model.get("id", "")) == normalized:
			return model
	return MODELS[0]


static func label_for(id: String) -> String:
	return str(get_model(id).get("label", "Godot Robot"))


static func scene_path_for(id: String) -> String:
	return str(get_model(id).get("scene", ""))
