shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Spark bursts from a broken cable or a shorting lamp (scenes/props/city_sparks.tscn):
// one MultiMesh of thin quads. Every `interval` seconds a burst fires: each
// spark flies out on its own direction, falls under gravity and is drawn as a
// streak along its velocity. Bursts are seeded by the node's world position.
// The MultiMesh holds identical instances at the origin (scripts/props/city_sparks.gd).
uniform float interval = 2.6;
uniform float burst_time = 0.9;
uniform float spread_speed = 3.2;
uniform float gravity = 9.0;
uniform float width = 0.03;
uniform float streak = 0.12;
uniform vec3 hot_color : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 cool_color : source_color = vec3(1.0, 0.45, 0.1);
// 0..1: chance a burst is skipped, so a cable stutters irregularly.
uniform float skip = 0.35;

varying float life;
varying float alive;

float hash(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
}

void vertex() {
	// Every instance sits at the node origin; INSTANCE_ID picks its direction.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float node_seed = hash(dot(origin, vec3(1.3, 7.1, 3.7)));
	float id = float(INSTANCE_ID);
	float r = hash(id * 1.37 + 0.5);
	float a = hash(id * 3.11 + 1.7) * 6.2832;
	float up = hash(id * 5.73 + 2.9) * 1.2 - 0.2;
	vec3 dir = normalize(vec3(cos(a), up + 0.6, sin(a)));
	float t = TIME + node_seed * 30.0;
	float cycle = floor(t / interval);
	float local_t = t - cycle * interval - r * 0.15;
	alive = step(skip, hash(cycle + node_seed * 13.0)) * step(0.0, local_t) * step(local_t, burst_time * (0.5 + 0.5 * r));
	life = clamp(local_t / (burst_time * (0.5 + 0.5 * r)), 0.0, 1.0);
	vec3 vel = dir * spread_speed * (0.5 + r);
	float s = max(local_t, 0.0);
	vec3 p = origin + vel * s + vec3(0.0, -0.5 * gravity * s * s, 0.0);
	vec3 v = vel + vec3(0.0, -gravity * s, 0.0);
	vec4 view_pos = VIEW_MATRIX * vec4(p, 1.0);
	vec3 view_v = (VIEW_MATRIX * vec4(v, 0.0)).xyz;
	vec2 along = normalize(view_v.xy + vec2(1e-4, 0.0));
	vec2 side = vec2(-along.y, along.x);
	view_pos.xy += along * VERTEX.y * streak * length(v) * 0.5 + side * VERTEX.x * width;
	// Dead sparks collapse to a point outside the clip volume.
	POSITION = mix(vec4(0.0, 0.0, -10.0, 1.0), PROJECTION_MATRIX * view_pos, alive);
}

void fragment() {
	float edge = 1.0 - smoothstep(0.3, 1.0, abs(UV.x * 2.0 - 1.0));
	vec3 col = mix(hot_color, cool_color, life);
	ALBEDO = col * edge * (1.0 - life * 0.6) * 3.0;
}
