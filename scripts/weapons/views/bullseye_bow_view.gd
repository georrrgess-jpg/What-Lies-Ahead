class_name BullseyeBowView
extends RefCounted
## Bullseye Longbow viewmodel motion (WeaponData.view_script).
##
## The draw: the nocking point (and with it the arrow and the drawing hand,
## ArmR) is pulled back DRAW_LEN at full draw. The string cannot stretch, so
## each limb (a chain of segments, LimbT0..4 / LimbB0..4) bends back until
## its string groove (TipT / TipB) is the string's half length from the
## nocking point again (a bisection on the bend each frame), and the two
## halves of the string (StringT / StringB, pivots on the nocking point) are
## turned onto the tips, so the string pulls into a V.
## The loose: the string snaps forward past brace and rings out (a damped
## spring), the limbs flick with it, the arrow is gone and the drawing hand
## opens and follows through. The nock (the reload, its timing and sounds in
## scripts/weapons/reloads/bullseye_bow_reload.gd) is posed here from the
## reload progress: the hand drops to the hip quiver, comes back with an
## arrow, lays it on the shelf and slides it back until the nock clicks onto
## the string, then the fingers hook the string again.
## The hold follows real archery form (see the constants): at rest the bow
## hangs at the ready; drawing raises it on a straight bow arm while the
## drawing hand (a three-under hook, its back flat and in line with the
## forearm) comes back to the right side of the face, the elbow falling in
## behind the arrow. Both forearms always point back at the body (_pose_arms).
## Held past the Bullseye window the bow trembles more and more (the mode's
## fatigue). Inspect: the drawing hand lets go, the string is plucked and
## rings, then the bow is spun a full turn on its grip.

