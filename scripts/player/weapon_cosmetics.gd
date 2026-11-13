class_name WeaponCosmetics
extends RefCounted
## Applies equipped cosmetics to a weapon model (viewmodel or menu preview).
## Weapon models follow one naming contract (art/blender/weapon_kit.py):
##   materials  "Shell" (main colour), "Trim" (panels), "Cell" (energy glow),
##              arms "Glove", "GlovePlate", "Cuff", "Sleeve"
##   nodes      "Decal" (emblem, hidden unless a decal is equipped),
##              "CharmPoint" (the eye of the charm lug a charm hangs from),
##              "ArmL"/"ArmR" (first-person arms), "*Holo" (hologram copies
##              of the cell, shown only during reloads)
## Menu previews show the bare weapon: prepare_preview() hides the arms and
## hologram parts wherever they sit in the model.
## `loadout` is Cosmetics.weapon_loadout(weapon_id):
##   {finish, cell, decal, charm, arms} (any may be null or missing).
##
## Finishes: flat colours ([shell, trim], params metallic/roughness), or a
## shader: params = {"shader": "res://art/shaders/x.gdshader", "shader_params": {...}}.
## The shader receives `shell_color` and `trim_color` (from `colors`), any
## shader_params, and is applied to both the Shell and Trim surfaces (Trim gets
## `is_trim = true`).
## Cells: colors[0]; params.animate = "rainbow" or "pulse" animates it (CellGlow).
## Decals: colors [fill, edge, ink]; params.emblem names a sticker in
##   art/models/cosmetic_decals.glb ("Heart" -> node "Emblem_Heart"); without
##   one, the weapon's own emblem is tinted. params.shader styles the fill.
## Charms: params.charm names a node in art/models/cosmetic_charms.glb
##   ("Duck" -> "Charm_Duck"), hung from CharmPoint with swing (WeaponCharm).
## Arms: a gloves item or an operator. colors [glove, plate, cuff, sleeve,
##   accent, third]; params pattern (see PATTERNS), pattern_on (material
##   names), scale, metallic, roughness, glow, shader + shader_on.

const CHARMS_SCENE := "res://art/models/cosmetic_charms.glb"
const DECALS_SCENE := "res://art/models/cosmetic_decals.glb"
const GLOVE_SHADER := "res://art/shaders/skin_glove.gdshader"
const ARM_MATERIALS := ["Glove", "GlovePlate", "Cuff", "Sleeve"]
const PATTERNS := {
	"solid": 0, "stripes": 1, "camo": 2, "checker": 3, "dots": 4, "knit": 5, "tiger": 6,
	"neon": 7, "scales": 8, "flames": 9, "stars": 10, "pixels": 11,
}

static var _shaders := {}
static var _materials := {}
static var _prop_meshes := {}


static func apply(model: Node3D, _weapon: WeaponData, loadout: Dictionary) -> void:
	var finish: CosmeticItem = loadout.get("finish")
	var cell: CosmeticItem = loadout.get("cell")
	_walk(model, finish, cell, loadout.get("arms"))
	_apply_decal(model, loadout.get("decal"))
	_apply_charm(model, loadout.get("charm"))
	_apply_cell_animation(model, cell)


## Gets a freshly instantiated weapon model ready for a menu preview: hides
## the hologram copies of the cell and (unless `with_arms`) the first-person
## arms, wherever they are parented.
static func prepare_preview(model: Node3D, with_arms := false) -> void:
	for node in model.find_children("*", "Node3D", true, false):
		var node_name := String(node.name)
		if node_name.ends_with("Holo") or (not with_arms and node_name.begins_with("Arm")):
			(node as Node3D).visible = false


## Bounds of the visible meshes of a weapon model, in the model's own space
## (works outside the scene tree; a hanging charm is left out).
static func visible_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.get_parent().name == "WeaponCharm" or not _shown_in(model, mi):
			continue
		var box := to_model(model, mi) * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


static func _shown_in(model: Node3D, node: Node3D) -> bool:
	var n: Node = node
	while n and n != model:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


