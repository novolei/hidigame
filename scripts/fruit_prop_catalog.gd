extends RefCounted
class_name FruitPropCatalog


# Compatibility note: the class name is kept because existing lobby/playtest code
# already references FruitPropCatalog. The catalog now covers all replicable map
# props, not only fruit.
const MAP_PROPS := [
	{"id": "apple", "name": "Apple", "category": "fruit", "scene": "res://Prefabs/Fruits/apple.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.18, 1.18, 1.18)},
	{"id": "banana", "name": "Banana", "category": "fruit", "scene": "res://Prefabs/Fruits/banana.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.25, 1.25, 1.25)},
	{"id": "banana_bunch", "name": "Banana Bunch", "category": "fruit", "scene": "res://Prefabs/Fruits/banana_bunch.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "coconut", "name": "Coconut", "category": "fruit", "scene": "res://Prefabs/Fruits/coconut.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "lemon", "name": "Lemon", "category": "fruit", "scene": "res://Prefabs/Fruits/lemon.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.18, 1.18, 1.18)},
	{"id": "lime", "name": "Lime", "category": "fruit", "scene": "res://Prefabs/Fruits/lime.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.18, 1.18, 1.18)},
	{"id": "orange", "name": "Orange", "category": "fruit", "scene": "res://Prefabs/Fruits/orange.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.18, 1.18, 1.18)},
	{"id": "pineapple", "name": "Pineapple", "category": "fruit", "scene": "res://Prefabs/Fruits/pineapple.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(0.98, 0.98, 0.98)},
	{"id": "watermelon", "name": "Watermelon", "category": "fruit", "scene": "res://Prefabs/Fruits/watermelon.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.05, 1.05, 1.05)},
	{"id": "watermelon_slice", "name": "Watermelon Slice", "category": "fruit", "scene": "res://Prefabs/Fruits/watermelon_slice.tscn", "material": "res://Materials/M_fruit.tres", "scale": Vector3(1.16, 1.16, 1.16)},

	{"id": "burger", "name": "Burger", "category": "junk_food", "scene": "res://Prefabs/Junk Food/burger.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "fries", "name": "Fries", "category": "junk_food", "scene": "res://Prefabs/Junk Food/fries.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.05, 1.05, 1.05)},
	{"id": "hot_dog", "name": "Hot Dog", "category": "junk_food", "scene": "res://Prefabs/Junk Food/hot_dog.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "pizza_cheese", "name": "Cheese Pizza", "category": "junk_food", "scene": "res://Prefabs/Junk Food/pizza_cheese.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "pizza_pepperoni", "name": "Pepperoni Pizza", "category": "junk_food", "scene": "res://Prefabs/Junk Food/pizza_pepperoni.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "soda_can_cola", "name": "Cola Can", "category": "junk_food", "scene": "res://Prefabs/Junk Food/soda_can_cola.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "soda_can_beer", "name": "Soda Can", "category": "junk_food", "scene": "res://Prefabs/Junk Food/soda_can_beer.tscn", "material": "res://Materials/M_junk_food.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "ice_cream_vanilla_cone", "name": "Vanilla Cone", "category": "junk_food", "scene": "res://Prefabs/Junk Food/ice_cream_vanilla_cone.tscn", "material": "res://Materials/M_scoop_white.tres", "scale": Vector3(1.0, 1.0, 1.0)},
	{"id": "ice_cream_chocolate_cone", "name": "Chocolate Cone", "category": "junk_food", "scene": "res://Prefabs/Junk Food/ice_cream_chocolate_cone.tscn", "material": "res://Materials/M_scoop_chocolate.tres", "scale": Vector3(1.0, 1.0, 1.0)},
	{"id": "ice_cream_strawberry_cone", "name": "Strawberry Cone", "category": "junk_food", "scene": "res://Prefabs/Junk Food/ice_cream_strawberry_cone.tscn", "material": "res://Materials/M_scoop_strawberry.tres", "scale": Vector3(1.0, 1.0, 1.0)},

	{"id": "plate", "name": "Plate", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/plate.tscn", "material": "res://Materials/M_plate.tres", "scale": Vector3(1.16, 1.16, 1.16)},
	{"id": "dish", "name": "Dish", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/dish.tscn", "material": "res://Materials/M_plate.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "dish_full", "name": "Full Dish", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/dish_full.tscn", "material": "res://Materials/M_plate.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "bowl", "name": "Bowl", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/bowl.tscn", "material": "res://Materials/M_plate.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "bowl_full", "name": "Full Bowl", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/bowl_full.tscn", "material": "res://Materials/M_bowl_contents.tres", "scale": Vector3(1.05, 1.05, 1.05)},
	{"id": "bowl_half", "name": "Half Bowl", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/bowl_half.tscn", "material": "res://Materials/M_bowl_contents.tres", "scale": Vector3(1.05, 1.05, 1.05)},
	{"id": "sushi_block", "name": "Sushi Block", "category": "dish", "scene": "res://Prefabs/Plates and Dishes/sushi_block.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.05, 1.05, 1.05)},

	{"id": "drumstick", "name": "Drumstick", "category": "protein", "scene": "res://Prefabs/Protein/drumstick.tscn", "material": "res://Materials/M_protein.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "egg", "name": "Egg", "category": "protein", "scene": "res://Prefabs/Protein/egg.tscn", "material": "res://Materials/M_protein.tres", "scale": Vector3(1.2, 1.2, 1.2)},
	{"id": "egg_cooked", "name": "Cooked Egg", "category": "protein", "scene": "res://Prefabs/Protein/egg_cooked.tscn", "material": "res://Materials/M_protein.tres", "scale": Vector3(1.14, 1.14, 1.14)},
	{"id": "meat_haunch", "name": "Meat Haunch", "category": "protein", "scene": "res://Prefabs/Protein/meat_haunch.tscn", "material": "res://Materials/M_protein.tres", "scale": Vector3(1.02, 1.02, 1.02)},
	{"id": "steak", "name": "Steak", "category": "protein", "scene": "res://Prefabs/Protein/steak.tscn", "material": "res://Materials/M_protein.tres", "scale": Vector3(1.12, 1.12, 1.12)},

	{"id": "sushi_salmon_maki", "name": "Salmon Maki", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_salmon_maki.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_salmon_nigiri", "name": "Salmon Nigiri", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_salmon_nigiri.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_shiromi_maki", "name": "Shiromi Maki", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_shiromi_maki.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_shiromi_nigiri", "name": "Shiromi Nigiri", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_shiromi_nigiri.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_shrimp_nigiri", "name": "Shrimp Nigiri", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_shrimp_nigiri.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_tuna_maki", "name": "Tuna Maki", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_tuna_maki.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "sushi_tuna_nigiri", "name": "Tuna Nigiri", "category": "sushi", "scene": "res://Prefabs/Sushi/sushi_tuna_nigiri.tscn", "material": "res://Materials/M_sushi.tres", "scale": Vector3(1.12, 1.12, 1.12)},

	{"id": "broccoli", "name": "Broccoli", "category": "vegetable", "scene": "res://Prefabs/Vegetables/broccoli.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.05, 1.05, 1.05)},
	{"id": "carrot", "name": "Carrot", "category": "vegetable", "scene": "res://Prefabs/Vegetables/carrot.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.14, 1.14, 1.14)},
	{"id": "corn", "name": "Corn", "category": "vegetable", "scene": "res://Prefabs/Vegetables/corn.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "cucumber", "name": "Cucumber", "category": "vegetable", "scene": "res://Prefabs/Vegetables/cucumber.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "eggplant", "name": "Eggplant", "category": "vegetable", "scene": "res://Prefabs/Vegetables/eggplant.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.08, 1.08, 1.08)},
	{"id": "mushroom", "name": "Mushroom", "category": "vegetable", "scene": "res://Prefabs/Vegetables/mushroom.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "onion_red", "name": "Red Onion", "category": "vegetable", "scene": "res://Prefabs/Vegetables/onion_red.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "onion_white", "name": "White Onion", "category": "vegetable", "scene": "res://Prefabs/Vegetables/onion_white.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.1, 1.1, 1.1)},
	{"id": "potato", "name": "Potato", "category": "vegetable", "scene": "res://Prefabs/Vegetables/potato.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.12, 1.12, 1.12)},
	{"id": "tomato", "name": "Tomato", "category": "vegetable", "scene": "res://Prefabs/Vegetables/tomato.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.14, 1.14, 1.14)},
	{"id": "zucchini", "name": "Zucchini", "category": "vegetable", "scene": "res://Prefabs/Vegetables/zucchini.tscn", "material": "res://Materials/M_vegetable.tres", "scale": Vector3(1.08, 1.08, 1.08)},
]


static func all() -> Array:
	return MAP_PROPS


static func by_id(prop_id: String) -> Dictionary:
	for prop in MAP_PROPS:
		if str(prop.get("id", "")) == prop_id:
			return prop
	return MAP_PROPS[0]


static func random_entry(rng: RandomNumberGenerator) -> Dictionary:
	return MAP_PROPS[rng.randi_range(0, MAP_PROPS.size() - 1)]
