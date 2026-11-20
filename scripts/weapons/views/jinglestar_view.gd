extends MeleeView
## Jester's Jinglestar viewmodel (art/models/jinglestar.glb): a flail. The
## handle is posed like any melee weapon; the chain, the head and the ribbons
## are a simulated rope (JinglestarChain) hanging from the cap's eye
## (ChainAnchor), driven by the hand's motion, so the head hangs and sways at
## rest, lags, whips and trails with real weight.
##
##   idle    the head hangs below the cap and sways with the breathing hand
##   light   figure-eights: the handle cocks up to one side and whips across,
##           the head pulled through the middle of the screen at the contact
##           moment (a soft pull on top of the physics), alternating sides
##   windup  the hand rises and whirls the head overhead, faster with the charge
##   heavy   the whirl is brought over the top and slammed down the middle
##   equip   drawn up from the lower right, the head dropping into its swing
##
## The chain never stretches, never passes through the hand, the handle or
## the eye (JinglestarChain); with Reduce motion it is damped hard and the eye's
## own turning no longer swings it. Each link is posed between two points of
## the rope, the head along its last segment (spinning about it in the whirl),
## each ribbon segment along its rope. Menus and stills without a player keep
## the model's straight rest layout. Encore steps (JinglestarMode) puff
## sparkles off the head and each jingle shockwave throws confetti.
## Inspect: JinglestarTricks.

