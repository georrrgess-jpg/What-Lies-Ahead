// Shared helpers for the finish_*.gdshader weapon finishes
// (contract: scripts/player/weapon_cosmetics.gd). Every finish samples the
// mesh's own space (lp = VERTEX, ln = NORMAL in vertex()), so the pattern
// sticks to the weapon in first person, the Locker and thumbnails alike.
// Weapon models run along local Z (muzzle at -Z), are 0.4-1.0 long and
// 0.1-0.27 wide.

float fh21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fh31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec2 fh22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 fh33(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

float fnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(fh21(i), fh21(i + vec2(1.0, 0.0)), u.x), mix(fh21(i + vec2(0.0, 1.0)), fh21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(fh31(i), fh31(i + vec3(1.0, 0.0, 0.0)), u.x), mix(fh31(i + vec3(0.0, 1.0, 0.0)), fh31(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(fh31(i + vec3(0.0, 0.0, 1.0)), fh31(i + vec3(1.0, 0.0, 1.0)), u.x), mix(fh31(i + vec3(0.0, 1.0, 1.0)), fh31(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float ffbm2(vec2 p) {
	return fnoise2(p) * 0.55 + fnoise2(p * 2.07 + 3.1) * 0.3 + fnoise2(p * 4.13 + 7.7) * 0.15;
}

float ffbm3(vec3 p) {
	return fnoise3(p) * 0.55 + fnoise3(p * 2.07 + 3.1) * 0.3 + fnoise3(p * 4.13 + 7.7) * 0.15;
}

// 2D coordinates on the face's dominant plane. u always runs along the barrel
// (local Z) except on the muzzle and butt faces; v runs up on the sides.
vec2 fplane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.x >= a.y && a.x >= a.z) {
		return vec2(p.z, p.y);
	}
	if (a.y >= a.z) {
		return vec2(p.z, p.x);
	}
	return vec2(p.x, p.y);
}

// 1 on the side faces (the ones the player sees most), 0 elsewhere.
float fside(vec3 n) {
	vec3 a = abs(n);
	return step(a.y, a.x) * step(a.z, a.x);
}

float ffres(vec3 normal, vec3 view, float power) {
	return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), power);
}

// A studio reflection for metals: bright soft-box horizon over a darker floor,
// so polished metal reads as metal even with no reflections around (Locker,
// thumbnails). `r` is the view-space reflection vector.
vec3 fstudio(vec3 r, vec3 tint) {
	float sky = smoothstep(-0.15, 0.15, r.y) * 0.6 + smoothstep(0.25, 0.9, r.y) * 0.4;
	float horizon = exp(-pow((r.y - 0.06) * 8.0, 2.0));
	float box = smoothstep(0.5, 0.8, r.x) * smoothstep(-0.1, 0.3, r.y) * 0.5;
	vec3 deep = tint * 0.35;
	vec3 bright = mix(tint, vec3(1.0), 0.5);
	return mix(deep, bright, sky) + vec3(1.0) * (horizon * 0.45 + box);
}

// A height field turned into a bumped normal (screen-space derivatives; cheap
// and renderer-agnostic). `pos` is VERTEX, `n` is NORMAL (both view space).
vec3 fbump(vec3 pos, vec3 n, float h, float strength) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h) * strength;
	float dhdy = dFdy(h) * strength;
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad);
}

// Hue palette: t in 0..1 around the colour wheel.
vec3 fhue(float t) {
	return clamp(abs(fract(t + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}
