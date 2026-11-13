class_name TutorialProps
extends RefCounted
## The interactive pieces of Boot Camp, built at run time from the markers of
## scenes/levels/boot_camp.tscn: goal pads, balloons to look at and the
## shooting gallery's targets. Chunky, flat-coloured, emissive accents, like
## the rest of the pier; each kind shares its materials.

const PINK := Color(1.0, 0.25, 0.64)
const CYAN := Color(0.21, 0.94, 1.0)
const GOLD := Color(1.0, 0.76, 0.29)
const CREAM := Color(1.0, 0.94, 0.86)
const INK := Color(0.07, 0.05, 0.18)

static var _mats := {}


static func mat(key: String, color: Color, glow := 0.0, unshaded := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func cylinder(radius: float, height: float, material: Material, segments := 32) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	c.material = material
	return c


static func mesh_node(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A goal pad: a glowing ring on the deck, a soft light column and a bobbing
## chevron. Reached when the player stands on it.
class Pad extends Node3D:
	const RADIUS := 1.5
	var active := false
	var _column: MeshInstance3D
	var _arrow: MeshInstance3D
	var _time := 0.0

	func _ready() -> void:
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS - 0.18
		torus.outer_radius = RADIUS
		torus.rings = 32
		torus.ring_segments = 6
		torus.material = TutorialProps.mat("pad_ring", TutorialProps.CYAN, 2.4)
		TutorialProps.mesh_node(self, torus, Vector3(0, 0.05, 0))
		var disc := TutorialProps.cylinder(RADIUS - 0.18, 0.02, TutorialProps.mat("pad_disc", Color(TutorialProps.CYAN, 0.18), 0.0, true))
		TutorialProps.mesh_node(self, disc, Vector3(0, 0.03, 0))
		var beam := CylinderMesh.new()
		beam.top_radius = RADIUS - 0.25
		beam.bottom_radius = RADIUS - 0.2
		beam.height = 3.2
		beam.radial_segments = 24
		beam.cap_top = false
		beam.cap_bottom = false
		beam.material = TutorialProps.mat("pad_beam", Color(TutorialProps.CYAN, 0.12), 0.0, true)
		_column = TutorialProps.mesh_node(self, beam, Vector3(0, 1.6, 0))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.34
		cone.bottom_radius = 0.0
		cone.height = 0.46
		cone.radial_segments = 4
		cone.material = TutorialProps.mat("pad_arrow", TutorialProps.GOLD, 2.0)
		_arrow = TutorialProps.mesh_node(self, cone, Vector3(0, 2.6, 0))
		set_active(active)

	func set_active(on: bool) -> void:
		active = on
		visible = on
		set_process(on)

	func _process(delta: float) -> void:
		_time += delta
		_arrow.position.y = 2.5 + sin(_time * 3.0) * 0.18
		_arrow.rotation.y = _time * 1.6

	## True when `p` (the player's feet) is on the pad.
	func contains(p: Vector3) -> bool:
		var d := p - global_position
		return Vector2(d.x, d.z).length() < RADIUS and absf(d.y) < 1.6


## A carnival balloon on a string; it pops when the player looks straight at it.
class Balloon extends Node3D:
	signal popped
	var color := TutorialProps.PINK
	var alive := true
	var _time := randf() * 6.0
	var _body: Node3D

	func _ready() -> void:
		_body = Node3D.new()
		add_child(_body)
		var sphere := SphereMesh.new()
		sphere.radius = 0.55
		sphere.height = 1.3
		sphere.radial_segments = 20
		sphere.rings = 10
		sphere.material = TutorialProps.mat("balloon_%s" % color.to_html(), color, 0.5)
		TutorialProps.mesh_node(_body, sphere)
		var knot := TutorialProps.cylinder(0.08, 0.12, sphere.material, 8)
		TutorialProps.mesh_node(_body, knot, Vector3(0, -0.68, 0))
		var string := TutorialProps.cylinder(0.012, 2.6, TutorialProps.mat("string", TutorialProps.CREAM), 4)
		TutorialProps.mesh_node(_body, string, Vector3(0, -2.0, 0))

	func _process(delta: float) -> void:
		_time += delta
		_body.position = Vector3(sin(_time * 0.9) * 0.08, sin(_time * 1.4) * 0.12, 0)

	## Pops the balloon (confetti and a pop).
	func pop() -> void:
		if not alive:
			return
		alive = false
		Fx.confetti(get_parent(), global_position)
		Sfx.play_at(&"onb_pop", global_position, 2.0, randf_range(0.95, 1.08))
		popped.emit()
		queue_free()

	func centre() -> Vector3:
		return _body.global_position


## A shooting-gallery target on a hinge: TIN (a bullseye that flips up),
## FAR (a big bullseye on a tall stand) or CUTOUT (a zombie silhouette with a
## head ring: only head hits count). Shots reach it through TargetRange.
class Target extends Node3D:
	enum Kind { TIN, FAR, CUTOUT }
	signal hit(target: Target, headshot: bool, at: Vector3)
	var kind := Kind.TIN
	var up := false
	var _hinge: Node3D
	var _body: StaticBody3D
	var _tween: Tween
	## Height (in the hinge's space) above which a cut-out hit is a headshot.
	var _head_y := 1.25

	func _ready() -> void:
		_hinge = Node3D.new()
		add_child(_hinge)
		_body = StaticBody3D.new()
		_body.set_meta("tutorial_target", self)
		_hinge.add_child(_body)
		match kind:
			Kind.TIN: _build_tin(0.45, 0.6)
			Kind.FAR: _build_tin(0.8, 1.9)
			Kind.CUTOUT: _build_cutout()
		_hinge.rotation.x = -PI * 0.5
		_body.collision_layer = 0

	func _build_tin(radius: float, height: float) -> void:
		var post := TutorialProps.cylinder(0.06, height, TutorialProps.mat("post", TutorialProps.INK), 8)
		TutorialProps.mesh_node(_hinge, post, Vector3(0, height * 0.5, 0))
		var face := Vector3(0, height + radius, 0)
		var rings := [[1.0, TutorialProps.CREAM, 0.0], [0.72, TutorialProps.PINK, 0.4], [0.44, TutorialProps.CREAM, 0.0], [0.2, TutorialProps.PINK, 0.8]]
		var i := 0
		for r in rings:
			var disc := TutorialProps.cylinder(radius * r[0], 0.06 + i * 0.012, TutorialProps.mat("ring_%d" % i, r[1], r[2]))
			TutorialProps.mesh_node(_hinge, disc, face, Vector3(PI * 0.5, 0, 0))
			i += 1
		_shape(Vector3(radius * 2.0, radius * 2.0, 0.12), face)

	func _build_cutout() -> void:
		var board := TutorialProps.mat("cutout", Color(0.36, 0.72, 0.42))
		var shirt := TutorialProps.mat("cutout_shirt", Color(1.0, 0.55, 0.3))
		var body := BoxMesh.new()
		body.size = Vector3(0.9, 0.95, 0.06)
		body.material = shirt
		TutorialProps.mesh_node(_hinge, body, Vector3(0, 0.62, 0))
		for side in [-1.0, 1.0]:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.22, 0.7, 0.05)
			arm.material = board
			TutorialProps.mesh_node(_hinge, arm, Vector3(side * 0.58, 0.82, 0.02), Vector3(0, 0, side * -1.1))
		var head := TutorialProps.cylinder(0.3, 0.07, board, 24)
		TutorialProps.mesh_node(_hinge, head, Vector3(0, 1.42, 0), Vector3(PI * 0.5, 0, 0))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.3
		ring.outer_radius = 0.38
		ring.rings = 24
		ring.ring_segments = 6
		ring.material = TutorialProps.mat("head_ring", TutorialProps.GOLD, 1.6)
		TutorialProps.mesh_node(_hinge, ring, Vector3(0, 1.42, 0.02), Vector3(PI * 0.5, 0, 0))
		for side in [-0.1, 0.1]:
			var eye := TutorialProps.cylinder(0.05, 0.08, TutorialProps.mat("eye", TutorialProps.CYAN, 2.5), 10)
			TutorialProps.mesh_node(_hinge, eye, Vector3(side, 1.46, 0.02), Vector3(PI * 0.5, 0, 0))
		_shape(Vector3(1.0, 1.0, 0.1), Vector3(0, 0.62, 0))
		_shape(Vector3(0.76, 0.76, 0.1), Vector3(0, 1.42, 0))
		_head_y = 1.05

	func _shape(size: Vector3, at: Vector3) -> void:
		var s := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		s.shape = box
		s.position = at
		_body.add_child(s)

	## Flips the target up (live) or down.
	func raise(on: bool, delay := 0.0) -> void:
		up = on
		_body.collision_layer = 1 if on else 0
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_interval(delay)
		if on:
			_tween.tween_callback(Sfx.play_at.bind(&"onb_target_up", global_position, -4.0, randf_range(0.95, 1.05), 12.0))
		_tween.tween_property(_hinge, "rotation:x", 0.0 if on else -PI * 0.5, 0.28 if on else 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Where to aim: the bullseye, or a cut-out's head (world space).
	func aim_point() -> Vector3:
		var heights := {Kind.TIN: 1.05, Kind.FAR: 2.7, Kind.CUTOUT: 1.42}
		return global_transform * Vector3(0, heights[kind], 0)

	## A shot landed on the target at `at` (world space).
	func take_shot(at: Vector3) -> void:
		if not up:
			return
		var head := kind != Kind.CUTOUT or _hinge.to_local(at).y > _head_y
		hit.emit(self, head, at)
