class_name TracerStyles
extends RefCounted
## The "tracer" cosmetics: how the player's shots are drawn. Fx.tracer() asks
## draw() first when a tracer item is equipped. params.style is one of:
##   solid      the standard beam in the item's colour
##   helix      two strands twisting round the shot (colors 0 and 1)
##   sparkle    the beam plus glitter that lingers along the path
##   rainbow    a beam cycling through the rainbow along its length
##   lightning  a jagged, flickering bolt with forks
##   comet      a glowing head racing to the target with a sparkling tail
##   bubbles    a thin beam leaving soap bubbles that drift up and pop
## and the pattern styles (PATTERNS), drawn with one shared unit mesh and
## art/shaders/tracer_pattern.gdshader, so no mesh is built per shot:
##   ribbon     a satin ribbon twisting along the shot (front colour 0, back 1)
##   morse      dots and dashes spelling P-O-P racing to the target
##   heartbeat  an ECG line with a spike every few metres and a running blip
##   fence      four laser rails with rungs streaming along them
##   neon       a fat neon-sign tube with a hot core that strikes on
##   tickets    a slowly curling roll of prize tickets
##   chevrons   arrows streaming to the target
##   candy      a candy-stripe tube with spiralling stripes
## params.flakes = true swaps sparkle glitter for snowflakes.
##
## The coloured ribbons are drawn with normal (mix) blending: added light
## turns every hue white against the bright skies, and the colour is the point
## of these items.

const MAX_SEGMENTS := 160
const PATTERN_SHADER := "res://art/shaders/tracer_pattern.gdshader"
## Pattern styles: shader style index, unit mesh, width (times the weapon's
## tracer width), life, reveal time and whether a thin beam runs underneath.
const PATTERNS := {
	"ribbon": [0, "strip", 5.0, 0.2, 0.05, false],
	"morse": [1, "cross", 6.5, 0.22, 0.05, true],
	"heartbeat": [2, "cross", 1.8, 0.26, 0.05, false],
	"fence": [3, "cross", 8.0, 0.18, 0.04, false],
	"neon": [4, "cross", 3.5, 0.2, 0.03, false],
	"tickets": [5, "strip", 8.0, 0.3, 0.08, false],
	"chevrons": [6, "cross", 9.0, 0.2, 0.04, true],
	"candy": [7, "tube", 3.0, 0.2, 0.04, false],
}
## Segments along the shared unit meshes (the heartbeat bends along them).
const UNIT_SEGMENTS := 400

static var _ribbon_material: StandardMaterial3D
static var _unit_meshes := {}
static var _pattern_materials := {}


## Draws a styled tracer. Returns false if the style is unknown (the caller
## then draws the standard tracer).
static func draw(parent: Node, from: Vector3, to: Vector3, width: float, item: CosmeticItem) -> bool:
	var style := String(item.params.get("style", "solid"))
	var c0 := item.color(0, Color(0.3, 0.95, 1.0))
	var c1 := item.color(1, c0.lerp(Color.WHITE, 0.5))
	match style:
		"solid":
			Fx.beam(parent, from, to, c0, width)
			_spawn(parent, from, to, _straight(from, to, width * 0.55, c0), 0.14, 0.03)
		"helix":
			Fx.beam(parent, from, to, c0.lerp(Color.WHITE, 0.6), width * 0.25)
			_spawn(parent, from, to, _helix(from, to, width, c0, c1), 0.2, 0.05)
		"sparkle":
			Fx.beam(parent, from, to, c0, width * 0.8)
			_glitter(parent, from, to, [c0, c1, Color.WHITE], bool(item.params.get("flakes", false)))
		"rainbow":
			_spawn(parent, from, to, _rainbow(from, to, width), 0.16, 0.04)
		"lightning":
			_spawn(parent, from, to, _lightning(from, to, width, c0, c1), 0.12, 0.0, true)
		"comet":
			Fx.beam(parent, from, to, c0, width * 0.5)
			_comet(parent, from, to, c0, c1)
		"bubbles":
			Fx.beam(parent, from, to, c0, width * 0.5)
			_bubble_trail(parent, from, to, [c0, c1, Color.WHITE])
		_:
			if not PATTERNS.has(style):
				return false
			_pattern(parent, from, to, width, style, c0, c1)
	return true


