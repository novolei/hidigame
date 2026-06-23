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
	hud.set_passive_skills([
		{"icon": "detect", "charge_ratio": 0.0, "cooldown_remaining": 12.0, "cooldown_total": 45.0, "disabled": true},
	])
	await get_tree().process_frame
	_expect(hud.visible, "SkillHUD should become visible when skills are assigned")
	_expect(hud._get_icon_texture("detect") != null, "SkillHUD should support the detect icon used by Hunter SCAN")
	_expect(hud._get_icon_texture("blink") != null, "SkillHUD should support the blink icon used by Stalker PHASE")
	_expect(is_equal_approx(hud.get_passive_card_scale(), 0.67), "SkillHUD passive cards should be 0.67x regular skill cards")
	var viewport_size := Vector2(1920.0, 1080.0)
	var skill_start: Vector2 = hud._get_skill_row_start(viewport_size)
	var skill_card_size: Vector2 = hud._get_skill_card_size(viewport_size)
	var skill_slant := hud._get_card_slant_angle(Rect2(skill_start, skill_card_size), hud._get_hud_scale(viewport_size))
	_expect(skill_slant > 0.0, "SkillHUD cooldown overlays should use the same positive slant as the bottom meter")
	_expect(is_equal_approx(tan(skill_slant), hud._get_skill_row_slope()), "SkillHUD cooldown slant should match the shared skill-row meter slope")
	var meter_points := []
	for i in range(3):
		var rect := Rect2(
			skill_start + Vector2(float(i) * (skill_card_size.x + SkillHUD.CARD_GAP * hud._get_hud_scale(viewport_size)), float(i) * SkillHUD.STEP_Y * hud._get_hud_scale(viewport_size)),
			skill_card_size
		)
		var meter_line: Array[Vector2] = hud._get_charge_meter_line(rect, hud._get_hud_scale(viewport_size))
		var icon_rect: Rect2 = hud._get_skill_icon_rect(rect, hud._get_hud_scale(viewport_size))
		_expect(is_equal_approx(meter_line[0].x, icon_rect.position.x), "SkillHUD meter should align its left edge with the cooldown panel left edge")
		meter_points.append(meter_line[0])
		meter_points.append(meter_line[1])
	_expect(_points_share_slope(meter_points, hud._get_skill_row_slope()), "SkillHUD meter segments should be collinear along the shared row slope")
	var passive_rects: Array[Rect2] = hud._get_passive_skill_rects(viewport_size)
	_expect(passive_rects.size() == 1, "SkillHUD should lay out one Hunter passive icon")
	if passive_rects.size() == 1:
		var passive_rect := passive_rects[0]
		var skill_right := skill_start.x + skill_card_size.x * 3.0 + SkillHUD.CARD_GAP * hud._get_hud_scale(viewport_size) * 2.0
		_expect(is_equal_approx(passive_rect.size.x, skill_card_size.x * 0.67), "Passive icon should be 0.67x the regular skill icon width")
		_expect(is_equal_approx(passive_rect.size.y, skill_card_size.y * 0.67), "Passive icon should be 0.67x the regular skill icon height")
		_expect(absf(passive_rect.end.x - skill_right) < 0.1, "Passive icon should be right-aligned above the SkillHUD row")
		_expect(passive_rect.position.y < skill_start.y, "Passive icon should be on the row above the main SkillHUD icons")
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


func _points_share_slope(points: Array, slope: float) -> bool:
	if points.size() < 2:
		return true
	var origin: Vector2 = points[0]
	var intercept := origin.y - origin.x * slope
	for point in points:
		var typed_point: Vector2 = point
		if absf((typed_point.y - typed_point.x * slope) - intercept) > 0.1:
			return false
	return true
