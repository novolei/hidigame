@tool
extends SceneTree

const OUTPUT_PATH := "res://assets/ui/native_boot_brand_splash.png"
const CANVAS_SIZE := Vector2i(1920, 1080)

var _render_viewport: SubViewport


func _initialize() -> void:
	_build_render_tree()
	call_deferred("_capture")


func _build_render_tree() -> void:
	_render_viewport = SubViewport.new()
	_render_viewport.name = "NativeBootSplashViewport"
	_render_viewport.size = CANVAS_SIZE
	_render_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_render_viewport)

	var canvas := Control.new()
	canvas.name = "NativeBootSplashCanvas"
	canvas.size = Vector2(CANVAS_SIZE)
	_render_viewport.add_child(canvas)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = StartupBrandRenderer.BACKGROUND_COLOR
	background.size = Vector2(CANVAS_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)

	var brand := Control.new()
	brand.name = "CenterBrand"
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(brand)

	var logo_size := StartupBrandRenderer.LOGO_BASE_SIZE
	var gap_size := StartupBrandRenderer.GAP_BASE_SIZE
	var wordmark_height := logo_size
	var wordmark_width := roundf(wordmark_height * StartupBrandRenderer.WORDMARK_BASE_SIZE.x / StartupBrandRenderer.WORDMARK_BASE_SIZE.y)
	var total_width := logo_size + gap_size + wordmark_width
	var brand_height := maxf(logo_size, wordmark_height)
	brand.position = Vector2(roundf((CANVAS_SIZE.x - total_width) * 0.5), roundf(CANVAS_SIZE.y * 0.5 - brand_height * 0.5))
	brand.size = Vector2(total_width, brand_height)

	var logo := TextureRect.new()
	logo.name = "LogoTexture"
	logo.texture = ResourceLoader.load("res://icon.png", "Texture2D") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2.ZERO
	logo.size = Vector2(logo_size, logo_size)
	brand.add_child(logo)

	var wordmark := StartupBrandRenderer.create_wordmark_container(StartupBrandRenderer.load_wordmark_font())
	wordmark.position = Vector2(logo_size + gap_size, 0.0)
	wordmark.size = Vector2(wordmark_width, wordmark_height)
	StartupBrandRenderer.sync_wordmark_container(wordmark)
	brand.add_child(wordmark)


func _capture() -> void:
	await process_frame
	await process_frame
	await process_frame
	var texture := _render_viewport.get_texture()
	if texture == null:
		push_error("Native boot splash render failed: viewport texture was null.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Native boot splash render failed: image was empty.")
		quit(1)
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Native boot splash render failed to save %s: %s" % [OUTPUT_PATH, error])
		quit(1)
		return
	print("Saved native boot splash to %s (%sx%s)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	quit(0)
