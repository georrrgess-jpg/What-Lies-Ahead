shader_type spatial;

// The city beyond the districts (tools/city/city_skyline.gd): one MultiMesh of
// unit boxes for every outer building, setback, roof house, spire and crane.
// Per instance: COLOR is the wall tint; INSTANCE_CUSTOM is (lit fraction,
// burning fraction, seed, window cell metres or 0 for a blank part). Windows
// follow each box's own faces (rotated blocks keep straight rows); far boxes
// fade into the ash haze, the lit and burning windows last.
uniform vec3 window_dark : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 window_lit : source_color = vec3(1.0, 0.74, 0.42);
uniform vec3 window_cold : source_color = vec3(0.62, 0.78, 1.0);
uniform vec3 fire_color : source_color = vec3(1.0, 0.36, 0.1);
uniform vec3 haze_color : source_color = vec3(0.32, 0.17, 0.15);
uniform float fade_start = 90.0;
uniform float fade_length = 380.0;

varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 local_normal;
varying vec4 tint;
varying vec4 info;

float hash(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 13.7) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * scale;
	local_normal = NORMAL;
	tint = COLOR;
	info = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 n = abs(local_normal);
	float roof = step(0.7, n.y);
	float cell_w = max(info.w, 0.01);
	float u = (n.x > n.z ? local_pos.z : local_pos.x) + info.z * 7.0;
	vec2 cell = vec2(u / cell_w, world_pos.y / (cell_w * 1.15));
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float side = n.x > n.z ? 1.0 : 0.0;
	float h = hash(id + vec2(side * 31.0, 0.0), info.z);
	float win = step(0.5, info.w) * step(0.2, f.x) * step(f.x, 0.8) * step(0.3, f.y) * step(f.y, 0.82) * step(1.0, id.y);
	// Every fourth row a cornice band breaks the grid (one city's floors).
	float band = step(0.5, info.w) * step(3.0, mod(id.y, 4.0)) * step(f.y, 0.14);
	float grain = hash(floor(vec2(u, world_pos.y) * 1.1), 3.0);
	vec3 wall = tint.rgb * (0.84 + 0.16 * grain) * mix(0.6, 1.0, smoothstep(0.0, 6.0, world_pos.y));
	wall *= 1.0 - band * 0.35;
	float burning = step(1.0 - info.y, h);
	wall *= 1.0 - burning * step(0.82, f.y) * 0.65;
	vec3 col = mix(wall, window_dark, win);
	vec3 glow = vec3(0.0);
	if (win > 0.5) {
		if (burning > 0.5) {
			glow = fire_color * (1.4 + 0.6 * sin(TIME * 3.0 + h * 50.0)) * (0.45 + 0.55 * (1.0 - f.y));
		} else if (h < info.x) {
			glow = mix(window_lit, window_cold, step(0.8, hash(id, info.z + 5.0))) * (0.6 + 0.4 * hash(id, 9.0));
		}
	}
	col = mix(col, tint.rgb * 0.3, roof);
	glow *= 1.0 - roof;
	float fade = clamp((length(world_pos - CAMERA_POSITION_WORLD) - fade_start) / fade_length, 0.0, 0.8);
	ALBEDO = mix(col, haze_color, fade);
	EMISSION = glow * (1.0 - fade * 0.4) + haze_color * fade * 0.55;
	ROUGHNESS = 0.9;
}
