extends SceneTree


func _initialize() -> void:
	var output_path := OS.get_environment("MAOMAO_TEST_PCK_PATH").strip_edges()
	if output_path.is_empty():
		push_error("[HotUpdateMakeTestPack] MAOMAO_TEST_PCK_PATH is required")
		quit(1)
		return
	var packer := PCKPacker.new()
	var error := packer.pck_start(output_path)
	if error != OK:
		push_error("[HotUpdateMakeTestPack] pck_start failed: %s" % error_string(error))
		quit(1)
		return
	error = packer.add_file_from_buffer("res://hot_update_test_marker.txt", "hot update marker".to_utf8_buffer())
	if error != OK:
		push_error("[HotUpdateMakeTestPack] add_file_from_buffer failed: %s" % error_string(error))
		quit(1)
		return
	error = packer.flush()
	if error != OK:
		push_error("[HotUpdateMakeTestPack] flush failed: %s" % error_string(error))
		quit(1)
		return
	print("[HotUpdateMakeTestPack] PASS")
	quit(0)
