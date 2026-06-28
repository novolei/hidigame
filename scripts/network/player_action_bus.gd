extends Node
class_name PlayerActionBus

const ACTION_EVENT_APPROX_BYTES: int = 96
const ACTION_NAME_MAX_LENGTH: int = 48
const PAYLOAD_KEY_MAX_LENGTH: int = 32
const MAX_PAYLOAD_KEYS: int = 12
const MAX_APPLIED_EVENT_KEYS: int = 128

@export var player_path: NodePath = NodePath("..")
@export var apply_on_listen_server: bool = true

var _player: Node = null
var _local_sequence: int = 0
var _applied_event_keys: Array[String] = []


func _ready() -> void:
	_resolve_player()


func publish_action(action_name: String, payload: Dictionary = {}) -> Dictionary:
	var source_peer_id: int = _source_peer_id()
	var event: Dictionary = _make_action_event(source_peer_id, action_name, payload)
	if event.is_empty():
		return {}
	if not _has_runtime_multiplayer_peer():
		return event
	if _is_runtime_multiplayer_server():
		_server_forward_action_event(event, source_peer_id)
	else:
		Network.record_rpc_event("player_action.request", 1, ACTION_EVENT_APPROX_BYTES + _payload_approx_bytes(event.get("payload", {})))
		_request_action_event.rpc_id(1, event)
	return event


func sanitize_action_event(raw_event: Dictionary, forced_source_peer_id: int = 0) -> Dictionary:
	return _sanitize_action_event(raw_event, forced_source_peer_id)


func apply_action_event(event: Dictionary) -> bool:
	return _apply_action_event(event)


func _has_runtime_multiplayer_peer() -> bool:
	return RuntimeMode.has_multiplayer_peer(multiplayer)


func _is_runtime_multiplayer_server() -> bool:
	return RuntimeMode.is_multiplayer_server(multiplayer)


func _local_peer_id() -> int:
	if _has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _source_peer_id() -> int:
	var player: Node = _resolve_player()
	if player != null and player.has_method("get_multiplayer_authority"):
		var authority: int = int(player.call("get_multiplayer_authority"))
		if authority > 0:
			return authority
	return _local_peer_id()


func _resolve_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_node_or_null(player_path)
	return _player


func _make_action_event(source_peer_id: int, action_name: String, payload: Dictionary) -> Dictionary:
	_local_sequence += 1
	if _local_sequence >= 0x7fffffff:
		_local_sequence = 1
	var raw_event: Dictionary = {
		"source_peer_id": source_peer_id,
		"tick": NetworkTime.tick,
		"sequence": _local_sequence,
		"action": action_name,
		"payload": payload,
	}
	return _sanitize_action_event(raw_event, source_peer_id)


@rpc("any_peer", "call_local", "reliable")
func _request_action_event(raw_event: Dictionary) -> void:
	if not _is_runtime_multiplayer_server():
		Network.record_perf_event("player_action.reject_not_server")
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		Network.record_perf_event("player_action.reject_sender")
		return
	if not _sender_controls_player(sender_id):
		Network.record_perf_event("player_action.reject_authority")
		return
	var event: Dictionary = _sanitize_action_event(raw_event, sender_id)
	if event.is_empty():
		Network.record_perf_event("player_action.reject_payload")
		return
	_server_forward_action_event(event, sender_id)


@rpc("any_peer", "call_remote", "reliable")
func _receive_action_event(raw_event: Dictionary) -> void:
	if _has_runtime_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		Network.record_perf_event("player_action.reject_remote_sender")
		return
	var event: Dictionary = _sanitize_action_event(raw_event)
	if event.is_empty():
		Network.record_perf_event("player_action.reject_remote_payload")
		return
	if int(event.get("source_peer_id", 0)) == _local_peer_id():
		return
	_apply_action_event(event)


func _server_forward_action_event(event: Dictionary, excluded_peer_id: int) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var clean_event: Dictionary = _sanitize_action_event(event, int(event.get("source_peer_id", 0)))
	if clean_event.is_empty():
		return
	var source_peer_id: int = int(clean_event.get("source_peer_id", 0))
	if apply_on_listen_server and source_peer_id != _local_peer_id():
		_apply_action_event(clean_event)
	var recipient_count: int = 0
	var peers: PackedInt32Array = multiplayer.get_peers()
	for peer_id: int in peers:
		if peer_id == excluded_peer_id:
			continue
		recipient_count += 1
		_receive_action_event.rpc_id(peer_id, clean_event)
	if recipient_count > 0:
		Network.record_rpc_event("player_action.forward", recipient_count, ACTION_EVENT_APPROX_BYTES + _payload_approx_bytes(clean_event.get("payload", {})))


