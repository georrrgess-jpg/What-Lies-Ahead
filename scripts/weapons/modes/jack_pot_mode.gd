class_name JackPotMode
extends WeaponMode
## Jack Pot: every shot lobs a jack-in-the-box mine (JackPotBox) on the
## WeaponData's launch velocity, so the aim arc preview shows where it lands.
## At most JackPotBox.MAX_BOXES are out at once: one more pops the oldest. The
## boxes stay out when the weapon is put away, so a field can be laid and
## held with the other gun. The viewmodel (scripts/weapons/views/jack_pot_view.gd)
## lights a bulb per box out.


func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	JackPotBox.launch(controller, from, WeaponController.launch_velocity(dir, data), data)
	return true


## How many of this player's boxes are out waiting to pop.
func boxes_out() -> int:
	return JackPotBox.live(controller).size()

