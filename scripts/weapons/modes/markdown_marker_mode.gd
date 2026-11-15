class_name MarkdownMarkerMode
extends WeaponMode
## Markdown Marker: every shot spits a glowing price-tag dart (MarkerDart)
## from the nozzle at the point under the crosshair, with a slight drop. A
## dart that hits sticks a tag on the zombie (PriceTags): +10% damage taken
## per tag from every weapon, up to three. A dart that hits a zombie already
## carrying three sets off a Clearance Pop instead: confetti and coins, splash
## damage round it, a tag on every neighbour it reaches and two tags back in
## the magazine. So the trick is three precise tags, then the pop (or the
## primary on a marked-down heavy). The drum, lever and stack pips on the
## viewmodel move in scripts/weapons/views/markdown_marker_view.gd.

## Tags on the zombie the last dart hit (0 after a pop): the view's stack pips.
var last_tags := 0
## Seconds since the last dart hit a zombie, and since the last pop.
var since_hit := 10.0
var since_pop := 10.0


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	MarkerDart.launch(self, from, to.normalized() if to.length() > 0.5 else dir, scale)
	return true


## A dart struck `z` at `point` after flying `travelled` metres.
func dart_hit(z: Zombie, point: Vector3, dir: Vector3, travelled: float, scale: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(z):
		return
	var tags := PriceTags.of(z)
	var full := tags.is_full()
	controller.strike(data, z, point, dir, travelled, scale)
	since_hit = 0.0
	if full:
		tags.clearance(controller, data)
		for i in PriceTags.POP_REFUND:
			controller.return_round(data)
		last_tags = 0
		since_pop = 0.0
	else:
		tags.stick(point)
		last_tags = tags.count()


func trigger(_spinning: bool, delta: float) -> bool:
	since_hit += delta
	since_pop += delta
	return true


## One cycle on a lone target: three tagged shots and the popping one (the
## stack's bonus on each, the pop's own damage), for the darts of two
## (POP_REFUND comes back).
func arsenal_dps(base: float) -> float:
	var n := PriceTags.MAX_TAGS + 1
	var marked := 0.0
	for i in n:
		marked += 1.0 + PriceTags.TAG_BONUS * i
	var per_dart := base / maxf(1.0, data.burst_damage())
	return base * marked / n + per_dart * PriceTags.POP_DAMAGE / n
