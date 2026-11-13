extends SceneTree
## Generator for the tutorial level "Boot Camp": the training midway behind
## Prize Pier. Rebuilds scenes/levels/boot_camp.tscn from the layout below,
## reusing the pier's props, materials, sky and ocean so it feels like the
## same place.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_boot_camp.gd
##
## Run it with a renderer (not --headless): MultiMesh instance data (string
## lights) is only stored when a real rendering server is present.
##
## Layout (metres, top view; the course runs toward -Z):
##   - Movement lane (x -4.5..4.5): balloons and the first pad at the start,
##     a sprint straight, then hurdle, crate, barrier and a low sign in a
##     fenced corridor. Each station has an arch with its name.
##   - Shooting gallery at the end of the lane: a counter at z -65 with pop-up
##     targets, zombie cut-outs and a far target (31 m) behind it.
##   - Live-fire arena east of the lane (x 9..45), behind a gate that the
##     tutorial opens: the loadout station in the middle, zombie pens on the
##     far sides and the exit portal in the far corner.
## The interactive pieces (balloons, pads, targets) are built at run time by
## scripts/onboarding/ from the Marker3D nodes under "Course".

const OUT_PATH := "res://scenes/levels/boot_camp.tscn"
const MODELS := "res://art/models/"
const DECK_THICK := 0.8
const RAIL_MODULE := 3.0
## Lane corridor half width and the stations along it (z of each obstacle).
const LANE := 4.5
const HURDLE_Z := -30.0
const CRATE_Z := -38.0
const BARRIER_Z := -45.0
const SIGN_Z := -52.5
const COUNTER_Z := -65.0
## Arena bounds and the gate between the lane and the arena (on x = 9).
const AX0 := 9.0
const AX1 := 45.0
const AZ0 := -66.0
const AZ1 := -20.0
const GATE_Z0 := -64.0
const GATE_Z1 := -58.0
const KIOSK_POS := Vector3(27.0, 0.0, -43.0)
const PORTAL_POS := Vector3(41.0, 0.0, -24.5)
const SUN_AZIMUTH_DEGREES := 24.0
const SKY_YAW_DEGREES := 180.0 - SUN_AZIMUTH_DEGREES

var level: Node3D
var geo: Node3D
var dressing: Node3D
var course: Node3D
var _materials := {}
var _boxes := {}


func _initialize() -> void:
	level = Node3D.new()
	level.name = "BootCamp"
	_build_environment()
	_build_ocean()
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dressing = Node3D.new()
	dressing.name = "Dressing"
	level.add_child(dressing)
	course = Node3D.new()
	course.name = "Course"
	level.add_child(course)

	_build_decks()
	_build_rails()
	_build_lane()
	_build_gallery()
	_build_arena()
	_build_backdrop()
	_build_string_lights()
	_build_markers()

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	level.set_script(load("res://scripts/run/level_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/onboarding/tutorial_run.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_boot_camp: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment (the pier's sunset)
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://art/textures/sky_sunset.png")
	pano.energy_multiplier = 0.92
	sky.sky_material = pano
	env.sky = sky
	env.sky_rotation = Vector3(0.0, deg_to_rad(SKY_YAW_DEGREES), 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.5, 0.84)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.6, 0.66)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var azimuth := deg_to_rad(SUN_AZIMUTH_DEGREES)
	var elevation := deg_to_rad(30.0)
	var to_sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.35, -0.4, -0.85).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(1.0, 0.62, 0.8)
	fill.light_energy = 0.34
	level.add_child(fill)


func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = plane
	ocean.position = Vector3(0, -4.2, 0)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/ocean.gdshader")
	var az := deg_to_rad(SUN_AZIMUTH_DEGREES)
	m.set_shader_parameter("sun_direction", Vector2(sin(az), -cos(az)))
	ocean.material_override = m
	level.add_child(ocean)


# ---------------------------------------------------------------------------
# Decks and rails
# ---------------------------------------------------------------------------

