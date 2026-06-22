extends RefCounted
class_name CharacterSkinCatalog

const DEFAULT_ID := "godot_robot"

const MODELS := [
	{
		"id": "godot_robot",
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
