class_name WeaponMode
extends RefCounted
## Optional gameplay a weapon adds on top of the data-driven fire modes
## (WeaponData.mode_script): a minigun that spins up before it fires, rounds
## that fly and ricochet off scenery on their own, a harpoon that reels in
## what it hits, a chain saw on the melee action. The WeaponController makes one for the held weapon and
## calls the hooks below; every hook defaults to "nothing special". The
## viewmodel's own moving parts belong in WeaponData.view_script, which can
## read the held weapon's mode (WeaponController.mode).

var controller: WeaponController
var data: WeaponData


## The mode of `weapon` for `owner_controller`, or null when it has none.
static func create(weapon: WeaponData, owner_controller: WeaponController) -> WeaponMode:
	if weapon.mode_script == null:
		return null
	var mode: WeaponMode = weapon.mode_script.new()
	mode.controller = owner_controller
	mode.data = weapon
	return mode


## Every physics frame while the weapon can be used. `spinning` is true while
## fire is held and nothing (a reload, a switch, a sprint) stops the weapon.
## Return false to hold the shot back.
func trigger(_spinning: bool, _delta: float) -> bool:
	return true


## The trigger was let go for good: a reload started, the weapon was put away
## or the controls were taken away.
func end_trigger() -> void:
	pass


## Fires one pellet along `dir` from `from` itself (its own projectile) with
## damage scale `scale`. Return false to let the controller fire it.
func launch(_from: Vector3, _dir: Vector3, _scale: float) -> bool:
	return false


## Adjusts the hits one shot gathered (WeaponController._record entries:
## damage, push...) before they are dealt, and adds the shot's own effects.
## `end` is where the shot stopped, `power` the charge (1 when uncharged).
func shape_hits(_hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	pass


## Extra move speed multiplier on top of WeaponData.move_speed_scale.
func move_scale() -> float:
	return 1.0


## Every physics frame while the weapon can be used: `held` is true while the
## melee action (WeaponController.MELEE_ACTION) is held and nothing stops the
## weapon. A mode with a melee attack (the Ripsaw's chain saw) runs it here;
## its hits go through WeaponController.melee_hit.
func melee(_held: bool, _delta: float) -> void:
	pass


## How close (metres) a zombie must be for the melee to reach it right now
## (0 = no melee, or not ready). The playtest bot reads it.
func melee_reach() -> float:
	return 0.0


## 0-1 fill of the mode's own gauge (a saw's fuel), drawn by the HUD beside
## the ammo counter; negative for none.
func gauge() -> float:
	return -1.0


## A reload finished (the magazine is full again).
func reloaded() -> void:
	pass


## The weapon is put away: free anything the mode made.
func dispose() -> void:
	pass
