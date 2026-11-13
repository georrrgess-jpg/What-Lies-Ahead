extends "res://scripts/run/level_environment.gd"
## Root script for Midnight Mall. Does everything level_environment.gd does
## (graphics preset, bulb halos) and runs the mall after hours:
##  - the Moonfall Fountain's colour show: its pool lights (material
##    "MallFountainLight"), its water (material "MallWater", swapped for the
##    animated water shader) and its glow light (group "mall_fountain_light")
##    cycle through the neon palette;
##  - the POWER CUT twist (a wave whose WaveData.twist is &"power_cut"): the
##    mains trip with a flicker and a clunk. Lights in group "mall_mains" fall
##    to a glimmer, neon and lit panels (group "mall_neon") and signs (group
##    "mall_signs") go dark, the ambient light drops, and the red emergency
##    lights (group "mall_emergency", material "MallEmergency") pulse. The
##    moonlight through the dome stays. Power returns when the wave is cleared.

const WATER_SHADER := "res://art/shaders/mall_water.gdshader"
const FOUNTAIN_COLORS: Array[Color] = [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 0.9), Color(0.62, 0.45, 1.0), Color(1.0, 0.72, 0.3)]
## Seconds each fountain colour holds before blending to the next.
const FOUNTAIN_STEP := 3.5
## What is left of the mains, the neon and the ambient light during the cut.
const CUT_MAINS := 0.06
const CUT_NEON := 0.1
const CUT_AMBIENT := 0.5
const CUT_SIGNS := Color(0.22, 0.2, 0.3)
const EMERGENCY_PERIOD := 1.3
const EMERGENCY_ENERGY := 1.8

var _time := 0.0
var _fountain_mats: Array[StandardMaterial3D] = []
var _water: ShaderMaterial
var _fountain_lights: Array[OmniLight3D] = []
var _director: RunDirector
var _cut := false
var _cut_level := 0.0           # 0 = power on, 1 = power cut
var _mains := {}                # OmniLight3D -> energy
var _neon := {}                 # BaseMaterial3D -> emission energy
var _signs := {}                # Label3D -> modulate
var _emergency_lights: Array[OmniLight3D] = []
var _emergency_mat: StandardMaterial3D
var _environment: Environment
var _ambient := 0.0


func _ready() -> void:
	super()
	_water = ShaderMaterial.new()
	_water.shader = load(WATER_SHADER)
	_collect(self)
	for node in get_tree().get_nodes_in_group("mall_fountain_light"):
		if node is OmniLight3D and is_ancestor_of(node):
			_fountain_lights.append(node)
	for node in get_tree().get_nodes_in_group("mall_mains"):
		if node is OmniLight3D and is_ancestor_of(node):
			_mains[node] = (node as OmniLight3D).light_energy
	for node in get_tree().get_nodes_in_group("mall_emergency"):
		if node is OmniLight3D and is_ancestor_of(node):
			_emergency_lights.append(node)
	for node in get_tree().get_nodes_in_group("mall_signs"):
		if node is Label3D and is_ancestor_of(node):
			_signs[node] = (node as Label3D).modulate
	for node in get_tree().get_nodes_in_group("mall_neon"):
		if is_ancestor_of(node):
			_add_neon(node)
	if world_environment and world_environment.environment:
		# Work on a copy: the scene's resource is shared with the next Retry.
		world_environment.environment = world_environment.environment.duplicate()
		_environment = world_environment.environment
		_ambient = _environment.ambient_light_energy


## Swaps the fountain water for the shader and gathers the materials the
## level animates (fountain lights, emergency lamps).
func _collect(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			match String(m.resource_name):
				"MallWater":
					mi.set_surface_override_material(i, _water)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"MallFountainLight":
					var own := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					mi.set_surface_override_material(i, own)
					_fountain_mats.append(own)
				"MallEmergency":
					if _emergency_mat == null:
						_emergency_mat = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
						_emergency_mat.emission_energy_multiplier = 0.4
					mi.set_surface_override_material(i, _emergency_mat)
	for child in node.get_children():
		_collect(child)


func _add_neon(node: Node) -> void:
	var m: Material = null
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
		var mesh := (node as MultiMeshInstance3D).multimesh.mesh
		m = mesh.surface_get_material(0) if mesh else null
	elif node is GeometryInstance3D:
		m = (node as GeometryInstance3D).material_override
	if m is BaseMaterial3D and not _neon.has(m):
		_neon[m] = (m as BaseMaterial3D).emission_energy_multiplier


func _process(delta: float) -> void:
	_time += delta
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _set_cut(false))
	_update_fountain()
	_update_cut(delta)


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_set_cut(wave != null and wave.twist == &"power_cut")


func _set_cut(on: bool) -> void:
	if on == _cut:
		return
	_cut = on
	Sfx.play(&"mall_power_down" if on else &"mall_power_up", -2.0)
	for l in _emergency_lights:
		l.visible = on


## The fountain's lights blend from one palette colour to the next.
func _update_fountain() -> void:
	var f := _time / FOUNTAIN_STEP
	var i := int(f) % FOUNTAIN_COLORS.size()
	var c := FOUNTAIN_COLORS[i].lerp(FOUNTAIN_COLORS[(i + 1) % FOUNTAIN_COLORS.size()], smoothstep(0.7, 1.0, fmod(f, 1.0)))
	var power := 1.0 - _cut_level
	for m in _fountain_mats:
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = 3.0 * power
	_water.set_shader_parameter("tint", c.lerp(Color(0.45, 0.85, 1.0), 0.45).lerp(Color(0.12, 0.16, 0.3), _cut_level))
	for l in _fountain_lights:
		l.light_color = c
		l.light_energy = 2.2 * power


## Eases the power level toward the target, with a stutter on the way down,
## and pulses the emergency lights while the power is out.
func _update_cut(delta: float) -> void:
	var target := 1.0 if _cut else 0.0
	if _cut_level != target:
		_cut_level = move_toward(_cut_level, target, delta / (0.9 if _cut else 2.5))
		var k := _cut_level
		if _cut and _cut_level < 0.8:
			k = _cut_level * (0.6 + 0.4 * absf(sin(_time * 37.0)))
		_apply_power(k)
	if _cut_level > 0.0:
		var pulse := 0.5 + 0.5 * sin(TAU * _time / EMERGENCY_PERIOD)
		for l in _emergency_lights:
			l.light_energy = EMERGENCY_ENERGY * _cut_level * (0.25 + 0.75 * pulse)
		if _emergency_mat:
			_emergency_mat.emission_energy_multiplier = 0.4 + 3.2 * _cut_level * pulse


func _apply_power(k: float) -> void:
	for l in _mains:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = float(_mains[l]) * lerpf(1.0, CUT_MAINS, k)
	for m in _neon:
		(m as BaseMaterial3D).emission_energy_multiplier = float(_neon[m]) * lerpf(1.0, CUT_NEON, k)
	for s in _signs:
		if is_instance_valid(s):
			(s as Label3D).modulate = (_signs[s] as Color).lerp(CUT_SIGNS, k)
	if _environment:
		_environment.ambient_light_energy = _ambient * lerpf(1.0, CUT_AMBIENT, k)
