extends RefCounted
class_name PartyMonsterAccessoryCatalog

const MANIFEST_PATH := "res://assets/characters/party_monster/party_monster_manifest.json"
const SLOT_EYES := "eyes"
const SLOT_MOUTH := "mouth"
const SLOT_NOSE := "nose"
const SLOT_HEAD := "head"
const SLOT_EARS := "ears"
const SLOT_GLOVES := "gloves"
const SLOT_TAIL := "tail"
const SLOT_ORDER := [SLOT_EYES, SLOT_MOUTH, SLOT_NOSE, SLOT_HEAD, SLOT_EARS, SLOT_GLOVES, SLOT_TAIL]
const SLOT_LABELS := {
	SLOT_EYES: "Eyes",
	SLOT_MOUTH: "Mouth",
	SLOT_NOSE: "Nose",
	SLOT_HEAD: "Headpiece",
	SLOT_EARS: "Ears",
	SLOT_GLOVES: "Gloves",
	SLOT_TAIL: "Tail",
}
const PREFIX_TO_SLOT := {
	"Eye": SLOT_EYES,
	"Mouth": SLOT_MOUTH,
	"Nose": SLOT_NOSE,
	"Hat": SLOT_HEAD,
	"Hair": SLOT_HEAD,
	"Horn": SLOT_HEAD,
	"Comb": SLOT_HEAD,
	"Grass": SLOT_HEAD,
	"Ear": SLOT_EARS,
	"Glove": SLOT_GLOVES,
	"Tail": SLOT_TAIL,
}

static var _manifest_cache: Dictionary = {}
static var _accessory_cache: Dictionary = {}
static var _slot_options_cache: Dictionary = {}
static var _variant_loadout_cache: Dictionary = {}


static func all_slots() -> Array:
	return SLOT_ORDER.duplicate()


static func normalize_slot(slot: String) -> String:
	var normalized := slot.strip_edges().to_lower()
	return normalized if SLOT_ORDER.has(normalized) else ""


static func slot_label(slot: String) -> String:
	return str(SLOT_LABELS.get(normalize_slot(slot), slot.capitalize()))


static func slot_for_node_name(node_name: String) -> String:
	var normalized := node_name.strip_edges()
	if normalized.is_empty():
		return ""
	for prefix in PREFIX_TO_SLOT.keys():
		var prefix_string := str(prefix)
		if not normalized.begins_with(prefix_string):
			continue
		var suffix := normalized.substr(prefix_string.length())
		if suffix.is_valid_int():
			return str(PREFIX_TO_SLOT[prefix_string])
	return ""


static func normalize_accessory_id(accessory_id: String) -> String:
	var normalized := accessory_id.strip_edges()
	if normalized.is_empty():
		return ""
	var accessory := get_accessory(normalized)
	return str(accessory.get("id", "")) if not accessory.is_empty() else ""


static func get_accessory(accessory_id: String) -> Dictionary:
	_ensure_accessory_cache()
	return (_accessory_cache.get(accessory_id.strip_edges(), {}) as Dictionary).duplicate(true)


static func get_accessory_by_node_name(node_name: String) -> Dictionary:
	_ensure_accessory_cache()
	var normalized := node_name.strip_edges()
	for accessory in _accessory_cache.values():
		var item: Dictionary = accessory as Dictionary
		if str(item.get("node_name", "")) == normalized:
			return item.duplicate(true)
	return {}


static func options_for_slot(slot: String) -> Array:
	_ensure_accessory_cache()
	var normalized_slot := normalize_slot(slot)
	if normalized_slot.is_empty():
		return []
	var result: Array = []
	for option in _slot_options_cache.get(normalized_slot, []):
		result.append((option as Dictionary).duplicate(true))
	return result


static func all_accessories() -> Array:
	_ensure_accessory_cache()
	var result: Array = []
	for slot in SLOT_ORDER:
		result.append_array(options_for_slot(str(slot)))
	return result


static func all_accessory_ids() -> Array:
	var result: Array = []
	for accessory in all_accessories():
		result.append(str((accessory as Dictionary).get("id", "")))
	return result


