extends Node

signal fov_changed(value: float)
signal graphics_changed(settings: Dictionary)
signal player_name_changed(player_name: String)

const MAX_PLAYER_NAME_LENGTH := 18

enum GIQuality {
	DISABLED = 0,
	LOW = 1,
	HIGH = 2,
}

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_FOV := 68.0
const MIN_FOV := 55.0
const MAX_FOV := 90.0
const DEBUG_LOG_ENV := "MAOMAO_DEBUG_LOG"

const DEFAULT_DISPLAY_MODE := Window.MODE_FULLSCREEN
const DEFAULT_VSYNC_MODE := DisplayServer.VSYNC_ENABLED
const DEFAULT_MAX_FPS := 0
const DEFAULT_RESOLUTION_SCALE := 1.0
const DEFAULT_SCALE_FILTER := Viewport.SCALING_3D_MODE_BILINEAR
const DEFAULT_TAA := false
const DEFAULT_MSAA := Viewport.MSAA_DISABLED
const DEFAULT_FXAA := false
const DEFAULT_SHADOW_MAPPING := true
const DEFAULT_SSAO_QUALITY := -1
const DEFAULT_SSIL_QUALITY := -1
const DEFAULT_BLOOM := true
const DEFAULT_VOLUMETRIC_FOG := false
const DEFAULT_GI_QUALITY := GIQuality.DISABLED

var camera_fov := DEFAULT_FOV
var display_mode: int = DEFAULT_DISPLAY_MODE
var vsync_mode: int = DEFAULT_VSYNC_MODE
var max_fps: int = DEFAULT_MAX_FPS
var resolution_scale := DEFAULT_RESOLUTION_SCALE
var scale_filter: int = DEFAULT_SCALE_FILTER
var taa_enabled := DEFAULT_TAA
var msaa_3d: int = DEFAULT_MSAA
var fxaa_enabled := DEFAULT_FXAA
var shadow_mapping_enabled := DEFAULT_SHADOW_MAPPING
var ssao_quality: int = DEFAULT_SSAO_QUALITY
var ssil_quality: int = DEFAULT_SSIL_QUALITY
var bloom_enabled := DEFAULT_BLOOM
var volumetric_fog_enabled := DEFAULT_VOLUMETRIC_FOG
var gi_quality: int = DEFAULT_GI_QUALITY
var player_name := ""


func _ready() -> void:
	load_settings()


# -- Player profile name (persisted) ------------------------------------------

func get_player_name() -> String:
	return player_name


func has_player_name() -> bool:
	return not player_name.strip_edges().is_empty()


func set_player_name(value: String) -> void:
	var sanitized := sanitize_player_name(value)
	if sanitized == player_name:
		return
	player_name = sanitized
	_save_settings()
	player_name_changed.emit(player_name)


func sanitize_player_name(value: String) -> String:
	var cleaned := String(value).strip_edges()
	# Collapse internal whitespace and cap length so names stay tidy in lobby/HUD.
	cleaned = cleaned.replace("\n", " ").replace("\t", " ")
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	if cleaned.length() > MAX_PLAYER_NAME_LENGTH:
		cleaned = cleaned.substr(0, MAX_PLAYER_NAME_LENGTH).strip_edges()
	return cleaned


func load_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	camera_fov = clampf(float(config.get_value("video", "camera_fov", DEFAULT_FOV)), MIN_FOV, MAX_FOV)
	display_mode = _normalize_display_mode(config.get_value("video", "display_mode", DEFAULT_DISPLAY_MODE))
	vsync_mode = _normalize_vsync_mode(config.get_value("video", "vsync", DEFAULT_VSYNC_MODE))
	max_fps = _normalize_max_fps(config.get_value("video", "max_fps", DEFAULT_MAX_FPS))
	resolution_scale = _normalize_resolution_scale(config.get_value("video", "resolution_scale", DEFAULT_RESOLUTION_SCALE))
	scale_filter = _normalize_scale_filter(config.get_value("video", "scale_filter", DEFAULT_SCALE_FILTER))
	taa_enabled = bool(config.get_value("rendering", "taa", DEFAULT_TAA))
	msaa_3d = _normalize_msaa(config.get_value("rendering", "msaa", DEFAULT_MSAA))
	fxaa_enabled = bool(config.get_value("rendering", "fxaa", DEFAULT_FXAA))
	shadow_mapping_enabled = bool(config.get_value("rendering", "shadow_mapping", DEFAULT_SHADOW_MAPPING))
	ssao_quality = _normalize_ao_quality(config.get_value("rendering", "ssao_quality", DEFAULT_SSAO_QUALITY), true)
	ssil_quality = _normalize_ao_quality(config.get_value("rendering", "ssil_quality", DEFAULT_SSIL_QUALITY), false)
	bloom_enabled = bool(config.get_value("rendering", "bloom", DEFAULT_BLOOM))
	volumetric_fog_enabled = bool(config.get_value("rendering", "volumetric_fog", DEFAULT_VOLUMETRIC_FOG))
	gi_quality = _normalize_gi_quality(config.get_value("rendering", "gi_quality", DEFAULT_GI_QUALITY))
	player_name = sanitize_player_name(str(config.get_value("profile", "player_name", "")))


