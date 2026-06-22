extends RefCounted
class_name UnityAssetCatalog


const DECORATIONS := [
	{"id": "synty_barrel_metal", "name": "Metal Barrel", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Prop_Barrel_Metal_01.glb", "material": "res://Materials/M_unity_metal.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_barrel_wood", "name": "Wood Barrel", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Prop_Barrel_Wood_01.glb", "material": "res://Materials/M_unity_synty_wood.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_cardboard_box", "name": "Cardboard Box", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Prop_Cardboard_Box_01.glb", "material": "res://Materials/M_unity_environment.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_crate", "name": "Crate", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Prop_Crate_01.glb", "material": "res://Materials/M_unity_synty_wood.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_traffic_cone", "name": "Traffic Cone", "scene": "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonPrototype_Prop_Cone_01.glb", "material": "res://Materials/M_unity_synty_starter.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_target", "name": "Target", "scene": "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonPrototype_Prop_Target_03.glb", "material": "res://Materials/M_unity_synty_starter.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_small_rock", "name": "Small Rock", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Env_Rock_01.glb", "material": "res://Materials/M_unity_synty_rock.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_bush", "name": "Bush", "scene": "res://assets/unity_migrated/synty/PolygonGeneric/Models/SM_Gen_Env_Bush_01.glb", "material": "res://Materials/M_unity_environment.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_tree_stump", "name": "Tree Stump", "scene": "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_Generic_TreeStump_01.glb", "material": "res://Materials/M_unity_synty_starter.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "synty_car_small", "name": "Small Car", "scene": "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonCity_Veh_Car_Small_01.glb", "material": "res://Materials/M_unity_synty_starter.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_busted_tank", "name": "Busted Tank", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/BustedTank.glb", "material": "res://Materials/M_unity_metal.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_cactus", "name": "Cactus", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Cactus.glb", "material": "res://Materials/M_unity_tanks_cactus.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_column", "name": "Column", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Column01.glb", "material": "res://Materials/M_unity_tanks_rock.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_oil_storage", "name": "Oil Storage", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/OilStorage.glb", "material": "res://Materials/M_unity_metal.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_rock", "name": "Tank Arena Rock", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Rocks01.glb", "material": "res://Materials/M_unity_tanks_rock.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_shell", "name": "Tank Shell", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Miscellaneous/Shell.glb", "material": "res://Materials/M_unity_metal.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_health", "name": "Health Pickup", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/PowerUps/Health.glb", "material": "res://Materials/M_unity_tanks_health.tres", "scale": Vector3.ONE, "force_material": true, "node_materials": {"Box004": "res://Materials/M_unity_tanks_health_cross.tres"}},
	{"id": "tanks_star", "name": "Star Pickup", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/PowerUps/Star.glb", "material": "res://Materials/M_unity_tanks_star.tres", "scale": Vector3.ONE, "force_material": true},
	{"id": "tanks_light_tank", "name": "Light Tank", "scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_Light_Model.glb", "material": "res://Materials/M_unity_tanks_red.tres", "scale": Vector3.ONE, "force_material": true},
]

const WEAPONS := {
	"ak74": {"id": "ak74", "name": "AK74", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/AK74.glb", "material": "res://Materials/M_unity_weapon.tres"},
	"m4": {"id": "m4", "name": "M4", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/M4_8.glb", "material": "res://Materials/M_unity_weapon.tres"},
	"m1911": {"id": "m1911", "name": "M1911", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/M1911.glb", "material": "res://Materials/M_unity_weapon.tres"},
	"rpg7": {"id": "rpg7", "name": "RPG7", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/RPG7.glb", "material": "res://Materials/M_unity_weapon.tres"},
	"uzi": {"id": "uzi", "name": "Uzi", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/Uzi.glb", "material": "res://Materials/M_unity_weapon.tres"},
	"smoke": {"id": "smoke", "name": "Smoke Grenade", "scene": "res://assets/unity_migrated/low_poly_weapons_vol1/Models/Smoke.glb", "material": "res://Materials/M_unity_weapon.tres"},
}


static func decorations() -> Array:
	return DECORATIONS


static func random_decoration(rng: RandomNumberGenerator) -> Dictionary:
	return DECORATIONS[rng.randi_range(0, DECORATIONS.size() - 1)]


static func weapon_by_id(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS["ak74"])
