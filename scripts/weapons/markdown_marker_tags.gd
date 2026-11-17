class_name PriceTags
extends Node3D
## The Markdown Marker's price tags on one zombie (a child added by the first
## tag that sticks, PriceTags.of(zombie)). Every tag marks the zombie down:
## it takes TAG_BONUS more damage per tag (up to MAX_TAGS) from every hit,
## whatever weapon it comes from (through the DamageStack, so armour still sees
## the hit first). The tags show as big bright stickers on its torso, sized
## to it and riding its Spine bone (a hunched Bruiser, a leaning Lifeguard
## and a Yeti wear them on the chest, not in the air or over the face); a
## full stack pulses. They peel off TAG_TIME after the last one stuck.
##
## A marker hit on a zombie that already carries a full stack sets off a
## Clearance Pop (clearance()): the tags burst in confetti and coins, the
## zombie takes POP_DAMAGE (heavies HEAVY_POP_SCALE of it), every zombie within POP_RADIUS takes a splash of
## it and gets one tag of its own (the coins stick), and the marker gets
## POP_REFUND tags back in its magazine (MarkdownMarkerMode).
## tools/balance_report.py reads these constants.

const NODE_NAME := "PriceTags"
const MAX_TAGS := 3
## Damage taken per tag (0.1 = +10%).
const TAG_BONUS := 0.1
## Seconds the tags stay on after the last one stuck.
const TAG_TIME := 7.0
## Clearance Pop: damage to the zombie popped, splash radius (m) and the share
## of the pop a neighbour at the edge takes (full at the centre).
const POP_DAMAGE := 34.0
const POP_RADIUS := 3.2
const POP_EDGE := 0.55
## Heavies (Bruisers, Yetis, alphas, bosses) take this share of a pop.
const HEAVY_POP_SCALE := 0.5
## Tags the pop gives back to the marker's magazine.
const POP_REFUND := 2
## Sticker size (m) on a torso FIT_WIDTH wide (a Tourist's), and the stick-on pop time.
const TAG_SIZE := Vector2(0.38, 0.23)
## Stickers scale with the torso's width (rest pose, before body_scale), within FIT_RANGE.
const FIT_WIDTH := 0.75
const FIT_RANGE := Vector2(0.75, 1.3)
## Where each tag of a stack sits: turn (radians) from the side it hit, and
## height from the torso's middle as a share of the torso's height.
const SLOTS: Array[Vector2] = [Vector2(0.0, 0.05), Vector2(0.6, -0.14), Vector2(-0.6, 0.2)]
const STICK_TIME := 0.16
## How far out a sticker sits, as a share of the torso box's half-depth in its
## direction (the box's corners are wider than the rounded body), plus a lift.
const SURFACE := 0.9
const LIFT := 0.02
const SHADER := "res://art/shaders/markdown_marker_tag.gdshader"
## Sale Pink, Register Yellow, Mall Fountain Teal (one per tag in a stack).
const COLORS: Array[Color] = [Color(1.0, 0.31, 0.64), Color(1.0, 0.82, 0.25), Color(0.13, 0.85, 0.85)]
const CONFETTI: Array[Color] = [Color(1.0, 0.31, 0.64), Color(1.0, 0.82, 0.25), Color(0.13, 0.85, 0.85), Color(0.54, 0.36, 1.0), Color(1.0, 0.96, 0.88)]
const COIN := [Color(1.0, 0.79, 0.24), Color(1.0, 0.92, 0.55)]
const STICK_SOUND := &"mdm_stick"
const POP_SOUND := &"mdm_pop"
const MASK_WORLD := 1

var zombie: Zombie
var _count := 0
var _left := 0.0
var _age := 0.0
var _stickers: Array[MeshInstance3D] = []
var _born: Array[float] = []
## Where the stickers live: a BoneAttachment3D on the Spine bone, or this node
## for a model without one; the torso box (skeleton rest space, or this
## node's) and the rest transform that maps it into the frame.
var _frame: Node3D
var _torso := AABB()
var _rest := Transform3D.IDENTITY
var _skeleton: Skeleton3D
var _bone := -1
var _fit := 1.0

