// The world's painted, shady look, over the game world and under the HUD:
// rich colours graded cool in the shadows and warm in the light, a soft glow
// around bright things, a miniature-like blur towards the top and bottom of
// the frame, and a deep vignette. No ink lines: the art carries its own edges.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation = 1.1;
uniform float contrast = 1.06;
uniform vec3 shadow_tint = vec3(0.86, 0.95, 1.08);
uniform vec3 light_tint = vec3(1.06, 1.02, 0.92);
uniform float bloom = 0.22;
uniform float bloom_threshold = 0.78;
uniform float tilt_blur = 2.5;  // blur radius at the very edge, in screen pixels (x the window's scale)
uniform float vignette = 0.55;
uniform float grain = 0.018;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 bright(vec2 uv, float lod) {
	vec3 s = textureLod(screen_tex, uv, lod).rgb;
	float y = dot(s, vec3(0.299, 0.587, 0.114));
	return s * smoothstep(bloom_threshold, 1.0, y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Miniature blur: sharp across the middle band, softer towards the edges.
	float band = smoothstep(0.3, 0.5, abs(uv.y - 0.5));
	vec3 c = texture(screen_tex, uv).rgb;
	if (band > 0.01) {
		// A small disc of taps (not a mip level: that would look blocky).
		vec2 rad = SCREEN_PIXEL_SIZE * tilt_blur * band * 3.0;
		vec3 acc = c;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785 + 0.4;
			float d = (i % 2 == 0) ? 1.0 : 0.55;
			acc += texture(screen_tex, uv + vec2(cos(a), sin(a)) * rad * d).rgb;
		}
		c = acc / 9.0;
	}
	// Glow: wide and soft, from the brightest parts only.
	vec3 g = bright(uv, 3.0) * 0.5 + bright(uv, 4.5) * 0.35 + bright(uv, 6.0) * 0.25;
	c += g * bloom;
	// Grade: more colour, cool shadows, warm light, a gentle S-curve.
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(y), c, saturation);
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, y));
	c = (c - 0.5) * contrast + 0.5;
	c = mix(c, c * c * (3.0 - 2.0 * c), 0.25);
	// A fine painted grain (in 2x2 blocks, so it reads as canvas, not noise).
	c += (hash(floor(FRAGCOORD.xy / 2.0)) - 0.5) * grain;
	// Vignette: deep, slightly blue, like the shade under trees.
	float v = distance(uv * vec2(1.0, 0.85), vec2(0.5, 0.425));
	float k = smoothstep(0.3, 0.85, v) * vignette;
	c = mix(c, c * vec3(0.32, 0.36, 0.46), k);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
