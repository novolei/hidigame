extends Control
class_name CardHUD

signal draft_choice_selected(card_id: String)
signal card_slot_used(slot_index: int)

const CardDatabase := preload("res://scripts/card_database.gd")
const CardVisual := preload("res://scripts/card_visual.gd")
const CardDetailTile := preload("res://scripts/card_detail_tile.gd")
const BLUR_SHADER := preload("res://shaders/card_draft_blur.gdshader")
const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const DRAFT_CARD_SIZE := Vector2(250.0, 350.0)
const SLOT_CARD_SIZE := Vector2(76.0, 100.0)
const DRAFT_GAP := 34.0
const SLOT_GAP := 5.0
const SLOT_STEP_Y := 14.0
const MARGIN := Vector2(28.0, 28.0)
# Vertical band reserved below the loadout slots for the PlayerHealthHUD bar
# (number label + slanted segment strip). Keeps the HP bar from overlapping the
# E/R cards in the bottom-left corner. Design pixels, scaled with the slots.
const HEALTH_BAR_RESERVE := 80.0
const UI_CONFIRM_SOUND_PATH := "res://assets/audio/ui/ui_confirm_click.mp3"

var _draft_state: Dictionary = {}
var _loadout: Array = []
var _blur_overlay: ColorRect = null
var _draft_layer: Control = null
var _detail_layer: Control = null
var _slot_layer: Control = null
var _animation_layer: Control = null
var _timer_panel: PanelContainer = null
var _pick_timer_label: Label = null
var _total_timer_label: Label = null
var _draft_cards: Array[CardVisual] = []
var _slot_cards: Array[CardVisual] = []
var _last_draft_key := ""
var _last_loadout_key := ""
var _local_pick_remaining := 0.0
var _local_total_remaining := 0.0
var _details_visible := false
var _confirm_click_player: AudioStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_ensure_confirm_click_player()
	_build_layers()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	if I18n and not I18n.locale_changed.is_connected(_on_locale_changed):
		I18n.locale_changed.connect(_on_locale_changed)
	_refresh(true)


func set_draft_state(state: Dictionary) -> void:
	_draft_state = state.duplicate(true)
	if _draft_state.is_empty():
		_local_pick_remaining = 0.0
		_local_total_remaining = 0.0
	else:
		_local_pick_remaining = float(_draft_state.get("pick_remaining_sec", _local_pick_remaining))
		_local_total_remaining = float(_draft_state.get("draft_remaining_sec", _local_total_remaining))
	_refresh(false)


func set_loadout(loadout: Array) -> void:
	_loadout = loadout.duplicate(true)
	if _loadout.is_empty():
		_details_visible = false
	_refresh(false)


func clear_cards() -> void:
	_draft_state.clear()
	_loadout.clear()
	_details_visible = false
	_refresh(true)


func is_drafting_active() -> bool:
	return not _draft_state.is_empty() and not bool(_draft_state.get("complete", false)) and not (_draft_state.get("choices", []) as Array).is_empty()


func is_detail_visible() -> bool:
	return _details_visible


func toggle_detail_panel() -> bool:
	if _loadout.is_empty():
		return false
	_details_visible = not _details_visible
	_refresh_detail_panel()
	_refresh(false)
	return true


func _process(delta: float) -> void:
	if not is_drafting_active():
		return
	_local_pick_remaining = maxf(0.0, _local_pick_remaining - delta)
	_local_total_remaining = maxf(0.0, _local_total_remaining - delta)
	_update_timer_panel()


func choose_by_index(index: int) -> bool:
	var choices := _draft_state.get("choices", []) as Array
	if index < 0 or index >= choices.size():
		return false
	var card_id := str(choices[index])
	var target_slot := int((_draft_state.get("kept", []) as Array).size())
	if index < _draft_cards.size():
		_spawn_pick_fly_clone(_draft_cards[index], target_slot)
	_play_confirm_click_sound()
	draft_choice_selected.emit(card_id)
	return true