## Nocking point travel at full draw (model metres, towards the camera).
const DRAW_LEN := 0.25
## The hold. At rest (WeaponData.view_position / view_rotation_degrees) the bow
## hangs low at the ready, canted a little, the bow arm bent and the drawing
## hand on the string. Drawing raises it to DRAWN_POS / DRAWN_ROT (the arrow
## rest and the cant, view space): the bow arm pushes out straight while the
## drawing hand comes back to the right side of the face. It stays up through
## the nock and for HOLD_UP seconds after an arrow, then settles again.
const DRAWN_POS := Vector3(0.065, -0.1, -0.72)
const DRAWN_ROT := Vector3(0.0, 0.0, -4.0)
const RAISE_RATE := 11.0
const LOWER_RATE := 3.2
const HOLD_UP := 0.7
## The arms (view space, model metres: x right, y up, z back to the camera).
## The bow arm's forearm points back at the left elbow at rest and at the left
## shoulder (a straight arm) with the bow up. The drawing arm's forearm points
## at the right elbow while the hand is forward, and lies along DRAW_LINE
## (wrist to elbow) as the hand comes back to full draw.
const BOW_ELBOW := Vector3(-0.24, -0.42, -0.22)
const BOW_SHOULDER := Vector3(-0.27, -0.22, 0.0)
const DRAW_ELBOW := Vector3(0.4, -0.46, -0.05)
const DRAW_LINE := Vector3(0.38, -0.22, 0.9)
## How far each arm turns about what it holds (the riser, the string) and
## bends at the wrist to get there (degrees).
const BOW_SWIVEL := 22.0
const BOW_WRIST := 32.0
const DRAW_SWIVEL := 75.0
const DRAW_WRIST := 32.0
## Bend of each limb segment per unit of bend (root to curl), and the bend's search range.
const BEND_SHARE := [0.55, 1.0, 1.0, 0.85, 0.2]
const BEND_MAX := 0.6
## The string after a loose: ring frequency (Hz) and damping ratio.
const STRING_HZ := 7.5
const STRING_DAMP := 0.22
## How fast the string follows a let-down (1/s).
const LET_DOWN_RATE := 9.0
## The drawing hand's follow-through after a loose (metres back, seconds).
const FOLLOW := 0.03
const FOLLOW_TIME := 0.14
## Fatigue tremble (model metres and degrees at full fatigue).
const TREMBLE_POS := 0.006
const TREMBLE_ROT := 1.6
## The nock reload's hand path: offsets from the nocking point (Godot model
## space: x right, y up, z back) and turns (degrees), at reload progress k.
## The first key is replaced by where the hand let go. The hand drops to the
## hip quiver (out of sight, low on the right), comes back with an arrow,
## lays it on the shelf and slides it back onto the string.
const NOCK_KEYS := [
	[0.0, Vector3(0.0, 0.0, 0.03), Vector3.ZERO],
	[0.26, Vector3(0.24, -0.42, 0.26), Vector3(-34.0, 0.0, -30.0)],
	[0.38, Vector3(0.25, -0.44, 0.25), Vector3(-38.0, 6.0, -34.0)],
	[0.6, Vector3(0.035, -0.035, -0.11), Vector3(7.0, -9.0, -6.0)],
	[0.72, Vector3(0.0, 0.01, -0.07), Vector3(0.0, -2.0, 0.0)],
	[0.84, Vector3(0.0, 0.0, 0.0), Vector3.ZERO],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## The bow's own tilt while an arrow is nocked (offset, degrees), in and out.
const NOCK_TILT_POS := Vector3(-0.01, 0.008, 0.0)
const NOCK_TILT_ROT := Vector3(3.0, -4.0, 7.0)
## Reload progress at which the new arrow is in the hand, and is nocked.
const ARROW_IN := 0.34
const NOCKED := 0.84
## Inspect: seconds, the pluck and the spin.
const INSPECT_LENGTH := 3.4
const PLUCK_AT := 0.95
const SPIN_START := 1.55
const SPIN_END := 2.45
const INSPECT_POSES := [
	[0.0, Vector3(0.0, -0.06, -0.72), Vector3(0.0, 0.0, 0.0)],
	[0.16, Vector3(-0.02, 0.0, -0.8), Vector3(6.0, 36.0, 16.0)],
	[0.42, Vector3(-0.02, 0.0, -0.8), Vector3(4.0, 40.0, 14.0)],
	[0.5, Vector3(0.0, -0.02, -0.82), Vector3(0.0, 18.0, 4.0)],
	[0.76, Vector3(0.0, -0.02, -0.82), Vector3(0.0, 14.0, 2.0)],
	[0.86, Vector3(0.02, -0.04, -0.76), Vector3(-6.0, 26.0, -4.0)],
	[1.0, Vector3(0.0, -0.06, -0.72), Vector3(0.0, 4.0, 0.0)],
]
const GOLD := [Color(1.0, 0.86, 0.36), Color(1.0, 0.98, 0.88), Color(1.0, 0.6, 0.2)]

var _top: Array[Node3D] = []
var _bottom: Array[Node3D] = []
var _top_rest: Array[Transform3D] = []
var _bottom_rest: Array[Transform3D] = []
var _tip_top: Node3D
var _tip_bottom: Node3D
var _strings: Array[Node3D] = []
var _string_rest: Array[Transform3D] = []
var _arrow: Node3D
var _arrow_rest := Transform3D.IDENTITY
var _hand: Node3D
var _hand_rest := Transform3D.IDENTITY
var _bow_hand: Node3D
var _bow_hand_rest := Transform3D.IDENTITY
## Each arm's palm node (Arm<S>Hand), its rest, and in the arm's own space its
## wrist and its forearm's direction (wrist to elbow).
var _palm_r: Node3D
var _palm_l: Node3D
var _palm_r_rest := Transform3D.IDENTITY
var _palm_l_rest := Transform3D.IDENTITY
var _wrist_r := Vector3.ZERO
var _wrist_l := Vector3.ZERO
var _fore_r := Vector3.BACK
var _fore_l := Vector3.BACK
## The drawn hold in the idle hold's frame, how far the bow is raised to it
## (0..1) and the drawing hand's place before the arms are aimed.
var _drawn := Transform3D.IDENTITY
var _raise := 0.0
var _hand_base := Transform3D.IDENTITY
var _reload_from := Vector3.ZERO
var _nock := Vector3.ZERO
## The string's half length (nock to groove) and its rest direction.
var _half := 0.6
var _rig: HandRig
var _glint: MeshInstance3D
## Nocking point offset (metres towards the camera) and its speed.
var _pull := 0.0
var _pull_speed := 0.0
var _snapping := false
var _since_loose := 10.0
var _loose_pull := 0.0
## True while the string hand holds the string (a draw can start).
var _hooked := true
var _was_reloading := false
var _clicked := false
var _time := 0.0
var _inspecting := false
var _pluck := 0.0
var _pluck_speed := 0.0
var _plucked := false
var _spun := false


func setup(v: WeaponView) -> void:
	for part in ["Arrow", "StringT", "StringB", "ArmR"]:
		v.register_part(part)
	for i in 5:
		var t := v.model.find_child("LimbT%d" % i, true, false) as Node3D
		var b := v.model.find_child("LimbB%d" % i, true, false) as Node3D
		if t == null or b == null:
			return
		_top.append(t)
		_bottom.append(b)
		_top_rest.append(t.transform)
		_bottom_rest.append(b.transform)
	_tip_top = v.model.find_child("TipT", true, false) as Node3D
	_tip_bottom = v.model.find_child("TipB", true, false) as Node3D
	for key in ["StringT", "StringB"]:
		var s := v.part(key)
		_strings.append(s)
		_string_rest.append(s.transform if s else Transform3D.IDENTITY)
	_arrow = v.part("Arrow")
	_arrow_rest = v.rest_transform("Arrow")
	_hand = v.part("ArmR")
	_hand_rest = v.rest_transform("ArmR")
	_bow_hand = v.part("ArmL")
	_bow_hand_rest = v.rest_transform("ArmL")
	_hand_base = _hand_rest
	_palm_r = v.model.find_child("ArmRHand", true, false) as Node3D
	_palm_l = v.model.find_child("ArmLHand", true, false) as Node3D
	var elbow_r := v.model.find_child("ElbowR", true, false) as Node3D
	var elbow_l := v.model.find_child("ElbowL", true, false) as Node3D
	if _palm_r and elbow_r:
		_palm_r_rest = _palm_r.transform
		_wrist_r = _palm_r.position
		_fore_r = (elbow_r.position - _wrist_r).normalized()
	if _palm_l and elbow_l:
		_palm_l_rest = _palm_l.transform
		_wrist_l = _palm_l.position
		_fore_l = (elbow_l.position - _wrist_l).normalized()
	var hold := Transform3D(Basis.from_euler(v.data.view_rotation_degrees * (PI / 180.0)), v.data.view_position)
	_drawn = hold.affine_inverse() * Transform3D(Basis.from_euler(DRAWN_ROT * (PI / 180.0)), DRAWN_POS)
	var nock := v.model.find_child("Nock", true, false) as Node3D
	_nock = nock.position if nock else _arrow_rest.origin
	_half = _in_model(v, _tip_top).distance_to(_nock) if _tip_top else 0.6
	_rig = HandRig.of(v.model)
	var holo := v.part("CellHolo")
	if holo:
		holo.visible = false
	_glint = _make_glint(v)


func fired(_v: WeaponView) -> void:
	_snapping = true
	_since_loose = 0.0
	_loose_pull = _pull
	_hooked = false
	if _rig:
		_rig.set_pose(&"R", HandRig.Pose.OPEN, 0.05)


func event(v: WeaponView, name: StringName) -> void:
	if name == BullseyeBowMode.BULLSEYE_EVENT and _arrow:
		var muzzle := v.model.find_child("Muzzle", true, false) as Node3D
		if muzzle:
			v.spark_burst(_in_model(v, muzzle), Vector3(0, 0, -1), GOLD, 14, 3.0, 0.3, 0.012)


func update(v: WeaponView, delta: float) -> void:
	if _top.is_empty():
		return
	_time += delta
	_since_loose += delta
	var w := v.player.weapons if v.player else null
	var held := w != null and w.current == v.data
	var reloading := held and w.is_reloading()
	var draw := w.shown_charge() if held else 0.0
	var mode := w.mode as BullseyeBowMode if held else null
	var loaded := not held or w.magazine() > 0

	# The string: drawn with the charge, a snap and ring after a loose, eased home on a let-down.
	var goal := draw * DRAW_LEN
	if draw > 0.0:
		_pull = goal
		_pull_speed = 0.0
		_snapping = false
	elif _snapping:
		var omega := TAU * STRING_HZ
		_pull_speed += (-omega * omega * _pull - 2.0 * STRING_DAMP * omega * _pull_speed) * delta
		_pull += _pull_speed * delta
		if absf(_pull) < 0.0004 and absf(_pull_speed) < 0.02:
			_pull = 0.0
			_snapping = false
	else:
		_pull = lerpf(_pull, 0.0, 1.0 - exp(-LET_DOWN_RATE * delta))
	_pose_string(v, _pull + _pluck)

	# The arrow rides the nocking point; gone once loosed until the nock brings another.
	if reloading:
		if not _was_reloading:
			_reload_from = _hand_base.origin - _hand_rest.origin if _hand else Vector3.ZERO
		_pose_reload(w.reload_progress())
	else:
		if _was_reloading:
			_hooked = true
			if _rig:
				_rig.set_pose(&"R", HandRig.Pose.GRIP, 0.1)
		_clicked = false
		if loaded and not _hooked and _since_loose > 0.3:
			# A full quiver brought back by a pick-up, or a let-down: hook again.
			_hooked = true
			if _rig:
				_rig.set_pose(&"R", HandRig.Pose.GRIP, 0.12)
		if _arrow:
			_arrow.visible = loaded and _hooked
			_arrow.transform = Transform3D(_arrow_rest.basis, _arrow_rest.origin + Vector3(0, 0, maxf(0.0, _pull)))
		if _hand and not _inspecting:
			var at := maxf(0.0, _pull)
			if not _hooked:
				# Follow-through: the open hand drifts back past where it let go.
				at = _loose_pull + FOLLOW * smoothstep(0.0, FOLLOW_TIME, _since_loose)
			_hand_base = Transform3D(_hand_rest.basis, _hand_rest.origin + Vector3(0.012 * at / DRAW_LEN, 0, at))
	_was_reloading = reloading

	# The bow comes up as it is drawn and stays up while arrows are flying.
	var up := draw > 0.0 or reloading or _since_loose < HOLD_UP
	var lift := clampf(draw * 2.2, 0.0, 1.0) if draw > 0.0 else (1.0 if up else 0.0)
	lift = maxf(lift, _raise) if up else lift
	_raise = lerpf(_raise, lift, 1.0 - exp(-(RAISE_RATE if lift > _raise else LOWER_RATE) * delta))
	var aim := v.player.aim_blend if v.player else v.staged_aim
	var stance := Transform3D.IDENTITY.interpolate_with(_drawn, smoothstep(0.0, 1.0, _raise) * (1.0 - aim))

	# The arrowhead glints in the Bullseye window; past it the bow arm trembles.
	var window := mode != null and mode.in_window()
	if _glint:
		_glint.visible = window
		if window:
			_glint.scale = Vector3.ONE * (0.8 + 0.5 * absf(sin(_time * 22.0)))
			_glint.rotate_object_local(Vector3.BACK, delta * 6.0)
	if not _inspecting:
		var tired := clampf(mode.fatigue() / 1.5, 0.0, 1.0) if mode else 0.0
		var shake := tired * tired
		var pos := Vector3(sin(_time * 31.0) + 0.5 * sin(_time * 57.0), sin(_time * 27.0 + 1.0) + 0.5 * sin(_time * 49.0), 0.0) * TREMBLE_POS * shake
		var rot := Vector3(sin(_time * 23.0), sin(_time * 19.0 + 2.0), sin(_time * 29.0)) * deg_to_rad(TREMBLE_ROT) * shake
		var tilt := Transform3D.IDENTITY
		if reloading:
			# The bow tips in a little for the arrow, and back as it is nocked.
			var k := w.reload_progress()
			var u := smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.72, 0.95, k))
			tilt = Transform3D(Basis.from_euler(NOCK_TILT_ROT * (PI / 180.0) * u), NOCK_TILT_POS * u)
		v.model.transform = stance * tilt * Transform3D(Basis.from_euler(rot), pos)
		_pose_arms(v, _bow_hand_rest)


