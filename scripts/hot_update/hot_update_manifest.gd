class_name HotUpdateManifest
extends RefCounted

const Constants := preload("res://scripts/hot_update/hot_update_constants.gd")

const PACKAGE_TYPES := ["base", "content", "patch", "delta", "launcher"]


static func parse_json_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		return {
			"ok": false,
			"error": "Manifest JSON parse failed at line %d: %s" % [parser.get_error_line(), parser.get_error_message()],
			"manifest": {},
			"errors": [],
		}
	if not parser.data is Dictionary:
		return {
			"ok": false,
			"error": "Manifest root must be a JSON object.",
			"manifest": {},
			"errors": [],
		}
	var manifest: Dictionary = parser.data
	var errors := validate(manifest)
	return {
		"ok": errors.is_empty(),
		"error": "" if errors.is_empty() else "Manifest validation failed.",
		"manifest": manifest,
		"errors": errors,
	}


static func validate(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", 0)) != Constants.MANIFEST_SCHEMA_VERSION:
		errors.append("schema_version must be %d." % Constants.MANIFEST_SCHEMA_VERSION)
	_require_string(manifest, "app_id", errors)
	_require_string(manifest, "channel", errors)
	_require_string(manifest, "version", errors)
	if int(manifest.get("protocol_version", 0)) <= 0:
		errors.append("protocol_version must be a positive integer.")
	var packages_value: Variant = manifest.get("packages", [])
	if not packages_value is Array:
		errors.append("packages must be an array.")
		return errors
	var ids: Dictionary = {}
	var packages: Array = packages_value
	for index: int in range(packages.size()):
		var value: Variant = packages[index]
		if not value is Dictionary:
			errors.append("packages[%d] must be an object." % index)
			continue
		var package: Dictionary = value
		var id := str(package.get("id", "")).strip_edges()
		if id.is_empty():
			errors.append("packages[%d].id is required." % index)
		elif ids.has(id):
			errors.append("Duplicate package id: %s." % id)
		else:
			ids[id] = true
		_require_string(package, "version", errors, "packages[%d]" % index)
		var package_type := str(package.get("type", "patch")).strip_edges()
		if not PACKAGE_TYPES.has(package_type):
			errors.append("packages[%d].type must be one of %s." % [index, str(PACKAGE_TYPES)])
		var url := str(package.get("url", "")).strip_edges()
		var local_path := str(package.get("local_path", "")).strip_edges()
		if url.is_empty() and local_path.is_empty():
			errors.append("packages[%d] must define url or local_path." % index)
		var sha := str(package.get("sha256", "")).strip_edges().to_lower()
		if sha.length() != 64:
			errors.append("packages[%d].sha256 must be a 64-character SHA-256 hex string." % index)
		elif not _is_hex_string(sha):
			errors.append("packages[%d].sha256 contains non-hex characters." % index)
		if int(package.get("size_bytes", 0)) < 0:
			errors.append("packages[%d].size_bytes must not be negative." % index)
		var dependencies: Variant = package.get("dependencies", [])
		if not dependencies is Array:
			errors.append("packages[%d].dependencies must be an array when present." % index)
	return errors


static func compatibility_errors(manifest: Dictionary, app_version: String, protocol_version: int) -> Array[String]:
	var errors: Array[String] = []
	var manifest_channel := str(manifest.get("channel", "")).strip_edges()
	if not manifest_channel.is_empty() and manifest_channel != Constants.channel():
		errors.append("Manifest channel '%s' does not match client channel '%s'." % [manifest_channel, Constants.channel()])
	var min_app_version := str(manifest.get("min_app_version", "")).strip_edges()
	if not min_app_version.is_empty() and compare_versions(app_version, min_app_version) < 0:
		errors.append("Client version %s is older than required minimum %s." % [app_version, min_app_version])
	var manifest_protocol := int(manifest.get("protocol_version", protocol_version))
	if manifest_protocol != protocol_version:
		errors.append("Manifest protocol %d does not match client protocol %d." % [manifest_protocol, protocol_version])
	return errors


static func required_packages(remote_manifest: Dictionary, installed_manifest: Dictionary, include_optional: bool = false) -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	var installed_map := installed_package_map(installed_manifest)
	for package in sorted_packages(remote_manifest):
		var package_type := str(package.get("type", "patch"))
		if package_type == "launcher":
			continue
		if not include_optional and not bool(package.get("required", true)):
			continue
		var id := str(package.get("id", ""))
		var installed_package: Dictionary = installed_map.get(id, {})
		var remote_sha := str(package.get("sha256", "")).to_lower()
		var installed_sha := str(installed_package.get("sha256", "")).to_lower()
		var remote_version := str(package.get("version", ""))
		var installed_version := str(installed_package.get("version", ""))
		if installed_sha != remote_sha or installed_version != remote_version:
			pending.append(package.duplicate(true))
	return pending


static func installed_package_map(installed_manifest: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var packages_value: Variant = installed_manifest.get("packages", [])
	if not packages_value is Array:
		return result
	var packages: Array = packages_value
	for value in packages:
		if not value is Dictionary:
			continue
		var package: Dictionary = value
		var id := str(package.get("id", "")).strip_edges()
		if not id.is_empty():
			result[id] = package
	return result


static func sorted_packages(manifest: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var packages_value: Variant = manifest.get("packages", [])
	if not packages_value is Array:
		return result
	for value in packages_value:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_order := int(a.get("load_order", 1000))
		var right_order := int(b.get("load_order", 1000))
		if left_order == right_order:
			return str(a.get("id", "")) < str(b.get("id", ""))
		return left_order < right_order
	)
	return result


static func package_url(manifest: Dictionary, package: Dictionary, manifest_url: String = "") -> String:
	var url := str(package.get("url", "")).strip_edges()
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	var base_url := str(manifest.get("base_url", "")).strip_edges()
	if base_url.is_empty():
		base_url = _directory_url(manifest_url)
	if base_url.is_empty():
		return url
	return base_url.trim_suffix("/") + "/" + url.trim_prefix("/")


static func compare_versions(left: String, right: String) -> int:
	var left_parts := left.strip_edges().split(".", false)
	var right_parts := right.strip_edges().split(".", false)
	var part_count := maxi(left_parts.size(), right_parts.size())
	for index: int in range(part_count):
		var left_part := _version_part(left_parts[index]) if index < left_parts.size() else 0
		var right_part := _version_part(right_parts[index]) if index < right_parts.size() else 0
		if left_part < right_part:
			return -1
		if left_part > right_part:
			return 1
	return 0


static func _version_part(value: String) -> int:
	var digits := ""
	for index: int in range(value.length()):
		var character := value[index]
		if character >= "0" and character <= "9":
			digits += character
		else:
			break
	return int(digits) if digits.is_valid_int() else 0


static func _require_string(data: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	var label := key if prefix.is_empty() else "%s.%s" % [prefix, key]
	if str(data.get(key, "")).strip_edges().is_empty():
		errors.append("%s is required." % label)


static func _is_hex_string(value: String) -> bool:
	for index: int in range(value.length()):
		var character := value[index].to_lower()
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")):
			return false
	return true


static func _directory_url(url: String) -> String:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		return ""
	var slash_index := clean_url.rfind("/")
	if slash_index < 0:
		return ""
	return clean_url.substr(0, slash_index)
