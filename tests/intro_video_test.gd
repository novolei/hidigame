extends Control

const INTRO_SCENE_PATH := "res://scenes/ui/intro_video.tscn"
const EXPECTED_BADGE_ASPECT := 274.0 / 419.0
const ASPECT_TOLERANCE := 0.01


func _ready() -> void:
	await get_tree().process_frame
	var intro_scene := load(INTRO_SCENE_PATH) as PackedScene
	_assert(intro_scene != null, "Intro scene loads")
	var intro := intro_scene.instantiate() as IntroVideo
	_assert(intro != null, "Intro scene instantiates as IntroVideo")
	add_child(intro)
	await get_tree().process_frame

	var video_player := intro.get_node_or_null("VideoStreamPlayer") as VideoStreamPlayer
	_assert(video_player != null, "Video player exists")
	_assert(video_player.stream != null, "Intro video stream is assigned")
	_assert(video_player.get_stream_length() >= 4.0, "Intro video has a valid playback duration")
	_assert(video_player.expand, "Intro video expands to the viewport")
	await get_tree().create_timer(0.35).timeout
	_assert(video_player.is_playing(), "Intro video starts playing")

	var badge := intro.get_node_or_null("RatingBadge") as TextureRect
	var badge_background := intro.get_node_or_null("RatingBadgeBackground") as Panel
	_assert(badge != null, "ESRB badge exists")
	_assert(badge_background != null, "ESRB rounded background exists")
	_assert(badge.texture != null, "ESRB SVG texture is assigned")
	_assert(badge.texture.resource_path == "res://assets/ui/esrb_everyone_10_plus.svg", "ESRB uses SVG asset")
	_assert(badge.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "ESRB keeps its aspect ratio")

	var layout := intro.get_rating_badge_layout_for_test()
	var aspect := float(layout.get("aspect", 0.0))
	var badge_size := layout.get("badge_size", Vector2.ZERO) as Vector2
	var background_size := layout.get("background_size", Vector2.ZERO) as Vector2
	_assert(absf(aspect - EXPECTED_BADGE_ASPECT) <= ASPECT_TOLERANCE, "ESRB aspect ratio is preserved")
	_assert(badge_size.y <= 132.0, "ESRB badge remains small at 1080p")
	_assert(background_size.x > badge_size.x and background_size.y > badge_size.y, "Rounded background pads the badge")

	print("[IntroVideoTest] PASS")
	get_tree().quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("[IntroVideoTest] FAIL: %s" % message)
	get_tree().quit(1)
