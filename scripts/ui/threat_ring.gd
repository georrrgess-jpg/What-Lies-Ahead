class_name ThreatRing
extends Control
## Arcs around the reticle that point at danger:
##  - red, when the player takes a hit: it flares wide, then narrows and
##    fades over a second;
##  - amber and pulsing with a chevron, while a zombie off to the side or
##    behind is winding up, charging, or already within arm's reach, so the
##    player can react.
##
## Hits and warnings live in fixed slots (nothing is allocated in a fight),
## zombies are scanned a few times a second, and the ring only redraws while
## there is something to show.

## Radii in pixels at 1080p. Both sit well outside the reticle and carry a
## dark under-stroke, so they stay readable over the viewmodel and bright scenery.
const RADIUS := 270.0
## Warnings sit further out than damage arcs so the two never overlap.
const WARN_RADIUS := 340.0
const UNDER := Color(0.04, 0.0, 0.07)
const DAMAGE_COLOR := Color(1.0, 0.12, 0.28)
const WARN_COLOR := Color(1.0, 0.6, 0.1)
const DAMAGE_LIFE := 1.1
const WARN_DISTANCE := 7.0
const SLOTS := 8
const SCAN_INTERVAL := 0.07

var player: Player
var director: RunDirector

var _hit_pos := PackedVector3Array()
var _hit_age := PackedFloat32Array()
var _warn_pos := PackedVector3Array()
var _warn_count := 0
var _time := 0.0
var _scan := 0.0
var _active := false
var _chevron := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_pos.resize(SLOTS)
	_hit_age.resize(SLOTS)
	_hit_age.fill(DAMAGE_LIFE)
	_warn_pos.resize(SLOTS)


## A hit landed from `source_position` (world space).
func add_hit(source_position: Vector3) -> void:
	# Reuse the slot of the oldest arc.
	var slot := 0
	for i in SLOTS:
		if _hit_age[i] > _hit_age[slot]:
			slot = i
	_hit_pos[slot] = source_position
	_hit_age[slot] = 0.0


## Angle on screen (0 = straight up, clockwise) of a world point.
func _screen_angle(world_pos: Vector3) -> float:
	var to := world_pos - player.global_position
	var local := player.global_transform.basis.inverse() * to
	return atan2(local.x, -local.z)


func _process(delta: float) -> void:
	_time += delta
	var showing := false
	for i in SLOTS:
		if _hit_age[i] < DAMAGE_LIFE:
			_hit_age[i] += delta
			showing = true
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_INTERVAL
		_find_warnings()
	showing = showing or _warn_count > 0
	if showing or _active:
		queue_redraw()
	_active = showing


## Zombies winding up, charging or at arm's reach, outside the player's view.
func _find_warnings() -> void:
	_warn_count = 0
	if player == null or director == null or not player.alive:
		return
	var limit := deg_to_rad(38.0)
	for z in director.alive_enemies():
		if _warn_count >= SLOTS:
			break
		if not is_instance_valid(z) or z.is_dead():
			continue
		var d := z.global_position.distance_to(player.global_position)
		var urgent := (z.is_winding_up() and d <= WARN_DISTANCE) or (z.is_charging() and d <= 16.0) or d <= 2.6
		if urgent and absf(_screen_angle(z.global_position)) > limit:
			_warn_pos[_warn_count] = z.global_position
			_warn_count += 1


func _draw() -> void:
	if player == null:
		return
	var c := size * 0.5
	for i in SLOTS:
		if _hit_age[i] >= DAMAGE_LIFE:
			continue
		var t := _hit_age[i] / DAMAGE_LIFE
		var alpha := (1.0 - t) * (1.0 - t)
		var flare := 1.0 - smoothstep(0.0, 0.18, t)
		_arc(c, _screen_angle(_hit_pos[i]), 0.42 + 0.2 * flare, Color(DAMAGE_COLOR, alpha * 0.95), 15.0 + 9.0 * flare, RADIUS - 10.0 * flare)
	var pulse := 0.8 + 0.2 * sin(_time * 18.0)
	for i in _warn_count:
		var angle := _screen_angle(_warn_pos[i])
		_arc(c, angle, 0.42, Color(WARN_COLOR, pulse), 20.0, WARN_RADIUS)
		var out := Vector2(sin(angle), -cos(angle))
		var side := Vector2(cos(angle), sin(angle))
		var tip := c + out * (WARN_RADIUS + 34.0 + 6.0 * pulse)
		_chevron[0] = tip + out * 32.0
		_chevron[1] = tip + side * 26.0
		_chevron[2] = tip - side * 26.0
		draw_colored_polygon(_chevron, Color(UNDER, pulse * 0.8))
		_chevron[0] = tip + out * 24.0
		_chevron[1] = tip + side * 18.0
		_chevron[2] = tip - side * 18.0
		draw_colored_polygon(_chevron, Color(WARN_COLOR, pulse))


## An arc with a dark under-stroke and a bright core line.
func _arc(c: Vector2, angle: float, half_width: float, color: Color, thickness: float, radius: float) -> void:
	# Godot's draw_arc measures from +X; screen "up" is -90 degrees.
	var centre := angle - PI * 0.5
	var pad := 6.0 / radius   # the under-stroke also overhangs both ends
	draw_arc(c, radius, centre - half_width - pad, centre + half_width + pad, 24, Color(UNDER, color.a * 0.8), thickness + 10.0, true)
	draw_arc(c, radius, centre - half_width, centre + half_width, 24, color, thickness, true)
	draw_arc(c, radius + thickness * 0.2, centre - half_width * 0.8, centre + half_width * 0.8, 24, Color(1, 1, 1, color.a * 0.45), thickness * 0.22, true)
