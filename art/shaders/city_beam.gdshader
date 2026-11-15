shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A searchlight beam sweeping the smoke over Ashfall City: an open cone,
// brightest along its axis and near the lamp, fading up its length, with
// slow drifting smoke breaking it up. the lamp is at the narrow bottom.
uniform vec3 beam_color : source_color = vec3(0.75, 0.85, 1.0);
uniform float strength = 0.6;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// The side of a CylinderMesh spans UV.y 0 (top) to 0.5 (bottom).
	float along = clamp(UV.y * 2.0, 0.0, 1.0);
	// Edges of the cone face away from the eye: soft rim, solid core.
	float core = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float fade = pow(along, 1.4) * smoothstep(1.0, 0.96, along);
	float smoke = 0.6 + 0.4 * noise(vec2(UV.x * 18.0, along * 6.0 - TIME * 0.25));
	ALBEDO = beam_color * core * fade * smoke * strength;
}
