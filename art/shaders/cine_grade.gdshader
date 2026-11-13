shader_type canvas_item;
render_mode unshaded;
// The showreel's lens and colour grade (CineOverlay.grade), drawn over the 3D
// frame and under the titles. One full-screen pass:
//   grade     lift (added to the shadows), gain (multiplies the highlights),
//             contrast, saturation and a vignette: one look per act
//   defocus   a fake shallow depth of field: the frame blurs with distance
//             from `focus` beyond `focus_radius` (rack focus = tween these)
//   smear     a directional motion blur for whip pans (uv span)
//   flare     an anamorphic streak and halo at `flare_pos` (the sun, a muzzle)
// The blurs only sample when they are switched on.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float vignette = 0.0;
uniform vec2 aspect = vec2(1.7778, 1.0);
uniform vec2 focus = vec2(0.5, 0.5);
uniform float focus_radius = 0.3;
uniform float defocus = 0.0;
uniform vec2 smear = vec2(0.0);
uniform vec2 flare_pos = vec2(0.5, 0.5);
uniform vec4 flare_color = vec4(1.0, 0.7, 0.45, 0.0);

const float GOLDEN = 2.39996;

vec3 blurred(vec2 uv, float radius) {
	vec3 sum = texture(screen_tex, uv).rgb;
	for (int i = 1; i < 12; i++) {
		float r = sqrt(float(i) / 11.0) * radius;
		float a = float(i) * GOLDEN;
		sum += texture(screen_tex, uv + vec2(cos(a), sin(a)) * r / aspect).rgb;
	}
	return sum / 12.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	float blur = 0.0;
	if (defocus > 0.0) {
		vec2 d = (uv - focus) * aspect;
		blur = smoothstep(focus_radius, focus_radius + 0.35, length(d)) * defocus;
	}
	if (dot(smear, smear) > 0.0) {
		col = vec3(0.0);
		for (int i = 0; i < 10; i++) {
			col += texture(screen_tex, uv + smear * (float(i) / 9.0 - 0.5)).rgb;
		}
		col /= 10.0;
	} else if (blur > 0.0005) {
		col = blurred(uv, blur);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = clamp(col, 0.0, 1.0);
	col = col * gain + lift * (1.0 - col);
	if (flare_color.a > 0.0) {
		vec2 d = (uv - flare_pos) * aspect;
		float streak = exp(-abs(d.y) * 160.0) * exp(-abs(d.x) * 2.2);
		float halo = exp(-length(d) * 7.0);
		col += flare_color.rgb * flare_color.a * (streak * 0.9 + halo * 0.55);
	}
	vec2 v = (uv - 0.5) * aspect / aspect.x * 2.0;
	col *= 1.0 - vignette * smoothstep(0.35, 1.25, length(v * vec2(1.0, 1.3)));
	COLOR = vec4(col, 1.0);
}
