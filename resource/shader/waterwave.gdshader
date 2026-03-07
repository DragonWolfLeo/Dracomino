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
	float wave = sin(TIME+(SCREEN_UV.x*wave_frequency))*wave_strength*sin(TIME);
	float dist = water_height - SCREEN_UV.y;
	float water_surface_effect = pow(1.0-clamp(-(dist-wave)/watersurface_height, 0.0, 1.0), 4.0);
	if(dist < wave){
		float distort = distortion_strength*sin(TIME+SCREEN_UV.y*cycle)*dist;
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(distort, 0.0)) + water_color + (watersurface_color*water_surface_effect);
		vec2 reflectUV = vec2(SCREEN_UV.x, water_height+dist);
		COLOR += texture(SCREEN_TEXTURE, reflectUV - vec2(distort, 0.0) + reflection_shear*dist)*reflection_strength*clamp(1.0+dist/reflection_strength, 0.0, 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}