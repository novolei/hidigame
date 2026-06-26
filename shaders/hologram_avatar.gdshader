shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D source_texture : source_color;
uniform bool use_source_texture = false;
uniform vec4 source_tint : source_color = vec4(1.0, 0.36, 0.92, 1.0);
uniform vec4 scan_color : source_color = vec4(1.0, 0.28, 0.88, 1.0);
uniform vec4 scan_edge_color : source_color = vec4(0.66, 0.18, 1.0, 1.0);
uniform vec4 scan_glow_color : source_color = vec4(0.22, 0.06, 1.0, 1.0);
uniform vec4 solid_fill_color : source_color = vec4(0.16, 0.05, 0.82, 1.0);
uniform vec4 sweep_highlight_color_a : source_color = vec4(0.78, 0.96, 1.0, 1.0);
uniform vec4 sweep_highlight_color_b : source_color = vec4(0.22, 0.82, 1.0, 1.0);
uniform float emission_power : hint_range(0.0, 10.0) = 5.65;
uniform float solid_fill_alpha : hint_range(0.0, 0.35) = 0.22;
uniform float solid_fill_emission : hint_range(0.0, 3.0) = 0.72;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.9;
uniform float fresnel_power : hint_range(0.1, 10.0) = 1.55;
uniform float scan_line_repetitions : hint_range(1.0, 180.0) = 27.0;
uniform float scan_line_speed : hint_range(-10.0, 10.0) = 0.82;
uniform float scan_line_width : hint_range(0.002, 0.48) = 0.03;
uniform float scan_glow_width : hint_range(0.002, 0.8) = 0.068;
uniform float scan_line_intensity : hint_range(0.0, 8.0) = 2.75;
uniform float scan_glow_intensity : hint_range(0.0, 8.0) = 1.8;
uniform float sweep_highlight_intensity : hint_range(0.0, 8.0) = 3.4;
uniform float sweep_glitch_rate_a : hint_range(0.0, 20.0) = 0.72;
uniform float sweep_glitch_rate_b : hint_range(0.0, 20.0) = 0.48;
uniform float sweep_line_count_a : hint_range(1.0, 8.0) = 4.0;
uniform float sweep_line_count_b : hint_range(1.0, 8.0) = 3.0;
uniform float glitch_line_cycle : hint_range(6.0, 64.0) = 24.0;
uniform float vertex_shift_repetitions : hint_range(1.0, 80.0) = 18.0;
uniform float vertex_shift_speed : hint_range(-10.0, 10.0) = 0.8;
uniform float vertex_shift_strength : hint_range(0.0, 0.05) = 0.005;
uniform float vertical_fade_power : hint_range(0.0, 4.0) = 0.45;

varying vec3 wave_world_coords;

float hash11(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453123);
}

float centered_line(float phase, float width) {
	float distance = abs(fract(phase) - 0.5);
	return 1.0 - smoothstep(width, width * 1.65, distance);
}

float glitch_envelope(float phase) {
	float appear = smoothstep(0.04, 0.18, phase);
	float disappear = 1.0 - smoothstep(0.62, 0.96, phase);
	return appear * disappear;
}

float cluster_scan_lines(float line_id, float tick, float seed, float line_count) {
	float center = floor(hash11(tick + seed) * max(glitch_line_cycle - line_count, 1.0)) + line_count * 0.5;
	float wrapped = mod(line_id - center + glitch_line_cycle * 0.5, glitch_line_cycle) - glitch_line_cycle * 0.5;
	float half_count = max((line_count - 1.0) * 0.5, 0.0);
	return 1.0 - step(half_count + 0.01, abs(wrapped));
}

void vertex() {
	wave_world_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = sin((wave_world_coords.y * vertex_shift_repetitions + TIME * vertex_shift_speed) * TAU);
	float offset = band * vertex_shift_strength;
	VERTEX.x += offset;
	VERTEX.z += cos((wave_world_coords.y * vertex_shift_repetitions - TIME * vertex_shift_speed) * TAU) * vertex_shift_strength * 0.55;
}

void fragment() {
	vec4 sampled = source_tint;
	if (use_source_texture) {
		sampled *= texture(source_texture, UV);
	}

	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, fresnel_power);
	float vertical_fade = clamp(pow(max(wave_world_coords.y + 0.15, 0.0), vertical_fade_power), 0.35, 1.0);

	float scan_coord = wave_world_coords.y * scan_line_repetitions - TIME * scan_line_speed;
	float scan_core = centered_line(scan_coord, scan_line_width);
	float scan_glow = centered_line(scan_coord, scan_glow_width);
	float line_id = floor(scan_coord);

	float tick_a = floor(TIME * sweep_glitch_rate_a);
	float tick_b = floor(TIME * sweep_glitch_rate_b + 17.0);
	float envelope_a = glitch_envelope(fract(TIME * sweep_glitch_rate_a));
	float envelope_b = glitch_envelope(fract(TIME * sweep_glitch_rate_b + 0.37));
	float cluster_a = cluster_scan_lines(line_id, tick_a, 13.7, sweep_line_count_a);
	float cluster_b = cluster_scan_lines(line_id, tick_b, 41.3, sweep_line_count_b);
	float sweep_scan_a = scan_core * cluster_a * envelope_a;
	float sweep_scan_b = scan_core * cluster_b * envelope_b;
	float sweep_highlight = clamp(sweep_scan_a + sweep_scan_b, 0.0, 1.0);

	float core_strength = scan_core * (0.9 + fresnel * 0.22);
	float glow_strength = max(scan_glow - scan_core * 0.34, 0.0) * (0.72 + fresnel * 0.38);
	float solid_strength = solid_fill_alpha * (0.74 + fresnel * 0.26);
	vec3 solid_color = solid_fill_color.rgb * solid_strength * solid_fill_emission;
	vec3 line_color = mix(scan_color.rgb, scan_edge_color.rgb, clamp(fresnel * 0.5 + sweep_highlight * 0.12, 0.0, 1.0));
	vec3 final_color = solid_color;
	final_color += line_color * core_strength * scan_line_intensity;
	final_color += scan_glow_color.rgb * glow_strength * scan_glow_intensity;
	final_color += sweep_highlight_color_a.rgb * sweep_scan_a * sweep_highlight_intensity;
	final_color += sweep_highlight_color_b.rgb * sweep_scan_b * sweep_highlight_intensity * 0.92;

	ALBEDO = final_color;
	EMISSION = final_color * emission_power;
	ALPHA = sampled.a * vertical_fade * clamp(solid_strength + core_strength * line_alpha + glow_strength * 0.32 + sweep_highlight * 0.74, 0.0, 1.0);
}
