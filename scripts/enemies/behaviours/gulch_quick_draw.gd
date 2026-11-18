class_name GulchQuickDrawBehaviour
extends EnemyBehaviour
## Cowpoke (and Sheriff Rattlebones' escorts): at mid range with a clear line
## of sight it stops and squares up for a quick-draw (the telegraph: the Draw
## clip, a spur jingle, a gold glint flashing at its gun hand and the threat
## ring), then snaps the toy six-shooter level and fires a glowing cork pellet
## straight at the player: fast, but with a flat, readable flight. Breaking
## line of sight or a headshot during the draw spoils the shot. Melee still
## works up close.

@export var min_range := 6.0
@export var max_range := 20.0
@export var cooldown := 5.0
## Seconds before the first draw (a random pick in this range).
@export var first_draw := Vector2(1.5, 3.5)
@export var windup := 0.92
@export var damage := 7.0
@export var projectile_speed := 19.0
@export var arc := 0.08
@export var size := 0.18
## How much of the player's motion the shot leads (0 = aims where they stand).
@export var lead := 0.35
@export var color := Color(1.0, 0.78, 0.25)
@export var glint_color := Color(1.0, 0.9, 0.45)
@export var windup_clip: StringName = &"Draw"
@export var windup_sound: StringName = &"gulch_cowpoke_draw"
@export var fire_sound: StringName = &"gulch_cowpoke_shot"

var _cool := 2.0
var _winding := 0.0
var _glint: MeshInstance3D

static var _glint_mesh: QuadMesh


func on_ready(_z: Zombie) -> void:
	_cool = randf_range(first_draw.x, first_draw.y)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0, to.z), delta * 2.0)
		z.move_with(Vector3.ZERO)
		_pulse_glint()
		if _winding <= 0.0:
			_fire(z)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_begin(z)
			return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot:
		interrupt(z)
	return amount


func interrupt(z: Zombie) -> void:
	if _winding <= 0.0:
		return
	_winding = 0.0
	_cool = cooldown * 0.6
	_drop_glint()
	z.play_animation(&"Stagger", 0.05)


func on_death(_z: Zombie) -> void:
	_drop_glint()


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	z.play_animation(windup_clip, 0.1)
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.2, 0.0, randf_range(0.94, 1.06))
	_make_mesh()
	_glint = MeshInstance3D.new()
	_glint.mesh = _glint_mesh
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(_glint)
	# At the gun hand (the right hip), a little in front of the body.
	_glint.position = Vector3(-0.42, 0.95, 0.25) * z.data.body_scale


func _pulse_glint() -> void:
	if not is_instance_valid(_glint):
		return
	var k := 1.0 - _winding / maxf(windup, 0.01)
	_glint.scale = Vector3.ONE * (0.35 + 0.65 * k + 0.25 * sin(k * 40.0))


func _drop_glint() -> void:
	if is_instance_valid(_glint):
		_glint.queue_free()
	_glint = null


func _fire(z: Zombie) -> void:
	_drop_glint()
	if not z.has_line_of_sight():
		z.play_animation(z.data.move_animation, 0.3)
		return
	var from := z.global_position + Vector3.UP * 1.3 * z.data.body_scale
	var to := z.target.global_position - z.global_position
	to.y = 0.0
	from += to.normalized() * 0.6
	var t := clampf(z.distance_to_target() / projectile_speed, 0.0, 1.2)
	var aim := z.target.global_position + Vector3.UP * 1.0 + z.target.velocity * Vector3(1, 0, 1) * t * lead
	EnemyProjectile.launch(z.get_parent(), from, aim, projectile_speed, damage, color, arc, size, z)
	Sfx.play_at(fire_sound, from, 0.0, randf_range(0.92, 1.08))
	Fx.impact(z.get_parent(), from, to.normalized(), color)
	z.play_animation(z.data.move_animation, 0.3)


func _make_mesh() -> void:
	if _glint_mesh:
		return
	_glint_mesh = QuadMesh.new()
	_glint_mesh.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.albedo_color = glint_color
	m.albedo_texture = _star_texture()
	_glint_mesh.material = m


## A four-point sparkle drawn once into a small texture.
static func _star_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			var ray := maxf(1.0 - (dx * 7.0 + dy) * 0.9, 1.0 - (dy * 7.0 + dx) * 0.9)
			var core := 1.0 - sqrt(dx * dx + dy * dy) * 2.2
			var a := clampf(maxf(ray, core), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
