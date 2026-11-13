shader_type spatial;
// Weapon finish "Solar Flare": the surface of a star. Boiling plasma granules
// with dark lanes between them churn slowly; now and then a flare swells and
// bursts white-hot. The trim is darker penumbra with an orange corona rim.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.75, 0.12, 0.02);
uniform vec3 trim_color : source_color = vec3(0.12, 0.04, 0.02);
uniform bool is_trim = false;
uniform vec3 hot_color : source_color = vec3(1.0, 0.75, 0.2);
uniform float churn = 0.25;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	float t = TIME * churn;
	// Granules: ridged noise, bright cells bounded by dark lanes.
	float g = fnoise3(lp * 38.0 + vec3(t, -t * 0.7, t * 0.5));
	float g2 = fnoise3(lp * 80.0 - vec3(t * 1.3, t, 0.0));
	float cells = 1.0 - abs(g * 2.0 - 1.0);
	cells = cells * 0.75 + g2 * 0.25;
	float big = ffbm3(lp * 7.0 + vec3(0.0, t * 0.6, t * 0.3));
	// Flares: a slow field that, when it peaks, pulses over a few seconds.
	float f = fnoise3(lp * 4.0 + vec3(t * 0.8, 0.0, -t));
	float burst = pow(0.5 + 0.5 * sin(TIME * 0.9 + f * 12.0), 6.0);
	float flare = smoothstep(0.6, 0.8, f) * burst;
	float heat = clamp(cells * 0.6 + big * 0.5 + flare * 0.7 - 0.15, 0.0, 1.0);
	vec3 col = mix(shell_color * 0.35, shell_color, smoothstep(0.1, 0.5, heat));
	col = mix(col, hot_color, smoothstep(0.45, 0.8, heat));
	col = mix(col, vec3(1.0, 0.97, 0.85), smoothstep(0.85, 1.0, heat) + flare * 0.5);
	if (is_trim) {
		// Penumbra: the same plasma, cooler and darker, with a corona rim.
		ALBEDO = mix(trim_color, col * 0.3, 0.5);
		METALLIC = 0.2;
		ROUGHNESS = 0.4;
		EMISSION = col * 0.4 * (0.4 + 0.6 * cells) + hot_color * pow(fres, 2.0) * 0.8;
	} else {
		ALBEDO = col * 0.4;
		METALLIC = 0.0;
		ROUGHNESS = 0.5;
		EMISSION = col * (1.1 + flare) + hot_color * pow(fres, 2.0) * 0.3;
	}
}
