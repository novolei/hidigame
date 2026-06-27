extends SceneTree

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")
const ManagerScript := preload("res://scripts/hot_update/hot_update_manager.gd")
const Store := preload("res://scripts/hot_update/hot_update_store.gd")

var failures: Array[String] = []
var _manifest_ready := false
var _pending_count := 0
var _pending_ids: Array[String] = []
var _installed := false
var _failed_message := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var manifest_url := OS.get_environment("MAOMAO_TEST_MANIFEST_URL").strip_edges()
	var expected_ids := _expected_package_ids()
	var marker_path := OS.get_environment("MAOMAO_TEST_MARKER_PATH").strip_edges()
	if marker_path.is_empty() and not OS.has_environment("MAOMAO_TEST_MARKER_PATH"):
		marker_path = "res://hot_update_test_marker.txt"
	var include_optional := _env_bool("MAOMAO_TEST_INCLUDE_OPTIONAL_PACKAGES", false)
	var manifest_timeout := _env_float("MAOMAO_TEST_MANIFEST_TIMEOUT_SEC", 5.0)
	var install_timeout := _env_float("MAOMAO_TEST_INSTALL_TIMEOUT_SEC", 10.0)
	_expect(not manifest_url.is_empty(), "MAOMAO_TEST_MANIFEST_URL is required")
	_expect(not expected_ids.is_empty(), "Expected package id list must not be empty")
	if not failures.is_empty():
		_finish()
		return

	var previous_auto_check: Variant = ProjectSettings.get_setting(Constants.SETTING_AUTO_CHECK_ON_BOOT, false)
	ProjectSettings.set_setting(Constants.SETTING_AUTO_CHECK_ON_BOOT, false)
	var manager: Node = ManagerScript.new()
	root.add_child(manager)
	await process_frame
	ProjectSettings.set_setting(Constants.SETTING_AUTO_CHECK_ON_BOOT, previous_auto_check)

	manager.status_changed.connect(func(message: String) -> void:
		print("[HotUpdateHttpInstallTest] " + message)
	)
	manager.update_failed.connect(func(message: String) -> void:
		_failed_message = message
	)
	manager.manifest_ready.connect(func(_manifest: Dictionary, pending_packages: Array) -> void:
		_manifest_ready = true
		_pending_count = pending_packages.size()
		_pending_ids.clear()
		for pending_package in pending_packages:
			if pending_package is Dictionary:
				_pending_ids.append(str((pending_package as Dictionary).get("id", "")))
	)
	manager.update_installed.connect(func(_restart_required: bool) -> void:
		_installed = true
	)

	_expect(bool(manager.call("check_for_updates", manifest_url, include_optional)), "check_for_updates should start")
	await _wait_until(func() -> bool:
		return _manifest_ready or not _failed_message.is_empty()
	, manifest_timeout)
	_expect(_failed_message.is_empty(), "Manifest check failed: %s" % _failed_message)
	_expect(_manifest_ready, "Manifest should be ready")
	_expect(_pending_count == expected_ids.size(), "Expected %d pending package(s), got %d: %s" % [expected_ids.size(), _pending_count, str(_pending_ids)])
	for expected_id in expected_ids:
		_expect(_pending_ids.has(expected_id), "Pending package list should include %s: %s" % [expected_id, str(_pending_ids)])
	_expect(bool(manager.call("install_pending_updates")), "install_pending_updates should start")
	await _wait_until(func() -> bool:
		return _installed or not _failed_message.is_empty()
	, install_timeout)
	_expect(_failed_message.is_empty(), "Install failed: %s" % _failed_message)
	_expect(_installed, "Update should install")

	var load_result := Store.load_installed_packs()
	var loaded: Array = load_result.get("loaded", []) as Array
	var failed: Array = load_result.get("failed", []) as Array
	for expected_id in expected_ids:
		_expect(loaded.has(expected_id), "Installed PCK should load through ProjectSettings.load_resource_pack: %s" % expected_id)
	_expect(failed.is_empty(), "No installed packages should fail loading: %s" % str(failed))
	if not marker_path.is_empty():
		_expect(FileAccess.file_exists(marker_path), "Mounted test PCK should expose known marker file: %s" % marker_path)
	_finish()


func _wait_until(predicate: Callable, timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if bool(predicate.call()):
			return
		await create_timer(0.05).timeout
		elapsed += 0.05


func _finish() -> void:
	_cleanup()
	if failures.is_empty():
		print("[HotUpdateHttpInstallTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[HotUpdateHttpInstallTest] " + failure)
		quit(1)


func _cleanup() -> void:
	var package_dir := Constants.USER_ROOT.path_join(Constants.PACKAGE_DIR)
	var temp_dir := Constants.USER_ROOT.path_join(Constants.TEMP_DIR)
	_remove_files(package_dir)
	_remove_files(temp_dir)
	var manifest_path := Store.installed_manifest_path()
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)


func _remove_files(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))


func _expected_package_ids() -> Array[String]:
	var raw := OS.get_environment("MAOMAO_TEST_EXPECTED_PACKAGE_IDS").strip_edges()
	if raw.is_empty():
		return ["core_patch"]
	var result: Array[String] = []
	for value in raw.split(",", false):
		var package_id := value.strip_edges()
		if not package_id.is_empty():
			result.append(package_id)
	return result


func _env_float(name: String, fallback: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty():
		return fallback
	var parsed := raw.to_float()
	if parsed <= 0.0:
		return fallback
	return parsed


func _env_bool(name: String, fallback: bool) -> bool:
	var raw := OS.get_environment(name).strip_edges().to_lower()
	if raw.is_empty():
		return fallback
	if raw in ["1", "true", "yes", "on", "enabled"]:
		return true
	if raw in ["0", "false", "no", "off", "disabled"]:
		return false
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