func use_slot(index: int) -> bool:
	if index < 0 or index >= _loadout.size():
		return false
	var slot := _loadout[index] as Dictionary
	if bool(slot.get("used", false)):
		return false
	if not CardDatabase.is_manual(str(slot.get("id", ""))):
		return false
	if index < _slot_cards.size():
		_pulse_slot(_slot_cards[index])
	card_slot_used.emit(index)
	return true


func _ensure_confirm_click_player() -> void:
	if _confirm_click_player and is_instance_valid(_confirm_click_player):
		return
	_confirm_click_player = AudioStreamPlayer.new()
	_confirm_click_player.name = "ConfirmClickAudio"
	_confirm_click_player.bus = &"Master"
	_confirm_click_player.volume_db = -7.0
	_confirm_click_player.max_polyphony = 4
	var stream := load(UI_CONFIRM_SOUND_PATH)
	if stream is AudioStream:
		_confirm_click_player.stream = stream
	add_child(_confirm_click_player)


func _play_confirm_click_sound() -> void:
	if not _confirm_click_player or not is_instance_valid(_confirm_click_player):
		return
	if not _confirm_click_player.stream:
		return
	_confirm_click_player.pitch_scale = randf_range(0.985, 1.015)
	_confirm_click_player.stop()
	_confirm_click_player.play()


func _build_layers() -> void:
	_slot_layer = Control.new()
	_slot_layer.name = "CardSlotLayer"
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_slot_layer)

	_blur_overlay = ColorRect.new()
	_blur_overlay.name = "CardDraftBlurOverlay"
	_blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_overlay.color = Color.WHITE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	_blur_overlay.material = blur_material
	_blur_overlay.visible = false
	add_child(_blur_overlay)

	_draft_layer = Control.new()
	_draft_layer.name = "CardDraftLayer"
	_draft_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_draft_layer)
	_build_timer_panel()

	_detail_layer = Control.new()
	_detail_layer.name = "CardDetailLayer"
	_detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_layer.visible = false
	add_child(_detail_layer)

	_animation_layer = Control.new()
	_animation_layer.name = "CardAnimationLayer"
	_animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_animation_layer)


