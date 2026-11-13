shader_type spatial;
render_mode cull_disabled;
// Melted chocolate for the Candy Works river and waterfall: a swirl texture
// (R height, G sheen) scrolled along the flow, two layers drifting at
// different speeds, glossy highlights where the sheen gathers.

uniform sampler2D swirl : filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.24, 0.12, 0.07, 1.0);
uniform vec4 milk_color : source_color = vec4(0.55, 0.3, 0.17, 1.0);
uniform vec2 flow = vec2(0.12, 0.0);   // UV per second
uniform float scale = 0.18;            // texture repeats per metre (world UV)
uniform bool world_uv = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 base = world_uv ? world_pos.xz * scale : UV;
	vec4 a = texture(swirl, base + flow * TIME);
	vec4 b = texture(swirl, base * 1.7 + vec2(0.37, 0.11) + flow * TIME * 1.6);
	float h = a.r * 0.6 + b.r * 0.4;
	float sheen = max(a.g, b.g * 0.8);
	ALBEDO = mix(deep_color.rgb, milk_color.rgb, smoothstep(0.25, 0.85, h));
	ROUGHNESS = mix(0.32, 0.08, sheen);
	SPECULAR = 0.7;
	EMISSION = milk_color.rgb * sheen * 0.12;
}
