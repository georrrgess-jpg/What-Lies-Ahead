extends WeaponMode
## Shutterbug: every shot is a camera flash, not a bullet. It lights up a cone
## in front of the player and hits every zombie inside it that the flash can
## see (up to MAX_TARGETS, nearest first): full damage close in and on the
## centre line, less toward the rim and the far end. Each one it hits is
## dazzled (Dazzle): knocked out of its windup, staggered (once per
## Dazzle.COOLDOWN; never heavies or alphas) and slowed. Aiming down the
## sights zooms the flash: a narrower, longer cone that hits harder. The
## wheel of bulbs, the shutter and the focus ring move in
## scripts/weapons/views/shutterbug_view.gd.

## Reach (m) and half-angle (degrees) of the flash at the hip and fully aimed.
const HIP_REACH := 11.0
const AIM_REACH := 15.0
const HIP_CONE := 30.0
const AIM_CONE := 13.0
## Damage multiplier of a fully aimed flash.
const AIM_BONUS := 1.3
## Damage share at the rim of the cone and at the far end of its reach;
## full damage out to FULL_RANGE.
const RIM_SCALE := 0.6
const FAR_SCALE := 0.6
const FULL_RANGE := 3.0
const MAX_TARGETS := 8
## Seconds a 1-mass zombie stays dazed.
const DAZE := 1.4
const FLASH_COLOR := Color(0.85, 0.95, 1.0)
const DAZZLE_SOUND := &"gn8b_shutter_daze"

## Zombies the flash being fired caught: [zombie, point, direction, damage].
var _caught: Array = []


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	_caught.clear()
	var aim := controller.player.ads
	var reach := lerpf(HIP_REACH, AIM_REACH, aim)
	var cone := deg_to_rad(lerpf(HIP_CONE, AIM_CONE, aim))
	var power := data.damage * scale * lerpf(1.0, AIM_BONUS, aim)
	var eye := controller.player.aim_transform().origin
	for node in controller.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var chest := z.global_position + Vector3.UP * 1.05 * z.data.body_scale
		var to := chest - eye
		var dist := to.length()
		if dist > reach + 0.4 * z.data.body_scale:
			continue
		# The zombie's half-width counts, so one at the rim is still lit.
		var off := maxf(0.0, dir.angle_to(to) - atan2(0.4 * z.data.body_scale, maxf(0.5, dist)))
		if off > cone or not _sees(eye, chest):
			continue
		var k_rim := lerpf(1.0, RIM_SCALE, off / cone)
		var k_far := lerpf(1.0, FAR_SCALE, clampf((dist - FULL_RANGE) / (reach - FULL_RANGE), 0.0, 1.0))
		var facing := chest - Vector3(to.x, 0.0, to.z).normalized() * 0.3 * z.data.body_scale
		_caught.append([z, facing, to.normalized(), power * k_rim * k_far, dist])
	_caught.sort_custom(func(a: Array, b: Array) -> bool: return a[4] < b[4])
	if _caught.size() > MAX_TARGETS:
		_caught.resize(MAX_TARGETS)
	_flash(from, dir, reach, cone)
	return true


func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	var staggered := false
	for c in _caught:
		var z: Zombie = c[0]
		if not is_instance_valid(z) or z.is_dead():
			continue
		hits[z.get_instance_id()] = {"zombie": z, "damage": c[3], "head_damage": 0.0, "push": data.knockback, "head": false,
			"heads": 0, "count": 1, "point": c[1], "body_point": c[1], "dir": c[2]}
		staggered = Dazzle.of(z).apply(DAZE) or staggered
	if staggered:
		Sfx.play(DAZZLE_SOUND, -6.0, randf_range(0.96, 1.05))
	_caught.clear()


## Line of sight through scenery (zombies do not block the light).
func _sees(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, WeaponController.MASK_WORLD)
	return controller.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The flash: a burst of light that lights up the cone, and glints racing out.
func _flash(from: Vector3, dir: Vector3, reach: float, cone: float) -> void:
	var level := controller.player.get_parent()
	if level == null:
		return
	var k := Settings.flash_scale()
	if k > 0.05:
		var light := OmniLight3D.new()
		light.light_color = FLASH_COLOR
		light.omni_range = reach * 1.1
		light.omni_attenuation = 0.6
		light.light_energy = 5.0 * k
		light.shadow_enabled = false
		level.add_child(light)
		light.global_position = from + dir * 1.2
		var tw := light.create_tween()
		tw.tween_property(light, "light_energy", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(light.queue_free)
	WeaponFx.flash(level, from + dir * 0.15, FLASH_COLOR, 0.5, 0.1)
	WeaponFx.burst(level, from + dir * 0.3, dir, [Color.WHITE, FLASH_COLOR, Color(1.0, 0.95, 0.7)], 14, reach * 1.6, 0.22, 0.03,
		rad_to_deg(cone) * 0.8, Vector3.ZERO)