func _build_timer_panel() -> void:
	_timer_panel = PanelContainer.new()
	_timer_panel.name = "CardDraftTimerPanel"
	_timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.035, 0.78)
	panel_style.border_color = Color(0.98, 0.24, 0.58, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	_timer_panel.add_theme_stylebox_override("panel", panel_style)

	var row := HBoxContainer.new()
	row.name = "TimerRow"
	row.add_theme_constant_override("separation", 18)
	_timer_panel.add_child(row)

	_pick_timer_label = _make_timer_label("PICK 10")
	_total_timer_label = _make_timer_label("DRAFT 20")
	row.add_child(_pick_timer_label)
	row.add_child(_total_timer_label)
	_timer_panel.visible = false
	_draft_layer.add_child(_timer_panel)


func _make_timer_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _refresh(force_rebuild: bool) -> void:
	if not _draft_layer:
		return
	var draft_key := _get_draft_key()
	var loadout_key := _get_loadout_key()
	if force_rebuild or draft_key != _last_draft_key:
		_rebuild_draft_cards(not force_rebuild)
		_last_draft_key = draft_key
	if force_rebuild or loadout_key != _last_loadout_key:
		_rebuild_slot_cards()
		_refresh_detail_panel()
		_last_loadout_key = loadout_key
	if _blur_overlay:
		_blur_overlay.visible = is_drafting_active() or _details_visible
	_update_timer_panel()
	visible = is_drafting_active() or not _loadout.is_empty() or _details_visible


func _rebuild_draft_cards(animate: bool) -> void:
	_clear_cards(_draft_cards)
	_draft_cards.clear()
	var active := is_drafting_active()
	_draft_layer.visible = active
	if not active:
		return
	var choices := _draft_state.get("choices", []) as Array
	var rects := _get_draft_rects(choices.size())
	for i in range(choices.size()):
		var card_id := str(choices[i])
		var card := CardVisual.new()
		card.name = "DraftCard%d" % i
		card.custom_minimum_size = rects[i].size
		card.size = rects[i].size
		card.position = rects[i].position
		card.pivot_offset = rects[i].size * 0.5
		card.configure(card_id, str(i + 1), "draft")
		card.pressed.connect(func(): choose_by_index(i))
		_draft_layer.add_child(card)
		_draft_cards.append(card)
		if animate:
			_animate_draft_card_in(card, rects[i], i)
	_layout_timer_panel()


func _rebuild_slot_cards() -> void:
	_clear_cards(_slot_cards)
	_slot_cards.clear()
	_slot_layer.visible = not _loadout.is_empty()
	for i in range(_loadout.size()):
		var slot := _loadout[i] as Dictionary
		var card_id := str(slot.get("id", ""))
		var rect := _get_slot_rect(i)
		var card := CardVisual.new()
		card.name = "CardSlot%d" % i
		card.custom_minimum_size = rect.size
		card.size = rect.size
		card.position = rect.position
		card.pivot_offset = rect.size * 0.5
		card.rotation = deg_to_rad(-4.0 if i == 0 else 4.0)
		card.configure(card_id, "E" if i == 0 else "R", "slot", bool(slot.get("used", false)), not CardDatabase.is_manual(card_id))
		card.pressed.connect(func(): use_slot(i))
		_slot_layer.add_child(card)
		_slot_cards.append(card)


func _animate_draft_card_in(card: CardVisual, final_rect: Rect2, index: int) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2(0.54, 0.54)
	card.rotation = deg_to_rad([-12.0, 5.0, 14.0][index % 3])
	card.position = Vector2(final_rect.position.x + [-210.0, 0.0, 210.0][index % 3], -final_rect.size.y - 90.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.08 * index)
	tween.tween_property(card, "position", final_rect.position, 0.58).set_delay(0.08 * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.50).set_delay(0.08 * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", deg_to_rad([-4.0, 0.0, 4.0][index % 3]), 0.50).set_delay(0.08 * index).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _spawn_pick_fly_clone(source: CardVisual, target_slot: int) -> void:
	var clone := CardVisual.new()
	clone.name = "CardPickFlyClone"
	clone.size = source.size
	clone.position = source.global_position - global_position
	clone.pivot_offset = source.pivot_offset
	clone.rotation = source.rotation
	clone.scale = source.scale
	clone.configure(source.card_id, source.key_text, source.display_mode)
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_layer.add_child(clone)
	var target := _get_slot_rect(clampi(target_slot, 0, 1))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(clone, "position", target.position, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(clone, "size", target.size, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(clone, "scale", Vector2(1.0, 1.0), 0.42)
	tween.tween_property(clone, "rotation", deg_to_rad(-4.0 if target_slot == 0 else 4.0), 0.42)
	tween.tween_property(clone, "modulate:a", 0.0, 0.12).set_delay(0.34)
	tween.set_parallel(false)
	tween.tween_callback(clone.queue_free)


func _pulse_slot(card: CardVisual) -> void:
	card.queue_redraw()


func _refresh_detail_panel() -> void:
	if not _detail_layer:
		return
	for child in _detail_layer.get_children():
		child.queue_free()
	_detail_layer.visible = _details_visible and not _loadout.is_empty()
	if not _detail_layer.visible:
		return

	var viewport_size := _get_canvas_size()
	var scale_value := _get_draft_scale(viewport_size)
	var tile_count := mini(_loadout.size(), 2)
	var tile_size := Vector2(360.0, 318.0) * scale_value
	var tile_gap := 96.0 * scale_value
	var total_width := float(tile_count) * tile_size.x + float(maxi(tile_count - 1, 0)) * tile_gap
	var start := Vector2((viewport_size.x - total_width) * 0.5, viewport_size.y * 0.50 - tile_size.y * 0.5)
	var root := Control.new()
	root.visible = false
	_detail_layer.add_child(root)

	var title := Label.new()
	title.text = "卡牌详情" if CardDatabase.is_zh_locale() else "CARD DETAILS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(round(30.0 * scale_value)))
	title.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	root.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(18.0 * scale_value))
	root.add_child(row)

	for i in range(tile_count):
		var slot := _loadout[i] as Dictionary
		var card_id := str(slot.get("id", ""))
		var tile := CardDetailTile.new()
		tile.name = "CardDetailTile%d" % i
		tile.position = start + Vector2(float(i) * (tile_size.x + tile_gap), 0.0)
		tile.size = tile_size
		tile.custom_minimum_size = tile_size
		tile.configure(card_id, "E" if i == 0 else "R")
		_detail_layer.add_child(tile)


func _make_detail_card(card_id: String, key_name: String, scale_value: float) -> PanelContainer:
	var card := CardDatabase.get_card(card_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 260.0) * scale_value
	panel.add_theme_stylebox_override("panel", _make_detail_card_style(str(card.get("team", ""))))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(8.0 * scale_value))
	panel.add_child(box)

	var header := Label.new()
	header.text = "%s  %s" % [key_name, CardDatabase.display_name_for_locale(card_id)]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", int(round(24.0 * scale_value)))
	header.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90, 1.0))
	box.add_child(header)

	var meta := Label.new()
	meta.text = _card_meta_text(card)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", int(round(15.0 * scale_value)))
	meta.add_theme_color_override("font_color", Color(0.74, 0.86, 0.92, 0.92))
	box.add_child(meta)

	var zh := Label.new()
	zh.text = "%s%s" % ["功能: " if CardDatabase.is_zh_locale() else "Effect: ", CardDatabase.description_for_locale(card_id)]
	zh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zh.add_theme_font_size_override("font_size", int(round(17.0 * scale_value)))
	zh.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.96))
	box.add_child(zh)
	return panel