static func loadout_for_model_id(model_id: String) -> Dictionary:
	var normalized_model := model_id.strip_edges().to_lower()
	if normalized_model.is_empty():
		return {}
	if _variant_loadout_cache.has(normalized_model):
		return (_variant_loadout_cache[normalized_model] as Dictionary).duplicate(true)
	var manifest := _load_manifest()
	var variants: Array = manifest.get("variants", []) as Array
	var result := {}
	for entry in variants:
		if not entry is Dictionary:
			continue
		var variant: Dictionary = entry as Dictionary
		if str(variant.get("id", "")).strip_edges().to_lower() != normalized_model:
			continue
		var active_nodes: Array = variant.get("active_nodes", []) as Array
		for raw_node in active_nodes:
			var node_name := str(raw_node)
			var slot := slot_for_node_name(node_name)
			if slot.is_empty() or result.has(slot):
				continue
			var accessory := get_accessory_by_node_name(node_name)
			if not accessory.is_empty():
				result[slot] = str(accessory.get("id", ""))
		break
	_variant_loadout_cache[normalized_model] = result.duplicate(true)
	return result


static func sanitize_loadout(value, fallback_model_id: String = "") -> Dictionary:
	var result := {}
	if value is Dictionary:
		var raw_loadout: Dictionary = value as Dictionary
		for raw_slot in raw_loadout.keys():
			var slot := normalize_slot(str(raw_slot))
			if slot.is_empty():
				continue
			var accessory_id := normalize_accessory_id(str(raw_loadout[raw_slot]))
			if accessory_id.is_empty():
				continue
			var accessory := get_accessory(accessory_id)
			if str(accessory.get("slot", "")) == slot:
				result[slot] = accessory_id
	if result.is_empty() and not fallback_model_id.strip_edges().is_empty():
		result = loadout_for_model_id(fallback_model_id)
	return result


static func replace_accessory(loadout: Dictionary, accessory_id: String, fallback_model_id: String = "") -> Dictionary:
	var accessory := get_accessory(accessory_id)
	if accessory.is_empty():
		return sanitize_loadout(loadout, fallback_model_id)
	var result := sanitize_loadout(loadout, fallback_model_id)
	var slot := str(accessory.get("slot", ""))
	if not slot.is_empty():
		result[slot] = str(accessory.get("id", ""))
	return result


static func loadout_has_accessory(loadout: Dictionary, accessory_id: String) -> bool:
	var normalized := normalize_accessory_id(accessory_id)
	if normalized.is_empty():
		return false
	var clean := sanitize_loadout(loadout)
	for value in clean.values():
		if str(value) == normalized:
			return true
	return false


static func loadout_has_any_accessory(loadout: Dictionary, accessory_ids: Array) -> bool:
	var clean := sanitize_loadout(loadout)
	if clean.is_empty():
		return false
	for raw_id in accessory_ids:
		var normalized := normalize_accessory_id(str(raw_id))
		if normalized.is_empty():
			continue
		for value in clean.values():
			if str(value) == normalized:
				return true
	return false


static func accessory_label(accessory_id: String) -> String:
	var accessory := get_accessory(accessory_id)
	if accessory.is_empty():
		return "Unknown Accessory"
	return str(accessory.get("label", accessory.get("id", accessory_id)))


static func accessory_slot(accessory_id: String) -> String:
	var accessory := get_accessory(accessory_id)
	return str(accessory.get("slot", "")) if not accessory.is_empty() else ""


static func random_accessory_ids(seed_value: int, count: int, unique_slots: bool = false) -> Array:
	var pool := all_accessories()
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var result: Array = []
	var used_slots := {}
	while not pool.is_empty() and result.size() < count:
		var index := rng.randi_range(0, pool.size() - 1)
		var accessory: Dictionary = pool[index] as Dictionary
		pool.remove_at(index)
		var slot := str(accessory.get("slot", ""))
		if unique_slots and used_slots.has(slot):
			continue
		used_slots[slot] = true
		result.append(str(accessory.get("id", "")))
	return result


