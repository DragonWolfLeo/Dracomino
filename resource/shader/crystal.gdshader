shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float scale : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float speed : hint_range(-1.0, 1.0, 0.01) = 1.0;
uniform vec2 disp = vec2(0.0, 0.0);
uniform vec3 tint_strength = vec3(1.0);
uniform float edgeshine : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float refraction : hint_range(-1.0, 1.0, 0.01) = 0.03;

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
	vec4 tint = color;
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
	// Tint cell
	tint += vec4((sin(center.x)+0.5),(sin(center.y+sin(SCREEN_UV.x*8.0))+0.5),(sin(TIME/4.0)+1.5),0) * vec4(tint_strength, 0.0);
	// Make edge
	md=1e8;
	for(float j=-2.;j<=2.;j++) for(float i=-2.;i<=2.;i++){
		if(abs(i)+abs(j)>0.1) {
			vec2 neighbor = center + vec2(i,j);
			vec2 neighborcore = cell(neighbor)+neighbor;
			d = dot(normalize(p - (core+neighborcore)/2.), (core-neighborcore));
			md=min(md, d);
		}
	}
	d = clamp(exp2(-32.0*md), 0.0, 1.0);
	vec2 offset = -((core-center))*refraction;

	// Shiny effect
	float shineheight = -0.8;
	float narrowness = 10.0;
	float shinestrength = 0.2;
	float dist = abs((center.y-time)+(offset.x*16.0) - shineheight);
	float effect = 1.0-dist*narrowness;
	effect = max(effect, 0.0);
	float edgeeffect = 1.0-dist;
	edgeeffect = max(edgeeffect, 0.0);
	tint += (d*edgeshine*edgeeffect) + vec4(vec3(1.0)*effect*shinestrength, 1.0);

	// Apply offset and color
	vec2 uv = SCREEN_UV + offset;
	uv = (floor(uv/SCREEN_PIXEL_SIZE)+0.5)*SCREEN_PIXEL_SIZE; // Snap to pixel
	COLOR = textureLod(SCREEN_TEXTURE, uv, 0.0) + tint;

}