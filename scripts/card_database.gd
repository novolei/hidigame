extends RefCounted
class_name CardDatabase

const TEAM_PROP := "prop"
const TEAM_HUNTER := "hunter"

const CATEGORY_ACTIVE := "active"
const CATEGORY_DEFENSE := "defense"
const CATEGORY_PASSIVE := "passive"
const CATEGORY_TRACKING := "tracking"
const CATEGORY_CONTROL := "control"
const CATEGORY_RESOURCE := "resource"

const ACTIVATION_MANUAL := "manual"
const ACTIVATION_REACTIVE := "reactive"

const CARDS := {
	"prop_chromatic_burst": {
		"team": TEAM_PROP,
		"code": "A1",
		"name": "Chromatic Burst",
		"name_zh": "瞬间隐形",
		"category": CATEGORY_ACTIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 1.0,
		"summary": "1 秒内自动全身隐形, 但仍保留脚步声。",
		"icon": "stealth",
	},
	"prop_micro_form": {
		"team": TEAM_PROP,
		"code": "A2",
		"name": "Micro Form",
		"name_zh": "强化变小",
		"category": CATEGORY_ACTIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 15.0,
		"summary": "身体比例临时缩小到 0.25 倍, 到时间恢复。",
		"icon": "shape",
	},
	"prop_flashbang": {
		"team": TEAM_PROP,
		"code": "A3",
		"name": "Flashbang",
		"name_zh": "闪光弹",
		"category": CATEGORY_ACTIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 5.0,
		"radius": 10.0,
		"summary": "10m 内 Hunter 视野短暂白屏, 对 Prop 不影响。",
		"icon": "flashlight",
	},
	"prop_decoy_echo": {
		"team": TEAM_PROP,
		"code": "A4",
		"name": "Decoy Echo",
		"name_zh": "诱饵残影",
		"category": CATEGORY_ACTIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 15.0,
		"summary": "原地留下可被攻击的静止虚像。",
		"icon": "detect",
	},
	"prop_portal_step": {
		"team": TEAM_PROP,
		"code": "A5",
		"name": "Portal Step",
		"name_zh": "移行换位",
		"category": CATEGORY_ACTIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 0.0,
		"summary": "瞬移到 40-50m 内随机坐标, 并留下粒子残影。",
		"icon": "blink",
	},
	"prop_static_aura": {
		"team": TEAM_PROP,
		"code": "D1",
		"name": "Static Aura",
		"name_zh": "静止力场",
		"category": CATEGORY_DEFENSE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"radius": 8.0,
		"summary": "8m 范围内所有 Props 免疫伤害。",
		"icon": "camo",
	},
	"prop_emergency_conceal": {
		"team": TEAM_PROP,
		"code": "D2",
		"name": "Emergency Conceal",
		"name_zh": "时之砂",
		"category": CATEGORY_DEFENSE,
		"activation": ACTIVATION_REACTIVE,
		"duration": 5.0,
		"summary": "受到致命伤或生命值低于 5% 时自动石化 5 秒并恢复 65% 生命值。",
		"icon": "locked",
	},
	"prop_paint_bomb": {
		"team": TEAM_PROP,
		"code": "D3",
		"name": "Paint Bomb",
		"name_zh": "涂装炸弹",
		"category": CATEGORY_DEFENSE,
		"activation": ACTIVATION_MANUAL,
		"duration": 5.0,
		"radius": 20.0,
		"summary": "20m 内 Hunter 视野变模糊。",
		"icon": "camo",
	},
	"prop_time_stop": {
		"team": TEAM_PROP,
		"code": "D4",
		"name": "Time Stop",
		"name_zh": "时间静止",
		"category": CATEGORY_DEFENSE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"radius": 10.0,
		"summary": "10m 内 Hunter 时间减半, 移速 -50%。",
		"icon": "locked",
	},
	"prop_mist_clones": {
		"team": TEAM_PROP,
		"code": "D5",
		"name": "Mist Clones",
		"name_zh": "雾隐分身",
		"category": CATEGORY_DEFENSE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"summary": "生成 2 个跟随虚像, 自动机枪优先锁定虚像。",
		"icon": "stealth",
	},
	"prop_sense": {
		"team": TEAM_PROP,
		"code": "P1",
		"name": "Sense",
		"name_zh": "远程遥感",
		"category": CATEGORY_PASSIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"summary": "视野内可见 Hunter 立刻缩小至 50%。",
		"icon": "detect",
	},
	"prop_empty_bullet": {
		"team": TEAM_PROP,
		"code": "P2",
		"name": "Empty Bullet",
		"name_zh": "子弹清空",
		"category": CATEGORY_PASSIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"summary": "Hunter AK 与自动炮塔弹药/热量资源瞬间清空。",
		"icon": "locked",
	},
	"prop_silent_steps": {
		"team": TEAM_PROP,
		"code": "P3",
		"name": "Silent Steps",
		"name_zh": "无声步伐",
		"category": CATEGORY_PASSIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 18.0,
		"summary": "移动完全无脚步声, 喷涂声不受影响。",
		"icon": "sprint",
	},
	"prop_extreme_immunity": {
		"team": TEAM_PROP,
		"code": "P4",
		"name": "Extreme Immunity",
		"name_zh": "极度免疫",
		"category": CATEGORY_PASSIVE,
		"activation": ACTIVATION_MANUAL,
		"duration": 25.0,
		"summary": "短时间免疫 Hunter 伤害和控制技能。",
		"icon": "camo",
	},
	"prop_revival": {
		"team": TEAM_PROP,
		"code": "P5",
		"name": "Revival Card",
		"name_zh": "复活卡",
		"category": CATEGORY_PASSIVE,
		"activation": ACTIVATION_REACTIVE,
		"duration": 5.0,
		"summary": "被 Hunter 击杀后 5 秒自动复活到 Hunter 视野之外的随机位置。",
		"icon": "locked",
	},
	"hunter_pulse_scan": {
		"team": TEAM_HUNTER,
		"code": "H1",
		"name": "Pulse Scan",
		"name_zh": "脉冲扫描",
		"category": CATEGORY_TRACKING,
		"activation": ACTIVATION_MANUAL,
		"duration": 6.0,
		"radius": 24.0,
		"summary": "24m 范围内所有 Prop 产生轮廓/音频提示。",
		"icon": "detect",
	},
	"hunter_blacklight": {
		"team": TEAM_HUNTER,
		"code": "H2",
		"name": "Blacklight",
		"name_zh": "黑光显影",
		"category": CATEGORY_TRACKING,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"radius": 18.0,
		"summary": "18m 内喷涂/隐身痕迹显形, 克制 Chameleon 和 Stalker。",
		"icon": "flashlight",
	},
	"hunter_overclock_rounds": {
		"team": TEAM_HUNTER,
		"code": "H3",
		"name": "Overclock Rounds",
		"name_zh": "超频弹匣",
		"category": CATEGORY_RESOURCE,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"summary": "立即补充一组弹药并短时间维持压制节奏。",
		"icon": "sprint",
	},
	"hunter_gravity_net": {
		"team": TEAM_HUNTER,
		"code": "H4",
		"name": "Gravity Net",
		"name_zh": "重力网",
		"category": CATEGORY_CONTROL,
		"activation": ACTIVATION_MANUAL,
		"duration": 8.0,
		"radius": 10.0,
		"summary": "10m 内 Prop 移速 -45%。",
		"icon": "locked",
	},
	"hunter_echo_marker": {
		"team": TEAM_HUNTER,
		"code": "H5",
		"name": "Echo Marker",
		"name_zh": "回声标记",
		"category": CATEGORY_TRACKING,
		"activation": ACTIVATION_MANUAL,
		"duration": 5.0,
		"radius": 35.0,
		"summary": "标记 35m 内最近的 Prop 最后位置。",
		"icon": "detect",
	},
	"hunter_light_cage": {
		"team": TEAM_HUNTER,
		"code": "H6",
		"name": "Light Cage",
		"name_zh": "光牢",
		"category": CATEGORY_CONTROL,
		"activation": ACTIVATION_MANUAL,
		"duration": 7.0,
		"radius": 12.0,
		"summary": "12m 内 Prop 隐身/阴影收益失效并减速。",
		"icon": "flashlight",
	},
	"hunter_turret_overdrive": {
		"team": TEAM_HUNTER,
		"code": "H7",
		"name": "Turret Overdrive",
		"name_zh": "炮塔过载",
		"category": CATEGORY_RESOURCE,
		"activation": ACTIVATION_MANUAL,
		"duration": 10.0,
		"summary": "重置自动炮塔过热并短时间强化锁定压力。",
		"icon": "locked",
	},
	"hunter_ammo_cache": {
		"team": TEAM_HUNTER,
		"code": "H8",
		"name": "Ammo Cache",
		"name_zh": "补给缓存",
		"category": CATEGORY_RESOURCE,
		"activation": ACTIVATION_MANUAL,
		"duration": 0.0,
		"summary": "立即补满当前 AK 弹药储备。",
		"icon": "locked",
	},
	"hunter_adrenaline": {
		"team": TEAM_HUNTER,
		"code": "H9",
		"name": "Adrenaline",
		"name_zh": "肾上腺素",
		"category": CATEGORY_CONTROL,
		"activation": ACTIVATION_MANUAL,
		"duration": 6.0,
		"summary": "6 秒内移速 +45%, 用于追击或重新占位。",
		"icon": "sprint",
	},
	"hunter_signal_jammer": {
		"team": TEAM_HUNTER,
		"code": "H10",
		"name": "Signal Jammer",
		"name_zh": "信号干扰",
		"category": CATEGORY_CONTROL,
		"activation": ACTIVATION_MANUAL,
		"duration": 6.0,
		"radius": 14.0,
		"summary": "14m 内 Prop 新卡牌发动失败, 已激活效果不被驱散。",
		"icon": "locked",
	},
}

