// Key art inside a world card (scripts/ui/world_card.gd): cropped to the
// card's rounded rectangle, shaded towards the card's backing colour along the
// bottom and left where the text sits, and greyed out while the world is locked.
// A card can draw its art wider than itself and slide it for parallax: `inset`
// is where the card's corner sits inside the art's rectangle. `sweep` (0-1)
// moves a light band across the card; `stripes` lays the locked hazard
// stripes over it.
shader_type canvas_item;

uniform vec2 rect_size = vec2(520.0, 280.0);
uniform vec2 inset = vec2(0.0, 0.0);
uniform float radius = 26.0;
uniform vec4 shade : source_color = vec4(0.1, 0.08, 0.27, 1.0);
uniform float shade_amount = 0.85;
uniform float saturation = 1.0;
uniform float sweep = -1.0;
uniform float stripes = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(grey), c.rgb, saturation);
	vec2 at = local - inset;
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(at - half_size) - (half_size - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float mask = clamp(0.5 - d, 0.0, 1.0);
	vec2 p = at / rect_size;
	// The text column (left) and the status line (bottom) sit on darker art.
	float g = smoothstep(0.3, 1.0, p.y) * 0.55 + smoothstep(0.9, 0.1, p.x) * 0.7;
	c.rgb = mix(c.rgb, shade.rgb, clamp(g, 0.0, 1.0) * shade_amount);
	if (stripes > 0.0) {
		float band = step(0.5, fract((at.x + at.y) / 46.0));
		c.rgb *= 1.0 - band * 0.22 * stripes;
	}
	if (sweep > -0.5) {
		// A slanted band of light travelling left to right.
		float x = p.x + (1.0 - p.y) * 0.35 - (sweep * 1.7 - 0.35);
		float light = smoothstep(0.12, 0.0, abs(x)) * 0.55;
		c.rgb += vec3(light);
	}
	COLOR = vec4(c.rgb, c.a * mask);
}
