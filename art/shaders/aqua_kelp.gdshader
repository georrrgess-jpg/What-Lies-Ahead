shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Swaying kelp (and anemone tentacles, sea grass). The bend grows with height
// above the mesh origin, so the holdfast stays planted while the tips drift in
// a slow current, with a faster flutter on top. Each instance gets its own
// phase from its world position.
uniform vec3 albedo : source_color = vec3(0.3, 0.6, 0.2);
uniform vec3 tip_color : source_color = vec3(0.7, 0.85, 0.3);
uniform float height = 5.0;
uniform float sway = 0.6;
uniform float speed = 0.6;
uniform vec2 current = vec2(1.0, 0.35);
uniform float roughness = 0.6;
uniform float translucency = 0.35;

varying float hk;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = origin.x * 0.73 + origin.z * 1.31;
	float k = clamp(VERTEX.y / height, 0.0, 1.0);
	hk = k;
	float bend = pow(k, 1.6);
	float t = TIME * speed + ph;
	vec2 d = normalize(current);
	float main = sin(t) * 0.7 + sin(t * 0.43 + 1.3) * 0.5;
	float flutter = sin(TIME * speed * 3.1 + ph * 2.0 + VERTEX.y * 1.7) * 0.18;
	float off = (main + flutter) * sway * bend;
	VERTEX.x += d.x * off;
	VERTEX.z += d.y * off + cos(t * 0.8) * sway * 0.35 * bend;
}

void fragment() {
	vec3 col = mix(albedo, tip_color, smoothstep(0.3, 1.0, hk));
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	// Back-lit look: leaves glow a little, more toward the light at the top.
	EMISSION = col * translucency * (0.3 + hk * 0.7);
}