const PROP_POOL := [
	"prop_chromatic_burst",
	"prop_micro_form",
	"prop_flashbang",
	"prop_decoy_echo",
	"prop_portal_step",
	"prop_static_aura",
	"prop_emergency_conceal",
	"prop_paint_bomb",
	"prop_time_stop",
	"prop_mist_clones",
	"prop_sense",
	"prop_empty_bullet",
	"prop_silent_steps",
	"prop_extreme_immunity",
	"prop_revival",
]

const HUNTER_POOL := [
	"hunter_pulse_scan",
	"hunter_blacklight",
	"hunter_overclock_rounds",
	"hunter_gravity_net",
	"hunter_echo_marker",
	"hunter_light_cage",
	"hunter_turret_overdrive",
	"hunter_ammo_cache",
	"hunter_adrenaline",
	"hunter_signal_jammer",
]

const LOCALIZATION := {
	"prop_chromatic_burst": {
		"name_zh": "瞬间隐形",
		"name_en": "Chromatic Burst",
		"description_zh": "1秒内自动全身隐形，但移动脚步声仍会保留。",
		"description_en": "Automatically turns fully invisible for 1 second while footstep audio remains audible.",
	},
	"prop_micro_form": {
		"name_zh": "强化变小",
		"name_en": "Micro Form",
		"description_zh": "将身体比例临时缩小至原来的0.25倍，15秒后恢复。",
		"description_en": "Temporarily shrinks the body to 25% of its original scale for 15 seconds.",
	},
	"prop_flashbang": {
		"name_zh": "闪光弹",
		"name_en": "Flashbang",
		"description_zh": "使10米范围内的Hunter短暂白屏5秒，对Prop无影响。",
		"description_en": "Blinds Hunters within 10 meters for 5 seconds without affecting Props.",
	},
	"prop_decoy_echo": {
		"name_zh": "诱饵残影",
		"name_en": "Decoy Echo",
		"description_zh": "在原地留下一个可被攻击的静止虚像，持续15秒。",
		"description_en": "Leaves a stationary attackable afterimage at the current position for 15 seconds.",
	},
	"prop_portal_step": {
		"name_zh": "移行换位",
		"name_en": "Portal Step",
		"description_zh": "瞬移到地图40-50米内的随机落点，并留下粒子残影。",
		"description_en": "Teleports to a random nearby map position 40-50 meters away and leaves a particle echo.",
	},
	"prop_static_aura": {
		"name_zh": "静止力场",
		"name_en": "Static Aura",
		"description_zh": "8米范围内所有Prop获得伤害免疫，持续8秒。",
		"description_en": "Grants damage immunity to all Props within 8 meters for 8 seconds.",
	},
	"prop_emergency_conceal": {
		"name_zh": "时之砂",
		"name_en": "Emergency Conceal",
		"description_zh": "受到致命伤或生命值低于5%时自动触发，变成静态石头5秒并恢复至65%生命值。",
		"description_en": "Auto-triggers on lethal damage or below 5% health, becoming a static stone for 5 seconds and recovering to 65% health.",
	},
	"prop_paint_bomb": {
		"name_zh": "涂装炸弹",
		"name_en": "Paint Bomb",
		"description_zh": "使20米范围内Hunter视野模糊5秒。",
		"description_en": "Blurs the vision of Hunters within 20 meters for 5 seconds.",
	},
	"prop_time_stop": {
		"name_zh": "时间静止",
		"name_en": "Time Stop",
		"description_zh": "10米范围内Hunter移速降低50%，持续8秒。",
		"description_en": "Reduces Hunter movement speed by 50% within 10 meters for 8 seconds.",
	},
	"prop_mist_clones": {
		"name_zh": "雾隐分身",
		"name_en": "Mist Clones",
		"description_zh": "生成2个跟随移动的虚像，自动机枪会优先锁定虚像，持续8秒。",
		"description_en": "Creates 2 moving clones for 8 seconds; automatic turrets prioritize the clones.",
	},
	"prop_sense": {
		"name_zh": "远程遥感",
		"name_en": "Sense",
		"description_zh": "视野内可见Hunter会被短暂缩小至50%，持续8秒。",
		"description_en": "Visible Hunters in sight are temporarily shrunk to 50% scale for 8 seconds.",
	},
	"prop_empty_bullet": {
		"name_zh": "子弹清空",
		"name_en": "Empty Bullet",
		"description_zh": "清空Hunter的AK武器弹药和自动炮塔弹药资源。",
		"description_en": "Empties Hunter AK ammunition and automatic turret ammunition resources.",
	},
	"prop_silent_steps": {
		"name_zh": "无声步伐",
		"name_en": "Silent Steps",
		"description_zh": "移动完全无脚步声，喷涂声除外，持续18秒。",
		"description_en": "Removes movement footstep audio for 18 seconds, excluding spray sounds.",
	},
	"prop_extreme_immunity": {
		"name_zh": "极度免疫",
		"name_en": "Extreme Immunity",
		"description_zh": "免疫Hunter伤害和控制技能，持续25秒。",
		"description_en": "Grants immunity to Hunter damage and control effects for 25 seconds.",
	},
	"prop_revival": {
		"name_zh": "复活卡",
		"name_en": "Revival Card",
		"description_zh": "被Hunter击杀后5秒自动复活到Hunter视野之外的随机位置。",
		"description_en": "After being killed by a Hunter, automatically revives 5 seconds later at a random position outside Hunter sight.",
	},
	"hunter_pulse_scan": {
		"name_zh": "脉冲扫描",
		"name_en": "Pulse Scan",
		"description_zh": "侦测24米范围内Prop轮廓和音频提示，持续6秒。",
		"description_en": "Reveals Prop silhouettes and audio hints within 24 meters for 6 seconds.",
	},
	"hunter_blacklight": {
		"name_zh": "黑光显影",
		"name_en": "Blacklight",
		"description_zh": "显现18米范围内喷涂、隐身和阴影痕迹，持续8秒。",
		"description_en": "Reveals paint, invisibility, and shadow traces within 18 meters for 8 seconds.",
	},
	"hunter_overclock_rounds": {
		"name_zh": "超频弹匣",
		"name_en": "Overclock Rounds",
		"description_zh": "立即补充一组AK弹药，并短暂维持压制节奏8秒。",
		"description_en": "Instantly refills a burst of AK ammunition and sustains pressure for 8 seconds.",
	},
	"hunter_gravity_net": {
		"name_zh": "重力网",
		"name_en": "Gravity Net",
		"description_zh": "使10米范围内Prop移速降低45%，持续8秒。",
		"description_en": "Slows Props within 10 meters by 45% for 8 seconds.",
	},
	"hunter_echo_marker": {
		"name_zh": "回声标记",
		"name_en": "Echo Marker",
		"description_zh": "标记35米范围内最近Prop的最后位置，持续5秒。",
		"description_en": "Marks the last known position of the nearest Prop within 35 meters for 5 seconds.",
	},
	"hunter_light_cage": {
		"name_zh": "光牢",
		"name_en": "Light Cage",
		"description_zh": "使12米范围内Prop隐身和阴影收益失效并减速，持续7秒。",
		"description_en": "Suppresses Prop invisibility and shadow benefits within 12 meters and slows them for 7 seconds.",
	},
	"hunter_turret_overdrive": {
		"name_zh": "炮塔过载",
		"name_en": "Turret Overdrive",
		"description_zh": "重置自动炮塔过热并强化锁定压力，持续10秒。",
		"description_en": "Resets automatic turret overheat and increases targeting pressure for 10 seconds.",
	},
	"hunter_ammo_cache": {
		"name_zh": "补给缓存",
		"name_en": "Ammo Cache",
		"description_zh": "立即将当前AK弹药补充到上限。",
		"description_en": "Instantly refills the current AK ammunition reserve to its cap.",
	},
	"hunter_adrenaline": {
		"name_zh": "肾上腺素",
		"name_en": "Adrenaline",
		"description_zh": "Hunter移速提升45%，持续6秒，用于追击或重新占位。",
		"description_en": "Increases Hunter movement speed by 45% for 6 seconds for pursuit or repositioning.",
	},
	"hunter_signal_jammer": {
		"name_zh": "信号干扰",
		"name_en": "Signal Jammer",
		"description_zh": "干扰14米范围内Prop新卡牌发动，已激活效果不会被驱散，持续6秒。",
		"description_en": "Disrupts new Prop card activations within 14 meters for 6 seconds without dispelling existing effects.",
	},
}


