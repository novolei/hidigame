extends SceneTree

# Validates the join-time version handshake gate (Phase 1 of the incremental
# update plan). Covers the decision core (BuildInfo) and the producer/consumer
# key contract in network.gd, so a stale-build mismatch is refused at join
# instead of crashing later on a divergent RPC.
#
# Run headlessly:
#   godot --headless -s tests/network_version_handshake_test.gd

var failures: Array[String] = []


func _init() -> void:
	_test_protocol_gate()
	_test_handshake_payload()
	_test_network_handshake_contract()

	if failures.is_empty():
		print("[NetworkVersionHandshakeTest] PASS")
	else:
		for failure in failures:
			push_error("[NetworkVersionHandshakeTest] " + failure)
	quit(0 if failures.is_empty() else 1)


func _test_protocol_gate() -> void:
	var current := BuildInfo.NETWORK_PROTOCOL_VERSION
	_expect(BuildInfo.protocol_version() == current, "protocol_version() should equal the constant")
	_expect(BuildInfo.is_compatible(current), "matching protocol must be compatible")
	# A peer that predates the handshake advertises nothing; callers pass -1.
	_expect(not BuildInfo.is_compatible(-1), "stale/old peer (-1) must be incompatible")
	_expect(not BuildInfo.is_compatible(current + 1), "newer protocol must be incompatible")
	_expect(not BuildInfo.is_compatible(current - 1), "older protocol must be incompatible")


func _test_handshake_payload() -> void:
	var payload := BuildInfo.handshake_payload()
	_expect(payload.has("protocol_version"), "handshake payload must carry protocol_version")
	_expect(payload.has("build_id"), "handshake payload must carry build_id")
	_expect(payload.has("content_version"), "handshake payload must carry content_version")
	_expect(int(payload.get("protocol_version", -1)) == BuildInfo.NETWORK_PROTOCOL_VERSION, "payload protocol must match the constant")
	_expect(not str(payload.get("build_id", "")).is_empty(), "build_id must have a non-empty fallback")
	_expect(not str(payload.get("content_version", "")).is_empty(), "content_version must have a non-empty fallback")


func _test_network_handshake_contract() -> void:
	# Guard the producer/consumer key contract: the same keys the handshake payload
	# produces must be the ones network.gd reads on both the server and client side.
	var src := FileAccess.get_file_as_string("res://scripts/network.gd")
	_expect(src.contains("_register_player.rpc_id(1, _handshake_registration_info())"),
		"client must send handshake-tagged info to the server on connect")
	_expect(src.contains("BuildInfo.is_compatible(client_protocol)"),
		"server must gate the client's protocol on registration")
	_expect(src.contains("_rpc_reject_protocol.rpc_id"),
		"server must notify rejected clients with a reject RPC")
	_expect(src.contains("_broadcast_full_sync.rpc_id(sender_id, players, lobby_config, BuildInfo.handshake_payload())"),
		"server must include its handshake in the first full sync")
	_expect(src.contains("BuildInfo.is_compatible(server_protocol)"),
		"client must validate the server's protocol on the first full sync")
	_expect(src.contains('new_player_info.get("protocol_version"'),
		"server must read protocol_version from the registration payload")
	_expect(src.contains('server_info.get("protocol_version"'),
		"client must read protocol_version from the server handshake")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
