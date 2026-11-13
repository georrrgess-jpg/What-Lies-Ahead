shader_type spatial;
// Weapon finish "Kaleidoscope": tiles of six-fold mirrored candy-glass shards
// that turn slowly, each tile its own rosette, with dark seams between the
// shards. On the trim the glass sits in a dark mirror with a rainbow edge.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(1.0, 0.45, 0.75);
uniform vec3 trim_color : source_color = vec3(0.05, 0.03, 0.08);
uniform bool is_trim = false;
uniform float tile = 0.12;
uniform float turn_speed = 0.25;
uniform float hue_offset = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	vec2 uv = fplane(lp, ln) / tile;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float seed = fh21(id);
	// Fold the angle into twelve mirrored wedges (six-fold symmetry).
	float a = atan(f.y, f.x) + TIME * turn_speed * (seed > 0.5 ? 1.0 : -1.0);
	float wedge = 3.14159265 / 6.0;
	a = abs(mod(a, 2.0 * wedge) - wedge);
	float rad = length(f);
	vec2 k = vec2(cos(a), sin(a)) * rad;
	// Shards: a few soft noise bands cut into flat facets.
	float v = fnoise2(k * 4.5 + seed * 40.0 + vec2(0.0, TIME * 0.12));
	float shards = v * 2.6 + rad * 2.4;
	float band = floor(shards);
	float seam = smoothstep(0.08, 0.0, min(fract(shards), 1.0 - fract(shards)));
	float spoke = smoothstep(0.035, 0.0, a * rad) * step(0.06, rad);
	float pick = fract(band * 0.37 + seed * 0.61);
	vec3 glass = pick < 0.25 ? shell_color : (pick < 0.5 ? vec3(0.2, 0.85, 1.0) : (pick < 0.75 ? vec3(1.0, 0.85, 0.2) : vec3(0.55, 0.3, 1.0)));
	glass = mix(glass, fhue(pick + hue_offset), 0.15);
	// Seams between shards, faint mirror spokes, and a frame round each tile.
	seam = max(max(seam, spoke * 0.6), smoothstep(0.46, 0.5, max(abs(f.x), abs(f.y))));
	if (is_trim) {
		// The same glass seen in a dark mirror: deeper, with a rainbow rim.
		vec3 rim = fhue(fres * 0.8 + TIME * 0.05 + hue_offset);
		vec3 deep = mix(glass, trim_color, 0.55);
		ALBEDO = deep * (1.0 - seam * 0.85);
		METALLIC = 0.5;
		ROUGHNESS = 0.12;
		EMISSION = deep * 0.35 * (1.0 - seam) + fstudio(r, vec3(0.5)) * 0.15 + rim * fres * 0.5;
	} else {
		ALBEDO = glass * (1.0 - seam * 0.85);
		METALLIC = 0.1;
		ROUGHNESS = 0.15;
		EMISSION = glass * (0.45 + 0.2 * fres) * (1.0 - seam) + vec3(1.0) * smoothstep(0.08, 0.0, rad) * 0.6;
	}
}
