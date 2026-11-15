extends RefCounted
## Build-time mesh merging for the Ashfall City generator
## (tools/build_endless_city.gd): fewer surfaces, so fewer draw calls.
##
##  - merged_model(path): one ArrayMesh from every MeshInstance3D of a kit
##    model, whose plain surfaces (opaque, not glowing StandardMaterial3D that
##    differ only in colour and roughness) become one surface per texture,
##    the colour moved into the vertex colours. The kit's 10-24 surfaces per
##    model drop to 3-8; glowing, glass and shader surfaces are kept as they are.
##  - compound(parts): one ArrayMesh from primitive meshes placed by
##    transforms (detailed set dressing built from boxes and cylinders), merged
##    the same way.

## Kit model path -> merged ArrayMesh.
static var _models := {}
## Merged-material key -> the shared vertex-coloured material.
static var _shared := {}


## The kit model at `path` (a .glb scene) as one merged mesh, cached.
static func merged_model(path: String) -> ArrayMesh:
	if _models.has(path):
		return _models[path]
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var parts: Array = []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := Transform3D()
		var n: Node = mi
		while n != scene:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		parts.append([mi.mesh, xf])
	scene.free()
	var mesh := compound(parts)
	_models[path] = mesh
	return mesh


## Merges `parts` ([Mesh, Transform3D] or [Mesh, Transform3D, Material]
## overriding every surface's material) into one ArrayMesh.
static func compound(parts: Array) -> ArrayMesh:
	# Group key -> [material, arrays of every surface in the group].
	var groups := {}
	var order: Array = []
	for part in parts:
		var mesh: Mesh = part[0]
		var xf: Transform3D = part[1]
		for i in mesh.get_surface_count():
			var material: Material = part[2] if part.size() > 2 else mesh.surface_get_material(i)
			var key := _key(material)
			if not groups.has(key):
				groups[key] = [_group_material(key, material), []]
				order.append(key)
			var tint := Color.WHITE
			if _mergeable(material):
				tint = (material as BaseMaterial3D).albedo_color
			groups[key][1].append(_surface(mesh.surface_get_arrays(i), xf, tint))
	var out := ArrayMesh.new()
	for key in order:
		var arrays := _concat(groups[key][1])
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, groups[key][0])
	return out


## Plain surfaces merge by texture: opaque, unlit-free StandardMaterial3D.
static func _mergeable(material: Material) -> bool:
	var m := material as StandardMaterial3D
	return m != null and not m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not m.vertex_color_use_as_albedo


static func _key(material: Material) -> String:
	if not _mergeable(material):
		return "own|%d" % (material.get_instance_id() if material else 0)
	var m := material as StandardMaterial3D
	return "merge|%s|%s|%s|%s|%s|%d|%d" % [m.albedo_texture.resource_path if m.albedo_texture else "",
		m.normal_texture.resource_path if m.normal_enabled and m.normal_texture else "", m.uv1_scale,
		m.uv1_triplanar, m.uv1_world_triplanar, int(m.metallic > 0.3), 0]


static func _group_material(key: String, material: Material) -> Material:
	if not key.begins_with("merge|"):
		return material
	if _shared.has(key):
		return _shared[key]
	var m := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.resource_name = "CityMerged"
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_shared[key] = m
	return m


## One surface's arrays moved by `xf`, its colours multiplied by `tint`.
static func _surface(arrays: Array, xf: Transform3D, tint: Color) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nb := xf.basis.inverse().transposed()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	out_v.resize(verts.size())
	out_n.resize(verts.size())
	out_c.resize(verts.size())
	for k in verts.size():
		out_v[k] = xf * verts[k]
		out_n[k] = (nb * normals[k]).normalized() if k < normals.size() else Vector3.UP
		out_c[k] = (colors[k] * tint) if k < colors.size() else tint
	if indices.is_empty():
		indices.resize(verts.size())
		for k in verts.size():
			indices[k] = k
	# A mirroring transform flips the winding.
	if xf.basis.determinant() < 0.0:
		for k in range(0, indices.size(), 3):
			var t := indices[k + 1]
			indices[k + 1] = indices[k + 2]
			indices[k + 2] = t
	return {"v": out_v, "n": out_n, "c": out_c, "uv": uvs, "i": indices}


static func _concat(surfaces: Array) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var any_uv := false
	for s in surfaces:
		any_uv = any_uv or not (s["uv"] as PackedVector2Array).is_empty()
	for s in surfaces:
		var base := v.size()
		v.append_array(s["v"])
		n.append_array(s["n"])
		c.append_array(s["c"])
		if any_uv:
			var su: PackedVector2Array = s["uv"]
			if su.size() == (s["v"] as PackedVector3Array).size():
				uv.append_array(su)
			else:
				var pad := PackedVector2Array()
				pad.resize((s["v"] as PackedVector3Array).size())
				uv.append_array(pad)
		for k in s["i"]:
			idx.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	if any_uv:
		arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
