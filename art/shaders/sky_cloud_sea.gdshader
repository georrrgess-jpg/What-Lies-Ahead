shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// The sea of clouds far below the islands: rolling cumulus tops, sunlit peach
// on the sun side and lilac-blue in the troughs, fading into the horizon haze.
// Two noise layers at different scales and speeds give it depth. `speed` rises
// during the Gale twist.
uniform vec3 top_color : source_color = vec3(1.0, 0.97, 0.94);
uniform vec3 lit_color : source_color = vec3(1.0, 0.8, 0.62);
uniform vec3 trough_color : source_color = vec3(0.62, 0.64, 0.86);
uniform vec3 haze_color : source_color = vec3(0.98, 0.88, 0.84);
uniform vec2 sun_direction = vec2(0.96, 0.26);
uniform vec2 wind = vec2(-1.0, 0.25);
uniform float speed = 1.0;
uniform float haze_start = 250.0;
uniform float haze_end = 1500.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * speed;
	vec2 drift = wind * t;
	float big = fbm(p * 0.006 + drift * 0.004);
	float small = fbm(p * 0.03 + drift * 0.012 + big * 1.5);
	float h = big * 0.7 + small * 0.3;
	// Fake light from the sun: compare the height a step toward the sun.
	vec2 ld = normalize(sun_direction);
	float h2 = fbm((p + ld * 18.0) * 0.006 + drift * 0.004) * 0.7 + small * 0.3;
	float shade = clamp(0.55 + (h - h2) * 6.0, 0.0, 1.0);
	vec3 col = mix(trough_color, top_color, smoothstep(0.3, 0.62, h));
	col = mix(col, lit_color, shade * smoothstep(0.4, 0.7, h) * 0.45);
	col = mix(col * 0.92, col, shade);
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, haze_color, smoothstep(haze_start, haze_end, dist));
	ALBEDO = col;
}