func _build_decks() -> void:
	var decks := Node3D.new()
	decks.name = "Decks"
	geo.add_child(decks)
	_deck(decks, "Lane", -9.0, 9.0, -66.0, 8.0)
	_deck(decks, "GalleryField", -9.0, 9.0, -99.0, -66.0)
	_deck(decks, "Arena", AX0, AX1, AZ0, AZ1)
	# Pier pylons under everything (scenery, one MultiMesh).
	var spots: Array[Vector3] = []
	for x in range(-8, 9, 8):
		for z in range(6, -99, -8):
			spots.append(Vector3(x, 0, z))
	for x in range(14, 45, 8):
		for z in range(-22, -66, -8):
			spots.append(Vector3(x, 0, z))
	var pylon := CylinderMesh.new()
	pylon.top_radius = 0.42
	pylon.bottom_radius = 0.5
	pylon.height = 7.0
	pylon.radial_segments = 10
	pylon.material = _mat("pylon", Color(0.36, 0.22, 0.2), 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pylon
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i] + Vector3(0, -DECK_THICK - 3.5, 0)))
	var pylons := MultiMeshInstance3D.new()
	pylons.name = "Pylons"
	pylons.multimesh = mm
	dressing.add_child(pylons)


func _build_rails() -> void:
	var rails := Node3D.new()
	rails.name = "Rails"
	geo.add_child(rails)
	_rail(rails, "RailStart", Vector3(-9, 0, 8), Vector3(9, 0, 8))
	_rail(rails, "RailWest", Vector3(-9, 0, 8), Vector3(-9, 0, -99))
	_rail(rails, "RailGalleryBack", Vector3(-9, 0, -99), Vector3(9, 0, -99))
	_rail(rails, "RailEastLane", Vector3(9, 0, 8), Vector3(9, 0, AZ1))
	_rail(rails, "RailEastField", Vector3(9, 0, AZ0), Vector3(9, 0, -99))
	# Between the lane and the arena: a fence with the gate opening.
	_rail(rails, "RailArenaWestA", Vector3(AX0, 0, AZ1), Vector3(AX0, 0, GATE_Z1))
	_rail(rails, "RailArenaWestB", Vector3(AX0, 0, GATE_Z0), Vector3(AX0, 0, AZ0))
	_rail(rails, "RailArenaNorth", Vector3(AX0, 0, AZ1), Vector3(AX1, 0, AZ1))
	_rail(rails, "RailArenaEast", Vector3(AX1, 0, AZ1), Vector3(AX1, 0, AZ0))
	_rail(rails, "RailArenaSouth", Vector3(AX0, 0, AZ0), Vector3(AX1, 0, AZ0))


# ---------------------------------------------------------------------------
# Movement lane
# ---------------------------------------------------------------------------

