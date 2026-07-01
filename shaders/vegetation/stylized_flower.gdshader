shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 stem_color : source_color = vec4(0.18, 0.50, 0.16, 1.0);
uniform vec4 stem_shadow_color : source_color = vec4(0.07, 0.24, 0.08, 1.0);
uniform vec4 petal_color_a : source_color = vec4(0.93, 0.96, 0.88, 1.0);
uniform vec4 petal_color_b : source_color = vec4(0.95, 0.82, 0.92, 1.0);
uniform vec4 petal_color_c : source_color = vec4(0.74, 0.88, 1.0, 1.0);
uniform vec4 petal_color_d : source_color = vec4(0.98, 0.86, 0.45, 1.0);
uniform vec4 petal_color_e : source_color = vec4(0.78, 0.68, 1.0, 1.0);
uniform vec4 center_color : source_color = vec4(0.96, 0.78, 0.24, 1.0);

uniform float veg_time = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.38);
uniform float wind_strength : hint_range(0.0, 3.0) = 0.42;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.78;
uniform float wind_noise_scale : hint_range(0.001, 1.0) = 0.045;
uniform float gust_strength : hint_range(0.0, 2.0) = 0.34;
uniform float wind_flatten_strength : hint_range(0.0, 1.0) = 0.04;

uniform int touch_count = 0;
uniform float touch_push_strength : hint_range(0.0, 3.0) = 0.48;
uniform float touch_crush_strength : hint_range(0.0, 2.0) = 0.42;
uniform float touch_recovery : hint_range(0.1, 8.0) = 0.95;
uniform vec4 touch0 = vec4(0.0);
uniform vec4 touch1 = vec4(0.0);
uniform vec4 touch2 = vec4(0.0);
uniform vec4 touch3 = vec4(0.0);
uniform vec4 touch4 = vec4(0.0);
uniform vec4 touch5 = vec4(0.0);
uniform vec4 touch6 = vec4(0.0);
uniform vec4 touch7 = vec4(0.0);
uniform vec4 touch_dir0 = vec4(0.0);
uniform vec4 touch_dir1 = vec4(0.0);
uniform vec4 touch_dir2 = vec4(0.0);
uniform vec4 touch_dir3 = vec4(0.0);
uniform vec4 touch_dir4 = vec4(0.0);
uniform vec4 touch_dir5 = vec4(0.0);
uniform vec4 touch_dir6 = vec4(0.0);
uniform vec4 touch_dir7 = vec4(0.0);

varying float part_petal;
varying float part_center;
varying float height_weight_varying;
varying float flower_palette;
varying float flower_variant;
varying float flower_color_bias;
varying float wind_light;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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

float attenuation_curve(float normalized_distance) {
	float edge = clamp(normalized_distance, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.0, 1.0, edge);
	return pow(fade, 1.58);
}

