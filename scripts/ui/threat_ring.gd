class_name ThreatRing
extends Control
## Arcs around the reticle that point at danger:
##  - red, when the player takes a hit (fades over a second);
##  - amber and pulsing, while a nearby zombie off to the side or behind is
##    winding up an attack, so the player can turn or step away in time.

const RADIUS := 150.0
const DAMAGE_LIFE := 1.1
const WARN_DISTANCE := 7.0

var player: Player
var director: RunDirector
var _hits: Array = []        # [{ "pos": Vector3, "age": float }]
var _warnings: Array = []    # screen angles (radians) this frame
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_hit(source_position: Vector3) -> void:
	_hits.append({"pos": source_position, "age": 0.0})


## Angle on screen (0 = straight up, clockwise) of a world point.
func _screen_angle(world_pos: Vector3) -> float:
	var to := world_pos - player.global_position
	var local := player.global_transform.basis.inverse() * to
	return atan2(local.x, -local.z)


func _process(delta: float) -> void:
	_time += delta
	for h in _hits:
		h["age"] = float(h["age"]) + delta
	_hits = _hits.filter(func(h): return float(h["age"]) < DAMAGE_LIFE)
	_warnings.clear()
	if player and director and player.alive:
		for z in director.alive_enemies():
			if not is_instance_valid(z) or not z.is_winding_up():
				continue
			if z.global_position.distance_to(player.global_position) > WARN_DISTANCE:
				continue
			var angle := _screen_angle(z.global_position)
			# Only warn about threats the player probably cannot see.
			if absf(angle) > deg_to_rad(38.0):
				_warnings.append(angle)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var c := size * 0.5
	for h in _hits:
		var t := float(h["age"]) / DAMAGE_LIFE
		var alpha := (1.0 - t) * (1.0 - t)
		_arc(c, _screen_angle(h["pos"]), 0.55, Color(1.0, 0.12, 0.28, alpha * 0.95), 16.0 + 6.0 * (1.0 - t))
	var pulse := 0.6 + 0.4 * sin(_time * 18.0)
	for angle in _warnings:
		_arc(c, angle, 0.42, Color(1.0, 0.78, 0.15, pulse), 12.0)
		var tip := c + Vector2(sin(angle), -cos(angle)) * (RADIUS + 26.0)
		var side := Vector2(cos(angle), sin(angle)) * 12.0
		var out := Vector2(sin(angle), -cos(angle)) * 16.0
		draw_colored_polygon(PackedVector2Array([tip + out, tip + side, tip - side]), Color(1.0, 0.78, 0.15, pulse))


func _arc(c: Vector2, angle: float, half_width: float, color: Color, thickness: float) -> void:
	# Godot's draw_arc measures from +X; screen "up" is -90 degrees.
	var centre := angle - PI * 0.5
	draw_arc(c, RADIUS, centre - half_width, centre + half_width, 24, Color(0.05, 0.0, 0.08, color.a * 0.6), thickness + 6.0, true)
	draw_arc(c, RADIUS, centre - half_width, centre + half_width, 24, color, thickness, true)
