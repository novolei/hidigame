extends Node
class_name LanRoomDiscovery

## Zero-backend LAN room discovery for the "Private Server" browser.
##
## A host advertises its direct ENet room over UDP broadcast on the local network; a
## browser binds the discovery port and collects those announcements. Because two game
## instances on the SAME machine cannot both bind the broadcast port, we also mirror each
## advertisement to a short-lived JSON file under user:// (a directory all local instances
## share) — so same-machine multi-window testing discovers rooms reliably too.
##
## Nothing here touches the public VPS or Noray; discovery and the subsequent join are
## pure peer-to-peer on the LAN.

signal rooms_updated(rooms: Array)

const DISCOVERY_PORT := 50127
const BROADCAST_INTERVAL := 1.0      # seconds between advertise beacons
const STALE_SECONDS := 3.6           # drop a room this long after its last beacon
const POLL_INTERVAL := 0.4           # how often the browser rebuilds + emits the list
const REGISTRY_DIR := "user://lan_rooms"
const MAGIC := "MMLAN1"              # packet tag so we ignore unrelated UDP traffic

var _advertising := false
var _browsing := false
var _ad_info: Dictionary = {}
var _ad_uid := ""
var _ad_accum := BROADCAST_INTERVAL
var _poll_accum := 0.0
var _send_socket: PacketPeerUDP = null
var _recv_socket: PacketPeerUDP = null
var _rooms: Dictionary = {}          # uid -> {"entry": Dictionary, "seen": float}
var _last_signature := ""


func _exit_tree() -> void:
	stop_advertising()
	stop_browsing()


# --- Advertising (host side) -------------------------------------------------

func start_advertising(info: Dictionary) -> void:
	_ad_info = info.duplicate(true)
	if _ad_uid.is_empty():
		_ad_uid = _make_uid()
	_advertising = true
	_ad_accum = BROADCAST_INTERVAL    # beacon immediately on the next tick
	if _send_socket == null:
		_send_socket = PacketPeerUDP.new()
		_send_socket.set_broadcast_enabled(true)
	_ensure_registry_dir()
	set_process(true)


func update_advertisement(info: Dictionary) -> void:
	# Merge live fields (e.g. player_count) without resetting the uid/beacon.
	for key in info.keys():
		_ad_info[key] = info[key]


func stop_advertising() -> void:
	if not _advertising:
		return
	_advertising = false
	_remove_registry_file(_ad_uid)
	if _send_socket:
		_send_socket.close()
		_send_socket = null
	_maybe_idle()


func is_advertising() -> bool:
	return _advertising


# --- Browsing (joiner side) --------------------------------------------------

func start_browsing() -> void:
	if _browsing:
		return
	_browsing = true
	_rooms.clear()
	_last_signature = ""
	_recv_socket = PacketPeerUDP.new()
	_recv_socket.set_broadcast_enabled(true)
	# Bind may fail if another local instance already holds the port — that's fine,
	# the user:// registry fallback still surfaces same-machine rooms.
	_recv_socket.bind(DISCOVERY_PORT, "*")
	_poll_accum = POLL_INTERVAL
	set_process(true)


func stop_browsing() -> void:
	if not _browsing:
		return
	_browsing = false
	if _recv_socket:
		_recv_socket.close()
		_recv_socket = null
	_rooms.clear()
	_maybe_idle()


func is_browsing() -> bool:
	return _browsing


func get_rooms() -> Array:
	var now := _now()
	var list: Array = []
	for uid in _rooms.keys():
		var record: Dictionary = _rooms[uid]
		if now - float(record["seen"]) <= STALE_SECONDS:
			list.append((record["entry"] as Dictionary).duplicate(true))
	list.sort_custom(func(a, b): return str(a.get("room_name", "")).naturalnocasecmp_to(str(b.get("room_name", ""))) < 0)
	return list


# --- Main loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _advertising:
		_ad_accum += delta
		if _ad_accum >= BROADCAST_INTERVAL:
			_ad_accum = 0.0
			_emit_beacon()
	if _browsing:
		_drain_packets()
		_poll_accum += delta
		if _poll_accum >= POLL_INTERVAL:
			_poll_accum = 0.0
			_scan_registry()
			_expire_and_emit()


func _maybe_idle() -> void:
	if not _advertising and not _browsing:
		set_process(false)


# --- Advertise plumbing ------------------------------------------------------

