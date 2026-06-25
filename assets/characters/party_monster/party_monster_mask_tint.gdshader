shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sam_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_01 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_02 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_03 : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec4 color_01 : source_color = vec4(1.0, 0.66, 0.0, 1.0);
uniform vec4 color_02 : source_color = vec4(0.45, 0.30, 0.95, 1.0);
uniform vec4 color_03 : source_color = vec4(0.31, 0.47, 0.0, 1.0);
uniform vec4 color_04 : source_color = vec4(0.44, 0.53, 0.11, 1.0);
uniform vec4 color_05 : source_color = vec4(0.08, 0.33, 0.63, 1.0);
uniform vec4 color_06 : source_color = vec4(0.54, 0.57, 0.07, 1.0);
uniform vec4 color_07 : source_color = vec4(0.72, 0.35, 0.02, 1.0);
uniform vec4 color_08 : source_color = vec4(0.36, 0.59, 0.08, 1.0);

uniform float color_01_power = 2.15;
uniform float color_02_power = 2.15;
uniform float color_03_power = 2.15;
uniform float color_04_power = 2.15;
uniform float color_05_power = 2.15;
uniform float color_06_power = 2.15;
uniform float color_07_power = 2.15;
uniform float color_08_power = 2.15;

uniform float metallic_strength : hint_range(0.0, 1.0, 0.01) = 0.06;
uniform float occlusion_strength : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float min_roughness : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float max_roughness : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float specular_level : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform vec4 surface_tint : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float pastel_blend : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float saturation : hint_range(0.0, 1.25, 0.01) = 0.86;
uniform float highlight_rolloff : hint_range(0.0, 0.35, 0.01) = 0.08;
uniform float shadow_warmth : hint_range(0.0, 0.2, 0.01) = 0.035;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	vec4 m1 = texture(mask_01, UV);
	vec4 m2 = texture(mask_02, UV);
	vec4 m3 = texture(mask_03, UV);

	vec4 tint = vec4(0.0);
	tint += min(vec4(m1.r), color_01) * color_01_power;
	tint += min(vec4(m1.g), color_02) * color_02_power;
	tint += min(vec4(m1.b), color_03) * color_03_power;
	tint += min(vec4(m2.r), color_04) * color_04_power;
	tint += min(vec4(m2.g), color_05) * color_05_power;
	tint += min(vec4(m2.b), color_06) * color_06_power;
	tint += min(vec4(m3.r), color_07) * color_07_power;
	tint += min(vec4(m3.g), color_08) * color_08_power;

	float mask_amount = clamp(m1.r + m1.g + m1.b + m2.r + m2.g + m2.b + m3.r + m3.g, 0.0, 1.0);
	vec3 tinted = clamp((base * tint).rgb, vec3(0.0), vec3(1.0));
	vec3 masked_albedo = clamp(mix(base.rgb, tinted, mask_amount), vec3(0.0), vec3(1.0));
	vec4 sam = texture(sam_texture, UV);

	float unity_metallic = clamp(sam.b, 0.0, 1.0);
	float unity_smoothness = clamp(sam.r, 0.0, 1.0);
	float unity_occlusion = clamp(sam.g, 0.0, 1.0);
	vec3 warm_albedo = clamp(masked_albedo * surface_tint.rgb, vec3(0.0), vec3(1.0));
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
