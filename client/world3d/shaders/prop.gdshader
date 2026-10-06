// Furniture and other vertex-coloured things (materials.gd "matte", "wood",
// ...): like a StandardMaterial3D, darkened in unlit windowless rooms.
shader_type spatial;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform float roughness = 0.85;
uniform float metallic = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 a = atmos_at(v_world);
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * a.g;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
