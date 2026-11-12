shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The acrylic window of a display tank. Everything drawn behind it (sand,
// coral, kelp, fish, the tank walls) is seen "through water": the shader reads
// the depth buffer to find how much water lies between the glass and the
// object behind it, fogs it toward a depth-graded water colour, projects
// rippling caustics onto it, and marches a few samples along the view ray to
// add slanted god rays and drifting particles. The glass adds a fresnel rim
// and soft streaky reflections. Cheap enough for a handful of panes.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D caustic_tex : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec3 deep_color : source_color = vec3(0.01, 0.07, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.04, 0.42, 0.56);
uniform vec3 ray_color : source_color = vec3(0.45, 0.95, 1.0);
uniform vec3 transmit_tint : source_color = vec3(0.62, 0.9, 1.0);
// Fog per metre of water, and the distance at which empty views saturate.
uniform float density = 0.11;
uniform float max_distance = 26.0;
// World heights of the tank floor and water surface (for the colour grade and rays).
uniform float floor_y = 0.0;
uniform float surface_y = 6.5;
uniform float ray_strength = 0.5;
uniform float ray_scale = 1.0;
uniform float caustic_strength = 0.7;
uniform float particle_strength = 0.0;
uniform float glass_rim = 0.35;
uniform float brightness = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float caustic(vec3 p) {
	vec2 uv = p.xz * 0.21 + vec2(p.y * 0.04);
	float t = TIME * 0.035;
	float a = texture(caustic_tex, uv + vec2(t, t * 0.6)).r;
	float b = texture(caustic_tex, uv * 1.33 + vec2(-t * 0.8, t * 0.45) + 0.37).r;
	return pow(min(a, b) * 1.6, 1.3);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	vec4 vpos = INV_PROJECTION_MATRIX * ndc;
	vpos.xyz /= vpos.w;
	vec3 behind_w = (INV_VIEW_MATRIX * vec4(vpos.xyz, 1.0)).xyz;
	vec3 glass_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ray = behind_w - glass_w;
	float dist = min(length(ray), max_distance);
	vec3 dir = normalize(ray);
	float span = max(0.5, surface_y - floor_y);

	// Water colour: darker toward the floor and far away, lighter near the surface.
	float h = clamp((mix(glass_w.y, behind_w.y, 0.6) - floor_y) / span, 0.0, 1.0);
	vec3 water = mix(deep_color, shallow_color, smoothstep(0.0, 1.1, h));
	float fog = 1.0 - exp(-dist * density);

	// God rays and marine snow along the view ray.
	float rays = 0.0;
	float snow = 0.0;
	const int STEPS = 8;
	for (int i = 0; i < STEPS; i++) {
		float s = (float(i) + 0.5) / float(STEPS) * dist;
		vec3 p = glass_w + dir * s;
		float ph = clamp((p.y - floor_y) / span, 0.0, 1.0);
		vec2 q = vec2(p.x + p.y * 0.42, p.z + p.y * 0.18) * ray_scale;
		float band = sin(q.x * 1.1 + TIME * 0.35) * sin(q.y * 0.8 - TIME * 0.27)
			+ 0.6 * sin((q.x - q.y) * 2.3 + TIME * 0.5);
		rays += smoothstep(0.45, 1.5, band) * (0.25 + 0.75 * ph) * exp(-s * density * 0.7);
		if (particle_strength > 0.0) {
			vec3 q3 = p * 7.0 + vec3(0.0, TIME * 0.5, 0.0);
			vec3 cell = floor(q3);
			vec3 r = vec3(hash13(cell), hash13(cell + 17.0), hash13(cell + 41.0));
			float d = length(fract(q3) - r);
			snow += smoothstep(0.16, 0.0, d) * step(0.7, hash13(cell + 5.0)) * exp(-s * 0.25);
		}
	}
	rays *= dist / float(STEPS) * 0.22 * ray_strength;
	snow *= particle_strength * 0.12;

	vec3 behind = texture(screen_tex, SCREEN_UV).rgb * transmit_tint;
	float lit = caustic(behind_w) * caustic_strength * (1.0 - fog) * smoothstep(-0.2, 0.6, (behind_w.y - floor_y) / span + 0.3);
	behind += shallow_color * lit * 1.4 + ray_color * lit * 0.35;
	vec3 col = mix(behind, water, clamp(fog, 0.0, 1.0)) * brightness;
	col += ray_color * rays + vec3(0.7, 0.95, 1.0) * snow;

	// Glass: fresnel rim plus faint diagonal streak reflections.
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - abs(dot(n, normalize(-VERTEX))), 4.0);
	float streak = smoothstep(0.92, 1.0, sin((glass_w.x + glass_w.z) * 1.7 + glass_w.y * 2.2) * 0.5 + 0.5);
	col += vec3(0.65, 0.92, 1.0) * (fres * glass_rim + streak * 0.035);
	ALBEDO = col;
}
