shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
	vec3 c = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).xyz;
	float res = 3.0;
	c *= res;
	c = round(c);
	c /= res;
	COLOR.xyz = c;
}