static func _spawn(parent: Node, from: Vector3, to: Vector3, mesh: Mesh, life: float, reveal: float, flicker := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var t := StyledTracer.take(parent)
	t.mesh = mesh
	t.material_override = _material()
	t.launch(from, to, life, reveal, flicker)


static func _pattern(parent: Node, from: Vector3, to: Vector3, width: float, style: String, c0: Color, c1: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var spec: Array = PATTERNS[style]
	if spec[5]:
		Fx.beam(parent, from, to, c0, width * 0.35)
	var t := StyledTracer.take(parent)
	t.mesh = unit_mesh(spec[1])
	t.material_override = pattern_material(spec[0], c0, c1)
	t.launch_pattern(from, to, width * spec[2], spec[3], spec[4])


## The pattern shader with one item's colours (cached per style and colours).
static func pattern_material(index: int, c0: Color, c1: Color) -> ShaderMaterial:
	var key := "%d|%s|%s" % [index, c0.to_html(), c1.to_html()]
	if not _pattern_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(PATTERN_SHADER)
		m.set_shader_parameter("style", index)
		m.set_shader_parameter("color_a", c0)
		m.set_shader_parameter("color_b", c1)
		_pattern_materials[key] = m
	return _pattern_materials[key]


## A shared unit mesh along +Z from 0 to 1 with UV.y = z and UV.x across:
## "strip" (one flat strip in X), "cross" (strips in X and Y, seen from any
## side) or "tube" (UV.x round it).
static func unit_mesh(kind: String) -> Mesh:
	if _unit_meshes.has(kind):
		return _unit_meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector2Array()
	if kind == "tube":
		for k in 11:
			rim.append(Vector2(cos(TAU * k / 10.0), sin(TAU * k / 10.0)) * 0.5)
	for i in UNIT_SEGMENTS:
		var z0 := float(i) / UNIT_SEGMENTS
		var z1 := float(i + 1) / UNIT_SEGMENTS
		if kind == "tube":
			for k in 10:
				_unit_quad(st, rim[k], rim[k + 1], z0, z1, k / 10.0, (k + 1) / 10.0)
		else:
			_unit_quad(st, Vector2(-0.5, 0.0), Vector2(0.5, 0.0), z0, z1, 0.0, 1.0)
			if kind == "cross":
				_unit_quad(st, Vector2(0.0, -0.5), Vector2(0.0, 0.5), z0, z1, 0.0, 1.0)
	_unit_meshes[kind] = st.commit()
	return _unit_meshes[kind]


static func _unit_quad(st: SurfaceTool, a: Vector2, b: Vector2, z0: float, z1: float, u0: float, u1: float) -> void:
	var corners := [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)]
	var uvs := [Vector2(u0, z0), Vector2(u1, z0), Vector2(u1, z1), Vector2(u0, z1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])


## Soap bubbles hanging along the shot (drifting up, popping) with a fizz of
## coloured beads so the trail reads against a bright sky too.
static func _bubble_trail(parent: Node, from: Vector3, to: Vector3, cols: Array) -> void:
	var length := from.distance_to(to)
	var start := from + (to - from).normalized() * minf(1.5, length * 0.3)
	FxSwarm.spawn(parent, start, FxShapes.bubble(), cols, {"count": clampi(int(length * 1.2), 6, 40), "shape": "line",
		"line_to": to, "jitter": 0.1, "speed": Vector2(0.1, 0.4), "life": Vector2(0.5, 0.9), "size": Vector2(0.1, 0.18),
		"gravity": Vector3(0, 1.2, 0), "drag": 2.0, "wobble": 0.5, "pop": true, "grow": 0.2, "spin": 0.0, "stagger": 0.05})
	FxSwarm.spawn(parent, start, FxShapes.ball(), cols, {"count": clampi(int(length * 1.0), 5, 32), "shape": "line", "line_to": to,
		"jitter": 0.08, "speed": Vector2(0.1, 0.5), "life": Vector2(0.3, 0.6), "size": Vector2(0.03, 0.05),
		"gravity": Vector3(0, 0.8, 0), "drag": 2.0})


## Unshaded, vertex-coloured, alpha-blended (see the note at the top).
static func _material() -> StandardMaterial3D:
	if _ribbon_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		_ribbon_material = m
	return _ribbon_material


## A frame along the shot: x/y across it, z along it (from the muzzle).
static func _frame(from: Vector3, to: Vector3) -> Basis:
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := dir.cross(up).normalized()
	return Basis(x, x.cross(dir).normalized(), dir)


## Adds a thin camera-agnostic ribbon (two crossed strips) along `pts`.
static func _ribbon(st: SurfaceTool, pts: PackedVector3Array, cols: PackedColorArray, widths: PackedFloat32Array, frame: Basis) -> void:
	for side in [frame.x, frame.y]:
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var wa: Vector3 = side * widths[i]
			var wb: Vector3 = side * widths[i + 1]
			var ca := cols[i]
			var cb := cols[i + 1]
			_rv(st, a - wa, ca)
			_rv(st, b - wb, cb)
			_rv(st, b + wb, cb)
			_rv(st, a - wa, ca)
			_rv(st, b + wb, cb)
			_rv(st, a + wa, ca)


static func _rv(st: SurfaceTool, at: Vector3, c: Color) -> void:
	st.set_color(c)
	st.add_vertex(at)


static func _helix(from: Vector3, to: Vector3, width: float, c0: Color, c1: Color) -> Mesh:
	var frame := _frame(from, to)
	var length := from.distance_to(to)
	var n := clampi(int(length * 7.0), 12, MAX_SEGMENTS)
	var radius := maxf(0.06, width * 1.1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 2:
		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		var widths := PackedFloat32Array()
		for i in n + 1:
			var t := float(i) / n
			# The helix opens up over the first metres so it never fills the screen.
			var r := radius * smoothstep(0.0, 1.0, t * length / 3.0)
			var a := t * length * 2.6 + strand * PI
			pts.append(from + frame.z * (t * length) + (frame.x * cos(a) + frame.y * sin(a)) * r)
			var c := c0 if strand == 0 else c1
			cols.append(Color(c, 1.0 - t * 0.5))
			widths.append(width * 0.2)
		_ribbon(st, pts, cols, widths, frame)
	return st.commit()


## A straight ribbon in one colour, thin at the muzzle and fading towards the target.
static func _straight(from: Vector3, to: Vector3, width: float, c: Color) -> Mesh:
	var length := from.distance_to(to)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var widths := PackedFloat32Array()
	for i in 7:
		var t := i / 6.0
		pts.append(from.lerp(to, t))
		cols.append(Color(c, 0.95 - t * 0.45))
		widths.append(width * (0.2 + 0.8 * minf(1.0, t * length / 3.0)))
	_ribbon(st, pts, cols, widths, _frame(from, to))
	return st.commit()


static func _rainbow(from: Vector3, to: Vector3, width: float) -> Mesh:
	var frame := _frame(from, to)
	var length := from.distance_to(to)
	var n := clampi(int(length * 2.0), 6, MAX_SEGMENTS)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var widths := PackedFloat32Array()
	var offset := randf()
	for i in n + 1:
		var t := float(i) / n
		pts.append(from + frame.z * (t * length))
		cols.append(Color.from_hsv(fmod(offset + t * length * 0.12, 1.0), 0.8, 1.0))
		widths.append(width * (0.15 + 0.85 * minf(1.0, t * length / 3.0)) * 0.8)
	_ribbon(st, pts, cols, widths, frame)
	return st.commit()


static func _lightning(from: Vector3, to: Vector3, width: float, c0: Color, c1: Color) -> Mesh:
	var frame := _frame(from, to)
	var length := from.distance_to(to)
	var n := clampi(int(length * 1.5), 5, 60)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var widths := PackedFloat32Array()
	for i in n + 1:
		var t := float(i) / n
		var amp := 0.0 if i == 0 or i == n else minf(0.25, length * 0.02) * sin(t * PI)
		var off := frame.x * randf_range(-amp, amp) + frame.y * randf_range(-amp, amp)
		pts.append(from + frame.z * (t * length) + off)
		cols.append(c0.lerp(Color.WHITE, randf() * 0.5))
		widths.append(width * 0.35)
	_ribbon(st, pts, cols, widths, frame)
	# A few short forks.
	for k in mini(3, n / 3):
		var i0 := randi_range(1, n - 2)
		var fork := PackedVector3Array([pts[i0]])
		var dir := (frame.z + frame.x * randf_range(-1.0, 1.0) + frame.y * randf_range(-1.0, 1.0)).normalized()
		for j in 3:
			fork.append(fork[j] + (dir + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))).normalized() * length * 0.03)
		_ribbon(st, fork, PackedColorArray([c1, c1, c1, c1]), PackedFloat32Array([width * 0.25, width * 0.2, width * 0.15, width * 0.1]), frame)
	return st.commit()


