extends RefCounted
class_name PlayerNameGenerator

# Generates fun prop-hunt themed display names for the player profile / dice button.
# Chinese vs English output follows the active game language so the rolled name
# matches what the player reads. Pure data + randi(); no scene/IO dependencies.

const CN_PREFIXES: Array[String] = [
	"暗影", "迅捷", "潜行", "隐秘", "暗夜", "神秘", "狡猾", "无声", "疾风", "幽灵",
	"伪装", "寂静", "灵巧", "诡秘", "飞掠", "静默", "鬼魅", "藏匿", "夜行", "猎影",
]
const CN_NOUNS: Array[String] = [
	"猎手", "变色龙", "潜行者", "幽灵", "刺客", "行者", "猎人", "影子", "伏击者",
	"守望者", "追踪者", "拟态师", "隐者", "夜枭", "游侠", "幻影",
]

const EN_ADJECTIVES: Array[String] = [
	"Shadow", "Swift", "Sneaky", "Silent", "Hidden", "Mystic", "Crafty", "Phantom",
	"Sly", "Ghostly", "Nimble", "Cunning", "Lurking", "Veiled", "Stealthy", "Wily",
	"Dusky", "Elusive", "Hushed", "Prowling",
]
const EN_NOUNS: Array[String] = [
	"Hunter", "Chameleon", "Stalker", "Ghost", "Phantom", "Prowler", "Shade", "Mimic",
	"Watcher", "Tracker", "Lurker", "Specter", "Sneak", "Rogue", "Owl", "Ranger",
]


# Returns a random themed name. When chinese is true, returns a Chinese name,
# otherwise an English one.
static func random_name(chinese: bool) -> String:
	if chinese:
		return _pick(CN_PREFIXES) + _pick(CN_NOUNS)
	# English names append a small number ~50% of the time for uniqueness.
	var base := _pick(EN_ADJECTIVES) + _pick(EN_NOUNS)
	if randi() % 2 == 0:
		base += str(randi() % 90 + 10)
	return base


static func _pick(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
