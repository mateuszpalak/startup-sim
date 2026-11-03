// The floor picture, painted: soft blotches of lighter and darker, warmer and
// cooler colour across the whole map (seamless over tiles), and a fine
// brush grain. Anchored to the world, so it doesn't swim with the camera.
shader_type canvas_item;

uniform vec2 world_size = vec2(1024.0, 1024.0);  // the map in world pixels
uniform float blotch = 0.14;
uniform float hue_shift = 0.05;
uniform float brush = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 w = UV * world_size;
	float big = fbm(w / 40.0);
	float warm = fbm(w / 70.0 + vec2(31.0, 7.0));
	// Brush strokes: noise stretched a little sideways.
	float stroke = noise(vec2(w.x / 1.6, w.y / 4.5)) * 0.6 + noise(w / 1.2) * 0.4;
	vec3 c = t.rgb;
	c *= 1.0 + (big - 0.5) * blotch * 2.0;
	c += (vec3(0.6, 0.25, -0.35) * (warm - 0.5)) * hue_shift;
	c *= 1.0 + (stroke - 0.5) * brush;
	COLOR = vec4(c, t.a);
}
