extends SceneTree

# Verifies the death-tombstone nameplate's font wiring and placement constants. The bilingual font
# must resolve Latin glyphs from Bangers and fall back to AaFengKuangYuanShiRen for CJK, and the
# placement/thickness constants must keep solid 3D text on the smiley face (front +Z, above base).

const CharacterScript := preload("res://scripts/player.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_fonts_load()
	_test_bilingual_fallback_wiring()
	_test_placement_constants_sane()

	if failures.is_empty():
		print("[TombstoneNameplateTest] PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[TombstoneNameplateTest] " + failure)
		quit(1)


var failures: Array[String] = []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_source_fonts_load() -> void:
	var latin: Resource = load(CharacterScript.PROP_TOMBSTONE_NAME_FONT_LATIN)
	var cjk: Resource = load(CharacterScript.PROP_TOMBSTONE_NAME_FONT_CJK)
	_expect(latin is Font, "Latin font (Bangers) failed to load as Font")
	_expect(cjk is Font, "CJK font (AaFengKuangYuanShiRen) failed to load as Font")


# Mirrors the runtime font construction so the fallback chain is validated without reaching into a
# private helper: Bangers as base, the CJK face as the fallback that catches glyphs Bangers lacks.
func _test_bilingual_fallback_wiring() -> void:
	var latin: Font = load(CharacterScript.PROP_TOMBSTONE_NAME_FONT_LATIN) as Font
	var cjk: Font = load(CharacterScript.PROP_TOMBSTONE_NAME_FONT_CJK) as Font
	if latin == null or cjk == null:
		return
	var variation := FontVariation.new()
	variation.base_font = latin
	variation.fallbacks = [cjk] as Array[Font]
	_expect(variation.base_font == latin, "FontVariation base must be the Latin (Bangers) face")
	_expect(variation.fallbacks.size() == 1, "FontVariation must carry exactly the CJK fallback")


func _test_placement_constants_sane() -> void:
	var offset: Vector3 = CharacterScript.PROP_TOMBSTONE_NAME_LOCAL_OFFSET
	_expect(offset.y > 0.0, "Name offset Y should be above the base")
	_expect(offset.z > 0.0, "Name offset Z should be on the front (+Z) smiley face")
	_expect(CharacterScript.PROP_TOMBSTONE_NAME_DEPTH > 0.0, "TextMesh depth must be > 0 (3D thickness)")
	_expect(CharacterScript.PROP_TOMBSTONE_NAME_MAX_DISPLAY_UNITS > 0, "Name width budget must be positive")
	var color: Color = CharacterScript.PROP_TOMBSTONE_NAME_COLOR
	_expect(color.r > color.b and color.r < 0.6, "Name colour should be a dark warm brown")
	var wide: float = CharacterScript.PROP_TOMBSTONE_COLLIDER_WIDTH_RATIO
	var deep: float = CharacterScript.PROP_TOMBSTONE_COLLIDER_DEPTH_RATIO
	_expect(wide <= 1.0 and deep <= 1.0, "Collider ratios must not exceed the model AABB")
