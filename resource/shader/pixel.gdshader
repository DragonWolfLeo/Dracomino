shader_type canvas_item;

uniform float pixelScale = 8.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment()
{
	vec2 res = SCREEN_PIXEL_SIZE*pixelScale;
	vec2 nearestPixelUV = res * round(SCREEN_UV / res);
	nearestPixelUV = (floor(nearestPixelUV/SCREEN_PIXEL_SIZE)+0.5)*SCREEN_PIXEL_SIZE; // Snap to pixel
   COLOR = textureLod(SCREEN_TEXTURE, nearestPixelUV, 0.0);

}