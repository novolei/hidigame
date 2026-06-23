class_name Hunyuan3DService
extends Node

signal job_submitted(job_id: String)
signal job_status_changed(status: String, payload: Dictionary)
signal generation_ready(result: Dictionary)
signal generation_failed(message: String)

const DIRECT_SUBMIT_URL := "https://api.ai3d.cloud.tencent.com/v1/ai3d/submit"
const DIRECT_QUERY_URL := "https://api.ai3d.cloud.tencent.com/v1/ai3d/query"
const POLL_SECONDS := 3.0
const DEFAULT_FACE_COUNT := 30000

var proxy_url := ""
var api_key_env_name := "HUNYUAN_3D_API_KEY"
var last_job_id := ""
var last_error := ""

var _submit_request: HTTPRequest
var _query_request: HTTPRequest
var _download_request: HTTPRequest
var _poll_timer: Timer
var _mode := ""
var _pending_result: Dictionary = {}
var _pending_download_type := ""


func _ready() -> void:
	_ensure_nodes()


func configure(proxy_endpoint: String = "", env_name: String = "HUNYUAN_3D_API_KEY") -> void:
	proxy_url = proxy_endpoint.strip_edges()
	api_key_env_name = env_name


func is_configured() -> bool:
	return not _resolve_proxy_url().is_empty() or not _resolve_api_key().is_empty()


func submit_capture(image: Image, prompt: String = "") -> bool:
	_ensure_nodes()
	last_error = ""
	if not image:
		_fail("No capture image was provided.")
		return false
	var buffer := image.save_png_to_buffer()
	if buffer.is_empty():
		_fail("Could not encode capture image.")
		return false
	var encoded := Marshalls.raw_to_base64(buffer)
	var clean_prompt := prompt.strip_edges()
	if clean_prompt.is_empty():
		clean_prompt = "Generate one low-poly standalone white 3D prop that naturally fits the captured game scene. Keep it compact, readable, and easy for a player to paint."
	var payload := {
		"ImageUrl": {"Url": "data:image/png;base64,%s" % encoded},
		"GenerateType": "Geometry",
		"FaceCount": DEFAULT_FACE_COUNT,
		"ResultFormat": "GLB"
	}
	var proxy := _resolve_proxy_url()
	if not proxy.is_empty():
		_mode = "proxy"
		var proxy_payload := payload.duplicate(true)
		proxy_payload["source"] = "chameleon_environment_blend"
		proxy_payload["PromptHint"] = clean_prompt
		return _post_json(_submit_request, proxy.trim_suffix("/") + "/submit", proxy_payload, [])
	var api_key := _resolve_api_key()
	if api_key.is_empty():
		_fail("Hunyuan 3D is not configured. Set HUNYUAN_3D_PROXY_URL or HUNYUAN_3D_API_KEY.")
		return false
	_mode = "direct"
	return _post_json(_submit_request, DIRECT_SUBMIT_URL, payload, ["Authorization: %s" % api_key])


func poll_job(job_id: String = "") -> bool:
	_ensure_nodes()
	var id := job_id if not job_id.is_empty() else last_job_id
	if id.is_empty():
		return false
	var proxy := _resolve_proxy_url()
	if _mode == "proxy" and not proxy.is_empty():
		return _post_json(_query_request, proxy.trim_suffix("/") + "/query", {"JobId": id}, [])
	var api_key := _resolve_api_key()
	if api_key.is_empty():
		_fail("Hunyuan 3D query is not configured.")
		return false
	return _post_json(_query_request, DIRECT_QUERY_URL, {"JobId": id}, ["Authorization: %s" % api_key])


func _ensure_nodes() -> void:
	if not _submit_request:
		_submit_request = HTTPRequest.new()
		_submit_request.name = "HunyuanSubmitRequest"
		add_child(_submit_request)
		_submit_request.request_completed.connect(_on_submit_completed)
	if not _query_request:
		_query_request = HTTPRequest.new()
		_query_request.name = "HunyuanQueryRequest"
		add_child(_query_request)
		_query_request.request_completed.connect(_on_query_completed)
	if not _download_request:
		_download_request = HTTPRequest.new()
		_download_request.name = "HunyuanDownloadRequest"
		add_child(_download_request)
		_download_request.request_completed.connect(_on_download_completed)
	if not _poll_timer:
		_poll_timer = Timer.new()
		_poll_timer.name = "HunyuanPollTimer"
		_poll_timer.one_shot = false
		_poll_timer.wait_time = POLL_SECONDS
		add_child(_poll_timer)
		_poll_timer.timeout.connect(func(): poll_job())


