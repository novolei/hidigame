extends RefCounted
class_name NorayPrivateTransport

signal status_changed(status_key: String, is_error: bool)
signal host_handshake_requested(address: String, port: int)

const MODE_NONE: String = ""
const MODE_HOST: String = "host"
const MODE_CLIENT: String = "client"
const JOIN_PREFIX: String = "noray:"
const JOIN_URL_PREFIX: String = "noray://"
const DEFAULT_NORAY_HOST: String = "8.153.148.157"
const DEFAULT_NORAY_PORT: int = 8890
const CONNECT_TIMEOUT_SEC: float = 10.0
const ID_TIMEOUT_SEC: float = 8.0
const NAT_WAIT_TIMEOUT_SEC: float = 10.0
const RELAY_WAIT_TIMEOUT_SEC: float = 12.0
const HANDSHAKE_TIMEOUT_SEC: float = 5.0
const HANDSHAKE_INTERVAL_SEC: float = 0.08

var active_mode: String = MODE_NONE
var share_code: String = ""
var noray_host: String = DEFAULT_NORAY_HOST
var noray_port: int = DEFAULT_NORAY_PORT
var local_port: int = -1
var _signals_bound: bool = false
var _id_wait_oid_received: bool = false
var _id_wait_pid_received: bool = false
var _client_join_token: int = 0
var _client_attempt_done: bool = false
var _client_attempt_error: int = ERR_BUSY
var _client_attempt_peer: ENetMultiplayerPeer = null
var _client_attempt_address: String = ""
var _client_attempt_port: int = -1
var _client_attempt_mode: String = ""


static func is_noray_target(value: String) -> bool:
	var target: String = value.strip_edges().to_lower()
	if target.is_empty():
		return false
	return target.begins_with(JOIN_PREFIX) or target.begins_with(JOIN_URL_PREFIX)


static func extract_oid(value: String) -> String:
	var target: String = value.strip_edges()
	var lower_target: String = target.to_lower()
	if lower_target.begins_with(JOIN_URL_PREFIX):
		target = target.substr(JOIN_URL_PREFIX.length())
	elif lower_target.begins_with(JOIN_PREFIX):
		target = target.substr(JOIN_PREFIX.length())
	return target.strip_edges()


static func make_share_code(oid: String) -> String:
	var clean_oid: String = oid.strip_edges()
	return "%s%s" % [JOIN_PREFIX, clean_oid] if not clean_oid.is_empty() else ""


func reset(disconnect_noray: bool = true) -> void:
	_client_join_token += 1
	_client_attempt_done = false
	_client_attempt_error = ERR_BUSY
	_client_attempt_peer = null
	_client_attempt_address = ""
	_client_attempt_port = -1
	_client_attempt_mode = ""
	active_mode = MODE_NONE
	share_code = ""
	local_port = -1
	if disconnect_noray and Noray.is_connected_to_host():
		Noray.disconnect_from_host()


func prepare_host(scene_tree: SceneTree, max_players: int) -> Dictionary:
	reset(true)
	_bind_signals()
	active_mode = MODE_HOST
	var register_result: Dictionary = await _connect_and_register(scene_tree)
	var register_error: int = int(register_result.get("error", FAILED))
	if register_error != OK:
		reset(true)
		return _error_result(register_error)

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var listen_port: int = int(register_result.get("local_port", Noray.local_port))
	var create_error: int = peer.create_server(listen_port, max_players)
	if create_error != OK:
		reset(true)
		return _error_result(create_error)

	local_port = listen_port
	share_code = make_share_code(str(register_result.get("oid", Noray.oid)))
	status_changed.emit("join_status.noray_host_ready", false)
	return {
		"error": OK,
		"peer": peer,
		"share_code": share_code,
		"oid": str(register_result.get("oid", Noray.oid)),
		"local_port": local_port,
		"noray_host": noray_host,
		"noray_port": noray_port,
	}


func prepare_client(scene_tree: SceneTree, target: String) -> Dictionary:
	reset(true)
	_bind_signals()
	active_mode = MODE_CLIENT
	var oid: String = extract_oid(target)
	if oid.is_empty():
		reset(true)
		return _error_result(ERR_INVALID_PARAMETER)

	var register_result: Dictionary = await _connect_and_register(scene_tree)
	var register_error: int = int(register_result.get("error", FAILED))
	if register_error != OK:
		reset(true)
		return _error_result(register_error)

	local_port = int(register_result.get("local_port", Noray.local_port))
	var nat_result: Dictionary = await _try_client_connect(scene_tree, oid, false, NAT_WAIT_TIMEOUT_SEC)
	if int(nat_result.get("error", FAILED)) == OK:
		return nat_result

	status_changed.emit("join_status.noray_relay", false)
	var relay_result: Dictionary = await _try_client_connect(scene_tree, oid, true, RELAY_WAIT_TIMEOUT_SEC)
	if int(relay_result.get("error", FAILED)) != OK:
		reset(true)
	return relay_result


func _bind_signals() -> void:
	if _signals_bound:
		return
	Noray.on_connect_nat.connect(_on_noray_connect_nat)
	Noray.on_connect_relay.connect(_on_noray_connect_relay)
	Noray.on_oid.connect(_on_noray_oid)
	Noray.on_pid.connect(_on_noray_pid)
	_signals_bound = true