func _build_lane() -> void:
	var lane := Node3D.new()
	lane.name = "LaneProps"
	geo.add_child(lane)
	var teal := _mat("teal", Color(0.09, 0.56, 0.58), 0.55)
	var cream := _mat("cream", Color(1.0, 0.93, 0.82), 0.6)
	var pink := _mat("pink", Color(0.95, 0.3, 0.62), 0.55)
	var crate := _mat("crate", Color(0.78, 0.5, 0.3), 0.8)
	# The corridor fences, from the end of the sprint to the gallery.
	_rail(lane, "CorridorWest", Vector3(-LANE, 0, -27.0), Vector3(-LANE, 0, -58.0))
	_rail(lane, "CorridorEast", Vector3(LANE, 0, -27.0), Vector3(LANE, 0, -58.0))

	# Hurdle: a striped bar too high to step over (0.55 m), low enough to hop.
	_box(lane, "Hurdle", Vector3(LANE * 2.0, 0.55, 0.3), Vector3(0, 0.275, HURDLE_Z), pink)
	for x in [-LANE + 0.3, 0.0, LANE - 0.3]:
		_box(lane, "HurdleFoot%d" % int(x), Vector3(0.5, 0.12, 0.9), Vector3(x, 0.06, HURDLE_Z), teal)

	# Crate wall: 1.2 m, deep enough to stand on, to climb (mantle) and drop off.
	var stack := _box(lane, "CrateStack", Vector3(LANE * 2.0, 1.2, 2.4), Vector3(0, 0.6, CRATE_Z), crate)
	(stack.get_node("Mesh") as MeshInstance3D).visible = false
	for i in 3:
		var x := -LANE + 1.5 + i * 3.0
		var c := MeshInstance3D.new()
		c.name = "Crate%d" % i
		c.mesh = _box_mesh(Vector3(2.92, 1.2, 2.4), crate)
		c.position = Vector3(x, 0.6, CRATE_Z)
		lane.add_child(c)
		var band := MeshInstance3D.new()
		band.name = "CrateBand%d" % i
		band.mesh = _box_mesh(Vector3(2.96, 0.16, 2.44), teal)
		band.position = Vector3(x, 0.95, CRATE_Z)
		lane.add_child(band)

	# Vault barrier: 1 m high and thin, so it is vaulted, not stood on.
	_box(lane, "Barrier", Vector3(LANE * 2.0, 1.0, 0.25), Vector3(0, 0.5, BARRIER_Z), teal)
	_box(lane, "BarrierCap", Vector3(LANE * 2.0, 0.08, 0.32), Vector3(0, 1.02, BARRIER_Z), cream).collision_layer = 0

	# Low sign: its underside at 1.25 m, too low to walk under, room to slide.
	_box(lane, "LowSign", Vector3(LANE * 2.0, 1.6, 1.0), Vector3(0, 1.25 + 0.8, SIGN_Z), pink)
	_box(lane, "LowSignTrim", Vector3(LANE * 2.0 + 0.1, 0.12, 1.06), Vector3(0, 1.31, SIGN_Z), cream).collision_layer = 0
	for x in [-LANE + 0.2, LANE - 0.2]:
		_box(lane, "LowSignPost%d" % int(x), Vector3(0.3, 3.2, 0.3), Vector3(x, 1.6, SIGN_Z), teal)
	_label(lane, "DuckSign", "DUCK!", Vector3(0, 2.05, SIGN_Z + 0.52), 0.0, 150, Color(1.0, 0.95, 0.8))

	# Station arches with their names.
	_arch(lane, "ArchLook", Vector3(0, 0, -1.0), "BOOT CAMP")
	_arch(lane, "ArchSprint", Vector3(0, 0, -12.0), "SPRINT")
	_arch(lane, "ArchJump", Vector3(0, 0, HURDLE_Z + 2.5), "JUMP")
	_arch(lane, "ArchMantle", Vector3(0, 0, CRATE_Z + 2.8), "CLIMB")
	_arch(lane, "ArchVault", Vector3(0, 0, BARRIER_Z + 2.4), "VAULT")
	_arch(lane, "ArchGallery", Vector3(0, 0, -59.0), "SHOOTING GALLERY")

	# The midway either side of the open start and the sprint straight.
	for i in 3:
		var z := -4.0 - i * 7.5
		_prop(dressing, "booth", "BoothW%d" % i, Vector3(-7.0, 0, z), 90.0, Vector3(4.6, 3.6, 3.4))
		_collider(lane, "BoothW%dCol" % i, Vector3(3.4, 3.6, 4.7), Vector3(-7.0, 1.8, z))
		_prop(dressing, "booth", "BoothE%d" % i, Vector3(7.0, 0, z), -90.0, Vector3(4.6, 3.6, 3.4))
		_collider(lane, "BoothE%dCol" % i, Vector3(3.4, 3.6, 4.7), Vector3(7.0, 1.8, z))
	_prop(dressing, "popcorn_cart", "Popcorn", Vector3(-7.4, 0, 4.8), 90.0, Vector3(1.7, 2, 1))
	_collider(lane, "PopcornCol", Vector3(1.1, 2.0, 1.8), Vector3(-7.4, 1.0, 4.8))
	_prop(dressing, "trash_bin", "Bin0", Vector3(7.6, 0, 5.2), 0.0, Vector3(0.7, 1.1, 0.7))
	_collider(lane, "Bin0Col", Vector3(0.7, 1.1, 0.7), Vector3(7.6, 0.55, 5.2))
	_prop(dressing, "planter", "Planter0", Vector3(-6.8, 0, -27.5), 90.0, Vector3(3.2, 0.9, 1.5))
	_prop(dressing, "planter", "Planter1", Vector3(6.8, 0, -27.5), 90.0, Vector3(3.2, 0.9, 1.5))
	for x in [-6.8, 6.8]:
		_prop(dressing, "palm", "Palm%d" % int(x), Vector3(x, 0.6, -27.5), x * 13.0, Vector3(0.5, 7, 0.5))
		_collider(lane, "Planter%dCol" % int(x), Vector3(1.5, 1.0, 3.2), Vector3(x, 0.5, -27.5))
	for k in 4:
		var z := 2.0 - k * 16.0
		_prop(dressing, "lamp_post", "LampW%d" % k, Vector3(-8.9, 0, z), 0.0, Vector3(0.3, 5.5, 0.3))
		_prop(dressing, "lamp_post", "LampE%d" % k, Vector3(8.9, 0, z), 180.0, Vector3(0.3, 5.5, 0.3))
	# Painted sprint lane.
	var paint := _mat("deck_paint", Color(0.95, 0.3, 0.62), 0.6)
	for x in [-1.6, 1.6]:
		var stripe := MeshInstance3D.new()
		stripe.name = "SprintStripe%d" % int(x * 10)
		stripe.mesh = _box_mesh(Vector3(0.22, 0.01, 18.0), paint)
		stripe.position = Vector3(x, 0.012, -17.0)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(stripe)


