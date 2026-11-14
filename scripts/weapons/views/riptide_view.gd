extends RefCounted
## Riptide Harpoon viewmodel motion (WeaponData.view_script): the spear
## leaves the barrel when it fires while the spool reels the line in, then
## a new spear slides home from the muzzle (if one is left); charging draws
## the spear back into the barrel and ticks the spool backwards. The reload
## (riptide_reload.gd) loads a spear and winds the spool by hand.

## Seconds the spear is out after a shot, then how long it takes to slide home.
const SPEAR_OUT := 0.42
const SPEAR_LOAD := 0.16
## How far a new spear starts out of the muzzle, and how far a full charge draws it back (m).
const SPEAR_SLIDE := 0.12
const DRAW := 0.035
## Spool turns per second while reeling, and per second at full charge.
const REEL_TURNS := 2.6
const CHARGE_TURNS := -0.35

var _spear: Node3D
var _spool: Node3D
var _spear_rest := Transform3D.IDENTITY
var _spool_rest := Transform3D.IDENTITY
var _since_shot := 10.0
var _reel := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Harpoon", "Reel"]:
		v.register_part(part)
	_spear = v.part("Harpoon")
	_spool = v.part("Reel")
	_spear_rest = v.rest_transform("Harpoon")
	_spool_rest = v.rest_transform("Reel")


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	if v.is_reloading():
		_since_shot = 10.0
		_reel = 0.0
		return
	var w := v.player.weapons if v.player else null
	var held := w != null and w.current == v.data
	var charge := w.shown_charge() if held else 0.0
	_since_shot += delta
	var reeling := 1.0 - smoothstep(0.0, SPEAR_OUT, _since_shot)
	_reel = fmod(_reel + (REEL_TURNS * reeling + CHARGE_TURNS * charge) * TAU * delta, TAU)
	if _spool:
		_spool.transform = Transform3D(_spool_rest.basis * Basis(Vector3.RIGHT, _reel), _spool_rest.origin)
	if _spear == null:
		return
	_spear.visible = _since_shot >= SPEAR_OUT and (not held or w.magazine() > 0)
	var slide := 1.0 - smoothstep(SPEAR_OUT, SPEAR_OUT + SPEAR_LOAD, _since_shot)
	_spear.transform = Transform3D(_spear_rest.basis, _spear_rest.origin + Vector3(0.0, 0.0, -SPEAR_SLIDE * slide + DRAW * charge))
