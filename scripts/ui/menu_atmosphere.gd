class_name MenuAtmosphere
extends Control
## Full-screen overlay that gives the menu depth and life: a soft vignette,
## a tinted gradient from the left (where the menu sits), drifting glowing
## motes, and faint scanlines rolling down. Accent colour follows the world.
## The motes and scanlines are one canvas shader: nothing runs per frame on
## the CPU and nothing is redrawn.

## Size of the grid the motes live in (canvas pixels); about half the cells hold one.
const CELL := 168.0

var accent := UiKit.PINK:
	set(v):
		accent = v
		if _motes:
			(_motes.material as ShaderMaterial).set_shader_parameter("accent", accent)
var _motes: ColorRect

static var _shader: Shader


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(UiKit.INK, 0.86), Color(UiKit.INK, 0.35), Color(UiKit.INK, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	add_child(_layer(gt))
	var v := Gradient.new()
	v.offsets = PackedFloat32Array([0.55, 1.0])
	v.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.04, 0.0, 0.1, 0.75)])
	var vt := GradientTexture2D.new()
	vt.gradient = v
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 1.15)
	vt.width = 256
	vt.height = 256
	add_child(_layer(vt))
	_motes = ColorRect.new()
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = _motes_shader()
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("warm", UiKit.AMBER)
	m.set_shader_parameter("cell", CELL)
	_motes.material = m
	add_child(_motes)
	resized.connect(_on_resized)
	_on_resized()


func _layer(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture = tex
	return r


func _on_resized() -> void:
	(_motes.material as ShaderMaterial).set_shader_parameter("canvas_size", size)


static func _motes_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
// Motes: one per grid cell (about half the cells), each column of cells
// rising at its own slow speed, swaying and twinkling. Scanlines: a 1 px
// dark line every 6 px, rolling down.
uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform float cell = 168.0;
uniform vec4 accent : source_color = vec4(1.0, 0.25, 0.64, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.76, 0.29, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * canvas_size;
	float column = floor(px.x / cell);
	float speed = mix(0.006, 0.018, hash(vec2(column, 3.7))) * canvas_size.y;
	vec2 q = vec2(px.x, px.y + TIME * speed);
	vec2 id = floor(q / cell);
	vec4 col = vec4(0.0);
	if (hash(id) < 0.55) {
		float ph = hash(id + 17.0) * 6.2832;
		vec2 at = (id + 0.2 + 0.6 * vec2(hash(id + 3.1), hash(id + 5.3))) * cell;
		at.x += sin(TIME * 0.6 + ph) * 12.0;
		float r = mix(1.5, 4.5, hash(id + 9.2));
		float d = distance(q, at);
		float a = 0.25 + 0.25 * sin(TIME * 1.7 + ph);
		vec3 c = hash(id + 11.9) < 0.5 ? warm.rgb : accent.rgb;
		float halo = (1.0 - smoothstep(r * 2.6 - 1.5, r * 2.6, d)) * a * 0.18;
		float core = (1.0 - smoothstep(r - 1.0, r + 0.5, d)) * a;
		col = vec4(c, halo);
		col = mix(col, vec4(mix(c, vec3(1.0), 0.4), 1.0), core);
		col.a = max(halo, core);
	}
	float line = step(fract((px.y - TIME * 18.0) / 6.0), 1.0 / 6.0) * 0.045;
	COLOR = vec4(mix(vec3(0.0), col.rgb, col.a / max(col.a + line, 0.0001)), max(col.a, line));
}"""
	return _shader
