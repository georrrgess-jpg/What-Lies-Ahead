extends SceneTree
## Generator for the Endless grey-box test map (a dev tool, not a level of the
## game): scenes/levels/endless_testbed.tscn. Five walled districts laid out
## like Ashfall City's (the square in the middle, Precinct 9 to the north with
## the Broadcast Tower behind it, the Metro to the east, the Market to the
## west), joined by EndlessGate nodes of all three open styles, with every
## marker of the scene contract in docs/ENDLESS.md: player spawn, loadout
## station, entrances per district, district areas, traps and supply drops,
## and a navmesh baked with the gates shut (one island per district).
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_endless_testbed.gd
##
## Play it in place of the city with the dev driver:
##   -- --autoplay=endless --scene=res://scenes/levels/endless_testbed.tscn

const OUT_PATH := "res://scenes/levels/endless_testbed.tscn"
const WALL_H := 5.0
const WALL_T := 0.8
const GATE_W := 6.0

## District id -> [centre, size (x, z), floor colour].
const DISTRICTS := {
	&"ashfall_square": [Vector3(0, 0, 0), Vector2(44, 44), Color(0.36, 0.3, 0.28)],
	&"precinct": [Vector3(0, 0, -40), Vector2(36, 36), Color(0.22, 0.3, 0.45)],
	&"metro": [Vector3(42, 0, 0), Vector2(40, 30), Color(0.22, 0.4, 0.3)],
	&"market": [Vector3(-42, 0, 0), Vector2(40, 30), Color(0.45, 0.22, 0.38)],
	&"tower": [Vector3(0, 0, -78), Vector2(40, 40), Color(0.45, 0.4, 0.2)],
}
## Gates: [district it opens, position, yaw (deg), open style].
const GATES := [
	[&"precinct", Vector3(0, 0, -22), 0.0, &"shutter"],
	[&"metro", Vector3(22, 0, 0), 90.0, &"slide"],
	[&"market", Vector3(-22, 0, 0), 90.0, &"topple"],
	[&"tower", Vector3(0, 0, -58), 0.0, &"shutter"],
]

var level: Node3D
var geo: Node3D
var _mats := {}


func _initialize() -> void:
	level = Node3D.new()
	level.name = "EndlessTestbed"
	_environment()
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	for id in DISTRICTS:
		_district(id)
	for g in GATES:
		_gate(g[0], g[1], g[2], g[3])
	_cover()
	_station()
	_markers()
	get_root().add_child(level)
	await process_frame
	_bake(nav)
	get_root().remove_child(level)
	level.set_script(load("res://scripts/run/level_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)
	_own(level, level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_endless_testbed: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.16, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.55, 0.5)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.25, 0.15)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.7, 0.5)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38, -35, 0)
	level.add_child(sun)


## A district: its floor, its walls (with gaps where gates or other districts
## meet it), its area box.
func _district(id: StringName) -> void:
	var c: Vector3 = DISTRICTS[id][0]
	var size: Vector2 = DISTRICTS[id][1]
	var root := Node3D.new()
	root.name = String(id).to_pascal_case()
	geo.add_child(root)
	_box(root, "Floor", Vector3(size.x, 0.4, size.y), c + Vector3(0, -0.2, 0), _mat(DISTRICTS[id][2]))
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var wall := _mat(Color(0.55, 0.52, 0.5))
	# North/south and east/west walls, split around a gate gap where one sits.
	for side in [Vector3(0, 0, -hz), Vector3(0, 0, hz), Vector3(-hx, 0, 0), Vector3(hx, 0, 0)]:
		var along_x: bool = side.x == 0.0
		var length: float = size.x if along_x else size.y
		var at: Vector3 = c + side
		if _gate_at(at):
			var half := (length - GATE_W) * 0.5
			var shift := (GATE_W + half) * 0.5
			for s in [-1.0, 1.0]:
				var off := Vector3(s * shift, 0, 0) if along_x else Vector3(0, 0, s * shift)
				_box(root, "Wall", Vector3(half, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, half), at + off + Vector3(0, WALL_H * 0.5, 0), wall)
		else:
			_box(root, "Wall", Vector3(length, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, length), at + Vector3(0, WALL_H * 0.5, 0), wall)
	var area := Area3D.new()
	area.name = "Area_%s" % id
	area.collision_layer = 8
	area.collision_mask = 2
	area.position = c + Vector3(0, 2, 0)
	area.set_meta(&"district", id)
	area.add_to_group("endless_district_area", true)
	level.add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x - 1.0, 5, size.y - 1.0)
	shape.shape = box
	area.add_child(shape)


func _gate_at(at: Vector3) -> bool:
	for g in GATES:
		if (g[1] as Vector3).distance_to(Vector3(at.x, 0, at.z)) < 1.5:
			return true
	return false


