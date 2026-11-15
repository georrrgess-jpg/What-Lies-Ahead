class_name EndlessProps
extends RefCounted
## Small building blocks for the Endless features the director builds at run
## time (traps, supply crates): the art kit's model when it exists
## (art/models/city_*.glb), chunky stand-in shapes otherwise, shared
## materials, signs and cheap particle bursts.

const MODELS := "res://art/models/"
const HAZARD := [Color(1.0, 0.78, 0.12), Color(0.08, 0.07, 0.09)]

static var _materials := {}
static var _burst_mesh: BoxMesh
static var _stripes: ImageTexture


## The kit's model `city_<name>.glb` as a fresh instance, or null.
static func model(name: String) -> Node3D:
	var path := MODELS + "city_%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


## A shared lit material (or glowing when `glow` > 0).
static func mat(color: Color, glow := 0.0, roughness := 0.75) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), glow, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_materials[key] = m
	return m


## Yellow-and-black hazard stripes (diagonal, tiling).
static func hazard_mat() -> StandardMaterial3D:
	if _materials.has("hazard"):
		return _materials["hazard"]
	if _stripes == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		for y in 32:
			for x in 32:
				img.set_pixel(x, y, HAZARD[((x + y) / 8) % 2])
		img.generate_mipmaps()
		_stripes = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _stripes
	m.uv1_scale = Vector3(3, 3, 3)
	m.roughness = 0.6
	_materials["hazard"] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, material)


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _instance(parent, mesh, pos, material)


static func _instance(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A sign that always faces the player (turning about Y only).
static func sign(parent: Node3D, text: String, font_size: int, color: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiKit.display_font()
	l.font_size = font_size
	l.pixel_size = 0.008
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.02, 0.06, 0.9)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.position = pos
	parent.add_child(l)
	return l


static func light(parent: Node3D, color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.position = pos
	o.shadow_enabled = false
	parent.add_child(o)
	return o


## A cheap particle burst (FxBurst) of cubes in `colors`.
static func burst(parent: Node, at: Vector3, direction: Vector3, colors: Array, amount: int, speed: float, life: float, size: float, spread := 70.0, gravity := Vector3(0, -6.0, 0)) -> void:
	if _burst_mesh == null:
		_burst_mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_burst_mesh.material = m
	FxBurst.spawn(parent, at, direction, colors, amount, speed, life, size, spread, gravity, _burst_mesh)
