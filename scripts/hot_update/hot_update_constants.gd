class_name HotUpdateConstants
extends RefCounted

const MANIFEST_SCHEMA_VERSION := 1
const DEFAULT_CHANNEL := "dev"
const DEFAULT_PROTOCOL_VERSION := 1
const USER_ROOT := "user://hot_update"
const PACKAGE_DIR := "packages"
const TEMP_DIR := "tmp"
const INSTALLED_MANIFEST_FILE := "installed_manifest.json"
const ENV_ENABLED := "MAOMAO_UPDATE_ENABLED"
const ENV_MANIFEST_URL := "MAOMAO_UPDATE_MANIFEST_URL"
const ENV_MANIFEST_MIRROR_URLS := "MAOMAO_UPDATE_MANIFEST_MIRROR_URLS"

const SETTING_ENABLED := "hot_update/enabled"
const SETTING_SERVER_ENABLED := "hot_update/server_enabled"
const SETTING_AUTO_CHECK_ON_BOOT := "hot_update/auto_check_on_boot"
const SETTING_LOAD_INSTALLED_ON_BOOT := "hot_update/load_installed_packs_on_boot"
const SETTING_SHOW_STATUS_OVERLAY := "hot_update/show_status_overlay"
const SETTING_MANIFEST_URL := "hot_update/manifest_url"
const SETTING_MANIFEST_MIRROR_URLS := "hot_update/manifest_mirror_urls"
const SETTING_CHANNEL := "hot_update/channel"
const SETTING_PROTOCOL_VERSION := "hot_update/protocol_version"
const SETTING_HTTP_TIMEOUT_SEC := "hot_update/http_timeout_sec"
const SETTING_PACKAGE_TIMEOUT_SEC := "hot_update/package_timeout_sec"
const SETTING_DOWNLOAD_CHUNK_SIZE_BYTES := "hot_update/download_chunk_size_bytes"

const PUBLIC_SERVER_ARGS := [
	"--maomao-public-server",
	"--public-server",
	"--maomao-room-server",
]


static func app_version() -> String:
	var setting_version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if not setting_version.is_empty():
		return setting_version
	if FileAccess.file_exists("res://VERSION"):
		var file_version := FileAccess.get_file_as_string("res://VERSION").strip_edges()
		if not file_version.is_empty():
			return file_version
	return "dev"


static func channel() -> String:
	var value := _setting_string(SETTING_CHANNEL, DEFAULT_CHANNEL)
	return DEFAULT_CHANNEL if value.is_empty() else value


static func protocol_version() -> int:
	return _setting_int(SETTING_PROTOCOL_VERSION, DEFAULT_PROTOCOL_VERSION)


static func manifest_url() -> String:
	var env_url := OS.get_environment(ENV_MANIFEST_URL).strip_edges()
	if not env_url.is_empty():
		return env_url
	return _setting_string(SETTING_MANIFEST_URL, "")


static func manifest_urls() -> Array[String]:
	var result: Array[String] = []
	_append_unique_string(result, manifest_url())
	for mirror_url in manifest_mirror_urls():
		_append_unique_string(result, mirror_url)
	return result


static func manifest_mirror_urls() -> Array[String]:
	var result: Array[String] = []
	var env_urls := OS.get_environment(ENV_MANIFEST_MIRROR_URLS).strip_edges()
	if not env_urls.is_empty():
		for value in _split_url_list(env_urls):
			_append_unique_string(result, value)
	var setting_value: Variant = ProjectSettings.get_setting(SETTING_MANIFEST_MIRROR_URLS, [])
	for value in _variant_to_string_array(setting_value):
		_append_unique_string(result, value)
	return result


static func is_enabled() -> bool:
	return _environment_bool(ENV_ENABLED, _setting_bool(SETTING_ENABLED, true))


static func should_auto_check_on_boot() -> bool:
	return _setting_bool(SETTING_AUTO_CHECK_ON_BOOT, false)


static func should_load_installed_on_boot() -> bool:
	var default_value := not OS.has_feature("editor")
	return _setting_bool(SETTING_LOAD_INSTALLED_ON_BOOT, default_value)


static func should_show_status_overlay() -> bool:
	return _setting_bool(SETTING_SHOW_STATUS_OVERLAY, false)


static func http_timeout_sec() -> float:
	return maxf(0.0, _setting_float(SETTING_HTTP_TIMEOUT_SEC, 30.0))


static func package_timeout_sec() -> float:
	return maxf(0.0, _setting_float(SETTING_PACKAGE_TIMEOUT_SEC, 0.0))


static func download_chunk_size_bytes() -> int:
	return clampi(_setting_int(SETTING_DOWNLOAD_CHUNK_SIZE_BYTES, 1048576), 4096, 16777216)


static func is_public_server_context() -> bool:
	if OS.get_environment("MAOMAO_PUBLIC_SERVER") == "1" or OS.get_environment("MAOMAO_ROOM_SERVER") == "1":
		return true
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg in args:
		if PUBLIC_SERVER_ARGS.has(str(arg)):
			return true
	return false


static func can_run_in_current_context() -> bool:
	if not is_enabled():
		return false
	if is_public_server_context() and not _setting_bool(SETTING_SERVER_ENABLED, false):
		return false
	return true


static func user_subdir(path_name: String) -> String:
	return USER_ROOT.path_join(path_name)


static func _setting_string(key: String, fallback: String) -> String:
	return str(ProjectSettings.get_setting(key, fallback)).strip_edges()


static func _setting_bool(key: String, fallback: bool) -> bool:
	var value: Variant = ProjectSettings.get_setting(key, fallback)
	if value is bool:
		return bool(value)
	return _parse_bool(str(value), fallback)


static func _setting_int(key: String, fallback: int) -> int:
	var value: Variant = ProjectSettings.get_setting(key, fallback)
	if value is int:
		return int(value)
	var text := str(value)
	return text.to_int() if text.is_valid_int() else fallback


static func _setting_float(key: String, fallback: float) -> float:
	var value: Variant = ProjectSettings.get_setting(key, fallback)
	if value is float or value is int:
		return float(value)
	var parsed := str(value).to_float()
	return parsed if parsed > 0.0 else fallback


static func _environment_bool(key: String, fallback: bool) -> bool:
	var value := OS.get_environment(key).strip_edges()
	if value.is_empty():
		return fallback
	return _parse_bool(value, fallback)


static func _parse_bool(value: String, fallback: bool) -> bool:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["1", "true", "yes", "on", "enabled"]:
		return true
	if normalized in ["0", "false", "no", "off", "disabled"]:
		return false
	return fallback


static func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value as PackedStringArray:
			_append_unique_string(result, str(item))
	elif value is Array:
		for item in value as Array:
			_append_unique_string(result, str(item))
	else:
		for item in _split_url_list(str(value)):
			_append_unique_string(result, item)
	return result


static func _split_url_list(value: String) -> Array[String]:
	var result: Array[String] = []
	for item in value.replace(";", ",").split(",", false):
		var clean := str(item).strip_edges()
		if not clean.is_empty():
			result.append(clean)
	return result


static func _append_unique_string(target: Array[String], value: String) -> void:
	var clean := value.strip_edges()
	if clean.is_empty() or target.has(clean):
		return
	target.append(clean)
