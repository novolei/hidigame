extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := SkillHUD.new()
	add_child(hud)
	await get_tree().process_frame

	var icon_keys := ["flashlight", "stealth", "blink", "detect", "shape", "camo", "grapple", "sprint", "locked"]
	for key in icon_keys:
		var texture: Texture2D = hud._get_icon_texture(key)
		_expect(texture != null, "SkillHUD should preload icon texture: " + key)
		if texture:
			_expect(texture.get_width() > 0 and texture.get_height() > 0, "SkillHUD icon texture should have dimensions: " + key)

	hud.set_skills([
		{"title": "FLASH", "key": "F", "icon": "flashlight", "charge_ratio": 1.0},
		{"title": "SCAN", "key": "2", "icon": "detect", "charge_ratio": 0.0, "disabled": true},
		{"title": "PHASE", "key": "2", "icon": "blink", "charge_ratio": 0.0, "disabled": true},
	])
	await get_tree().process_frame
	_expect(hud.visible, "SkillHUD should become visible when skills are assigned")
	_expect(hud._get_icon_texture("detect") != null, "SkillHUD should support the detect icon used by Hunter SCAN")
	_expect(hud._get_icon_texture("blink") != null, "SkillHUD should support the blink icon used by Stalker PHASE")
	var scale_720p: float = hud._get_hud_scale(Vector2(1280.0, 720.0))
	var scale_1080p: float = hud._get_hud_scale(Vector2(1920.0, 1080.0))
	var scale_1440p: float = hud._get_hud_scale(Vector2(2560.0, 1440.0))
	var scale_4k: float = hud._get_hud_scale(Vector2(3840.0, 2160.0))
	_expect(scale_1080p > scale_720p, "SkillHUD should scale up from 720p to 1080p")
	_expect(scale_1440p > scale_1080p, "SkillHUD should keep scaling up above the default 1080p window")
	_expect(scale_4k > scale_1440p, "SkillHUD should continue scaling at 4K before hitting the high-resolution cap")
	_expect(scale_4k <= SkillHUD.MAX_HUD_SCALE, "SkillHUD scale should stay within the high-resolution cap")

	hud.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[SkillHUDIconTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[SkillHUDIconTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
