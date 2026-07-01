shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shallow_color : source_color = vec4(0.14, 0.88, 0.78, 0.78);
uniform vec4 deep_color : source_color = vec4(0.02, 0.40, 0.64, 0.90);
uniform vec4 underwater_color : source_color = vec4(0.05, 0.68, 0.75, 0.58);
uniform vec4 highlight_color : source_color = vec4(0.82, 1.00, 0.92, 0.64);
uniform vec4 foam_color : source_color = vec4(0.88, 1.00, 0.93, 0.72);
uniform float water_time = 0.0;
uniform float max_depth : hint_range(0.1, 5.0) = 1.2;
uniform float depth_fade : hint_range(0.0, 2.0) = 0.70;
uniform float refraction_strength : hint_range(0.0, 0.12) = 0.034;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.42;
uniform float glint_strength : hint_range(0.0, 2.0) = 0.72;
uniform float shore_foam_width : hint_range(0.02, 1.0) = 0.38;
uniform float wave_height : hint_range(0.0, 0.5) = 0.072;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.94;
uniform float flow_scale : hint_range(0.1, 32.0) = 14.6;
uniform float ripple_height : hint_range(0.0, 0.5) = 0.13;
uniform float ripple_speed : hint_range(0.1, 8.0) = 2.9;
uniform float ripple_width : hint_range(0.02, 1.2) = 0.24;
uniform float ripple_decay : hint_range(0.1, 8.0) = 1.95;
uniform int ripple_count = 0;
uniform vec4 ripple0 = vec4(0.0);
uniform vec4 ripple1 = vec4(0.0);
uniform vec4 ripple2 = vec4(0.0);
uniform vec4 ripple3 = vec4(0.0);
uniform vec4 ripple4 = vec4(0.0);
uniform vec4 ripple5 = vec4(0.0);
uniform vec4 ripple6 = vec4(0.0);
uniform vec4 ripple7 = vec4(0.0);
uniform vec4 ripple_dir0 = vec4(0.0);
uniform vec4 ripple_dir1 = vec4(0.0);
uniform vec4 ripple_dir2 = vec4(0.0);
uniform vec4 ripple_dir3 = vec4(0.0);
uniform vec4 ripple_dir4 = vec4(0.0);
uniform vec4 ripple_dir5 = vec4(0.0);
uniform vec4 ripple_dir6 = vec4(0.0);
uniform vec4 ripple_dir7 = vec4(0.0);

varying float wave_mix;
varying float ripple_mix;
varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(173.31, 611.73));
	p += dot(p, p + 23.17);
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

float ripple_from(vec2 world_xz, vec4 data, vec4 direction_data, int slot_index) {
	if (ripple_count <= slot_index || data.w <= 0.001) {
		return 0.0;
	}
	float age = max(water_time - data.z, 0.0);
	float spread = age * ripple_speed;
	float dist = distance(world_xz, data.xy);
	float ring = 1.0 - smoothstep(ripple_width, ripple_width * 2.25, abs(dist - spread));
	float range_fade = 1.0 - smoothstep(data.w * 0.28, data.w, spread);
	float age_fade = exp(-age * ripple_decay);
	float speed_boost = clamp(direction_data.z, 0.55, 1.35);
	return ring * range_fade * age_fade * speed_boost;
}

float ripple_total(vec2 world_xz) {
	float value = 0.0;
	value += ripple_from(world_xz, ripple0, ripple_dir0, 0);
	value += ripple_from(world_xz, ripple1, ripple_dir1, 1);
	value += ripple_from(world_xz, ripple2, ripple_dir2, 2);
	value += ripple_from(world_xz, ripple3, ripple_dir3, 3);
	value += ripple_from(world_xz, ripple4, ripple_dir4, 4);
	value += ripple_from(world_xz, ripple5, ripple_dir5, 5);
	value += ripple_from(world_xz, ripple6, ripple_dir6, 6);
	value += ripple_from(world_xz, ripple7, ripple_dir7, 7);
	return clamp(value, 0.0, 1.35);
}

float linear_depth(float depth_value, vec2 screen_uv, mat4 inv_projection_matrix) {
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_value);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= max(view.w, 0.0001);
	return -view.z;
}

