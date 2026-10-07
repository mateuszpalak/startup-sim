// Furniture surfaces: vertex colour (sRGB) + a subtle procedural texture in
// world space (no texture files), picked by `kind`:
//   0 painted / plastic  1 wood grain  2 fabric weave  3 brushed metal
//   4 leaves  5 glazed ceramic  6 rough plaster / concrete  7 rubber
// A small bump from the same pattern perturbs the normal. Darkened in
// unlit windowless rooms (atmos mask), like shaders/prop.gdshader.
shader_type spatial;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform int kind = 0;
uniform float rough = 0.8;
uniform float metal = 0.0;
uniform float bump = 0.6;

varying vec3 v_world;
varying vec3 v_wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Planar coordinates of the face (dominant axis of the world normal):
// x = along the long horizontal direction, y = the other one.
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return vec2(p.z, p.y);
	return vec2(p.x, p.y);
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	vec2 uv = face_uv(v_world, v_wn);
	float h = 0.0;      // height for the bump
	float r = rough;
	float m = metal;
	float shade = 1.0;
	if (kind == 1) {
		// wood: long grain (along x on tops, upright on sides), growth rings
		if (abs(v_wn.y) < 0.5) uv = vec2(v_world.y, abs(v_wn.x) > abs(v_wn.z) ? v_world.z : v_world.x);
		float ring = noise(vec2(uv.x * 0.9, uv.y * 14.0 + noise(uv * 2.0) * 3.0));
		float fine = noise(vec2(uv.x * 3.0, uv.y * 45.0));
		shade = 0.9 + ring * 0.16 + fine * 0.06;
		h = ring * 0.5 + fine * 0.5;
		r = rough + (fine - 0.5) * 0.15;
	} else if (kind == 2) {
		// fabric: a fine weave + soft mottling, velvet-ish rim
		vec2 q = uv * 60.0;
		float weave = sin(q.x) * sin(q.y) * 0.5 + 0.5;
		float mot = noise(uv * 7.0);
		shade = 0.94 + weave * 0.03 + mot * 0.07;
		h = weave;
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		col = mix(col, col * 1.35 + 0.02, rim * rim * 0.35);
	} else if (kind == 3) {
		// brushed metal: streaks along uv.x
		float s = noise(vec2(uv.x * 2.0, uv.y * 160.0));
		shade = 0.95 + s * 0.1;
		h = s * 0.3;
		r = rough + (s - 0.5) * 0.12;
	} else if (kind == 4) {
		// leaves: blotchy tone, lighter edges towards the light
		float n = noise(v_world.xz * 9.0 + v_world.y * 5.0);
		shade = 0.85 + n * 0.3;
		h = n;
		BACKLIGHT = col * 0.35;
	} else if (kind == 5) {
		// glazed ceramic: almost flat, a hint of waviness
		float n = noise(uv * 4.0);
		shade = 0.98 + n * 0.04;
		h = n * 0.2;
		CLEARCOAT = 0.6;
		CLEARCOAT_ROUGHNESS = 0.1;
	} else if (kind == 6) {
		// plaster / concrete
		float n = noise(uv * 6.0) * 0.6 + noise(uv * 31.0) * 0.4;
		shade = 0.93 + n * 0.12;
		h = n;
	} else if (kind == 7) {
		float n = noise(uv * 40.0);
		shade = 0.95 + n * 0.08;
		h = n * 0.5;
	} else {
		// paint / plastic: barely-there orange peel
		float n = noise(uv * 23.0);
		shade = 0.97 + n * 0.05;
		h = n * 0.25;
	}
	col *= shade;
	// bump from the height's screen derivatives (Mikkelsen's surface gradient)
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float hx = dFdx(h);
	float hy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * bump * 0.003);
	float lit = atmos_light(atmos_at(v_world));
	ALBEDO = col * lit;
	SPECULAR = 0.5 * lit;
	ROUGHNESS = clamp(r, 0.04, 1.0);
	METALLIC = m;
}
