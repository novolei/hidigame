shader_type canvas_item;

uniform float tilt_x : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float tilt_y : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float flash_phase = 0.0;
uniform float hover_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flash_intensity : hint_range(0.0, 2.0, 0.01) = 0.85;
uniform float stripe_width : hint_range(8.0, 80.0, 1.0) = 34.0;
uniform float stripe_spacing : hint_range(1.0, 40.0, 0.5) = 15.0;
uniform float flash_angle : hint_range(0.0, 360.0, 1.0) = 35.0;
uniform float perspective_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float outline_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);

void vertex() {
	vec2 centered = UV - vec2(0.5);
	float tilt_power = clamp(length(vec2(tilt_x, tilt_y)), 0.0, 1.0);
	float depth = centered.x * tilt_y * 0.32 - centered.y * tilt_x * 0.26;
	VERTEX.xy += vec2(centered.y * tilt_y * 34.0, centered.x * tilt_x * 27.0) * perspective_strength;
	VERTEX.xy += centered * depth * 30.0 * perspective_strength;
	VERTEX.xy *= 1.0 + (1.0 - length(centered)) * (0.018 + tilt_power * 0.018);
}

void fragment() {
	vec4 base = COLOR;
	vec2 centered = UV - vec2(0.5);
	vec2 tilt = vec2(tilt_y, -tilt_x);
	float tilt_power = clamp(length(tilt), 0.0, 1.0);
	float facing = clamp(1.0 + dot(centered, tilt) * 0.42, 0.76, 1.24);
	base.rgb *= mix(1.0, facing, 0.52 + hover_amount * 0.28);

	float left_edge = 1.0 - smoothstep(0.0, 0.105, UV.x);
	float right_edge = 1.0 - smoothstep(0.0, 0.105, 1.0 - UV.x);
	float top_edge = 1.0 - smoothstep(0.0, 0.105, UV.y);
	float bottom_edge = 1.0 - smoothstep(0.0, 0.105, 1.0 - UV.y);
	float rim = max(max(left_edge, right_edge), max(top_edge, bottom_edge));
	float inner_fade = smoothstep(0.0, 0.06, UV.x) * smoothstep(0.0, 0.06, UV.y) * smoothstep(0.0, 0.06, 1.0 - UV.x) * smoothstep(0.0, 0.06, 1.0 - UV.y);

	float angle = radians(flash_angle + tilt_y * 24.0 - tilt_x * 16.0);
	vec2 dir = normalize(vec2(cos(angle), sin(angle)));
	float tilted_phase = flash_phase + dot(tilt, vec2(0.18, 0.12)) * hover_amount;
	float stripe = sin((dot(UV, dir) * stripe_spacing + tilted_phase * 6.2831853) * 1.12) * 0.5 + 0.5;
	float sheen = pow(stripe, stripe_width) * flash_intensity * inner_fade;
	float wide_sheen = pow(stripe, max(stripe_width * 0.42, 3.0)) * 0.18 * flash_intensity * inner_fade;
	float outline_sheen = pow(stripe, max(stripe_width * 0.58, 4.0)) * rim * outline_intensity * (0.72 + hover_amount * 0.58);

	vec3 cool_rim = mix(vec3(0.58, 0.86, 1.0), flash_color.rgb, 0.44);
	base.rgb += cool_rim * rim * (0.08 + tilt_power * 0.12) * base.a;
	base.rgb += flash_color.rgb * (sheen * (0.72 + hover_amount * 0.28) + outline_sheen * 1.25 + wide_sheen) * base.a;
	COLOR = base;
}
