shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float waveStrength = 0.004;
	float waveFrequency = 50.0;
	float cutoff = 0.3 + (sin(TIME+(SCREEN_UV.x*waveFrequency))*waveStrength*sin(TIME));
	if(cutoff >= SCREEN_UV.y){
		COLOR.a = 0.0;
	}
}