## An arch over the lane: two posts and a signboard with `text`.
func _arch(parent: Node3D, arch_name: String, at: Vector3, text: String) -> void:
	var teal := _mat("teal", Color(0.09, 0.56, 0.58), 0.55)
	var board := _mat("arch_board", Color(0.11, 0.07, 0.22), 0.6)
	var gold := _mat("arch_gold", Color(1.0, 0.76, 0.3), 0.4, Color(1.0, 0.7, 0.25), 0.6)
	for x in [-LANE - 0.15, LANE + 0.15]:
		var post := MeshInstance3D.new()
		post.name = "%sPost%d" % [arch_name, int(x)]
		post.mesh = _box_mesh(Vector3(0.28, 5.2, 0.28), teal)
		post.position = at + Vector3(x, 2.6, 0)
		parent.add_child(post)
	var sign := MeshInstance3D.new()
	sign.name = arch_name + "Board"
	sign.mesh = _box_mesh(Vector3(LANE * 1.6, 1.15, 0.18), board)
	sign.position = at + Vector3(0, 4.7, 0)
	parent.add_child(sign)
	var trim := MeshInstance3D.new()
	trim.name = arch_name + "Trim"
	trim.mesh = _box_mesh(Vector3(LANE * 1.6 + 0.16, 1.31, 0.12), gold)
	trim.position = at + Vector3(0, 4.7, -0.04)
	parent.add_child(trim)
	_label(parent, arch_name + "Text", text, at + Vector3(0, 4.7, 0.1), 0.0, 160 if text.length() < 12 else 120, Color(1.0, 0.95, 0.82))


# ---------------------------------------------------------------------------
# Shooting gallery
# ---------------------------------------------------------------------------

