class_name EndlessPowerup
extends Node3D
## A power-up lying where a zombie fell (EndlessPowerups drops it): a chunky
## glowing token in its colour, spinning and bobbing over a ring of light,
## with a short beam and its name over it. It lies for `life` seconds,
## blinking faster through the last few, and is taken by walking into it.

signal collected(powerup: EndlessPowerup)

const PICKUP := 1.8
## Seconds of blinking before it is gone.
const WARN := 5.0

var kind: StringName
var color := Color.WHITE
var title := ""
var glyph := ""
var life := 20.0
var director: RunDirector

var _token: Node3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0
var _done := false


func _ready() -> void:
	add_to_group("endless_powerup")
	_build()
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Seconds before it disappears.
func time_left() -> float:
	return maxf(0.0, life - _time)


func _process(delta: float) -> void:
	_time += delta
	_token.rotation.y += delta * 2.4
	_token.position.y = 1.0 + sin(_time * 3.2) * 0.12
	var left := life - _time
	var shown := true
	if left < WARN:
		# Blinks faster as it runs out.
		shown = fmod(_time * lerpf(9.0, 3.0, left / WARN), 1.0) > 0.35
	_token.visible = shown
	_light.light_energy = (2.2 + sin(_time * 6.0) * 0.4) if shown else 0.4
	_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(_time * 4.0))
	if left <= 0.0 and not _done:
		_done = true
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_callback(queue_free)
		return
	var player := director.player if director else null
	if not _done and player and player.alive and _flat_distance(player.global_position) < PICKUP:
		_done = true
		collected.emit(self)
		EndlessProps.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, [color, color.lerp(Color.WHITE, 0.6)], 36, 5.0, 0.7, 0.12, 80.0)
		queue_free()


func _flat_distance(at: Vector3) -> float:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() + maxf(0.0, absf(at.y - global_position.y) - 1.5)


# --- looks ---------------------------------------------------------------------

## The token (a thick coin with the glyph on both faces), the ring and beam
## of light under it, and the name over it.
func _build() -> void:
	_token = Node3D.new()
	_token.name = "Token"
	add_child(_token)
	var coin := EndlessProps.cylinder(_token, 0.42, 0.16, Vector3.ZERO, EndlessProps.mat(color, 2.4, 0.3), 20)
	coin.rotation.x = PI * 0.5
	EndlessProps.cylinder(_token, 0.47, 0.1, Vector3.ZERO, EndlessProps.mat(color.lerp(Color.WHITE, 0.5), 1.0, 0.3), 20).rotation.x = PI * 0.5
	for side in [1.0, -1.0]:
		var l := EndlessProps.sign(_token, glyph, 64, Color(0.08, 0.04, 0.1), Vector3(0, 0, 0.09 * side))
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.outline_size = 0
		l.pixel_size = 0.006
		l.rotation.y = 0.0 if side > 0.0 else PI
	_ring = EndlessProps.cylinder(self, 0.9, 0.04, Vector3(0, 0.03, 0), _additive(Color(color, 0.5)), 24)
	EndlessProps.cylinder(self, 0.12, 3.0, Vector3(0, 1.5, 0), _additive(Color(color, 0.22)), 8)
	var name_tag := EndlessProps.sign(self, title, 34, color.lerp(Color.WHITE, 0.4), Vector3(0, 1.9, 0))
	name_tag.no_depth_test = true
	_light = EndlessProps.light(self, color, 2.2, 6.0, Vector3(0, 1.0, 0))


static func _additive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