func _sender_controls_player(sender_id: int) -> bool:
	var player: Node = _resolve_player()
	if player == null:
		return false
	if player.has_method("get_multiplayer_authority"):
		return int(player.call("get_multiplayer_authority")) == sender_id
	return false


func _apply_action_event(event: Dictionary) -> bool:
	var clean_event: Dictionary = _sanitize_action_event(event)
	if clean_event.is_empty():
		return false
	var event_key: String = _event_key(clean_event)
	if _applied_event_keys.has(event_key):
		return false
	_remember_event_key(event_key)
	var player: Node = _resolve_player()
	if player == null or not player.has_method("apply_network_action_event"):
		return false
	player.call("apply_network_action_event", clean_event)
	return true


func _sanitize_action_event(raw_event: Dictionary, forced_source_peer_id: int = 0) -> Dictionary:
	var action: String = _normalize_action_name(str(raw_event.get("action", "")))
	if action.is_empty():
		return {}
	var source_peer_id: int = forced_source_peer_id if forced_source_peer_id > 0 else int(raw_event.get("source_peer_id", 0))
	if source_peer_id <= 0:
		source_peer_id = _source_peer_id()
	var tick: int = int(raw_event.get("tick", NetworkTime.tick))
	var sequence: int = int(raw_event.get("sequence", 0))
	var raw_payload: Variant = raw_event.get("payload", {})
	var payload: Dictionary = {}
	if raw_payload is Dictionary:
		payload = raw_payload
	return {
		"source_peer_id": source_peer_id,
		"tick": tick,
		"sequence": sequence,
		"action": action,
		"payload": _sanitize_payload(payload),
	}


func _normalize_action_name(action_name: String) -> String:
	var normalized: String = action_name.strip_edges().to_lower()
	if normalized.length() > ACTION_NAME_MAX_LENGTH:
		normalized = normalized.substr(0, ACTION_NAME_MAX_LENGTH)
	var output: String = ""
	for index: int in normalized.length():
		var character: String = normalized.substr(index, 1)
		if character.is_valid_identifier() or character == "." or character == "-":
			output += character
		elif character == " ":
			output += "_"
	return output


func _sanitize_payload(raw_payload: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	var count: int = 0
	for raw_key: Variant in raw_payload.keys():
		if count >= MAX_PAYLOAD_KEYS:
			break
		var key: String = str(raw_key).strip_edges()
		if key.is_empty():
			continue
		if key.length() > PAYLOAD_KEY_MAX_LENGTH:
			key = key.substr(0, PAYLOAD_KEY_MAX_LENGTH)
		var value: Variant = raw_payload[raw_key]
		if _is_supported_payload_value(value):
			payload[key] = value
			count += 1
	return payload


func _is_supported_payload_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR:
			return true
		_:
			return false


func _payload_approx_bytes(raw_payload: Variant) -> int:
	if not (raw_payload is Dictionary):
		return 0
	var payload: Dictionary = raw_payload
	var total: int = 0
	for key: Variant in payload.keys():
		total += mini(str(key).length(), PAYLOAD_KEY_MAX_LENGTH) + 4
		var value: Variant = payload[key]
		match typeof(value):
			TYPE_BOOL:
				total += 1
			TYPE_INT, TYPE_FLOAT:
				total += 8
			TYPE_STRING:
				total += mini(str(value).length(), 64)
			TYPE_VECTOR2:
				total += 8
			TYPE_VECTOR3, TYPE_COLOR:
				total += 12
			_:
				total += 4
	return total


func _event_key(event: Dictionary) -> String:
	return "%d:%d:%d:%s" % [
		int(event.get("source_peer_id", 0)),
		int(event.get("tick", 0)),
		int(event.get("sequence", 0)),
		str(event.get("action", "")),
	]


func _remember_event_key(event_key: String) -> void:
	_applied_event_keys.append(event_key)
	while _applied_event_keys.size() > MAX_APPLIED_EVENT_KEYS:
		_applied_event_keys.pop_front()