static var _quad: QuadMesh
## [colour index][ready 0/1] -> ShaderMaterial
static var _mats: Array = []


## The tags on `z`, created on first use.
static func of(z: Zombie) -> PriceTags:
	var existing := z.get_node_or_null(NODE_NAME) as PriceTags
	if existing:
		return existing
	var t := PriceTags.new()
	t.name = NODE_NAME
	t.zombie = z
	z.add_child(t)
	return t


## Damage multiplier the tags lend a hit that bypasses take_hit's filters.
static func damage_scale(z: Zombie) -> float:
	var t := z.get_node_or_null(NODE_NAME) as PriceTags
	return 1.0 + TAG_BONUS * t.count() if t else 1.0


## Tags on the zombie right now.
func count() -> int:
	return _count


func is_full() -> bool:
	return _count >= MAX_TAGS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)
	zombie.died.connect(func(_z: Zombie, _w: StringName) -> void: _peel(false))


## A tag sticks at `point` (world space): one more mark-down, up to MAX_TAGS
## (a full stack only has its timer refreshed).
func stick(point: Vector3) -> void:
	if zombie.is_dead():
		return
	_left = TAG_TIME
	if _count >= MAX_TAGS:
		return
	DamageStack.ensure(zombie)
	_add_sticker(point)
	_count += 1
	if _count >= MAX_TAGS:
		for s in _stickers.size():
			_stickers[s].material_override = _material(s, true)
	set_physics_process(true)
	Sfx.play_at(STICK_SOUND, point, -7.0, 0.92 + 0.1 * _count)


## Clearance Pop: the full stack bursts. `controller` deals the damage as the
## marker `weapon`'s; returns the number of zombies the splash reached.
func clearance(controller: WeaponController, weapon: WeaponData) -> int:
	var s := zombie.data.body_scale
	var centre := zombie.global_position + Vector3.UP * 1.1 * s
	_peel(true)
	var level := zombie.get_parent()
	WeaponFx.burst(level, centre, Vector3.UP, CONFETTI, 26, 6.0, 0.8, 0.045, 180.0, Vector3(0, -6.0, 0))
	WeaponFx.burst(level, centre, Vector3.UP, COIN, 12, 4.5, 0.75, 0.07, 120.0, Vector3(0, -14.0, 0))
	WeaponFx.flash(level, centre, COLORS[0], 0.9, 0.14)
	WeaponFx.shockwave(level, zombie.global_position + Vector3.UP * 0.15, COLORS[1], POP_RADIUS)
	Sfx.play_at(POP_SOUND, centre, 0.0, randf_range(0.96, 1.04))
	if not is_instance_valid(controller):
		return 0
	if not zombie.is_dead():
		controller.ring_hit(weapon, zombie, centre, Vector3.UP, _pop_share(zombie), false)
	var reached := 0
	for node in zombie.get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other == zombie or other.is_dead():
			continue
		var chest := other.global_position + Vector3.UP * 1.0 * other.data.body_scale
		var d := chest.distance_to(centre)
		if d > POP_RADIUS or not _clear(centre, chest):
			continue
		var away := (chest - centre).normalized()
		var hit_at := chest - away * other.data.capsule_radius * other.data.body_scale
		controller.ring_hit(weapon, other, hit_at, away, _pop_share(other) * lerpf(1.0, POP_EDGE, d / POP_RADIUS), false)
		reached += 1
		if not other.is_dead():
			PriceTags.of(other).stick(hit_at)
	return reached


## The pop's damage to `z` (heavies shrug off part of it).
static func _pop_share(z: Zombie) -> float:
	return POP_DAMAGE * (HEAVY_POP_SCALE if z.data.heavy else 1.0)