## The light swing (right to left, mirrored on every other swing): cocked up
## and out to the right, whipped across and down, followed through low left.
const FLAIL_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.2, Vector3(0.1, 0.09, 0.04), Vector3(16.0, -12.0, -26.0)],
	[0.44, Vector3(-0.12, -0.03, -0.1), Vector3(-22.0, 16.0, 34.0)],
	[0.64, Vector3(-0.2, -0.1, -0.02), Vector3(-30.0, 20.0, 40.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## The heavy, from the wind-up (raised high, whirling) down through the slam.
const FLAIL_HEAVY_KEYS := [
	[0.0, Vector3(-0.03, 0.07, -0.02), Vector3(20.0, -4.0, -10.0)],
	[0.3, Vector3(-0.05, -0.12, -0.12), Vector3(-38.0, 8.0, 16.0)],
	[0.52, Vector3(-0.07, -0.15, -0.05), Vector3(-42.0, 10.0, 18.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Contact moments (share of the light swing, of the heavy): the head crosses the middle.
const LIGHT_CONTACT := 0.38
const HEAVY_CONTACT := 0.3
## The head's path through a light swing (view space, right to left; x
## mirrored on the other side): [t, point]; and the pull's rise and fall.
const LIGHT_PATH := [
	[0.08, Vector3(0.46, 0.1, -0.72)],
	[0.24, Vector3(0.36, 0.14, -0.86)],
	[LIGHT_CONTACT, Vector3(0.02, -0.04, -1.0)],
	[0.56, Vector3(-0.36, -0.26, -0.8)],
]
const LIGHT_PULL := Vector3(0.06, 0.6, 0.85)   # from, until, strength
## The heavy's path: up over the top and down the middle.
const HEAVY_PATH := [
	[0.0, Vector3(0.12, 0.3, -0.9)],
	[0.14, Vector3(0.04, 0.38, -1.0)],
	[HEAVY_CONTACT, Vector3(0.0, -0.2, -1.05)],
	[0.5, Vector3(-0.06, -0.4, -0.86)],
]
const HEAVY_PULL := Vector3(0.0, 0.58, 1.0)
## The whirl: its centre from the cap (view units: over and in front of it), radius, the plane's tilt
## towards the eye (degrees), and its turn rate (rad/s) from no charge to full.
const WHIRL_CENTRE := Vector3(-0.08, 0.04, -0.12)
const WHIRL_RADIUS := 0.2
const WHIRL_TILT := 38.0
const WHIRL_SPIN := Vector2(8.0, 17.0)
## The hand's own little circle while it whirls (view units).
const WHIRL_WRIST := 0.014
## How much of the eye's own motion swings the chain (0 with Reduce motion).
const CARRY := 0.35
## The head's spin about its chain (degrees a second) while whirling, and its fade (1/s).
const HEAD_SPIN := 900.0
const SPIN_FADE := 2.5
## Rattle: a change of the head's velocity (view units / s) this big in a frame jingles, at most this often.
const RATTLE_JERK := 2.4
const RATTLE_GAP := 0.14
## Radii of the colliders: the hand and forearm, the handle.
const ARM_RADIUS := 0.055
const HANDLE_RADIUS := 0.028
const LINKS := 6
const LINK_PITCH := 0.028
const HEAD_OFFSET := 0.062
const RIBBONS := 3
const RIBBON_SEGS := 3
const RIBBON_SEG := 0.05
const SPARKLE := [Color(1.0, 0.85, 0.35), Color(1, 1, 1), Color(0.6, 0.35, 1.0), Color(0.2, 0.9, 0.6)]

var chain := JinglestarChain.new()
var tricks := JinglestarTricks.new()
var _arms := ArmAim.new()
var _view: WeaponView
var _links: Array[Node3D] = []
var _head: Node3D
var _handle: Node3D
var _anchor: Node3D
var _arm: Node3D
var _elbow: Node3D
## Ribbon segment nodes: [ribbon][segment]; each ribbon's root in the head's frame.
var _ribbon_nodes: Array = []
var _ribbon_roots: Array[Vector3] = []
var _live := false
var _fresh := true
var _last_view := Transform3D.IDENTITY
## The handle in the view's frame last frame (a paused weapon carries the chain with it).
var _last_handle := Transform3D.IDENTITY
var _side := Vector3.RIGHT
var _head_basis := Basis.IDENTITY
var _spin := 0.0
var _spin_rate := 0.0
var _whirl := 0.0
var _whirl_weight := 0.0
var _last_vel := Vector3.ZERO
var _rattle_wait := 0.0
var _encore_seen := 0
var _rings_seen := 0


func setup(view: WeaponView) -> void:
	super.setup(view)
	_view = view
	var model := view.model
	view.register_part("Handle")
	view.register_part("Head")
	_handle = view.part("Handle")
	_head = view.part("Head")
	_anchor = model.find_child("ChainAnchor", true, false) as Node3D
	_arm = model.find_child("ArmR", true, false) as Node3D
	_elbow = model.find_child("ElbowR", true, false) as Node3D
	_links.clear()
	for i in LINKS:
		var l := model.find_child("Link%d" % i, true, false) as Node3D
		if l:
			_links.append(l)
	_ribbon_nodes.clear()
	_ribbon_roots.clear()
	for i in RIBBONS:
		var segs: Array[Node3D] = []
		for k in RIBBON_SEGS:
			var r := model.find_child("Ribbon%d_%d" % [i, k], true, false) as Node3D
			if r:
				segs.append(r)
		if segs.size() == RIBBON_SEGS and _head:
			_ribbon_nodes.append(segs)
			# The root in the head's own frame (its eye at the origin, the ball along -Z).
			_ribbon_roots.append(segs[0].transform.origin)
	_live = view.player != null and _anchor != null and _head != null and _links.size() == LINKS
	_fresh = true
	_arms.setup(view)
	tricks.setup(view, self)
	var mode := _mode(view)
	if mode and "encore" in mode:
		_encore_seen = mode.encore
		_rings_seen = mode.rings


func light_keys() -> Array:
	return FLAIL_LIGHT_KEYS


func heavy_keys() -> Array:
	return FLAIL_HEAVY_KEYS


func contact_at(heavy: bool) -> float:
	return HEAVY_CONTACT if heavy else LIGHT_CONTACT


## Raised high and to the right, the wrist circling with the whirl.
func windup_pose(charge: float) -> Array:
	var pose := super.windup_pose(charge)
	var k := minf(1.0, charge * 4.0)
	pose[0] += Vector3(cos(_whirl), 0.0, sin(_whirl)) * WHIRL_WRIST * k
	return pose


## The draw: swung up from the lower right.
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := maxf(0.1, view.data.equip_time + 0.15)
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var k := 1.0 - ease_out(t / length)
	return [Vector3(0.08 * k, -0.14 * k, 0.0), Vector3(-40.0 * k, 0.0, -26.0 * k)]


## A breathing sway with a slow rock of the wrist, so the head swings a little at rest.
func idle_pose(t: float) -> Array:
	return [Vector3(0.003 * sin(t * 0.9), sin(t * 1.6) * 0.005, 0.0), Vector3(sin(t * 1.1) * 1.6, sin(t * 0.7) * 2.2, sin(t * 0.85) * 2.6)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if _live and view.is_inspecting():
		tricks.apply(view, delta)
	_arms.update(view, delta)
	if not _live:
		return
	var to_view := view.global_transform.affine_inverse()
	var anchor := to_view * _anchor.global_position
	var down := (to_view.basis * Vector3.DOWN).normalized()
	_side = (to_view.basis * _handle.global_transform.basis.x).normalized()
	if _fresh:
		_start(anchor)
	chain.calm = Settings.reduce_motion()
	chain.capsules = [
		[to_view * _arm.global_position, to_view * _elbow.global_position, ARM_RADIUS],
		[to_view * _handle.global_transform * Vector3(0.0, 0.0, 0.13), to_view * _handle.global_transform * Vector3(0.0, 0.0, -0.31), HANDLE_RADIUS],
	]
	var handle_xf := to_view * _handle.global_transform
	if not _running(view):
		chain.move(handle_xf * _last_handle.affine_inverse())
	else:
		chain.carry(to_view * _last_view, 0.0 if chain.calm else CARRY)
		_drive(view, mode, anchor, delta)
		chain.advance(delta, anchor, down, _roots())
		_sounds(view, mode, delta)
	_last_view = view.global_transform
	_last_handle = handle_xf
	_pose(view, delta)


## The chain is laid out at the first frame: coiled up over the cap on the
## draw (it drops into a swing), hanging at rest otherwise.
func _start(anchor: Vector3) -> void:
	_fresh = false
	var lengths := PackedFloat32Array()
	for i in LINKS:
		lengths.append(LINK_PITCH)
	lengths.append(HEAD_OFFSET)
	chain.setup(anchor, Vector3.DOWN, lengths)
	chain.ribbons.clear()
	for i in _ribbon_roots.size():
		chain.add_ribbon(anchor, Vector3.DOWN, RIBBON_SEGS, RIBBON_SEG)
	if _equip < 0.2:
		chain.lay(anchor, [Vector3(0.2, 1.0, -0.3), Vector3(0.4, 1.0, -0.6), Vector3(0.6, 0.6, -1.0), Vector3(0.6, 0.0, -1.0)])
	_last_view = _view.global_transform
	_last_handle = _view.global_transform.affine_inverse() * _handle.global_transform
	_head_basis = Basis.IDENTITY


## False while the weapon itself is paused (stills freeze the chain with the swing).
func _running(view: WeaponView) -> bool:
	return view.player.weapons == null or view.player.weapons.is_physics_processing()


## The pull on the head for the swing (or trick) in progress.
func _drive(view: WeaponView, mode: MeleeMode, anchor: Vector3, delta: float) -> void:
	chain.pull = 0.0
	var phase := mode.phase if mode else MeleeMode.Phase.IDLE
	var whirling := phase == MeleeMode.Phase.WINDUP
	_whirl_weight = move_toward(_whirl_weight, 1.0 if whirling else 0.0, delta * (5.0 if whirling else 8.0))
	if view.is_inspecting():
		tricks.drive(chain, anchor)
		_spin_rate = lerpf(_spin_rate, tricks.spin, 1.0 - exp(-6.0 * delta))
		return
	if whirling:
		_whirl += lerpf(WHIRL_SPIN.x, WHIRL_SPIN.y, mode.charge) * delta
		_spin_rate = HEAD_SPIN * (0.3 + 0.7 * mode.charge)
	else:
		_spin_rate *= exp(-SPIN_FADE * delta)
	if _whirl_weight > 0.0:
		chain.pull_target = whirl_point(anchor, _whirl)
		chain.pull = _whirl_weight * 0.8
	match phase:
		MeleeMode.Phase.LIGHT:
			var side := 1.0 if mode.swing_index % 2 == 1 else -1.0
			var t := mode.progress()
			var target := _path(LIGHT_PATH, t)
			chain.pull_target = Vector3(target.x * side, target.y, target.z)
			chain.pull = _hump(t, LIGHT_PULL)
		MeleeMode.Phase.HEAVY:
			var t := mode.progress()
			chain.pull_target = _path(HEAVY_PATH, t)
			chain.pull = _hump(t, HEAVY_PULL)
			_whirl += WHIRL_SPIN.y * delta * (1.0 - t)


## A point of the whirl `angle` round, above `anchor` (view space).
func whirl_point(anchor: Vector3, angle: float) -> Vector3:
	var tilt := deg_to_rad(WHIRL_TILT)
	var across := Vector3.RIGHT
	var deep := Vector3(0.0, sin(tilt), -cos(tilt))
	return anchor + WHIRL_CENTRE + (across * cos(angle) + deep * sin(angle)) * WHIRL_RADIUS


## The ribbons' roots now, from the head's last frame.
func _roots() -> Array:
	var out := []
	var eye := chain.p[LINKS]
	for r in _ribbon_roots:
		out.append(eye + _head_basis * r)
	return out


## Every link, the head and the ribbons onto the rope.
func _pose(view: WeaponView, delta: float) -> void:
	var g := view.global_transform
	var side := _side
	for i in LINKS:
		var a := chain.p[i]
		var b := chain.p[i + 1]
		var basis := _along(b - a, side)
		side = basis.x
		_links[i].global_transform = g * Transform3D(basis, (a + b) * 0.5)
	var eye := chain.p[LINKS]
	var hb := _along(chain.head() - eye, side)
	_spin = fmod(_spin + _spin_rate * delta, 360.0)
	hb = Basis(-hb.z, deg_to_rad(_spin)) * hb
	_head_basis = hb
	_head.global_transform = g * Transform3D(hb, eye)
	for j in _ribbon_nodes.size():
		if j >= chain.ribbons.size():
			break
		var pts: PackedVector3Array = chain.ribbons[j][0]
		var rside := hb.x
		var segs: Array = _ribbon_nodes[j]
		for k in segs.size():
			# A ribbon runs along its segments' +Z.
			var basis := _along(pts[k] - pts[k + 1], rside)
			rside = basis.x
			(segs[k] as Node3D).global_transform = g * Transform3D(basis, pts[k])


## A basis whose -Z runs along `dir`, its X as near `side` as it can be.
static func _along(dir: Vector3, side: Vector3) -> Basis:
	var z := -dir.normalized() if dir.length() > 1e-6 else Vector3.BACK
	var x := side - z * side.dot(z)
	if x.length() < 1e-4:
		x = z.cross(Vector3.UP)
		if x.length() < 1e-4:
			x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## The point at `t` along a path of [t, point] keys (smoothly eased between).
static func _path(path: Array, t: float) -> Vector3:
	if t <= float(path[0][0]):
		return path[0][1]
	for i in range(1, path.size()):
		if t <= float(path[i][0]):
			var a: Array = path[i - 1]
			var b: Array = path[i]
			var u := (t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return (a[1] as Vector3).lerp(b[1], ease_in_out(u))
	return path[path.size() - 1][1]


## 0 before `w.x`, rising to w.z and back to 0 at `w.y`.
static func _hump(t: float, w: Vector3) -> float:
	if t <= w.x or t >= w.y:
		return 0.0
	var u := (t - w.x) / (w.y - w.x)
	return w.z * minf(1.0, minf(u * 4.0, (1.0 - u) * 3.0))


## Chain rattles on a sharp jerk, sparkles on an encore step, confetti on a jingle shockwave.
func _sounds(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	var vel := chain.head_velocity()
	var jerk := (vel - _last_vel).length()
	_last_vel = vel
	_rattle_wait -= delta
	if jerk > RATTLE_JERK and _rattle_wait <= 0.0 and view.is_visible_in_tree():
		_rattle_wait = RATTLE_GAP
		Sfx.play(&"jingle_rattle", clampf(-20.0 + jerk * 1.5, -20.0, -8.0), randf_range(0.92, 1.1))
	if mode == null or not "encore" in mode:
		return
	var head_in_model := view.model.to_local(_head.global_transform * Vector3(0.0, 0.0, -HEAD_OFFSET))
	if mode.encore > _encore_seen:
		view.spark_burst(head_in_model, Vector3.UP, SPARKLE, 6 + 3 * mode.encore, 1.2, 0.35, 0.012)
	_encore_seen = mode.encore
	if mode.rings != _rings_seen:
		_rings_seen = mode.rings
		view.spark_burst(head_in_model, Vector3.UP, SPARKLE, 26, 2.2, 0.6, 0.016)


# --- inspect: JinglestarTricks ------------------------------------------------------------

func inspect_length() -> float:
	return tricks.choose()


func inspect_poses() -> Array:
	return tricks.poses()


func inspect_start(v: WeaponView) -> void:
	tricks.start(v)


func inspect(v: WeaponView, t: float) -> void:
	tricks.play(v, t)


func inspect_end(v: WeaponView) -> void:
	tricks.stop(v)
