shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
	COLOR = vec4(vec3(1.0) - texture(SCREEN_TEXTURE, SCREEN_UV).xyz, 1.0);
}