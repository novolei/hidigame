@tool
extends RefCounted
class_name StartupBrandRenderer

const APP_NAME := "Monster & Hunter"
const FONT_PATH := "res://assets/fonts/startup/SairaStencil-ExtraBoldItalic.ttf"
const BACKGROUND_COLOR := Color8(45, 143, 252, 255)
const LOGO_BASE_SIZE := 132.0
const GAP_BASE_SIZE := 18.0
const WORDMARK_BASE_SIZE := Vector2(840.0, 132.0)
const WORDMARK_VIEWPORT_SIZE := Vector2i(1680, 264)
const WORDMARK_ROTATION_DEGREES := Vector3(-2.8, -7.2, 0.0)
const WORDMARK_MESH_SCALE := Vector3(1.0, 1.24, 1.0)
const WORDMARK_HORIZONTAL_BIAS := -0.010
const WORDMARK_FONT_SIZE := 62
const WORDMARK_GLYPH_SPACING := -3
const WORDMARK_SPACE_SPACING := -10
const WORDMARK_PIXEL_SIZE := 0.0208
const WORDMARK_DEPTH := 0.165
const WORDMARK_CURVE_STEP := 0.16
const WORDMARK_TEXT_WIDTH := 620.0


static func load_wordmark_font() -> Font:
	var resource := ResourceLoader.load(FONT_PATH)
	if resource is Font:
		var variation := FontVariation.new()
		variation.base_font = resource
		var text_server := TextServerManager.get_primary_interface()
		if text_server != null:
			variation.variation_opentype = { text_server.name_to_tag("wght"): 800 }
		variation.set_spacing(TextServer.SPACING_GLYPH, WORDMARK_GLYPH_SPACING)
		variation.set_spacing(TextServer.SPACING_SPACE, WORDMARK_SPACE_SPACING)
		return variation
	return null


static func create_wordmark_container(font: Font) -> Control:
	var container := Control.new()
	container.name = "Wordmark3D"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = false

	var viewport := create_wordmark_viewport(font, WORDMARK_VIEWPORT_SIZE)
	container.add_child(viewport)

	for index in range(1, 4):
		var trail := TextureRect.new()
		trail.name = "WordmarkTrail%d" % index
		trail.texture = viewport.get_texture()
		trail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trail.stretch_mode = TextureRect.STRETCH_SCALE
		trail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trail.modulate = Color(0.560, 0.660, 0.850, 0.0)
		trail.size = WORDMARK_BASE_SIZE
		container.add_child(trail)

	var glow := TextureRect.new()
	glow.name = "WordmarkGlow"
	glow.texture = viewport.get_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate = Color(0.760, 0.840, 1.0, 0.24)
	glow.size = WORDMARK_BASE_SIZE
	container.add_child(glow)

	var texture := TextureRect.new()
	texture.name = "WordmarkTexture"
	texture.texture = viewport.get_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.size = WORDMARK_BASE_SIZE
	container.add_child(texture)
	return container


static func create_wordmark_viewport(font: Font, viewport_size: Vector2i = WORDMARK_VIEWPORT_SIZE) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "WordmarkViewport"
	viewport.size = viewport_size
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var root := Node3D.new()
	root.name = "WordmarkScene"
	viewport.add_child(root)

	var mesh := _create_text_mesh(font)
	var text := MeshInstance3D.new()
	text.name = "WordmarkTextMesh"
	text.mesh = mesh
	text.material_override = _create_wordmark_material()
	text.rotation_degrees = WORDMARK_ROTATION_DEGREES
	text.scale = WORDMARK_MESH_SCALE
	root.add_child(text)

	var camera := Camera3D.new()
	camera.name = "WordmarkCamera"
	root.add_child(camera)
	_fit_camera_to_wordmark(camera, text, mesh)
	return viewport


