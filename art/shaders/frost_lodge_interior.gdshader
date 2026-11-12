shader_type spatial;
render_mode unshaded, cull_back;

// Interior mapping for the lodge's A-frame glass wall: every pixel of the
// glass casts the view ray into an imaginary room behind it (in the mesh's
// local space) and shades whatever it hits: plank floor with a rug, knotty
// pine under the sloping roof, a log back wall with a roaring stone
// fireplace, a loft and a glowing chandelier. No textures, no extra geometry.
uniform vec3 room_min = vec3(-10.6, 1.4, -13.6);
uniform vec3 room_max = vec3(10.6, 14.4, -0.6);
uniform float loft_height = 6.0;
uniform float loft_depth = 4.5;
uniform vec3 wood_color : source_color = vec3(0.72, 0.42, 0.24);
uniform vec3 pine_color : source_color = vec3(0.86, 0.6, 0.36);
uniform vec3 log_color : source_color = vec3(0.55, 0.3, 0.18);
uniform vec3 stone_color : source_color = vec3(0.48, 0.42, 0.5);
uniform vec3 fire_color : source_color = vec3(1.0, 0.55, 0.16);
uniform vec3 rug_color : source_color = vec3(0.75, 0.16, 0.2);
uniform vec3 glass_tint : source_color = vec3(1.0, 0.86, 0.66);
uniform float brightness = 1.25;

varying vec3 local_pos;
varying vec3 local_cam;

