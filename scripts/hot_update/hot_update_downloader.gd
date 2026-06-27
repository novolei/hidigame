class_name HotUpdateDownloader
extends Node

signal manifest_downloaded(url: String, result: Dictionary)
signal package_downloaded(package: Dictionary, temp_path: String)
signal package_failed(package: Dictionary, message: String)
signal package_progress(package: Dictionary, downloaded_bytes: int, total_bytes: int, status: int)

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")

var _request: HTTPRequest
var _operation := ""
var _manifest_url := ""
var _active_package: Dictionary = {}
var _active_temp_path := ""
var _progress_timer: Timer


func _ready() -> void:
	_ensure_request()


func fetch_manifest(url: String) -> bool:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		manifest_downloaded.emit(clean_url, {
			"ok": false,
			"error": "Manifest URL is empty.",
			"body": "",
		})
		return false
	_ensure_request()
	if _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_request.cancel_request()
	_operation = "manifest"
	_manifest_url = clean_url
	_active_package.clear()
	_active_temp_path = ""
	_request.download_file = ""
	_request.timeout = Constants.http_timeout_sec()
	var error := _request.request(clean_url)
	if error != OK:
		manifest_downloaded.emit(clean_url, {
			"ok": false,
			"error": "Manifest request failed to start: %s" % error_string(error),
			"body": "",
		})
		return false
	return true


func download_package(package: Dictionary, url: String, temp_path: String) -> bool:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		package_failed.emit(package, "Package URL is empty.")
		return false
	DirAccess.make_dir_recursive_absolute(temp_path.get_base_dir())
	_ensure_request()
	if _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_request.cancel_request()
	_operation = "package"
	_manifest_url = ""
	_active_package = package.duplicate(true)
	_active_temp_path = temp_path
	_request.download_file = temp_path
	_request.timeout = Constants.package_timeout_sec()
	_request.download_chunk_size = Constants.download_chunk_size_bytes()
	var error := _request.request(clean_url)
	if error != OK:
		package_failed.emit(package, "Package request failed to start: %s" % error_string(error))
		return false
	_start_progress_timer()
	return true


func _ensure_request() -> void:
	if _request != null and is_instance_valid(_request):
		return
	_request = HTTPRequest.new()
	_request.name = "HotUpdateHTTPRequest"
	_request.timeout = Constants.http_timeout_sec()
	_request.use_threads = true
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	_ensure_progress_timer()


func _ensure_progress_timer() -> void:
	if _progress_timer != null and is_instance_valid(_progress_timer):
		return
	_progress_timer = Timer.new()
	_progress_timer.name = "HotUpdateProgressTimer"
	_progress_timer.wait_time = 0.5
	_progress_timer.one_shot = false
	_progress_timer.timeout.connect(_on_progress_timer_timeout)
	add_child(_progress_timer)


func _start_progress_timer() -> void:
	_ensure_progress_timer()
	_progress_timer.start()


func _stop_progress_timer() -> void:
	if _progress_timer != null and is_instance_valid(_progress_timer):
		_progress_timer.stop()


func _on_progress_timer_timeout() -> void:
	if _operation != "package" or _request == null or not is_instance_valid(_request):
		_stop_progress_timer()
		return
	package_progress.emit(
		_active_package.duplicate(true),
		_request.get_downloaded_bytes(),
		_request.get_body_size(),
		_request.get_http_client_status()
	)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_stop_progress_timer()
	var completed_operation: String = _operation
	_operation = ""
	_request.download_file = ""
	if completed_operation == "manifest":
		_finish_manifest(result, response_code, body)
	elif completed_operation == "package":
		_finish_package(result, response_code)


func _finish_manifest(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		manifest_downloaded.emit(_manifest_url, {
			"ok": false,
			"error": "Manifest download failed: %s" % result,
			"body": "",
		})
		return
	if response_code < 200 or response_code >= 300:
		manifest_downloaded.emit(_manifest_url, {
			"ok": false,
			"error": "Manifest request returned HTTP %d." % response_code,
			"body": "",
		})
		return
	manifest_downloaded.emit(_manifest_url, {
		"ok": true,
		"error": "",
		"body": body.get_string_from_utf8(),
	})


func _finish_package(result: int, response_code: int) -> void:
	var package := _active_package.duplicate(true)
	if result != HTTPRequest.RESULT_SUCCESS:
		package_failed.emit(package, "Package download failed: %s" % result)
		return
	if response_code < 200 or response_code >= 300:
		package_failed.emit(package, "Package request returned HTTP %d." % response_code)
		return
	package_downloaded.emit(package, _active_temp_path)
