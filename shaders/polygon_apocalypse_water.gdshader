shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.36, 0.72, 0.88, 0.54);
uniform vec4 deep_color : source_color = vec4(0.04, 0.24, 0.34, 0.68);
uniform float wave_height = 0.025;
uniform float wave_scale = 0.085;
uniform float wave_speed = 0.55;
uniform float color_variation = 0.16;
uniform float specular_strength = 0.72;
uniform float surface_roughness = 0.24;
uniform float emission_strength = 0.025;

void vertex() {
	float wave_a = sin((VERTEX.x + VERTEX.z * 0.45) * wave_scale * 12.0 + TIME * wave_speed);
	float wave_b = sin((VERTEX.z - VERTEX.x * 0.25) * wave_scale * 16.0 - TIME * wave_speed * 1.35);
	VERTEX.y += (wave_a + wave_b) * 0.5 * wave_height;
}

void fragment() {
	float wave_a = sin((UV.x * 11.0 + UV.y * 5.0) + TIME * wave_speed * 1.8);
	float wave_b = sin((UV.y * 13.0 - UV.x * 4.0) - TIME * wave_speed * 1.3);
	float foam = smoothstep(0.58, 1.0, (wave_a + wave_b) * 0.5 + 0.5);
	vec4 water_color = mix(deep_color, shallow_color, clamp(foam * color_variation + 0.38, 0.0, 1.0));
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
	SPECULAR = specular_strength;
	EMISSION = water_color.rgb * emission_strength;
}
