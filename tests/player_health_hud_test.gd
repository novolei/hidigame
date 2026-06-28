extends SceneTree

## Headless coverage for the role-based HP pools and the bottom-left health bar.
## Run: godot --headless tests/player_health_hud_test.gd

const PlayerHealthHUDScript := preload("res://scripts/player_health_hud.gd")
const CardHUDScript := preload("res://scripts/card_hud.gd")
const PlayerScript := preload("res://scripts/player.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_role_health_pools()
	_test_slant_matches_card_row()
	await _test_health_bar_value_model()

	if failures.is_empty():
		print("[PlayerHealthHUDTest] PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[PlayerHealthHUDTest] " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_role_health_pools() -> void:
	# Hunter is tankier than the props per the GDD HP balance.
	_expect(PlayerScript.HUNTER_MAX_HEALTH == 250.0, "Hunter max HP should be 250")
	_expect(PlayerScript.PROP_MAX_HEALTH == 200.0, "Prop max HP should be 200")
	_expect(PlayerScript.CARD_RESCUE_HEALTH_RATIO > 0.0 and PlayerScript.CARD_RESCUE_HEALTH_RATIO < 1.0,
		"Card rescue ratio should be a fraction")


func _test_slant_matches_card_row() -> void:
	# The HP bar echoes the loadout (技能卡) card-row tilt but flattened ~5 degrees.
	var card_degrees: float = rad_to_deg(atan(CardHUDScript.SLOT_STEP_Y / (CardHUDScript.SLOT_CARD_SIZE.x + CardHUDScript.SLOT_GAP)))
	var expected: float = card_degrees - 5.0
	_expect(absf(PlayerHealthHUDScript.HEALTH_SLANT_DEGREES - expected) < 1.0,
		"Health bar slant (%.2f deg) should be ~5 deg flatter than the card row (%.2f deg)" % [PlayerHealthHUDScript.HEALTH_SLANT_DEGREES, card_degrees])
	_expect(PlayerHealthHUDScript.SEGMENTS == 10, "Health bar should render 10 segments")


func _test_health_bar_value_model() -> void:
	var hud := PlayerHealthHUDScript.new()
	root.add_child(hud)
	await process_frame

	# No combat role / no max -> bar stays hidden.
	hud.set_health(0.0, 0.0)
	_expect(not hud.visible, "Bar should hide when max health is zero")
	_expect(not bool(hud.get("_has_data")), "Bar should hold no data when max is zero")

	# First real assignment snaps the display to full and shows the bar.
	hud.set_health(250.0, 250.0)
	_expect(hud.visible, "Bar should show once a max is provided")
	_expect(is_equal_approx(float(hud.get("_target_health")), 250.0), "Target should equal current")
	_expect(is_equal_approx(float(hud.get("_display_health")), 250.0), "Display should snap to first value")
	_expect(is_equal_approx(float(hud.get("_max_health")), 250.0), "Max should be stored")

	# Taking damage lowers the target and triggers the damage flash.
	hud.set_health(125.0, 250.0)
	_expect(is_equal_approx(float(hud.get("_target_health")), 125.0), "Target should follow damage")
	_expect(float(hud.get("_damage_flash")) > 0.0, "Damage should raise the flash value")

	# Overheal is clamped to the pool ceiling.
	hud.set_health(900.0, 250.0)
	_expect(is_equal_approx(float(hud.get("_target_health")), 250.0), "Target should clamp to max")

	# clear() hides and forgets state.
	hud.clear()
	_expect(not hud.visible, "clear() should hide the bar")
	_expect(not bool(hud.get("_has_data")), "clear() should drop the data flag")

	hud.queue_free()