void vertex() {
	local_pos = VERTEX;
	local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float stripes(float x, float width, float soft) {
	float f = fract(x / width);
	return smoothstep(0.0, soft, f) * smoothstep(1.0, 1.0 - soft, f);
}

// Height of the A-frame roof above x.
float roof_y(float x) {
	return room_min.y + (room_max.x - abs(x)) / room_max.x * (room_max.y - room_min.y);
}

void fragment() {
	vec3 dir = normalize(local_pos - local_cam);
	vec3 o = local_pos;
	float t_hit = 1e5;
	int face = 0;   // 1 floor, 2 back wall, 3 roof, 4 loft
	if (dir.y < 0.0) {
		float t = (room_min.y - o.y) / dir.y;
		if (t > 0.0 && t < t_hit) { t_hit = t; face = 1; }
	}
	if (dir.z < 0.0) {
		float t = (room_min.z - o.z) / dir.z;
		if (t > 0.0 && t < t_hit) { t_hit = t; face = 2; }
	}
	// Both roof planes: y = roof_y(x).
	float slope = (room_max.y - room_min.y) / room_max.x;
	for (int s = 0; s < 2; s++) {
		float sx = s == 0 ? 1.0 : -1.0;
		// y + slope * sx * x = room_min.y + slope * room_max.x
		float denom = dir.y + slope * sx * dir.x;
		if (abs(denom) > 1e-4) {
			float t = (room_min.y + slope * room_max.x - o.y - slope * sx * o.x) / denom;
			vec3 p = o + dir * t;
			if (t > 0.0 && t < t_hit && sx * p.x >= -0.01) { t_hit = t; face = 3; }
		}
	}
	// The loft floor near the glass.
	if (abs(dir.y) > 1e-4) {
		float t = (loft_height - o.y) / dir.y;
		vec3 p = o + dir * t;
		if (t > 0.0 && t < t_hit && p.z > room_max.z - loft_depth && abs(p.x) < 6.5) { t_hit = t; face = 4; }
	}
	vec3 p = o + dir * t_hit;
	vec3 fire_pos = vec3(0.0, room_min.y + 1.0, room_min.z + 0.4);
	float flicker = 0.85 + 0.15 * sin(TIME * 9.0) * sin(TIME * 5.3 + 1.0);
	float fire_light = 3.5 / (1.0 + dot(p - fire_pos, p - fire_pos) * 0.05) * flicker;
	vec3 col = vec3(0.0);
	if (face == 1) {
		float planks = stripes(p.x, 0.5, 0.04);
		col = wood_color * (0.75 + 0.25 * planks);
		vec2 rug = abs(p.xz - vec2(0.0, room_min.z + 4.5)) - vec2(2.6, 1.8);
		float on_rug = 1.0 - smoothstep(0.0, 0.05, max(rug.x, rug.y));
		float rug_band = 1.0 - smoothstep(0.0, 0.05, abs(max(rug.x, rug.y) + 0.35) - 0.12);
		col = mix(col, mix(rug_color, vec3(1.0, 0.82, 0.4), rug_band), on_rug);
	} else if (face == 2) {
		float logs = stripes(p.y, 0.42, 0.1);
		col = log_color * (0.55 + 0.45 * logs);
		float chimney = step(abs(p.x), 2.4);
		float stones = stripes(p.y + floor(p.x / 0.8) * 0.15, 0.45, 0.12) * stripes(p.x + floor(p.y / 0.45) * 0.4, 0.8, 0.1);
		col = mix(col, stone_color * (0.6 + 0.4 * stones), chimney);
		vec2 box = abs(vec2(p.x, p.y - (room_min.y + 1.0))) - vec2(1.3, 0.85);
		float firebox = 1.0 - smoothstep(0.0, 0.08, max(box.x, box.y));
		float flame = 0.6 + 0.4 * sin(p.x * 7.0 + TIME * 6.0) * sin(p.y * 5.0 - TIME * 8.0);
		col = mix(col, fire_color * (1.8 + flame) * flicker, firebox);
		// Two framed pictures either side of the chimney.
		for (int i = 0; i < 2; i++) {
			vec2 c = vec2(i == 0 ? -5.0 : 5.0, room_min.y + 3.2);
			vec2 d = abs(p.xy - c) - vec2(1.0, 0.7);
			float frame = 1.0 - smoothstep(0.0, 0.04, max(d.x, d.y));
			float art = 1.0 - smoothstep(0.0, 0.04, max(d.x, d.y) + 0.12);
			col = mix(col, vec3(0.25, 0.14, 0.1), frame);
			col = mix(col, mix(vec3(0.3, 0.55, 0.85), vec3(0.95, 0.95, 1.0), smoothstep(c.y - 0.2, c.y + 0.3, p.y + abs(p.x - c.x) * 0.6)), art);
		}
	} else if (face == 3) {
		float boards = stripes(p.y + abs(p.x) * 0.2, 0.35, 0.06);
		col = pine_color * (0.7 + 0.3 * boards);
		float beams = 1.0 - stripes(p.z, 2.4, 0.06) * stripes(p.z + 0.25, 2.4, 0.06);
		col = mix(col, log_color * 0.5, step(0.5, beams) * 0.8);
	} else if (face == 4) {
		col = (dir.y > 0.0 ? wood_color * 0.45 : wood_color * 0.9);
	}
	// Warm room light, the fire, and depth falloff.
	col *= 0.55 + fire_light * 0.25;
	col *= mix(1.0, 0.6, clamp(t_hit / 18.0, 0.0, 1.0));
	// Chandelier: a ring of glowing bulbs hanging in the middle of the hall.
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) / 6.0 * 6.2831853;
		vec3 bulb = vec3(cos(a) * 1.4, 8.6, -6.5 + sin(a) * 1.4);
		float tb = dot(bulb - o, dir);
		if (tb > 0.0 && tb < t_hit) {
			float d = length(o + dir * tb - bulb);
			glow += vec3(1.0, 0.78, 0.45) * exp(-d * d * 18.0) * 2.5;
		}
	}
	// Frost creeping in from the edges of the glass.
	float edge = min(roof_y(local_pos.x) - local_pos.y, local_pos.y - room_min.y);
	float frost = 1.0 - smoothstep(0.0, 0.9, edge);
	vec3 view = normalize(local_cam - local_pos);
	float sheen = pow(1.0 - clamp(view.z, 0.0, 1.0), 3.0) * 0.25;
	vec3 final_col = (col * glass_tint + glow) * brightness;
	final_col = mix(final_col, vec3(0.85, 0.9, 1.0), frost * 0.55) + vec3(0.6, 0.65, 0.95) * sheen;
	ALBEDO = final_col;
}
