shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float crack_strength : hint_range(0.0, 0.35) = 0.12;
uniform float edge_glint : hint_range(0.0, 0.3) = 0.055;
uniform vec4 wet_clay_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float clay_noise(vec3 p) {
	return sin(dot(p, vec3(17.13, 31.71, 11.47))) * sin(dot(p, vec3(7.91, 19.37, 23.11)));
}

void fragment() {
	vec3 base = COLOR.rgb * wet_clay_tint.rgb;
	float grain = clay_noise(VERTEX * 4.0) * 0.5 + 0.5;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = base * (0.94 + grain * crack_strength);
	ROUGHNESS = 0.86;
	METALLIC = 0.0;
	SPECULAR = 0.38;
	EMISSION = base * fresnel * edge_glint;
}
