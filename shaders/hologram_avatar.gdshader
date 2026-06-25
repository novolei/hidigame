shader_type spatial;
render_mode blend_add, depth_draw_always, cull_disabled, unshaded;

uniform sampler2D source_texture : source_color;
uniform bool use_source_texture = false;
uniform vec4 source_tint : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform vec4 hologram_color : source_color = vec4(0.05, 0.82, 1.0, 0.82);
uniform vec4 fresnel_color : source_color = vec4(0.64, 1.0, 1.0, 1.0);
uniform vec4 scan_color : source_color = vec4(0.10, 0.92, 1.0, 1.0);
uniform float inherited_skin_strength : hint_range(0.0, 1.0) = 0.45;
uniform float emission_power : hint_range(0.0, 8.0) = 2.8;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.62;
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.25;
uniform float scan_line_repetitions : hint_range(1.0, 180.0) = 62.0;
uniform float scan_line_speed : hint_range(-10.0, 10.0) = 1.35;
uniform float scan_line_width : hint_range(0.002, 0.48) = 0.055;
uniform float scan_line_intensity : hint_range(0.0, 4.0) = 1.35;
uniform float color_line_repetitions : hint_range(1.0, 80.0) = 14.0;
uniform float color_line_speed : hint_range(-10.0, 10.0) = -0.42;
uniform float vertex_shift_repetitions : hint_range(1.0, 80.0) = 18.0;
uniform float vertex_shift_speed : hint_range(-10.0, 10.0) = 0.8;
uniform float vertex_shift_strength : hint_range(0.0, 0.05) = 0.006;
uniform float vertical_fade_power : hint_range(0.0, 4.0) = 0.45;

varying vec3 wave_world_coords;

void vertex() {
	wave_world_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = sin((wave_world_coords.y * vertex_shift_repetitions + TIME * vertex_shift_speed) * TAU);
	float offset = band * vertex_shift_strength;
	VERTEX.x += offset;
	VERTEX.z += cos((wave_world_coords.y * vertex_shift_repetitions - TIME * vertex_shift_speed) * TAU) * vertex_shift_strength * 0.65;
}

void fragment() {
	vec4 sampled = source_tint;
	if (use_source_texture) {
		sampled *= texture(source_texture, UV);
	}

	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, fresnel_power);

	float scan_phase = fract(wave_world_coords.y * scan_line_repetitions - TIME * scan_line_speed);
	float scan_distance = abs(scan_phase - 0.5);
	float scan_line = 1.0 - smoothstep(scan_line_width, scan_line_width * 2.2, scan_distance);

	float color_phase = fract(wave_world_coords.y * color_line_repetitions - TIME * color_line_speed);
	float color_band = 0.5 + 0.5 * sin(color_phase * TAU);
	float vertical_fade = clamp(pow(max(wave_world_coords.y + 0.15, 0.0), vertical_fade_power), 0.35, 1.0);

	vec3 inherited_color = sampled.rgb * inherited_skin_strength;
	vec3 final_color = mix(hologram_color.rgb, inherited_color + hologram_color.rgb * 0.45, inherited_skin_strength);
	final_color += fresnel_color.rgb * fresnel * 0.9;
	final_color += scan_color.rgb * scan_line * scan_line_intensity;
	final_color += scan_color.rgb * color_band * 0.12;

	ALBEDO = final_color;
	EMISSION = final_color * emission_power;
	ALPHA = clamp(sampled.a * base_alpha * vertical_fade * (0.38 + fresnel * 0.72 + scan_line * 0.86), 0.0, 1.0);
}
