// Characters and what they hold (avatar_mesh.gd mat()): matte colour,
// darkened as a whole in an unlit windowless room - the room is looked up
// once at the object's origin, so a figure never gets a lit/dark seam.
shader_type spatial;

#include "res://world3d/shaders/atmos.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.78;
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy = 0.0;

varying float v_light;

void vertex() {
	// no world built yet (character creation preview): fully lit
	if (atmos_mask_size.x <= 1.0) {
		v_light = 1.0;
	} else {
		v_light = atmos_light(atmos_at(NODE_POSITION_WORLD + vec3(0.0, 0.3, 0.0)));
	}
}

void fragment() {
	ALBEDO = albedo.rgb * v_light;
	ROUGHNESS = roughness;
	SPECULAR = 0.5 * v_light;
	EMISSION = emission.rgb * emission_energy;
}
