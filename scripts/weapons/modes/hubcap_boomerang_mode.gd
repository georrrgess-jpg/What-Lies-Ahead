extends WeaponMode
## Road Rager (hubcap_boomerang): every shot is a spinning hubcap
## (HubcapShot) thrown at the point under the crosshair. It slices through
## every zombie out to max_range and again on its way home, where the catch
## slots it straight back into the magazine (it only costs ammo when lost).
## From the hip it carves a wide loop to the right; aimed down the sights it
## flies straight out and back down the same line (two hits on the target in
## its path). The launcher's tyres, rack and magnet move in
## scripts/weapons/views/hubcap_boomerang_view.gd.


func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	var throw_dir := to.normalized() if to.length() > 1.0 else dir
	HubcapShot.launch(controller.player.get_parent(), from, throw_dir, data, controller, controller.player.ads)
	return true


## Aimed throws hit their target on the way out and again on the way back,
## and catches keep the magazine topped up (no reloads while they land), so
## the three hubcaps' round trips set the pace.
func arsenal_dps(_base: float) -> float:
	return 2.0 * data.damage / maxf(data.fire_interval, _cycle() / data.magazine_size)


## Seconds from a throw at a target to its catch (out to max_range, the
## hang, home again), roughly.
func _cycle() -> float:
	var out := data.max_range / (data.projectile_speed * (1.0 - HubcapShot.OUT_SLOWDOWN / 3.0))
	var back := data.max_range / (data.projectile_speed * (HubcapShot.BACK_START + HubcapShot.BACK_TOP) * 0.5)
	return out + HubcapShot.HANG_TIME + back
