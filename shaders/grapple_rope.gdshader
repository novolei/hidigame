// Stalker grapple rope — flowing energy cable.
// Camera-facing ribbon (built per-frame in stalker_grapple_visual.gd). The
// across-width gradient fakes a round cable (bright core, soft edges); a
// scrolling flow texture + a travelling highlight band sell "energy reeling in".
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform sampler2D flow_tex : source_color, hint_default_white;
uniform vec3 core_color : source_color = vec3(0.78, 0.93, 1.0);
uniform vec3 edge_color : source_color = vec3(0.12, 0.46, 1.0);
uniform float energy = 3.2;
uniform float tiling = 5.0;
uniform float scroll_speed = -2.6;   // flow direction along the cable
uniform float pulse_speed = -1.9;    // travelling reel highlight
uniform float alpha_mul = 1.0;       // global fade (extend in / retract out)

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);            // 1 at center, 0 at edges
	float core = pow(clamp(across, 0.0, 1.0), 2.2);
	float flow = texture(flow_tex, vec2(UV.x * tiling + TIME * scroll_speed, UV.y)).r;
	float band = pow(fract(UV.x - TIME * pulse_speed), 6.0);  // sharp travelling pulse
	vec3 col = mix(edge_color, core_color, core) + core_color * band * 0.85;
	float a = across * (0.45 + 0.55 * flow);
	a = clamp(a + band * 0.5, 0.0, 1.0) * alpha_mul;
	ALBEDO = col * energy;
	EMISSION = col * energy;
	ALPHA = clamp(a, 0.0, 1.0);
}
