shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Glowing jellyfish drifting in the column tanks. MultiMesh: the instance
// transform places the jelly; INSTANCE_CUSTOM = (drift radius, rise amplitude,
// speed, phase). The bell (above the origin) pulses, the tentacles (below)
// trail and ripple, and the whole jelly bobs up and down on its own beat.
// Opaque but strongly emissive with a bright fresnel rim, so it reads as
// translucent and still shows through the water-glass shader.
uniform vec3 albedo : source_color = vec3(1.0, 0.45, 0.8);
uniform vec3 glow : source_color = vec3(1.0, 0.4, 0.85);
uniform float glow_energy = 1.6;
uniform float pulse_speed = 1.6;

varying float bell;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = TIME * c.z + c.w;
	float beat = TIME * pulse_speed * (0.8 + c.z) + c.w * 4.0;
	float squeeze = pow(0.5 + 0.5 * sin(beat), 3.0);
	bell = step(0.0, VERTEX.y);
	if (VERTEX.y > 0.0) {
		VERTEX.xz *= 1.0 - squeeze * 0.18 * smoothstep(0.0, 0.25, VERTEX.y);
		VERTEX.y *= 1.0 + squeeze * 0.12;
	} else {
		float k = -VERTEX.y;
		VERTEX.x += sin(beat * 0.7 + k * 5.0) * 0.06 * k;
		VERTEX.z += cos(beat * 0.6 + k * 4.0) * 0.06 * k;
	}
	float sc = max(0.001, length(MODEL_MATRIX[0].xyz));
	vec3 drift = vec3(cos(t * 0.3) * c.x, sin(t * 0.5) * c.y + squeeze * 0.05, sin(t * 0.3) * c.x);
	VERTEX += drift / sc;
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = albedo * 0.35;
	ROUGHNESS = 0.2;
	EMISSION = glow * glow_energy * (0.35 + fres * 1.4) * mix(0.8, 1.0, bell);
}