## Lays both arms so their forearms come from the body: the bow arm from the
## left elbow (at rest) or shoulder (bow up), the drawing arm from the right
## elbow, falling in behind the arrow as the hand comes back to the face.
## `bow_base`: the bow hand's place before it is aimed (model space).
func _pose_arms(v: WeaponView, bow_base: Transform3D) -> void:
	var to_model := (v.global_transform.affine_inverse() * v.model.global_transform).affine_inverse()
	var aim := v.player.aim_blend if v.player else v.staged_aim
	if _bow_hand and _palm_l:
		var out := maxf(smoothstep(0.0, 1.0, _raise), aim)
		var elbow := to_model * BOW_ELBOW.lerp(BOW_SHOULDER, out)
		_aim_arm(_bow_hand, _palm_l, bow_base, _palm_l_rest, _wrist_l, _fore_l, bow_base.origin, bow_base.basis * Vector3(0.0, 1.0, -0.06).normalized(),
			elbow, Vector3.ZERO, 0.0, BOW_SWIVEL, BOW_WRIST)
	if _hand and _palm_r:
		var back := smoothstep(0.25, 1.0, (_hand_base.origin.z - _hand_rest.origin.z) / DRAW_LEN)
		var pivot := _hand_base * (_hand_rest.affine_inverse() * _nock)
		_aim_arm(_hand, _palm_r, _hand_base, _palm_r_rest, _wrist_r, _fore_r, pivot, (_hand_base.basis * _hand_rest.basis.inverse() * Vector3.UP).normalized(),
			to_model * DRAW_ELBOW, (to_model.basis * DRAW_LINE).normalized(), back, DRAW_SWIVEL, DRAW_WRIST)