func _connect_and_register(scene_tree: SceneTree) -> Dictionary:
	status_changed.emit("join_status.noray_connecting", false)
	_configure_noray_endpoint()
	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()
		await scene_tree.process_frame

	var connect_error: int = await Noray.connect_to_host(noray_host, noray_port)
	if connect_error != OK:
		status_changed.emit("join_status.noray_failed", true)
		return _error_result(connect_error)

	_id_wait_oid_received = false
	_id_wait_pid_received = false
	status_changed.emit("join_status.noray_registering", false)
	var register_error: int = Noray.register_host()
	if register_error != OK:
		status_changed.emit("join_status.noray_failed", true)
		return _error_result(register_error)

	var id_error: int = await _wait_for_ids(scene_tree)
	if id_error != OK:
		status_changed.emit("join_status.noray_failed", true)
		return _error_result(id_error)

	status_changed.emit("join_status.noray_register_remote", false)
	var remote_error: int = await Noray.register_remote()
	if remote_error != OK:
		status_changed.emit("join_status.noray_failed", true)
		return _error_result(remote_error)

	return {
		"error": OK,
		"oid": Noray.oid,
		"local_port": Noray.local_port,
	}


func _wait_for_ids(scene_tree: SceneTree) -> int:
	var deadline_msec: int = Time.get_ticks_msec() + roundi(ID_TIMEOUT_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		if _id_wait_oid_received and _id_wait_pid_received:
			return OK
		await scene_tree.process_frame
	return ERR_TIMEOUT


func _try_client_connect(scene_tree: SceneTree, oid: String, use_relay: bool, timeout_sec: float) -> Dictionary:
	_client_join_token += 1
	var token: int = _client_join_token
	_client_attempt_done = false
	_client_attempt_error = ERR_BUSY
	_client_attempt_peer = null
	_client_attempt_address = ""
	_client_attempt_port = -1
	_client_attempt_mode = "relay" if use_relay else "nat"

	status_changed.emit("join_status.noray_relay" if use_relay else "join_status.noray_punchthrough", false)
	var connect_error: int = Noray.connect_relay(oid) if use_relay else Noray.connect_nat(oid)
	if connect_error != OK:
		return _error_result(connect_error)

	var deadline_msec: int = Time.get_ticks_msec() + roundi(timeout_sec * 1000.0)
	while token == _client_join_token and Time.get_ticks_msec() < deadline_msec:
		if _client_attempt_done:
			if _client_attempt_error == OK:
				status_changed.emit("join_status.noray_connected", false)
				return {
					"error": OK,
					"peer": _client_attempt_peer,
					"address": _client_attempt_address,
					"port": _client_attempt_port,
					"mode": _client_attempt_mode,
					"local_port": local_port,
					"noray_host": noray_host,
					"noray_port": noray_port,
				}
			return _error_result(_client_attempt_error)
		await scene_tree.process_frame
	return _error_result(ERR_TIMEOUT)


func _on_noray_connect_nat(address: String, port: int) -> void:
	if active_mode == MODE_HOST:
		host_handshake_requested.emit(address, port)
	elif active_mode == MODE_CLIENT and _client_attempt_mode == "nat":
		await _client_connect_endpoint(address, port, "nat", _client_join_token)


func _on_noray_connect_relay(address: String, port: int) -> void:
	if active_mode == MODE_HOST:
		host_handshake_requested.emit(address, port)
	elif active_mode == MODE_CLIENT and _client_attempt_mode == "relay":
		await _client_connect_endpoint(address, port, "relay", _client_join_token)


func _client_connect_endpoint(address: String, port: int, mode: String, token: int) -> void:
	if token != _client_join_token or _client_attempt_done:
		return
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	var bind_error: int = udp.bind(local_port)
	if bind_error != OK:
		_mark_client_attempt(bind_error, null, address, port, mode, token)
		return
	udp.set_dest_address(address, port)
	var handshake_error: int = await PacketHandshake.over_packet_peer(udp, HANDSHAKE_TIMEOUT_SEC, HANDSHAKE_INTERVAL_SEC)
	udp.close()
	if handshake_error != OK and handshake_error != ERR_BUSY:
		_mark_client_attempt(handshake_error, null, address, port, mode, token)
		return

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: int = peer.create_client(address, port, 0, 0, 0, local_port)
	if create_error != OK:
		_mark_client_attempt(create_error, null, address, port, mode, token)
		return
	_mark_client_attempt(OK, peer, address, port, mode, token)


func _mark_client_attempt(error: int, peer: ENetMultiplayerPeer, address: String, port: int, mode: String, token: int) -> void:
	if token != _client_join_token:
		return
	_client_attempt_error = error
	_client_attempt_peer = peer
	_client_attempt_address = address
	_client_attempt_port = port
	_client_attempt_mode = mode
	_client_attempt_done = true


func _on_noray_oid(_oid: String) -> void:
	_id_wait_oid_received = true


func _on_noray_pid(_pid: String) -> void:
	_id_wait_pid_received = true


func _configure_noray_endpoint() -> void:
	var env_host: String = OS.get_environment("MAOMAO_NORAY_HOST").strip_edges()
	var env_port: String = OS.get_environment("MAOMAO_NORAY_PORT").strip_edges()
	noray_host = env_host if not env_host.is_empty() else DEFAULT_NORAY_HOST
	noray_port = int(env_port) if env_port.is_valid_int() else DEFAULT_NORAY_PORT


func _error_result(error: int) -> Dictionary:
	return {
		"error": error,
	}
