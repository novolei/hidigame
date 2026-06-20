@tool
extends EditorPlugin

const AUTOLOAD_NAME := "BootSplashPlus"
const AUTOLOAD_PATH := "res://addons/boot_splash_plus/boot_splash_plus_runtime.gd"

const PLUS_ENABLED := "application/boot_splash+/general/enabled"
const PLUS_RUN_IN_EDITOR := "application/boot_splash+/general/run_in_editor_playtest"
const PLUS_WAIT_FOR_SCENE_LOAD := "application/boot_splash+/general/wait_for_scene_load"
const PLUS_MIN_TIME := "application/boot_splash+/timing/minimum_display_time_seconds"
const PLUS_FADE_IN_TIME := "application/boot_splash+/timing/fade_in_time"
const PLUS_FADE_TIME := "application/boot_splash+/timing/fade_out_time"
const PLUS_BG_MODE := "application/boot_splash+/background/mode"
const PLUS_BG_COLOR := "application/boot_splash+/background/color"
const PLUS_BG_IMAGE := "application/boot_splash+/background/image"
const PLUS_BG_FIT := "application/boot_splash+/background/fit"
const PLUS_BG_ANIMATION := "application/boot_splash+/background/animation"
const PLUS_BG_ANIMATION_DURATION := "application/boot_splash+/background/animation_duration"
const PLUS_BG_BLUR_AMOUNT := "application/boot_splash+/background/blur_amount"
const PLUS_BG_DARKEN_AMOUNT := "application/boot_splash+/background/darken_amount"
const PLUS_OVERLAY_COLOR := "application/boot_splash+/background/overlay_color"
const PLUS_LOGO_IMAGE := "application/boot_splash+/logo/image"
const PLUS_LOGO_SIZE := "application/boot_splash+/logo/size_percent"
const PLUS_LOGO_POSITION := "application/boot_splash+/logo/position"
const PLUS_LOGO_OPACITY := "application/boot_splash+/logo/opacity"
const PLUS_SHOW_FALLBACK_LOGO := "application/boot_splash+/logo/show_fallback_logo"
const PLUS_LOGO_ANIMATION := "application/boot_splash+/logo/animation"
const PLUS_LOGO_ANIMATION_DURATION := "application/boot_splash+/logo/animation_duration"
const PLUS_SHOW_PROGRESS_BAR := "application/boot_splash+/progress_bar/show"
const PLUS_PROGRESS_BAR_POSITION := "application/boot_splash+/progress_bar/position"
const PLUS_PROGRESS_BAR_WIDTH := "application/boot_splash+/progress_bar/width_percent"
const PLUS_PROGRESS_BAR_HEIGHT := "application/boot_splash+/progress_bar/height_px"
const PLUS_PROGRESS_BAR_STYLE := "application/boot_splash+/progress_bar/style"
const PLUS_PROGRESS_BAR_COLOR := "application/boot_splash+/progress_bar/color"
const PLUS_PROGRESS_BAR_BACKGROUND_COLOR := "application/boot_splash+/progress_bar/background_color"
const PLUS_SOUND := "application/boot_splash+/sound/file"
const PLUS_SOUND_VOLUME_DB := "application/boot_splash+/sound/volume_db"
const PLUS_SOUND_PITCH_SCALE := "application/boot_splash+/sound/pitch_scale"
const PLUS_SOUND_DELAY := "application/boot_splash+/sound/delay_seconds"
const PLUS_SOUND_FADE_IN := "application/boot_splash+/sound/fade_in"
const PLUS_SOUND_FADE_IN_TIME := "application/boot_splash+/sound/fade_in_time"
const PLUS_SOUND_FADE_OUT := "application/boot_splash+/sound/fade_out"
const PLUS_SOUND_FADE_OUT_TIME := "application/boot_splash+/sound/fade_out_time"


