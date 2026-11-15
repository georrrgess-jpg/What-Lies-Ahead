extends WeaponMode
## Teacup Twister: every shot is a lobbed teacup shell (TwisterVortex) that
## opens a whirl where it lands, dragging nearby zombies into a spinning
## cluster before it pops. It flies on the WeaponData's launch velocity, so
## the aim arc preview shows where it comes down. The cup turret on the
## viewmodel moves in scripts/weapons/views/teacup_twister_view.gd.

const TRAIT := "VORTEX"


func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	TwisterVortex.launch(controller, from, WeaponController.launch_velocity(dir, data), data)
	return true
