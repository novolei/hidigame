extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var report: Dictionary = ChameleonPropCatalog.build_qa_report(true)
	var errors: Array = report.get("errors", [])
	var warnings: Array = report.get("warnings", [])
	var entries: Array = report.get("entries", [])
	var item_count := int(report.get("item_count", 0))
	var hand_size := int(report.get("hand_size", 0))

	_expect(bool(report.get("ok", false)), "Prop catalog should have no blocking QA errors: " + _join_array(errors))
	_expect(item_count >= 20, "Prop catalog should expose enough disguise variety for random hands; item_count=%d" % item_count)
	_expect(hand_size == ChameleonPropCatalog.DEFAULT_HAND_SIZE, "Prop catalog hand size should stay at the intended five choices; hand_size=%d" % hand_size)
	_expect(entries.size() == item_count, "QA report should include one entry per catalog item")

	for entry_value in entries:
		var entry := entry_value as Dictionary
		_expect(bool(entry.get("loadable", false)), "Prop entry should be loadable: %s" % str(entry.get("id", "")))
		_expect((entry.get("errors", []) as Array).is_empty(), "Prop entry should have no blocking errors: %s" % str(entry))

	var hand_a: Array = ChameleonPropCatalog.random_hand_for_player(7, "qa_session", hand_size)
	var hand_b: Array = ChameleonPropCatalog.random_hand_for_player(7, "qa_session", hand_size)
	var hand_ids_a := _ids_for_hand(hand_a)
	var hand_ids_b := _ids_for_hand(hand_b)
	_expect(hand_a.size() == hand_size, "Random hand should use the configured hand size")
	_expect(hand_ids_a == hand_ids_b, "Random hand should be deterministic for the same player and session seed")
	_expect(_ids_are_unique(hand_ids_a), "Random hand should not contain duplicate prop ids")

	if not warnings.is_empty():
		print("[ChameleonPropCatalogQATest] Warnings: " + _join_array(warnings))

	if failures.is_empty():
		print("[ChameleonPropCatalogQATest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ChameleonPropCatalogQATest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ids_for_hand(hand: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for item_value in hand:
		var item := item_value as Dictionary
		ids.append(str(item.get("id", "")))
	return ids


func _ids_are_unique(ids: PackedStringArray) -> bool:
	var seen := {}
	for id in ids:
		if seen.has(id):
			return false
		seen[id] = true
	return true


func _join_array(values: Array) -> String:
	var parts := PackedStringArray()
	for value in values:
		parts.append(str(value))
	return "; ".join(parts)