func _post_json(request_node: HTTPRequest, url: String, payload: Dictionary, extra_headers: Array) -> bool:
	var headers := ["Content-Type: application/json"]
	for header in extra_headers:
		headers.append(str(header))
	var body := JSON.stringify(payload)
	var err := request_node.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_fail("HTTP request failed to start: %s" % error_string(err))
		return false
	return true


func _on_submit_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload: Dictionary = _parse_response(result, response_code, body)
	if payload.is_empty():
		return
	var response: Dictionary = payload.get("Response", payload) as Dictionary
	var job_id := str(response.get("JobId", response.get("job_id", "")))
	if job_id.is_empty():
		_fail(str(response.get("ErrorMessage", "Hunyuan submit response did not include JobId.")))
		return
	last_job_id = job_id
	job_submitted.emit(job_id)
	_poll_timer.start()


func _on_query_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload: Dictionary = _parse_response(result, response_code, body)
	if payload.is_empty():
		return
	var response: Dictionary = payload.get("Response", payload) as Dictionary
	var status := str(response.get("Status", response.get("status", ""))).to_upper()
	job_status_changed.emit(status, response)
	if status == "WAIT" or status == "RUN":
		return
	_poll_timer.stop()
	if status == "DONE":
		if not _try_download_best_result(response):
			generation_ready.emit(response)
	else:
		_fail(str(response.get("ErrorMessage", "Hunyuan generation failed.")))


func _try_download_best_result(response: Dictionary) -> bool:
	var files = response.get("ResultFile3Ds", response.get("result_file_3ds", []))
	if not files is Array:
		return false
	for file in files:
		if not file is Dictionary:
			continue
		var info := file as Dictionary
		var url := str(info.get("Url", info.get("url", ""))).strip_edges()
		if url.is_empty():
			continue
		var type := str(info.get("Type", info.get("type", ""))).to_upper()
		var lower_url := url.to_lower()
		if type != "GLB" and not lower_url.ends_with(".glb"):
			continue
		_pending_result = response.duplicate(true)
		_pending_download_type = "GLB"
		var err := _download_request.request(url)
		if err != OK:
			_fail("Could not start generated GLB download: %s" % error_string(err))
			return false
		return true
	return false


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Generated model download failed: %s" % result)
		return
	if response_code < 200 or response_code >= 300:
		_fail("Generated model download returned HTTP %d." % response_code)
		return
	var dir := "user://hunyuan_3d"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file_name := "%s.%s" % [last_job_id if not last_job_id.is_empty() else str(Time.get_ticks_msec()), _pending_download_type.to_lower()]
	var local_path := "%s/%s" % [dir, file_name]
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if not file:
		_fail("Could not save generated model to user storage.")
		return
	file.store_buffer(body)
	file.close()
	var ready_result := _pending_result.duplicate(true)
	ready_result["local_model_path"] = local_path
	ready_result["local_model_type"] = _pending_download_type
	_pending_result.clear()
	_pending_download_type = ""
	generation_ready.emit(ready_result)


func _parse_response(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("HTTP request failed: %s" % result)
		return {}
	if response_code < 200 or response_code >= 300:
		_fail("HTTP %d: %s" % [response_code, body.get_string_from_utf8()])
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Response was not a JSON object.")
		return {}
	return parsed as Dictionary


func _resolve_proxy_url() -> String:
	if not proxy_url.is_empty():
		return proxy_url
	return OS.get_environment("HUNYUAN_3D_PROXY_URL").strip_edges()


func _resolve_api_key() -> String:
	return OS.get_environment(api_key_env_name).strip_edges()


func _fail(message: String) -> void:
	last_error = message
	if _poll_timer:
		_poll_timer.stop()
	generation_failed.emit(message)