static func get_card(card_id: String) -> Dictionary:
	return (CARDS.get(card_id, {}) as Dictionary).duplicate(true)


static func get_localized(card_id: String) -> Dictionary:
	var fallback := get_card(card_id)
	var localized := (LOCALIZATION.get(card_id, {}) as Dictionary).duplicate(true)
	if localized.is_empty():
		localized = {
			"name_zh": str(fallback.get("name_zh", card_id)),
			"name_en": str(fallback.get("name", card_id)),
			"description_zh": str(fallback.get("summary", "")),
			"description_en": str(fallback.get("summary", "")),
		}
	localized["code"] = str(fallback.get("code", ""))
	localized["category"] = str(fallback.get("category", "card"))
	localized["activation"] = str(fallback.get("activation", ACTIVATION_MANUAL))
	localized["duration"] = float(fallback.get("duration", 0.0))
	localized["radius"] = float(fallback.get("radius", 0.0))
	localized["team"] = str(fallback.get("team", ""))
	return localized


static func get_current_locale() -> String:
	return str(I18n.current_locale) if I18n else "en"


static func is_zh_locale(locale: String = "") -> bool:
	var resolved := get_current_locale() if locale.is_empty() else locale
	return resolved.to_lower().begins_with("zh")


static func display_name_for_locale(card_id: String, locale: String = "") -> String:
	var localized := get_localized(card_id)
	return str(localized.get("name_zh", card_id)) if is_zh_locale(locale) else str(localized.get("name_en", card_id))


static func description_for_locale(card_id: String, locale: String = "") -> String:
	var localized := get_localized(card_id)
	return str(localized.get("description_zh", "")) if is_zh_locale(locale) else str(localized.get("description_en", ""))


static func has_card(card_id: String) -> bool:
	return CARDS.has(card_id)


static func is_manual(card_id: String) -> bool:
	return str(get_card(card_id).get("activation", ACTIVATION_MANUAL)) == ACTIVATION_MANUAL


static func display_name(card_id: String) -> String:
	return display_name_for_locale(card_id)


static func get_pool_for_role(role: int) -> Array:
	if role == 2:
		return HUNTER_POOL.duplicate()
	return PROP_POOL.duplicate()


static func random_choices_for_role(role: int, count: int, excluded: Array, rng: RandomNumberGenerator) -> Array:
	var pool := get_pool_for_role(role)
	var candidates: Array = []
	for card_id in pool:
		if not excluded.has(card_id):
			candidates.append(card_id)
	var choices: Array = []
	while not candidates.is_empty() and choices.size() < count:
		var index := rng.randi_range(0, candidates.size() - 1)
		choices.append(candidates[index])
		candidates.remove_at(index)
	return choices
