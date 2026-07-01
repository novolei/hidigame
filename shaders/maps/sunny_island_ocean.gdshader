shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.78, 0.86, 0.82);
uniform vec4 deep_color : source_color = vec4(0.04, 0.28, 0.56, 0.92);
uniform vec4 foam_color : source_color = vec4(0.86, 0.98, 0.94, 0.78);
uniform float wave_height : hint_range(0.0, 2.0) = 0.34;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.82;
uniform float wave_scale : hint_range(0.01, 2.0) = 0.105;
uniform float foam_radius : hint_range(0.0, 200.0) = 62.0;
uniform float foam_width : hint_range(0.1, 24.0) = 8.0;

varying float wave_mix;
varying float shore_mix;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 893.21));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float slow_wave = sin((world_xz.x * 0.13 + world_xz.y * 0.05) + TIME * wave_speed);
	float cross_wave = sin((world_xz.y * 0.17 - world_xz.x * 0.07) + TIME * wave_speed * 1.37);
	float noise_wave = value_noise(world_xz * wave_scale + vec2(TIME * wave_speed * 0.15, TIME * wave_speed * -0.11)) * 2.0 - 1.0;
	float wave = slow_wave * 0.48 + cross_wave * 0.32 + noise_wave * 0.20;
	VERTEX.y += wave * wave_height;
	wave_mix = wave * 0.5 + 0.5;
	float radius = length(world_xz);
	shore_mix = 1.0 - smoothstep(foam_radius, foam_radius + foam_width, radius);
}

void fragment() {
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shore_mix * 0.72 + wave_mix * 0.18);
	float foam_line = smoothstep(0.24, 0.74, shore_mix) * (0.55 + wave_mix * 0.45);
	ALBEDO = mix(water, foam_color.rgb, foam_line * 0.34);
	ALPHA = mix(deep_color.a, shallow_color.a, shore_mix * 0.65) + foam_line * 0.08;
	ROUGHNESS = 0.28;
	METALLIC = 0.0;
	SPECULAR = 0.42;
}
