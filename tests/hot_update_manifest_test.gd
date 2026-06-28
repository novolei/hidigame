extends SceneTree

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")
const Manifest := preload("res://scripts/hot_update/hot_update_manifest.gd")
const Store := preload("res://scripts/hot_update/hot_update_store.gd")

var failures: Array[String] = []
var _test_root := "user://hot_update_test"


func _initialize() -> void:
	_cleanup()
	_test_manifest_validation_and_pending_packages()
	_test_store_paths_and_verification()
	_test_installed_manifest_roundtrip()
	_cleanup()
	if failures.is_empty():
		print("[HotUpdateManifestTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[HotUpdateManifestTest] " + failure)
		quit(1)


func _test_manifest_validation_and_pending_packages() -> void:
	var remote := _remote_manifest()
	var validation_errors := Manifest.validate(remote)
	_expect(validation_errors.is_empty(), "Valid manifest should pass validation: %s" % str(validation_errors))
	var package_urls := Manifest.package_urls(remote, (remote.get("packages", []) as Array)[0] as Dictionary, "https://updates.example.invalid/maomao/dev/manifest.json")
	_expect(package_urls.size() == 2, "Package URLs should include primary and mirror sources")
	_expect(package_urls[0] == "https://updates.example.invalid/maomao/dev/packages/core_patch_0.4.5.pck", "Primary package URL should be first")
	_expect(package_urls[1] == "https://updates-al.example.invalid/maomao/dev/packages/core_patch_0.4.5.pck", "Mirror package URL should be second")
	var installed := {
		"schema_version": Constants.MANIFEST_SCHEMA_VERSION,
		"packages": [
			{
				"id": "core_patch",
				"version": "0.4.4",
				"sha256": "1111111111111111111111111111111111111111111111111111111111111111",
			},
		],
	}
	var pending := Manifest.required_packages(remote, installed)
	_expect(pending.size() == 2, "Changed core and missing content package should both be pending")
	_expect(str(pending[0].get("id", "")) == "core_patch", "Pending packages should respect load_order")
	_expect(str(pending[1].get("id", "")) == "maps_warehouse", "Required packages should include required content")
	var pending_with_optional := Manifest.required_packages(remote, installed, true)
	_expect(pending_with_optional.size() == 3, "Optional package should be pending only when include_optional is true")
	_expect(str(pending_with_optional[1].get("id", "")) == "characters_party_monster", "Optional package should keep load_order when included")
	# Baseline gate: a bundled version at-or-above a pack's version makes that pack non-pending,
	# so a fresh full baseline never pulls a pack it would only skip at mount. Empty = gate off.
	var pending_superseded := Manifest.required_packages(remote, installed, true, "9.9.9")
	_expect(pending_superseded.is_empty(), "Packs at-or-below the bundled baseline must not be pending")
	var pending_below_bundle := Manifest.required_packages(remote, installed, true, "0.0.1")
	_expect(pending_below_bundle.size() == 3, "Packs newer than the bundled baseline stay pending")
	var invalid := remote.duplicate(true)
	invalid["packages"] = [{"id": "bad", "version": "1", "sha256": "not-a-sha"}]
	_expect(not Manifest.validate(invalid).is_empty(), "Invalid package SHA should fail validation")


func _test_store_paths_and_verification() -> void:
	Store.ensure_directories(_test_root)
	var package := {
		"id": "core_patch",
		"version": "0.4.5",
		"url": "packages/core_patch_0.4.5.pck",
		"sha256": "",
		"size_bytes": 0,
	}
	var local_path := Store.package_local_path(package, _test_root)
	_expect(local_path.ends_with("core_patch_0.4.5_core_patch_0.4.5.pck"), "Package paths should preserve numeric version/file components")
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	_expect(file != null, "Test package file should open for writing")
	if file != null:
		file.store_string("hot update test")
		file.close()
	package["size_bytes"] = FileAccess.get_size(local_path)
	package["sha256"] = FileAccess.get_sha256(local_path)
	_expect(Store.verify_package_file(package, local_path), "Store should verify expected size and SHA-256")
	package["sha256"] = "0000000000000000000000000000000000000000000000000000000000000000"
	_expect(not Store.verify_package_file(package, local_path), "Store should reject wrong SHA-256")


func _test_installed_manifest_roundtrip() -> void:
	var remote := _remote_manifest()
	var package := (remote.get("packages", []) as Array)[0] as Dictionary
	var save_error := Store.save_installed_manifest(remote, [package], _test_root)
	_expect(save_error == OK, "Installed manifest should save")
	var loaded := Store.load_installed_manifest(_test_root)
	_expect(str(loaded.get("version", "")) == "0.4.5", "Installed manifest version should roundtrip")
	var installed_map := Manifest.installed_package_map(loaded)
	_expect(installed_map.has("core_patch"), "Installed package map should include saved package")


func _remote_manifest() -> Dictionary:
	return {
		"schema_version": Constants.MANIFEST_SCHEMA_VERSION,
		"app_id": "monster_hunter",
		"channel": Constants.DEFAULT_CHANNEL,
		"version": "0.4.5",
		"content_version": "2026.06.27.1",
		"min_app_version": "0.4.4",
		"protocol_version": Constants.DEFAULT_PROTOCOL_VERSION,
		"base_url": "https://updates.example.invalid/maomao/dev",
		"mirrors": [
			{
				"id": "AL",
				"base_url": "https://updates-al.example.invalid/maomao/dev",
			},
		],
		"packages": [
			{
				"id": "core_patch",
				"version": "0.4.5",
				"type": "patch",
				"url": "packages/core_patch_0.4.5.pck",
				"sha256": "2222222222222222222222222222222222222222222222222222222222222222",
				"size_bytes": 128,
				"load_order": 10,
				"required": true,
				"restart_required": true,
			},
			{
				"id": "characters_party_monster",
				"version": "0.4.5",
				"type": "content",
				"url": "packages/characters_party_monster_0.4.5.pck",
				"sha256": "4444444444444444444444444444444444444444444444444444444444444444",
				"size_bytes": 64,
				"load_order": 30,
				"required": false,
				"restart_required": true,
			},
			{
				"id": "maps_warehouse",
				"version": "0.4.5",
				"type": "content",
				"url": "packages/maps_warehouse_0.4.5.pck",
				"sha256": "3333333333333333333333333333333333333333333333333333333333333333",
				"size_bytes": 256,
				"load_order": 50,
				"required": true,
				"restart_required": true,
			},
		],
	}


func _cleanup() -> void:
	var package_dir := _test_root.path_join(Constants.PACKAGE_DIR)
	var temp_dir := _test_root.path_join(Constants.TEMP_DIR)
	_remove_files(package_dir)
	_remove_files(temp_dir)
	var manifest_path := Store.installed_manifest_path(_test_root)
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)


func _remove_files(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
