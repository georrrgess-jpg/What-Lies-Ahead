shader_type spatial;
// Patterned first-person arm materials (glove, plate, cuff, sleeve). Used by
// glove skins and by operators' arm schemes (scripts/player/weapon_cosmetics.gd).
// Patterns are 3D so they wrap the arms of every weapon model without UVs.
//   0 solid  1 stripes  2 camo  3 checker  4 polka dots  5 knit  6 tiger
//   7 neon lines  8 scales  9 flames  10 stars  11 pixels  12 circuit traces
//   13 bones (12 and 13 are drawn on the face of each surface's main axis)
uniform vec3 base_color : source_color = vec3(0.17, 0.16, 0.21);
uniform vec3 accent_color : source_color = vec3(1.0, 0.25, 0.62);
uniform vec3 third_color : source_color = vec3(1.0, 1.0, 1.0);
uniform int pattern = 0;
uniform float scale = 1.0;
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform float glow = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// 2D coordinates on the plane facing the normal's main axis (box mapping).
vec2 box_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.x > a.y && a.x > a.z) {
		return p.yz;
	}
	return a.y > a.z ? p.xz : p.xy;
}

float bone_sdf(vec2 f) {
	vec2 q = vec2(clamp(f.x, -0.22, 0.22), 0.0);
	float shaft = length(f - q) - 0.055;
	vec2 k = vec2(0.25, 0.07);
	vec2 a = abs(f);
	return min(shaft, length(a - k) - 0.08);
}

// Returns (accent amount, third-colour amount).
vec2 pattern_mask(vec3 p, vec3 nrm) {
	if (pattern == 1) {
		float s = fract(dot(p, vec3(0.35, 0.6, 0.7)) * 22.0);
		return vec2(step(0.55, s), step(0.88, s));
	} else if (pattern == 2) {
		float n = vnoise(p * 26.0);
		float m = vnoise(p * 26.0 + 9.0);
		return vec2(step(0.55, n), step(0.62, m) * (1.0 - step(0.55, n)));
	} else if (pattern == 3) {
		vec3 c = floor(p * 30.0);
		return vec2(mod(c.x + c.y + c.z, 2.0), 0.0);
	} else if (pattern == 4) {
		vec3 c = p * 34.0;
		float d = length(fract(c) - 0.5);
		float alt = mod(dot(floor(c), vec3(1.0)), 2.0);
		return vec2(step(d, 0.3) * (1.0 - alt), step(d, 0.3) * alt);
	} else if (pattern == 5) {
		// Knit: zigzag rows like a woolly jumper, with a contrast band.
		float row = p.y * 40.0 + abs(fract(p.x * 30.0 + p.z * 30.0) - 0.5) * 1.6;
		float band = fract(p.y * 5.0);
		return vec2(step(0.5, fract(row)) * 0.35 + step(0.7, band), step(0.75, band) * step(0.5, fract(row)));
	} else if (pattern == 6) {
		float n = vnoise(p * vec3(8.0, 30.0, 8.0)) * 0.6 + vnoise(p * 50.0) * 0.4;
		float s = abs(fract(dot(p, vec3(10.0, 2.0, 12.0)) + n * 1.2) - 0.5);
		return vec2(step(s, 0.12), 0.0);
	} else if (pattern == 7) {
		vec3 g = abs(fract(p * 18.0) - 0.5);
		float l = step(0.44, max(g.x, g.z)) * step(0.3, fract(p.y * 9.0));
		return vec2(l, 0.0);
	} else if (pattern == 8) {
		vec3 c = p * vec3(40.0, 52.0, 40.0);
		vec3 f = fract(c) - 0.5;
		float d = length(f.xy + vec2(0.0, 0.25));
		return vec2(smoothstep(0.42, 0.5, d), step(0.5, vnoise(floor(c))) * 0.4);
	} else if (pattern == 9) {
		float n = vnoise(p * 30.0 + vec3(0.0, -TIME * 1.5, 0.0));
		float h = fract(p.y * 3.0 + 0.5) + n * 0.6;
		return vec2(step(0.75, h), step(1.05, h));
	} else if (pattern == 10) {
		vec3 c = p * 22.0;
		vec3 f = fract(c) - 0.5;
		float a = atan(f.y, f.x + f.z);
		float r = length(f) * (1.0 + 0.45 * sin(a * 5.0));
		return vec2(step(r, 0.24) * step(0.5, hash31(floor(c))), 0.0);
	} else if (pattern == 11) {
		vec3 q = floor(p * 45.0);
		float n = vnoise(q * 0.22);
		return vec2(step(0.58, n), step(0.82, hash31(q)));
	} else if (pattern == 12) {
		// Circuit board: straight traces cell by cell, solder pads at some joints.
		vec2 g = box_uv(p, nrm) * 24.0;
		vec2 i = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash31(vec3(i, 1.0));
		float line = h < 0.45 ? step(abs(f.y), 0.075) : (h < 0.9 ? step(abs(f.x), 0.075) : 0.0);
		float pad = step(length(f), 0.2) * step(0.72, hash31(vec3(i, 5.0)));
		return vec2(max(line, pad), pad);
	} else if (pattern == 13) {
		// Scattered cartoon bones, turned every which way.
		vec2 g = box_uv(p, nrm) * 15.0;
		vec2 i = floor(g);
		vec2 f = fract(g) - 0.5;
		float a = floor(hash31(vec3(i, 2.0)) * 4.0) * 0.785;
		f = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * f;
		float bone = step(bone_sdf(f), 0.0) * step(0.3, hash31(vec3(i, 9.0)));
		return vec2(bone, bone * step(0.85, hash31(vec3(i, 4.0))));
	}
	return vec2(0.0);
}

void fragment() {
	vec2 m = pattern_mask(lp * scale, ln);
	vec3 col = mix(base_color, accent_color, clamp(m.x, 0.0, 1.0));
	col = mix(col, third_color, clamp(m.y, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = accent_color * m.x * glow;
}
