class_name HotUpdateManager
extends Node

signal status_changed(message: String)
signal manifest_ready(manifest: Dictionary, pending_packages: Array)
signal update_failed(message: String)
signal update_installed(restart_required: bool)

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")
const Manifest := preload("res://scripts/hot_update/hot_update_manifest.gd")
const Store := preload("res://scripts/hot_update/hot_update_store.gd")
const DownloaderScript := preload("res://scripts/hot_update/hot_update_downloader.gd")
const StatusOverlayScript := preload("res://scripts/hot_update/hot_update_status_overlay.gd")

var remote_manifest: Dictionary = {}
var pending_packages: Array[Dictionary] = []
var installed_packages: Array[Dictionary] = []
var last_error := ""
var loaded_local_packages: Array[String] = []

var _downloader: HotUpdateDownloader
var _manifest_url := ""
var _install_index := 0
var _restart_required := false
var _status_overlay: CanvasLayer
var _last_progress_package_id := ""
var _last_progress_percent := -1
var _include_optional_packages := false


func _enter_tree() -> void:
	if not Constants.can_run_in_current_context():
		return
	Store.ensure_directories()
	if Constants.should_load_installed_on_boot():
		var result := Store.load_installed_packs()
		loaded_local_packages = result.get("loaded", []) as Array[String]
		var failed: Array = result.get("failed", []) as Array
		if not failed.is_empty():
			status_changed.emit("Some installed update packs failed to load: %s" % str(failed))


func _ready() -> void:
	if not Constants.can_run_in_current_context():
		return
	if Constants.should_show_status_overlay():
		_ensure_status_overlay()
	if Constants.should_auto_check_on_boot():
		check_for_updates()


func check_for_updates(manifest_url: String = "", include_optional_packages: bool = false) -> bool:
	if not Constants.can_run_in_current_context():
		last_error = "Hot update is disabled in this runtime context."
		update_failed.emit(last_error)
		return false
	_include_optional_packages = include_optional_packages
	if Constants.should_show_status_overlay():
		_ensure_status_overlay()
	_manifest_url = manifest_url.strip_edges()
	if _manifest_url.is_empty():
		_manifest_url = Constants.manifest_url()
	if _manifest_url.is_empty():
		last_error = "No hot update manifest URL is configured."
		update_failed.emit(last_error)
		return false
	_ensure_downloader()
	status_changed.emit("Checking update manifest.")
	return _downloader.fetch_manifest(_manifest_url)


func install_pending_updates() -> bool:
	if remote_manifest.is_empty():
		last_error = "No remote manifest has been checked yet."
		update_failed.emit(last_error)
		return false
	if pending_packages.is_empty():
		update_installed.emit(false)
		return true
	_install_index = 0
	_restart_required = false
	installed_packages = _installed_package_list()
	_download_next_package()
	return true


func has_pending_updates() -> bool:
	return not pending_packages.is_empty()


func current_app_version() -> String:
	return Constants.app_version()


func _ensure_downloader() -> void:
	if _downloader != null and is_instance_valid(_downloader):
		return
	_downloader = DownloaderScript.new()
	_downloader.name = "HotUpdateDownloader"
	_downloader.manifest_downloaded.connect(_on_manifest_downloaded)
	_downloader.package_downloaded.connect(_on_package_downloaded)
	_downloader.package_failed.connect(_on_package_failed)
	_downloader.package_progress.connect(_on_package_progress)
	add_child(_downloader)


func _ensure_status_overlay() -> void:
	if _status_overlay != null and is_instance_valid(_status_overlay):
		return
	_status_overlay = StatusOverlayScript.new()
	_status_overlay.name = "HotUpdateStatusOverlay"
	add_child(_status_overlay)
	_status_overlay.call("bind", self)
	_status_overlay.call("show_idle")


