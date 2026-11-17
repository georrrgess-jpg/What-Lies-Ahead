shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The war still going on beyond the city (one MultiMesh, far off on the
// horizon): streams of tracer fire stuttering up into the smoke and flares
// drifting down under their parachutes. INSTANCE_CUSTOM: x phase (0..1),
// y period (s), z mode (0 tracer stream: a quad along local +Y; 1 flare: a
// round glow), w how far a flare falls (m). The instance colour is the light.
uniform float strength = 2.4;

varying vec4 cfg;
varying vec3 light;
varying float life;

void vertex() {
	cfg = INSTANCE_CUSTOM;
	light = COLOR.rgb;
	float t = fract(TIME / cfg.y + cfg.x);
	life = t;
	if (cfg.z > 0.5) {
		// Flares sink and sway.
		VERTEX.y -= t * cfg.w / max(MODEL_MATRIX[1].y, 0.001);
		VERTEX.x += sin(TIME * 0.7 + cfg.x * 20.0) * 0.4;
	}
}

void fragment() {
	float a;
	if (cfg.z < 0.5) {
		// Short bursts in the first part of each period; dashes run up the stream.
		float firing = step(life, 0.45) * step(0.04, fract(life * 9.0));
		float dash = step(0.7, fract(UV.y * 9.0 + TIME * 4.5 + cfg.x * 3.0));
		float core = 1.0 - abs(UV.x - 0.5) * 2.0;
		a = firing * dash * core * (0.3 + 0.7 * UV.y);
	} else {
		float r = length(UV - 0.5) * 2.0;
		float burn = smoothstep(0.0, 0.03, life) * smoothstep(1.0, 0.75, life);
		float flick = 0.8 + 0.2 * sin(TIME * 23.0 + cfg.x * 50.0);
		a = (smoothstep(1.0, 0.0, r) * 0.35 + smoothstep(0.25, 0.0, r)) * burn * flick;
	}
	ALBEDO = light * a * strength;
}
