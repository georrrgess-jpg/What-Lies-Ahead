shader_type spatial;
// Impact marks left on the static world by shots (see scripts/fx/impact_marks.gd).
// One quad per mark in a MultiMesh; everything is procedural (no textures).
// Per instance: COLOR = the weapon's energy colour, INSTANCE_CUSTOM =
// (spawn time, style, seed, seconds before the fade). Premultiplied alpha
// lets one draw both darken the surface (soot) and add light (the hot glow).
// Styles: 0 bolt hole, 1 pellet, 2 rail streak, 3 blast scorch, 4 frost
// patch, 5 arc burn, 6 bounce scuff.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, fog_disabled, shadows_disabled, skip_vertex_transform;

// The marks' clock (seconds), advanced by the pool while any mark is alive.
uniform float now = 0.0;
// Seconds a mark takes to fade (or, for frost, to melt) once its time is up.
uniform float fade_time = 2.5;

varying vec4 v_data;
varying vec3 v_color;
varying float v_dist;

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_color = COLOR.rgb;
	vec3 view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dist = length(view);
	// Pulled a hair towards the eye: the same pixels on screen, a nearer depth,
	// so the mark never fights the surface it lies on at any distance.
	VERTEX = view * 0.9995;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Coverage of branch k of an arc burn: a jagged line wandering outwards
// from radius `start` to `reach`, thinning as it goes.
float branch(float r, float ang, float k, float seed, float start, float reach, float wander) {
	float a = seed * 6.2832 + k * 2.39996 + (noise(vec2(r * 5.0, k * 7.3 + seed * 13.0)) - 0.5) * wander;
	float side = abs(mod(ang - a + 3.14159, 6.28318) - 3.14159) * r;
	float t = clamp((r - start) / max(reach - start, 0.01), 0.0, 1.0);
	float inside = step(start, r) * (1.0 - smoothstep(0.8, 1.0, t));
	float thick = mix(0.07, 0.015, t);
	return inside * (1.0 - smoothstep(thick * 0.45, thick, side));
}

