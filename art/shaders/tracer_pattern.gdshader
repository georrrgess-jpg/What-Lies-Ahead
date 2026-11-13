shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Pattern tracers (scripts/cosmetics/tracer_styles.gd). One shared unit mesh
// (z = UV.y from 0 at the muzzle to 1 at the target, x/y across, UV.x across
// or round the tube) is stretched along the shot; the pattern is laid out
// here in metres, so no mesh is built per shot.
//   0 gift ribbon   1 morse code   2 heartbeat   3 laser fence
//   4 neon tube     5 ticket roll  6 chevrons    7 candy stripe
// Normal (mix) blending with a light core and a darker rim keeps the colour
// readable against bright skies.
uniform int style = 0;
uniform vec4 color_a : source_color = vec4(1.0, 0.3, 0.6, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Per shot (StyledTracer): length in metres, how much has shot out (0-1),
// the fade (0 opaque, 1 gone), seconds since the shot and a random seed.
instance uniform float length_m = 10.0;
instance uniform float shown = 1.0;
instance uniform float fade = 0.0;
instance uniform float age = 0.0;
instance uniform float seed = 0.0;

varying float v_along;
varying float v_shade;

const float MORSE_UNIT = 0.3;

// The ECG trace: a small bump, the sharp spike and a slow wave every 4 m.
float heartbeat(float a) {
	float x = mod(a + seed * 4.0, 4.0);
	float h = 0.05 * sin(clamp((x - 0.6) / 0.4, 0.0, 1.0) * 3.14159);
	h += mix(0.0, -0.08, clamp((x - 1.55) / 0.12, 0.0, 1.0));
	h += mix(0.0, 0.58, clamp((x - 1.67) / 0.12, 0.0, 1.0)) - mix(0.0, 0.73, clamp((x - 1.79) / 0.14, 0.0, 1.0));
	h += mix(0.0, 0.23, clamp((x - 1.93) / 0.12, 0.0, 1.0));
	h += 0.12 * sin(clamp((x - 2.6) / 0.6, 0.0, 1.0) * 3.14159);
	return h;
}

// Distance (in dot radii) to the nearest mark of "P O P" in Morse, repeating.
float morse(float x, float u) {
	// Runs as (start, length) in units: P .--.  O ---  P .--.  then a word gap.
	vec2 runs[11] = vec2[11](vec2(0.0, 1.0), vec2(2.0, 3.0), vec2(6.0, 3.0), vec2(10.0, 1.0), vec2(14.0, 3.0), vec2(18.0, 3.0),
		vec2(22.0, 3.0), vec2(28.0, 1.0), vec2(30.0, 3.0), vec2(34.0, 3.0), vec2(38.0, 1.0));
	float d = 99.0;
	for (int i = 0; i < 11; i++) {
		float mid = runs[i].x + runs[i].y * 0.5;
		float half_seg = runs[i].y * 0.5 - 0.5;
		d = min(d, length(vec2(max(abs(x - mid) - half_seg, 0.0) * 2.0, u)));
	}
	return d;
}

void vertex() {
	v_along = UV.y * length_m;
	float width_m = length(MODEL_MATRIX[0].xyz);
	// The pattern opens up over the first metres so it never fills the screen.
	VERTEX.xy *= 0.3 + 0.7 * clamp(v_along / 3.0, 0.0, 1.0);
	if (style == 0 || style == 5) {
		float twist = (style == 0 ? 1.2 : 0.3) * v_along + seed * 6.28;
		float c = cos(twist);
		float s = sin(twist);
		VERTEX.xy = vec2(c * VERTEX.x - s * VERTEX.y, s * VERTEX.x + c * VERTEX.y);
		v_shade = 0.72 + 0.28 * abs(c);
	} else if (style == 2) {
		// Flat at the muzzle, full height from about 6 m out.
		VERTEX.y += heartbeat(v_along) * clamp((v_along - 1.0) / 5.0, 0.0, 1.0) / max(width_m, 0.001);
		v_shade = 1.0;
	} else {
		// Round the tube: lit from above.
		v_shade = 0.7 + 0.3 * normalize(VERTEX.xy + vec2(0.0001)).y;
	}
}

void fragment() {
	if (v_along > shown * length_m) {
		discard;
	}
	float u = UV.x * 2.0 - 1.0;
	float au = abs(u);
	vec3 col = color_a.rgb;
	float alpha = 1.0;
	float t = TIME + seed * 10.0;
	if (style == 0) {
		col = (FRONT_FACING ? color_a.rgb : color_b.rgb) * v_shade;
		col = mix(col, vec3(1.0), smoothstep(0.12, 0.0, abs(u - 0.35)) * 0.45);
		col *= 1.0 - 0.35 * smoothstep(0.8, 1.0, au);
	} else if (style == 1) {
		float d = morse(mod(v_along / MORSE_UNIT - t * 70.0, 46.0), u);
		col = mix(color_a.rgb * 0.45, mix(color_a.rgb, color_b.rgb, 0.35), smoothstep(1.0, 0.75, d));
		alpha = smoothstep(1.15, 0.95, d);
	} else if (style == 2) {
		float blip = mod(t * 55.0, length_m + 12.0) - 6.0;
		float glow = exp(-abs(v_along - blip) * 1.2);
		col = mix(color_a.rgb, vec3(1.0), smoothstep(0.5, 0.0, au) * 0.55 + glow * 0.6);
		alpha = smoothstep(1.0, 0.4, au);
	} else if (style == 3) {
		float rail = smoothstep(0.74, 0.84, au);
		float rung = step(fract((v_along - t * 14.0) / 0.55), 0.13);
		col = mix(color_b.rgb, color_a.rgb, rail);
		col = mix(col, vec3(1.0), smoothstep(0.86, 0.8, au) * rail * 0.4);
		alpha = max(rail, rung * 0.9);
		alpha = max(alpha, 0.12);
		col *= 1.0 - 0.4 * smoothstep(0.95, 1.0, au);
	} else if (style == 4) {
		float core = smoothstep(0.4, 0.0, au);
		col = mix(color_a.rgb, mix(color_a.rgb, vec3(1.0), 0.85), core);
		alpha = smoothstep(1.0, 0.55, au) * 0.95 + 0.05;
		// The tube strikes on with a flicker, like a neon sign.
		if (age < 0.07) {
			alpha *= step(0.45, fract(sin(floor(t * 60.0) * 12.9898) * 43758.5453));
		}
	} else if (style == 5) {
		float x = mod(v_along, 0.9);
		float y = u * 0.18;
		col = color_a.rgb;
		float border = max(step(0.8, au), max(step(x, 0.06), step(0.84, x)));
		col = mix(col, color_b.rgb, border);
		vec2 sp = vec2(x - 0.45, y);
		float ang = atan(sp.y, sp.x);
		float star = step(length(sp), 0.075 * (0.62 + 0.38 * cos(5.0 * ang + 1.5708)));
		col = mix(col, color_b.rgb, star);
		float bars = (step(0.14, x) - step(0.3, x) + step(0.6, x) - step(0.76, x)) * step(abs(y), 0.06) * step(0.012, abs(y));
		col = mix(col, color_a.rgb * 0.62, bars);
		// Perforations between tickets.
		alpha = 1.0 - step(x, 0.018) * step(0.45, fract(u * 4.0));
		col *= FRONT_FACING ? v_shade : v_shade * 0.82;
	} else if (style == 6) {
		float f = fract((v_along + au * 0.35 - t * 24.0) / 0.7);
		float on = smoothstep(0.5, 0.53, f) * smoothstep(0.88, 0.85, f);
		col = mix(color_a.rgb * 0.55, mix(color_a.rgb, color_b.rgb, smoothstep(0.75, 0.86, f)), on);
		alpha = max(on, smoothstep(0.2, 0.0, au) * 0.35);
	} else {
		float stripe = step(0.5, fract(UV.x * 2.0 + v_along * 1.4 - t * 3.0));
		col = mix(color_a.rgb, color_b.rgb, stripe) * v_shade;
	}
	ALBEDO = col;
	ALPHA = alpha * (1.0 - fade);
}