## Aims one arm. `base` is the arm node's place before aiming; `wrist` and
## `fore` its wrist and forearm direction in its own space. The forearm should
## point at `elbow` (model space), blended by `line_share` towards the
## direction `line`. The arm turns (its hand with it) about `axis` through
## `pivot` by at most `swivel_max` degrees, then the forearm alone bends at
## the wrist by at most `wrist_max` for the rest; the hand stays on its hold.
func _aim_arm(arm: Node3D, palm: Node3D, base: Transform3D, palm_rest: Transform3D, wrist: Vector3, fore: Vector3, pivot: Vector3, axis: Vector3,
		elbow: Vector3, line: Vector3, line_share: float, swivel_max: float, wrist_max: float) -> void:
	var at := base * wrist
	var dir := (base.basis * fore).normalized()
	var want := (elbow - at).normalized()
	if line_share > 0.0 and line != Vector3.ZERO:
		want = want.slerp(line, line_share).normalized()
	var turn := 0.0
	var a := dir - axis * dir.dot(axis)
	var b := want - axis * want.dot(axis)
	if a.length() > 0.05 and b.length() > 0.05:
		turn = clampf(a.signed_angle_to(b, axis), -deg_to_rad(swivel_max), deg_to_rad(swivel_max))
	var spin := Transform3D(Basis(axis, turn), pivot - Basis(axis, turn) * pivot)
	var turned := spin * base
	at = spin * at
	dir = spin.basis * dir
	var bend := Basis.IDENTITY
	var cross := dir.cross(want)
	if cross.length() > 0.001:
		bend = Basis(cross.normalized(), minf(dir.angle_to(want), deg_to_rad(wrist_max)))
	arm.transform = Transform3D(bend, at - bend * at) * turned
	palm.transform = arm.transform.affine_inverse() * turned * palm_rest


