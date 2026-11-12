class_name AquaDiveHelmet
extends EnemyBehaviour
## Deep Diver armour. The brass diving helmet shrugs off most headshot damage
## (it clanks and sparks) until enough head damage cracks the visor: the helmet
## then pops off and tumbles away, the diver staggers, and from then on its
## bare head takes full headshot damage. Losing the helmet panics the diver
## into a short rush, so cracking it is a choice, not a free win.

@export var helmet_health := 45.0
## Fraction of headshot damage that gets through while the helmet holds.
@export_range(0.0, 1.0) var head_armor := 0.3
## Name of the helmet accessory mesh in the model.
@export var helmet_mesh := "Acc_Diver_Helmet"
@export var clank_sound: StringName = &"aqua_helmet_clank"
@export var break_sound: StringName = &"aqua_helmet_crack"
@export var rush_seconds := 2.5
@export var rush_speed := 1.4

var _hp := 0.0
var _helmet: MeshInstance3D
var _rush := 0.0


func on_ready(z: Zombie) -> void:
	_hp = helmet_health
	_helmet = z.find_child(helmet_mesh, true, false) as MeshInstance3D


func on_physics(z: Zombie, delta: float) -> bool:
	if _rush > 0.0:
		_rush -= delta
		z.speed_multiplier = rush_speed
	return false


func on_hit(z: Zombie, amount: float, hit_position: Vector3, headshot: bool) -> float:
	if not headshot or _hp <= 0.0:
		return amount
	_hp -= amount
	var out := (hit_position - (z.global_position + Vector3.UP * 1.6)).normalized()
	if _hp > 0.0:
		Sfx.play_at(clank_sound, hit_position, -2.0, randf_range(0.92, 1.12))
		Fx.impact(z.get_parent(), hit_position, out, Color(1.0, 0.78, 0.3))
		return amount * head_armor
	_break(z, hit_position, out)
	return amount * head_armor


## True while the helmet still protects the head.
func is_armoured() -> bool:
	return _hp > 0.0


func _break(z: Zombie, at: Vector3, out: Vector3) -> void:
	Sfx.play_at(break_sound, at, 1.0, randf_range(0.95, 1.05))
	for i in 3:
		Fx.impact(z.get_parent(), at, (out + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), randf_range(-0.6, 0.6))).normalized(),
			Color(0.55, 0.95, 1.0) if i % 2 == 0 else Color(1.0, 0.8, 0.35))
	Fx.hit_pop(z.get_parent(), at, out, true)
	z.knockback(-Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 2.0)
	z.play_animation(&"Hit", 0.05)
	_rush = rush_seconds
	if _helmet == null:
		return
	_helmet.visible = false
	_tumble(z)


## The helmet flies off: an unskinned copy of its mesh, tossed up and back.
func _tumble(z: Zombie) -> void:
	var flying := MeshInstance3D.new()
	flying.mesh = _helmet.mesh
	flying.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(flying)
	flying.global_transform = _helmet.global_transform
	var back := -Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y))
	var spin := Vector3(randf_range(1.5, 2.5), randf_range(-1.0, 1.0), 0.0)
	var start := flying.global_position
	var tw := flying.create_tween().set_parallel(true)
	tw.tween_property(flying, "global_position", start + back * 1.0 + Vector3.UP * 0.8, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(flying, "rotation", flying.rotation + spin, 0.3)
	tw.chain().tween_property(flying, "global_position", start + back * 2.2 - Vector3.UP * 1.4, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(flying, "rotation", flying.rotation + spin * 2.5, 0.45)
	tw.chain().tween_property(flying, "scale", Vector3.ONE * 0.01, 0.2)
	tw.chain().tween_callback(flying.queue_free)
