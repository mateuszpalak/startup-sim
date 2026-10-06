// Rain streaks (weather_3d.gd: a MultiMesh of quads, all the motion here).
// Every drop has a fixed spot in the world (wrapped around the camera's
// focus), falls to the ground of its tile and is hidden over rooms under a
// roof (atmos mask).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords, fog_disabled;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform vec3 center = vec3(0.0);
uniform float area = 40.0;
uniform float height = 14.0;
uniform float speed = 13.0;
uniform float drop_len = 0.9;
uniform float wind = 0.15;
uniform vec4 tint : source_color = vec4(0.75, 0.82, 0.92, 0.35);

varying float v_a;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec2 home = vec2(h1(id), h1(id + 71.31)) * area;
	vec2 xz = center.xz + (fract((home - center.xz) / area + 0.5) - 0.5) * area;
	vec4 a = atmos_at(vec3(xz.x, atmos_floor_y, xz.y));
	float ground = a.b > 0.5 ? atmos_floor_y : 0.0;
	float ph = fract(h1(id + 3.17) - TIME * speed / height);
	vec3 dir = normalize(vec3(wind, -1.0, wind * 0.4));
	vec3 p = vec3(xz.x, ground, xz.y) - dir * (ph * height);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 side = normalize(cross(dir, cam - p));
	VERTEX = p + side * VERTEX.x * 0.05 - dir * (VERTEX.y + 0.5) * drop_len;
	v_a = a.r * smoothstep(0.0, 0.04, ph) * (1.0 - smoothstep(0.35, 0.5, length(xz - center.xz) / area));
}

void fragment() {
	if (v_a < 0.01) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a * v_a * (1.0 - abs(UV.x * 2.0 - 1.0)) * smoothstep(0.0, 0.4, 1.0 - UV.y);
}
