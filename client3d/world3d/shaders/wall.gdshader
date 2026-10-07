// Walls: vertex colour, cut away around the line from the player to the
// camera (dithered), so the player is never hidden behind a wall.
// world_view.gd updates the uniforms every frame.
shader_type spatial;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform vec3 focus = vec3(0.0, -1000.0, 0.0);  // the player's chest
uniform vec3 cam_pos = vec3(0.0, 1000.0, 0.0);
uniform float radius = 2.6;     // metres around the line
uniform float keep_h = 0.55;    // walls are never cut below this (above the floor)
uniform float floor_y = 0.0;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	// The shadow pass renders from the light: never cut there.
	bool main_view = distance(CAMERA_POSITION_WORLD, cam_pos) < 1.0;
	if (main_view && v_world.y > floor_y + keep_h) {
		vec3 d = cam_pos - focus;
		float t = dot(v_world - focus, d) / dot(d, d);
		if (t > 0.0 && t < 1.0) {
			// Distance in the ground plane only: a soft vertical cylinder
			// following the view line (cuts the whole wall height).
			vec3 c = focus + d * t;
			float dist = length((v_world - c).xz);
			float cut = 1.0 - smoothstep(radius * 0.65, radius, dist);
			// Only things clearly between (in front of) the player and the camera.
			cut *= smoothstep(0.0, 0.08, t);
			if (cut > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	// the room this face looks into: dark when it is (atmos.gdshaderinc)
	vec4 a = atmos_at(v_world + vec3(v_normal.x, 0.0, v_normal.z) * 0.45);
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * atmos_light(a);  // vertex colours are sRGB
	ROUGHNESS = 0.9;
}
