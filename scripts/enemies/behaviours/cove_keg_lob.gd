class_name CoveKegLobBehaviour
extends CityFirebugBehaviour
## Powder Monkey (Skull Harbor): the Firebug's telegraphed throw with a powder
## keg. It stops, lights the fuse (the keg appears in its hands, sparking)
## and heaves it overhead while the threat ring warns; on release a ring marks
## where the keg lands (where the player is heading). The keg lands, rolls to
## a stop and fizzes for `fuse` seconds while the ring fills, then blows up in
## a burst of smoke and sparks. Step out of the ring. A headshot during the
## wind-up makes it drop the keg; it backs off when rushed.

## Seconds the keg fizzes on the ground before it blows.
@export var fuse := 1.1


## Releases the keg: marks the landing spot (flight + fuse) and throws it.
func _release(z: Zombie) -> void:
	_show_bottle(false)
	if _anim:
		_anim.speed_scale = 1.0
	var player := z.target
	var from := z.global_position + Vector3.UP * 2.0 * z.data.body_scale
	var t := clampf(z.distance_to_target() / projectile_speed, 0.6, 1.5)
	var aim := player.global_position + player.velocity * Vector3(1, 0, 1) * t * lead
	var zone := BossZone.new()
	zone.radius = radius
	zone.telegraph = t + fuse
	zone.damage = damage
	zone.color = color
	zone.prop = BossZone.Prop.NONE
	zone.warn_sound = &""
	zone.hit_sound = smash_sound
	zone.source = z
	z.get_parent().add_child(zone)
	zone.global_position = BossMove.floor_point(z, aim)
	CovePowderKeg.throw(z.get_parent(), from, zone, t, apex, fuse)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.92, 1.06))
	z.play_animation(z.data.move_animation, 0.3)
