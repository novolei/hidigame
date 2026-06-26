shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(0.55, 1.0, 0.94, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.36;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.78;
uniform float emission_power : hint_range(0.0, 16.0) = 8.4;
uniform float ripple_density : hint_range(1.0, 48.0) = 18.0;
uniform float ribbon_density : hint_range(1.0, 48.0) = 14.0;
uniform float flow_speed : hint_range(-10.0, 10.0) = 2.4;
uniform float top_fade : hint_range(0.0, 1.0) = 0.20;
uniform float edge_softness : hint_range(0.001, 0.45) = 0.11;
uniform float side_rail_width : hint_range(0.001, 0.22) = 0.044;
uniform float shimmer_strength : hint_range(0.0, 3.0) = 1.18;
uniform float dual_beam_offset : hint_range(0.0, 0.28) = 0.082;
uniform float beam_thickness : hint_range(0.01, 0.32) = 0.105;
uniform float outline_thickness : hint_range(0.01, 0.42) = 0.172;
uniform float energy_wobble : hint_range(0.0, 1.5) = 0.62;
uniform float pulse_rate : hint_range(0.1, 12.0) = 5.1;
uniform float space_fade_start : hint_range(0.0, 0.4) = 0.035;
uniform float atmospheric_falloff : hint_range(0.2, 4.0) = 1.75;
uniform float cosmic_entry_strength : hint_range(0.0, 2.0) = 0.72;

vec2 random_vec2(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float gradient_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(random_vec2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(random_vec2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(random_vec2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(random_vec2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) + 0.5;
}

float fbm(vec2 uv) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 4; i++) {
		value += amplitude * gradient_noise(uv * frequency);
		frequency *= 2.05;
		amplitude *= 0.5;
	}
	return value;
}

float line_mask(float value, float width) {
	float dist = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width * 1.85, dist);
}

vec2 bolt_mask(vec2 uv, float seed, float side, float width_multiplier) {
	float time = TIME * flow_speed + seed;
	float low_noise = fbm(vec2(uv.y * ribbon_density * 0.19 + seed * 5.73, time * 0.21));
	float high_noise = fbm(vec2(uv.y * ribbon_density * 0.53 + seed * 9.17, -time * 0.15));
	float wave = sin(uv.y * ripple_density * 0.58 + time * 1.4 + seed) * 0.030;
	wave += sin(uv.y * ripple_density * 0.17 - time * 0.9 + seed * 2.1) * 0.021;
	float center = 0.5 + side * dual_beam_offset + (low_noise - 0.5) * energy_wobble * 0.22 + (high_noise - 0.5) * energy_wobble * 0.10 + wave;
	float rough_edge = 0.74 + high_noise * 0.38 + sin(uv.y * 7.3 + time + seed) * 0.08;
	float dist = abs(uv.x - center);
	float core_width = beam_thickness * width_multiplier * rough_edge;
	float outline_width = outline_thickness * width_multiplier * (0.86 + low_noise * 0.20);
	float core = 1.0 - smoothstep(core_width, core_width + edge_softness * 0.08, dist);
	float outline = 1.0 - smoothstep(outline_width, outline_width + edge_softness * 0.16, dist);
	outline = max(outline - core * 0.68, 0.0);
	return vec2(core, outline);
}

void fragment() {
	vec2 uv = UV;
	vec2 beam_a = bolt_mask(uv, 11.0, -1.0, 1.00);
	vec2 beam_b = bolt_mask(uv, 37.0, 1.0, 0.86);
	vec2 beam_c = bolt_mask(uv, 71.0, 0.0, 0.48);

	float core = max(max(beam_a.x, beam_b.x), beam_c.x * 0.78);
	float outline = max(max(beam_a.y, beam_b.y), beam_c.y * 0.58);
	float bridge_band = 1.0 - smoothstep(dual_beam_offset + 0.02, dual_beam_offset + outline_thickness * 1.65, abs(uv.x - 0.5));
	float plasma_noise = fbm(vec2(uv.y * ribbon_density * 0.34 - TIME * flow_speed * 0.18, uv.x * 8.0 + TIME * 0.24));
	float plasma = smoothstep(0.48, 0.88, plasma_noise + outline * 0.25) * bridge_band;
	float rail_left = line_mask(uv.x + side_rail_width * 0.8, side_rail_width);
	float rail_right = line_mask(uv.x - side_rail_width * 0.8, side_rail_width);
	float rails = max(rail_left, rail_right) * smoothstep(0.22, 0.70, abs(uv.x - 0.5) * 2.0);
	float scan = line_mask(uv.y * ripple_density - TIME * flow_speed * 1.45, 0.052) * (0.42 + bridge_band * 0.58);
	float pulse = 0.72 + 0.28 * pow(0.5 + 0.5 * sin(TIME * pulse_rate + uv.y * 8.0), 2.0);
	float shimmer = smoothstep(0.58, 0.96, fbm(vec2(uv.x * 14.0 + TIME * 0.48, uv.y * 22.0 - TIME * flow_speed))) * shimmer_strength;
	float height_ratio = smoothstep(space_fade_start, 1.0, uv.y);
	float orbital_dissolve = 1.0 - smoothstep(0.88, 1.0, uv.y);
	float height_alpha = mix(1.0, top_fade, pow(height_ratio, atmospheric_falloff)) * orbital_dissolve;
	float ground_focus = 1.0 - smoothstep(0.0, 0.15, uv.y);
	float cosmic_window = smoothstep(0.70, 1.0, uv.y);
	float cosmic_pulse = line_mask(uv.y * 5.5 - TIME * max(flow_speed, 0.25) * 0.18, 0.16) * bridge_band * cosmic_window * cosmic_entry_strength;
	float alpha = (outline * base_alpha + core * core_alpha + plasma * 0.22 + rails * 0.16 + scan * 0.17 + shimmer * 0.055 + ground_focus * core * 0.16 + cosmic_pulse * 0.09) * height_alpha * pulse;

	vec3 color = beam_color.rgb;
	vec3 outline_color = mix(color, vec3(1.0), 0.42);
	vec3 hot_core = mix(color, vec3(1.0), 0.88);
	vec3 final_color = mix(color, outline_color, clamp(outline + plasma * 0.44, 0.0, 1.0));
	final_color = mix(final_color, hot_core, clamp(core + scan * 0.34, 0.0, 1.0));

	ALBEDO = final_color;
	EMISSION = final_color * emission_power * (0.46 + outline * 0.84 + core * 1.65 + plasma * 0.78 + scan * 0.58 + rails * 0.44 + ground_focus * 0.30 + cosmic_pulse * 0.42);
	ALPHA = clamp(alpha * beam_color.a, 0.0, 0.92);
}
