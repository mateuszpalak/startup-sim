// Background of the menu screens (login, the character): deep blue-green
// above, a warm dusk glow below, soft out-of-focus lights drifting slowly
// and a vignette - the shady storybook look of the game, behind the panels.
shader_type canvas_item;

uniform vec3 top = vec3(0.09, 0.16, 0.19);
uniform vec3 bottom = vec3(0.42, 0.26, 0.22);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top, bottom, smoothstep(0.25, 1.1, uv.y));
	float aspect = 1.0 / max(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 0.001);
	for (int i = 0; i < 14; i++) {
		float f = float(i);
		vec2 p = vec2(hash(f * 3.1), hash(f * 7.7));
		p += vec2(sin(TIME * 0.05 + f), cos(TIME * 0.04 + f * 1.3)) * 0.04;
		float r = 0.03 + hash(f * 1.9) * 0.07;
		vec2 d = (uv - p) * vec2(aspect, 1.0);
		float k = smoothstep(r, r * 0.55, length(d));
		vec3 tint = mix(vec3(1.0, 0.82, 0.55), vec3(0.6, 0.9, 0.85), hash(f * 5.3));
		c += tint * k * (0.05 + 0.06 * hash(f * 2.7));
	}
	float v = distance(uv, vec2(0.5, 0.45));
	c *= 1.0 - smoothstep(0.35, 0.95, v) * 0.55;
	COLOR = vec4(c, 1.0);
}