void vertex() {
	vec3 before_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float slow_wave = sin((before_world.x * 0.32 + before_world.z * 0.15) + water_time * wave_speed);
	float cross_wave = sin((before_world.z * 0.41 - before_world.x * 0.12) + water_time * wave_speed * 1.42);
	float noise_wave = value_noise(before_world.xz * 0.21 + vec2(water_time * 0.18, -water_time * 0.13)) * 2.0 - 1.0;
	float wave = slow_wave * 0.44 + cross_wave * 0.32 + noise_wave * 0.24;
	float ripple = ripple_total(before_world.xz);
	VERTEX.y += wave * wave_height + ripple * ripple_height;
	wave_mix = wave * 0.5 + 0.5;
	ripple_mix = ripple;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float edge_distance = min(UV.x, 1.0 - UV.x);
	float bank_edge = 1.0 - smoothstep(0.03, 0.25, edge_distance);
	float center_depth = smoothstep(0.10, 0.50, edge_distance);
	float surface_depth = linear_depth(FRAGCOORD.z, SCREEN_UV, INV_PROJECTION_MATRIX);
	float scene_depth = linear_depth(texture(depth_texture, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX);

	vec2 flow_noise_uv = world_position.xz * 0.115 + vec2(water_time * 0.12, -water_time * 0.09);
	float distort_a = value_noise(flow_noise_uv) * 2.0 - 1.0;
	float distort_b = value_noise(flow_noise_uv * 1.91 + vec2(8.3, -5.7)) * 2.0 - 1.0;
	vec2 distortion = vec2(distort_a, distort_b) * refraction_strength * (0.55 + center_depth * 0.55);
	vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.001), vec2(0.999));
	float refracted_depth = linear_depth(texture(depth_texture, refracted_uv).r, refracted_uv, INV_PROJECTION_MATRIX);
	if (refracted_depth <= surface_depth + 0.015) {
		refracted_uv = SCREEN_UV;
		refracted_depth = scene_depth;
	}

	float water_thickness = clamp(max(refracted_depth - surface_depth, scene_depth - surface_depth), 0.0, max_depth);
	float depth_ratio = clamp(water_thickness / max(max_depth, 0.001), 0.0, 1.0);
	depth_ratio = mix(depth_ratio, center_depth, 0.36);

	float flow = UV.y * flow_scale - water_time * 0.82;
	float caustic_a = smoothstep(0.88, 1.0, sin(flow + sin(UV.x * 10.0) * 1.35) * 0.5 + 0.5);
	float caustic_b = smoothstep(0.91, 1.0, sin(flow * 1.47 + UV.x * 18.0 + world_position.x * 0.07) * 0.5 + 0.5);
	float caustic_noise = smoothstep(0.28, 0.96, value_noise(world_position.xz * 0.42 + vec2(water_time * 0.08, water_time * 0.04)));
	float caustics = (caustic_a * 0.58 + caustic_b * 0.42) * caustic_noise * (0.55 + wave_mix * 0.35);
	float ripple_highlight = clamp(ripple_mix * 0.78, 0.0, 1.0);

	vec2 normal_uv = world_position.xz * 0.78 + vec2(water_time * 0.34, -water_time * 0.19);
	float normal_a = value_noise(normal_uv);
	float normal_b = value_noise(normal_uv + vec2(0.18, 0.0));
	float normal_c = value_noise(normal_uv + vec2(0.0, 0.18));
	vec3 procedural_normal = normalize(vec3((normal_a - normal_b) * normal_strength, 1.0, (normal_a - normal_c) * normal_strength));
	NORMAL = normalize(mix(NORMAL, procedural_normal, clamp(normal_strength, 0.0, 1.0)));
	float fresnel = pow(1.0 - clamp(abs(dot(normalize(VIEW), NORMAL)), 0.0, 1.0), 2.35);
	float glint_lines = smoothstep(0.92, 1.0, sin(flow * 1.92 + world_position.x * 0.18 + normal_a * 4.0) * 0.5 + 0.5);
	glint_lines *= (0.35 + wave_mix * 0.45 + ripple_highlight * 0.35) * glint_strength;

	float shore_depth_foam = 1.0 - smoothstep(0.02, shore_foam_width, water_thickness);
	float shore_noise = smoothstep(0.34, 0.80, value_noise(world_position.xz * 0.88 + vec2(water_time * 0.18, -water_time * 0.11)));
	float shore_foam = shore_depth_foam * shore_noise * (0.42 + bank_edge * 0.58);
	float moving_foam = smoothstep(0.92, 1.0, sin(flow * 0.78 + value_noise(world_position.xz * 0.24) * 5.0) * 0.5 + 0.5) * 0.18;
	float foam = clamp(shore_foam + moving_foam * bank_edge + ripple_highlight * 0.34, 0.0, 1.0);

	vec3 screen_color = texture(screen_texture, refracted_uv).rgb;
	vec3 water_tint = mix(shallow_color.rgb, deep_color.rgb, depth_ratio * 0.92 + center_depth * 0.16);
	vec3 submerged = mix(screen_color, underwater_color.rgb, clamp(depth_ratio * depth_fade, 0.0, 0.82));
	vec3 water = mix(submerged, water_tint, 0.34 + depth_ratio * 0.38);
	float highlight_amount = clamp(caustics * 0.18 + ripple_highlight * 0.24 + fresnel * 0.18 + glint_lines * 0.13, 0.0, 0.62);
	water = mix(water, highlight_color.rgb, highlight_amount);
	water = mix(water, foam_color.rgb, foam * foam_color.a);

	ALBEDO = water;
	EMISSION = highlight_color.rgb * (caustics * 0.09 + ripple_highlight * 0.17 + foam * 0.07 + glint_lines * 0.10 + fresnel * 0.035);
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, depth_ratio) + foam * 0.08 + ripple_highlight * 0.045 + fresnel * 0.04, 0.0, 0.95);
	ROUGHNESS = mix(0.18, 0.07, clamp(glint_lines + fresnel * 0.45, 0.0, 1.0));
	METALLIC = 0.0;
	SPECULAR = clamp(0.78 + fresnel * 0.16 + glint_lines * 0.08, 0.0, 1.0);
}
