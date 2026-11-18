class_name FaireJesterTricksBehaviour
extends LavaCoconutLobBehaviour
## Jester (Royal Faire). Pin toss: the Tiki Bartender's telegraphed lob with a
## juggling pin. It plants its feet and twirls the pin overhead (the juggle is
## the telegraph, with a call and the threat ring; a headshot during it spills
## the throw), then lobs it at where the player is heading.
## Cartwheel: now and then (and sometimes when hit) it cartwheels a few metres
## sideways out of your aim with a jingle. It never attacks from a cartwheel.

## The pin's colours: body and band glow.
@export var pin_color := Color(0.98, 0.96, 0.9)
@export var band_color := Color(0.85, 0.2, 0.25)
## Turns per second of the twirl during the windup.
@export var twirl_speed := 2.4

@export_group("Cartwheel")
@export var cartwheel_cooldown := 5.5
@export var cartwheel_time := 0.55
@export var cartwheel_speed := 6.5
## Chance that a hit sets off a cartwheel (when one is ready).
@export_range(0.0, 1.0) var cartwheel_on_hit := 0.3
@export var cartwheel_range := Vector2(4.0, 16.0)
@export var cartwheel_sound: StringName = &"faire_jester_jingle"
## Height of the hips the cartwheel turns about (before body scale).
@export var hip_height := 1.0

static var _pin_mesh: CylinderMesh

var _wheel := 0.0
var _wheel_cool := 3.0
var _wheel_dir := Vector3.RIGHT
var _wheel_sign := 1.0


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	_wheel_cool = randf_range(2.0, cartwheel_cooldown)
	if _pin_mesh == null:
		_pin_mesh = CylinderMesh.new()
		_pin_mesh.top_radius = 0.35
		_pin_mesh.bottom_radius = 0.6
		_pin_mesh.height = 2.6
		_pin_mesh.radial_segments = 8
		_pin_mesh.rings = 2
		var m := StandardMaterial3D.new()
		m.albedo_color = pin_color
		m.roughness = 0.4
		m.emission_enabled = true
		m.emission = band_color
		m.emission_energy_multiplier = 0.25
		_pin_mesh.material = m


func on_physics(z: Zombie, delta: float) -> bool:
	_wheel_cool -= delta
	if _wheel > 0.0:
		_tick_wheel(z, delta)
		return true
	if _winding > 0.0 and is_instance_valid(_held):
		_held.rotate_x(TAU * twirl_speed * delta)
	elif _can_wheel(z):
		var d := z.distance_to_target()
		if d >= cartwheel_range.x and d <= cartwheel_range.y and z.has_line_of_sight():
			_begin_wheel(z)
			return true
	return super.on_physics(z, delta)


func on_hit(z: Zombie, amount: float, hit_position: Vector3, headshot: bool) -> float:
	var taken := super.on_hit(z, amount, hit_position, headshot)
	if _winding <= 0.0 and _can_wheel(z) and z.health > taken and randf() < cartwheel_on_hit:
		_begin_wheel(z)
	return taken


func on_death(z: Zombie) -> void:
	super.on_death(z)
	if _wheel > 0.0:
		_wheel = 0.0
		_set_roll(z, 0.0)


func _begin(z: Zombie) -> void:
	super._begin(z)
	if is_instance_valid(_held):
		_held.mesh = _pin_mesh


func _can_wheel(z: Zombie) -> bool:
	return _wheel <= 0.0 and _wheel_cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and not z.is_fleeing()


func _begin_wheel(z: Zombie) -> void:
	_wheel = cartwheel_time
	_wheel_cool = cartwheel_cooldown * randf_range(0.8, 1.25)
	_wheel_sign = 1.0 if randf() < 0.5 else -1.0
	var side := Vector3(cos(z.rotation.y), 0.0, -sin(z.rotation.y))
	_wheel_dir = side * _wheel_sign
	z.play_animation(z.data.move_animation, 0.05)
	Sfx.play_at(cartwheel_sound, z.global_position + Vector3.UP * 1.2, -2.0, randf_range(0.92, 1.1))


func _tick_wheel(z: Zombie, delta: float) -> void:
	_wheel = maxf(0.0, _wheel - delta)
	var k := 1.0 - _wheel / cartwheel_time
	_set_roll(z, -_wheel_sign * TAU * k)
	z.move_with(_wheel_dir * cartwheel_speed)
	if _wheel <= 0.0:
		_set_roll(z, 0.0)


## Turns the model about its forward axis through the hips (0 = upright).
func _set_roll(z: Zombie, angle: float) -> void:
	var h := hip_height * z.data.body_scale
	z.model_root.rotation = Vector3(0.0, 0.0, angle)
	z.model_root.position = Vector3(0.0, h, 0.0) + Basis(Vector3.BACK, angle) * Vector3(0.0, -h, 0.0)