func _emit_beacon() -> void:
	var payload := _build_payload()
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	if _send_socket:
		_send_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_send_socket.put_packet(bytes)
	_write_registry_file(payload)


func _build_payload() -> Dictionary:
	return {
		"magic": MAGIC,
		"uid": _ad_uid,
		"room_name": str(_ad_info.get("room_name", "Room")),
		"host_name": str(_ad_info.get("host_name", "")),
		"player_count": int(_ad_info.get("player_count", 1)),
		"max_players": int(_ad_info.get("max_players", 24)),
		"port": int(_ad_info.get("port", 0)),
		"locked": bool(_ad_info.get("locked", false)),
		"build": str(_ad_info.get("build", "")),
		"lan_ip": _local_lan_ip(),
		"ts": _now(),
	}


# --- Browse plumbing ---------------------------------------------------------

func _drain_packets() -> void:
	if _recv_socket == null:
		return
	while _recv_socket.get_available_packet_count() > 0:
		var bytes := _recv_socket.get_packet()
		var sender_ip := _recv_socket.get_packet_ip()
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if parsed is Dictionary:
			_ingest(parsed as Dictionary, sender_ip)


func _scan_registry() -> void:
	var dir := DirAccess.open(REGISTRY_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var text := FileAccess.get_file_as_string(REGISTRY_DIR.path_join(file_name))
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				# Same-machine peers connect over loopback.
				_ingest(parsed as Dictionary, "127.0.0.1")
		file_name = dir.get_next()
	dir.list_dir_end()


func _ingest(payload: Dictionary, sender_ip: String) -> void:
	if str(payload.get("magic", "")) != MAGIC:
		return
	var uid := str(payload.get("uid", ""))
	if uid.is_empty() or (_advertising and uid == _ad_uid):
		return  # never list our own room in our own browser
	var beacon_ts := float(payload.get("ts", 0.0))
	# Registry files keep their own timestamp; reject ones already stale on disk.
	if beacon_ts > 0.0 and _now() - beacon_ts > STALE_SECONDS:
		return
	var address := str(payload.get("lan_ip", sender_ip))
	if sender_ip != "127.0.0.1" and not sender_ip.is_empty():
		address = sender_ip  # the actual sender is the most reliable route
	elif sender_ip == "127.0.0.1":
		address = "127.0.0.1"
	var entry := {
		"uid": uid,
		"room_name": str(payload.get("room_name", "Room")),
		"host_name": str(payload.get("host_name", "")),
		"player_count": int(payload.get("player_count", 1)),
		"max_players": int(payload.get("max_players", 24)),
		"address": address,
		"port": int(payload.get("port", 0)),
		"locked": bool(payload.get("locked", false)),
		"build": str(payload.get("build", "")),
	}
	_rooms[uid] = {"entry": entry, "seen": _now()}


func _expire_and_emit() -> void:
	var now := _now()
	for uid in _rooms.keys():
		if now - float((_rooms[uid] as Dictionary)["seen"]) > STALE_SECONDS:
			_rooms.erase(uid)
	var rooms := get_rooms()
	var signature := _signature(rooms)
	if signature != _last_signature:
		_last_signature = signature
		rooms_updated.emit(rooms)


# --- Registry file fallback --------------------------------------------------

func _ensure_registry_dir() -> void:
	if not DirAccess.dir_exists_absolute(REGISTRY_DIR):
		DirAccess.make_dir_recursive_absolute(REGISTRY_DIR)


func _write_registry_file(payload: Dictionary) -> void:
	_ensure_registry_dir()
	var file := FileAccess.open(_registry_path(_ad_uid), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
		file.close()


func _remove_registry_file(uid: String) -> void:
	if uid.is_empty():
		return
	var path := _registry_path(uid)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _registry_path(uid: String) -> String:
	return REGISTRY_DIR.path_join("%s.json" % uid)


# --- Helpers -----------------------------------------------------------------

func _signature(rooms: Array) -> String:
	var parts: Array = []
	for room in rooms:
		parts.append("%s:%d:%s" % [str(room.get("uid", "")), int(room.get("player_count", 0)), str(room.get("room_name", ""))])
	return "|".join(parts)


func _local_lan_ip() -> String:
	for address in IP.get_local_addresses():
		var ip := str(address)
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			return ip
	return "127.0.0.1"


func _make_uid() -> String:
	return "%x%x" % [int(_now() * 1000.0) & 0xffffff, randi() & 0xffffff]


func _now() -> float:
	return Time.get_unix_time_from_system()
