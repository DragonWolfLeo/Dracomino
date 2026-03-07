shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform vec4 water_color : source_color;
uniform vec4 watersurface_color : source_color = vec4(1.0);
uniform float watersurface_height = 0.05;
uniform float wave_strength = 0.004;
uniform float wave_frequency = 50.0;
uniform float cycle = 16.0;
uniform float distortion_strength = 0.05;
uniform float water_height = 0.3;
uniform float reflection_shear = 0.2;
uniform float reflection_strength = 0.25;

void fragment() {
	float cutoff = water_height + (sin(TIME+(SCREEN_UV.x*wave_frequency))*wave_strength*sin(TIME));
	float cutoff_depth = cutoff - SCREEN_UV.y;
	float water_surface_effect = pow(1.0-clamp(-cutoff_depth/watersurface_height, 0.0, 1.0), 4.0);
	if(cutoff_depth < 0.0){
		float wave = distortion_strength*sin(TIME+SCREEN_UV.y*cycle)*cutoff_depth;
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(wave, 0.0)) + water_color + (watersurface_color*water_surface_effect);
		vec2 reflectUV = vec2(SCREEN_UV.x, cutoff+cutoff_depth);
		COLOR += texture(SCREEN_TEXTURE, reflectUV + vec2(wave, 0.0) + reflection_shear*cutoff_depth)*reflection_strength*clamp(1.0+cutoff_depth/reflection_strength, 0.0, 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}