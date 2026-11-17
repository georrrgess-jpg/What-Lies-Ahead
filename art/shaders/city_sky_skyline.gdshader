shader_type spatial;

// Buildings of the burnt city, near and far: concrete walls in world space,
// rows of dark windows (a few still lit, a few burning), soot above the burnt
// ones, a darker base and roofs. Used for the skyline's towers (a MultiMesh of
// boxes, `far_fade` 1) and the cores of the city blocks behind the facades.
uniform vec3 wall_color : source_color = vec3(0.4, 0.34, 0.34);
uniform vec3 window_dark : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 window_lit : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 fire_color : source_color = vec3(1.0, 0.36, 0.1);
uniform vec2 window_size = vec2(3.0, 3.4);    // metres per window cell (across, up)
uniform float lit_fraction = 0.05;
uniform float fire_fraction = 0.04;
uniform float seed = 0.0;
uniform float far_fade = 0.0;                  // 1: fade toward the haze with distance
uniform vec3 haze_color : source_color = vec3(0.32, 0.17, 0.15);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	float roof = step(0.7, n.y);
	float u = n.x > n.z ? world_pos.z : world_pos.x;
	vec2 cell = vec2(u, world_pos.y) / window_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float h = hash(id + floor(world_pos.xz * 0.013) * 17.0);
	float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.28, f.y) * step(f.y, 0.8) * step(1.0, id.y);
	float grain = hash(floor(vec2(u, world_pos.y) * 1.3));
	vec3 wall = wall_color * (0.82 + 0.18 * grain) * mix(0.55, 1.0, smoothstep(0.0, 5.0, world_pos.y));
	// A cornice band every fourth floor, like the skyline's (one city).
	wall *= 1.0 - 0.3 * step(3.0, mod(id.y, 4.0)) * step(f.y, 0.14);
	// Soot streaks above the burnt-out windows.
	float burnt = step(1.0 - fire_fraction * 4.0, h);
	wall *= 1.0 - burnt * step(0.8, f.y) * 0.6;
	vec3 col = mix(wall, window_dark, win);
	vec3 glow = vec3(0.0);
	if (win > 0.5) {
		if (h > 1.0 - fire_fraction) {
			glow = fire_color * (1.3 + 0.5 * sin(TIME * 3.0 + h * 50.0)) * (0.5 + 0.5 * (1.0 - f.y));
		} else if (h < lit_fraction) {
			glow = window_lit * 0.8;
		}
	}
	col = mix(col, wall_color * 0.35, roof);
	glow *= 1.0 - roof;
	float fade = far_fade * clamp((length(world_pos - CAMERA_POSITION_WORLD) - 100.0) / 350.0, 0.0, 0.75);
	ALBEDO = mix(col, haze_color, fade);
	EMISSION = glow * (1.0 - fade * 0.5) + haze_color * fade * 0.6;
	ROUGHNESS = 0.9;
}