func _enter_tree() -> void:
	_register_project_settings()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _register_project_settings() -> void:
	_register_setting(PLUS_ENABLED, TYPE_BOOL, _migrated_values(["application/boot_splash+/enabled", "application/boot_splash/plus:_preview_in_playtest"], true))
	_register_setting(PLUS_RUN_IN_EDITOR, TYPE_BOOL, _migrated_value("application/boot_splash+/run_in_editor_playtest", true))
	_register_setting(PLUS_WAIT_FOR_SCENE_LOAD, TYPE_BOOL, _migrated_value("application/boot_splash+/wait_for_scene_load", true))
	_register_setting(PLUS_MIN_TIME, TYPE_FLOAT, _minimum_seconds_default(), PROPERTY_HINT_RANGE, "0,60,0.1,or_greater")
	_register_setting(PLUS_FADE_IN_TIME, TYPE_FLOAT, _migrated_value("application/boot_splash+/fade_in_time", 0.0), PROPERTY_HINT_RANGE, "0,5,0.05,or_greater")
	_register_setting(PLUS_FADE_TIME, TYPE_FLOAT, _migrated_value("application/boot_splash+/fade_out_time", 0.25), PROPERTY_HINT_RANGE, "0,5,0.05,or_greater")
	_register_setting(PLUS_BG_MODE, TYPE_INT, _migrated_values(["application/boot_splash+/background_mode", "application/boot_splash/plus:_background_mode"], 0), PROPERTY_HINT_ENUM, "Color,Image")
	_register_setting(PLUS_BG_COLOR, TYPE_COLOR, _migrated_value("application/boot_splash+/background_color", ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.14, 0.14, 0.14, 1.0))))
	_register_setting(PLUS_BG_IMAGE, TYPE_STRING, _migrated_values(["application/boot_splash+/background_image", "application/boot_splash/plus:_background_image"], ""), PROPERTY_HINT_FILE, "*.png,*.webp,*.jpg,*.jpeg")
	_register_setting(PLUS_BG_FIT, TYPE_INT, _migrated_values(["application/boot_splash+/background_fit", "application/boot_splash/plus:_background_fit"], 0), PROPERTY_HINT_ENUM, "Cover,Contain,Stretch,Tile")
	_register_setting(PLUS_BG_ANIMATION, TYPE_INT, _migrated_value("application/boot_splash+/background_animation", 0), PROPERTY_HINT_ENUM, "None,Slow Zoom In,Slow Zoom Out,Slow Pan")
	_register_setting(PLUS_BG_ANIMATION_DURATION, TYPE_FLOAT, _migrated_value("application/boot_splash+/background_animation_duration", 4.0), PROPERTY_HINT_RANGE, "0.5,30,0.1,or_greater")
	_register_setting(PLUS_BG_BLUR_AMOUNT, TYPE_FLOAT, _migrated_value("application/boot_splash+/background_blur_amount", 0.0), PROPERTY_HINT_RANGE, "0,8,0.5")
	_register_setting(PLUS_BG_DARKEN_AMOUNT, TYPE_FLOAT, _migrated_value("application/boot_splash+/background_darken_amount", 0.0), PROPERTY_HINT_RANGE, "0,1,0.05")
	_register_setting(PLUS_OVERLAY_COLOR, TYPE_COLOR, _migrated_values(["application/boot_splash+/overlay_color", "application/boot_splash/plus:_overlay_color"], Color(0, 0, 0, 0)))
	_register_setting(PLUS_LOGO_IMAGE, TYPE_STRING, _migrated_values(["application/boot_splash+/logo_image", "application/boot_splash/plus:_logo_image"], ""), PROPERTY_HINT_FILE, "*.png,*.webp,*.jpg,*.jpeg,*.svg")
	_register_setting(PLUS_LOGO_SIZE, TYPE_FLOAT, _migrated_values(["application/boot_splash+/logo_size_percent", "application/boot_splash/plus:_logo_size_percent"], 35.0), PROPERTY_HINT_RANGE, "5,90,1")
	_register_setting(PLUS_LOGO_POSITION, TYPE_INT, _migrated_values(["application/boot_splash+/logo_position", "application/boot_splash/plus:_logo_position"], 0), PROPERTY_HINT_ENUM, "Center,Top,Bottom")
	_register_setting(PLUS_LOGO_OPACITY, TYPE_FLOAT, _migrated_value("application/boot_splash+/logo_opacity", 1.0), PROPERTY_HINT_RANGE, "0,1,0.05")
	_register_setting(PLUS_SHOW_FALLBACK_LOGO, TYPE_BOOL, _migrated_values(["application/boot_splash+/show_fallback_logo", "application/boot_splash/plus:_show_fallback_logo"], true))
	_register_setting(PLUS_LOGO_ANIMATION, TYPE_INT, _migrated_value("application/boot_splash+/logo_animation", 0), PROPERTY_HINT_ENUM, "None,Fade In,Fade In Out,Pulse,Scale In,Slight Float")
	_register_setting(PLUS_LOGO_ANIMATION_DURATION, TYPE_FLOAT, _migrated_value("application/boot_splash+/logo_animation_duration", 0.8), PROPERTY_HINT_RANGE, "0.1,10,0.1,or_greater")
	_register_setting(PLUS_SHOW_PROGRESS_BAR, TYPE_BOOL, _migrated_values(["application/boot_splash+/show_progress_bar", "application/boot_splash/plus:_show_progress_bar"], true))
	_register_setting(PLUS_PROGRESS_BAR_POSITION, TYPE_INT, _migrated_value("application/boot_splash+/progress_bar_position", 0), PROPERTY_HINT_ENUM, "Lower Middle,Bottom,More Bottom,Center,Top")
	_register_setting(PLUS_PROGRESS_BAR_WIDTH, TYPE_FLOAT, _migrated_value("application/boot_splash+/progress_bar_width_percent", 46.0), PROPERTY_HINT_RANGE, "5,100,1")
	_register_setting(PLUS_PROGRESS_BAR_HEIGHT, TYPE_INT, _migrated_value("application/boot_splash+/progress_bar_height_px", 10), PROPERTY_HINT_RANGE, "1,100,1,or_greater")
	_register_setting(PLUS_PROGRESS_BAR_STYLE, TYPE_INT, _migrated_value("application/boot_splash+/progress_bar_style", 0), PROPERTY_HINT_ENUM, "Fill,Pulse,Blink")
	_register_setting(PLUS_PROGRESS_BAR_COLOR, TYPE_COLOR, _migrated_values(["application/boot_splash+/progress_bar_color", "application/boot_splash/plus:_progress_bar_color"], Color(0.25, 0.55, 1.0, 1.0)))
	_register_setting(PLUS_PROGRESS_BAR_BACKGROUND_COLOR, TYPE_COLOR, _migrated_values(["application/boot_splash+/progress_bar_background_color", "application/boot_splash/plus:_progress_bar_background_color"], Color(1, 1, 1, 0.22)))
	_register_setting(PLUS_SOUND, TYPE_STRING, _migrated_value("application/boot_splash+/sound", ""), PROPERTY_HINT_FILE, "*.wav,*.ogg,*.mp3")
	_register_setting(PLUS_SOUND_VOLUME_DB, TYPE_FLOAT, _migrated_value("application/boot_splash+/sound_volume_db", 0.0), PROPERTY_HINT_RANGE, "-80,24,0.5")
	_register_setting(PLUS_SOUND_PITCH_SCALE, TYPE_FLOAT, _migrated_value("application/boot_splash+/sound_pitch_scale", 1.0), PROPERTY_HINT_RANGE, "0.25,4,0.05,or_greater")
	_register_setting(PLUS_SOUND_DELAY, TYPE_FLOAT, _migrated_value("application/boot_splash+/sound_delay_seconds", 0.0), PROPERTY_HINT_RANGE, "0,10,0.1,or_greater")
	_register_setting(PLUS_SOUND_FADE_IN, TYPE_BOOL, _migrated_value("application/boot_splash+/fade_in_sound", true))
	_register_setting(PLUS_SOUND_FADE_IN_TIME, TYPE_FLOAT, _migrated_value("application/boot_splash+/sound_fade_in_time", 0.5), PROPERTY_HINT_RANGE, "0,10,0.1,or_greater")
	_register_setting(PLUS_SOUND_FADE_OUT, TYPE_BOOL, _migrated_value("application/boot_splash+/fade_out_sound", true))
	_register_setting(PLUS_SOUND_FADE_OUT_TIME, TYPE_FLOAT, _migrated_value("application/boot_splash+/sound_fade_out_time", 0.5), PROPERTY_HINT_RANGE, "0,10,0.1,or_greater")


func _register_setting(path: String, type: int, default_value: Variant, hint := PROPERTY_HINT_NONE, hint_string := "") -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({
		"name": path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})


func _migrated_value(old_path: String, default_value: Variant) -> Variant:
	if ProjectSettings.has_setting(old_path):
		return ProjectSettings.get_setting(old_path, default_value)
	return default_value


func _migrated_values(old_paths: Array, default_value: Variant) -> Variant:
	for old_path in old_paths:
		if ProjectSettings.has_setting(old_path):
			return ProjectSettings.get_setting(old_path, default_value)
	return default_value


func _minimum_seconds_default() -> float:
	if ProjectSettings.has_setting("application/boot_splash+/minimum_display_time_seconds"):
		return float(ProjectSettings.get_setting("application/boot_splash+/minimum_display_time_seconds", 1.5))
	if ProjectSettings.has_setting("application/boot_splash+/minimum_display_time"):
		return float(ProjectSettings.get_setting("application/boot_splash+/minimum_display_time", 1500)) / 1000.0
	return 1.5
