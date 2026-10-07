// Glowing surfaces (monitors, signs, lamps): vertex colour, emitted.
shader_type spatial;

uniform float energy = 1.6;

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * 0.3;
	EMISSION = c * energy;
	ROUGHNESS = 0.25;
}
