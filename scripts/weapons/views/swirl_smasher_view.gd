extends MeleeView
## Swirl Smasher viewmodel (art/models/swirl_smasher.glb): a giant lollipop.
##
##   candy   turns about its own axis (the disc's normal, Candy local Y): a
##           half turn on the draw, a slow drift at rest, spinning up with
##           the heavy's wind-up and carried on by the smash
##   bow     the cellophane bow flutters at rest and is flung by every swing
## Swings are wide, flat sweeps; the heavy is the shared overhead smash.

## Light swings: a wide flat sweep, slower and further round than a knife's.
const SWIRL_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.22, Vector3(0.14, 0.05, 0.06), Vector3(10.0, -14.0, -38.0)],
	[0.46, Vector3(-0.14, -0.02, -0.12), Vector3(-26.0, 16.0, 52.0)],
	[0.64, Vector3(-0.3, -0.1, -0.03), Vector3(-34.0, 26.0, 84.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Candy spin (degrees a second): drifting at rest, at full wind-up.
const DRIFT := 12.0
const SPIN_FULL := 900.0
const EQUIP_SPIN := 180.0
## Bow flutter: degrees and rate at rest, and how far a swing flings it.
const FLUTTER := 6.0
const FLUTTER_HZ := 1.3
const FLING := 22.0

var _candy: Node3D
var _bow: Node3D
var _spin := 0.0
var _speed := 0.0
var _fling := 0.0


func setup(view: WeaponView) -> void:
	super.setup(view)
	view.register_part("Candy")
	view.register_part("Bow")
	_candy = view.part("Candy")
	_bow = view.part("Bow")
	_spin = 0.0
	_speed = 0.0


func light_keys() -> Array:
	return SWIRL_LIGHT_KEYS


## The draw: swung up onto the shoulder from the lower right.
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := maxf(0.1, view.data.equip_time + 0.15)
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var k := 1.0 - ease_out(t / length)
	return [Vector3(0.06 * k, -0.12 * k, 0.0), Vector3(-50.0 * k, 0.0, -30.0 * k)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	var goal := DRIFT
	var swinging := false
	if mode:
		match mode.phase:
			MeleeMode.Phase.WINDUP:
				goal = lerpf(DRIFT, SPIN_FULL, mode.charge)
			MeleeMode.Phase.HEAVY:
				goal = SPIN_FULL * 0.6 * (1.0 - mode.progress())
				swinging = true
			MeleeMode.Phase.LIGHT:
				swinging = true
	_speed = lerpf(_speed, goal, 1.0 - exp(-4.0 * delta))
	_spin = fmod(_spin + _speed * delta, 360.0)
	var equip_turn := EQUIP_SPIN * (1.0 - ease_out(_equip / 0.5)) if view.player else 0.0
	if _candy:
		_candy.transform = view.rest_transform("Candy") * Transform3D(Basis(Vector3.UP, deg_to_rad(_spin + equip_turn)), Vector3.ZERO)
	_fling = lerpf(_fling, FLING if swinging else 0.0, 1.0 - exp(-8.0 * delta))
	if _bow:
		var sway := sin(_time * TAU * FLUTTER_HZ) * FLUTTER + _fling * sin(_time * 19.0)
		_bow.transform = view.rest_transform("Bow") * Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(sway * 0.4), deg_to_rad(sway))), Vector3.ZERO)