void fragment() {
	float age = now - v_data.x;
	int style = int(v_data.y + 0.5);
	float seed = v_data.z;
	float life = v_data.w;
	float fade = 1.0 - smoothstep(life, life + fade_time, age);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float heat = exp(-age * 3.0);

	float soot = 0.0;   // how much of the surface is darkened (0-1)
	float stain = 0.0;  // lingering tint of the weapon's colour
	float glow = 0.0;   // hot light, cooling to nothing in about a second
	vec3 cover = vec3(0.0); // frost: a pale layer laid over the surface
	float cover_a = 0.0;

	if (style <= 1) {
		// A small scorched hole: a dark core in a soot ring with a ragged rim.
		float pellet = float(style);
		float edge = mix(0.8, 0.88, pellet) + mix(0.2, 0.1, pellet) * (noise(dir * 3.0 + seed * 13.0) - 0.5);
		float hole = 1.0 - smoothstep(0.17, 0.26, r);
		float ring = 1.0 - smoothstep(0.2, edge, r);
		float spikes = smoothstep(0.62, 0.86, noise(dir * 5.0 + seed * 7.0)) * (1.0 - smoothstep(0.25, 0.97, r)) * (1.0 - pellet);
		soot = max(hole * 0.92, max(pow(ring, 1.3) * 0.8, spikes * 0.6));
		stain = smoothstep(0.18, 0.34, r) * (1.0 - smoothstep(0.34, edge, r)) * 0.14;
		glow = heat * (1.0 - smoothstep(0.0, 0.5, r)) * 2.4;
	} else if (style == 2 || style == 6) {
		// A burnt gouge along the shot (rail), or a soft skid (bounce).
		float scuff = float(style == 6);
		float w = sqrt(max(0.0, 1.0 - p.x * p.x)) * (0.7 + 0.3 * noise(vec2(p.x * 5.0, seed * 9.0)));
		float d = abs(p.y) / max(w, 0.02);
		float body = 1.0 - smoothstep(0.3, 1.0, d);
		float core = (1.0 - smoothstep(0.0, 0.3, d)) * smoothstep(0.0, 0.4, w);
		soot = mix(max(core * 0.95, body * 0.78), body * 0.45, scuff);
		stain = body * (1.0 - core) * mix(0.12, 0.22, scuff);
		heat = exp(-age * mix(2.2, 4.0, scuff));
		glow = heat * exp(-d * d * 5.0) * w * mix(2.2, 0.8, scuff);
	} else if (style == 3) {
		// A round blast scorch: soot flaring out in rays, mottled, embers
		// that glow a little longer than a shot's, and a coloured rim.
		float edge = 0.66 + 0.26 * (noise(dir * 2.5 + seed * 5.0) - 0.5) + 0.14 * (noise(dir * 7.0 + seed * 3.0) - 0.5);
		float body = pow(1.0 - smoothstep(0.08, edge, r), 0.75);
		float rays = smoothstep(0.55, 0.8, noise(dir * 9.0 + seed * 11.0)) * (1.0 - smoothstep(0.3, 0.98, r));
		soot = max(body * 0.85, rays * 0.6) * (0.78 + 0.22 * noise(p * 9.0 + seed * 17.0));
		float rim = smoothstep(edge - 0.22, edge - 0.06, r) * (1.0 - smoothstep(edge - 0.06, edge + 0.06, r));
		stain = rim * 0.3 + body * 0.06;
		float embers = smoothstep(0.72, 0.9, noise(p * 13.0 + seed * 21.0)) * body;
		glow = embers * exp(-age * 1.1) * 2.0 + heat * (1.0 - smoothstep(0.0, 0.6, r)) * 0.9;
	} else if (style == 4) {
		// A frost patch: six-fold crystal fingers over a mottled rime, which
		// melts back to the middle instead of fading.
		float a = atan(p.y, p.x) + seed * 6.2832;
		float melt = smoothstep(life, life + fade_time, age);
		float edge = (0.62 + 0.2 * pow(abs(cos(a * 3.0)), 8.0) + 0.3 * (noise(dir * 3.0 + seed * 4.0) - 0.5) + 0.12 * (noise(dir * 9.0 + seed * 2.0) - 0.5)) * (1.0 - melt);
		float rime = 1.0 - smoothstep(edge - 0.14, edge, r);
		float feather = pow(abs(cos(a * 9.0 + r * 4.0)), 18.0) * (1.0 - smoothstep(edge * 0.7, edge * 1.15, r)) * 0.6;
		float body = max(rime * (0.6 + 0.4 * noise(p * 11.0 + seed * 19.0)), feather);
		cover_a = body * 0.6;
		cover = mix(vec3(0.62, 0.86, 1.0), vec3(1.0), noise(p * 7.0 + seed) * 0.5) * 0.95 * cover_a;
		float sparkle = smoothstep(0.93, 0.98, noise(p * 26.0 + seed * 31.0)) * rime;
		glow = sparkle * (0.5 + 1.2 * heat) + heat * rime * 0.6;
		fade = 1.0;
	} else {
		// An arc burn: jagged branches crawling out from a burnt spot.
		float lines = 0.0;
		float ang = atan(p.y, p.x);
		for (int k = 0; k < 6; k++) {
			lines = max(lines, branch(r, ang, float(k), seed, 0.0, 0.55 + 0.4 * hash(vec2(float(k), seed)), 2.2));
		}
		for (int k = 6; k < 11; k++) {
			float s = 0.2 + 0.35 * hash(vec2(seed, float(k)));
			lines = max(lines, branch(r, ang, float(k), seed + 0.37, s, s + 0.25 + 0.2 * hash(vec2(float(k), seed * 3.0)), 3.0) * 0.8);
		}
		float spot = 1.0 - smoothstep(0.08, 0.17, r);
		float halo = (1.0 - smoothstep(0.0, 0.75, r)) * 0.25;
		soot = max(max(lines, spot) * 0.86, halo * (0.6 + 0.4 * noise(p * 6.0 + seed)));
		stain = lines * 0.07;
		glow = heat * max(lines, spot) * 2.0;
	}

	// Far marks are a few pixels: let them go rather than shimmer.
	float keep = fade * (1.0 - smoothstep(35.0, 50.0, v_dist));
	vec3 hot = mix(v_color, vec3(1.0), clamp(heat * 0.7, 0.0, 1.0));
	vec3 soot_color = mix(vec3(0.035, 0.025, 0.05), v_color * 0.08, 0.3);
	float a = clamp(max(soot, cover_a), 0.0, 1.0);
	vec3 rgb = soot_color * soot + cover + v_color * stain + hot * glow;
	ALBEDO = rgb * keep;
	ALPHA = a * keep;
}
