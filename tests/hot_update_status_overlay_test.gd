extends SceneTree

const OverlayScript := preload("res://scripts/hot_update/hot_update_status_overlay.gd")

var failures: Array[String] = []


class FakeHotUpdateManager:
	extends Node

	signal status_changed(message: String)
	signal manifest_ready(manifest: Dictionary, pending_packages: Array)
	signal update_failed(message: String)
	signal update_installed(restart_required: bool)

	var check_count := 0
	var install_count := 0

	func check_for_updates() -> bool:
		check_count += 1
		status_changed.emit("Fake manifest check.")
		return true

	func install_pending_updates() -> bool:
		install_count += 1
		update_installed.emit(true)
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := FakeHotUpdateManager.new()
	root.add_child(manager)
	var overlay := OverlayScript.new()
	root.add_child(overlay)
	await process_frame
	overlay.bind(manager)
	overlay.show_idle()

	var status_label := overlay.get_node("HotUpdateOverlayRoot/HotUpdatePanel/HotUpdatePanelBody/StatusLabel") as Label
	var detail_label := overlay.get_node("HotUpdateOverlayRoot/HotUpdatePanel/HotUpdatePanelBody/DetailLabel") as Label
	var install_button := overlay.get_node("HotUpdateOverlayRoot/HotUpdatePanel/HotUpdatePanelBody/HotUpdateButtons/InstallButton") as Button
	_expect(overlay.visible, "Overlay should be visible after show_idle")
	_expect(status_label.text == "Update service ready.", "Idle status should be visible")
	_expect(install_button.disabled, "Install button should start disabled")

	manager.manifest_ready.emit({}, [{"id": "core_patch"}])
	_expect(status_label.text == "Update manifest ready.", "Manifest ready status should be visible")
	_expect(not install_button.disabled, "Install button should enable when packages are pending")
	_expect(detail_label.text.contains("1 package"), "Pending package count should be shown")

	install_button.pressed.emit()
	_expect(manager.install_count == 1, "Install button should call manager install")
	_expect(status_label.text == "Update installed.", "Install completion should update status")
	_expect(install_button.disabled, "Install button should disable after install")

	if failures.is_empty():
		print("[HotUpdateStatusOverlayTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[HotUpdateStatusOverlayTest] " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
