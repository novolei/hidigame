class_name HotUpdateStore
extends RefCounted

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")
const Manifest := preload("res://scripts/hot_update/hot_update_manifest.gd")


static func ensure_directories(root_path: String = "") -> void:
	var root := _root(root_path)
	DirAccess.make_dir_recursive_absolute(root)
	DirAccess.make_dir_recursive_absolute(root.path_join(Constants.PACKAGE_DIR))
	DirAccess.make_dir_recursive_absolute(root.path_join(Constants.TEMP_DIR))


static func installed_manifest_path(root_path: String = "") -> String:
	return _root(root_path).path_join(Constants.INSTALLED_MANIFEST_FILE)


static func load_installed_manifest(root_path: String = "") -> Dictionary:
	var path := installed_manifest_path(root_path)
	if not FileAccess.file_exists(path):
		return _empty_installed_manifest()
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _empty_installed_manifest()
	return parsed as Dictionary


static func save_installed_manifest(remote_manifest: Dictionary, installed_packages: Array[Dictionary], root_path: String = "") -> int:
	ensure_directories(root_path)
	var manifest := {
		"schema_version": Constants.MANIFEST_SCHEMA_VERSION,
		"app_id": str(remote_manifest.get("app_id", "")),
		"channel": str(remote_manifest.get("channel", Constants.channel())),
		"version": str(remote_manifest.get("version", "")),
		"content_version": str(remote_manifest.get("content_version", remote_manifest.get("version", ""))),
		"protocol_version": int(remote_manifest.get("protocol_version", Constants.protocol_version())),
		"applied_at_unix": Time.get_unix_time_from_system(),
		"packages": installed_packages,
	}
	return write_json_file(installed_manifest_path(root_path), manifest)


static func load_installed_packs(root_path: String = "") -> Dictionary:
	var installed_manifest := load_installed_manifest(root_path)
	var loaded: Array[String] = []
	var failed: Array[String] = []
	for package in Manifest.sorted_packages(installed_manifest):
		var local_path := package_local_path(package, root_path)
		if not verify_package_file(package, local_path):
			failed.append(str(package.get("id", "")))
			continue
		var load_path := ProjectSettings.globalize_path(local_path) if local_path.begins_with("user://") else local_path
		if ProjectSettings.load_resource_pack(load_path, true):
			loaded.append(str(package.get("id", "")))
		else:
			failed.append(str(package.get("id", "")))
	return {
		"loaded": loaded,
		"failed": failed,
	}


static func package_local_path(package: Dictionary, root_path: String = "") -> String:
	var explicit := str(package.get("local_path", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	var file_name := _package_file_name(package)
	var version := _sanitize_file_component(str(package.get("version", "0")))
	var id := _sanitize_file_component(str(package.get("id", "package")))
	return _root(root_path).path_join(Constants.PACKAGE_DIR).path_join("%s_%s_%s" % [id, version, file_name])


static func package_temp_path(package: Dictionary, root_path: String = "") -> String:
	var final_path := package_local_path(package, root_path)
	return _root(root_path).path_join(Constants.TEMP_DIR).path_join(final_path.get_file() + ".download")


static func verify_package_file(package: Dictionary, local_path: String) -> bool:
	if not FileAccess.file_exists(local_path):
		return false
	var expected_size := int(package.get("size_bytes", -1))
	if expected_size >= 0 and FileAccess.get_size(local_path) != expected_size:
		return false
	var expected_sha := str(package.get("sha256", "")).strip_edges().to_lower()
	if expected_sha.length() == 64:
		return FileAccess.get_sha256(local_path).to_lower() == expected_sha
	return true


static func promote_temp_package(temp_path: String, final_path: String, root_path: String = "") -> int:
	ensure_directories(root_path)
	if FileAccess.file_exists(final_path):
		var remove_error := DirAccess.remove_absolute(final_path)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(temp_path, final_path)


static func write_json_file(path: String, data: Dictionary) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	return OK


static func _empty_installed_manifest() -> Dictionary:
	return {
		"schema_version": Constants.MANIFEST_SCHEMA_VERSION,
		"app_id": "",
		"channel": Constants.channel(),
		"version": "",
		"content_version": "",
		"protocol_version": Constants.protocol_version(),
		"packages": [],
	}


static func _root(root_path: String) -> String:
	return Constants.USER_ROOT if root_path.strip_edges().is_empty() else root_path.strip_edges()


static func _package_file_name(package: Dictionary) -> String:
	var file_name := str(package.get("file_name", "")).strip_edges()
	if not file_name.is_empty():
		return _sanitize_file_component(file_name)
	var source := str(package.get("url", "")).strip_edges()
	if source.is_empty():
		source = str(package.get("id", "package")) + ".pck"
	var query_index := source.find("?")
	if query_index >= 0:
		source = source.substr(0, query_index)
	var slash_index := source.rfind("/")
	if slash_index >= 0:
		source = source.substr(slash_index + 1)
	if source.is_empty():
		source = str(package.get("id", "package")) + ".pck"
	return _sanitize_file_component(source)


static func _sanitize_file_component(value: String) -> String:
	var clean := ""
	for index: int in range(value.length()):
		var character := value[index]
		if _is_ascii_alnum(character) or character in [".", "-", "_"]:
			clean += character
		else:
			clean += "_"
	return clean if not clean.is_empty() else "package"


static func _is_ascii_alnum(character: String) -> bool:
	return (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9")