static func sync_wordmark_container(container: Control) -> void:
	var viewport := container.get_node_or_null("WordmarkViewport") as SubViewport
	if viewport != null:
		viewport.size = Vector2i(maxi(2, int(roundf(container.size.x * 2.0))), maxi(2, int(roundf(container.size.y * 2.0))))
	for index in range(1, 4):
		var trail := container.get_node_or_null("WordmarkTrail%d" % index) as TextureRect
		if trail != null:
			trail.position = Vector2.ZERO
			trail.size = container.size
	var glow := container.get_node_or_null("WordmarkGlow") as TextureRect
	if glow != null:
		var glow_pad := container.size * 0.028
		glow.position = -glow_pad
		glow.size = container.size + glow_pad * 2.0
	var texture := container.get_node_or_null("WordmarkTexture") as TextureRect
	if texture != null:
		texture.position = Vector2.ZERO
		texture.size = container.size


static func _create_text_mesh(font: Font) -> TextMesh:
	var mesh := TextMesh.new()
	mesh.text = APP_NAME
	mesh.font = font if font != null else load_wordmark_font()
	mesh.font_size = WORDMARK_FONT_SIZE
	mesh.pixel_size = WORDMARK_PIXEL_SIZE
	mesh.curve_step = WORDMARK_CURVE_STEP
	mesh.depth = WORDMARK_DEPTH
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mesh.width = WORDMARK_TEXT_WIDTH
	return mesh


static func _fit_camera_to_wordmark(camera: Camera3D, text: MeshInstance3D, mesh: TextMesh) -> void:
	var aabb := mesh.get_aabb()
	var center := aabb.position + aabb.size * 0.5
	var content_width := maxf(0.01, aabb.size.x * WORDMARK_MESH_SCALE.x)
	var content_height := maxf(0.01, aabb.size.y * WORDMARK_MESH_SCALE.y)
	var horizontal_bias := content_width * WORDMARK_HORIZONTAL_BIAS
	text.position = Vector3(-center.x + horizontal_bias, -center.y, 0.0)

	var aspect := WORDMARK_BASE_SIZE.x / WORDMARK_BASE_SIZE.y
	var camera_height := content_height * 1.035
	if camera_height * aspect < content_width * 1.025:
		camera_height = (content_width * 1.025) / aspect

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_height
	camera.near = 0.01
	camera.far = 20.0
	camera.position = Vector3(0.0, 0.0, 7.0)
	camera.current = true


static func _create_wordmark_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 face_color : source_color = vec4(0.965, 0.957, 0.937, 1.0);
uniform vec4 face_shadow_color : source_color = vec4(0.900, 0.895, 0.875, 1.0);
uniform vec4 outline_color : source_color = vec4(0.561, 0.659, 0.847, 1.0);
uniform vec4 outline_shadow_color : source_color = vec4(0.330, 0.420, 0.610, 1.0);
uniform vec4 rim_color : source_color = vec4(0.730, 0.800, 0.930, 1.0);

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float face_y = clamp(UV.y / 0.40, 0.0, 1.0);
	float side_uv = smoothstep(0.740, 0.865, UV.y);
	float side_normal = smoothstep(0.220, 0.780, 1.0 - abs(NORMAL.z));
	float outline_mask = max(side_uv, side_normal * 0.86);
	float rim_mask = smoothstep(0.020, 0.130, face_y) * smoothstep(1.000, 0.720, face_y) * 0.18;
	float matte_noise = (grain(FRAGCOORD.xy) - 0.5) * 0.008;
	vec3 face = mix(face_color.rgb, face_shadow_color.rgb, smoothstep(0.30, 1.0, face_y) * 0.42);
	vec3 outline = mix(outline_color.rgb, outline_shadow_color.rgb, smoothstep(0.820, 1.0, UV.y) * 0.45);
	vec3 base = mix(face, outline, outline_mask);
	base = mix(base, rim_color.rgb, rim_mask * (1.0 - side_uv));
	base += vec3(matte_noise);
	ALBEDO = base;
	ALPHA = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
