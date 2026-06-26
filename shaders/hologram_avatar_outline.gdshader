shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded;

uniform vec4 scan_color : source_color = vec4(1.0, 0.28, 0.88, 1.0);
uniform vec4 scan_edge_color : source_color = vec4(0.66, 0.18, 1.0, 1.0);
uniform vec4 scan_glow_color : source_color = vec4(0.2, 0.05, 1.0, 1.0);
uniform vec4 sweep_highlight_color : source_color = vec4(0.72, 0.94, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.08) = 0.006;
uniform float emission_power : hint_range(0.0, 10.0) = 4.75;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.42;
uniform float scan_line_repetitions : hint_range(1.0, 180.0) = 27.0;
uniform float scan_line_speed : hint_range(-10.0, 10.0) = 0.82;
uniform float scan_line_width : hint_range(0.002, 0.48) = 0.03;
uniform float scan_glow_width : hint_range(0.002, 0.8) = 0.068;
uniform float sweep_glitch_rate : hint_range(0.0, 20.0) = 0.62;
uniform float sweep_line_count : hint_range(1.0, 8.0) = 3.0;
uniform float glitch_line_cycle : hint_range(6.0, 64.0) = 24.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 1.4;

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
	VERTEX += NORMAL * outline_width;
	wave_world_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float view_dot = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(view_dot, 0.0, 1.0), fresnel_power);
	float scan_coord = wave_world_coords.y * scan_line_repetitions - TIME * scan_line_speed;
	float scan_core = centered_line(scan_coord, scan_line_width);
	float scan_glow = centered_line(scan_coord, scan_glow_width);
	float line_id = floor(scan_coord);
	float tick = floor(TIME * sweep_glitch_rate + 9.0);
	float envelope = glitch_envelope(fract(TIME * sweep_glitch_rate + 0.19));
	float sweep_scan = scan_core * cluster_scan_lines(line_id, tick, 23.1, sweep_line_count) * envelope;
	float glow_strength = max(scan_glow - scan_core * 0.34, 0.0) * (0.72 + fresnel * 0.38);
	vec3 final_color = mix(scan_color.rgb, scan_edge_color.rgb, fresnel * 0.75) * scan_core * 1.35;
	final_color += scan_glow_color.rgb * glow_strength * 1.35;
	final_color += sweep_highlight_color.rgb * sweep_scan * 1.35;
	ALBEDO = final_color;
	EMISSION = final_color * emission_power;
	ALPHA = clamp(scan_core * line_alpha * (0.35 + fresnel * 0.65) + glow_strength * 0.18 + sweep_scan * 0.42, 0.0, 1.0);
}
