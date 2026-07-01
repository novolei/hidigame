extends RefCounted
class_name AnimalCatalog

## Static data table for the per-round animals (disguise targets + ambient life).
##
## Three asset families, verified via Fennara:
##   - "atlas" wild pack (wildanimal_ani): rigged but NO animation clips → driven
##     by AnimalProp's procedural liveliness; colored by the shared palette atlas.
##   - "deer" (deers/*Walk.fbx): rig + 1 Walk clip + embedded texture; hunt-tracker
##     NPCs.
##   - "iceage" (Mammoth/SabreTooth/Sloth): rig + real Idle/Walk clips, vertex-
##     colored (no texture). SabreTooth is also a hunt-tracker.
##
## IMPORTANT sizing note: the imported models have wildly different native scales
## (a "raw" deer is a few metres, a raw mammoth is HUNDREDS of metres because of
## FBX import units). So the catalog stores the desired FINAL size in metres
## (`height` = standing height, `radius` = collision radius), and AnimalProp
## measures each model's real in-tree AABB at spawn and computes the uniform scale
## needed to hit `height`. Never hardcode a per-model scale multiplier.
##
## Animated species are listed first and prioritised by random_species(), so a
## round always includes the deer (and usually the ice-age beasts) before the
## clip-less wild animals fill the remaining slots.
##
## Per-species fields:
##   scene     full res:// path to the imported model
##   height    FINAL standing height in metres (player is ~1.73 m)
##   radius    FINAL collision radius in metres
##   speed     slow-walk metres/second while pathing
##   texture   "atlas" (shared palette override) | "embedded" (model's own material)
##   behavior  "wander" | "hunt_tracker" (patrol + follow a hunter)
##   track     hunt-tracker tuning (range/fov_deg/speed/leash/give_up/follow_gap)
##   animated  true when the model ships AnimationPlayer clips AnimalProp can drive

const ATLAS_PATH: String = "res://resources/animals/wildanimal_ani/texture/wild_animals_map.png"
const ATLAS_MATERIAL_PATH: String = "res://resources/animals/wild_animal_atlas_material.tres"
const WILD_DIR: String = "res://resources/animals/wildanimal_ani/fbx/unity/"

## One AK bullet is 25 dmg, so a clean hit one-shots a real animal.
const ANIMAL_HEALTH: float = 25.0

const SPECIES: Array[Dictionary] = [
	# --- animated, prioritised: deer (hunt-trackers) ---
	{"id": "buck", "name": "雄鹿", "scene": "res://resources/animals/deers/BuckWalk.fbx", "height": 1.55, "radius": 0.40, "speed": 2.3, "texture": "embedded", "behavior": "hunt_tracker", "track": {"range": 18.0, "fov_deg": 78.0, "speed": 3.2, "leash": 16.0, "give_up": 4.0, "follow_gap": 3.5}, "animated": true},
	{"id": "button_buck", "name": "幼角鹿", "scene": "res://resources/animals/deers/ButtonBuckWalk.fbx", "height": 1.35, "radius": 0.36, "speed": 2.4, "texture": "embedded", "behavior": "hunt_tracker", "track": {"range": 18.0, "fov_deg": 78.0, "speed": 3.3, "leash": 16.0, "give_up": 4.0, "follow_gap": 3.5}, "animated": true},
	{"id": "fawn", "name": "小鹿", "scene": "res://resources/animals/deers/FawnWalk.fbx", "height": 1.05, "radius": 0.30, "speed": 2.5, "texture": "embedded", "behavior": "hunt_tracker", "track": {"range": 16.0, "fov_deg": 78.0, "speed": 3.4, "leash": 15.0, "give_up": 3.5, "follow_gap": 3.0}, "animated": true},
	# --- animated, prioritised: ice-age beasts ---
	{"id": "mammoth", "name": "猛犸", "scene": "res://resources/animals/iceage/Mammoth.fbx", "height": 2.6, "radius": 1.0, "speed": 1.3, "texture": "embedded", "behavior": "wander", "animated": true},
	# SabreTooth is a relentless tracker: longer sight, faster pursuit, longer leash.
	{"id": "sabretooth", "name": "剑齿虎", "scene": "res://resources/animals/iceage/SabreTooth.fbx", "height": 1.7, "radius": 0.55, "speed": 2.4, "texture": "embedded", "behavior": "hunt_tracker", "track": {"range": 30.0, "fov_deg": 100.0, "speed": 5.2, "leash": 34.0, "give_up": 7.5, "follow_gap": 2.0}, "animated": true},
	{"id": "sloth", "name": "树懒", "scene": "res://resources/animals/iceage/Sloth.fbx", "height": 1.5, "radius": 0.55, "speed": 0.8, "texture": "embedded", "behavior": "wander", "animated": true},
	# --- clip-less wild pack: procedural movement, atlas-colored ---
	{"id": "bear", "name": "棕熊", "scene": WILD_DIR + "bear.fbx", "height": 1.35, "radius": 0.55, "speed": 1.4, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "boar", "name": "野猪", "scene": WILD_DIR + "boar.fbx", "height": 0.85, "radius": 0.40, "speed": 1.7, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "fox", "name": "狐狸", "scene": WILD_DIR + "fox.fbx", "height": 0.60, "radius": 0.26, "speed": 2.0, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "hedgehog", "name": "刺猬", "scene": WILD_DIR + "hedhog.fbx", "height": 0.40, "radius": 0.22, "speed": 1.1, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "owl", "name": "猫头鹰", "scene": WILD_DIR + "owl.fbx", "height": 0.70, "radius": 0.30, "speed": 1.2, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "rabbit", "name": "兔子", "scene": WILD_DIR + "rabbit.fbx", "height": 0.52, "radius": 0.26, "speed": 2.1, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "squirrel", "name": "松鼠", "scene": WILD_DIR + "squirrel.fbx", "height": 0.38, "radius": 0.18, "speed": 2.0, "texture": "atlas", "behavior": "wander", "animated": false},
	{"id": "wolf", "name": "灰狼", "scene": WILD_DIR + "wolf.fbx", "height": 1.20, "radius": 0.40, "speed": 1.9, "texture": "atlas", "behavior": "wander", "animated": false},
]


static func species_by_id(species_id: String) -> Dictionary:
	for entry in SPECIES:
		if String(entry.get("id", "")) == species_id:
			return entry
	return {}


## Picks `count` species, prioritising animated ones (deer first, then ice-age),
## then filling the rest with shuffled clip-less wild animals. Sampling repeats
## with cycling if more animals are requested than there are species.
static func random_species(rng: RandomNumberGenerator, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0 or SPECIES.is_empty():
		return result
	var prioritized: Array[Dictionary] = []
	var fillers: Array[Dictionary] = []
	for entry in SPECIES:
		if bool(entry.get("animated", false)):
			prioritized.append(entry)
		else:
			fillers.append(entry)
	_shuffle(fillers, rng)
	var ordered: Array[Dictionary] = prioritized + fillers
	var index: int = 0
	while result.size() < count:
		result.append(ordered[index % ordered.size()])
		index += 1
	return result


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