vec3 touch_deform(vec3 vertex_position, vec3 world_position, float height_weight, vec4 touch_data, vec4 touch_dir, int slot_index, mat4 inverse_model, vec2 wind) {
	if (touch_count <= slot_index || touch_data.w <= 0.0) {
		return vertex_position;
	}
	float age = max(veg_time - touch_data.z, 0.0);
	float recovery = smoothstep(0.0, 0.16, age) * exp(-age * touch_recovery);
	vec2 diff = world_position.xz - touch_data.xy;
	float radius = max(touch_data.w, 0.001);
	vec2 movement_direction = touch_dir.xy;
	if (length(movement_direction) < 0.05) {
		movement_direction = normalize(wind + vec2(0.001, 0.0));
	} else {
		movement_direction = normalize(movement_direction);
	}
	vec2 side_direction = vec2(-movement_direction.y, movement_direction.x);
	float along_distance = abs(dot(diff, movement_direction)) / max(radius * 0.94, 0.001);
	float side_distance = abs(dot(diff, side_direction)) / max(radius * 0.50, 0.001);
	float footprint_distance = length(vec2(along_distance, side_distance));
	float pressure = attenuation_curve(footprint_distance) * recovery;
	if (pressure <= 0.001) {
		return vertex_position;
	}
	float side_offset = clamp(dot(diff, side_direction) / max(radius * 0.54, 0.001), -1.0, 1.0);
	vec2 fall_world = movement_direction * 0.90 + side_direction * side_offset * 0.12 + wind * 0.08;
	fall_world = normalize(fall_world + vec2(0.001, 0.0));
	vec2 fall_local = (inverse_model * vec4(fall_world.x, 0.0, fall_world.y, 0.0)).xz;
	fall_local = normalize(fall_local + vec2(0.001, 0.0));
	float speed_factor = clamp(touch_dir.z, 0.42, 1.02);
	float bend_weight = pow(clamp(height_weight, 0.0, 1.0), 1.34);
	float crush_weight = pow(clamp(height_weight, 0.0, 1.0), 1.04);
	float push_pressure = pressure * (1.0 - smoothstep(0.70, 1.0, footprint_distance));
	float push_amount = min(push_pressure * touch_push_strength * (0.05 + speed_factor * 0.07) * bend_weight, 0.10);
	float crush_pressure = pow(pressure, 1.30);
	vertex_position.xz += fall_local * push_amount;
	vertex_position.y -= crush_pressure * touch_crush_strength * (0.24 + speed_factor * 0.11) * crush_weight;
	return vertex_position;
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float uv_height = clamp(UV.y, 0.0, 1.0);
	float height_weight = pow(uv_height, 1.22);
	float stiffness = max(INSTANCE_CUSTOM.r, 0.22);
	float phase = INSTANCE_CUSTOM.g * 6.2831853;
	flower_color_bias = INSTANCE_CUSTOM.b;
	flower_palette = INSTANCE_CUSTOM.a;
	part_petal = COLOR.r;
	part_center = COLOR.g;
	flower_variant = COLOR.b;

	vec2 wind = normalize(wind_direction + vec2(0.001, 0.0));
	vec2 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xz;
	local_wind = normalize(local_wind + vec2(0.001, 0.0));
	vec2 wind_sample_position = world_position.xz + wind * veg_time * wind_speed * 20.0;
	vec2 wind_sample = wind_sample_position * wind_noise_scale + vec2(phase, phase * 0.41);
	float wind_noise = value_noise(wind_sample);
	float wind_detail = value_noise(wind_sample * 2.2 + vec2(9.0, -15.0));
	float gust = sin(veg_time * wind_speed * 0.88 + phase + wind_noise * 6.2831853) * 0.5 + 0.5;
	float wind_force = ((wind_noise - 0.5) * 0.92 + (wind_detail - 0.5) * 0.34 + gust * gust_strength) * wind_strength;
	float wind_bend = wind_force * height_weight * stiffness;

	VERTEX.xz += local_wind * wind_bend;
	VERTEX.y -= abs(wind_bend) * wind_flatten_strength * height_weight;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat4 inverse_model = inverse(MODEL_MATRIX);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch0, touch_dir0, 0, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch1, touch_dir1, 1, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch2, touch_dir2, 2, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch3, touch_dir3, 3, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch4, touch_dir4, 4, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch5, touch_dir5, 5, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch6, touch_dir6, 6, inverse_model, wind);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch7, touch_dir7, 7, inverse_model, wind);

	height_weight_varying = uv_height;
	wind_light = clamp(0.34 + wind_noise * 0.40 + gust * 0.22 + wind_force * 0.16, 0.0, 1.0);
}

void fragment() {
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 stem = mix(stem_shadow_color.rgb, stem_color.rgb, 0.72 + height_weight_varying * 0.16);
	float palette = fract(flower_palette + flower_variant * 0.31);
	vec3 petal = petal_color_a.rgb;
	petal = mix(petal, petal_color_b.rgb, smoothstep(0.12, 0.28, palette));
	petal = mix(petal, petal_color_c.rgb, smoothstep(0.34, 0.50, palette));
	petal = mix(petal, petal_color_d.rgb, smoothstep(0.56, 0.72, palette));
	petal = mix(petal, petal_color_e.rgb, smoothstep(0.78, 0.94, palette));
	petal *= 1.0 + flower_color_bias * 0.18;
	vec3 flower_color = mix(stem, petal, clamp(part_petal, 0.0, 1.0));
	flower_color = mix(flower_color, center_color.rgb, clamp(part_center, 0.0, 1.0));
	flower_color *= mix(0.78, 1.12, wind_light);
	ALBEDO = flower_color;
	ALPHA = 0.96;
	ROUGHNESS = 0.88;
}
