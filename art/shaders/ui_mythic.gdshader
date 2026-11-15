shader_type canvas_item;
// The Mythic rarity's treatment in the UI (scripts/ui/kit/mythic_fx.gd): a
// slow red-to-gold flow with a white-hot glint sweeping across every few
// seconds and a few twinkling sparks, so Mythic reads above Legendary's
// flat gold. Works on any canvas item: a ColorRect, a stylebox plate, or
// text (dark pixels such as lettering shadows and ink keep their colour).
uniform vec3 red : source_color = vec3(1.0, 0.16, 0.26);
uniform vec3 gold : source_color = vec3(1.0, 0.76, 0.24);
uniform float speed = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	float flow = 0.5 + 0.5 * sin((px.x + px.y * 0.5) * 0.018 - TIME * speed * 3.0);
	vec3 col = mix(red, gold, smoothstep(0.15, 0.85, flow));
	float glint = exp(-pow(fract((px.x - px.y * 0.35) * 0.0016 - TIME * 0.22) * 8.0 - 4.0, 2.0) * 2.5);
	vec2 cell = floor(px / 7.0);
	float spark = step(0.97, hash(cell)) * pow(0.5 + 0.5 * sin(TIME * 5.0 + hash(cell + 3.1) * 40.0), 8.0);
	col = mix(col, vec3(1.0, 0.97, 0.88), clamp(glint * 0.75 + spark, 0.0, 1.0));
	float lum = dot(COLOR.rgb, vec3(0.3, 0.55, 0.15));
	COLOR.rgb = mix(COLOR.rgb, col, smoothstep(0.22, 0.32, lum));
}
