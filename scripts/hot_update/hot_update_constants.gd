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

const SETTING_ENABLED := "hot_update/enabled"
const SETTING_SERVER_ENABLED := "hot_update/server_enabled"
const SETTING_AUTO_CHECK_ON_BOOT := "hot_update/auto_check_on_boot"
const SETTING_LOAD_INSTALLED_ON_BOOT := "hot_update/load_installed_packs_on_boot"
const SETTING_SHOW_STATUS_OVERLAY := "hot_update/show_status_overlay"
const SETTING_MANIFEST_URL := "hot_update/manifest_url"
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


static func is_enabled() -> bool:
	return _environment_bool(ENV_ENABLED, _setting_bool(SETTING_ENABLED, true))


static func should_auto_check_on_boot() -> bool:
	return _setting_bool(SETTING_AUTO_CHECK_ON_BOOT, false)


static func should_load_installed_on_boot() -> bool:
	return _setting_bool(SETTING_LOAD_INSTALLED_ON_BOOT, true)


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
	var value := str(ProjectSettings.get_setting(key, fallback)).strip_edges()
	return int(value) if value.is_valid_int() else fallback


static func _setting_float(key: String, fallback: float) -> float:
	var value := str(ProjectSettings.get_setting(key, fallback)).strip_edges()
	return float(value) if value.is_valid_float() else fallback


static func _environment_bool(env_name: String, fallback: bool) -> bool:
	var value := OS.get_environment(env_name).strip_edges()
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
