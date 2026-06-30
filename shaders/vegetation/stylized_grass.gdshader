shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.40, 0.74, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.82, 1.0, 0.35, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.20, 0.42, 0.12, 1.0);

uniform float veg_time = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.38);
uniform float wind_strength : hint_range(0.0, 3.0) = 0.58;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.82;
uniform float wind_noise_scale : hint_range(0.001, 1.0) = 0.055;
uniform float gust_strength : hint_range(0.0, 2.0) = 0.55;
uniform float wind_flatten_strength : hint_range(0.0, 1.0) = 0.16;

uniform int touch_count = 0;
uniform float touch_push_strength : hint_range(0.0, 3.0) = 1.18;
uniform float touch_crush_strength : hint_range(0.0, 2.0) = 0.34;
uniform float touch_recovery : hint_range(0.1, 8.0) = 1.28;
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

vec3 touch_deform(vec3 vertex_position, vec3 world_position, float height_weight, vec4 touch_data, vec4 touch_dir, int slot_index, mat4 inverse_model) {
	if (touch_count <= slot_index || touch_data.w <= 0.0) {
		return vertex_position;
	}
	float age = max(veg_time - touch_data.z, 0.0);
	float recovery = exp(-age * touch_recovery);
	vec2 diff = world_position.xz - touch_data.xy;
	float dist = length(diff);
	float falloff = smoothstep(touch_data.w, 0.0, dist) * recovery;
	if (falloff <= 0.001) {
		return vertex_position;
	}
	vec2 push_world = diff + touch_dir.xy * 0.35;
	if (length(push_world) < 0.01) {
		push_world = -normalize(wind_direction + vec2(0.001, 0.0));
	} else {
		push_world = normalize(push_world);
	}
	vec2 push_local = (inverse_model * vec4(push_world.x, 0.0, push_world.y, 0.0)).xz;
	float speed_factor = clamp(touch_dir.z, 0.35, 1.65);
	vertex_position.xz += push_local * falloff * touch_push_strength * speed_factor * height_weight;
	vertex_position.y -= falloff * touch_crush_strength * speed_factor * height_weight;
	return vertex_position;
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_weight = smoothstep(0.04, 1.0, UV.y);
	float stiffness = max(INSTANCE_CUSTOM.r, 0.35);
	float phase = INSTANCE_CUSTOM.g * 6.2831853;
	blade_color_bias = INSTANCE_CUSTOM.b;

	vec2 wind = normalize(wind_direction + vec2(0.001, 0.0));
	vec2 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xz;
	local_wind = normalize(local_wind + vec2(0.001, 0.0));
	float slow_noise = value_noise(world_position.xz * wind_noise_scale + wind * veg_time * wind_speed + phase);
	float fast_noise = value_noise(world_position.xz * wind_noise_scale * 2.7 + wind * veg_time * wind_speed * 1.8 + phase * 0.37);
	float gust = sin(veg_time * wind_speed * 0.9 + phase + slow_noise * 6.2831853) * 0.5 + 0.5;
	float sway = ((slow_noise - 0.5) * 1.25 + (fast_noise - 0.5) * 0.55 + gust * gust_strength) * wind_strength;
	float bend = sway * height_weight * stiffness;

	VERTEX.xz += local_wind * bend;
	VERTEX.y -= abs(bend) * wind_flatten_strength * height_weight;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat4 inverse_model = inverse(MODEL_MATRIX);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch0, touch_dir0, 0, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch1, touch_dir1, 1, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch2, touch_dir2, 2, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch3, touch_dir3, 3, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch4, touch_dir4, 4, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch5, touch_dir5, 5, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch6, touch_dir6, 6, inverse_model);
	VERTEX = touch_deform(VERTEX, world_position, height_weight, touch7, touch_dir7, 7, inverse_model);

	blade_height_weight = height_weight;
	wind_light = clamp(0.5 + sway * 0.7, 0.0, 1.0);
}

void fragment() {
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float tint = clamp(blade_height_weight + blade_color_bias * 0.18, 0.0, 1.0);
	vec3 grass_color = mix(base_color.rgb, tip_color.rgb, tint);
	grass_color = mix(shadow_color.rgb, grass_color, clamp(0.45 + wind_light * 0.55, 0.0, 1.0));
	ALBEDO = grass_color;
	ROUGHNESS = 0.86;
}
