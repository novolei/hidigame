extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/effects/freeform_clay_shell.tscn")
	var ugc_script: Script = load("res://scripts/chameleon_sculpt_ugc.gd")
	var source: Node = scene.instantiate()
	add_child(source)
	await get_tree().process_frame
	source.call("apply_sculpt_stroke_local", "add", Vector3(0.48, 1.1, 0.0), 0.26, 1.0)
	source.call("paint_sphere_local", Vector3(0.48, 1.1, 0.0), 0.32, Color(0.2, 0.8, 0.35, 1.0))

	var creation: Dictionary = ugc_script.call("make_creation", "FakeTree", source, "test-author")
	_expect(str(creation.get("name", "")) == "FakeTree", "UGC creation should keep the sanitized name")
	_expect(creation.has("body") and creation.get("body", {}) is Dictionary, "UGC creation should store a compact body payload")
	var code: String = ugc_script.call("encode_share_code", creation)
	_expect(code.begins_with("HIDI-CLAY-1:"), "UGC share code should include the clay prefix")
	var decoded: Dictionary = ugc_script.call("decode_share_code", code)
	_expect(str(decoded.get("name", "")) == "FakeTree", "UGC share code should decode the creation name")
	_expect(int(decoded.get("likes", -1)) == 0 and int(decoded.get("downloads", -1)) == 0, "UGC share code should not import spoofable social counters")
	var creation_body: Dictionary = creation.get("body", {})
	var decoded_body: Dictionary = decoded.get("body", {})
	_expect((decoded_body.get("grid", []) as Array).size() == 3, "UGC share code should preserve the solid SDF grid shape")
	_expect(_same_array_value(decoded_body.get("sdf_q_rle", []), creation_body.get("sdf_q_rle", [])), "UGC share code should preserve quantized solid SDF RLE")
	_expect((decoded_body.get("palette", []) as Array).size() == (creation_body.get("palette", []) as Array).size(), "UGC share code should preserve voxel color palette")
	var tampered_creation := decoded.duplicate(true)
	tampered_creation["likes"] = 999
	tampered_creation["downloads"] = 888
	var tampered_code: String = "HIDI-CLAY-1:" + Marshalls.raw_to_base64(JSON.stringify(tampered_creation).to_utf8_buffer())
	var tampered_decoded: Dictionary = ugc_script.call("decode_share_code", tampered_code)
	_expect(int(tampered_decoded.get("likes", -1)) == 0 and int(tampered_decoded.get("downloads", -1)) == 0, "UGC decode should strip tampered share-code likes and downloads")

	var downloaded: Node = scene.instantiate()
	add_child(downloaded)
	await get_tree().process_frame
	_expect(bool(downloaded.call("apply_compact_body", decoded.get("body", {}))), "Downloaded UGC body should apply to a shell")
	_expect(int(downloaded.call("get_vertex_count")) > 400, "Downloaded UGC body should produce a visible freeform sculpt shell")
	var downloaded_body: Dictionary = downloaded.call("make_compact_body")
	_expect(downloaded_body.get("checksum", -1) == decoded_body.get("checksum", -2), "Downloaded UGC body should replay the same compact profile")

	var creations := [creation, ugc_script.call("make_creation", "Plain", downloaded, "test-author")]
	creations = ugc_script.call("like_by_id", creations, str(creation.get("id", "")))
	creations = ugc_script.call("like_by_id", creations, str(creation.get("id", "")))
	creations = ugc_script.call("mark_downloaded_by_id", creations, str(creation.get("id", "")))
	var board: Array = ugc_script.call("leaderboard", creations, 2)
	_expect(board.size() == 2, "UGC leaderboard should honor the requested limit")
	_expect(str((board[0] as Dictionary).get("name", "")) == "FakeTree", "UGC leaderboard should rank by likes before downloads")
	_expect(int((board[0] as Dictionary).get("likes", 0)) == 2, "UGC like count should be persisted in leaderboard entries")
	_expect(int((board[0] as Dictionary).get("downloads", 0)) == 1, "UGC download count should be persisted in leaderboard entries")

	source.queue_free()
	downloaded.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[ChameleonSculptUGCTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ChameleonSculptUGCTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _same_array_value(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array:
		return false
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var left: Variant = a[i]
		var right: Variant = b[i]
		if left is Array or right is Array:
			if not _same_array_value(left, right):
				return false
		elif left != right:
			return false
	return true
