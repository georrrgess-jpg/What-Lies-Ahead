class_name ImpactMarks
extends MultiMeshInstance3D
## Impact marks on the static world: a small glowing scorched hole where a
## shot lands, cooling from the weapon's energy colour to soot in about a
## second, then fading after a while. Each weapon leaves its own kind (see
## art/shaders/impact_mark.gdshader): bolt holes, pellet clusters, a burnt
## gouge along a rail shot, a round blast scorch, a frost patch, an arc burn
## and a skid where a lobbed ball bounces. Nothing in the level changes.
##
## One per level, made by FxWarmup behind the fade-in: a fixed ring of quads
## in one MultiMesh (one draw call; the oldest mark is reused when it is full),
## all drawing done by the shader from per-instance data. The only script work
## is placing a mark, plus advancing the shader's clock while any mark is
## still showing.
##
## Marks go only on static scenery: a StaticBody3D on physics layer 1 that is
## not moving and not under a scripted node (stations, rides), and whose name
## does not mark it as a collider that is not the visible surface (SKIP_NAMES:
## stand-in boxes around props, glass fronts, stair ramps above the visible
## steps, water, lava). A body in the "no_impact_marks" group is skipped too.
## A mark is shrunk or dropped where it would hang over an edge, so it never
## floats in the air.

enum Style { BOLT, PELLET, RAIL, BLAST, FROST, ARC, SCUFF }

const SHADER := "res://art/shaders/impact_mark.gdshader"
const NO_MARKS_GROUP := &"no_impact_marks"
## Body names that never take marks: stand-in boxes around props ("...Collision",
## "...Col", "...Guard", gates, ropes) and see-through railings and fences,
## invisible walls, stair and escalator ramps, glass shop fronts, doors,
## windows and tanks, and water, lava, rivers and pools.
const SKIP_NAMES := "Collision|Collider|Col$|Col[A-Z0-9]|Guard|Gate\\d|Rope|Rail|Fence|Grille|Windbreak|NoClimb|PlayerWall|Stair|Wedge|Escalator|^Front\\d|Door|Glass|Window|Skylight|Tank|Water|Lava|River|Pool|Basin"
const MASK_WORLD := 1
## Marks kept at once on the High and Low graphics presets.
const CAP_HIGH := 128
const CAP_LOW := 48
## Seconds a mark stays before it fades, per preset.
const LIFE_HIGH := 24.0
const LIFE_LOW := 10.0
const FADE := 2.5
## Height above the collision surface: clears painted markings and floor
## decals laid a little proud of it (the shader also nudges the depth).
const LIFT := 0.025
## Half sizes in metres per style (a bolt's comes from its tracer width, a
## blast's from its splash radius).
const HALF := [0.0, 0.045, 0.1, 0.0, 0.3, 0.3, 0.13]
## Edge probes, as fractions of the mark's half extents: four for small
## marks, eight for big ones.
const PROBES: Array[Vector2] = [Vector2(0.8, 0), Vector2(-0.8, 0), Vector2(0, 0.8), Vector2(0, -0.8),
	Vector2(0.56, 0.56), Vector2(-0.56, 0.56), Vector2(0.56, -0.56), Vector2(-0.56, -0.56)]
## Tried in turn when a mark would hang over an edge.
const SHRINK := [1.0, 0.62, 0.38]

static var _material: ShaderMaterial
static var _quad: QuadMesh
static var _current: ImpactMarks
static var _skip_names: RegEx

var _now := 0.0
var _next := 0
var _used := 0
var _life := LIFE_HIGH
## Clock time when the last mark is gone (the clock then stops).
var _until := 0.0
var _last_at := Vector3.INF
var _last_time := -100.0
var _last_style := -1
var _query: PhysicsRayQueryParameters3D
## Collider instance id -> whether it takes marks (decided once per body).
var _markable := {}


# --- entry points ----------------------------------------------------------------

## A shot from `w` hit the world: `hit` is the ray result (position, normal,
## collider), `dir` the shot's direction.
static func shot(level: Node, hit: Dictionary, dir: Vector3, w: WeaponData) -> void:
	var marks := _in(level)
	if marks == null:
		return
	var style := _style_of(w)
	var half: float = _bolt_half(w) if style == Style.BOLT else HALF[style]
	marks._place(hit["position"], hit["normal"], hit["collider"], dir, style, w.tracer_color, half)


