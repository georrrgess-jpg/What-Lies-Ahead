shader_type spatial;
render_mode cull_back;

// Launch-pad apron for Dune Spaceport: sun-bleached concrete slabs with sand
// drifting over them. Everything is mapped in world XZ, so any box or plane
// can use it. Drifts gather where `sand_amount` is high, toward the arena edges
// (beyond `clear_radius` from `clear_center`) and along the wind direction.
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile_metres = 8.0;
uniform float sand_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec2 clear_center = vec2(0.0, 0.0);
uniform float clear_radius = 18.0;
uniform float edge_fade = 22.0;
uniform vec2 wind = vec2(0.8, 0.6);
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = p / tile_metres;
	vec3 conc = texture(concrete_tex, uv).rgb;
	vec3 sand = texture(sand_tex, uv * 0.75 + vec2(0.37, 0.11)).rgb;
	// Drift mask: large soft noise stretched along the wind, more sand at the edges.
	vec2 w = normalize(wind);
	vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	float n1 = texture(noise_tex, q * vec2(0.012, 0.03)).r;
	float n2 = texture(noise_tex, q * vec2(0.05, 0.11) + 0.3).g;
	float edge = smoothstep(clear_radius, clear_radius + edge_fade, length(p - clear_center));
	float drift = n1 * 0.75 + n2 * 0.35 + sand_amount * 0.9 + edge * 0.55 - 0.92;
	float m = smoothstep(0.0, 0.16, drift);
	// A thin dusting even where no drift sits.
	float dust = smoothstep(0.35, 0.8, n2) * 0.18;
	vec3 col = mix(conc, sand, clamp(m + dust, 0.0, 1.0));
	// Darker damp-looking rim where sand thins out over the slab.
	col *= 1.0 - 0.08 * smoothstep(0.0, 0.05, drift) * (1.0 - smoothstep(0.05, 0.16, drift));
	ALBEDO = col * tint;
	vec3 nc = texture(concrete_normal, uv).rgb;
	vec3 ns = texture(sand_normal, uv * 0.75 + vec2(0.37, 0.11)).rgb;
	NORMAL_MAP = mix(nc, ns, m);
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = mix(0.82, 0.95, m);
	SPECULAR = 0.3;
}
