class_name HotUpdateManager
extends Node

signal status_changed(message: String)
signal manifest_ready(manifest: Dictionary, pending_packages: Array)
signal update_failed(message: String)
signal update_installed(restart_required: bool)
# Emitted when the client is too old to be brought current by patches (e.g. below the
# manifest min_app_version) but the manifest advertises a newer full client to download.
signal full_client_required(version: String, url: String, reason: String)

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
var full_client_info: Dictionary = {}

var _downloader: HotUpdateDownloader
var _manifest_url := ""
var _manifest_urls: Array[String] = []
var _manifest_url_index := 0
var _install_index := 0
var _restart_required := false
var _status_overlay: CanvasLayer
var _last_progress_package_id := ""
var _last_progress_percent := -1
var _include_optional_packages := false
var _active_package_urls: Array[String] = []
var _active_package_url_index := 0


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
	_manifest_urls = _candidate_manifest_urls(manifest_url)
	_manifest_url_index = 0
	if _manifest_urls.is_empty():
		last_error = "No hot update manifest URL is configured."
		update_failed.emit(last_error)
		return false
	_manifest_url = _manifest_urls[_manifest_url_index]
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


func _on_manifest_downloaded(_url: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		var download_error := str(result.get("error", "Manifest download failed."))
		if _try_next_manifest_url(download_error):
			return
		last_error = download_error
		update_failed.emit(last_error)
		return
	var parsed := Manifest.parse_json_text(str(result.get("body", "")))
	if not bool(parsed.get("ok", false)):
		var errors: Array = parsed.get("errors", []) as Array
		var parse_error := str(parsed.get("error", "Manifest validation failed.")) + " " + str(errors)
		if _try_next_manifest_url(parse_error):
			return
		last_error = parse_error
		update_failed.emit(last_error)
		return
	var manifest: Dictionary = parsed.get("manifest", {}) as Dictionary
	var advertised_full_client: Variant = manifest.get("full_client", {})
	full_client_info = advertised_full_client if advertised_full_client is Dictionary else {}
	var compatibility := Manifest.compatibility_errors(manifest, Constants.app_version(), Constants.protocol_version())
	if not compatibility.is_empty():
		var compatibility_error := str(compatibility)
		if _try_next_manifest_url(compatibility_error):
			return
		last_error = compatibility_error
		# Too old to patch: point the player at a full re-download when the manifest offers one,
		# instead of silently continuing on stale bundled content.
		var full_url := str(full_client_info.get("url", "")).strip_edges()
		if not full_url.is_empty():
			full_client_required.emit(str(full_client_info.get("version", "")), full_url, compatibility_error)
		update_failed.emit(last_error)
		return
	remote_manifest = manifest
	var installed_manifest := Store.load_installed_manifest()
	# Pass the bundled baseline version so packs at-or-below it are never pulled (a fresh full
	# baseline must not download an older core_patch it would only skip at mount).
	pending_packages = Manifest.required_packages(remote_manifest, installed_manifest, _include_optional_packages, BuildInfo.content_version())
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
	_active_package_urls = Manifest.package_urls(remote_manifest, package, _manifest_url)
	_active_package_url_index = 0
	if _active_package_urls.is_empty():
		last_error = "No download URL is available for package: %s" % str(package.get("id", ""))
		update_failed.emit(last_error)
		return
	_download_current_package_url(package)


func _download_current_package_url(package: Dictionary) -> void:
	var source_url := _active_package_urls[_active_package_url_index]
	var temp_path := Store.package_temp_path(package)
	_last_progress_package_id = str(package.get("id", ""))
	_last_progress_percent = -1
	var source_label := "primary" if _active_package_url_index == 0 else "mirror %d" % _active_package_url_index
	status_changed.emit("Downloading update package %s (%d/%d) from %s." % [_last_progress_package_id, _install_index + 1, pending_packages.size(), source_label])
	_ensure_downloader()
	_downloader.download_package(package, source_url, temp_path)


func _on_package_downloaded(package: Dictionary, temp_path: String) -> void:
	if not Store.verify_package_file(package, temp_path):
		var verify_error := "Downloaded package failed size or SHA-256 verification: %s" % str(package.get("id", ""))
		if _try_next_package_url(package, temp_path, verify_error):
			return
		last_error = verify_error
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
	var temp_path := Store.package_temp_path(package)
	if _try_next_package_url(package, temp_path, message):
		return
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


func _try_next_manifest_url(reason: String) -> bool:
	if _manifest_url_index + 1 >= _manifest_urls.size():
		return false
	_manifest_url_index += 1
	_manifest_url = _manifest_urls[_manifest_url_index]
	status_changed.emit("Manifest source failed (%s). Trying mirror %d/%d." % [reason, _manifest_url_index, _manifest_urls.size() - 1])
	return _downloader.fetch_manifest(_manifest_url)


func _try_next_package_url(package: Dictionary, temp_path: String, reason: String) -> bool:
	if _active_package_url_index + 1 >= _active_package_urls.size():
		return false
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	_active_package_url_index += 1
	status_changed.emit("Package %s source failed (%s). Trying mirror %d/%d." % [str(package.get("id", "")), reason, _active_package_url_index, _active_package_urls.size() - 1])
	_download_current_package_url(package)
	return true


func _candidate_manifest_urls(manifest_url: String) -> Array[String]:
	var result: Array[String] = []
	var clean_url := manifest_url.strip_edges()
	if not clean_url.is_empty():
		_append_unique_url(result, clean_url)
		return result
	for url in Constants.manifest_urls():
		_append_unique_url(result, url)
	return result


func _append_unique_url(target: Array[String], url: String) -> void:
	var clean_url := url.strip_edges()
	if clean_url.is_empty() or target.has(clean_url):
		return
	target.append(clean_url)


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