func _physics_process(delta: float) -> void:
	if _count == 0:
		set_physics_process(false)
		return
	_age += delta
	_left -= delta
	if _left <= 0.0:
		_peel(false)
		return
	var fading := _left < 1.0
	for i in _stickers.size():
		var t := clampf((_age - _born[i]) / STICK_TIME, 0.0, 1.0)
		# Slapped on: overshoots, then settles flat.
		var k := 1.0 + sin(t * PI) * 0.45 - (1.0 - t) * 0.6
		_stickers[i].scale = Vector3.ONE * maxf(0.05, k) * _fit
		_stickers[i].visible = not fading or fmod(_left * 9.0, 1.0) > 0.35


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	return zombie.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Every tag comes off (popped, peeled or the zombie died) and the mark-down ends.
func _peel(popped: bool) -> void:
	if _count > 0 and not popped and is_instance_valid(zombie):
		var at := zombie.global_position + Vector3.UP * 1.1 * zombie.data.body_scale
		WeaponFx.burst(zombie.get_parent(), at, Vector3.UP, CONFETTI, 4 + 2 * _count, 2.0, 0.5, 0.035, 120.0, Vector3(0, -5.0, 0))
	for s in _stickers:
		s.queue_free()
	_stickers.clear()
	_born.clear()
	_count = 0
	set_physics_process(false)


# --- looks ---------------------------------------------------------------------

## A sticker on the torso on the side the tag hit, facing out from the body.
## Each tag of a stack has its own slot (SLOTS), so all of them show.
func _add_sticker(point: Vector3) -> void:
	if _frame == null:
		_setup_frame()
	var local := _torso_point(point)
	var centre := _torso.get_center()
	var out := Vector3(local.x - centre.x, 0.0, local.z - centre.z)
	if out.length() < 0.01:
		out = Vector3(0, 0, 1)
	var slot: Vector2 = SLOTS[_count % SLOTS.size()]
	out = out.normalized().rotated(Vector3.UP, slot.x)
	var half := _torso.size * 0.5
	var reach := 1.0 / sqrt(pow(out.x / maxf(0.01, half.x), 2.0) + pow(out.z / maxf(0.01, half.z), 2.0))
	var anchor := Vector3(centre.x, centre.y + slot.y * _torso.size.y, centre.z) + out * (reach * SURFACE + LIFT)
	var m := MeshInstance3D.new()
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = TAG_SIZE
	m.mesh = _quad
	m.material_override = _material(_count, false)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roll := randf_range(-0.45, 0.45)
	m.transform = _rest.affine_inverse() * Transform3D(Basis.looking_at(-out, Vector3.UP) * Basis(Vector3.BACK, roll), anchor)
	m.scale = Vector3.ONE * 0.05
	_frame.add_child(m)
	_stickers.append(m)
	_born.append(_age)


## Picks the stickers' frame and torso box: the outfit on the Spine bone, or
## (no skeleton) a box from the body capsule on the zombie itself.
func _setup_frame() -> void:
	_skeleton = zombie.skeleton()
	_bone = _skeleton.find_bone("Spine") if _skeleton else -1
	_torso = zombie.torso_rest_box() if _bone >= 0 else AABB()
	if _torso.size == Vector3.ZERO:
		var s := zombie.data.body_scale
		var r := zombie.data.capsule_radius * s * 0.8
		_bone = -1
		_frame = self
		_torso = AABB(Vector3(-r, 0.85 * s, -r), Vector3(2.0 * r, 0.6 * s, 2.0 * r))
		_fit = s
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Spine"
	_skeleton.add_child(attach)
	_frame = attach
	_rest = _skeleton.get_bone_global_rest(_bone)
	_fit = clampf(_torso.size.x / FIT_WIDTH, FIT_RANGE.x, FIT_RANGE.y)


## `point` (world) in the torso box's space: the bone's rest pose for a
## skinned body (so a leaning or hunched pose maps back onto the box).
func _torso_point(point: Vector3) -> Vector3:
	if _bone < 0:
		return to_local(point)
	var in_skeleton := _skeleton.global_transform.affine_inverse() * point
	return _rest * _skeleton.get_bone_global_pose(_bone).affine_inverse() * in_skeleton


static func _material(index: int, ready_state: bool) -> ShaderMaterial:
	if _mats.is_empty():
		var shader: Shader = load(SHADER)
		for c in COLORS:
			var pair: Array[ShaderMaterial] = []
			for r in 2:
				var sm := ShaderMaterial.new()
				sm.shader = shader
				sm.set_shader_parameter("fill_color", c)
				sm.set_shader_parameter("ready", float(r))
				pair.append(sm)
			_mats.append(pair)
	return _mats[index % COLORS.size()][1 if ready_state else 0]
