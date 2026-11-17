shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Ashfall City cloth in the wind (one MultiMesh of subdivided quads): flags
// on roof poles, banners down the facades, tarps and laundry on the lines.
// The quad runs x 0..1 from the pinned edge, y 0..-1 down from the top.
// INSTANCE_CUSTOM: x phase (0..1), y mode (0 = flag pinned at its pole edge,
// 1 = hanging cloth pinned along its top), z flap (metres at the free edge),
// w pattern (0 plain, 1 three stripes, 2 hazard chevrons, 3 red cross on
// white). The instance colour tints it; the free edge is torn and singed.
uniform float speed = 3.4;
uniform float tear = 0.22;

varying float pin_dist;
varying vec4 cfg;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	cfg = INSTANCE_CUSTOM;
	float hang = step(0.5, cfg.y);
	float d = mix(UV.x, UV.y, hang);
	float across = mix(UV.y, UV.x, hang);
	float ph = cfg.x * 6.2832;
	float gust = 0.75 + 0.25 * sin(TIME * 0.4 + ph);
	float w = TIME * speed * (1.0 - 0.3 * hang) - d * 5.0 + across * 1.3 + ph;
	float amp = cfg.z * gust * d;
	float z = amp * sin(w);
	// d/dd of the wave, for a normal that catches the light in the folds.
	float slope = cfg.z * gust * (sin(w) - d * 5.0 * cos(w));
	VERTEX.z += z;
	// A flag droops a little at its free end when the gust drops.
	VERTEX.y -= (1.0 - hang) * d * d * 0.12 * (1.0 - gust);
	NORMAL = normalize(mix(vec3(-slope, 0.0, 1.0), vec3(0.0, slope, 1.0), hang));
	pin_dist = d;
}

void fragment() {
	float hang = step(0.5, cfg.y);
	float across = mix(UV.y, UV.x, hang);
	// Torn free edge: ragged strips of different lengths.
	float rag = hash(floor(across * 9.0) + cfg.x * 31.0);
	if (pin_dist > 1.0 - tear * rag) {
		discard;
	}
	vec3 base = COLOR.rgb;
	float pattern = cfg.w;
	vec3 col = base;
	if (pattern > 0.5 && pattern < 1.5) {
		float band = floor(across * 3.0);
		col = band == 1.0 ? vec3(0.9, 0.88, 0.82) : (band == 2.0 ? base * 0.35 : base);
	} else if (pattern > 1.5 && pattern < 2.5) {
		float s = step(0.5, fract((UV.x + UV.y) * 3.0));
		col = mix(vec3(0.06, 0.05, 0.04), vec3(1.0, 0.62, 0.05), s);
	} else if (pattern > 2.5) {
		vec2 c = abs(UV - vec2(0.5));
		float cross = step(max(min(c.x, c.y), 0.0), 0.08) * step(max(c.x, c.y), 0.3);
		col = mix(vec3(0.92, 0.9, 0.86), vec3(0.85, 0.08, 0.06), cross);
	}
	// Soot creeping in from the torn edge.
	float soot = smoothstep(0.55, 1.0, pin_dist + rag * 0.15);
	col = mix(col, vec3(0.05, 0.04, 0.035), soot * 0.75);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.35;
}
