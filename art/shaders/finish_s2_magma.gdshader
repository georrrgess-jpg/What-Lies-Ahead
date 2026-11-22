shader_type spatial;
// Series 2 Epic "Magma Run": plates of cooled black basalt drifting on a
// river of lava. Lava (shell_color red to color_b orange to color_c yellow)
// glows through the cracks between plates and flows along the weapon; the
// plate edges smoulder and embers wink out of the seams. A kill boils the
// lava up white-hot. The trim is forged iron with a red-hot rim.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.9, 0.12, 0.02);
uniform vec3 trim_color : source_color = vec3(0.12, 0.1, 0.1);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.45, 0.05);
uniform vec3 color_c : source_color = vec3(1.0, 0.85, 0.35);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

vec3 lava_ramp(float h) {
	vec3 c = mix(vec3(0.05, 0.0, 0.0), shell_color, smoothstep(0.0, 0.35, h));
	c = mix(c, color_b, smoothstep(0.35, 0.7, h));
	return mix(c, color_c, smoothstep(0.7, 1.0, h));
}

void fragment() {
	float t = s2_time(TIME, 2.0);
	vec2 uv = fplane(lp, ln);
	vec2 flow = vec2(t * 0.012, 0.0);
	vec4 v = s2_voronoi((uv + flow) / 0.028);
	float crack = v.y - v.x;
	float n = ffbm2((uv + flow * 2.5) * 40.0 + vec2(t * 0.25, 0.0));
	float seam = 1.0 - smoothstep(0.04, 0.12 + n * 0.08, crack);
	float heat = clamp(n * 0.9 + 0.25 + pulse * 0.5, 0.0, 1.0);
	float throb = 0.85 + 0.15 * sin(t * 2.0 + v.z * 1.7 + v.w * 2.3);
	vec3 lava = lava_ramp(heat) * throb;
	// The plate: rough rock, warmer towards its edge.
	float rock = ffbm2(uv * 260.0 + v.zw);
	vec3 basalt = vec3(0.05, 0.045, 0.045) * (0.6 + 0.8 * rock);
	float edge = smoothstep(0.3, 0.05, crack) * (1.0 - seam);
	vec2 eid = floor(uv * 240.0);
	float ember = step(0.996, fh21(eid + floor(t * 2.0))) * smoothstep(0.25, 0.0, crack);
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = mix(basalt, lava * 0.5, seam);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.85, 0.4, seam);
	NORMAL = fbump(VERTEX, NORMAL, rock * (1.0 - seam), 0.0015);
	EMISSION = lava * seam * 2.4 + lava_ramp(0.3) * edge * 0.35 * throb + color_c * ember * 3.0;
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
