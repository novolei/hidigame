extends Node

signal locale_changed(locale: String)

const CONFIG_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["en", "zh"]

var current_locale := "en"
var language_setting := "auto"

var _translations := {
	"en": {
		"app.title": "PHANTOM HUNT",
		"app.subtitle": "PRIVATE MATCH",
		"settings": "SETTINGS",
		"language": "LANGUAGE",
		"language.auto": "AUTO",
		"language.en": "ENGLISH",
		"language.zh": "SIMPLIFIED CHINESE",
		"player_setup": "PLAYER SETUP",
		"room_setup": "ROOM ACCESS",
		"nickname": "NICKNAME",
		"skin": "SKIN",
		"server_ip": "SERVER IP",
		"room_name": "ROOM NAME",
		"join_target": "HOST / ROOM",
		"lobby_password": "LOBBY ID / PASSWORD",
		"lobby_id": "LOBBY ID",
		"host_lobby": "HOST LOBBY",
		"join_lobby": "JOIN LOBBY",
		"quit": "QUIT",
		"match_details": "MATCH DETAILS",
		"private_match": "PRIVATE MATCH",
		"copy": "COPY",
		"start_match": "START MATCH",
		"start_match_count": "START EARLY %d/%d",
		"players_needed": "AT LEAST 2 PLAYERS NEEDED TO START MATCH",
		"teams_ready": "READY WHEN TEAMS ARE ASSIGNED",
		"level": "ARENA",
		"variant": "VARIANT",
		"condition": "CONDITION",
		"game_show": "GAME SHOW",
		"duration": "ROUND TIME",
		"hunter_count": "HUNTERS",
		"hide_prep": "HIDE PREP",
		"auto_assign": "AUTO ASSIGN TEAMS",
		"choose_side": "CHOOSE SIDE",
		"unassigned": "UNASSIGNED PLAYER(S)",
		"spectators": "SPECTATORS",
		"team.chameleon": "HIDERS",
		"team.stalker": "STALKERS",
		"team.hunter": "HUNTERS",
		"role.chameleon": "HIDER",
		"role.stalker": "STALKER",
		"role.hunter": "HUNTER",
		"back": "BACK",
		"close": "CLOSE",
		"chat": "CHAT",
		"chat.scope_lobby": "LOBBY",
		"chat.placeholder": "Type message",
		"manage_lobby": "MANAGE LOBBY",
		"leave_lobby": "LEAVE LOBBY",
		"placeholder.nick": "Player",
		"placeholder.skin": "blue / yellow / green / red",
		"placeholder.room_name": "Bili's Room",
		"placeholder.ip": "127.0.0.1",
		"placeholder.join_target": "127.0.0.1 or room name",
		"placeholder.lobby": "Lobby ID / password",
		"join_status.need_target": "Enter a host address or room name.",
		"join_status.need_password": "Enter the Lobby ID / password.",
		"join_status.ready_address": "Direct host address ready.",
		"join_status.ready_room": "Room name ready for Steam lobby lookup; local dev falls back to localhost.",
		"join_status.connecting": "Connecting...",
		"steam_status.ready": "STEAM LOBBY ENABLED",
		"steam_status.offline": "STEAM OFFLINE: DIRECT HOST / LOCAL TEST MODE",
		"phase": "PHASE",
		"role": "ROLE",
		"players": "PLAYERS",
		"prep_remaining": "HIDE PREP",
		"match_remaining": "MATCH",
		"health": "HEALTH",
		"ammo": "AMMO",
		"phase.LOBBY": "LOBBY",
		"phase.PREP": "PREP",
		"phase.PLAY": "PLAY",
		"phase.END": "END",
		"option.map.Warehouse": "WAREHOUSE",
		"option.map.Street Block": "STREET BLOCK",
		"option.map.Training Yard": "TRAINING YARD",
		"option.variant.Default": "STANDARD",
		"option.variant.Low Ammo": "LOW AMMO",
		"option.variant.Fast Hunt": "FAST HUNT",
		"option.condition.Normal": "ANY",
		"option.condition.Rain": "RAIN",
		"option.condition.Night": "NIGHT",
		"option.game_show.None": "NONE",
		"option.game_show.Airdrop Show": "AIRDROP SHOW",
		"option.game_show.Chaos Show": "CHAOS SHOW",
		"option.duration.300": "5 MIN",
		"option.duration.600": "10 MIN",
		"option.duration.900": "15 MIN",
		"option.prep.30": "30 SEC",
		"option.prep.60": "60 SEC",
		"option.prep.120": "120 SEC",
		"option.hunters.-1": "AUTO",
		"option.hunters.1": "1 HUNTER",
		"option.hunters.2": "2 HUNTERS",
		"option.hunters.3": "3 HUNTERS",
		"option.hunters.4": "4 HUNTERS",
		"option.hunters.5": "5 HUNTERS",
		"option.hunters.6": "6 HUNTERS",
		"option.hunters.7": "7 HUNTERS",
		"option.hunters.8": "8 HUNTERS",
	},
	"zh": {
		"app.title": "幻影猎场",
		"app.subtitle": "私人比赛",
		"settings": "设置",
		"language": "语言",
		"language.auto": "自动",
		"language.en": "英语",
		"language.zh": "简体中文",
		"player_setup": "玩家设置",
		"room_setup": "房间连接",
		"nickname": "昵称",
		"skin": "外观",
		"server_ip": "服务器 IP",
		"room_name": "房间名",
		"join_target": "HOST / 房间",
		"lobby_password": "LOBBY ID / 密码",
		"lobby_id": "房间 ID",
		"host_lobby": "创建房间",
		"join_lobby": "加入房间",
		"quit": "退出",
		"match_details": "比赛详情",
		"private_match": "私人比赛",
		"copy": "复制",
		"start_match": "开始比赛",
		"start_match_count": "提前开始 %d/%d",
		"players_needed": "至少需要 2 名玩家才能开始比赛",
		"teams_ready": "队伍分配完成后即可开始",
		"level": "竞技场",
		"variant": "变体",
		"condition": "条件",
		"game_show": "节目事件",
		"duration": "回合时长",
		"hunter_count": "猎手数量",
		"hide_prep": "躲藏准备",
		"auto_assign": "自动分配队伍",
		"choose_side": "选择阵营",
		"unassigned": "未分配玩家",
		"spectators": "观战席",
		"team.chameleon": "藏匿者",
		"team.stalker": "潜行者",
		"team.hunter": "猎人",
		"role.chameleon": "藏匿者",
		"role.stalker": "潜行者",
		"role.hunter": "猎人",
		"back": "返回",
		"close": "关闭",
		"chat": "聊天",
		"chat.scope_lobby": "大厅",
		"chat.placeholder": "输入消息",
		"manage_lobby": "管理房间",
		"leave_lobby": "离开房间",
		"placeholder.nick": "玩家",
		"placeholder.skin": "blue / yellow / green / red",
		"placeholder.room_name": "Bili 的房间",
		"placeholder.ip": "127.0.0.1",
		"placeholder.join_target": "127.0.0.1 或房间名",
		"placeholder.lobby": "Lobby ID / 密码",
		"join_status.need_target": "请输入 Host 地址或房间名。",
		"join_status.need_password": "请输入 Lobby ID / 密码。",
		"join_status.ready_address": "Host 地址已就绪。",
		"join_status.ready_room": "房间名已就绪；当前本地开发模式会回退连接 localhost。",
		"join_status.connecting": "正在连接...",
		"steam_status.ready": "STEAM LOBBY 已启用",
		"steam_status.offline": "STEAM 离线：直连 / 本地测试模式",
		"phase": "阶段",
		"role": "角色",
		"players": "玩家",
		"prep_remaining": "躲藏准备",
		"match_remaining": "比赛剩余",
		"health": "生命",
		"ammo": "弹药",
		"phase.LOBBY": "大厅",
		"phase.PREP": "准备",
		"phase.PLAY": "比赛",
		"phase.END": "结算",
		"option.map.Warehouse": "仓库",
		"option.map.Street Block": "街区",
		"option.map.Training Yard": "训练场",
		"option.variant.Default": "标准",
		"option.variant.Low Ammo": "低弹药",
		"option.variant.Fast Hunt": "快速猎捕",
		"option.condition.Normal": "任意",
		"option.condition.Rain": "雨天",
		"option.condition.Night": "夜晚",
		"option.game_show.None": "无",
		"option.game_show.Airdrop Show": "空投秀",
		"option.game_show.Chaos Show": "混乱秀",
		"option.duration.300": "5 分钟",
		"option.duration.600": "10 分钟",
		"option.duration.900": "15 分钟",
		"option.prep.30": "30 秒",
		"option.prep.60": "60 秒",
		"option.prep.120": "120 秒",
		"option.hunters.-1": "自动",
		"option.hunters.1": "1 名猎手",
		"option.hunters.2": "2 名猎手",
		"option.hunters.3": "3 名猎手",
		"option.hunters.4": "4 名猎手",
		"option.hunters.5": "5 名猎手",
		"option.hunters.6": "6 名猎手",
		"option.hunters.7": "7 名猎手",
		"option.hunters.8": "8 名猎手",
	}
}


