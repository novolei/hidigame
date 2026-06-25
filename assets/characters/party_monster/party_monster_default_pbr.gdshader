shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_smoothness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float metallic_strength : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float occlusion_strength : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float min_roughness : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float max_roughness : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float specular_level : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform vec4 surface_tint : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float pastel_blend : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float saturation : hint_range(0.0, 1.25, 0.01) = 0.88;
uniform float highlight_rolloff : hint_range(0.0, 0.35, 0.01) = 0.08;
uniform float shadow_warmth : hint_range(0.0, 0.2, 0.01) = 0.035;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	vec4 metallic_smoothness = texture(metallic_smoothness_texture, UV);
	vec4 ambient_occlusion = texture(ao_texture, UV);

	float unity_metallic = clamp(metallic_smoothness.r, 0.0, 1.0);
	float unity_smoothness = clamp(metallic_smoothness.a, 0.0, 1.0);
	float unity_occlusion = clamp(ambient_occlusion.g, 0.0, 1.0);
	vec3 source_albedo = clamp(base.rgb, vec3(0.0), vec3(1.0));
	vec3 warm_albedo = clamp(source_albedo * surface_tint.rgb, vec3(0.0), vec3(1.0));
	float luma = dot(warm_albedo, vec3(0.2126, 0.7152, 0.0722));
	vec3 saturated_albedo = mix(vec3(luma), warm_albedo, saturation);
	vec3 pastel_target = vec3(luma) * 0.82 + surface_tint.rgb * 0.18;
	vec3 shaped_albedo = mix(saturated_albedo, pastel_target, pastel_blend);
	float rolloff = smoothstep(0.74, 1.0, max(max(shaped_albedo.r, shaped_albedo.g), shaped_albedo.b)) * highlight_rolloff;
	vec3 warmed_shadow = shaped_albedo * (1.0 - shadow_warmth) + vec3(0.055, 0.040, 0.028) * shadow_warmth;
	vec3 final_albedo = clamp(mix(warmed_shadow, warmed_shadow * 0.90 + vec3(0.045, 0.036, 0.028), rolloff), vec3(0.0), vec3(0.96));

	ALBEDO = final_albedo;
	METALLIC = clamp(unity_metallic * metallic_strength, 0.0, 1.0);
	ROUGHNESS = clamp(1.0 - unity_smoothness, min_roughness, max_roughness);
	AO = mix(1.0, unity_occlusion, occlusion_strength);
	SPECULAR = specular_level;
}
