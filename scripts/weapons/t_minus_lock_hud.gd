class_name TMinusLockHud
extends Control
## The T-Minus Six's paint-lock overlay (made by its mode, under the HUD):
##
##   radar   while aiming, a teal ring round the crosshair the size of the
##           lock cone, a sweep line turning in it (faster per lock) and six
##           pips on its rim: lit per lock, hollow for a loaded rocket, dim
##           for an empty tube
##   paint   a yellow arc filling round the head being painted
##   locks   a teal bracket box on each painted head, popping as a lock
##           lands, with one pip per rocket it will take
##
## It redraws only while one of these shows.

const TEAL := Color(0.247, 0.941, 0.831)
const YELLOW := Color(1.0, 0.824, 0.247)
const RED := Color(0.91, 0.247, 0.247)
const BOX := 15.0

var mode: TMinusSixMode
var _time := 0.0
var _sweep := 0.0
var _drawn := false
var _corner := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _seen: Array[Zombie] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	if _showing():
		_sweep = wrapf(_sweep + delta * (2.5 + 1.6 * mode.lock_count()), 0.0, TAU)
		_drawn = true
		queue_redraw()
	elif _drawn:
		_drawn = false
		queue_redraw()


func _showing() -> bool:
	var w := mode.controller
	if w == null or w.current != mode.data or not w.enabled or not w.player.alive:
		return false
	return w.player.aim_blend > 0.25 or mode.lock_count() > 0


func _draw() -> void:
	if not _showing():
		return
	var p := mode.controller.player
	var cam := p.camera
	var aim := p.aim_blend
	if aim > 0.25:
		_draw_radar(size * 0.5, _cone_pixels(cam), clampf((aim - 0.25) / 0.5, 0.0, 1.0))
	if is_instance_valid(mode.painting) and not mode.painting.is_dead() and mode.paint > 0.0:
		var at := _screen(cam, mode.painting)
		if at.x > -1.0:
			draw_arc(at, BOX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * mode.paint, 32, Color(UiKit.INK, 0.7), 6.0, true)
			draw_arc(at, BOX + 6.0, -PI * 0.5, -PI * 0.5 + TAU * mode.paint, 32, YELLOW, 3.0, true)
	_seen.clear()
	for z in mode.locks:
		if is_instance_valid(z) and not _seen.has(z):
			_seen.append(z)
			_draw_lock(cam, z, mode.locks_on(z))


## The lock cone's radius on screen.
func _cone_pixels(cam: Camera3D) -> float:
	var half := deg_to_rad(cam.fov) * 0.5
	return tan(deg_to_rad(mode.LOCK_CONE)) / tan(half) * size.y * 0.5


func _draw_radar(c: Vector2, r: float, k: float) -> void:
	var ink := Color(UiKit.INK, 0.45 * k)
	draw_arc(c, r, 0.0, TAU, 72, ink, 5.0, true)
	draw_arc(c, r, 0.0, TAU, 72, Color(TEAL, 0.55 * k), 2.0, true)
	# The sweep: a bright line and a fading wedge trailing it.
	for i in 6:
		var a := _sweep - i * 0.09
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.25, c + Vector2(cos(a), sin(a)) * r, Color(TEAL, (0.5 - i * 0.08) * k), 2.0, true)
	var cap := mode.lock_cap()
	var locked := mode.lock_count()
	for i in mode.MAX_LOCKS:
		var a := -PI * 0.5 + (i - (mode.MAX_LOCKS - 1) * 0.5) * 0.24
		var at := c + Vector2(cos(a), sin(a)) * (r + 12.0)
		draw_circle(at, 6.0, Color(UiKit.INK, 0.8 * k))
		if i < locked:
			var pop := 1.0 + 0.6 * clampf(1.0 - mode.since_lock / 0.15, 0.0, 1.0) * float(i == locked - 1)
			draw_circle(at, 4.2 * pop, Color(TEAL.lerp(Color.WHITE, 0.3), k))
		elif i < cap:
			draw_arc(at, 3.6, 0.0, TAU, 16, Color(TEAL, 0.8 * k), 1.6, true)
		else:
			draw_circle(at, 2.2, Color(RED, 0.5 * k))


func _draw_lock(cam: Camera3D, z: Zombie, count: int) -> void:
	var at := _screen(cam, z)
	if at.x < -1.0:
		return
	var pop := 1.0 + 0.35 * clampf(1.0 - mode.since_lock / 0.15, 0.0, 1.0) * float(z == mode.locks.back())
	var s := BOX * pop
	var spin := 0.25 * sin(_time * 6.0)
	for i in 4:
		var a := spin + i * PI * 0.5 + PI * 0.25
		var corner := at + Vector2(cos(a), sin(a)) * s * 1.41
		var along := Vector2(cos(a + PI * 0.75), sin(a + PI * 0.75)) * s * 0.6
		var down := Vector2(cos(a - PI * 0.75), sin(a - PI * 0.75)) * s * 0.6
		_corner[0] = corner + along
		_corner[1] = corner
		_corner[2] = corner + down
		draw_polyline(_corner, Color(UiKit.INK, 0.8), 6.0, true)
		draw_polyline(_corner, TEAL, 2.6, true)
	for i in count:
		var pip := at + Vector2((i - (count - 1) * 0.5) * 8.0, s + 12.0)
		draw_circle(pip, 3.6, Color(UiKit.INK, 0.85))
		draw_circle(pip, 2.4, YELLOW)


## Where `z`'s head is on screen (x below -1 when behind the camera).
func _screen(cam: Camera3D, z: Zombie) -> Vector2:
	var head := TMinusRocket.seek_point(z)
	if cam.is_position_behind(head):
		return Vector2(-10.0, -10.0)
	return cam.unproject_position(head)
