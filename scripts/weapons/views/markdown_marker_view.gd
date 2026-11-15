extends RefCounted
## Markdown Marker viewmodel motion (WeaponData.view_script): every shot
## clacks the squeeze lever up toward the grip, spits the loaded tag out of
## the nozzle (the next one slides out of the slot) and turns the tag-roll drum
## a quarter turn with a little overshoot. The three pips in the flank window
## show the tags on the zombie hit last and blink when it is ready to pop; a
## Clearance Pop flashes them all and kicks the drum. The reload
## (markdown_marker_reload.gd) changes the roll.

const PIPS := 3
## Seconds: the lever clacks up and springs back; the tag flies, the next slides out.
const LEVER_TIME := 0.15
const LEVER_DEG := -16.0
const TAG_OUT := 0.05
const TAG_FEED := 0.12
const TAG_OFFSET := Vector3(0.0, 0.0, -0.06)
## Degrees the drum turns per shot, and how long the turn takes.
const DRUM_STEP := 90.0
const DRUM_TIME := 0.12
const CONFETTI := [Color(1.0, 0.31, 0.64), Color(1.0, 0.82, 0.25), Color(0.13, 0.85, 0.85), Color(1.0, 0.96, 0.88)]

var _lever: Node3D
var _tag: Node3D
var _drum: Node3D
var _muzzle: Node3D
var _pips: Array[Node3D] = []
var _since_shot := 10.0
var _drum_from := 0.0
var _drum_to := 0.0
var _popped := false


func setup(v: WeaponView) -> void:
	for p in ["Lever", "Tag", "Drawer", "ReceiptHolo"]:
		v.register_part(p)
	for i in PIPS:
		v.register_part("Pip%d" % i)
		_pips.append(v.part("Pip%d" % i))
	_lever = v.part("Lever")
	_tag = v.part("Tag")
	_drum = v.part("Drum")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	var receipt := v.part("ReceiptHolo")
	if receipt:
		receipt.visible = false


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	_drum_from = _drum_to
	_drum_to = fmod(_drum_to + DRUM_STEP, 360.0)
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.15, -1), CONFETTI, 4, 0.7, 0.16, 0.006)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	if v.is_reloading():
		_drum_to = 0.0
		_drum_from = 0.0
		return
	var mode := _mode(v)
	if _lever:
		var k := sin(clampf(_since_shot / LEVER_TIME, 0.0, 1.0) * PI)
		_lever.transform = v.rest_transform("Lever") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(LEVER_DEG * k)), Vector3.ZERO)
	_pose_tag(v)
	_pose_drum(v, mode)
	_pose_pips(mode)


func event(_v: WeaponView, _name: StringName) -> void:
	pass


## The drum eases to its next quarter turn (a pop gives it an extra half spin).
func _pose_drum(v: WeaponView, mode: MarkdownMarkerMode) -> void:
	if _drum == null:
		return
	var t := clampf(_since_shot / DRUM_TIME, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - t, 3.0) + sin(t * PI) * 0.12
	var goal := _drum_to
	if _drum_to < _drum_from:
		goal += 360.0
	var angle := lerpf(_drum_from, goal, ease_k)
	if mode and mode.since_pop < 0.3:
		angle += 180.0 * (1.0 - pow(1.0 - mode.since_pop / 0.3, 2.0))
	_drum.transform = v.rest_transform("Drum") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-angle)), Vector3.ZERO)


## The loaded tag: flying out, hidden, sliding out of the slot, or at rest.
func _pose_tag(v: WeaponView) -> void:
	if _tag == null:
		return
	var rest := v.rest_transform("Tag")
	var t := _since_shot
	if t < TAG_OUT:
		_tag.visible = true
		_tag.transform = Transform3D(rest.basis, rest.origin + TAG_OFFSET * (t / TAG_OUT) * 2.0)
	elif t < TAG_OUT + 0.03 or _magazine(v) <= 0:
		_tag.visible = false
	elif t < TAG_FEED:
		_tag.visible = true
		var k := smoothstep(TAG_OUT + 0.03, TAG_FEED, t)
		_tag.transform = Transform3D(rest.basis.scaled(Vector3(1.0, 1.0, maxf(0.05, k))), rest.origin + Vector3(0, 0, 0.012) * (1.0 - k))
	else:
		_tag.visible = true
		_tag.transform = rest


## Pips lit for the tags on the last zombie hit; a full stack blinks, a pop flashes all three.
func _pose_pips(mode: MarkdownMarkerMode) -> void:
	var lit := 0
	var blink := true
	if mode:
		var fresh := mode.since_hit < PriceTags.TAG_TIME
		lit = mode.last_tags if fresh else 0
		if lit >= PIPS:
			blink = fmod(mode.since_hit * 6.0, 1.0) < 0.6
		if mode.since_pop < 0.45:
			lit = PIPS
			blink = fmod(mode.since_pop * 14.0, 1.0) < 0.5
	for i in _pips.size():
		if _pips[i]:
			_pips[i].visible = i < lit and blink


func _mode(v: WeaponView) -> MarkdownMarkerMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as MarkdownMarkerMode


func _magazine(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return v.data.magazine_size
	return p.weapons.magazine()
