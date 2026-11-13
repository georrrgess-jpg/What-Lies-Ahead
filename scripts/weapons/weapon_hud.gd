class_name WeaponHud
extends Control
## Full-screen HUD overlay for the weapon fire modes, drawn on top of the
## normal reticle:
##   charge   a ring around the reticle that fills while charging, with rail
##            brackets closing in; pulses when the charge is full
##   heat     a gauge beside the ammo counter, cyan to red; flashes while venting
##   burst    one pip per shot of a burst under the reticle, lit when ready
##   seek     a spinning diamond on the zombie a seeking weapon will hit

const RING_RADIUS := 46.0

var player: Player
## The ammo counter, so the heat bar can sit right above it.
var ammo_label: Control
var _time := 0.0
var _heat_back := StyleBoxFlat.new()
var _heat_fill := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func bind(p: Player, ammo: Control) -> void:
	player = p
	ammo_label = ammo


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


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
	# The idle ring steps aside for an optic's own reticle; a charge still shows.
	var idle := 1.0 - player.ads if k <= 0.0 and player.view.sight_has_reticle() else 1.0
	var ink := Color(UiKit.INK, 0.6 * idle)
	draw_arc(c, RING_RADIUS, 0.0, TAU, 64, ink, 8.0, true)
	if k <= 0.0:
		return
	var full := k >= 1.0
	var col := data.tracer_color.lerp(Color.WHITE, 0.25 if not full else 0.55 + 0.45 * sin(_time * 18.0))
	var start := -PI * 0.5
	draw_arc(c, RING_RADIUS, start, start + TAU * k, 64, col, 5.0, true)
	# Rail brackets slide in from the sides as the charge builds.
	var gap := lerpf(70.0, 18.0, ease(k, 0.6))
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * gap
		var pts := PackedVector2Array([Vector2(x + side * 10.0, c.y - 12.0), Vector2(x, c.y - 12.0), Vector2(x, c.y + 12.0), Vector2(x + side * 10.0, c.y + 12.0)])
		draw_polyline(pts, Color(UiKit.INK, 0.8), 6.0, true)
		draw_polyline(pts, col, 2.6, true)
	if full:
		var r := RING_RADIUS + 8.0 + 4.0 * sin(_time * 18.0)
		draw_arc(c, r, 0.0, TAU, 64, Color(col, 0.45), 2.0, true)


func _draw_heat(heat: float, venting: bool, data: WeaponData) -> void:
	if ammo_label == null:
		return
	var rect := ammo_label.get_global_rect()
	rect.position -= get_global_rect().position
	# A vertical gauge just left of the ammo counter, filling from the bottom.
	var bar := Rect2(rect.position.x - 30.0, rect.position.y + 18.0, 16.0, rect.size.y - 34.0)
	var back := _heat_back
	back.bg_color = Color(UiKit.INK, 0.75)
	back.set_corner_radius_all(8)
	back.set_expand_margin_all(4)
	draw_style_box(back, bar)
	var col := data.tracer_color.lerp(UiKit.AMBER, smoothstep(0.45, 0.75, heat)).lerp(UiKit.RED, smoothstep(0.75, 0.95, heat))
	if venting:
		col = UiKit.RED.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 20.0))
	var k := 1.0 if venting else heat
	if k > 0.01:
		var fill := _heat_fill
		fill.bg_color = col
		fill.set_corner_radius_all(8)
		var h := maxf(16.0, bar.size.y * k)
		draw_style_box(fill, Rect2(bar.position.x, bar.end.y - h, bar.size.x, h))


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
	var pts := PackedVector2Array()
	for i in 5:
		var a := _time * 2.5 + i * PI * 0.5
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(UiKit.INK, 0.75), 6.0, true)
	draw_polyline(pts, data.tracer_color, 2.6, true)
	draw_circle(p, 3.0, data.tracer_color.lerp(Color.WHITE, 0.5))
