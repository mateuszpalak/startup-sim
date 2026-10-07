// Windows and glass doors: see-through; at night a window of a room with
// the lamp on glows warm.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform vec3 glow : source_color = vec3(1.0, 0.78, 0.45);

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = vec3(v_normal.x, 0.0, v_normal.z) * 0.6;
	float lamp = max(atmos_at(v_world + n).a, atmos_at(v_world - n).a);
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float lit = lamp * atmos_night;
	ALBEDO = c;
	ALPHA = mix(COLOR.a, 0.85, lit * 0.6);
	EMISSION = glow * lit * 1.4;
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
}
