shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
	float cutoff = 0.3;
	float cutoff_depth = cutoff - SCREEN_UV.y;
	if(cutoff_depth < 0.0){
		float strength = 0.05;
		float cycle = 16.0;
		float wave = strength*sin(TIME+SCREEN_UV.y*cycle)*cutoff_depth;
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(wave, 0.0));
	} else {
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	}
}