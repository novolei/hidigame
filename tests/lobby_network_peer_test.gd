extends Node

const TEST_LOBBY_ID := "T7QA"
const TIMEOUT_SEC := 8.0

var mode := ""
var elapsed := 0.0


func _ready() -> void:
	mode = _get_arg_value("--mode")
	match mode:
		"server":
			_start_server()
		"client":
			call_deferred("_start_client")
		_:
			_fail("Missing --mode server|client")


func _process(delta: float) -> void:
	elapsed += delta
	if mode == "server":
		if Network.players.size() >= 2:
			_pass("server saw joined player")
	elif mode == "client":
		if Network.players.size() >= 2 and str(Network.lobby_config.get("lobby_id", "")) == TEST_LOBBY_ID:
			_pass("client received lobby sync")

	if elapsed >= TIMEOUT_SEC:
		_fail("%s timed out. players=%d lobby=%s" % [mode, Network.players.size(), str(Network.lobby_config.get("lobby_id", ""))])


func _start_server() -> void:
	var error = Network.start_host("Host", "blue", Network.Role.CHAMELEON)
	if error:
		_fail("server start failed: " + str(error))
		return
	Network.lobby_config["lobby_id"] = TEST_LOBBY_ID
	Network.players[1] = Network.player_info.duplicate()
	print("[LobbyNetworkPeerTest] server ready lobby=", TEST_LOBBY_ID)


func _start_client() -> void:
	await get_tree().create_timer(0.5).timeout
	var error = Network.join_game("Client", "yellow", "127.0.0.1", TEST_LOBBY_ID, Network.Role.HUNTER)
	if error:
		_fail("client join failed: " + str(error))
		return
	print("[LobbyNetworkPeerTest] client joining lobby=", TEST_LOBBY_ID)


func _get_arg_value(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == name:
			return args[i + 1]
	return ""


func _pass(message: String) -> void:
	print("[LobbyNetworkPeerTest] PASS ", message)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[LobbyNetworkPeerTest] FAIL " + message)
	get_tree().quit(1)
