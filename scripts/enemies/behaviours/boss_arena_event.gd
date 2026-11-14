class_name BossArenaEvent
extends Resource
## Something the arena does when an alpha reaches a phase (listed in
## AlphaBossBehaviour.events). Each is announced with a HUD callout and lasts
## `seconds` (0 = until the alpha falls). Kinds:
##
##   darkness   the lights go out (sky, ambient and sun dim to `strength`);
##              the alpha carries a light of its own colour so it still reads
##   gale       wind leans on the player along a heading that swings round
##              every few seconds (`strength` m/s; streaks show the way)
##   ink        ink clouds creep in from the screen edges (`strength` = how far)
##   chill      a freezing blizzard: the player moves at `strength` x speed and
##              frost creeps over the screen edges
##   frenzy     the alpha goes into a rush: `strength` x speed and its moves
##              come back that much faster

@export var kind: StringName = &"darkness"
@export var phase := 1
@export var seconds := 0.0
@export var strength := 0.3
@export var color := Color(0.4, 0.2, 0.8)
@export var callout := ""
@export var sound: StringName = &"boss_event"

const FADE := 1.2
const GUST_SECONDS := Vector2(3.5, 5.5)

var _left := 0.0
var _on := false
var _environment: Environment
var _saved := {}
var _light: OmniLight3D
var _overlay: CanvasLayer
var _overlay_mat: ShaderMaterial
var _heading := Vector3.RIGHT
var _gust := 0.0
var _streaks: CPUParticles3D
var _speeds := Vector2.ZERO
var _level := 0.0

static var _vignette: Shader


func is_active() -> bool:
	return _on


## Multiplies the alpha's speed and move tempo while this event runs.
func tempo() -> float:
	return strength if _on and kind == &"frenzy" else 1.0


func start(z: Zombie) -> void:
	if _on:
		return
	_on = true
	_left = seconds
	_level = 0.0
	Sfx.play(sound, 0.0)
	match kind:
		&"darkness":
			_dim(z, true)
			_light = OmniLight3D.new()
			_light.light_color = color
			_light.light_energy = 3.0
			_light.omni_range = 9.0
			z.add_child(_light)
			_light.position = Vector3.UP * 2.5 * z.data.body_scale
		&"ink", &"chill":
			_add_overlay(z)
			if kind == &"chill":
				_speeds = Vector2(z.target.walk_speed, z.target.sprint_speed)
				z.target.walk_speed *= strength
				z.target.sprint_speed *= strength
		&"gale":
			_gust = 0.0
			_streaks = _make_streaks()
			z.get_parent().add_child(_streaks)


func stop(z: Zombie) -> void:
	if not _on:
		return
	_on = false
	match kind:
		&"darkness":
			_dim(z, false)
			if is_instance_valid(_light):
				_light.queue_free()
		&"ink", &"chill":
			if is_instance_valid(_overlay):
				var tw := _overlay.create_tween()
				tw.tween_method(_set_overlay, _level, 0.0, FADE)
				tw.tween_callback(_overlay.queue_free)
			if kind == &"chill" and is_instance_valid(z.target):
				z.target.walk_speed = _speeds.x
				z.target.sprint_speed = _speeds.y
		&"gale":
			if is_instance_valid(_streaks):
				_streaks.queue_free()


func tick(z: Zombie, delta: float) -> void:
	if not _on:
		return
	_level = minf(1.0, _level + delta / FADE)
	if seconds > 0.0:
		_left -= delta
		if _left <= 0.0:
			stop(z)
			return
	match kind:
		&"ink", &"chill":
			_set_overlay(_level)
		&"gale":
			_blow(z, delta)


func _blow(z: Zombie, delta: float) -> void:
	_gust -= delta
	if _gust <= 0.0:
		_gust = randf_range(GUST_SECONDS.x, GUST_SECONDS.y)
		var a := randf() * TAU
		_heading = Vector3(cos(a), 0.0, sin(a))
		Sfx.play(&"boss_gust", -2.0, randf_range(0.9, 1.1))
	var player := z.target
	if not player.alive or not player.controls_enabled:
		return
	player.move_and_collide(_heading * strength * _level * delta)
	if is_instance_valid(_streaks):
		_streaks.global_position = player.global_position + Vector3.UP * 1.5 - _heading * 9.0
		_streaks.direction = _heading
		_streaks.emitting = true


func _make_streaks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7, 2.5, 7)
	p.spread = 4.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 22.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 1.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1, 1, 1, 0.45)
	q.material = m
	p.mesh = q
	return p


## Ink or frost creeping in from the screen edges (a full-screen vignette).
func _add_overlay(z: Zombie) -> void:
	if _vignette == null:
		_vignette = Shader.new()
		_vignette.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float level = 0.0;
uniform float reach = 0.3;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = max(abs(p.x), abs(p.y) * 0.85) + 0.08 * sin(UV.y * 14.0 + TIME * 1.7) * sin(UV.x * 11.0 - TIME * 1.3);
	float edge = smoothstep(1.0 - reach * level, 1.12 - reach * level * 0.4, d);
	COLOR = vec4(tint.rgb, tint.a * edge * level);
}
"""
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = _vignette
	_overlay_mat.set_shader_parameter("tint", Color(color, 0.92))
	_overlay_mat.set_shader_parameter("reach", strength)
	rect.material = _overlay_mat
	_overlay.add_child(rect)
	z.get_tree().current_scene.add_child(_overlay)


func _set_overlay(k: float) -> void:
	if _overlay_mat:
		_overlay_mat.set_shader_parameter("level", k)


## Dims the level's sky, ambient light and sun to `strength` (or back up).
func _dim(z: Zombie, on: bool) -> void:
	var level := z.get_tree().current_scene
	if _environment == null:
		var we := level.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we == null or we.environment == null:
			return
		# Work on a copy: the scene's resource is shared with the next Retry.
		we.environment = we.environment.duplicate()
		_environment = we.environment
		_saved[&"ambient"] = _environment.ambient_light_energy
		_saved[&"background"] = _environment.background_energy_multiplier
		for node in level.find_children("*", "DirectionalLight3D", true, false):
			_saved[node] = (node as DirectionalLight3D).light_energy
	var k := strength if on else 1.0
	var tw := level.create_tween().set_parallel()
	tw.tween_property(_environment, "ambient_light_energy", float(_saved[&"ambient"]) * k, FADE)
	tw.tween_property(_environment, "background_energy_multiplier", float(_saved[&"background"]) * k, FADE)
	for light in _saved:
		if light is DirectionalLight3D and is_instance_valid(light):
			tw.tween_property(light, "light_energy", float(_saved[light]) * k, FADE)
