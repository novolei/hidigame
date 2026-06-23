shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform sampler2D base_texture : source_color;
uniform bool use_base_texture = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D paint_texture : source_color;
uniform float paint_display_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform bool paint_exact_color_match = false;
uniform float paint_roughness : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float paint_metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float paint_specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform sampler2D paint_normal_texture : hint_normal;
uniform bool use_paint_normal_texture = false;
uniform float paint_normal_scale : hint_range(0.0, 2.0, 0.01) = 1.0;

void fragment() {
	vec4 base = base_color;
	if (use_base_texture) {
		base *= texture(base_texture, UV);
	}

	vec4 paint = texture(paint_texture, UV);
	float paint_alpha = clamp(paint.a, 0.0, 1.0);
	float paint_blend = clamp(paint_alpha * paint_display_strength, 0.0, 1.0);

	if (paint_exact_color_match) {
		ALBEDO = mix(base.rgb, vec3(0.0), paint_blend);
		EMISSION = paint.rgb * paint_blend;
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		SPECULAR = paint_specular;
	} else {
		ALBEDO = mix(base.rgb, paint.rgb, paint_blend);
		EMISSION = vec3(0.0);
		ROUGHNESS = paint_roughness;
		METALLIC = paint_metallic;
		SPECULAR = paint_specular;
		if (use_paint_normal_texture && paint_blend > 0.001) {
			NORMAL_MAP = texture(paint_normal_texture, UV).rgb;
			NORMAL_MAP_DEPTH = paint_normal_scale * paint_blend;
		}
	}
}