func _ready() -> void:
	_load_language_setting()


func t(key: String) -> String:
	var table: Dictionary = _translations.get(current_locale, _translations["en"])
	if table.has(key):
		return table[key]
	return _translations["en"].get(key, key)


func tf(key: String, values: Array) -> String:
	return t(key) % values


func option_text(group: String, value) -> String:
	return t("option.%s.%s" % [group, str(value)])


func set_language_setting(value: String) -> void:
	if value != "auto" and not SUPPORTED_LOCALES.has(value):
		value = "auto"
	language_setting = value
	var resolved := _resolve_locale(value)
	if resolved != current_locale:
		current_locale = resolved
		_save_language_setting()
		locale_changed.emit(current_locale)
	else:
		_save_language_setting()


func get_language_choices() -> Array:
	return [
		{"value": "auto", "label": t("language.auto")},
		{"value": "en", "label": t("language.en")},
		{"value": "zh", "label": t("language.zh")},
	]


func _load_language_setting() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		language_setting = str(config.get_value("game", "language", "auto"))
	current_locale = _resolve_locale(language_setting)


func _save_language_setting() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "language", language_setting)
	config.save(CONFIG_PATH)


func _resolve_locale(setting: String) -> String:
	if setting != "auto":
		return setting
	var os_lang := OS.get_locale_language().to_lower()
	if os_lang.begins_with("zh"):
		return "zh"
	return "en"
