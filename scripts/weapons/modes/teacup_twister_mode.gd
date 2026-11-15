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


## The whirl's spin ticks on a captured zombie come on top of every cup's pop.
func arsenal_dps(base: float) -> float:
	var cups_per_second := base / maxf(1.0, data.burst_damage())
	var spin := floorf(TwisterVortex.WHIRL_TIME / TwisterVortex.WHIRL_TICK) * TwisterVortex.WHIRL_TICK_DAMAGE
	return base + cups_per_second * spin
