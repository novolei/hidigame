shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.24, 0.62, 0.17, 1.0);
uniform vec4 tip_color : source_color = vec4(0.50, 0.82, 0.28, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.08, 0.26, 0.08, 1.0);

uniform float veg_time = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.38);
uniform float wind_strength : hint_range(0.0, 3.0) = 0.44;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.78;
uniform float wind_noise_scale : hint_range(0.001, 1.0) = 0.045;
uniform float gust_strength : hint_range(0.0, 2.0) = 0.34;
uniform float wind_flatten_strength : hint_range(0.0, 1.0) = 0.08;

uniform int touch_count = 0;
uniform float touch_push_strength : hint_range(0.0, 3.0) = 0.52;
uniform float touch_crush_strength : hint_range(0.0, 2.0) = 0.46;
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

varying float blade_height_weight;
varying float blade_color_bias;
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
	return pow(fade, 1.62);
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
	vec2 fall_world = movement_direction * 0.92 + side_direction * side_offset * 0.16 + wind * 0.08;
	fall_world = normalize(fall_world + vec2(0.001, 0.0));
	vec2 fall_local = (inverse_model * vec4(fall_world.x, 0.0, fall_world.y, 0.0)).xz;
	fall_local = normalize(fall_local + vec2(0.001, 0.0));
	float speed_factor = clamp(touch_dir.z, 0.42, 1.02);
	float bend_weight = pow(clamp(height_weight, 0.0, 1.0), 1.42);
	float crush_weight = pow(clamp(height_weight, 0.0, 1.0), 1.08);
	float push_pressure = pressure * (1.0 - smoothstep(0.72, 1.0, footprint_distance));
	float push_amount = min(push_pressure * touch_push_strength * (0.08 + speed_factor * 0.11) * bend_weight, 0.16);
	float crush_pressure = pow(pressure, 1.34);
	vertex_position.xz += fall_local * push_amount;
	vertex_position.y -= crush_pressure * touch_crush_strength * (0.42 + speed_factor * 0.18) * crush_weight;
	return vertex_position;
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float uv_height = clamp(UV.y, 0.0, 1.0);
	float height_weight = pow(uv_height, 1.34);
	float stiffness = max(INSTANCE_CUSTOM.r, 0.32);
	float phase = INSTANCE_CUSTOM.g * 6.2831853;
	blade_color_bias = INSTANCE_CUSTOM.b;

	vec2 wind = normalize(wind_direction + vec2(0.001, 0.0));
	vec2 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xz;
	local_wind = normalize(local_wind + vec2(0.001, 0.0));
	vec2 wind_sample_position = world_position.xz + wind * veg_time * wind_speed * 22.0;
	vec2 wind_sample = wind_sample_position * wind_noise_scale + vec2(phase, phase * 0.37);
	float wind_noise = value_noise(wind_sample);
	float wind_detail = value_noise(wind_sample * 2.7 + vec2(17.0, -11.0));
	float gust = sin(veg_time * wind_speed * 0.9 + phase + wind_noise * 6.2831853) * 0.5 + 0.5;
	float wind_force = ((wind_noise - 0.5) * 1.05 + (wind_detail - 0.5) * 0.42 + gust * gust_strength) * wind_strength;
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

	blade_height_weight = uv_height;
	wind_light = clamp(0.30 + wind_noise * 0.48 + gust * 0.22 + wind_force * 0.22, 0.0, 1.0);
}

void fragment() {
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float tint = clamp(0.10 + blade_height_weight * 0.66 + blade_color_bias * 0.08, 0.0, 1.0);
	vec3 soft_base = mix(shadow_color.rgb, base_color.rgb, 0.76 + blade_height_weight * 0.18);
	vec3 grass_color = mix(soft_base, tip_color.rgb, tint);
	grass_color *= mix(0.74, 1.08, wind_light);
	float blade_center = 1.0 - abs(UV.x - 0.5) * 2.0;
	float edge_softness = smoothstep(0.0, 0.90, blade_center);
	float tip_softness = mix(0.92, 1.0, smoothstep(0.0, 0.72, UV.y));
	ALBEDO = grass_color;
	ALPHA = mix(0.54, 0.93, edge_softness) * tip_softness;
	ROUGHNESS = 0.92;
}
