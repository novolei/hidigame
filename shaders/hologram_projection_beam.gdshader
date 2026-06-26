shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 shield_cyan_color : source_color = vec4(0.08, 0.92, 1.0, 0.58);
uniform vec4 shield_purple_color : source_color = vec4(0.74, 0.18, 1.0, 0.52);
uniform vec4 shield_red_color : source_color = vec4(1.0, 0.18, 0.38, 0.56);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float emission_power : hint_range(0.0, 10.0) = 4.2;
uniform float fresnel_power : hint_range(0.5, 10.0) = 2.4;
uniform float center_visibility : hint_range(0.0, 1.0) = 0.18;
uniform float hex_scale : hint_range(2.0, 80.0) = 20.0;
uniform float hex_edge_width : hint_range(0.001, 0.2) = 0.045;
uniform float hex_fill_strength : hint_range(0.0, 1.0) = 0.34;
uniform float ring_speed : hint_range(-4.0, 4.0) = 0.42;
uniform float ring_density : hint_range(1.0, 16.0) = 5.2;
uniform float ring_width : hint_range(0.005, 0.3) = 0.075;
uniform float segment_density : hint_range(1.0, 32.0) = 12.0;
uniform float wave_height : hint_range(0.0, 0.08) = 0.018;
uniform float shield_alpha_limit : hint_range(0.0, 1.0) = 0.48;
uniform float vertical_fade_power : hint_range(0.0, 4.0) = 0.82;

varying vec3 wave_world_coords;
varying float v_noise;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float hex_distance(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

vec4 hex_grid(vec2 uv) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = uv - gv;
	return vec4(gv, id);
}

float line_mask(float value, float width) {
	float dist = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width * 1.75, dist);
}

void vertex() {
	wave_world_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float angular = atan(NORMAL.z, NORMAL.x) / TAU + 0.5;
	float n = value_noise(vec2(angular * 7.0, UV.y * 5.0) + TIME * vec2(0.18, -0.1));
	v_noise = n;
	VERTEX += NORMAL * ((n - 0.5) * 2.0 * wave_height);
}

void fragment() {
	float view_dot = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(view_dot, 0.0, 1.0), fresnel_power);
	float vertical_fade = pow(1.0 - clamp(UV.y, 0.0, 1.0), vertical_fade_power);
	vertical_fade = mix(0.45, 1.0, vertical_fade);

	vec2 shield_uv = vec2(UV.x + TIME * 0.035, UV.y);
	vec4 hex = hex_grid(vec2(shield_uv.x * hex_scale, shield_uv.y * hex_scale * 1.12));
	float hex_dist = hex_distance(hex.xy);
	float hex_edge = 1.0 - smoothstep(0.5 - hex_edge_width, 0.5, hex_dist);
	hex_edge *= smoothstep(0.36, 0.5, hex_dist);
	float hex_fill = (1.0 - smoothstep(0.34, 0.5, hex_dist)) * hex_fill_strength;
	float hex_random = hash21(floor(hex.zw));
	float active_cell = step(0.42 + 0.2 * sin(TIME * 1.4), hex_random);

	float red_arc = line_mask(UV.x * segment_density + UV.y * 1.65 - TIME * ring_speed, ring_width);
	float cyan_arc = line_mask(UV.x * segment_density - UV.y * 1.45 + TIME * ring_speed * 0.8, ring_width * 0.85);
	float shield_ring = line_mask(UV.y * ring_density - TIME * ring_speed, ring_width);
	float outer_rim = smoothstep(0.62, 1.0, fresnel);

	float color_phase = 0.5 + 0.5 * sin((UV.x * 1.25 + UV.y * 0.6 - TIME * 0.12) * TAU);
	vec3 cyan_to_purple = mix(shield_cyan_color.rgb, shield_purple_color.rgb, smoothstep(0.12, 0.82, color_phase));
	vec3 neon_color = mix(cyan_to_purple, shield_red_color.rgb, smoothstep(0.45, 1.0, UV.y + red_arc * 0.42));
	neon_color = mix(neon_color, shield_cyan_color.rgb, cyan_arc * 0.5);
	neon_color = mix(neon_color, shield_red_color.rgb, red_arc * 0.72);

	float noise_glow = v_noise * (0.28 + fresnel * 0.95);
	float shield_body = center_visibility + fresnel * 0.82 + hex_fill * active_cell + noise_glow * 0.32;
	float pattern = hex_edge * (0.85 + active_cell * 0.65) + shield_ring * 0.75 + red_arc * 1.15 + cyan_arc * 0.95 + outer_rim * 0.72;
	float alpha = (shield_body * 0.28 + pattern * 0.42) * base_alpha * vertical_fade;

	ALBEDO = neon_color;
	EMISSION = neon_color * emission_power * (0.45 + pattern + fresnel * 1.35 + noise_glow);
	ALPHA = clamp(alpha, 0.0, shield_alpha_limit);
}