func _on_manifest_downloaded(url: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		last_error = str(result.get("error", "Manifest download failed."))
		update_failed.emit(last_error)
		return
	var parsed := Manifest.parse_json_text(str(result.get("body", "")))
	if not bool(parsed.get("ok", false)):
		var errors: Array = parsed.get("errors", []) as Array
		last_error = str(parsed.get("error", "Manifest validation failed.")) + " " + str(errors)
		update_failed.emit(last_error)
		return
	var manifest: Dictionary = parsed.get("manifest", {}) as Dictionary
	var compatibility := Manifest.compatibility_errors(manifest, Constants.app_version(), Constants.protocol_version())
	if not compatibility.is_empty():
		last_error = str(compatibility)
		update_failed.emit(last_error)
		return
	remote_manifest = manifest
	var installed_manifest := Store.load_installed_manifest()
	pending_packages = Manifest.required_packages(remote_manifest, installed_manifest, _include_optional_packages)
	status_changed.emit("Update manifest checked: %d pending package(s)." % pending_packages.size())
	manifest_ready.emit(remote_manifest.duplicate(true), pending_packages.duplicate(true))


func _download_next_package() -> void:
	if _install_index >= pending_packages.size():
		var save_error := Store.save_installed_manifest(remote_manifest, installed_packages)
		if save_error != OK:
			last_error = "Could not save installed update manifest: %s" % error_string(save_error)
			update_failed.emit(last_error)
			return
		status_changed.emit("Update packages installed.")
		update_installed.emit(_restart_required)
		return
	var package: Dictionary = pending_packages[_install_index]
	var source_url := Manifest.package_url(remote_manifest, package, _manifest_url)
	var temp_path := Store.package_temp_path(package)
	_last_progress_package_id = str(package.get("id", ""))
	_last_progress_percent = -1
	status_changed.emit("Downloading update package %s (%d/%d)." % [_last_progress_package_id, _install_index + 1, pending_packages.size()])
	_ensure_downloader()
	_downloader.download_package(package, source_url, temp_path)


func _on_package_downloaded(package: Dictionary, temp_path: String) -> void:
	if not Store.verify_package_file(package, temp_path):
		last_error = "Downloaded package failed size or SHA-256 verification: %s" % str(package.get("id", ""))
		update_failed.emit(last_error)
		return
	var final_path := Store.package_local_path(package)
	var promote_error := Store.promote_temp_package(temp_path, final_path)
	if promote_error != OK:
		last_error = "Could not install package %s: %s" % [str(package.get("id", "")), error_string(promote_error)]
		update_failed.emit(last_error)
		return
	var installed_package := package.duplicate(true)
	installed_package["local_path"] = final_path
	installed_package["installed_at_unix"] = Time.get_unix_time_from_system()
	_replace_installed_package(installed_package)
	_restart_required = _restart_required or bool(package.get("restart_required", true))
	_install_index += 1
	_download_next_package()


func _on_package_failed(package: Dictionary, message: String) -> void:
	last_error = "Package %s failed: %s" % [str(package.get("id", "")), message]
	update_failed.emit(last_error)


func _on_package_progress(package: Dictionary, downloaded_bytes: int, total_bytes: int, status: int) -> void:
	var package_id := str(package.get("id", ""))
	if package_id.is_empty():
		package_id = _last_progress_package_id
	var percent := -1
	if total_bytes > 0:
		percent = int(floor(float(downloaded_bytes) * 100.0 / float(total_bytes)))
	var should_emit := package_id != _last_progress_package_id
	if percent >= 0:
		should_emit = should_emit or _last_progress_percent < 0 or percent >= _last_progress_percent + 5 or percent >= 100
	else:
		should_emit = should_emit or downloaded_bytes > 0
	if not should_emit:
		return
	_last_progress_package_id = package_id
	_last_progress_percent = percent
	if total_bytes > 0:
		status_changed.emit("Downloading %s: %d%% (%s / %s)." % [package_id, percent, _format_bytes(downloaded_bytes), _format_bytes(total_bytes)])
	else:
		status_changed.emit("Downloading %s: %s received (HTTP status %d)." % [package_id, _format_bytes(downloaded_bytes), status])


func _format_bytes(value: int) -> String:
	if value >= 1073741824:
		return "%.2f GB" % (float(value) / 1073741824.0)
	if value >= 1048576:
		return "%.2f MB" % (float(value) / 1048576.0)
	if value >= 1024:
		return "%.2f KB" % (float(value) / 1024.0)
	return "%d B" % value


func _installed_package_list() -> Array[Dictionary]:
	var installed_manifest := Store.load_installed_manifest()
	var result: Array[Dictionary] = []
	var packages: Variant = installed_manifest.get("packages", [])
	if packages is Array:
		for value in packages:
			if value is Dictionary:
				result.append((value as Dictionary).duplicate(true))
	return result


func _replace_installed_package(package: Dictionary) -> void:
	var id := str(package.get("id", ""))
	for index: int in range(installed_packages.size()):
		if str(installed_packages[index].get("id", "")) == id:
			installed_packages[index] = package
			return
	installed_packages.append(package)
