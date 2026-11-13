class_name WeaponHud
extends Control
## Full-screen HUD overlay for the weapon fire modes, drawn on top of the
## normal reticle:
##   charge   a ring around the reticle that fills while charging, with rail
##            brackets closing in; pulses when the charge is full
##   heat     a segmented gauge beside the ammo counter, weapon colour to red;
##            flashes while venting
##   burst    one pip per shot of a burst under the reticle, lit when ready
##   seek     a spinning diamond on the zombie a seeking weapon will hit
##
## It redraws only while one of these is showing something that moves.

const RING_RADIUS := 46.0
const HEAT_SEGMENTS := 8

var player: Player
## The ammo counter, so the heat gauge can sit right beside it.
var ammo_label: Control
var _time := 0.0
var _heat_back := StyleBoxFlat.new()
var _heat_fill := StyleBoxFlat.new()
var _bracket := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _diamond := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _last_charge := -1.0
var _last_heat := -1.0
var _last_pips := -1
var _drawn := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heat_back.bg_color = Color(UiKit.INK, 0.78)
	_heat_back.set_corner_radius_all(6)
	_heat_back.set_expand_margin_all(4)
	_heat_fill.set_corner_radius_all(3)


func bind(p: Player, ammo: Control) -> void:
	player = p
	ammo_label = ammo


func _process(delta: float) -> void:
	_time += delta
	if _needs_redraw():
		_drawn = true
		queue_redraw()
	elif _drawn:
		# One more pass so whatever was showing is cleared.
		_drawn = false
		queue_redraw()


## True while something this overlay draws is changing.
func _needs_redraw() -> bool:
	if player == null or player.weapons.current == null or not player.alive:
		return false
	var w := player.weapons
	var data := w.current
	var changed := false
	if data.charge_time > 0.0:
		var k := w.charge_progress()
		changed = changed or k != _last_charge or k >= 1.0
		_last_charge = k
	if data.uses_heat():
		var heat := w.heat()
		changed = changed or heat != _last_heat or w.is_reloading()
		_last_heat = heat
	if data.burst_count > 1:
		var pips := w.magazine() if not w.is_reloading() and not w.is_switching() else 0
		changed = changed or pips != _last_pips
		_last_pips = pips
	return changed or (w.lock_target != null and is_instance_valid(w.lock_target))


func _draw() -> void:
	if player == null or player.weapons.current == null or not player.alive:
		return
	var w := player.weapons
	var data := w.current
	var c := size * 0.5
	if data.charge_time > 0.0:
		_draw_charge(c, w.charge_progress(), data)
	if data.uses_heat():
		_draw_heat(w.heat(), w.is_reloading(), data)
	if data.burst_count > 1:
		_draw_burst(c, w, data)
	if w.lock_target and is_instance_valid(w.lock_target) and not w.lock_target.is_dead():
		_draw_lock(w.lock_target, data)


func _draw_charge(c: Vector2, k: float, data: WeaponData) -> void:
	var ink := Color(UiKit.INK, 0.6)
	draw_arc(c, RING_RADIUS, 0.0, TAU, 64, ink, 8.0, true)
	if k <= 0.0:
		return
	var full := k >= 1.0
	var col := data.tracer_color.lerp(Color.WHITE, 0.25 if not full else 0.55 + 0.45 * sin(_time * 18.0))
	var start := -PI * 0.5
	draw_arc(c, RING_RADIUS, start, start + TAU * k, 64, col, 5.0, true)
	# Rail brackets slide in from the sides as the charge builds.
	var gap := lerpf(70.0, 18.0, ease(k, 0.6))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var x: float = c.x + side * gap
		_bracket[0] = Vector2(x + side * 10.0, c.y - 12.0)
		_bracket[1] = Vector2(x, c.y - 12.0)
		_bracket[2] = Vector2(x, c.y + 12.0)
		_bracket[3] = Vector2(x + side * 10.0, c.y + 12.0)
		draw_polyline(_bracket, Color(UiKit.INK, 0.8), 6.0, true)
		draw_polyline(_bracket, col, 2.6, true)
	if full:
		var r := RING_RADIUS + 8.0 + 4.0 * sin(_time * 18.0)
		draw_arc(c, r, 0.0, TAU, 64, Color(col, 0.45), 2.0, true)


## A column of segments just left of the ammo counter, filling from the bottom.
func _draw_heat(heat: float, venting: bool, data: WeaponData) -> void:
	if ammo_label == null:
		return
	var rect := ammo_label.get_global_rect()
	rect.position -= get_global_rect().position
	var left := rect.position.x + ((ammo_label as HudAmmo).digits_left() if ammo_label is HudAmmo else 0.0)
	var bar := Rect2(left - 40.0, rect.position.y + 22.0, 20.0, rect.size.y - 46.0)
	draw_style_box(_heat_back, bar)
	var col := data.tracer_color.lerp(UiKit.AMBER, smoothstep(0.45, 0.75, heat)).lerp(UiKit.RED, smoothstep(0.75, 0.95, heat))
	if venting:
		col = UiKit.RED.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 20.0))
	var lit := HEAT_SEGMENTS if venting else int(ceil(heat * HEAT_SEGMENTS - 0.01))
	var step := bar.size.y / HEAT_SEGMENTS
	_heat_fill.bg_color = col
	for i in lit:
		draw_style_box(_heat_fill, Rect2(bar.position.x, bar.end.y - (i + 1) * step + 2.0, bar.size.x, step - 4.0))


func _draw_burst(c: Vector2, w: WeaponController, data: WeaponData) -> void:
	var can_fire := not w.is_reloading() and not w.is_switching() and w.magazine() > 0
	var n := data.burst_count
	var spacing := 12.0
	var y := c.y + 30.0
	for i in n:
		var x := c.x + (i - (n - 1) * 0.5) * spacing
		var lit := can_fire and i < w.magazine()
		draw_circle(Vector2(x, y), 4.6, Color(UiKit.INK, 0.8))
		draw_circle(Vector2(x, y), 3.0, data.tracer_color if lit else Color(1, 1, 1, 0.25))


func _draw_lock(z: Zombie, data: WeaponData) -> void:
	var cam := player.camera
	var chest := z.global_position + Vector3.UP * 1.05 * z.data.body_scale
	if cam.is_position_behind(chest):
		return
	var p := cam.unproject_position(chest)
	var r := 16.0 + 2.0 * sin(_time * 10.0)
	for i in 5:
		var a := _time * 2.5 + i * PI * 0.5
		_diamond[i] = p + Vector2(cos(a), sin(a)) * r
	draw_polyline(_diamond, Color(UiKit.INK, 0.75), 6.0, true)
	draw_polyline(_diamond, data.tracer_color, 2.6, true)
	draw_circle(p, 3.0, data.tracer_color.lerp(Color.WHITE, 0.5))
