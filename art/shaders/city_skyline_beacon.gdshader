shader_type spatial;
render_mode unshaded, fog_disabled;

// Red aircraft-warning beacons on the skyline's spires, cranes and bridge
// (tools/city/city_skyline.gd): each blinks on its own phase
// (INSTANCE_CUSTOM.r), a slow beat like the Broadcast Tower's. With `steady`
// it is the roofs' neon trim instead: always on, in the instance colour.
uniform vec3 beacon_color : source_color = vec3(1.0, 0.08, 0.05);
uniform float period = 1.8;
uniform float steady = 0.0;

varying float phase;
varying vec3 tint;

void vertex() {
	phase = INSTANCE_CUSTOM.r;
	tint = COLOR.rgb;
}

void fragment() {
	float t = fract(TIME / period + phase);
	float on = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.35, 0.5, t));
	ALBEDO = mix(beacon_color * (0.15 + 3.5 * on), tint * 2.6, steady);
}