## A splash weapon went off at `at`. `hit` is the surface it struck, if any
## (empty for a blast in the air or on a zombie). Whatever it struck, the
## ground close below gets a scorch too, smaller the higher the blast.
static func blast(level: Node, at: Vector3, w: WeaponData, hit: Dictionary) -> void:
	var marks := _in(level)
	if marks == null:
		return
	var radius := clampf(w.splash_radius * 0.34, 0.5, 1.6)
	if not hit.is_empty():
		marks._place(hit["position"], hit["normal"], hit["collider"], Vector3.ZERO, Style.BLAST, w.tracer_color, radius)
		if (hit["normal"] as Vector3).y > 0.7:
			return
	var ground := marks._ray(at + Vector3.UP * 0.2, at + Vector3.DOWN * 1.6)
	if ground.is_empty():
		return
	radius *= clampf(1.15 - at.distance_to(ground["position"]) / 1.6, 0.35, 1.0)
	marks._place(ground["position"], ground["normal"], ground["collider"], Vector3.ZERO, Style.BLAST, w.tracer_color, radius)


## A lobbed ball bounced off the world.
static func scuff(level: Node, hit: Dictionary, dir: Vector3, w: WeaponData) -> void:
	var marks := _in(level)
	if marks:
		marks._place(hit["position"], hit["normal"], hit["collider"], dir, Style.SCUFF, w.tracer_color, HALF[Style.SCUFF])


## Level start (FxWarmup): makes this level's marks node, and draws one mark
## of each style on a throwaway node under `holder` so the shader compiles
## behind the fade-in.
static func warm_up(level: Node, holder: Node3D, at: Vector3, facing: Vector3) -> void:
	_in(level)
	var mm := _new_multimesh(Style.size())
	var basis := Basis.looking_at(-facing, Vector3.UP if absf(facing.y) < 0.99 else Vector3.RIGHT).scaled(Vector3.ONE * 0.3)
	for i in Style.size():
		mm.set_instance_transform(i, Transform3D(basis, at))
		mm.set_instance_color(i, Color(0.3, 0.95, 1.0))
		mm.set_instance_custom_data(i, Color(_current._now, i, 0.5, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mmi)


## Removes every mark (the screenshot tool's before/after stills).
static func clear(level: Node) -> void:
	var marks := _in(level)
	if marks:
		marks._reset()


# --- the pool --------------------------------------------------------------------

## This level's marks node (made on first use), or null when marks are off.
static func _in(level: Node) -> ImpactMarks:
	if level == null or not level.is_inside_tree():
		return null
	if is_instance_valid(_current) and _current.get_parent() == level:
		return _current
	_current = ImpactMarks.new()
	_current.name = "ImpactMarks"
	level.add_child(_current)
	return _current


static func _style_of(w: WeaponData) -> Style:
	match w.impact_style:
		&"frost":
			return Style.FROST
		&"arc":
			return Style.ARC
		&"rail":
			return Style.RAIL
	return Style.PELLET if w.pellets > 1 else Style.BOLT


static func _bolt_half(w: WeaponData) -> float:
	return clampf(w.tracer_width * 1.45, 0.06, 0.14)


static func _new_multimesh(count: int) -> MultiMesh:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER)
		_material.set_shader_parameter("fade_time", FADE)
		# Before every other see-through thing: marks lie on solid surfaces.
		_material.render_priority = -1
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = count
	return mm


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_to_group("graphics_listener")
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = MASK_WORLD
	apply_graphics_preset(Settings.is_low_graphics())
	_material.set_shader_parameter("now", _now)


## Called by the settings screen through the "graphics_listener" group.
func apply_graphics_preset(low: bool) -> void:
	_life = LIFE_LOW if low else LIFE_HIGH
	var cap := CAP_LOW if low else CAP_HIGH
	if multimesh == null or multimesh.instance_count != cap:
		multimesh = _new_multimesh(cap)
		material_override = _material
		_reset()


func _reset() -> void:
	_next = 0
	_used = 0
	_until = _now
	multimesh.visible_instance_count = 0
	set_process(false)