func _build_gallery() -> void:
	var g := Node3D.new()
	g.name = "Gallery"
	geo.add_child(g)
	var teal := _mat("teal", Color(0.09, 0.56, 0.58), 0.55)
	var cream := _mat("cream", Color(1.0, 0.93, 0.82), 0.6)
	var pink := _mat("pink", Color(0.95, 0.3, 0.62), 0.55)
	var board := _mat("arch_board", Color(0.11, 0.07, 0.22), 0.6)
	# The counter: waist high, the player cannot climb over it.
	var counter := _box(g, "Counter", Vector3(18.0, 1.05, 0.9), Vector3(0, 0.525, COUNTER_Z), pink)
	_no_perch(counter, Vector3(18.0, 1.05, 0.9))
	_box(g, "CounterTop", Vector3(18.1, 0.08, 1.0), Vector3(0, 1.09, COUNTER_Z), cream).collision_layer = 0
	# Awning posts and the striped roof over the firing line.
	for x in [-8.6, 8.6]:
		_box(g, "AwningPost%d" % int(x), Vector3(0.3, 4.4, 0.3), Vector3(x, 2.2, COUNTER_Z), teal)
	var stripes := 9
	for i in stripes:
		var strip := MeshInstance3D.new()
		strip.name = "Awning%d" % i
		strip.mesh = _box_mesh(Vector3(18.4 / stripes, 0.12, 3.2), pink if i % 2 == 0 else cream)
		strip.position = Vector3(-9.2 + 18.4 / stripes * (i + 0.5), 4.45, COUNTER_Z + 1.2)
		strip.rotation.x = deg_to_rad(-8.0)
		g.add_child(strip)
	# Target rails (low kick boards the pop-ups stand behind).
	for row in [[-74.0, 12.0], [-81.0, 14.0]]:
		_box(g, "KickBoard%d" % int(-row[0]), Vector3(row[1], 0.45, 0.25), Vector3(0, 0.225, row[0] + 0.6), teal)
	# The back wall: everything that misses lands on painted plywood.
	var back := _box(g, "BackWall", Vector3(18.0, 7.0, 0.5), Vector3(0, 3.5, -97.5), board)
	back.get_node("Mesh").set("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for i in 5:
		var ring := MeshInstance3D.new()
		ring.name = "WallStar%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.9 - i * 0.0
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.05
		cyl.radial_segments = 24
		cyl.material = _mat("wall_dot_%d" % (i % 3), [Color(1.0, 0.76, 0.3), Color(0.35, 0.9, 1.0), Color(1.0, 0.45, 0.75)][i % 3], 0.5)
		ring.mesh = cyl
		ring.rotation.x = deg_to_rad(90.0)
		ring.position = Vector3(-7.0 + i * 3.5, 5.6 - (i % 2) * 1.1, -97.2)
		g.add_child(ring)
	_label(g, "GalleryTitle", "SHOOT THE TARGETS", Vector3(0, 6.2, -97.15), 0.0, 220, Color(1.0, 0.95, 0.82))
	# Side walls of the gallery field.
	for x in [-8.75, 8.75]:
		_box(g, "FieldWall%d" % int(x), Vector3(0.5, 3.0, 31.0), Vector3(x, 1.5, -81.5), board)


# ---------------------------------------------------------------------------
# Live-fire arena
# ---------------------------------------------------------------------------

func _build_arena() -> void:
	var a := Node3D.new()
	a.name = "ArenaProps"
	geo.add_child(a)
	var kiosk: Node3D = (load("res://scenes/props/kiosk.tscn") as PackedScene).instantiate()
	kiosk.name = "Kiosk"
	a.add_child(kiosk)
	kiosk.position = KIOSK_POS
	var portal: Node3D = (load("res://scenes/props/portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	a.add_child(portal)
	portal.position = PORTAL_POS
	portal.rotation.y = deg_to_rad(180.0 + 45.0)

	# The gate between the gallery and the arena: closed until live fire.
	var gate := _box(course, "ArenaGate", Vector3(0.4, 2.4, GATE_Z1 - GATE_Z0), Vector3(AX0, 1.2, (GATE_Z0 + GATE_Z1) * 0.5), _mat("gate", Color(0.95, 0.3, 0.62), 0.5))
	_player_wall(gate, Vector3(0.4, 4.0, GATE_Z1 - GATE_Z0))
	_label(gate, "GateText", "LIVE FIRE", Vector3(-0.22, 0.2, 0), -90.0, 110, Color(1.0, 0.95, 0.82))
	_prop(dressing, "gate_ride", "GateArch", Vector3(AX0, 0, (GATE_Z0 + GATE_Z1) * 0.5), 90.0, Vector3(8, 5, 1))

	# Zombie pens: a ride gate on each far side (the zombies walk out of them).
	_prop(dressing, "gate_ride", "PenNorth", Vector3(27.0, 0, AZ1), 180.0, Vector3(8, 5, 1))
	_prop(dressing, "gate_ride", "PenEast", Vector3(AX1, 0, -50.0), -90.0, Vector3(8, 5, 1))
	_prop(dressing, "gate_ride", "PenSouth", Vector3(30.0, 0, AZ0), 0.0, Vector3(8, 5, 1))

	# Cover: crates and planters, clear of the station and the pens.
	var crate := _mat("crate", Color(0.78, 0.5, 0.3), 0.8)
	var cover := [
		[Vector3(18.0, 0, -32.0), 20.0], [Vector3(36.0, 0, -34.0), -15.0],
		[Vector3(18.5, 0, -55.0), -25.0], [Vector3(36.5, 0, -56.0), 10.0],
	]
	var i := 0
	for c in cover:
		var body := _box(a, "Cover%d" % i, Vector3(2.4, 1.2, 1.2), c[0] + Vector3(0, 0.6, 0), crate)
		body.rotation.y = deg_to_rad(c[1])
		_no_perch(body, Vector3(2.4, 1.2, 1.2))
		i += 1
	_prop(a, "bench", "ArenaBench", Vector3(44.0, 0, -40.0), -90.0, Vector3(0.8, 0.9, 2.2))
	_collider(a, "ArenaBenchCol", Vector3(0.9, 0.9, 2.2), Vector3(44.0, 0.45, -40.0))
	for k in 4:
		var spot: Vector3 = [Vector3(AX0 + 0.1, 0, -30.0), Vector3(AX1 - 0.1, 0, -28.0), Vector3(AX1 - 0.1, 0, -60.0), Vector3(20.0, 0, AZ0 + 0.1)][k]
		_prop(dressing, "lamp_post", "ArenaLamp%d" % k, spot, [0.0, 180.0, 180.0, -90.0][k], Vector3(0.3, 5.5, 0.3))

	# Exit lights from the station to the portal.
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var strip := BoxMesh.new()
	strip.size = Vector3(1.3, 0.04, 0.24)
	var light_script: Script = load("res://scripts/props/exit_light.gd")
	var from := KIOSK_POS + Vector3(3.2, 0, 3.0)
	var to := PORTAL_POS + Vector3(-1.6, 0, -1.6)
	var steps := int(from.distance_to(to) / 2.4)
	for k in steps + 1:
		var mi := MeshInstance3D.new()
		mi.name = "ExitLight%02d" % k
		mi.mesh = strip
		mi.position = from.lerp(to, float(k) / steps) + Vector3(0, 0.03, 0)
		mi.rotation.y = atan2(-(to - from).z, (to - from).x) + PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_script(light_script)
		mi.set("order", k)
		lights.add_child(mi)


# ---------------------------------------------------------------------------
# Skyline (no collision): the pier itself across the water
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	level.add_child(backdrop)
	var wheel := _prop(backdrop, "ferris_wheel", "FerrisWheel", Vector3(-40.0, 0.0, -60.0), 70.0, Vector3(26, 30, 4))
	wheel.scale = Vector3.ONE * 1.1
	wheel.set_script(load("res://scripts/props/ferris_wheel.gd"))
	var platform := MeshInstance3D.new()
	platform.name = "WheelPlatform"
	platform.mesh = _box_mesh(Vector3(12, DECK_THICK, 28), _deck_material())
	platform.position = Vector3(-40.0, -DECK_THICK * 0.5, -60.0)
	backdrop.add_child(platform)
	_prop(backdrop, "coaster", "Coaster", Vector3(10.0, -4.0, -135.0), -6.0, Vector3(60, 14, 10))
	_prop(backdrop, "lighthouse", "Lighthouse", Vector3(80.0, -4.0, -95.0), 0.0, Vector3(6, 20, 6))
	_prop(backdrop, "arcade", "ArcadeHall", Vector3(-16.0, 0, -20.0), 90.0, Vector3(14, 6, 8))
	var hall_floor := MeshInstance3D.new()
	hall_floor.name = "ArcadeFloor"
	hall_floor.mesh = _box_mesh(Vector3(10, DECK_THICK, 16), _deck_material())
	hall_floor.position = Vector3(-15.0, -DECK_THICK * 0.5, -20.0)
	backdrop.add_child(hall_floor)
	for k in 5:
		_prop(backdrop, "buoy", "Buoy%d" % k, Vector3(22.0 + k * 9.0, -4.2, 6.0 - k * 3.0), k * 40.0, Vector3(1, 2, 1))
	_prop(backdrop, "sailboat", "Sailboat", Vector3(70.0, -4.2, -20.0), 120.0, Vector3(4, 8, 10))


# ---------------------------------------------------------------------------
# String lights
# ---------------------------------------------------------------------------

func _build_string_lights() -> void:
	var lights := Node3D.new()
	lights.name = "StringLights"
	level.add_child(lights)
	var top := 5.0
	var spans := []
	for k in 3:
		var z := 2.0 - k * 16.0
		spans.append([Vector3(-8.9, top, z), Vector3(8.9, top, z - 16.0)])
		spans.append([Vector3(8.9, top, z), Vector3(-8.9, top, z - 16.0)])
	spans.append([Vector3(AX0 + 0.1, top, -30.0), KIOSK_POS + Vector3(-1.4, 6.7, 1.0)])
	spans.append([Vector3(AX1 - 0.1, top, -28.0), KIOSK_POS + Vector3(1.4, 6.7, 1.0)])
	spans.append([Vector3(AX1 - 0.1, top, -60.0), KIOSK_POS + Vector3(1.4, 6.7, -1.0)])
	spans.append([Vector3(20.0, top, AZ0 + 0.1), KIOSK_POS + Vector3(-1.4, 6.7, -1.0)])
	var i := 0
	for span in spans:
		_garland(lights, "Garland%02d" % i, span[0], span[1])
		i += 1


func _garland(parent: Node3D, garland_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var sag := clampf(length * 0.06, 0.35, 1.1)
	var bulbs := maxi(4, int(length / 1.1))
	var points: Array[Vector3] = []
	for k in bulbs + 1:
		var t := float(k) / bulbs
		points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var holder := Node3D.new()
	holder.name = garland_name
	parent.add_child(holder)
	var wire := MultiMeshInstance3D.new()
	wire.name = "Wire"
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	wm.mesh = _box_mesh(Vector3(1, 1, 1), _mat("wire", Color(0.12, 0.1, 0.18), 0.6))
	wm.instance_count = points.size() - 1
	for k in points.size() - 1:
		var p0 := points[k]
		var p1 := points[k + 1]
		var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		wm.set_instance_transform(k, Transform3D(Basis(basis.x * 0.025, basis.y * 0.025, basis.z * p0.distance_to(p1)), (p0 + p1) * 0.5))
	wire.multimesh = wm
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(wire)
	var colors := [Color(1.0, 0.76, 0.3), Color(1.0, 0.45, 0.75), Color(0.35, 0.95, 1.0), Color(1.0, 0.76, 0.3)]
	var bulb_mm := MultiMesh.new()
	bulb_mm.transform_format = MultiMesh.TRANSFORM_3D
	bulb_mm.use_colors = true
	bulb_mm.mesh = _bulb_mesh()
	bulb_mm.instance_count = points.size() - 2
	for k in range(1, points.size() - 1):
		bulb_mm.set_instance_transform(k - 1, Transform3D(Basis(), points[k] + Vector3.DOWN * 0.08))
		bulb_mm.set_instance_color(k - 1, colors[k % colors.size()])
	var bulbs_node := MultiMeshInstance3D.new()
	bulbs_node.name = "Bulbs"
	bulbs_node.multimesh = bulb_mm
	bulbs_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bulbs_node)


var _bulb_mesh_cache: Mesh


func _bulb_mesh() -> Mesh:
	if _bulb_mesh_cache:
		return _bulb_mesh_cache
	var m := StandardMaterial3D.new()
	m.resource_name = "GarlandBulb"
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 2.2
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = m
	_bulb_mesh_cache = sphere
	return sphere


# ---------------------------------------------------------------------------
# Markers: where the tutorial puts its balloons, pads, targets and zombies
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var marks := {
		"Balloon0": Vector3(-5.2, 3.4, 1.0), "Balloon1": Vector3(5.4, 3.0, 0.0), "Balloon2": Vector3(0.0, 6.4, -9.0),
		"PadMove": Vector3(0, 0, -6.0), "PadSprint": Vector3(0, 0, -25.5), "PadJump": Vector3(0, 0, HURDLE_Z - 3.0),
		"PadMantle": Vector3(0, 1.2, CRATE_Z), "PadVault": Vector3(0, 0, BARRIER_Z - 3.2), "PadSlide": Vector3(0, 0, SIGN_Z - 3.6),
		"FiringLine": Vector3(0, 0, COUNTER_Z + 1.2),
		"Target0": Vector3(-4.5, 0.45, -74.0), "Target1": Vector3(-2.2, 0.45, -74.0), "Target2": Vector3(0.0, 0.45, -74.0),
		"Target3": Vector3(2.2, 0.45, -74.0), "Target4": Vector3(4.5, 0.45, -74.0),
		"FarTarget": Vector3(0.0, 0.0, -94.5),
		"Cutout0": Vector3(-4.0, 0.45, -81.0), "Cutout1": Vector3(0.0, 0.45, -81.0), "Cutout2": Vector3(4.0, 0.45, -81.0),
		"ArenaEntry": Vector3(13.0, 0, (GATE_Z0 + GATE_Z1) * 0.5),
		"PenNorth": Vector3(27.0, 0.1, AZ1 + 2.0), "PenEast": Vector3(AX1 - 2.0, 0.1, -50.0), "PenSouth": Vector3(30.0, 0.1, AZ0 + 2.0),
		"Kiosk": KIOSK_POS,
	}
	for key in marks:
		var m := Marker3D.new()
		m.name = key
		m.position = marks[key]
		course.add_child(m)
	# The run director's own spawn points (it moves stuck zombies back to these).
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	for key in ["PenNorth", "PenEast", "PenSouth"]:
		var m := Marker3D.new()
		m.name = "Spawn" + key
		m.position = marks[key]
		m.add_to_group("enemy_spawn", true)
		spawns.add_child(m)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _bake_navigation(region: NavigationRegion3D) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_height = 1.75
	mesh.agent_radius = 0.5
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 8.0
	mesh.filter_baking_aabb = AABB(Vector3(-20, -1.0, -110), Vector3(80, 1.6, 130))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	print("build_boot_camp: navmesh polygons = %d" % mesh.get_polygon_count())
	region.navigation_mesh = mesh


# ---------------------------------------------------------------------------
# Helpers (as in build_prize_pier.gd)
# ---------------------------------------------------------------------------

func _label(parent: Node3D, label_name: String, text: String, pos: Vector3, yaw_degrees: float, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.text = text
	l.font = load("res://art/fonts/LilitaOne-Regular.ttf")
	l.font_size = font_size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_modulate = Color(0.07, 0.04, 0.16)
	l.outline_size = 24
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(l)
	return l


func _deck(parent: Node3D, deck_name: String, x0: float, x1: float, z0: float, z1: float) -> void:
	var size := Vector3(x1 - x0, DECK_THICK, z1 - z0)
	_box(parent, deck_name, size, Vector3((x0 + x1) * 0.5, -DECK_THICK * 0.5, (z0 + z1) * 0.5), _deck_material())


func _deck_material() -> StandardMaterial3D:
	if _materials.has("deck"):
		return _materials["deck"]
	var m := StandardMaterial3D.new()
	m.resource_name = "DeckWood"
	m.albedo_texture = load("res://art/textures/deck_planks.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = true
	m.normal_texture = load("res://art/textures/deck_planks_normal.png")
	m.normal_scale = 0.8
	m.roughness = 0.68
	m.metallic_specular = 0.3
	_materials["deck"] = m
	return m


## A rail run: repeated rail modules, one collision box and a player-only wall.
func _rail(parent: Node3D, rail_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var body := StaticBody3D.new()
	body.name = rail_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.25, 0.3)
	shape.shape = box
	shape.position.y = 0.625
	body.add_child(shape)
	var wall := StaticBody3D.new()
	wall.name = "PlayerWall"
	wall.collision_layer = 16
	wall.collision_mask = 0
	body.add_child(wall)
	var wall_shape := CollisionShape3D.new()
	wall_shape.name = "CollisionShape3D"
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(length, 3.4, 0.3)
	wall_shape.shape = wall_box
	wall_shape.position.y = 1.7
	wall.add_child(wall_shape)
	var count := maxi(1, int(round(length / RAIL_MODULE)))
	var step := length / count
	var module: PackedScene = load(MODELS + "rail.glb")
	for i in count:
		var m: Node3D = module.instantiate()
		m.name = "Module%02d" % i
		m.position = Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)
		m.scale = Vector3(step / RAIL_MODULE, 1, 1)
		body.add_child(m)


func _mat(key: String, color: Color, roughness := 0.7, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var key := "%s|%s" % [size, material.get_instance_id()]
	if _boxes.has(key):
		return _boxes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_boxes[key] = mesh
	return mesh


func _player_wall(body: StaticBody3D, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = "PlayerWall"
	wall.collision_layer = 16
	wall.collision_mask = 0
	body.add_child(wall)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5 - 1.2
	wall.add_child(shape)


## Player-only box over a collider, so the player can neither mantle onto it nor land on it.
func _no_perch(body: StaticBody3D, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = "PlayerWall"
	wall.collision_layer = 16
	wall.collision_mask = 0
	body.add_child(wall)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 3.0, size.z)
	shape.shape = box
	shape.position.y = size.y * 0.5 + 1.5
	wall.add_child(shape)


func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, material)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _collider(parent: Node3D, collider_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = collider_name
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(placeholder_size, _mat("placeholder", Color(0.75, 0.72, 0.8), 0.8))
		mi.name = "Placeholder"
		mi.position.y = placeholder_size.y * 0.5
		node = Node3D.new()
		node.add_child(mi)
	node.name = prop_name
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_degrees)
	return node


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
