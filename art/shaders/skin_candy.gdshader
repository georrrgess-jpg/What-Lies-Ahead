shader_type spatial;
// Weapon finish "Candy Stripes": glossy twisted stripes that wind around the
// weapon like a candy cane and creep slowly. `rainbow` cycles the stripe hue.
uniform vec3 shell_color : source_color = vec3(1.0, 0.97, 0.95);
uniform vec3 trim_color : source_color = vec3(0.92, 0.12, 0.25);
uniform bool is_trim = false;
uniform float stripes = 26.0;
uniform float speed = 0.12;
uniform bool rainbow = false;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hue(float t) {
	return clamp(abs(fract(t + vec3(0.0, 0.667, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	// The barrel runs along Z; twist the stripes around it.
	float around = atan(lp.x, lp.y) / 6.28318;
	float s = lp.z * stripes + around * 3.0 + lp.y * stripes * 0.6 + TIME * speed;
	float f = fract(s);
	float band = smoothstep(0.46, 0.5, f) * smoothstep(0.96, 0.92, f);
	vec3 stripe = rainbow ? mix(hue(floor(s) * 0.13 + TIME * 0.05), vec3(1.0), 0.15) : trim_color;
	vec3 base = is_trim ? mix(trim_color, shell_color, 0.25) : shell_color;
	ALBEDO = mix(base, stripe, band);
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0) * fres * 0.18;
}