## Pulls the nocking point back by `pull` (metres; negative: forward of
## brace), bends the limbs to keep the string's length and lays the string.
func _pose_string(v: WeaponView, pull: float) -> void:
	var nock := _nock + Vector3(0, 0, pull)
	var bend := 0.0
	if pull > 0.0005:
		var lo := 0.0
		var hi := BEND_MAX
		for _i in 14:
			var mid := (lo + hi) * 0.5
			_bend(mid)
			if _in_model(v, _tip_top).distance_to(nock) > _half:
				lo = mid
			else:
				hi = mid
		bend = (lo + hi) * 0.5
	elif pull < 0.0:
		# Past brace the limbs flick forward a touch with the string.
		bend = pull * 0.6
	_bend(bend)
	for i in 2:
		var s := _strings[i]
		var tip := _tip_top if i == 0 else _tip_bottom
		if s == null or tip == null:
			continue
		var along := _in_model(v, tip) - nock
		var y := along / _half
		var x := Vector3.RIGHT
		var z := x.cross(y.normalized())
		s.transform = Transform3D(Basis(x, y, z), nock)


func _bend(b: float) -> void:
	for i in _top.size():
		_top[i].transform = Transform3D(_top_rest[i].basis * Basis(Vector3.RIGHT, b * BEND_SHARE[i]), _top_rest[i].origin)
		_bottom[i].transform = Transform3D(_bottom_rest[i].basis * Basis(Vector3.RIGHT, -b * BEND_SHARE[i]), _bottom_rest[i].origin)


