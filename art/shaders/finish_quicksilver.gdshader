shader_type spatial;
// Weapon finish "Quicksilver": flowing liquid mercury. A slowly warping
// height field bends the surface normal, so the mirror-bright reflection
// ripples, pools and runs along the weapon; a faint oily rainbow sits at
// grazing angles. Trim is darker smoked chrome.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.85, 0.87, 0.92);
uniform vec3 trim_color : source_color = vec3(0.32, 0.33, 0.4);
uniform bool is_trim = false;
uniform float flow = 0.18;
uniform float ripple = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float t = TIME * flow;
	vec3 q = lp * 7.0;
	vec3 warp = vec3(fnoise3(q + vec3(t, 0.0, 0.0)), fnoise3(q + vec3(5.2, t, 1.3)), fnoise3(q + vec3(1.7, 9.2, -t)));
	float h = fnoise3(q * 1.6 + warp * 2.5 + vec3(0.0, 0.0, t * 2.0)) * 0.7 + fnoise3(q * 3.7 - warp * 1.5) * 0.3;
	// Slow travelling ripples along the barrel on top.
	h += sin(lp.z * 60.0 + h * 6.0 - TIME * 1.5) * 0.06;
	// Bump height in model units (a few millimetres), converted to view space
	// so a scaled viewmodel bumps the same.
	float to_view = length(dFdx(VERTEX)) / max(length(dFdx(lp)), 1e-6);
	vec3 n = fbump(VERTEX, NORMAL, h, 0.012 * ripple * to_view);
	NORMAL = n;
	vec3 r = reflect(-VIEW, n);
	float fres = ffres(n, VIEW, 3.0);
	vec3 tint = is_trim ? trim_color : shell_color;
	vec3 refl = fstudio(r, tint);
	vec3 oil = fhue(h * 2.0 + fres + t) * pow(fres, 2.0) * 0.25;
	ALBEDO = tint * 0.5;
	METALLIC = 1.0;
	ROUGHNESS = is_trim ? 0.14 : 0.06;
	SPECULAR = 0.8;
	EMISSION = refl * (is_trim ? 0.5 : 0.75) + tint * 0.12 + oil;
}