static func _glitter(parent: Node, from: Vector3, to: Vector3, cols: Array, flakes: bool) -> void:
	var length := from.distance_to(to)
	var start := from + (to - from).normalized() * minf(1.5, length * 0.3)
	FxSwarm.spawn(parent, start, FxShapes.snowflake() if flakes else FxShapes.star(), cols, {
		"count": clampi(int(length * 2.2), 8, 60), "shape": "line", "line_to": to, "jitter": 0.12,
		"speed": Vector2(0.2, 0.7), "life": Vector2(0.4, 0.9), "size": Vector2(0.1, 0.16) if flakes else Vector2(0.08, 0.14),
		"gravity": Vector3(0, -0.6, 0), "drag": 1.5, "spin": 5.0, "blink": 0.0 if flakes else 6.0, "grow": 0.05})


static func _comet(parent: Node, from: Vector3, to: Vector3, c0: Color, c1: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var head := MeshInstance3D.new()
	head.mesh = FxShapes.quad()
	head.material_override = FxShapes.star_flash_material(c0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(head)
	var start := from + (to - from).normalized() * minf(1.2, from.distance_to(to) * 0.5)
	head.global_position = start
	head.scale = Vector3.ONE * 0.9
	var time := clampf(start.distance_to(to) / 120.0, 0.03, 0.3)
	var tw := head.create_tween()
	tw.tween_property(head, "global_position", to, time)
	tw.tween_callback(head.queue_free)
	FxSwarm.spawn(parent, start, FxShapes.star(), [c0, c1, Color.WHITE], {"count": clampi(int(start.distance_to(to) * 1.2), 4, 36),
		"shape": "line", "line_to": to, "speed": Vector2(0.3, 1.0), "life": Vector2(0.25, 0.55), "size": Vector2(0.06, 0.1),
		"gravity": Vector3(0, -1.0, 0), "drag": 2.0, "stagger": time, "sweep": true, "spin": 6.0})
