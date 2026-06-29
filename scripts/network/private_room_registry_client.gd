extends Node
class_name PrivateRoomRegistryClient

## Client for the standalone private-room registry (tools/private_room_registry). A Noray host
## registers its room and re-posts every HEARTBEAT_INTERVAL_SEC as a keepalive; the private
## browser fetches the list to show Noray rooms across the internet. Deliberately separate from
## the public-lobby room list — these are private (Noray) rooms only.
##
## All traffic is plain HTTP to the existing nginx (/private_rooms/), so no new firewall port.
## Override the endpoint with MAOMAO_PRIVATE_REGISTRY_URL for local testing.

const DEFAULT_BASE_URL := "http://1.13.175.170/private_rooms"
const HEARTBEAT_INTERVAL_SEC := 8.0

signal rooms_fetched(rooms: Array)
signal rooms_fetch_failed()

var base_url: String = DEFAULT_BASE_URL
var _list_req: HTTPRequest = null
var _post_req: HTTPRequest = null
var _room: Dictionary = {}          # the room we are hosting (empty when not hosting)
var _hosting: bool = false
var _heartbeat_accum: float = 0.0


func _ready() -> void:
	var override_url := OS.get_environment("MAOMAO_PRIVATE_REGISTRY_URL").strip_edges()
	if not override_url.is_empty():
		base_url = override_url
	_list_req = HTTPRequest.new()
	_list_req.name = "RegistryListRequest"
	_list_req.timeout = 6.0   # so a down registry can't leave a fetch in-flight forever
	add_child(_list_req)
	_list_req.request_completed.connect(_on_list_completed)
	_post_req = HTTPRequest.new()
	_post_req.name = "RegistryPostRequest"
	_post_req.timeout = 6.0
	add_child(_post_req)
	set_process(false)


# --- Host side ---------------------------------------------------------------

func start_hosting(room: Dictionary) -> void:
	# Only meaningful for Noray rooms — the share code is the registry key + join handle.
	if not str(room.get("share_code", "")).to_lower().begins_with("noray:"):
		return
	_room = room.duplicate(true)
	_hosting = true
	_heartbeat_accum = 0.0
	_post_json("/register", _room)
	set_process(true)


func update_player_count(count: int) -> void:
	if _hosting:
		_room["player_count"] = max(0, count)


func stop_hosting() -> void:
	if not _hosting:
		return
	_hosting = false
	set_process(false)
	var code := str(_room.get("share_code", ""))
	_room = {}
	if not code.is_empty():
		_post_json("/remove", {"share_code": code})  # best-effort; the 20s TTL also reaps it


# --- Browse side -------------------------------------------------------------

func fetch_rooms() -> void:
	if _list_req == null:
		return
	if _list_req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # a fetch is already in flight
	var err := _list_req.request(base_url + "/list", PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		rooms_fetch_failed.emit()


# --- Internals ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not _hosting:
		return
	_heartbeat_accum += delta
	if _heartbeat_accum >= HEARTBEAT_INTERVAL_SEC:
		_heartbeat_accum = 0.0
		_post_json("/register", _room)


func _post_json(path: String, body: Dictionary) -> void:
	if _post_req == null:
		return
	# request() returns ERR_BUSY if the previous post is still in flight; that's fine for a
	# heartbeat (the prior post already refreshes the TTL) and remove is best-effort anyway.
	var headers := PackedStringArray(["Content-Type: application/json"])
	_post_req.request(base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_list_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		rooms_fetch_failed.emit()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and (parsed as Dictionary).get("rooms") is Array:
		rooms_fetched.emit(((parsed as Dictionary)["rooms"] as Array).duplicate(true))
	else:
		rooms_fetched.emit([])
