extends Node

signal availability_changed(available: bool, message: String)
signal lobby_created(success: bool, lobby_id: String, message: String)
signal lobby_lookup_completed(found: bool, address: String, room_name: String, lobby_password: String, steam_lobby_id: String, message: String, host_port: int)

const DEFAULT_LOBBY_TYPE_PUBLIC := 2
const DEFAULT_LOBBY_MEMBER_LIMIT := 24

var available := false
var initialized := false
var persona_name := ""
var steam_id := ""
var current_lobby_id := ""
var pending_host_data := {}
var pending_lookup := {}

var _steam: Object


func _ready() -> void:
	_initialize()


func _process(_delta: float) -> void:
	if available and _steam and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


func is_available() -> bool:
	return available


func can_use_lobbies() -> bool:
	return available and _steam and _steam.has_method("createLobby") and _steam.has_method("requestLobbyList")


func create_lobby(room_name: String, lobby_password: String, host_address: String, max_players: int = DEFAULT_LOBBY_MEMBER_LIMIT, host_port: int = -1) -> bool:
	if not can_use_lobbies():
		lobby_created.emit(false, "", "Steam is unavailable; using direct host mode.")
		return false
	pending_host_data = {
		"room_name": room_name,
		"lobby_password": lobby_password,
		"host_address": host_address,
		"host_port": host_port if host_port > 0 else Network.server_port,
		"max_players": max_players,
	}
	_steam.call("createLobby", DEFAULT_LOBBY_TYPE_PUBLIC, max_players)
	return true


func find_lobby(room_name: String, lobby_password: String) -> bool:
	if not can_use_lobbies():
		lobby_lookup_completed.emit(false, "", room_name, lobby_password, "", "Steam is unavailable; using direct host mode.", -1)
		return false
	pending_lookup = {
		"room_name": room_name.strip_edges(),
		"lobby_password": lobby_password.strip_edges().to_upper(),
	}
	_steam.call("requestLobbyList")
	return true


func join_lobby(steam_lobby_id: String) -> void:
	if available and _steam and _steam.has_method("joinLobby") and not steam_lobby_id.is_empty():
		_steam.call("joinLobby", int(steam_lobby_id))


func _initialize() -> void:
	if not Engine.has_singleton("Steam"):
		_set_availability(false, "GodotSteam extension is not loaded.")
		return
	_steam = Engine.get_singleton("Steam")
	_connect_steam_signals()

	var init_ok := true
	var init_message := "Steam initialized."
	if _steam.has_method("steamInit"):
		var result = _steam.call("steamInit")
		init_ok = _steam_init_succeeded(result)
		init_message = "Steam init result: %s" % str(result)
	initialized = init_ok
	if init_ok:
		persona_name = _get_persona_name()
		steam_id = _get_steam_id()
	_set_availability(init_ok, init_message)


func _connect_steam_signals() -> void:
	_connect_signal_if_present("lobby_created", _on_lobby_created)
	_connect_signal_if_present("lobby_joined", _on_lobby_joined)
	_connect_signal_if_present("lobby_match_list", _on_lobby_match_list)
	_connect_signal_if_present("join_requested", _on_join_requested)


func _connect_signal_if_present(signal_name: String, method: Callable) -> void:
	if _steam and _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, method):
		_steam.connect(signal_name, method)


func _on_lobby_created(connect_result, lobby_id) -> void:
	var success := int(connect_result) == 1
	current_lobby_id = str(lobby_id) if success else ""
	if success:
		_set_current_lobby_data()
	lobby_created.emit(success, current_lobby_id, "Steam lobby created." if success else "Steam lobby creation failed.")


func _on_lobby_joined(lobby_id, _permissions = 0, _locked = false, response = 1) -> void:
	var success := int(response) == 1
	if success:
		current_lobby_id = str(lobby_id)


func _on_join_requested(lobby_id, _friend_id = 0) -> void:
	if lobby_id:
		join_lobby(str(lobby_id))


func _on_lobby_match_list(lobbies) -> void:
	if pending_lookup.is_empty():
		return
	var wanted_room := str(pending_lookup.get("room_name", "")).strip_edges().to_lower()
	var wanted_password := str(pending_lookup.get("lobby_password", "")).strip_edges().to_upper()
	var lobby_ids := _normalize_lobby_list(lobbies)
	for lobby_id in lobby_ids:
		var room_name := _get_lobby_data(lobby_id, "room_name")
		var password := _get_lobby_data(lobby_id, "lobby_id")
		if room_name.strip_edges().to_lower() == wanted_room and password.strip_edges().to_upper() == wanted_password:
			var address := _get_lobby_data(lobby_id, "host_address")
			var host_port := int(_get_lobby_data(lobby_id, "host_port"))
			lobby_lookup_completed.emit(true, address, room_name, password, str(lobby_id), "Steam lobby found.", host_port)
			pending_lookup.clear()
			return
	lobby_lookup_completed.emit(false, "", str(pending_lookup.get("room_name", "")), wanted_password, "", "No matching Steam lobby found.", -1)
	pending_lookup.clear()


func _set_current_lobby_data() -> void:
	if not _steam or current_lobby_id.is_empty() or not _steam.has_method("setLobbyData"):
		return
	var lobby_int := int(current_lobby_id)
	_steam.call("setLobbyData", lobby_int, "room_name", str(pending_host_data.get("room_name", "")))
	_steam.call("setLobbyData", lobby_int, "lobby_id", str(pending_host_data.get("lobby_password", "")))
	_steam.call("setLobbyData", lobby_int, "host_address", str(pending_host_data.get("host_address", Network.SERVER_ADDRESS)))
	_steam.call("setLobbyData", lobby_int, "host_port", str(pending_host_data.get("host_port", Network.server_port)))
	_steam.call("setLobbyData", lobby_int, "steam_id", steam_id)
	_steam.call("setLobbyData", lobby_int, "version", str(ProjectSettings.get_setting("application/config/version", "dev")))
	if _steam.has_method("setLobbyJoinable"):
		_steam.call("setLobbyJoinable", lobby_int, true)


func _get_lobby_data(lobby_id, key: String) -> String:
	if not _steam or not _steam.has_method("getLobbyData"):
		return ""
	return str(_steam.call("getLobbyData", int(lobby_id), key))


func _normalize_lobby_list(lobbies) -> Array:
	if lobbies is Array:
		return lobbies
	if lobbies is PackedInt64Array:
		return Array(lobbies)
	if lobbies is PackedStringArray:
		return Array(lobbies)
	if lobbies is int:
		var result := []
		if _steam and _steam.has_method("getLobbyByIndex"):
			for index in range(lobbies):
				result.append(_steam.call("getLobbyByIndex", index))
		return result
	return []


func _steam_init_succeeded(result) -> bool:
	if result is Dictionary:
		var status = result.get("status", result.get("success", false))
		if status is bool:
			return status
		if status is int or status is float:
			return int(status) == 1
		return ["true", "1", "ok"].has(str(status).to_lower())
	if result is bool:
		return result
	if result is int:
		return result == 1
	return _steam and _steam.has_method("loggedOn") and bool(_steam.call("loggedOn"))


func _get_persona_name() -> String:
	if _steam and _steam.has_method("getPersonaName"):
		return str(_steam.call("getPersonaName"))
	return ""


func _get_steam_id() -> String:
	if _steam and _steam.has_method("getSteamID"):
		return str(_steam.call("getSteamID"))
	return ""


func _set_availability(value: bool, message: String) -> void:
	available = value
	availability_changed.emit(available, message)
