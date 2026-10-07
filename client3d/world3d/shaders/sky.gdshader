// The sky (lighting_3d.gd sets the colours by the time of day): a gradient,
// the sun's disc and glow, drifting clouds, stars and the moon at night,
// and a flash of lightning.
shader_type sky;
render_mode use_quarter_res_pass;

uniform vec3 top_color : source_color = vec3(0.37, 0.6, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.85, 0.9, 0.94);
uniform vec3 ground_color : source_color = vec3(0.25, 0.28, 0.24);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float clouds = 0.2;      // cover 0..1
uniform float night = 0.0;       // stars, moon
uniform float flash = 0.0;       // lightning
uniform float energy = 1.0;
uniform vec3 moon_dir = vec3(0.3, 0.6, -0.74);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	return noise2(p) * 0.5 + noise2(p * 2.1) * 0.27 + noise2(p * 4.3) * 0.15 + noise2(p * 8.7) * 0.08;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, pow(min(-h * 3.0, 1.0), 0.6));
	}
	if (h > 0.0) {
		// stars and the moon
		if (night > 0.01) {
			vec3 cell = floor(d * 220.0);
			float s = hash3(cell);
			float star = step(0.9975, s) * (0.5 + 0.5 * sin(TIME * (1.0 + s * 3.0) + s * 40.0));
			col += vec3(star) * night * smoothstep(0.0, 0.25, h) * 1.6;
			float md = dot(d, normalize(moon_dir));
			col += vec3(0.85, 0.88, 1.0) * night * (smoothstep(0.9994, 0.9997, md) * 2.0 + pow(max(md, 0.0), 300.0) * 0.25);
		}
		// the sun
		if (LIGHT0_ENABLED) {
			float sd = dot(d, LIGHT0_DIRECTION);
			vec3 sc = LIGHT0_COLOR * LIGHT0_ENERGY;
			col += sc * (smoothstep(0.9992, 0.9996, sd) * 6.0 + pow(max(sd, 0.0), 24.0) * 0.35 + pow(max(sd, 0.0), 4.0) * 0.12) * (1.0 - night);
		}
		// clouds on a plane far above
		vec2 uv = d.xz / (h + 0.12) * 1.4 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv);
		float cover = smoothstep(1.0 - clouds * 0.75 - 0.2, 1.0 - clouds * 0.75 + 0.15, n);
		vec3 cc = mix(cloud_color, cloud_color * 0.55, smoothstep(0.4, 0.9, n) * clouds);
		col = mix(col, cc, cover * smoothstep(0.0, 0.18, h) * 0.95);
	}
	col *= energy;
	col += vec3(0.75, 0.8, 1.0) * flash * 2.5;
	COLOR = col;
}
