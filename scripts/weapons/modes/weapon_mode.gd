class_name WeaponMode
extends RefCounted
## Optional behaviour a weapon adds on top of the data-driven fire modes
## (WeaponData.mode_script): a minigun that spins up before it fires, rounds
## that fly and ricochet on their own, a harpoon that reels in what it hits.
## The WeaponController makes one for the held weapon and calls the hooks
## below; the WeaponView calls animate() every frame so the weapon's own
## parts can move with it (a drum that turns per shot, spinning barrels).
## Every hook defaults to "nothing special".

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


## Moves the weapon's own parts in `model` (its viewmodel), every frame.
func animate(_model: Node3D, _delta: float) -> void:
	pass


## The weapon is put away: free anything the mode made.
func dispose() -> void:
	pass


## A part of the viewmodel and its rest transform, for animate(): returns
## [node, transform], or [] when the model has no such part.
static func find_part(model: Node3D, part: String) -> Array:
	var node := model.find_child(part, true, false) as Node3D
	return [node, node.transform] if node else []