func set_camera_fov(value: float) -> void:
	var normalized := clampf(value, MIN_FOV, MAX_FOV)
	if is_equal_approx(camera_fov, normalized):
		return
	camera_fov = normalized
	_save_settings()
	fov_changed.emit(camera_fov)


func reset_camera_fov() -> void:
	set_camera_fov(DEFAULT_FOV)


func graphics_settings() -> Dictionary:
	return {
		"display_mode": display_mode,
		"vsync": vsync_mode,
		"max_fps": max_fps,
		"resolution_scale": resolution_scale,
		"scale_filter": scale_filter,
		"taa": taa_enabled,
		"msaa": msaa_3d,
		"fxaa": fxaa_enabled,
		"shadow_mapping": shadow_mapping_enabled,
		"ssao_quality": ssao_quality,
		"ssil_quality": ssil_quality,
		"bloom": bloom_enabled,
		"volumetric_fog": volumetric_fog_enabled,
		"gi_quality": gi_quality,
	}


func set_graphics_setting(key: String, value) -> void:
	var values := graphics_settings()
	if not values.has(key):
		return
	values[key] = value
	set_graphics_settings(values)


func set_graphics_settings(values: Dictionary) -> void:
	var before := graphics_settings()
	_apply_graphics_values(values)
	var after := graphics_settings()
	if before == after:
		return
	_save_settings()
	graphics_changed.emit(after)


func reset_graphics_settings() -> void:
	set_graphics_settings({
		"display_mode": DEFAULT_DISPLAY_MODE,
		"vsync": DEFAULT_VSYNC_MODE,
		"max_fps": DEFAULT_MAX_FPS,
		"resolution_scale": DEFAULT_RESOLUTION_SCALE,
		"scale_filter": DEFAULT_SCALE_FILTER,
		"taa": DEFAULT_TAA,
		"msaa": DEFAULT_MSAA,
		"fxaa": DEFAULT_FXAA,
		"shadow_mapping": DEFAULT_SHADOW_MAPPING,
		"ssao_quality": DEFAULT_SSAO_QUALITY,
		"ssil_quality": DEFAULT_SSIL_QUALITY,
		"bloom": DEFAULT_BLOOM,
		"volumetric_fog": DEFAULT_VOLUMETRIC_FOG,
		"gi_quality": DEFAULT_GI_QUALITY,
	})


