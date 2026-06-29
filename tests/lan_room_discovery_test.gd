extends Node

## Headless test for LanRoomDiscovery: an advertiser and a browser in one process
## must discover each other (via UDP loopback and/or the user:// registry fallback),
## report the correct row fields, reflect live player-count updates, and clean up.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_clear_registry()

	var advertiser := LanRoomDiscovery.new()
	add_child(advertiser)
	var browser := LanRoomDiscovery.new()
	add_child(browser)

	advertiser.start_advertising({
		"room_name": "Bili Room",
		"host_name": "Bili",
		"player_count": 3,
		"max_players": 24,
		"port": 27015,
		"locked": true,
		"build": "test",
	})
	browser.start_browsing()

	await _wait(1.4)
	var rooms: Array = browser.get_rooms()
	_expect(rooms.size() == 1, "Browser should discover exactly one advertised room (got %d)" % rooms.size())
	if rooms.size() == 1:
		var room: Dictionary = rooms[0]
		_expect(str(room.get("room_name", "")) == "Bili Room", "Room name should propagate")
		_expect(str(room.get("host_name", "")) == "Bili", "Host name should propagate")
		_expect(int(room.get("player_count", 0)) == 3, "Player count should propagate")
		_expect(int(room.get("max_players", 0)) == 24, "Max players should be 24")
		_expect(bool(room.get("locked", false)) == true, "Locked flag should propagate")
		_expect(not str(room.get("address", "")).is_empty(), "Room should carry a connectable address")
		_expect(int(room.get("port", 0)) == 27015, "Room should carry the host port")

	# Live update: player count should refresh on the next beacons.
	advertiser.update_advertisement({"player_count": 7})
	await _wait(1.4)
	var updated: Array = browser.get_rooms()
	if updated.size() == 1:
		_expect(int((updated[0] as Dictionary).get("player_count", 0)) == 7, "Player count should update live")

	# A browser never lists its own advertised room.
	_expect(not advertiser.is_browsing(), "Advertiser is not browsing in this test")

	# Stopping advertising removes the registry file.
	advertiser.stop_advertising()
	await _wait(0.2)
	_expect(_registry_is_empty(), "Stopping advertising should remove the registry file")

	browser.stop_browsing()
	advertiser.queue_free()
	browser.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[LanRoomDiscoveryTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[LanRoomDiscoveryTest] " + failure)
		get_tree().quit(1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clear_registry() -> void:
	var dir := DirAccess.open(LanRoomDiscovery.REGISTRY_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(LanRoomDiscovery.REGISTRY_DIR.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()


func _registry_is_empty() -> bool:
	var dir := DirAccess.open(LanRoomDiscovery.REGISTRY_DIR)
	if dir == null:
		return true
	dir.list_dir_begin()
	var fname := dir.get_next()
	var count := 0
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count == 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