## The material a finish puts on a Shell (or Trim) surface. Shared between
## every weapon wearing the same finish.
static func finish_material(finish: CosmeticItem, base: StandardMaterial3D, is_trim: bool) -> Material:
	var key := "finish|%s|%s|%s" % [finish.id, is_trim, base.albedo_color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var out: Material
	if finish.params.has("shader"):
		var m := ShaderMaterial.new()
		m.shader = shader(String(finish.params["shader"]))
		m.set_shader_parameter("shell_color", finish.color(0, base.albedo_color))
		m.set_shader_parameter("trim_color", finish.color(1, base.albedo_color))
		m.set_shader_parameter("is_trim", is_trim)
		var extra: Dictionary = finish.params.get("shader_params", {})
		for k in extra:
			m.set_shader_parameter(k, extra[k])
		out = m
	else:
		var s: StandardMaterial3D = base.duplicate()
		s.albedo_color = finish.color(1, base.albedo_color) if is_trim else finish.color(0)
		s.metallic = float(finish.params.get("metallic", 0.0)) * (0.8 if is_trim else 1.0)
		s.roughness = float(finish.params.get("roughness", 0.5))
		out = s
	_materials[key] = out
	return out


static func _walk(node: Node, finish: CosmeticItem, cell: CosmeticItem, arms: CosmeticItem) -> void:
	if node is MeshInstance3D and node.mesh and not String(node.name).begins_with("Decal"):
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var mat_name := String(base.resource_name)
			var replacement: Material = null
			if (mat_name == "Shell" or mat_name == "Trim") and finish:
				replacement = finish_material(finish, base, mat_name == "Trim")
			elif mat_name == "Cell" and cell:
				var c: StandardMaterial3D = base.duplicate()
				c.albedo_color = cell.color(0)
				c.emission_enabled = true
				c.emission = cell.color(0)
				replacement = c
			elif arms and mat_name in ARM_MATERIALS:
				replacement = arm_material(arms, mat_name, base)
			mi.set_surface_override_material(i, replacement)
	for child in node.get_children():
		_walk(child, finish, cell, arms)


## The material an arm look (gloves item or operator) puts on one of the
## first-person arm surfaces.
static func arm_material(look: CosmeticItem, mat_name: String, base: StandardMaterial3D) -> Material:
	var key := "arm|%s|%s" % [look.id, mat_name]
	if _materials.has(key):
		return _materials[key]
	var index := ARM_MATERIALS.find(mat_name)
	var col := look.color(index, base.albedo_color)
	var p := look.params
	var out: Material
	var shader_on: Array = p.get("shader_on", ARM_MATERIALS)
	var pattern_on: Array = p.get("pattern_on", ["Glove", "Sleeve"])
	var pattern := int(PATTERNS.get(String(p.get("pattern", "solid")), 0))
	if p.has("shader") and mat_name in shader_on:
		var sm := ShaderMaterial.new()
		sm.shader = shader(String(p["shader"]))
		sm.set_shader_parameter("shell_color", col)
		sm.set_shader_parameter("trim_color", look.color(4, col))
		sm.set_shader_parameter("is_trim", mat_name == "GlovePlate" or mat_name == "Cuff")
		out = sm
	elif pattern != 0 and mat_name in pattern_on:
		var gm := ShaderMaterial.new()
		gm.shader = shader(GLOVE_SHADER)
		gm.set_shader_parameter("base_color", col)
		gm.set_shader_parameter("accent_color", look.color(4, Color.WHITE))
		gm.set_shader_parameter("third_color", look.color(5, Color.WHITE))
		gm.set_shader_parameter("pattern", pattern)
		gm.set_shader_parameter("scale", float(p.get("scale", 1.0)))
		gm.set_shader_parameter("roughness", float(p.get("roughness", base.roughness)))
		gm.set_shader_parameter("metallic", float(p.get("metallic", base.metallic)))
		gm.set_shader_parameter("glow", float(p.get("glow", 0.0)))
		out = gm
	else:
		var s: StandardMaterial3D = base.duplicate()
		s.albedo_color = col
		s.roughness = float(p.get("roughness", base.roughness))
		s.metallic = float(p.get("metallic", base.metallic)) if mat_name != "Sleeve" else base.metallic
		if float(p.get("glow", 0.0)) > 0.0 and mat_name == "GlovePlate":
			s.emission_enabled = true
			s.emission = col
			s.emission_energy_multiplier = float(p["glow"])
		out = s
	_materials[key] = out
	return out


# --- decals -------------------------------------------------------------------

static func _apply_decal(model: Node3D, decal: CosmeticItem) -> void:
	var old := model.find_child("DecalSkin", true, false)
	if old:
		old.free()
	var decal_node := model.find_child("Decal", true, false) as MeshInstance3D
	if decal_node == null:
		return
	decal_node.visible = decal != null
	if decal == null:
		return
	var emblem := String(decal.params.get("emblem", ""))
	var mesh := prop_mesh(DECALS_SCENE, "Emblem_" + emblem) if emblem != "" else null
	if mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = decal.color(0)
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = decal.color(0)
		m.emission_energy_multiplier = 0.35
		decal_node.material_override = m
		return
	decal_node.visible = false
	var sticker := MeshInstance3D.new()
	sticker.name = "DecalSkin"
	sticker.mesh = mesh
	sticker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var base := mesh.surface_get_material(i) as StandardMaterial3D
		if base:
			sticker.set_surface_override_material(i, sticker_material(decal, base))
	# Fit the sticker over the weapon's own emblem, facing the same way.
	var box := decal_node.mesh.get_aabb()
	var fit := minf(maxf(box.size.y, box.size.z), minf(box.size.y, box.size.z) * 1.3) * 1.05
	var centre := box.get_center()
	var shell := model.find_child("Shell", true, false) as MeshInstance3D
	var outward := -1.0
	if shell:
		var to_decal := to_model(model, shell).affine_inverse() * to_model(model, decal_node) * centre
		outward = -1.0 if to_decal.x < shell.mesh.get_aabb().get_center().x else 1.0
	var b := Basis.from_scale(Vector3.ONE * fit)
	if outward > 0.0:
		b = Basis(Vector3.UP, PI) * b
	centre.x += outward * box.size.x * 0.25
	sticker.transform = decal_node.transform * Transform3D(b, centre)
	decal_node.add_sibling(sticker)


## The material a decal item puts on one part of a sticker emblem
## (DecalFill, DecalEdge or DecalInk).
static func sticker_material(decal: CosmeticItem, base: StandardMaterial3D) -> Material:
	var part := String(base.resource_name)
	var key := "decal|%s|%s" % [decal.id, part]
	if _materials.has(key):
		return _materials[key]
	var out: Material
	if part == "DecalFill" and decal.params.has("shader"):
		var sm := ShaderMaterial.new()
		sm.shader = shader(String(decal.params["shader"]))
		sm.set_shader_parameter("shell_color", decal.color(0))
		sm.set_shader_parameter("trim_color", decal.color(1, Color.WHITE))
		out = sm
	else:
		var s: StandardMaterial3D = base.duplicate()
		match part:
			"DecalFill":
				s.albedo_color = decal.color(0)
				s.emission_enabled = true
				s.emission = decal.color(0)
				s.emission_energy_multiplier = 0.25
			"DecalEdge":
				s.albedo_color = decal.color(1, Color("1c1830"))
			_:
				s.albedo_color = decal.color(2, decal.color(1, Color("1c1830")))
		out = s
	_materials[key] = out
	return out


# --- charms -------------------------------------------------------------------

static func _apply_charm(model: Node3D, charm: CosmeticItem) -> void:
	var old := model.find_child("WeaponCharm", true, false)
	if old:
		old.free()
	if charm == null:
		return
	var mesh := prop_mesh(CHARMS_SCENE, "Charm_" + String(charm.params.get("charm", "")))
	if mesh == null:
		return
	var swing := WeaponCharm.new()
	swing.name = "WeaponCharm"
	var anchor := model.find_child("CharmPoint", true, false) as Node3D
	swing.setup(mesh, model, anchor)
	if anchor:
		anchor.add_child(swing)
	else:
		model.add_child(swing)
		swing.position = fallback_charm_point(model)


## Where a charm hangs on a model without a CharmPoint: low on the left side
## (the side the player sees), towards the back.
static func fallback_charm_point(model: Node3D) -> Vector3:
	var shell := model.find_child("Shell", true, false) as MeshInstance3D
	if shell == null:
		return Vector3.ZERO
	var box := shell.mesh.get_aabb()
	var local := Vector3(box.position.x + box.size.x * 0.08, box.position.y + box.size.y * 0.35, box.end.z - box.size.z * 0.3)
	return to_model(model, shell) * local


## `node`'s transform in `model`'s space (works outside the scene tree too).
static func to_model(model: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != model:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## A mesh from one of the cosmetic prop libraries, by node name (cached).
static func prop_mesh(scene_path: String, node_name: String) -> Mesh:
	var key := scene_path + "#" + node_name
	if _prop_meshes.has(key):
		return _prop_meshes[key]
	var mesh: Mesh = null
	var scene := load(scene_path) as PackedScene
	if scene:
		var root := scene.instantiate()
		var node := root.find_child(node_name, true, false) as MeshInstance3D
		if node:
			mesh = node.mesh
		root.free()
	_prop_meshes[key] = mesh
	return mesh


# --- animated cells -------------------------------------------------------------

static func _apply_cell_animation(model: Node3D, cell: CosmeticItem) -> void:
	var old := model.find_child("CellGlow", true, false)
	if old:
		old.free()
	if cell == null or not cell.params.has("animate"):
		return
	var glow := CellGlow.new()
	glow.name = "CellGlow"
	glow.mode = String(cell.params["animate"])
	glow.colors = cell.colors
	model.add_child(glow)
