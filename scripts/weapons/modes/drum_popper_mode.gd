extends WeaponMode
## Gumball Drum Popper: every shot is a bouncy gumball (RicochetRound) aimed
## from the muzzle at the point under the crosshair, so it lands where the
## player aims, then ricochets off scenery on its own. The drum and pump
## motion is in scripts/weapons/views/drum_popper_view.gd.


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	RicochetRound.launch(controller, from, to.normalized() if to.length() > 0.5 else dir, data, scale)
	return true
