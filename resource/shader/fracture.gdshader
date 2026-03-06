shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float scale : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float speed : hint_range(-1.0, 1.0, 0.01) = 1.0;
uniform float wobblespeed : hint_range(0.0, 50.0, 0.1) = 1.0;
uniform float wobblestrength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float shakespeed : hint_range(0.0, 50.0, 0.1) = 1.0;
uniform float shakestrength : hint_range(0.0, 5.0, 0.1) = 1.0;
uniform vec2 disp = vec2(0.0, 0.0);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3, p3.zyx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rcel(vec2 ip) {
	return mix(.25,.45, hash12(ip+.2));
}

vec2 cell(vec2 ip){
	float ag = 6.28*hash12(ip + 1.23) + 5.;
	return vec2(cos(ag), sin(ag)) * rcel(ip);
}

void fragment() {
	float time = -TIME*speed;
	float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
	vec2 U = (SCREEN_UV-disp) * 1000.0 * scale / vec2(ratio, 1.0);
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = 3.0 * (U + U - res) / res.y + vec2(0.0, time);
	vec2 ip = round(p);

	// Determine cell
	vec2 core, center;
	float md=1e8,d;
	for(float j=-1.;j<2.;j++) for(float i=-1.;i<2.;i++) {
		vec2 e = ip + vec2(i,j);
		vec2 c = cell(e)+e;
		d = length(c-p);
		if(d<md) {
			md = d;
			center = e;
			core = c;
		}
	}
	// Make wobble
	vec2 wobble = vec2(cos((TIME+center.x)*wobblespeed*0.5), sin((TIME+center.y)*wobblespeed))*wobblestrength;
	wobble.x *= sin(TIME*shakespeed)*shakestrength + sin(TIME*shakespeed*5.0)*shakestrength;
	md=1e8;
	// Create cracks
	for(float j=-2.;j<=2.;j++) for(float i=-2.;i<=2.;i++){
		if(abs(i)+abs(j)>.1) {
			vec2 neighbor = center + vec2(i,j);
			vec2 neighborcore = cell(neighbor)+neighbor;
			d = dot(normalize(p - (core+wobble+neighborcore)/2.), (core-neighborcore));
			md=min(md, d);
		}
	}
	d = exp(-200.0*md);
	vec2 offset = wobble*0.05;
	if(d<0.1){
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV - offset);
	} else {
		COLOR = vec4(0.0,0.0,0.0,1);
	}
}