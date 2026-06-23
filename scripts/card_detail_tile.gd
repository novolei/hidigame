class_name CardDetailTile
extends Control

const CardDatabase := preload("res://scripts/card_database.gd")
const CardVisual := preload("res://scripts/card_visual.gd")
const FONT_PATH := "res://assets/fonts/SairaCondensed-Bold.woff2"
const VALUE_FONT_PATH := "res://assets/fonts/Saira-9.woff2"

var card_id := ""
var key_name := ""
var _title_font: Font = null
var _value_font: Font = null
var _card_visual: CardVisual = null
var _category_label: Label = null
var _title_label: Label = null
var _meta_label: Label = null
var _desc_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_font = _load_font(FONT_PATH)
	_value_font = _load_font(VALUE_FONT_PATH)
	_build_children()
	if not card_id.is_empty():
		_apply_text()
		_layout_children()
	resized.connect(_layout_children)


func configure(next_card_id: String, next_key_name: String) -> void:
	card_id = next_card_id
	key_name = next_key_name
	if not _card_visual:
		return
	_apply_text()
	_layout_children()
	queue_redraw()


func _build_children() -> void:
	_card_visual = CardVisual.new()
	_card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_visual)

	_category_label = _make_label(15, Color(0.44, 0.82, 1.0, 0.94), HORIZONTAL_ALIGNMENT_CENTER, _title_font)
	_title_label = _make_label(30, Color(0.98, 0.98, 1.0, 0.98), HORIZONTAL_ALIGNMENT_CENTER, _title_font)
	_meta_label = _make_label(15, Color(0.72, 0.84, 0.92, 0.86), HORIZONTAL_ALIGNMENT_CENTER, _value_font)
	_desc_label = _make_label(17, Color(0.88, 0.92, 0.96, 0.94), HORIZONTAL_ALIGNMENT_CENTER, _value_font)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_category_label)
	add_child(_title_label)
	add_child(_meta_label)
	add_child(_desc_label)


func _make_label(font_size: int, color: Color, align: HorizontalAlignment, font: Font) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font if font else ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _apply_text() -> void:
	var card := CardDatabase.get_card(card_id)
	var zh := CardDatabase.is_zh_locale()
	_card_visual.configure(card_id, key_name, "slot", false, not CardDatabase.is_manual(card_id))
	_category_label.text = _category_text(str(card.get("category", "card")))
	_title_label.text = CardDatabase.display_name_for_locale(card_id)
	_meta_label.text = _meta_text(card, zh)
	_desc_label.text = "%s%s" % ["功能: " if zh else "Effect: ", CardDatabase.description_for_locale(card_id)]


func _layout_children() -> void:
	if not _card_visual:
		return
	var scale_value := clampf(size.y / 318.0, 0.70, 1.35)
	var card_size := Vector2(104.0, 137.0) * scale_value
	_card_visual.size = card_size
	_card_visual.custom_minimum_size = card_size
	_card_visual.position = Vector2((size.x - card_size.x) * 0.5, size.y * 0.02)
	_card_visual.pivot_offset = card_size * 0.5
	_card_visual.rotation = 0.0

	_category_label.position = Vector2(size.x * 0.12, size.y * 0.47)
	_category_label.size = Vector2(size.x * 0.76, size.y * 0.08)
	_title_label.position = Vector2(size.x * 0.05, size.y * 0.55)
	_title_label.size = Vector2(size.x * 0.90, size.y * 0.13)
	_meta_label.position = Vector2(size.x * 0.06, size.y * 0.67)
	_meta_label.size = Vector2(size.x * 0.88, size.y * 0.09)
	_desc_label.position = Vector2(size.x * 0.08, size.y * 0.76)
	_desc_label.size = Vector2(size.x * 0.84, size.y * 0.20)


func _draw() -> void:
	var line_y := size.y * 0.965
	var card := CardDatabase.get_card(card_id)
	var accent := _accent_color(card)
	draw_line(Vector2(size.x * 0.12, line_y), Vector2(size.x * 0.88, line_y), Color(accent.r, accent.g, accent.b, 0.34), 2.0, true)


func _meta_text(card: Dictionary, zh: bool) -> String:
	var activation := str(card.get("activation", CardDatabase.ACTIVATION_MANUAL))
	var duration := float(card.get("duration", 0.0))
	var radius := float(card.get("radius", 0.0))
	var parts: Array[String] = []
	parts.append("自动" if zh and activation == CardDatabase.ACTIVATION_REACTIVE else "手动" if zh else "Reactive" if activation == CardDatabase.ACTIVATION_REACTIVE else "Manual")
	parts.append(("持续 %.0fs" % duration) if zh and duration > 0.0 else ("Duration %.0fs" % duration) if duration > 0.0 else ("瞬时" if zh else "Instant"))
	if radius > 0.0:
		parts.append(("范围 %.0fm" % radius) if zh else ("Radius %.0fm" % radius))
	return "  /  ".join(parts)


func _category_text(category: String) -> String:
	var zh := CardDatabase.is_zh_locale()
	match category:
		CardDatabase.CATEGORY_ACTIVE:
			return "主动" if zh else "ACTIVE"
		CardDatabase.CATEGORY_DEFENSE:
			return "防御" if zh else "DEFENSE"
		CardDatabase.CATEGORY_PASSIVE:
			return "被动" if zh else "PASSIVE"
		CardDatabase.CATEGORY_TRACKING:
			return "战术" if zh else "TACTIC"
		CardDatabase.CATEGORY_CONTROL:
			return "控制" if zh else "CONTROL"
		CardDatabase.CATEGORY_RESOURCE:
			return "资源" if zh else "RESOURCE"
		_:
			return "卡牌" if zh else "CARD"


func _accent_color(card: Dictionary) -> Color:
	if str(card.get("team", "")) == CardDatabase.TEAM_HUNTER:
		return Color(0.92, 0.38, 0.34, 1.0)
	return Color(0.34, 0.72, 1.0, 1.0)


func _load_font(path: String) -> Font:
	var resource := load(path)
	return resource if resource is Font else null
