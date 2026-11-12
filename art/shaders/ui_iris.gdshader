shader_type canvas_item;
// Portal iris used to open the menu after the intro: everything outside a
// growing circle is the intro (drawn by this rect's colour); inside is see-
// through. A glowing ring rides the edge.
uniform float radius = 0.0;          // in screen heights
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec4 ring_color : source_color = vec4(0.25, 0.95, 1.0, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	float d = length(p);
	float inside = smoothstep(radius - 0.004, radius + 0.004, d);
	float ring = smoothstep(0.035, 0.0, abs(d - radius)) * step(0.001, radius);
	COLOR = vec4(mix(COLOR.rgb, ring_color.rgb, ring), max(COLOR.a * inside, ring));
}
