shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// The rotunda dome, painted like the view up through the sea: a deep navy rim
// that brightens to a glowing teal "surface" at the crown, with caustic
// ripples projected as if onto a plane far overhead and slow drifting light
// shafts. Expects a hemisphere mesh centred on its origin.
uniform sampler2D caustic_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 rim_color : source_color = vec3(0.02, 0.05, 0.13);
uniform vec3 mid_color : source_color = vec3(0.03, 0.2, 0.36);
uniform vec3 crown_color : source_color = vec3(0.25, 0.85, 0.95);
uniform vec3 caustic_color : source_color = vec3(0.55, 1.0, 1.0);
uniform float caustic_strength = 0.6;
uniform float brightness = 1.0;
// Rib pattern: number of dome ribs (0 = none).
uniform float ribs = 16.0;
// Vertical squash applied to the mesh (so the pattern stays round).
uniform float squash = 1.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec3 d = normalize(vec3(lpos.x, lpos.y / max(0.05, squash), lpos.z));
	float elev = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(rim_color, mid_color, smoothstep(0.0, 0.55, elev));
	col = mix(col, crown_color, smoothstep(0.6, 1.0, elev) * 0.85);
	// Caustics on an imaginary surface overhead.
	vec2 uv = d.xz / (d.y + 0.35) * 1.6;
	float t = TIME * 0.03;
	float a = texture(caustic_tex, uv + vec2(t, t * 0.7)).r;
	float b = texture(caustic_tex, uv * 1.27 + vec2(-t * 0.9, t * 0.4) + 0.4).r;
	float c = pow(min(a, b) * 1.7, 1.4);
	col += caustic_color * c * caustic_strength * smoothstep(0.15, 0.85, elev);
	// Soft rays fanning out from the crown.
	float ang = atan(d.z, d.x);
	float fan = 0.5 + 0.5 * sin(ang * 9.0 + TIME * 0.15) * sin(ang * 5.0 - TIME * 0.11);
	col += crown_color * fan * 0.12 * smoothstep(0.3, 0.9, elev);
	// Structural ribs, dark against the glow.
	if (ribs > 0.0) {
		float r = abs(fract(ang / 6.2831853 * ribs) - 0.5);
		float rib = smoothstep(0.035, 0.015, r) * smoothstep(0.97, 0.75, elev);
		col = mix(col, rim_color * 0.6, rib * 0.85);
		float ring = abs(fract(elev * 4.0) - 0.5);
		col = mix(col, rim_color * 0.7, smoothstep(0.03, 0.012, ring) * 0.6 * step(elev, 0.9));
	}
	ALBEDO = col * brightness;
}
