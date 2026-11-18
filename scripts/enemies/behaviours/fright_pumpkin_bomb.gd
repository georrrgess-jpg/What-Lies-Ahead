class_name FrightPumpkinBombBehaviour
extends CityFirebugBehaviour
## Pumpkin Head (Ghost Train): the Firebug's telegraphed lob with a pumpkin.
## It stops, lights the fuse of a carved pumpkin (it appears in its hand,
## sparking) and cocks it back while the threat ring warns; on release a ring
## marks the floor where it will land (where the player is heading) and the
## pumpkin tumbles in to burst exactly as the ring fills: a splash of pumpkin
## and green sparks, no burning patch. A headshot during the wind-up makes it
## drop the pumpkin. It stands its ground (no backing off) unless
## `retreat_range` is set.


## Releases the pumpkin: marks the landing spot and sends it on its way.
func _release(z: Zombie) -> void:
	_show_bottle(false)
	if _anim:
		_anim.speed_scale = 1.0
	var player := z.target
	var from := z.global_position + Vector3.UP * 2.0 * z.data.body_scale
	var t := clampf(z.distance_to_target() / projectile_speed, 0.7, 1.6)
	var aim := player.global_position + player.velocity * Vector3(1, 0, 1) * t * lead
	var zone := BossZone.new()
	zone.radius = radius
	zone.telegraph = t
	zone.damage = damage
	zone.color = color
	zone.prop = BossZone.Prop.NONE
	zone.warn_sound = &""
	zone.hit_sound = smash_sound
	zone.source = z
	z.get_parent().add_child(zone)
	zone.global_position = BossMove.floor_point(z, aim)
	FrightPumpkinShell.throw(z.get_parent(), from, zone.global_position, t, apex)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.92, 1.06))
	z.play_animation(z.data.move_animation, 0.3)
