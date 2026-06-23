shader_type canvas_item;

uniform float tilt_x : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float tilt_y : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float flash_phase = 0.0;
uniform float flash_intensity : hint_range(0.0, 2.0, 0.01) = 0.85;
uniform float stripe_width : hint_range(8.0, 80.0, 1.0) = 34.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);

void vertex() {
	vec2 centered = UV - vec2(0.5);
	VERTEX.xy += vec2(centered.y * tilt_y * 24.0, centered.x * tilt_x * 18.0);
	VERTEX.xy *= 1.0 + (1.0 - length(centered)) * 0.018;
}

void fragment() {
	vec4 base = COLOR;
	float diagonal = dot(UV, normalize(vec2(0.9, 0.55)));
	float sweep = fract(flash_phase + diagonal);
	float sheen = pow(1.0 - abs(sweep - 0.5) * 2.0, stripe_width) * flash_intensity;
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x) * smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.92, UV.y);
	base.rgb += flash_color.rgb * sheen * edge * base.a;
	COLOR = base;
}
