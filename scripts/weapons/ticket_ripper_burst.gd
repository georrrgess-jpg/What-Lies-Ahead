class_name TicketRipperBurst
extends Node3D
## The Ticket Ripper's WINNER pop (TicketRipperMode): where the golden
## ticket first strikes, a fountain of prize tickets and gold, a gold flash
## and ring, and BURST_DAMAGE to every other zombie within RADIUS (less
## toward the edge, heavies take HEAVY_SCALE). A "WINNER!" sign slams in over
## the spot at a fixed size on screen, wobbles, rises and fades. Pooled, like
## StrikeZoneBanner.

const RADIUS := 2.6
const BURST_DAMAGE := 34.0
const EDGE_SCALE := 0.5
const HEAVY_SCALE := 0.5
const POP_SOUND := &"tkr_pop"
const TICKETS := [Color(1.0, 0.95, 0.78), Color(1.0, 0.36, 0.5), Color(1.0, 0.82, 0.22), Color(0.2, 0.85, 0.78)]
const GOLD := [Color(1.0, 0.82, 0.22), Color(1.0, 0.95, 0.6), Color(1.0, 0.65, 0.15)]
const LIFE := 0.95
const RISE := 0.6
const OUTLINE := Color(0.32, 0.04, 0.16)

static var _pool: Array = []

var _title: Label3D
var _tween: Tween


## The pop at `at` for `weapon`, sparing the zombies the winner already struck.
static func pop(controller: WeaponController, weapon: WeaponData, at: Vector3, struck: Array[Zombie]) -> void:
	var level := controller.player.get_parent()
	WeaponFx.burst(level, at, Vector3.UP, TICKETS, 24, 5.5, 0.9, 0.06, 170.0, Vector3(0, -5.0, 0))
	WeaponFx.burst(level, at, Vector3.UP, GOLD, 10, 4.0, 0.6, 0.035, 120.0, Vector3(0, -9.0, 0))
	WeaponFx.flash(level, at, GOLD[0], 1.0, 0.16)
	WeaponFx.shockwave(level, Vector3(at.x, at.y - 0.9, at.z), GOLD[0], RADIUS)
	Sfx.play_at(POP_SOUND, at, 0.0, randf_range(0.97, 1.04))
	_sign(level, at + Vector3.UP * 0.5)
	var space := controller.player.get_world_3d().direct_space_state
	for node in controller.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or struck.has(z):
			continue
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		var d := chest.distance_to(at)
		if d > RADIUS or not space.intersect_ray(PhysicsRayQueryParameters3D.create(at, chest, WeaponController.MASK_WORLD)).is_empty():
			continue
		var away := (chest - at).normalized() if d > 0.01 else Vector3.UP
		var dmg := BURST_DAMAGE * lerpf(1.0, EDGE_SCALE, d / RADIUS) * (HEAVY_SCALE if z.data.heavy else 1.0)
		controller.ring_hit(weapon, z, chest - away * z.data.capsule_radius * z.data.body_scale, away, dmg, false)


static func _sign(parent: Node, at: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var b: TicketRipperBurst = null
	while not _pool.is_empty() and b == null:
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			b = candidate
	if b == null:
		b = TicketRipperBurst.new()
	if b.get_parent() != parent:
		if b.get_parent():
			b.get_parent().remove_child(b)
		parent.add_child(b)
	b._play(at)


func _init() -> void:
	_title = Label3D.new()
	_title.font = UiKit.display_font()
	_title.font_size = 96
	_title.pixel_size = 0.0014
	_title.outline_size = 22
	_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title.no_depth_test = true
	_title.fixed_size = true
	_title.render_priority = 10
	_title.outline_render_priority = 9
	_title.text = "WINNER!"
	add_child(_title)


func _play(at: Vector3) -> void:
	visible = true
	global_position = at
	_title.modulate = GOLD[0]
	_title.outline_modulate = OUTLINE
	_title.scale = Vector3.ONE * 2.0
	_title.rotation = Vector3.ZERO
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_title, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_wobble, 0.0, 1.0, 0.5).set_delay(0.18)
	_tween.tween_property(self, "global_position", at + Vector3.UP * RISE, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_fade, 1.0, 0.0, 0.3).set_delay(LIFE - 0.3)
	_tween.chain().tween_callback(_done)


func _wobble(k: float) -> void:
	_title.rotation.z = sin(k * TAU * 2.0) * 0.12 * (1.0 - k)


func _fade(a: float) -> void:
	_title.modulate.a = a
	_title.outline_modulate.a = a


func _done() -> void:
	visible = false
	_pool.append(self)