## An EndlessGate per the contract: Frame, Door, Blocker, Zone and NavLinks.
func _gate(district: StringName, at: Vector3, yaw: float, style: StringName) -> void:
	var gate := Node3D.new()
	gate.name = "Gate_%s" % district
	gate.position = at
	gate.rotation_degrees.y = yaw
	gate.set_script(load("res://scripts/endless/endless_gate.gd"))
	gate.set("district", district)
	gate.set("open_style", style)
	geo.add_child(gate)
	var frame := Node3D.new()
	frame.name = "Frame"
	gate.add_child(frame)
	var steel := _mat(Color(0.25, 0.25, 0.28))
	for s in [-1.0, 1.0]:
		_visual(frame, "Post", Vector3(0.6, WALL_H + 0.6, 1.2), Vector3(s * (GATE_W * 0.5 + 0.3), (WALL_H + 0.6) * 0.5, 0), steel)
	_visual(frame, "Lintel", Vector3(GATE_W + 1.2, 0.8, 1.2), Vector3(0, WALL_H + 0.2, 0), steel)
	var door := Node3D.new()
	door.name = "Door"
	gate.add_child(door)
	var accent: Color = DISTRICTS[district][2].lightened(0.35)
	_visual(door, "Panel", Vector3(GATE_W, WALL_H - 0.2, 0.25), Vector3(0, (WALL_H - 0.2) * 0.5, 0), _mat(accent))
	_visual(door, "Stripe", Vector3(GATE_W, 0.4, 0.3), Vector3(0, 1.0, 0), _mat(Color(1.0, 0.8, 0.15)))
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	gate.add_child(blocker)
	var bs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(GATE_W, WALL_H, 0.6)
	bs.shape = bb
	bs.position = Vector3(0, WALL_H * 0.5, 0)
	blocker.add_child(bs)
	var zone := Area3D.new()
	zone.name = "Zone"
	zone.collision_layer = 8
	zone.collision_mask = 2
	gate.add_child(zone)
	var zs := CollisionShape3D.new()
	var zb := BoxShape3D.new()
	zb.size = Vector3(GATE_W + 1.0, 3.0, 6.0)
	zs.shape = zb
	zs.position = Vector3(0, 1.5, 0)
	zone.add_child(zs)
	for i in 2:
		var link := NavigationLink3D.new()
		link.name = "NavLink" if i == 0 else "NavLink%d" % (i + 1)
		var x := -1.5 if i == 0 else 1.5
		link.start_position = Vector3(x, 0, 2.0)
		link.end_position = Vector3(x, 0, -2.0)
		link.bidirectional = true
		link.enabled = false
		gate.add_child(link)


## Cover in the square and the districts: crates and low walls for loops.
func _cover() -> void:
	var crate := _mat(Color(0.6, 0.42, 0.25))
	var cover := Node3D.new()
	cover.name = "Cover"
	geo.add_child(cover)
	var spots := [Vector3(-9, 0, -8), Vector3(9, 0, -8), Vector3(-9, 0, 9), Vector3(10, 0, 8),
		Vector3(-6, 0, -42), Vector3(7, 0, -36), Vector3(40, 0, -6), Vector3(46, 0, 6),
		Vector3(-40, 0, 6), Vector3(-46, 0, -6), Vector3(-8, 0, -80), Vector3(9, 0, -74)]
	for i in spots.size():
		_box(cover, "Crate%02d" % i, Vector3(3.0, 1.4, 1.6), spots[i] + Vector3(0, 0.7, 0), crate)


func _station() -> void:
	var kiosk: Node3D = (load("res://scenes/props/kiosk.tscn") as PackedScene).instantiate()
	kiosk.name = "Station"
	geo.add_child(kiosk)
	kiosk.position = Vector3(0, 0, 2)


func _markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0, 0.1, 11)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	# Corners of every district, away from its gates.
	for id in DISTRICTS:
		var c: Vector3 = DISTRICTS[id][0]
		var size: Vector2 = DISTRICTS[id][1]
		var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
		var used := 0
		for k in corners:
			var p := c + Vector3(k.x * (size.x * 0.5 - 2.5), 0.1, k.y * (size.y * 0.5 - 2.5))
			if id != &"ashfall_square" and used >= 3:
				break
			var m := Marker3D.new()
			m.name = "Spawn%s%d" % [String(id).to_pascal_case(), used + 1]
			m.position = p
			m.set_meta(&"district", id)
			m.add_to_group("enemy_spawn", true)
			spawns.add_child(m)
			used += 1
	var features := Node3D.new()
	features.name = "Features"
	level.add_child(features)
	var list := [
		["TrapSquare", &"trap_fire", &"ashfall_square", Vector3(-12, 0, -13)],
		["TrapPrecinct", &"trap_fire", &"precinct", Vector3(0, 0, -44)],
		["TrapMetro", &"trap_shock", &"metro", Vector3(42, 0, 0)],
		["TrapMarket", &"trap_fire", &"market", Vector3(-42, 0, 0)],
		["TrapTower", &"trap_shock", &"tower", Vector3(0, 0, -82)],
		["DropSquareA", &"supply_drop", &"ashfall_square", Vector3(-14, 0, 12)],
		["DropSquareB", &"supply_drop", &"ashfall_square", Vector3(14, 0, -12)],
		["DropPrecinct", &"supply_drop", &"precinct", Vector3(-10, 0, -34)],
		["DropMarket", &"supply_drop", &"market", Vector3(-36, 0, 8)],
	]
	for f in list:
		var m := Marker3D.new()
		m.name = f[0]
		m.position = f[3]
		m.set_meta(&"kind", f[1])
		m.set_meta(&"district", f[2])
		m.add_to_group("endless_feature", true)
		features.add_child(m)


## Bakes with every gate shut; keeps every island but crumbs.
func _bake(region: NavigationRegion3D) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_height = 1.75
	mesh.agent_radius = 0.75
	mesh.agent_max_climb = 0.25
	mesh.region_min_size = 14.0
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	region.navigation_mesh = mesh
	print("build_endless_testbed: navmesh polygons = %d" % mesh.get_polygon_count())


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	parent.add_child(body, true)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	_visual(body, "Mesh", size, Vector3.ZERO, material)
	return body


func _visual(parent: Node3D, mesh_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi, true)
	return mi


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		# An instanced scene (the station) keeps its own children.
		if child.scene_file_path == "":
			_own(child, root)