func _card_meta_text(card: Dictionary) -> String:
	var zh := CardDatabase.is_zh_locale()
	var category := _category_label(str(card.get("category", "card")))
	var activation := _activation_label(str(card.get("activation", "manual")))
	var duration := float(card.get("duration", 0.0))
	var radius := float(card.get("radius", 0.0))
	var parts := [category[0] if zh else category[1], activation[0] if zh else activation[1]]
	parts.append(("持续 %.0fs" % duration) if zh and duration > 0.0 else ("Duration %.0fs" % duration) if duration > 0.0 else ("瞬时" if zh else "Instant"))
	if radius > 0.0:
		parts.append(("范围 %.0fm" % radius) if zh else ("Radius %.0fm" % radius))
	return " · ".join(parts)


func _category_label(category: String) -> Array[String]:
	match category:
		CardDatabase.CATEGORY_ACTIVE:
			return ["主动", "Active"]
		CardDatabase.CATEGORY_DEFENSE:
			return ["防御", "Defense"]
		CardDatabase.CATEGORY_PASSIVE:
			return ["被动", "Passive"]
		CardDatabase.CATEGORY_TRACKING:
			return ["追踪", "Tracking"]
		CardDatabase.CATEGORY_CONTROL:
			return ["控制", "Control"]
		CardDatabase.CATEGORY_RESOURCE:
			return ["资源", "Resource"]
		_:
			return ["卡牌", "Card"]


func _activation_label(activation: String) -> Array[String]:
	if activation == CardDatabase.ACTIVATION_REACTIVE:
		return ["自动触发", "Reactive"]
	return ["手动使用", "Manual"]


func _make_detail_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.030, 0.040, 0.88)
	style.border_color = Color(0.82, 0.96, 1.0, 0.42)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 22.0
	return style


