extends RefCounted
class_name ChameleonSculptUGC

const SHARE_PREFIX := "HIDI-CLAY-1:"
const DEFAULT_LIBRARY_PATH := "user://chameleon_sculpt_creations.json"
const MAX_CREATION_NAME_LENGTH := 40
const MAX_SHARE_CODE_CHARS := 1048576
const MAX_BODY_JSON_BYTES := 524288


static func make_creation(name: String, shell: Node, author_id: String = "") -> Dictionary:
	var body := {}
	if shell and shell.has_method("make_compact_body"):
		body = shell.call("make_compact_body")
	var clean_name := _sanitize_name(name)
	return {
		"id": _creation_id(clean_name, body),
		"name": clean_name,
		"author_id": author_id,
		"created_at_unix": Time.get_unix_time_from_system(),
		"body": body,
		"likes": 0,
		"downloads": 0,
	}


static func encode_share_code(creation: Dictionary) -> String:
	var json := JSON.stringify(_sanitize_creation(creation, true))
	var bytes := json.to_utf8_buffer()
	return SHARE_PREFIX + Marshalls.raw_to_base64(bytes)


static func decode_share_code(code: String) -> Dictionary:
	var clean := code.strip_edges()
	if clean.begins_with(SHARE_PREFIX):
		clean = clean.substr(SHARE_PREFIX.length())
	if clean.length() > MAX_SHARE_CODE_CHARS:
		return {}
	var bytes := Marshalls.base64_to_raw(clean)
	if bytes.is_empty():
		return {}
	var json := bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(json)
	if not parsed is Dictionary:
		return {}
	return _sanitize_creation(parsed, true)


static func load_library(path: String = DEFAULT_LIBRARY_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return []
	var creations := []
	for item in parsed:
		if item is Dictionary:
			creations.append(_sanitize_creation(item))
	return creations


static func save_library(creations: Array, path: String = DEFAULT_LIBRARY_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var clean := []
	for item in creations:
		if item is Dictionary:
			clean.append(_sanitize_creation(item))
	file.store_string(JSON.stringify(clean, "\t"))
	return true


static func upsert_creation(creations: Array, creation: Dictionary) -> Array:
	var clean_creation := _sanitize_creation(creation)
	var id := str(clean_creation.get("id", ""))
	var result := []
	var replaced := false
	for item in creations:
		if not item is Dictionary:
			continue
		var clean_item := _sanitize_creation(item)
		if str(clean_item.get("id", "")) == id:
			result.append(clean_creation)
			replaced = true
		else:
			result.append(clean_item)
	if not replaced:
		result.append(clean_creation)
	return result


static func import_share_code_to_library(code: String, path: String = DEFAULT_LIBRARY_PATH) -> Dictionary:
	var creation := decode_share_code(code)
	if creation.is_empty():
		return {}
	var creations := upsert_creation(load_library(path), creation)
	save_library(creations, path)
	return creation


static func like_by_id(creations: Array, creation_id: String) -> Array:
	return _increment_stat(creations, creation_id, "likes")


static func mark_downloaded_by_id(creations: Array, creation_id: String) -> Array:
	return _increment_stat(creations, creation_id, "downloads")


static func leaderboard(creations: Array, limit: int = 20) -> Array:
	var clean := []
	for item in creations:
		if item is Dictionary:
			clean.append(_sanitize_creation(item))
	clean.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_likes := int(a.get("likes", 0))
		var b_likes := int(b.get("likes", 0))
		if a_likes != b_likes:
			return a_likes > b_likes
		var a_downloads := int(a.get("downloads", 0))
		var b_downloads := int(b.get("downloads", 0))
		if a_downloads != b_downloads:
			return a_downloads > b_downloads
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return clean.slice(0, max(0, limit))


static func _increment_stat(creations: Array, creation_id: String, stat_name: String) -> Array:
	var result := []
	for item in creations:
		if not item is Dictionary:
			continue
		var clean := _sanitize_creation(item)
		if str(clean.get("id", "")) == creation_id:
			clean[stat_name] = int(clean.get(stat_name, 0)) + 1
		result.append(clean)
	return result


static func _sanitize_creation(creation: Dictionary, reset_social_stats: bool = false) -> Dictionary:
	var body = creation.get("body", {})
	if not body is Dictionary:
		body = {}
	elif JSON.stringify(body).to_utf8_buffer().size() > MAX_BODY_JSON_BYTES:
		body = {}
	var clean := {
		"id": str(creation.get("id", "")),
		"name": _sanitize_name(str(creation.get("name", "Unnamed"))),
		"author_id": str(creation.get("author_id", "")),
		"created_at_unix": int(creation.get("created_at_unix", 0)),
		"body": body,
		"likes": 0 if reset_social_stats else max(0, int(creation.get("likes", 0))),
		"downloads": 0 if reset_social_stats else max(0, int(creation.get("downloads", 0))),
	}
	if str(clean.get("id", "")).is_empty():
		clean["id"] = _creation_id(str(clean.get("name", "Unnamed")), body)
	return clean


static func _sanitize_name(name: String) -> String:
	var clean := name.strip_edges()
	if clean.is_empty():
		clean = "Unnamed"
	if clean.length() > MAX_CREATION_NAME_LENGTH:
		clean = clean.substr(0, MAX_CREATION_NAME_LENGTH)
	return clean


static func _creation_id(name: String, body: Dictionary) -> String:
	var payload := name + ":" + JSON.stringify(body)
	return "%08x" % [payload.hash()]
