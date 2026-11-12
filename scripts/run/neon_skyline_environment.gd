extends "res://scripts/run/level_environment.gd"
## Root script for Neon Skyline. Does everything level_environment.gd does
## (graphics preset, bulb halos) and adds the night-city life:
##  - rain: open cylinders of falling streaks that follow the active camera;
##  - blinking red aviation beacons (nodes in group "neon_blink");
##  - conventions for models exported from Blender (see art/blender/neon_common.py):
##      material "NeonHalo_<hex>"  additive bulb halo in that colour;
##      material "NeonHolo..."     additive hologram (neon_holo.gdshader) tinted
##                                 from the material's colour;
##      node "Blink..."            blinks on and off (aviation beacons);
##      node "Spin..."             turns slowly about its vertical axis.

const RAIN_SHADER := "res://art/shaders/neon_rain.gdshader"
const HOLO_SHADER := "res://art/shaders/neon_holo.gdshader"
## Rain layers: radius, height, streak columns. The outer layers are skipped
## on the Low graphics preset.
const RAIN_LAYERS := [[3.5, 14.0, 70.0], [8.0, 22.0, 150.0], [15.0, 30.0, 260.0]]

## Turn rate of "Spin..." nodes (radians per second).
const SPIN_SPEED := 0.45

var _rain: Array[MeshInstance3D] = []
var _blinkers: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _neon_halos: Array[ShaderMaterial] = []
var _halo_by_color := {}
var _holo_cache := {}
var _time := 0.0


func _ready() -> void:
	_build_rain()
	super()
	_apply_neon_materials(self)
	for node in get_tree().get_nodes_in_group("neon_blink"):
		if node is Node3D and is_ancestor_of(node):
			_blinkers.append(node)
	apply_graphics_preset(Settings.is_low_graphics())


func apply_graphics_preset(low: bool) -> void:
	super(low)
	for i in _rain.size():
		_rain[i].visible = i == 0 or not low
	for m in _neon_halos:
		m.set_shader_parameter("strength", 0.45 if low else 0.65)


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		for r in _rain:
			r.global_position = Vector3(p.x, p.y - 4.0, p.z)
	for b in _blinkers:
		if is_instance_valid(b):
			var phase := fmod(absf(b.global_position.x * 0.37 + b.global_position.z * 0.21), 1.7)
			b.visible = fmod(_time + phase, 1.7) < 0.55
	for s in _spinners:
		if is_instance_valid(s):
			s.rotate_y(SPIN_SPEED * delta)


func _build_rain() -> void:
	var material := ShaderMaterial.new()
	material.shader = load(RAIN_SHADER)
	for layer in RAIN_LAYERS:
		var mi := MeshInstance3D.new()
		mi.name = "Rain%d" % _rain.size()
		var m: ShaderMaterial = material.duplicate()
		m.set_shader_parameter("columns", layer[2])
		m.set_shader_parameter("strength", 0.26 - 0.05 * _rain.size())
		mi.mesh = _rain_cylinder(layer[0], layer[1], m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 40.0
		add_child(mi)
		_rain.append(mi)


## Open cylinder (no caps), UV.x around, UV.y from top (0) to bottom (1).
func _rain_cylinder(radius: float, height: float, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		var quad := [[p0 + Vector3.UP * height, Vector2(u0, 0)], [p1 + Vector3.UP * height, Vector2(u1, 0)],
			[p1, Vector2(u1, 1)], [p0, Vector2(u0, 1)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


## Swaps the placeholder materials of imported models for the neon shaders
## and collects blinking and spinning nodes.
func _apply_neon_materials(node: Node) -> void:
	if node is Node3D and String(node.name).begins_with("Blink"):
		_blinkers.append(node)
	elif node is Node3D and String(node.name).begins_with("Spin"):
		_spinners.append(node)
	if node is MeshInstance3D and node.mesh:
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			var n := String(m.resource_name)
			if n.begins_with("NeonHalo"):
				mi.set_surface_override_material(i, _neon_halo_material(m))
			elif n.begins_with("NeonHolo"):
				mi.set_surface_override_material(i, _holo_material(m))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_neon_materials(child)


func _neon_halo_material(source: Material) -> ShaderMaterial:
	var color := (source as BaseMaterial3D).albedo_color if source is BaseMaterial3D else Color(1.0, 0.7, 0.3)
	var key := color.to_html(false)
	if not _halo_by_color.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(HALO_SHADER)
		m.set_shader_parameter("glow_color", color)
		_halo_by_color[key] = m
		_neon_halos.append(m)
	return _halo_by_color[key]


func _holo_material(source: Material) -> ShaderMaterial:
	var color := Color(0.3, 0.95, 1.0)
	if source is BaseMaterial3D:
		color = (source as BaseMaterial3D).albedo_color
	var key := color.to_html(false)
	if not _holo_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(HOLO_SHADER)
		m.set_shader_parameter("color_a", color)
		m.set_shader_parameter("color_b", Color.from_hsv(fmod(color.h + 0.16, 1.0), color.s * 0.8, 1.0))
		_holo_cache[key] = m
	return _holo_cache[key]

