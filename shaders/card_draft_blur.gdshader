shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 10.0, 0.25) = 4.5;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.05, 0.44);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 sum = vec4(0.0);
	sum += texture(screen_texture, SCREEN_UV + px * vec2(-1.5, -1.5)) * 0.06;
	sum += texture(screen_texture, SCREEN_UV + px * vec2( 0.0, -1.5)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV + px * vec2( 1.5, -1.5)) * 0.06;
	sum += texture(screen_texture, SCREEN_UV + px * vec2(-1.5,  0.0)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV) * 0.36;
	sum += texture(screen_texture, SCREEN_UV + px * vec2( 1.5,  0.0)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV + px * vec2(-1.5,  1.5)) * 0.06;
	sum += texture(screen_texture, SCREEN_UV + px * vec2( 0.0,  1.5)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV + px * vec2( 1.5,  1.5)) * 0.06;
	COLOR = mix(sum, tint, tint.a);
}
