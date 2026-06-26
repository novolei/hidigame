shader_type spatial;
render_mode cull_disabled;

uniform float t = 0.0;
uniform vec4 albedo_and_emissive_color : source_color = vec4(1.0);
uniform sampler2D noise_tex;
uniform float noise_scale = 1.0;
uniform float edge_width = 0.045;
uniform vec4 edge_color : source_color = vec4(0.64, 1.0, 0.24, 1.0);

void fragment() {
	float noise = texture(noise_tex, UV * noise_scale).r;
	float mask = step(t, noise);
	if (mask < 1.0) {
		discard;
	}
	float edge = smoothstep(t, t + edge_width, noise);
	vec3 dissolve_color = mix(edge_color.rgb, albedo_and_emissive_color.rgb, edge);
	ALBEDO = dissolve_color;
	EMISSION = dissolve_color;
}
