shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float cutoff = 0.3;
	if(cutoff >= SCREEN_UV.y){
		COLOR.a = 0.0;
	}
}