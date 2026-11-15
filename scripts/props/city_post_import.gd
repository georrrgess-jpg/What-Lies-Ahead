@tool
extends EditorScenePostImport
## Import script of every art/models/city_*.glb (Ashfall City kit; set as
## import_script/path in their .import files). Swaps the Blender materials by
## name, so the textures and animated surfaces are baked into the imported
## scene and every level that places a kit model gets them for free:
##
##   City<Key>          the palette colour with the shared grime texture
##                      (object-space triplanar: soot, streaks, chips)
##   CityBrick*         brick texture tinted by the colour
##   CityConcrete*      concrete texture tinted by the colour
##   CityNeon_<hex>     flickering neon (art/shaders/city_neon.gdshader)
##   CityHalo_<hex>     additive halo glow in that colour (bulb_halo.gdshader)
##   CityEmber          smouldering embers; CityFire a hotter, faster glow
##   CityPoliceRed/Blue alternating strobe halves of a light bar
##   CityLit_*, CityGlass*  kept as exported (steady lamps, glass)

const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

## World metres per texture tile.
const GRIME_TILE := 3.0
const BRICK_TILE := 2.2
const CONCRETE_TILE := 3.5

var _cache: Dictionary = {}


func _post_import(scene: Node) -> Object:
	_cache.clear()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material == null:
				continue
			var swapped := _swap(material)
			if swapped:
				mesh.surface_set_material(i, swapped)
	return scene


func _swap(material: Material) -> Material:
	var key := material.resource_name
	if not key.begins_with("City"):
		return null
	if _cache.has(key):
		return _cache[key]
	var result := _build(key, material as BaseMaterial3D)
	_cache[key] = result
	return result


func _build(key: String, source: BaseMaterial3D) -> Material:
	if source == null or key.begins_with("CityLit_"):
		return null
	if key == "CityGlass":
		return _cracked_glass(key)
	if key.begins_with("CityGlass"):
		return null
	if key.begins_with("CityNeon_"):
		return _shader("city_neon", {"color": _hex(key), "strength": 3.2}, key)
	if key.begins_with("CityHalo_"):
		return _shader("bulb_halo", {"glow_color": _hex(key), "strength": 0.6}, key)
	if key == "CityEmber":
		return _shader("city_ember", {"strength": 2.6, "speed": 0.8}, key)
	if key == "CityFire":
		return _shader("city_ember", {"strength": 4.5, "speed": 2.2, "cool_color": Color(0.9, 0.22, 0.04), "hot_color": Color(1.0, 0.8, 0.3)}, key)
	if key == "CityPoliceRed":
		return _shader("city_police", {"color": Color(1.0, 0.16, 0.22), "phase": 0.0}, key)
	if key == "CityPoliceBlue":
		return _shader("city_police", {"color": Color(0.2, 0.42, 1.0), "phase": 0.5}, key)
	if source.emission_enabled:
		return null
	if key.begins_with("CityBrick"):
		return _textured(source, "city_brick", BRICK_TILE, true)
	if key.begins_with("CityConcrete"):
		return _textured(source, "city_concrete", CONCRETE_TILE, true)
	return _textured(source, "city_grime", GRIME_TILE, false)


func _textured(source: BaseMaterial3D, texture: String, tile: float, with_normal: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = source.resource_name
	m.albedo_color = source.albedo_color
	m.albedo_texture = load(TEXTURES + texture + ".png")
	m.roughness = source.roughness
	m.metallic = source.metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE / tile
	m.uv1_triplanar_sharpness = 4.0
	if with_normal:
		m.normal_enabled = true
		m.normal_texture = load(TEXTURES + texture + "_normal.png")
		m.normal_scale = 0.7
	return m


func _shader(shader: String, params: Dictionary, key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + shader + ".gdshader")
	for p in params:
		m.set_shader_parameter(p, params[p])
	return m


## The colour encoded after the last underscore of a material name ("CityNeon_ff2fae").
func _hex(key: String) -> Color:
	return Color.html(key.get_slice("_", key.get_slice_count("_") - 1))


## The broken panes left in window frames: dark tinted glass with a glossy
## sheen and a cool rim, so a shard reads as glass against the dark rooms
## behind it (the exported pale blue read as holes through to the sky).
func _cracked_glass(key: String) -> Material:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = Color(0.1, 0.16, 0.2)
	m.metallic = 0.7
	m.metallic_specular = 0.8
	m.roughness = 0.12
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.3
	return m