static func loadout_summary(loadout: Dictionary, max_items: int = 4) -> String:
	var clean := sanitize_loadout(loadout)
	if clean.is_empty():
		return "None"
	var labels: Array[String] = []
	for slot in SLOT_ORDER:
		var slot_key := str(slot)
		if not clean.has(slot_key):
			continue
		labels.append("%s %s" % [slot_label(slot_key), _accessory_number(str(clean[slot_key]))])
		if labels.size() >= max_items:
			break
	var extra_count: int = maxi(clean.size() - labels.size(), 0)
	if extra_count > 0:
		labels.append("+%d" % extra_count)
	return " / ".join(labels)


static func bounty_escape_hint(loadout: Dictionary, accessory_ids: Array) -> String:
	var clean := sanitize_loadout(loadout)
	if clean.is_empty() or accessory_ids.is_empty():
		return ""
	var slots: Array[String] = []
	for raw_id in accessory_ids:
		var accessory_id := normalize_accessory_id(str(raw_id))
		if accessory_id.is_empty():
			continue
		for slot in clean.keys():
			if str(clean[slot]) != accessory_id:
				continue
			var label := slot_label(str(slot))
			if not slots.has(label):
				slots.append(label)
	return " or ".join(slots)


static func matching_bounty_labels(loadout: Dictionary, accessory_ids: Array) -> String:
	var clean := sanitize_loadout(loadout)
	var labels: Array[String] = []
	for raw_id in accessory_ids:
		var accessory_id := normalize_accessory_id(str(raw_id))
		if accessory_id.is_empty() or not loadout_has_accessory(clean, accessory_id):
			continue
		labels.append(accessory_label(accessory_id))
	return " or ".join(labels)


static func bounty_label(accessory_ids: Array) -> String:
	var labels: Array[String] = []
	for raw_id in accessory_ids:
		var accessory_id := normalize_accessory_id(str(raw_id))
		if accessory_id.is_empty():
			continue
		labels.append(accessory_label(accessory_id))
	return " or ".join(labels)


static func _accessory_number(accessory_id: String) -> String:
	var accessory := get_accessory(accessory_id)
	if accessory.is_empty():
		return accessory_id
	var prefix := str(accessory.get("prefix", ""))
	var node_name := str(accessory.get("node_name", accessory_id))
	if prefix.is_empty() or not node_name.begins_with(prefix):
		return node_name
	return node_name.substr(prefix.length())


static func _ensure_accessory_cache() -> void:
	if not _accessory_cache.is_empty():
		return
	_slot_options_cache.clear()
	for slot in SLOT_ORDER:
		_slot_options_cache[str(slot)] = []
	var manifest := _load_manifest()
	var variants: Array = manifest.get("variants", []) as Array
	var seen_nodes := {}
	for entry in variants:
		if not entry is Dictionary:
			continue
		var variant: Dictionary = entry as Dictionary
		var active_nodes: Array = variant.get("active_nodes", []) as Array
		for raw_node in active_nodes:
			var node_name := str(raw_node).strip_edges()
			if node_name.is_empty() or seen_nodes.has(node_name):
				continue
			var slot := slot_for_node_name(node_name)
			if slot.is_empty():
				continue
			seen_nodes[node_name] = true
			var accessory := _make_accessory(node_name, slot)
			_accessory_cache[str(accessory.get("id", ""))] = accessory
			(_slot_options_cache[slot] as Array).append(accessory)


static func _make_accessory(node_name: String, slot: String) -> Dictionary:
	var prefix := _prefix_for_node_name(node_name)
	var suffix := node_name.substr(prefix.length()) if not prefix.is_empty() else ""
	var label_number := suffix if not suffix.is_empty() else node_name
	return {
		"id": node_name,
		"node_name": node_name,
		"prefix": prefix,
		"slot": slot,
		"label": "%s %s" % [slot_label(slot), label_number],
	}


static func _prefix_for_node_name(node_name: String) -> String:
	for prefix in PREFIX_TO_SLOT.keys():
		var prefix_string := str(prefix)
		if node_name.begins_with(prefix_string):
			return prefix_string
	return ""


static func _load_manifest() -> Dictionary:
	if not _manifest_cache.is_empty():
		return _manifest_cache
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_manifest_cache = parsed as Dictionary
	return _manifest_cache
