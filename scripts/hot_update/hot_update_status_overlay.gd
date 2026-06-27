class_name HotUpdateStatusOverlay
extends CanvasLayer

const PANEL_WIDTH := 360.0
const PANEL_MARGIN := 20.0

var _manager
var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _detail_label: Label
var _check_button: Button
var _install_button: Button
var _close_button: Button
var _pending_count := 0


func _ready() -> void:
	layer = 80
	_build_ui()
	hide()


func bind(manager) -> void:
	_manager = manager
	if not _manager.status_changed.is_connected(_on_status_changed):
		_manager.status_changed.connect(_on_status_changed)
	if not _manager.manifest_ready.is_connected(_on_manifest_ready):
		_manager.manifest_ready.connect(_on_manifest_ready)
	if not _manager.update_failed.is_connected(_on_update_failed):
		_manager.update_failed.connect(_on_update_failed)
	if not _manager.update_installed.is_connected(_on_update_installed):
		_manager.update_installed.connect(_on_update_installed)


func show_idle() -> void:
	_set_status("Update service ready.", "Installed packages are loaded during boot when available.")
	_set_install_enabled(false)
	show()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "HotUpdateOverlayRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "HotUpdatePanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -PANEL_WIDTH - PANEL_MARGIN
	_panel.offset_right = -PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN
	_panel.offset_bottom = 210.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(_panel)

	var body := VBoxContainer.new()
	body.name = "HotUpdatePanelBody"
	body.add_theme_constant_override("separation", 8)
	_panel.add_child(body)

	_title_label = _label("Hot Update", 20, Color(1.0, 0.86, 0.42, 1.0))
	_title_label.name = "TitleLabel"
	body.add_child(_title_label)

	_status_label = _label("", 16, Color(0.94, 0.95, 0.98, 1.0))
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status_label)

	_detail_label = _label("", 13, Color(0.72, 0.75, 0.82, 1.0))
	_detail_label.name = "DetailLabel"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_label)

	var button_row := HBoxContainer.new()
	button_row.name = "HotUpdateButtons"
	button_row.add_theme_constant_override("separation", 8)
	body.add_child(button_row)

	_check_button = _button("Check")
	_check_button.name = "CheckButton"
	_check_button.pressed.connect(_on_check_pressed)
	button_row.add_child(_check_button)

	_install_button = _button("Install")
	_install_button.name = "InstallButton"
	_install_button.disabled = true
	_install_button.pressed.connect(_on_install_pressed)
	button_row.add_child(_install_button)

	_close_button = _button("Close")
	_close_button.name = "CloseButton"
	_close_button.pressed.connect(hide)
	button_row.add_child(_close_button)


func _on_check_pressed() -> void:
	if _manager == null:
		return
	show()
	_set_status("Checking update manifest.", "")
	_set_install_enabled(false)
	_manager.call("check_for_updates")


func _on_install_pressed() -> void:
	if _manager == null:
		return
	_set_status("Installing update packages.", "Downloaded packages are verified before installation.")
	_set_install_enabled(false)
	_manager.call("install_pending_updates")


func _on_status_changed(message: String) -> void:
	show()
	_set_status(message, _detail_label.text)


func _on_manifest_ready(_manifest: Dictionary, pending_packages: Array) -> void:
	_pending_count = pending_packages.size()
	if _pending_count == 0:
		_set_status("Game content is up to date.", "No package download is required.")
		_set_install_enabled(false)
	else:
		_set_status("Update manifest ready.", "%d package(s) are ready to download." % _pending_count)
		_set_install_enabled(true)
	show()


func _on_update_failed(message: String) -> void:
	_set_status("Update failed.", message)
	_set_install_enabled(_pending_count > 0)
	show()


func _on_update_installed(restart_required: bool) -> void:
	_pending_count = 0
	var detail := "Restart the game before joining online rooms." if restart_required else "Installed update packages are ready."
	_set_status("Update installed.", detail)
	_set_install_enabled(false)
	show()


func _set_status(status_text: String, detail_text: String) -> void:
	if _status_label:
		_status_label.text = status_text
	if _detail_label:
		_detail_label.text = detail_text


func _set_install_enabled(enabled: bool) -> void:
	if _install_button:
		_install_button.disabled = not enabled


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(92.0, 34.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.060, 0.075, 0.94)
	style.border_color = Color(0.47, 0.57, 0.72, 0.65)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style
