extends RefCounted
## Jack Pot viewmodel motion (WeaponData.view_script). The loaded box sits
## lid-first in the launch cup (Box, its Lid hinged at the back). A shot
## throws it out of the cup and the crank (Crank) kicks back a quarter turn
## as the launch spring lets go; the next box rises out of the cup on a
## springy overshoot. While loaded the box quivers now and then and its lid
## lifts a crack (something inside wants out). The three bulbs on the top
## edge (Bulb0..2) light one per box out in the field; with all three out
## the oldest one's bulb blinks: the next shot pops it. The fat trigger
## (Trigger) pulls on every shot.

const BULBS := 3
## Seconds: the box leaves the cup, then the next one rises into it.
const THROW := 0.07
const LOAD_START := 0.14
const LOAD_TIME := 0.24
## The launch cup's axis in model space (it leans up 22 degrees; the box's
## mesh is built along it, its node is not turned).
const CUP_AXIS := Vector3(0.0, 0.375, -0.927)
## How far the box flies out of the cup before it vanishes, and how deep the
## next one starts (along the cup's axis, model units).
const THROW_DEPTH := 0.09
const LOAD_DEPTH := 0.07
const CRANK_KICK := -90.0
const TRIGGER_TIME := 0.1
## Every PEEK_EVERY seconds the loaded box's lid lifts a crack for PEEK_TIME.
const PEEK_EVERY := 2.6
const PEEK_TIME := 0.32
const PEEK_DEG := 22.0

var _box: Node3D
var _lid: Node3D
var _crank: Node3D
var _trigger: Node3D
var _bulbs: Array[Node3D] = []
var _since_shot := 10.0
var _time := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Box", "Lid", "Crank", "Drum", "Trigger"]:
		v.register_part(part)
	for i in BULBS:
		v.register_part("Bulb%d" % i)
		_bulbs.append(v.part("Bulb%d" % i))
	_box = v.part("Box")
	_lid = v.part("Lid")
	_crank = v.part("Crank")
	_trigger = v.part("Trigger")


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_time += delta
	_light_bulbs(v)
	if v.is_reloading():
		return
	_pose_box(v)
	if _crank:
		var kick := sin(PI * clampf(_since_shot / 0.22, 0.0, 1.0)) * (1.0 - clampf(_since_shot / 0.22, 0.0, 1.0) * 0.5)
		_crank.transform = v.rest_transform("Crank") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(CRANK_KICK * kick)), Vector3.ZERO)
	if _trigger:
		var k := sin(clampf(_since_shot / TRIGGER_TIME, 0.0, 1.0) * PI)
		_trigger.transform = v.rest_transform("Trigger") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0 * k)), Vector3.ZERO)


## Thrown out of the cup, the next one rising in (none when the magazine is
## empty), the idle quiver and the lid's peek.
func _pose_box(v: WeaponView) -> void:
	if _box == null:
		return
	var loaded := _magazine(v) > 0
	var depth := 0.0
	var squash := 1.0
	if _since_shot < THROW:
		depth = -THROW_DEPTH * _since_shot / THROW
		_box.visible = true
	elif _since_shot < LOAD_START:
		_box.visible = false
	else:
		_box.visible = loaded
		var u := clampf((_since_shot - LOAD_START) / LOAD_TIME, 0.0, 1.0)
		depth = LOAD_DEPTH * (1.0 - _spring(u))
		squash = 1.0 + 0.08 * sin(PI * clampf(u * 1.6, 0.0, 1.0)) * (1.0 - u)
	var quiver := 0.0
	var peek := fmod(_time, PEEK_EVERY)
	if peek < PEEK_TIME:
		quiver = sin(peek * 90.0) * 1.2 * sin(PI * peek / PEEK_TIME)
	var pose := Transform3D(Basis(CUP_AXIS, deg_to_rad(quiver)).scaled(Vector3.ONE * squash), CUP_AXIS * -depth)
	_box.transform = v.rest_transform("Box") * pose
	if _lid:
		var lift := PEEK_DEG * sin(PI * clampf(peek / PEEK_TIME, 0.0, 1.0)) if _since_shot > LOAD_START + LOAD_TIME else 0.0
		_lid.transform = v.rest_transform("Lid") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lift)), Vector3.ZERO)


## One bulb per box out; the oldest blinks when the next shot will pop it.
func _light_bulbs(v: WeaponView) -> void:
	var mode := _mode(v)
	var out := mode.boxes_out() if mode else 0
	for i in _bulbs.size():
		if _bulbs[i] == null:
			continue
		var on := i < out
		if on and out >= JackPotBox.MAX_BOXES and i == 0:
			on = fmod(_time, 0.4) < 0.24
		_bulbs[i].visible = on


func _magazine(v: WeaponView) -> int:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons.magazine()
	return v.data.magazine_size


func _mode(v: WeaponView) -> JackPotMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as JackPotMode


## A springy settle from 0 to 1 (overshoots a little).
static func _spring(u: float) -> float:
	return 1.0 - exp(-6.0 * u) * cos(11.0 * u)
