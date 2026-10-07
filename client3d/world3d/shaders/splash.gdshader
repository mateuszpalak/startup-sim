// Splashes of the rain: little rings spreading on the outdoor ground, each
// at a new random spot every cycle (weather_3d.gd, a MultiMesh of quads).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords, fog_disabled;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform vec3 center = vec3(0.0);
uniform float area = 34.0;
uniform float rate = 2.2;
uniform vec4 tint : source_color = vec4(0.8, 0.86, 0.95, 0.35);

varying float v_a;
varying float v_t;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float cyc = TIME * rate + h1(id + 9.1);
	float n = floor(cyc);
	v_t = fract(cyc);
	vec2 home = vec2(h1(id + n * 3.7), h1(id * 1.3 + n * 5.9 + 17.0)) * area;
	vec2 xz = center.xz + (fract((home - center.xz) / area + 0.5) - 0.5) * area;
	vec4 a = atmos_at(vec3(xz.x, atmos_floor_y, xz.y));
	float ground = a.b > 0.5 ? atmos_floor_y : 0.0;
	float r = 0.06 + v_t * 0.16;
	VERTEX = vec3(xz.x + VERTEX.x * r * 2.0, ground + 0.03, xz.y + VERTEX.y * r * 2.0);
	v_a = a.r * (1.0 - v_t);
}

void fragment() {
	if (v_a < 0.01) {
		discard;
	}
	float d = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.65, 0.85, d) * (1.0 - smoothstep(0.85, 1.0, d));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * v_a * ring;
}
