extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest_path := OS.get_environment("MAOMAO_TEST_RELEASE_MANIFEST_PATH").strip_edges().replace("\\", "/")
	_expect(not manifest_path.is_empty(), "MAOMAO_TEST_RELEASE_MANIFEST_PATH is required")
	_expect(FileAccess.file_exists(manifest_path), "Release manifest must exist: %s" % manifest_path)
	if not failures.is_empty():
		_finish()
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(parsed is Dictionary, "Release manifest must parse as a JSON object")
	if not parsed is Dictionary:
		_finish()
		return

	var manifest := parsed as Dictionary
	var manifest_dir := manifest_path.get_base_dir()
	var packages: Variant = manifest.get("packages", [])
	_expect(packages is Array, "Release manifest packages must be an array")
	if not packages is Array:
		_finish()
		return

	for value in packages:
		if not value is Dictionary:
			failures.append("Package entry must be a dictionary")
			continue
		var package := value as Dictionary
		var package_id := str(package.get("id", ""))
		var package_url := str(package.get("url", "")).strip_edges()
		var package_path := manifest_dir.path_join(package_url).replace("\\", "/")
		print("[HotUpdateReleasePackLoadTest] loading %s from %s" % [package_id, package_path])
		_expect(FileAccess.file_exists(package_path), "Package file must exist: %s" % package_path)
		if not FileAccess.file_exists(package_path):
			continue
		var expected_size := int(package.get("size_bytes", -1))
		if expected_size >= 0:
			_expect(FileAccess.get_size(package_path) == expected_size, "Package size mismatch for %s" % package_id)
		var expected_sha := str(package.get("sha256", "")).strip_edges().to_lower()
		if expected_sha.length() == 64:
			_expect(FileAccess.get_sha256(package_path).to_lower() == expected_sha, "Package SHA mismatch for %s" % package_id)
		_expect(ProjectSettings.load_resource_pack(package_path, true), "Package should load through ProjectSettings.load_resource_pack: %s" % package_id)

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("[HotUpdateReleasePackLoadTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[HotUpdateReleasePackLoadTest] " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
