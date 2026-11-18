extends Node3D
## Boomtown weather: the Dust Storm twist. When a wave whose twist is
## `dust_storm` starts, a desert storm rolls in: the sky turns ochre, the sun
## dims and warms, an orange haze closes the view down the street, gusts howl
## and tumbleweeds bowl across the town. It clears once the wave is won.
## Listens to the run director, so it stays calm behind the main menu.

const TWIST := &"dust_storm"
const TUMBLEWEED := "res://art/models/gulch_tumbleweed.glb"

## Seconds for the storm to build or clear.
@export var transition := 4.0
@export var storm_fog_density := 0.034
@export var storm_fog_color := Color(0.86, 0.6, 0.36)
@export var storm_sun_color := Color(1.0, 0.72, 0.45)
@export var storm_sun_energy := 0.6
@export var storm_ambient_energy := 0.75
@export var storm_ambient_color := Color(0.9, 0.66, 0.46)
## Seconds between gusts (random in this range).
@export var gust_gap := Vector2(3.5, 7.0)
@export var tumbleweed_count := 14
## Lanes the tumbleweeds bowl down, north to south: (x from, x to, z end).
@export var lanes: Array[Vector3] = [Vector3(-6.5, 6.5, 37.0), Vector3(-25.0, -20.5, 22.5), Vector3(20.5, 29.0, 22.5)]
## Where every lane starts (the mine yard).
@export var roll_start := -44.0

var _director: RunDirector
var _storm := 0.0
var _target := 0.0
var _environment: Environment
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _base := {}
var _next_gust := 0.0
var _weeds: MultiMeshInstance3D
var _weed_pos := PackedVector3Array()
var _weed_speed := PackedFloat32Array()
var _weed_spin := PackedFloat32Array()
var _weed_lane := PackedInt32Array()


func _ready() -> void:
	# Work on copies: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment = we.environment.duplicate(true)
		_environment = we.environment
		_sky = _environment.sky.sky_material as ShaderMaterial if _environment.sky else null
		_base["fog_density"] = _environment.fog_density
		_base["fog_color"] = _environment.fog_light_color
		_base["ambient"] = _environment.ambient_light_energy
		_base["ambient_color"] = _environment.ambient_light_color
	_sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_base["sun_energy"] = _sun.light_energy
		_base["sun_color"] = _sun.light_color
	_make_weeds()


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(_on_wave_cleared)
	var next := move_toward(_storm, _target, delta / transition)
	if next != _storm:
		_storm = next
		_apply(ease(_storm, -1.6))
	if _storm > 0.01:
		_roll(delta)
		if _target > 0.0:
			_next_gust -= delta
			if _next_gust <= 0.0:
				_next_gust = randf_range(gust_gap.x, gust_gap.y)
				Sfx.play(&"gulch_wind_gust", -4.0 + _storm * 2.0, randf_range(0.9, 1.1))
	elif _weeds and _weeds.visible:
		_weeds.visible = false


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	if wave and wave.twist == TWIST:
		_target = 1.0
		_next_gust = 1.0


func _on_wave_cleared(_number: int, _total: int) -> void:
	_target = 0.0


func _apply(k: float) -> void:
	if _environment:
		_environment.fog_density = lerpf(_base["fog_density"], storm_fog_density, k)
		_environment.fog_light_color = (_base["fog_color"] as Color).lerp(storm_fog_color, k)
		_environment.ambient_light_energy = lerpf(_base["ambient"], storm_ambient_energy, k)
		_environment.ambient_light_color = (_base["ambient_color"] as Color).lerp(storm_ambient_color, k)
	if _sun:
		_sun.light_energy = lerpf(_base["sun_energy"], storm_sun_energy, k)
		_sun.light_color = (_base["sun_color"] as Color).lerp(storm_sun_color, k)
	if _sky:
		_sky.set_shader_parameter("dust", k)


func _make_weeds() -> void:
	if not ResourceLoader.exists(TUMBLEWEED):
		return
	var source: Node3D = (load(TUMBLEWEED) as PackedScene).instantiate()
	var found := source.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	source.free()
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tumbleweed_count
	_weeds = MultiMeshInstance3D.new()
	_weeds.name = "Tumbleweeds"
	_weeds.multimesh = mm
	_weeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weeds.visible = false
	add_child(_weeds)
	_weed_pos.resize(tumbleweed_count)
	_weed_speed.resize(tumbleweed_count)
	_weed_spin.resize(tumbleweed_count)
	_weed_lane.resize(tumbleweed_count)
	for i in tumbleweed_count:
		_weed_lane[i] = 0 if i % 3 != 2 else 1 + (i / 3) % 2
		var lane := lanes[_weed_lane[i]]
		_weed_pos[i] = Vector3(randf_range(lane.x, lane.y), 0.0, randf_range(roll_start, lane.z))
		_weed_speed[i] = randf_range(4.0, 7.5)
		_weed_spin[i] = randf() * TAU


## Rolls the tumbleweeds down their lanes with a little bounce, starting over at the mine.
func _roll(delta: float) -> void:
	if _weeds == null:
		return
	_weeds.visible = true
	var mm := _weeds.multimesh
	var size := lerpf(0.0, 1.0, clampf(_storm * 1.5, 0.0, 1.0))
	for i in tumbleweed_count:
		var p := _weed_pos[i]
		var lane := lanes[_weed_lane[i]]
		p.z += _weed_speed[i] * delta * _storm
		if p.z > lane.z:
			p = Vector3(randf_range(lane.x, lane.y), 0.0, roll_start)
		_weed_pos[i] = p
		_weed_spin[i] = fposmod(_weed_spin[i] + _weed_speed[i] * delta * 2.0, TAU)
		var hop := absf(sin(_weed_spin[i] * 1.5)) * 0.5
		var basis := Basis(Vector3.RIGHT, _weed_spin[i]).scaled(Vector3.ONE * size)
		mm.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 0.5 * size + hop, 0)))
