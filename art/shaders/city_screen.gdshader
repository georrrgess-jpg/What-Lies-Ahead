shader_type spatial;
render_mode unshaded, shadows_disabled;

// Ashfall City video screens and TVs left running (one MultiMesh of quads,
// UV 0..1). Each screen loops its own programme, seeded by INSTANCE_CUSTOM.x:
// the emergency alert (a warning sign over a scrolling ticker), an ad from the
// ads sheet, colour bars, then static; the signal tears and rolls now and then.
uniform sampler2D ads : source_color, filter_linear_mipmap;
uniform float strength = 1.6;
// The ads sheet's grid (columns, rows).
uniform vec2 cells = vec2(4.0, 8.0);

varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	seed = INSTANCE_CUSTOM.x;
}

vec3 alert(vec2 uv, float t) {
	vec3 col = mix(vec3(0.35, 0.02, 0.02), vec3(0.75, 0.05, 0.03), step(0.5, fract(t * 1.2)));
	// A warning triangle with a "!" in it.
	vec2 p = (uv - vec2(0.5, 0.42)) * vec2(1.6, 1.0);
	float tri = step(abs(p.x) * 1.7, p.y + 0.3) * step(p.y, 0.3);
	tri *= step(0.0, 0.3 - p.y);
	float bang = step(abs(p.x), 0.03) * step(-0.12, p.y) * step(p.y, 0.14);
	bang += step(length(p - vec2(0.0, 0.21)), 0.035);
	col = mix(col, vec3(1.0, 0.8, 0.1), tri);
	col = mix(col, vec3(0.05), tri * min(bang, 1.0));
	// The ticker: a white band with dashes of "text" crawling left.
	float band = step(0.82, uv.y) * step(uv.y, 0.95);
	float word = step(0.35, hash(vec2(floor(uv.x * 26.0 + t * 6.0), 3.0)));
	float glyph = step(0.25, fract(uv.x * 26.0 + t * 6.0)) * step(0.85, uv.y) * step(uv.y, 0.92);
	col = mix(col, vec3(0.92), band);
	col = mix(col, vec3(0.08), band * glyph * word);
	return col;
}

vec3 bars(vec2 uv) {
	float i = floor(uv.x * 7.0);
	vec3 c = vec3(i < 4.0 ? 0.8 : 0.0, (i < 2.0 || (i > 3.0 && i < 6.0)) ? 0.8 : 0.0, mod(i, 2.0) < 0.5 ? 0.8 : 0.0);
	return mix(c, vec3(0.05, 0.05, 0.12), step(0.75, uv.y));
}

void fragment() {
	float t = TIME + seed * 37.0;
	vec2 uv = UV;
	// Tearing: in bursts the rows slide sideways; a dark bar rolls down.
	float burst = step(0.82, fract(t * 0.21 + seed));
	float row = floor(uv.y * 24.0);
	uv.x += (hash(vec2(row, floor(t * 14.0))) - 0.5) * 0.22 * burst;
	float programme = mod(floor(t / 4.0), 4.0);
	vec3 col;
	if (programme < 0.5) {
		col = alert(uv, t);
	} else if (programme < 1.5) {
		float cell = floor(seed * 29.0 + floor(t / 16.0) * 3.0);
		vec2 c = vec2(mod(cell, cells.x), mod(floor(cell / cells.x), cells.y));
		col = texture(ads, (c + clamp(uv, 0.01, 0.99)) / cells).rgb;
	} else if (programme < 2.5) {
		col = bars(uv);
	} else {
		col = vec3(hash(floor(uv * vec2(160.0, 90.0)) + fract(t * 23.0)) * 0.8);
	}
	// Static between programmes, scanlines, a rolling bar, the tube's vignette.
	float edge = fract(t / 4.0);
	float snow = step(edge, 0.06) + burst * 0.25;
	col = mix(col, vec3(hash(floor(uv * vec2(120.0, 68.0)) + floor(t * 30.0) * 0.1)), clamp(snow, 0.0, 1.0));
	col *= 0.82 + 0.18 * sin(UV.y * 260.0);
	col *= 1.0 - 0.35 * smoothstep(0.0, 0.08, 0.08 - abs(fract(UV.y - t * 0.15) - 0.5));
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 1.2;
	ALBEDO = col * strength;
}