func apply_graphics_settings(window: Window, viewport: Viewport, environment: Environment, scene_root: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if window:
		window.set("mode", display_mode)
	DisplayServer.window_set_vsync_mode(vsync_mode)
	Engine.max_fps = max_fps
	if viewport:
		viewport.scaling_3d_scale = resolution_scale
		viewport.set("scaling_3d_mode", scale_filter)
		viewport.use_taa = taa_enabled
		viewport.set("msaa_3d", msaa_3d)
		viewport.set("screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA if fxaa_enabled else Viewport.SCREEN_SPACE_AA_DISABLED)
	if environment:
		_apply_environment_settings(environment)
	if scene_root and not shadow_mapping_enabled:
		_set_scene_shadows_enabled(scene_root, false)


func should_log_runtime_debug() -> bool:
	return _environment_bool(DEBUG_LOG_ENV, OS.is_debug_build() and DisplayServer.get_name() != "headless")


func _apply_graphics_values(values: Dictionary) -> void:
	display_mode = _normalize_display_mode(values.get("display_mode", display_mode))
	vsync_mode = _normalize_vsync_mode(values.get("vsync", vsync_mode))
	max_fps = _normalize_max_fps(values.get("max_fps", max_fps))
	resolution_scale = _normalize_resolution_scale(values.get("resolution_scale", resolution_scale))
	scale_filter = _normalize_scale_filter(values.get("scale_filter", scale_filter))
	taa_enabled = bool(values.get("taa", taa_enabled))
	msaa_3d = _normalize_msaa(values.get("msaa", msaa_3d))
	fxaa_enabled = bool(values.get("fxaa", fxaa_enabled))
	shadow_mapping_enabled = bool(values.get("shadow_mapping", shadow_mapping_enabled))
	ssao_quality = _normalize_ao_quality(values.get("ssao_quality", ssao_quality), true)
	ssil_quality = _normalize_ao_quality(values.get("ssil_quality", ssil_quality), false)
	bloom_enabled = bool(values.get("bloom", bloom_enabled))
	volumetric_fog_enabled = bool(values.get("volumetric_fog", volumetric_fog_enabled))
	gi_quality = _normalize_gi_quality(values.get("gi_quality", gi_quality))


func _apply_environment_settings(environment: Environment) -> void:
	_set_property_if_present(environment, "ssao_enabled", ssao_quality != -1)
	if ssao_quality != -1:
		RenderingServer.environment_set_ssao_quality(ssao_quality, ssao_quality == RenderingServer.ENV_SSAO_QUALITY_HIGH, 0.5, 2, 50, 300)
	_set_property_if_present(environment, "ssil_enabled", ssil_quality != -1)
	if ssil_quality != -1:
		RenderingServer.environment_set_ssil_quality(ssil_quality, ssil_quality == RenderingServer.ENV_SSIL_QUALITY_HIGH, 0.5, 2, 50, 300)
	_set_property_if_present(environment, "glow_enabled", bloom_enabled)
	_set_property_if_present(environment, "volumetric_fog_enabled", volumetric_fog_enabled)
	var gi_enabled := gi_quality != GIQuality.DISABLED
	_set_property_if_present(environment, "sdfgi_enabled", gi_enabled)
	if gi_enabled:
		_set_property_if_present(environment, "sdfgi_cascades", 4 if gi_quality == GIQuality.LOW else 6)
		_set_property_if_present(environment, "sdfgi_min_cell_size", 1.5 if gi_quality == GIQuality.LOW else 0.75)


func _set_scene_shadows_enabled(root: Node, enabled: bool) -> void:
	var lights: Array[Node] = root.find_children("*", "Light3D", true, false)
	for node in lights:
		var light := node as Light3D
		if light:
			light.shadow_enabled = enabled


func _set_property_if_present(object: Object, property_name: String, value) -> void:
	if object == null:
		return
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			object.set(property_name, value)
			return


func _normalize_display_mode(value) -> int:
	var mode := int(value)
	if mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		return mode
	return DEFAULT_DISPLAY_MODE


func _normalize_vsync_mode(value) -> int:
	var mode := int(value)
	if mode in [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX]:
		return mode
	return DEFAULT_VSYNC_MODE


func _normalize_max_fps(value) -> int:
	return clampi(int(value), 0, 1000)


func _normalize_resolution_scale(value) -> float:
	return clampf(float(value), 0.33, 1.0)


func _normalize_scale_filter(value) -> int:
	var mode := int(value)
	if mode in [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2]:
		return mode
	return DEFAULT_SCALE_FILTER


func _normalize_msaa(value) -> int:
	var mode := int(value)
	if mode in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]:
		return mode
	return DEFAULT_MSAA


func _normalize_ao_quality(value, _ssao: bool) -> int:
	var quality := int(value)
	if quality in [-1, RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH]:
		return quality
	return -1


func _normalize_gi_quality(value) -> int:
	var quality := int(value)
	if quality in [GIQuality.DISABLED, GIQuality.LOW, GIQuality.HIGH]:
		return quality
	return DEFAULT_GI_QUALITY


func _environment_bool(env_name: String, default_value: bool) -> bool:
	var raw_value := OS.get_environment(env_name).strip_edges().to_lower()
	if raw_value in ["1", "true", "yes", "on"]:
		return true
	if raw_value in ["0", "false", "no", "off"]:
		return false
	return default_value


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("video", "camera_fov", camera_fov)
	config.set_value("video", "display_mode", display_mode)
	config.set_value("video", "vsync", vsync_mode)
	config.set_value("video", "max_fps", max_fps)
	config.set_value("video", "resolution_scale", resolution_scale)
	config.set_value("video", "scale_filter", scale_filter)
	config.set_value("rendering", "taa", taa_enabled)
	config.set_value("rendering", "msaa", msaa_3d)
	config.set_value("rendering", "fxaa", fxaa_enabled)
	config.set_value("rendering", "shadow_mapping", shadow_mapping_enabled)
	config.set_value("rendering", "ssao_quality", ssao_quality)
	config.set_value("rendering", "ssil_quality", ssil_quality)
	config.set_value("rendering", "bloom", bloom_enabled)
	config.set_value("rendering", "volumetric_fog", volumetric_fog_enabled)
	config.set_value("rendering", "gi_quality", gi_quality)
	config.set_value("profile", "player_name", player_name)
	config.save(CONFIG_PATH)
