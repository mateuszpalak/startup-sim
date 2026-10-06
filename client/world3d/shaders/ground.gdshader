// Floors and the street: vertex colour + a procedural pattern picked by
// UV2.x (see materials.gd GROUND_*), all in world space (no textures).
shader_type spatial;

#include "res://world3d/shaders/atmos.gdshaderinc"

varying vec3 v_world;
varying float v_kind;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.15;
}

// 1 on grout lines of a grid of `cell` metres (line width w).
float grid(vec2 p, vec2 cell, float w) {
	vec2 g = abs(fract(p / cell + 0.5) - 0.5) * cell;
	return 1.0 - smoothstep(0.0, w, min(g.x, g.y));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_kind = UV2.x;
}

void fragment() {
	vec2 p = v_world.xz;
	vec3 col = pow(COLOR.rgb, vec3(2.2));  // vertex colours are sRGB
	float rough = 0.85;
	int k = int(v_kind + 0.5);
	if (k == 1) { // wooden planks along x
		float row = floor(p.y / 0.22);
		float off = hash(vec2(row, 3.0)) * 3.0;
		float plank = floor((p.x + off) / 1.6);
		float tone = hash(vec2(plank, row)) * 0.14 - 0.07;
		float grain = noise(vec2((p.x + off) * 1.5, p.y * 40.0)) * 0.08;
		col *= 1.0 + tone + grain - 0.04;
		float seam = max(1.0 - smoothstep(0.0, 0.008, abs(fract(p.y / 0.22) - 0.0) * 0.22),
			1.0 - smoothstep(0.0, 0.01, abs(fract((p.x + off) / 1.6)) * 1.6));
		col *= 1.0 - seam * 0.28;
		rough = 0.5;
	} else if (k == 2) { // ceramic tiles 0.5 m
		float t = hash(floor(p / 0.5)) * 0.05;
		col *= 1.0 - t;
		col = mix(col, col * 0.72, grid(p, vec2(0.5), 0.012));
		rough = 0.25;
	} else if (k == 3) { // office carpet tiles
		float t = hash(floor(p / 0.5)) * 0.06 - 0.03;
		float fib = noise(p * 60.0) * 0.09;
		col *= 1.0 + t + fib - 0.05;
		col = mix(col, col * 0.88, grid(p, vec2(0.5), 0.006));
		rough = 1.0;
	} else if (k == 4) { // grass
		float n = fbm(p * 0.7);
		float b = noise(p * 9.0);
		col = mix(col * 0.8, col * 1.18 + vec3(0.03, 0.04, 0.0), n);
		col *= 0.92 + b * 0.16;
		rough = 1.0;
	} else if (k == 5) { // asphalt
		float n = fbm(p * 1.3) * 0.12 + hash(floor(p * 40.0)) * 0.08;
		col *= 0.92 + n;
		rough = 0.9;
	} else if (k == 6) { // paving stones (running bond)
		vec2 q = p / vec2(0.5, 0.25);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		float t = hash(floor(q)) * 0.1;
		col *= 0.97 - t + fbm(p * 3.0) * 0.06;
		vec2 g = abs(fract(q) - 0.5);
		float line = 1.0 - smoothstep(0.44, 0.48, max(g.x, g.y * 1.0));
		col = mix(col * 0.75, col, line);
		rough = 0.9;
	} else if (k == 7) { // stone slabs 1 m
		float t = hash(floor(p)) * 0.08;
		col *= 0.98 - t + fbm(p * 2.0) * 0.07;
		col = mix(col, col * 0.8, grid(p, vec2(1.0), 0.01));
		rough = 0.35;
	} else if (k == 8) { // chequer plate (elevator)
		vec2 q = fract(p * 6.0);
		float d = abs(q.x - q.y);
		col *= 0.9 + 0.12 * (1.0 - smoothstep(0.05, 0.1, d));
		rough = 0.35;
		METALLIC = 0.6;
	} else {
		col *= 0.95 + fbm(p * 2.0) * 0.1;
	}
	// The weather and the room's light (atmos.gdshaderinc).
	vec4 a = atmos_at(v_world + vec3(0.0, 0.05, 0.0));
	float wet = atmos_wet * a.r;
	if (wet > 0.0) {
		// Wet: darker and glossy, puddles in the dips.
		float dip = smoothstep(0.58, 0.72, fbm(p * 0.45 + 7.0)) * ((k == 3 || k == 4) ? 0.0 : 1.0);
		col *= mix(1.0, 0.58, wet) * (1.0 - dip * wet * 0.25);
		rough = mix(rough, k == 4 ? 0.6 : 0.16, wet);
		rough = mix(rough, 0.02, dip * wet);
		SPECULAR = mix(0.5, 0.75, wet);
	}
	if (a.r > 0.5) {
		col *= atmos_cloud_shade(p, TIME);
	}
	ALBEDO = col * atmos_light(a);
	ROUGHNESS = rough;
}
