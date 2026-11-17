shader_type spatial;

// The gutted rooms behind the kit facades' windows (the backdrop wall a few
// metres in): near-black plaster, but room by room some still glow: a warm
// lamp, a cold TV flicker, a fire burning itself out. Cells are rooms
// (metres across, up) in world space, so a lit room shows through whichever
// windows of the shell sit in front of it.
uniform vec3 plaster : source_color = vec3(0.07, 0.055, 0.06);
uniform vec3 ember : source_color = vec3(0.16, 0.07, 0.04);
uniform vec3 lamp : source_color = vec3(1.0, 0.68, 0.36);
uniform vec3 screen : source_color = vec3(0.45, 0.65, 1.0);
uniform vec3 fire : source_color = vec3(1.0, 0.38, 0.1);
uniform vec2 room_size = vec2(4.5, 3.6);
uniform float lit_fraction = 0.12;
uniform float tv_fraction = 0.05;
uniform float fire_fraction = 0.05;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	float u = n.x > n.z ? world_pos.z + 50.0 * sign(world_pos.x) : world_pos.x + 50.0 * sign(world_pos.z);
	vec2 cell = vec2(u, world_pos.y) / room_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float h = hash(id);
	// Light falls off from the room's middle and pools toward its floor.
	float spot = (1.0 - smoothstep(0.05, 0.45, abs(f.x - 0.5))) * mix(1.0, 0.4, f.y);
	vec3 glow = ember * 0.25;
	if (h < lit_fraction) {
		glow = lamp * (0.22 + 0.28 * hash(id + 3.1)) * spot;
	} else if (h < lit_fraction + tv_fraction) {
		float flick = 0.6 + 0.4 * step(0.5, fract(sin(floor(TIME * 7.0 + h * 40.0)) * 91.7));
		glow = screen * 0.4 * flick * spot;
	} else if (h > 1.0 - fire_fraction) {
		float flame = 0.75 + 0.25 * sin(TIME * 9.0 + h * 60.0) * sin(TIME * 3.3 + h * 17.0);
		glow = fire * 0.9 * flame * (1.0 - smoothstep(0.0, 0.9, f.y)) * (0.4 + 0.6 * spot);
	}
	ALBEDO = plaster;
	ROUGHNESS = 1.0;
	EMISSION = glow;
}