func _process(delta: float) -> void:
	_now += delta
	_material.set_shader_parameter("now", _now)
	if _now > _until:
		_reset()


## Places one mark of `style` (half size `half`) on the surface at `at`.
func _place(at: Vector3, normal: Vector3, collider: Object, dir: Vector3, style: Style, color: Color, half: float) -> void:
	if not _takes_marks(collider) or normal.length_squared() < 0.5:
		return
	# A stream of shots (or beam ticks) on one spot does not stack up marks.
	var min_gap := half * (0.5 if style == Style.FROST else 0.3)
	if style == _last_style and _now - _last_time < 0.4 and at.distance_to(_last_at) < min_gap:
		return
	var n := normal.normalized()
	var half_w := half * randf_range(0.85, 1.15)
	var half_l := half_w
	var along := dir - n * dir.dot(n)
	if style == Style.RAIL or style == Style.SCUFF:
		# Long along the shot, longer still when it grazes the surface.
		half_l = half_w * (2.2 + 2.0 * (1.0 - absf(dir.dot(n))))
	elif style == Style.BOLT or style == Style.PELLET:
		half_l = half_w * (1.0 + 0.6 * (1.0 - absf(dir.dot(n))))
	if along.length_squared() < 0.0001 or (style != Style.RAIL and style != Style.SCUFF and half_l == half_w):
		along = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).rotated(n, randf() * TAU)
	var t := along.normalized()
	var b := n.cross(t)
	for k in SHRINK:
		if _fits(at, n, t * half_l * k, b * half_w * k, half_w > 0.45):
			_add(Transform3D(Basis(t * half_l * k * 2.0, b * half_w * k * 2.0, n), at + n * LIFT), style, color)
			_last_at = at
			_last_time = _now
			_last_style = style
			return


## True when every edge probe finds the same flat surface under the mark.
func _fits(at: Vector3, n: Vector3, ext_t: Vector3, ext_b: Vector3, big: bool) -> bool:
	for i in (8 if big else 4):
		var o := PROBES[i]
		var c := at + ext_t * o.x + ext_b * o.y
		var hit := _ray(c + n * 0.06, c - n * 0.06)
		if hit.is_empty() or (hit["normal"] as Vector3).dot(n) < 0.96 or absf((Vector3(hit["position"]) - at).dot(n)) > 0.02:
			return false
	return true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	_query.from = from
	_query.to = to
	return get_world_3d().direct_space_state.intersect_ray(_query)


func _add(xform: Transform3D, style: Style, color: Color) -> void:
	var life := _life * (1.25 if style == Style.BLAST else 1.0)
	multimesh.set_instance_transform(_next, xform)
	multimesh.set_instance_color(_next, color)
	multimesh.set_instance_custom_data(_next, Color(_now, style, randf(), life))
	_next = (_next + 1) % multimesh.instance_count
	_used = mini(_used + 1, multimesh.instance_count)
	multimesh.visible_instance_count = _used
	_until = maxf(_until, _now + life + FADE)
	if not is_processing():
		_material.set_shader_parameter("now", _now)
		set_process(true)


## Static, unmoving level scenery on the world layer (decided once per body).
func _takes_marks(collider: Object) -> bool:
	if collider == null:
		return false
	var id := collider.get_instance_id()
	if not _markable.has(id):
		_markable[id] = _is_scenery(collider, get_parent())
	return _markable[id]


static func _is_scenery(collider: Object, level: Node) -> bool:
	var body := collider as StaticBody3D
	if body == null or body is AnimatableBody3D or body.collision_layer & MASK_WORLD == 0:
		return false
	if body.constant_linear_velocity != Vector3.ZERO or body.constant_angular_velocity != Vector3.ZERO:
		return false
	if body.is_in_group(NO_MARKS_GROUP):
		return false
	if _skip_names == null:
		_skip_names = RegEx.create_from_string(SKIP_NAMES)
	if _skip_names.search(String(body.name)):
		return false
	# Under a scripted node (a station, a ride, anything that might move).
	var up := body.get_parent()
	while up != null and up != level:
		if up.get_script() != null:
			return false
		up = up.get_parent()
	return true
