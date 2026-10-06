// The atmosphere shared by the world shaders (lighting_3d.gd sets these):
//   atmos_mask   one texel per tile of the shown floor:
//                r = under the open sky, g = how lit the room is (darkness
//                of windowless rooms with the lamp off), b = the tile is
//                ground of the shown floor (else the street below),
//                a = a lamp is on in the room (glowing windows at night)
//   atmos_wet    0..1 wet ground outdoors (rain, drying after it)
//   atmos_night  0..1 (lamps, windows)
//   atmos_clouds 0..1 cloud cover (cloud shadows drifting over the ground)
global uniform sampler2D atmos_mask : filter_nearest;
global uniform vec2 atmos_mask_size;
global uniform float atmos_floor_y;
global uniform float atmos_wet;
global uniform float atmos_night;
global uniform float atmos_clouds;

vec4 atmos_at(vec3 w) {
	if (w.y < atmos_floor_y - 0.6) {
		return vec4(1.0, 1.0, 0.0, 0.0);  // the street under an upper floor
	}
	vec2 uv = (floor(w.xz) + 0.5) / atmos_mask_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(1.0, 1.0, 0.0, 0.0);
	}
	return textureLod(atmos_mask, uv, 0.0);
}

// How much light reaches a surface in the room of mask texel `a` (dark
// rooms: next to nothing, the sun shines in through the missing ceiling).
float atmos_light(vec4 a) {
	return a.g * a.g;
}

float atmos_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float atmos_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(atmos_hash(i), atmos_hash(i + vec2(1.0, 0.0)), u.x),
		mix(atmos_hash(i + vec2(0.0, 1.0)), atmos_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Shadows of clouds drifting over the land, 1 = none.
float atmos_cloud_shade(vec2 p, float time) {
	vec2 q = p * 0.045 + vec2(time * 0.012, time * 0.005);
	float n = atmos_noise(q) * 0.65 + atmos_noise(q * 2.7) * 0.35;
	return 1.0 - atmos_clouds * 0.32 * smoothstep(0.42, 0.68, n);
}
