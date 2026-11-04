// Shade under the trees with sunlight coming through the leaves: holes in
// the shadow that drift slowly as the leaves move. In world coordinates, so
// the light stays put when the camera moves.
shader_type canvas_item;

uniform float holes = 0.75;   // how much of the shadow the sun spots take away
uniform float speed = 0.35;

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * speed;
	float n = noise(world / 6.0 + vec2(t, t * 0.6)) * 0.6 + noise(world / 2.5 - vec2(t * 0.8, t * 1.3)) * 0.4;
	float spot = smoothstep(0.58, 0.72, n);
	COLOR.a *= 1.0 - spot * holes;
}