## The nock reload at progress k: the hand's path (NOCK_KEYS) about the
## nocking point, the arrow in it from ARROW_IN, the click at NOCKED.
func _pose_reload(k: float) -> void:
	var off := Vector3.ZERO
	var rot := Vector3.ZERO
	for i in NOCK_KEYS.size() - 1:
		var a: Array = NOCK_KEYS[i]
		var b: Array = NOCK_KEYS[i + 1]
		if k <= float(b[0]) or i == NOCK_KEYS.size() - 2:
			var u := smoothstep(0.0, 1.0, clampf((k - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0))
			off = ((a[1] as Vector3) if i > 0 else Vector3.ZERO).lerp(b[1], u)
			rot = (a[2] as Vector3).lerp(b[2], u)
			break
	# Out of the follow-through: the first stretch starts where the hand let go.
	off += _reload_from * (1.0 - smoothstep(0.0, float(NOCK_KEYS[1][0]), k))
	var turn := Transform3D(Basis.from_euler(rot * (PI / 180.0)), Vector3.ZERO)
	var path := Transform3D(Basis.IDENTITY, _nock + off) * turn * Transform3D(Basis.IDENTITY, -_nock)
	if _hand:
		_hand_base = path * _hand_rest
	if _arrow:
		_arrow.visible = k >= ARROW_IN
		_arrow.transform = path * _arrow_rest
	if _rig:
		if k < ARROW_IN and _hooked:
			_hooked = false
			_rig.set_pose(&"R", HandRig.Pose.RELAXED, 0.1)
		if k >= ARROW_IN * 0.8 and not _clicked and k < NOCKED:
			_clicked = true
			_rig.set_pose(&"R", HandRig.Pose.PINCH, 0.08)
		if k >= NOCKED and not _hooked:
			_hooked = true
			_rig.set_pose(&"R", HandRig.Pose.GRIP, 0.1)


# --- inspect -------------------------------------------------------------------

func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(_v: WeaponView) -> void:
	_inspecting = true
	_plucked = false
	_spun = false
	_pluck = 0.0
	_pluck_speed = 0.0
	if _rig:
		_rig.set_pose(&"R", HandRig.Pose.RELAXED, 0.15)


func inspect(v: WeaponView, t: float) -> void:
	var delta := 1.0 / 60.0
	# The drawing hand lets go and drops out of the way, coming back at the end.
	var away := smoothstep(0.05, 0.35, t) * (1.0 - smoothstep(INSPECT_LENGTH - 0.6, INSPECT_LENGTH - 0.2, t))
	if _hand:
		var turn := Transform3D(Basis.from_euler(Vector3(-0.5, 0.0, -0.7) * away), Vector3.ZERO)
		_hand_base = Transform3D(Basis.IDENTITY, _nock + Vector3(0.16, -0.34, 0.12) * away) * turn \
			* Transform3D(Basis.IDENTITY, -_nock) * _hand_rest
	# The pluck: the string is drawn a little and let go, ringing out.
	if t >= PLUCK_AT - 0.18 and t < PLUCK_AT:
		_pluck = 0.05 * smoothstep(PLUCK_AT - 0.18, PLUCK_AT, t)
		_pluck_speed = 0.0
	elif t >= PLUCK_AT:
		if not _plucked:
			_plucked = true
			Sfx.play(&"bb_twang", -6.0)
		var omega := TAU * STRING_HZ * 1.6
		_pluck_speed += (-omega * omega * _pluck - 2.0 * 0.08 * omega * _pluck_speed) * delta
		_pluck += _pluck_speed * delta
	# The spin: a full turn of the bow on its grip, eased in and out.
	if t >= SPIN_START and t <= SPIN_END + 0.05:
		var u := smoothstep(SPIN_START, SPIN_END, t)
		var grip := Vector3(0.0, -0.07, 0.01)
		var spin := Transform3D(Basis.IDENTITY, grip) * Transform3D(Basis(Vector3.UP, u * TAU), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -grip)
		v.model.transform = spin
		# The bow turns in the loosened bow hand: the hand and its arm stay put.
		_pose_arms(v, spin.affine_inverse() * _bow_hand_rest)
		if not _spun:
			_spun = true
			Sfx.play(&"bb_spin", -8.0)
	else:
		v.model.transform = Transform3D.IDENTITY
		_pose_arms(v, _bow_hand_rest)


func inspect_end(v: WeaponView) -> void:
	_inspecting = false
	_pluck = 0.0
	_pluck_speed = 0.0
	v.model.transform = Transform3D.IDENTITY
	_hand_base = _hand_rest
	_pose_arms(v, _bow_hand_rest)
	if _rig:
		_rig.set_pose(&"R", HandRig.Pose.GRIP, 0.12)


# --- helpers ----------------------------------------------------------------------

## `node`'s position in the model's space.
func _in_model(v: WeaponView, node: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != v.model:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.origin


## A small gold star on the arrowhead that flickers in the Bullseye window.
func _make_glint(v: WeaponView) -> MeshInstance3D:
	var muzzle := v.model.find_child("Muzzle", true, false) as Node3D
	if muzzle == null:
		return null
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _star_texture()
	m.albedo_color = Color(1.0, 0.85, 0.35)
	quad.material = m
	var g := MeshInstance3D.new()
	g.mesh = quad
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visible = false
	muzzle.add_child(g)
	return g


## A four-point twinkle, drawn once.
static func _star_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / size * 2.0 - Vector2.ONE
			var cross := maxf(0.0, 1.0 - absf(p.x) * 14.0) * maxf(0.0, 1.0 - absf(p.y)) + maxf(0.0, 1.0 - absf(p.y) * 14.0) * maxf(0.0, 1.0 - absf(p.x))
			var core := maxf(0.0, 1.0 - p.length() * 2.2)
			var a := clampf(cross + core * core, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
