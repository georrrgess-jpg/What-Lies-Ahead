shader_type spatial;
// Weapon finish "Teacup Ride": a grid of turntables, each carrying three
// pastel teacups that ride round its hub while every cup spins on its own
// saucer, swirl-striped with a gold rim. Chasing bulbs ring each platter
// over deep plum. On the trim the ride glows through smoked glass.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(1.0, 0.42, 0.72);
uniform vec3 trim_color : source_color = vec3(0.12, 0.05, 0.16);
uniform bool is_trim = false;
uniform vec3 cup_b : source_color = vec3(0.42, 0.95, 0.82);
uniform vec3 cup_c : source_color = vec3(1.0, 0.86, 0.36);
uniform vec3 floor_color : source_color = vec3(0.2, 0.07, 0.24);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.3);
uniform float tile = 0.11;
uniform float ride_speed = 0.6;
uniform float spin_speed = 2.4;

varying vec3 lp;
varying vec3 ln;

// One cup seen from above at `q` (its own centre): colour and coverage.
vec4 cup(vec2 q, float spin, vec3 col) {
	float d = length(q);
	float body = smoothstep(0.155, 0.145, d);
	float rim = smoothstep(0.02, 0.0, abs(d - 0.14)) * body;
	float inner = smoothstep(0.1, 0.09, d);
	// Swirl stripes winding into the cup, turning with it.
	float a = atan(q.y, q.x) + spin + d * 18.0;
	float stripe = step(0.5, fract(a * 0.954929658));
	vec3 c = mix(col, vec3(1.0, 0.97, 0.92), stripe * 0.55 * (1.0 - inner));
	c = mix(c, col * 0.55, inner);
	c = mix(c, gold, rim);
	// Handle: a nub on the rim that turns with the cup.
	vec2 h = vec2(cos(spin), sin(spin)) * 0.17;
	float handle = smoothstep(0.035, 0.025, length(q - h));
	c = mix(c, col, handle * (1.0 - body));
	return vec4(c, max(body, handle));
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	vec2 uv = fplane(lp, ln) / tile;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float seed = fh21(id);
	float dir = seed > 0.5 ? 1.0 : -1.0;
	float d = length(f);
	// The platter: a disc with a hub, and bulbs round its edge that chase.
	float platter = smoothstep(0.46, 0.44, d);
	float ring = smoothstep(0.025, 0.0, abs(d - 0.42));
	float ang = atan(f.y, f.x);
	float bulb_a = fract(ang * 1.909859317 + 0.5);
	float bulbs = smoothstep(0.03, 0.012, length(vec2((bulb_a - 0.5) * 0.22, d - 0.42)));
	float chase = step(0.5, fract(floor(ang * 1.909859317 + 6.0) * 0.5 + TIME * 2.0));
	vec3 col = mix(floor_color * 0.6, floor_color, platter);
	col = mix(col, gold * 0.7, ring * 0.6);
	vec3 glow = gold * bulbs * (0.25 + 0.95 * chase);
	col = mix(col, gold, bulbs * (0.4 + 0.6 * chase));
	float hub = smoothstep(0.07, 0.06, d);
	col = mix(col, gold, hub);
	// Three cups riding round the hub, each spinning on its own.
	float ride = TIME * ride_speed * dir + seed * 6.28;
	float covered = 0.0;
	vec3 cups[3] = vec3[3](shell_color, cup_b, cup_c);
	for (int i = 0; i < 3; i++) {
		float a = ride + float(i) * 2.0943951;
		vec2 c = vec2(cos(a), sin(a)) * 0.25;
		vec4 k = cup(f - c, TIME * spin_speed * -dir + float(i) * 1.7, cups[(i + int(seed * 3.0)) % 3]);
		col = mix(col, k.rgb, k.a);
		covered = max(covered, k.a);
	}
	if (is_trim) {
		vec3 deep = mix(col, trim_color, 0.5);
		ALBEDO = deep;
		METALLIC = 0.45;
		ROUGHNESS = 0.14;
		EMISSION = deep * 0.3 + glow * 0.8 + fstudio(r, vec3(0.5)) * 0.12 + gold * fres * 0.25;
	} else {
		ALBEDO = col;
		METALLIC = 0.12;
		ROUGHNESS = mix(0.4, 0.16, covered);
		EMISSION = col * (0.18 + 0.22 * covered) + glow + gold * fres * 0.12;
	}
	PRINT_LAYER
}
