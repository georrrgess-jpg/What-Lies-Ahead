class_name TinSergeantMode
extends WeaponMode
## Tin Sergeant: every shot lobs a wind-up tin soldier (TinSoldier) on the
## WeaponData's launch velocity, so the aim arc preview shows where it lands.
## The soldiers march on the zombies themselves and pop on them; up to
## TinSoldier.MAX_SOLDIERS are out at once (one more pops the oldest), and
## they keep marching when the weapon is put away.
##
## "Fall in!": while the sights are up, a flag (TinRallyFlag) stands where
## the aim arc lands and the whole squad marches to it, forms a ring round it
## and guards it, going only for zombies within TinSoldier.RALLY_GUARD of it.
## The flag holds TinSoldier.RALLY_KEEP seconds after the sights come down
## (and goes with the weapon). The viewmodel
## (scripts/weapons/views/tin_sergeant_view.gd) lights a lamp per soldier out
## and raises its pennant while the flag is planted.

const TRAIT := "MARCHING SQUAD"
## Aim blend (Player.ads) from which the flag follows the aim.
const AIM_IN := 0.8
## Seconds between landing-point traces while aiming.
const TRACE_EVERY := 0.05
const TRACE_STEP := 0.05
const MASK_WORLD := 1
## Share of shots that strike a zombie in flight (the Arsenal's DPS).
const DIRECT_SHARE := 0.4
const FALL_IN_SOUND := &"ts_fall_in"

var _flag: TinRallyFlag
var _trace := 0.0
var _was_aimed := false


func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	TinSoldier.launch(controller, from, WeaponController.launch_velocity(dir, data), data)
	return true


func trigger(_spinning: bool, delta: float) -> bool:
	var p := controller.player
	var aimed := p.ads >= AIM_IN and not controller.is_switching() and p.weapon_ready()
	var planted := false
	if aimed:
		_trace -= delta
		if _trace <= 0.0:
			_trace = TRACE_EVERY
			var at := _landing_point()
			if at != Vector3.INF:
				planted = not _was_aimed
				TinSoldier.set_rally(controller, at)
				if planted:
					Sfx.play(FALL_IN_SOUND, -6.0)
				_was_aimed = true
	else:
		_was_aimed = false
	_show_flag(planted, delta)
	return true


## Soldiers of this player out in the field.
func soldiers_out() -> int:
	return TinSoldier.live(controller).size()


## True while the squad has a flag to fall in on.
func rallying() -> bool:
	return TinSoldier.rally_of(controller) != Vector3.INF


func dispose() -> void:
	TinSoldier.clear_rally(controller)
	if _flag and is_instance_valid(_flag):
		_flag.queue_free()
	_flag = null


## Each soldier pops for full damage on the zombie it marches on; some strike
## it in flight too.
func arsenal_dps(_base: float) -> float:
	var hit := data.damage + data.direct_hit_bonus * DIRECT_SHARE
	return hit * data.magazine_size / (data.magazine_size * data.fire_interval + data.reload_time)


## Where a soldier fired now would land: the launch arc traced against the
## world (as ArcPreview does), or Vector3.INF when it flies off.
func _landing_point() -> Vector3:
	var p := controller.player
	var eye := p.aim_transform()
	var from := p.view.muzzle_position()
	var v := WeaponController.launch_velocity(-eye.basis.z, data)
	var space := p.get_world_3d().direct_space_state
	var t := 0.0
	while t < data.projectile_fuse:
		var nv := v + Vector3.DOWN * data.projectile_gravity * TRACE_STEP
		var to := from + nv * TRACE_STEP
		var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
		q.exclude = [p.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			if Vector3(hit["normal"]).y >= 0.5:
				return hit["position"]
			# A wall: the soldier drops to the floor at its foot.
			var foot := Vector3(hit["position"]) + Vector3(hit["normal"]) * 0.3
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot, foot + Vector3.DOWN * 8.0, MASK_WORLD))
			return Vector3.INF if down.is_empty() else Vector3(down["position"])
		from = to
		v = nv
		t += TRACE_STEP
	return Vector3.INF


func _show_flag(planted: bool, delta: float) -> void:
	var at := TinSoldier.rally_of(controller)
	if at == Vector3.INF and _flag == null:
		return
	if _flag == null or not is_instance_valid(_flag):
		var level := controller.player.get_parent()
		if level == null:
			return
		_flag = TinRallyFlag.new()
		level.add_child(_flag)
	_flag.show_at(at, TinSoldier.rally_left(controller), planted, delta)
