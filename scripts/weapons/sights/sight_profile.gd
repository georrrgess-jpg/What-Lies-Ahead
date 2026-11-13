class_name SightProfile
extends RefCounted
## The top outline of a weapon model under a sight line: for each slice along
## the weapon's length, the highest surface in a narrow strip either side of
## the line. Sights use it to work out, for any model, how high the eye and an
## optic must sit so that nothing on the weapon covers the point of aim.
##
## Model space: -Z points to the muzzle, +Y is up, the eye sits at a larger z.
## Profiles are measured once per weapon model and kept for the session.

const BUCKETS := 128
## Sample planes either side of the sight line (model units).
const PLANES: Array[float] = [-0.022, -0.011, 0.0, 0.011, 0.022]
const EMPTY := -1.0e9

## z of the front edge of the first slice (the muzzle end) and the slice length.
var z_start := 0.0
var z_step := 0.01
## Highest surface per slice (EMPTY where the strip is clear).
var top := PackedFloat32Array()

static var _cache := {}


## The outline of `model` around the vertical plane x = `x0`. `skip` lists
## nodes to leave out (built-in sights that an optic replaces). `key` names
## the model and what was skipped, for the cache.
static func of(model: Node3D, key: String, x0: float, skip: Array[Node]) -> SightProfile:
	var full_key := "%s|%.3f" % [key, x0]
	if not _cache.has(full_key):
		var profile := SightProfile.new()
		profile._measure(model, x0, skip)
		_cache[full_key] = profile
	return _cache[full_key]


func _measure(model: Node3D, x0: float, skip: Array[Node]) -> void:
	var lo := x0 + PLANES[0]
	var hi := x0 + PLANES[PLANES.size() - 1]
	var parts: Array = []
	var z_lo := INF
	var z_hi := -INF
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or _left_out(mi, model, skip):
			continue
		var xf := WeaponCosmetics.to_model(model, mi)
		var box := xf * mi.mesh.get_aabb()
		if box.end.x < lo or box.position.x > hi:
			continue
		z_lo = minf(z_lo, box.position.z)
		z_hi = maxf(z_hi, box.end.z)
		parts.append([xf, mi.mesh.get_faces()])
	top.resize(BUCKETS)
	top.fill(EMPTY)
	if parts.is_empty():
		return
	z_start = z_lo
	z_step = maxf(1e-4, (z_hi - z_lo) / BUCKETS)
	for part in parts:
		_add_faces(part[0], part[1], x0, lo, hi)


## Hologram copies, decals, charms and anything in `skip` are not part of the outline.
static func _left_out(mi: MeshInstance3D, model: Node3D, skip: Array[Node]) -> bool:
	var n: Node = mi
	while n and n != model:
		var node_name := String(n.name)
		if skip.has(n) or node_name.ends_with("Holo") or node_name.begins_with("Decal") or node_name == "WeaponCharm":
			return true
		n = n.get_parent()
	return false


func _add_faces(xf: Transform3D, faces: PackedVector3Array, x0: float, lo: float, hi: float) -> void:
	for i in range(0, faces.size() - 2, 3):
		var a := xf * faces[i]
		var b := xf * faces[i + 1]
		var c := xf * faces[i + 2]
		var min_x := minf(a.x, minf(b.x, c.x))
		var max_x := maxf(a.x, maxf(b.x, c.x))
		if max_x < lo or min_x > hi:
			continue
		for offset in PLANES:
			var xp := x0 + offset
			if xp >= min_x and xp <= max_x:
				_add_cut(a, b, c, xp)


## The triangle's cross-section in the plane x = xp is a segment: add it.
func _add_cut(a: Vector3, b: Vector3, c: Vector3, xp: float) -> void:
	var near := Vector2(INF, 0.0)    # x = z, y = height
	var far := Vector2(-INF, 0.0)
	for edge in [[a, b], [b, c], [c, a]]:
		var u: Vector3 = edge[0]
		var v: Vector3 = edge[1]
		if (u.x - xp) * (v.x - xp) > 0.0 or is_equal_approx(u.x, v.x):
			continue
		var hit := u.lerp(v, (xp - u.x) / (v.x - u.x))
		if hit.z < near.x:
			near = Vector2(hit.z, hit.y)
		if hit.z > far.x:
			far = Vector2(hit.z, hit.y)
	if near.x > far.x:
		return
	var first := clampi(int((near.x - z_start) / z_step), 0, BUCKETS - 1)
	var last := clampi(int((far.x - z_start) / z_step), 0, BUCKETS - 1)
	var span := far.x - near.x
	for bucket in range(first, last + 1):
		var z := clampf(z_start + (bucket + 0.5) * z_step, near.x, far.x)
		var y := maxf(near.y, far.y) if span < 1e-6 else lerpf(near.y, far.y, (z - near.x) / span)
		if y > top[bucket]:
			top[bucket] = y


func _bucket(z: float) -> int:
	return clampi(int((z - z_start) / z_step), 0, BUCKETS - 1)


func _centre(bucket: int) -> float:
	return z_start + (bucket + 0.5) * z_step


## The lowest height at which an eye at `eye_z` sees over everything in front
## of it, keeping the line `slope` (tangent of an angle) clear above every
## surface. Anything closer than `near` to the eye is not drawn and is ignored.
func needed_height(eye_z: float, slope: float, near: float) -> float:
	var need := EMPTY
	for bucket in BUCKETS:
		var y := top[bucket]
		var dist := eye_z - _centre(bucket)
		if y > EMPTY and dist >= near:
			need = maxf(need, y + slope * dist)
	return need


## Highest and lowest outline between two z values: Vector2(lowest, highest).
## Both are EMPTY when the strip is clear there.
func range_between(z_a: float, z_b: float) -> Vector2:
	var low := INF
	var high := EMPTY
	for bucket in range(_bucket(minf(z_a, z_b)), _bucket(maxf(z_a, z_b)) + 1):
		var y := top[bucket]
		if y > EMPTY:
			low = minf(low, y)
			high = maxf(high, y)
	return Vector2(EMPTY if high <= EMPTY else low, high)


## An eye at height `eye_y` looking down by up to `drop` per unit of distance
## must not sit over (or in) the weapon, or the camera would cut through it.
## Returns the smallest z at or behind `eye_z` where the part of the weapon
## `near` in front of the eye is below that view.
func clear_eye_z(eye_z: float, eye_y: float, drop: float, near: float, limit: float) -> float:
	var floor_y := eye_y - drop * near
	var bucket := _bucket(eye_z - near)
	if eye_z - near < z_start or eye_z - near > z_start + z_step * BUCKETS:
		return eye_z
	var z := eye_z
	while bucket < BUCKETS and top[bucket] > floor_y and z < eye_z + limit:
		bucket += 1
		z = _centre(bucket) + near
	return z


## How many of `rays` (unit directions from `origin`, model space) are blocked
## by the meshes under `node`.
static func rays_blocked(model: Node3D, node: Node, origin: Vector3, rays: Array[Vector3]) -> int:
	var blocked := 0
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for ray in rays:
		if _ray_hits(model, meshes, origin, ray):
			blocked += 1
	return blocked


static func _ray_hits(model: Node3D, meshes: Array[Node], origin: Vector3, ray: Vector3) -> bool:
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := WeaponCosmetics.to_model(model, mi)
		var faces := mi.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			if Geometry3D.ray_intersects_triangle(origin, ray, xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]) != null:
				return true
	return false
