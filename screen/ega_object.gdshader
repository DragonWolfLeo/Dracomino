shader_type canvas_item;

void fragment() {
	vec3 c = COLOR.xyz;
	float res = 3.0;
	c *= res;
	c = round(c);
	c /= res;
	COLOR.xyz = c;
}
