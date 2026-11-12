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
## params.flakes = true swaps sparkle glitter for snowflakes.

const MAX_SEGMENTS := 160


## Draws a styled tracer. Returns false if the style is unknown (the caller
## then draws the standard tracer).
static func draw(parent: Node, from: Vector3, to: Vector3, width: float, item: CosmeticItem) -> bool:
	var style := String(item.params.get("style", "solid"))
	var c0 := item.color(0, Color(0.3, 0.95, 1.0))
	var c1 := item.color(1, c0.lerp(Color.WHITE, 0.5))
	match style:
		"solid":
			Fx.beam(parent, from, to, c0, width)
		"helix":
			Fx.beam(parent, from, to, c0.lerp(Color.WHITE, 0.6), width * 0.35)
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
		_:
			return false
	return true


static func _spawn(parent: Node, from: Vector3, to: Vector3, mesh: Mesh, life: float, reveal: float, flicker := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var t := StyledTracer.new()
	t.mesh = mesh
	t.material_override = FxShapes.additive_material(Color.WHITE)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(t)
	t.launch(from, to, life, reveal, flicker)


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
			for v in [[a - wa, i], [b - wb, i + 1], [b + wb, i + 1], [a - wa, i], [b + wb, i + 1], [a + wa, i]]:
				st.set_color(cols[v[1]])
				st.add_vertex(v[0])


static func _helix(from: Vector3, to: Vector3, width: float, c0: Color, c1: Color) -> Mesh:
	var frame := _frame(from, to)
	var length := from.distance_to(to)
	var n := clampi(int(length * 7.0), 12, MAX_SEGMENTS)
	var radius := maxf(0.06, width * 1.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 2:
		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		var widths := PackedFloat32Array()
		for i in n + 1:
			var t := float(i) / n
			# The helix opens up from the muzzle so it never fills the screen.
			var r := radius * smoothstep(0.0, 0.08, t * length / 4.0)
			var a := t * length * 2.6 + strand * PI
			pts.append(from + frame.z * (t * length) + (frame.x * cos(a) + frame.y * sin(a)) * r)
			var c := c0 if strand == 0 else c1
			cols.append(Color(c, 1.0 - t * 0.5))
			widths.append(width * 0.28)
		_ribbon(st, pts, cols, widths, frame)
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
		cols.append(Color.from_hsv(fmod(offset + t * length * 0.06, 1.0), 0.8, 1.0))
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
		"count": clampi(int(length * 1.6), 6, 48), "shape": "line", "line_to": to, "jitter": 0.05,
		"speed": Vector2(0.2, 0.7), "life": Vector2(0.35, 0.8), "size": Vector2(0.06, 0.11) if flakes else Vector2(0.05, 0.09),
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
	head.scale = Vector3.ONE * 0.5
	var time := clampf(start.distance_to(to) / 120.0, 0.03, 0.3)
	var tw := head.create_tween()
	tw.tween_property(head, "global_position", to, time)
	tw.tween_callback(head.queue_free)
	FxSwarm.spawn(parent, start, FxShapes.star(), [c0, c1, Color.WHITE], {"count": clampi(int(start.distance_to(to) * 1.2), 4, 36),
		"shape": "line", "line_to": to, "speed": Vector2(0.3, 1.0), "life": Vector2(0.25, 0.55), "size": Vector2(0.06, 0.1),
		"gravity": Vector3(0, -1.0, 0), "drag": 2.0, "stagger": time, "sweep": true, "spin": 6.0})
