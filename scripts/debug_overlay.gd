extends Label
class_name DebugOverlay

const DEFAULT_POSITION := Vector2(12.0, 12.0)
const DEFAULT_SIZE := Vector2(320.0, 118.0)
const MEMORY_BYTES_TO_MIB := 1048576.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = DEFAULT_POSITION
	custom_minimum_size = DEFAULT_SIZE
	size = DEFAULT_SIZE
	z_index = 100
	visible = true
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_color", Color(0.9, 1.0, 0.92, 1.0))
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	_refresh_text()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_refresh_text()


func _refresh_text() -> void:
	text = "FPS: " + str(Engine.get_frames_per_second())
	text += "\nVSync: " + ("Enabled" if _is_vsync_enabled() else "Disabled")
	text += "\nBenchmark: " + _benchmark_status()
	text += "\nMemory: " + "%3.2f" % _static_memory_mib() + " MiB"

	var online: bool = _is_online_multiplayer()
	text += "\nOnline: " + ("Yes" if online else "No")
	if online:
		text += "\nMultiplayer ID: " + str(multiplayer.get_unique_id())


func _is_vsync_enabled() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


func _benchmark_status() -> String:
	if not is_inside_tree():
		return "Off"
	var tree: SceneTree = get_tree()
	if tree == null:
		return "Off"
	var level: Node = tree.get_first_node_in_group("party_monster_level")
	if level and level.has_method("get_benchmark_status_text"):
		return str(level.call("get_benchmark_status_text"))
	return "Off"


func _static_memory_mib() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / MEMORY_BYTES_TO_MIB


func _is_online_multiplayer() -> bool:
	var multiplayer_api: MultiplayerAPI = multiplayer
	if multiplayer_api == null:
		return false
	var peer: MultiplayerPeer = multiplayer_api.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
