shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D overlay_texture : source_color;
uniform vec2 position_in_atlas;
uniform vec2 size_in_atlas;
uniform uint atlas_index;

uniform float paint_display_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float paint_roughness : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float paint_metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float paint_specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform sampler2D paint_normal_texture : hint_normal;
uniform bool use_paint_normal_texture = false;
uniform float paint_normal_scale : hint_range(0.0, 2.0, 0.01) = 1.0;

void fragment() {
	vec2 atlas_uv = UV2 * size_in_atlas + position_in_atlas;
	bool is_camera_brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;

	if (is_camera_brush) {
		uint exponential_bit = 1u << 30u;
		float distance = -VERTEX.z;
		uint distance_bits = (packHalf2x16(vec2(distance, 0.0)) & 0xFFE0u) << uint(13 - 5);
		uint index_sign_bit = (atlas_index & 0x4u) << uint(31 - 2);
		uint index_exp_bits = (atlas_index & 0x3u) << 24u;
		float b = uintBitsToFloat(exponential_bit | distance_bits | index_sign_bit | index_exp_bits);

		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(atlas_uv - vec2(0.5), b);
	} else {
		vec4 paint = texture(overlay_texture, atlas_uv);
		float paint_alpha = clamp(paint.a * paint_display_strength, 0.0, 1.0);

		ALBEDO = paint.rgb;
		ALPHA = paint_alpha;
		ROUGHNESS = paint_roughness;
		METALLIC = paint_metallic;
		SPECULAR = paint_specular;

		if (use_paint_normal_texture && paint_alpha > 0.001) {
			NORMAL_MAP = texture(paint_normal_texture, UV).rgb;
			NORMAL_MAP_DEPTH = paint_normal_scale * paint_alpha;
		}
	}
}