func _make_detail_card_style(team: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.12, 0.78)
	style.border_color = Color(0.96, 0.56, 0.42, 0.72) if team == CardDatabase.TEAM_HUNTER else Color(0.70, 0.92, 1.0, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style


func _update_timer_panel() -> void:
	if not _timer_panel:
		return
	var active := is_drafting_active()
	_timer_panel.visible = active
	if not active:
		return
	var pick_index := int(_draft_state.get("pick_index", 1))
	if _pick_timer_label:
		_pick_timer_label.text = "PICK %d/2  %02d" % [pick_index, int(ceil(_local_pick_remaining))]
	if _total_timer_label:
		_total_timer_label.text = "TOTAL  %02d" % int(ceil(_local_total_remaining))
	_layout_timer_panel()


func _layout_timer_panel() -> void:
	if not _timer_panel:
		return
	var rects := _get_draft_rects((_draft_state.get("choices", []) as Array).size())
	if rects.is_empty():
		return
	var first := rects[0]
	var last := rects[rects.size() - 1]
	var total_rect := first.merge(last)
	var viewport_size := _get_canvas_size()
	var scale_value := _get_draft_scale(viewport_size)
	var panel_size := Vector2(320.0, 48.0) * scale_value
	_timer_panel.custom_minimum_size = panel_size
	_timer_panel.size = panel_size
	_timer_panel.position = Vector2(
		total_rect.position.x + total_rect.size.x * 0.5 - panel_size.x * 0.5,
		maxf(24.0 * scale_value, total_rect.position.y - panel_size.y - 18.0 * scale_value)
	)


func _get_draft_rects(count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var viewport_size := _get_canvas_size()
	var scale_value := _get_draft_scale(viewport_size)
	var card_size := DRAFT_CARD_SIZE * scale_value
	var gap := DRAFT_GAP * scale_value
	var total_width := float(count) * card_size.x + float(maxi(count - 1, 0)) * gap
	var start := Vector2((viewport_size.x - total_width) * 0.5, viewport_size.y * 0.47 - card_size.y * 0.5)
	for i in range(count):
		rects.append(Rect2(start + Vector2(float(i) * (card_size.x + gap), 0.0), card_size))
	return rects


func _get_slot_rect(index: int) -> Rect2:
	var viewport_size := _get_canvas_size()
	var scale_value := _get_slot_scale(viewport_size)
	var card_size := SLOT_CARD_SIZE * scale_value
	var gap := SLOT_GAP * scale_value
	var step_y := SLOT_STEP_Y * scale_value
	var margin := MARGIN * scale_value
	var x := margin.x + float(index) * (card_size.x + gap)
	# Lift the loadout column above the reserved HP-bar band so PlayerHealthHUD
	# renders directly beneath it in the bottom-left corner.
	var y := viewport_size.y - margin.y - HEALTH_BAR_RESERVE * scale_value - card_size.y - float(index) * step_y
	return Rect2(Vector2(x, y), card_size)


func _get_draft_scale(viewport_size: Vector2) -> float:
	var resolution_scale := minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	return clampf(resolution_scale, 0.62, 1.06)


func _get_slot_scale(viewport_size: Vector2) -> float:
	var resolution_scale := 1.35 * minf(viewport_size.x / BASE_VIEWPORT.x, viewport_size.y / BASE_VIEWPORT.y)
	return clampf(resolution_scale, 0.82, 1.65)


func _get_canvas_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return get_viewport_rect().size


func _get_draft_key() -> String:
	return JSON.stringify({
		"pick": _draft_state.get("pick_index", 0),
		"choices": _draft_state.get("choices", []),
		"complete": _draft_state.get("complete", false),
	})


func _get_loadout_key() -> String:
	return JSON.stringify(_loadout)


func _clear_cards(cards: Array[CardVisual]) -> void:
	for card in cards:
		if card and is_instance_valid(card):
			card.queue_free()


func _on_viewport_size_changed() -> void:
	_last_draft_key = ""
	_last_loadout_key = ""
	_refresh(true)


func _on_locale_changed(_locale: String) -> void:
	_last_draft_key = ""
	_last_loadout_key = ""
	_refresh(true)
