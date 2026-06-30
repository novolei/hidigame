shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 trunk_color : source_color = vec4(0.46, 0.31, 0.18, 1.0);
uniform vec4 leaf_color : source_color = vec4(0.30, 0.72, 0.25, 1.0);
uniform vec4 leaf_tip_color : source_color = vec4(0.62, 0.92, 0.28, 1.0);
uniform float tree_height : hint_range(1.0, 30.0) = 8.0;
uniform float veg_time = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.38);
uniform float wind_strength : hint_range(0.0, 4.0) = 0.42;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.82;
uniform float wind_noise_scale : hint_range(0.001, 1.0) = 0.035;
uniform float gust_strength : hint_range(0.0, 2.0) = 0.55;

varying float height_mix;
varying float leaf_flutter;

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
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float seed = hash21(world_origin.xz + vec2(13.17, 91.42));
	float height_weight = clamp(VERTEX.y / max(tree_height, 0.01), 0.0, 1.0);
	float crown_weight = smoothstep(0.18, 0.86, height_weight);
	float trunk_weight = pow(height_weight, 1.65);
	vec2 wind = normalize(wind_direction + vec2(0.001, 0.0));
	vec2 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xz;
	local_wind = normalize(local_wind + vec2(0.001, 0.0));

	float broad_noise = value_noise(world_origin.xz * wind_noise_scale + wind * veg_time * wind_speed * 0.35 + seed);
	float crown_noise = value_noise(world_position.xz * wind_noise_scale * 2.2 + wind * veg_time * wind_speed + seed * 3.7);
	float gust = sin(veg_time * wind_speed * 0.85 + seed * 6.2831853) * 0.5 + 0.5;
	float sway = (broad_noise * 0.75 + crown_noise * 0.35 + gust * gust_strength) * wind_strength;
	VERTEX.xz += local_wind * sway * trunk_weight;
	VERTEX.xz += local_wind * (crown_noise - 0.5) * wind_strength * crown_weight * 0.42;
	VERTEX.y -= abs(sway) * trunk_weight * 0.025;

	height_mix = height_weight;
	leaf_flutter = clamp(crown_noise + gust * 0.35, 0.0, 1.0);
}

void fragment() {
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	float leaf_amount = smoothstep(0.20, 0.46, height_mix);
	vec3 crown_color = mix(leaf_color.rgb, leaf_tip_color.rgb, clamp(height_mix * 0.8 + leaf_flutter * 0.25, 0.0, 1.0));
	ALBEDO = mix(trunk_color.rgb, crown_color, leaf_amount);
	ROUGHNESS = 0.82;
}
