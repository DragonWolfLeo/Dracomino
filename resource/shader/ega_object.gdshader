shader_type canvas_item;

void fragment() {
	vec3 c = COLOR.xyz;
	float res = 3.0;
	c *= res;
	c = round(c*COLOR.a);
	c /= res;
	COLOR.xyz = c;
	COLOR.a = COLOR.a > 0.5 ? 1.0 : 0.0;
}
