extends RefCounted
## The Neon Market's street life, called by tools/build_endless_city.gd:
##
##   preload("res://tools/city/city_market.gd").stalls(self, parent)   # in _build_market
##   preload("res://tools/city/city_market.gd").new(self).build()      # end of _build_market_glow
##
## A believable abandoned night market: a row of distinct shops on each side
## of the street (every sign different, each on a backing board bolted to
## the wall with its cable run to a junction box; shutters half down on
## some, lit interiors on a few), three vertical blade signs on three
## buildings, back-to-back stalls down the middle (each selling something
## else, its name on the awning), strings of paper lanterns hung from wall
## hooks between the bulb cables, and dropped goods by the stalls.
##
## Everything is batched by kind into a few MultiMeshes (per-instance
## colour); it never draws from the generator's random numbers.

## Street faces of the two rows of blocks (the Market rect's long sides).
const FACE_N := -8.0
const FACE_S := 8.0
## Stall islands (x centres): two stalls back to back at each end of one.
const ISLANDS := [40.0, 52.0, 72.0, 82.0]
## How far a stall's origin sits off the island's centre line: its back on
## the line, touching the other stall's (no notch between the colliders to
## snag on), its front toward the lane.
const STALL_Z := 1.09
## The stall's solid part in its own frame (counter, posts, the crates
## stacked on its +X side, the awning; not the scorch on the paving in
## front, which the kit's bounds include): centre and size.
const STALL_BODY := [Vector3(0.2815, 1.415, 0.18), Vector3(3.963, 2.83, 2.54)]
## The kit stall reaches further on +X (its crate stack) than on -X: a stall
## turned to face the other lane moves this far east so both line up.
const STALL_SKEW := 0.563
## Island ends with a solid stack of crates across them (the ones facing the
## entrance and the open middle; the crossings between islands stay clear):
## [island x, side].
const CRATE_ENDS := [[40.0, -1.0], [52.0, 1.0], [72.0, -1.0], [82.0, 1.0]]
## Half the island's length (the stall pairs' outer ends).
const ISLAND_HALF := 3.96
## Where the lantern strings cross: only where both sides have a wall to
## hook them to (the side alleys and the tower alley have none).
const LANTERN_X := [46.0, 53.5, 61.5, 75.0, 88.5]

## [x, side (-1 north row, 1 south row), bay width, name, colour, state]
## state: lit (lit interior), half (shutter half down over a dim shop),
## shut (shutter down), kit (lit, its sign from the kit: the noodle bar).
const SHOPS := [
	[37.0, -1.0, 4.4, "ARCADE", Color(1.0, 0.25, 0.75), "half"],
	[47.6, -1.0, 5.0, "LUCKY PAWN", Color(0.25, 0.9, 1.0), "shut"],
	[53.6, -1.0, 4.4, "PHARMACY", Color(0.35, 1.0, 0.45), "lit"],
	[59.2, -1.0, 4.0, "TEA HOUSE", Color(1.0, 0.72, 0.25), "lit"],
	[74.0, -1.0, 5.0, "KARAOKE", Color(0.62, 0.4, 1.0), "half"],
	[80.2, -1.0, 4.6, "PHONE REPAIR", Color(0.3, 0.55, 1.0), "lit"],
	[37.6, 1.0, 4.6, "LAUNDROMAT", Color(0.75, 0.95, 1.0), "lit"],
	[43.8, 1.0, 4.6, "DUMPLINGS", Color(1.0, 0.5, 0.15), "half"],
	[50.0, 1.0, 4.6, "BOOKS & COMICS", Color(1.0, 0.92, 0.3), "shut"],
	[61.6, 1.0, 4.4, "VIDEO RENTAL", Color(1.0, 0.22, 0.25), "half"],
	[70.6, 1.0, 4.8, "", Color(1.0, 0.75, 0.2), "kit"],
	[84.6, 1.0, 5.0, "GOLDEN DRAGON", Color(1.0, 0.8, 0.35), "lit"],
]
## Vertical blade signs, one per building: [x, side, centre height, word, colour].
const BLADES := [
	[44.7, -1.0, 6.4, "MAHJONG", Color(0.3, 1.0, 0.75)],
	[58.7, 1.0, 6.2, "CINEMA", Color(1.0, 0.3, 0.45)],
]
## What each stall sells, in stall_spots() order: [name, goods, colours].
const WARES := [
	["FRUIT", "balls", [Color(1.0, 0.5, 0.08), Color(0.85, 0.1, 0.1), Color(0.5, 0.75, 0.15)]],
	["FRESH FISH", "fish", [Color(0.7, 0.78, 0.85), Color(0.95, 0.5, 0.45)]],
	["LANTERNS", "lanterns", [Color(1.0, 0.2, 0.15), Color(1.0, 0.65, 0.15)]],
	["PHONE CASES", "cases", [Color(1.0, 0.3, 0.7), Color(0.3, 0.9, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 0.4, 1.0)]],
	["FLOWERS", "flowers", [Color(1.0, 0.35, 0.6), Color(1.0, 0.95, 0.9), Color(0.95, 0.75, 0.15)]],
	["STEAMED BAO", "steamers", [Color(0.78, 0.6, 0.35), Color(0.95, 0.92, 0.85)]],
	["TOYS", "cases", [Color(1.0, 0.2, 0.2), Color(0.2, 0.6, 1.0), Color(1.0, 0.85, 0.1), Color(0.3, 0.85, 0.3)]],
	["SPICES", "bowls", [Color(0.85, 0.3, 0.1), Color(0.95, 0.75, 0.15), Color(0.5, 0.25, 0.12)]],
	["SKEWERS", "grill", [Color(0.55, 0.3, 0.15), Color(1.0, 0.45, 0.1)]],
	["MANGOES", "balls", [Color(1.0, 0.75, 0.15), Color(0.95, 0.55, 0.1), Color(0.6, 0.75, 0.2)]],
	["CABLES", "cases", [Color(0.12, 0.12, 0.14), Color(0.9, 0.9, 0.92), Color(0.2, 0.5, 1.0)]],
	["ORCHIDS", "flowers", [Color(0.75, 0.4, 1.0), Color(1.0, 0.95, 0.95), Color(1.0, 0.5, 0.8)]],
	["CRAB", "fish", [Color(0.95, 0.35, 0.2), Color(0.8, 0.85, 0.9)]],
	["PAPER CRAFT", "lanterns", [Color(0.95, 0.85, 0.35), Color(1.0, 0.3, 0.5)]],
	["TEA LEAVES", "bowls", [Color(0.3, 0.45, 0.15), Color(0.55, 0.35, 0.15), Color(0.2, 0.3, 0.1)]],
	["SWEETS", "balls", [Color(1.0, 0.6, 0.8), Color(0.6, 0.9, 1.0), Color(1.0, 1.0, 0.6)]],
]

const WOOD := Color(0.5, 0.33, 0.18)
const BOARD := Color(0.07, 0.06, 0.08)
const STEEL := Color(0.42, 0.43, 0.46)
const WARM := Color(1.0, 0.72, 0.42)

## The generator (tools/build_endless_city.gd); untyped (a SceneTree script).
var b
## Kind -> [Mesh, Array[Transform3D], Array[Color]].
var _batches := {}


func _init(builder: Variant) -> void:
	b = builder


## Every stall's origin and yaw: [Vector3, yaw degrees], in WARES order.
static func stall_spots() -> Array:
	var spots := []
	for x: float in ISLANDS:
		for dx: float in [-1.98, 1.98]:
			var at: float = x + dx - STALL_SKEW * 0.5
			spots.append([Vector3(at + STALL_SKEW, 0, -STALL_Z), 180.0])
			spots.append([Vector3(at, 0, STALL_Z), 0.0])
	return spots


## The stalls themselves (solid kit pieces) and a player cap over each
## island; called from _build_market in place of the old islands.
static func stalls(builder: Variant, parent: Node3D) -> void:
	var i := 0
	for spot in stall_spots():
		var yaw: float = spot[1]
		builder._kit(parent, "city_market_stall", "Stall%d" % i, spot[0], yaw, Vector3(3.6, 2.8, 2.4))
		var body: StaticBody3D = builder._collider(parent, "Stall%dCollision" % i, STALL_BODY[1], spot[0])
		body.position = spot[0] + Basis(Vector3.UP, deg_to_rad(yaw)) * STALL_BODY[0]
		body.rotation.y = deg_to_rad(yaw)
		body.set_meta("top", STALL_BODY[1].y)
		i += 1
	for k in ISLANDS.size():
		# Over the whole island, awning rims included (nobody stands on a stall).
		builder._player_block(parent, "Stall%dCap" % k, Vector3(8.6, 3.0, 6.6), Vector3(ISLANDS[k], 4.5, 0.0))


func build() -> void:
	for shop in SHOPS:
		_shop(shop)
	for blade in BLADES:
		_blade(blade)
	var spots := stall_spots()
	for i in spots.size():
		_wares(spots[i][0], spots[i][1], WARES[i], i)
	_island_crates()
	_lantern_strings()
	_flush()


# --- shops ---------------------------------------------------------------------

## One shopfront: its sign board on the wall over the door, the board's neon
## rim and lettering, brackets, the cable to a junction box; the window lit,
## dim or shuttered.
func _shop(shop: Array) -> void:
	var x: float = shop[0]
	var side: float = shop[1]
	var width: float = shop[2]
	var text: String = shop[3]
	var color: Color = shop[4]
	var state: String = shop[5]
	var n := Vector3(0, 0, -side)
	var face := Vector3(x, 0, FACE_S if side > 0.0 else FACE_N)
	var yaw := 180.0 if side > 0.0 else 0.0
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var bay := width - 0.6
	if state != "kit":
		var w := minf(width - 0.4, maxf(bay * 0.8, text.length() * 0.27 + 0.7))
		var at := face + n * 0.2 + Vector3(0, 3.55, 0)
		_add("board", Transform3D(basis.scaled_local(Vector3(w, 0.8, 0.16)), at), BOARD)
		_add("glow", Transform3D(basis.scaled_local(Vector3(w + 0.12, 0.92, 0.06)), at - n * 0.06), color)
		for s in [-0.4, 0.4]:
			_add("board", Transform3D(basis.scaled_local(Vector3(0.06, 0.06, 0.24)), face + basis * Vector3(s * w, 3.98, 0.12)), STEEL)
		var l: Label3D = b._label(b.dressing, "Shop%s" % text.replace(" ", "").replace("&", ""), text, at + n * 0.09, yaw, 80, color.lightened(0.25))
		l.outline_modulate = color.darkened(0.7)
		var box := face + basis * Vector3(w * 0.5 + 0.35, 3.05, 0.07)
		_add("board", Transform3D(basis.scaled_local(Vector3(0.3, 0.4, 0.14)), box), Color(0.3, 0.31, 0.3))
		b._cable(face + basis * Vector3(w * 0.5 - 0.05, 3.18, 0.14), box + Vector3(0, 0.15, 0) + n * 0.06, 0.08, 4)
		if text == "PHARMACY":
			var cross := face + basis * Vector3(-w * 0.5 - 0.45, 3.55, 0.15)
			_add("glow", Transform3D(basis.scaled_local(Vector3(0.6, 0.2, 0.08)), cross), color)
			_add("glow", Transform3D(basis.scaled_local(Vector3(0.2, 0.6, 0.08)), cross), color)
		b._wall_glow(at + n * 0.1, n, w * 0.55, color, 0.35)
		b._reflectors.append([Vector3(x, 3.5, face.z) + n * 0.3, color, w * 0.18, 0.55])
	# The window bay under the sign.
	var lit := state == "lit" or state == "kit"
	var glass := WARM.lerp(color, 0.35).darkened(0.3) if lit else color.darkened(0.82)
	_add("window" if lit else "board", Transform3D(basis.scaled_local(Vector3(bay, 2.6, 0.05)), face + n * 0.04 + Vector3(0, 1.45, 0)), glass)
	if lit:
		# The shop inside against the light: shelves, a counter, a lamp.
		for sy in [1.75, 2.3]:
			_add("board", Transform3D(basis.scaled_local(Vector3(bay * 0.9, 0.05, 0.03)), face + n * 0.075 + Vector3(0, sy, 0)), BOARD)
		_add("board", Transform3D(basis.scaled_local(Vector3(bay * 0.55, 0.95, 0.03)), face + basis * Vector3(-bay * 0.18, 0.5, 0.075)), BOARD.lightened(0.05))
		_add("lantern", Transform3D(Basis().scaled(Vector3(0.22, 0.16, 0.22)), face + basis * Vector3(bay * 0.25, 2.55, 0.12)), WARM)
	for k in 3:
		var mx := (k - 1) * bay / 3.0
		_add("board", Transform3D(basis.scaled_local(Vector3(0.08, 2.6, 0.08)), face + basis * Vector3(mx, 1.45, 0.07)), BOARD)
	_add("board", Transform3D(basis.scaled_local(Vector3(bay + 0.2, 0.12, 0.12)), face + basis * Vector3(0, 2.8, 0.08)), BOARD)
	if state == "half" or state == "shut":
		var bottom := 1.5 if state == "half" else 0.05
		var h := 2.75 - bottom
		_add("board", Transform3D(basis.scaled_local(Vector3(bay, h, 0.06)), face + n * 0.12 + Vector3(0, bottom + h * 0.5, 0)), STEEL)
		var ribs := int(h / 0.3)
		for k in ribs:
			_add("board", Transform3D(basis.scaled_local(Vector3(bay, 0.04, 0.04)), face + n * 0.16 + Vector3(0, bottom + 0.15 + k * 0.3, 0)), STEEL.lightened(0.2))
	if lit:
		b._pool(Vector3(x, 0, face.z) + n * 1.8, bay * 0.6, WARM.lerp(color, 0.3), false, 0.45)
		b._reflectors.append([Vector3(x, 1.4, face.z) + n * 0.2, WARM.lerp(color, 0.3), bay * 0.2, 0.5])
		if state == "lit":
			b._omni(b.fx, "Shop%dLight" % int(x * 10.0 * side), Vector3(x, 2.4, face.z) + n * 1.6, WARM.lerp(color, 0.35), 0.9, 6.0)
	elif state == "half":
		b._pool(Vector3(x, 0, face.z) + n * 0.9, bay * 0.35, color, false, 0.25)


## A vertical blade sign standing out from the wall on two brackets: a
## board with a neon rim, the word down both faces, a cable to a box.
func _blade(blade: Array) -> void:
	var x: float = blade[0]
	var side: float = blade[1]
	var y: float = blade[2]
	var word: String = blade[3]
	var color: Color = blade[4]
	var n := Vector3(0, 0, -side)
	var face := Vector3(x, 0, FACE_S if side > 0.0 else FACE_N)
	var h := word.length() * 0.5 + 0.5
	var at := face + n * 0.95 + Vector3(0, y, 0)
	_add("board", Transform3D(Basis().scaled(Vector3(0.2, h, 0.95)), at), BOARD)
	_add("glow", Transform3D(Basis().scaled(Vector3(0.1, h + 0.14, 1.09)), at), color)
	for dy in [h * 0.5 - 0.2, -h * 0.5 + 0.2]:
		_add("board", Transform3D(Basis().scaled(Vector3(0.07, 0.07, 0.5)), face + n * 0.25 + Vector3(0, y + dy, 0)), STEEL)
	var letters := "\n".join(word.split(""))
	for s in [-1.0, 1.0]:
		var l: Label3D = b._label(b.dressing, "Blade%s%s" % [word, "W" if s < 0.0 else "E"], letters, at + Vector3(s * 0.11, 0, 0), 90.0 * s, 72, color.lightened(0.3))
		l.outline_modulate = color.darkened(0.7)
		l.line_spacing = -10.0
	var box := face + n * 0.07 + Vector3(0, y - h * 0.5 - 0.6, 0)
	_add("board", Transform3D(Basis().scaled(Vector3(0.3, 0.4, 0.14)), box), Color(0.3, 0.31, 0.3))
	b._cable(at - n * 0.45 + Vector3(0, -h * 0.5, 0), box + Vector3(0, 0.2, 0) + n * 0.07, 0.15, 4)
	b._wall_glow(face + Vector3(0, y, 0) + n * 0.1, n, h * 0.45, color, 0.3)
	b._pool(Vector3(x, 0, face.z) + n * 1.5, 2.2, color, false, 0.3)
	b._reflectors.append([at, color, 0.35, 0.6])


# --- stalls --------------------------------------------------------------------

## A stall's goods on the back half of its counter (the kit's fruit crates
## are on the front half), its name painted on the awning, and a few things
## dropped in front of it.
func _wares(origin: Vector3, yaw: float, ware: Array, index: int) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var colors: Array = ware[2]
	var top := 0.99
	var kind: String = ware[1]
	for k in 6:
		var lx := -1.25 + k * 0.5
		var c: Color = colors[k % colors.size()]
		var p := origin + basis * Vector3(lx, top, 0.0)
		match kind:
			"balls":
				for j in 3:
					_add("ball", Transform3D(Basis().scaled(Vector3.ONE * 0.13), p + basis * Vector3(-0.13 + j * 0.13, 0.07, 0.04 * (j % 2))), c)
			"fish":
				_add("board", Transform3D(basis.scaled_local(Vector3(0.42, 0.04, 0.3)), p + Vector3(0, 0.02, 0)), Color(0.42, 0.5, 0.58))
				for j in 2:
					_add("ball", Transform3D(basis * Basis(Vector3.UP, 0.2 * j).scaled(Vector3(0.36, 0.08, 0.1)), p + basis * Vector3(0, 0.09, -0.08 + j * 0.16)), c)
			"lanterns":
				_add("lantern", Transform3D(Basis().scaled(Vector3(0.22, 0.28, 0.22)), p + Vector3(0, 0.14, 0)), c)
				_add("lantern", Transform3D(Basis().scaled(Vector3(0.26, 0.32, 0.26)), origin + basis * Vector3(lx, 2.05, 1.25)), colors[(k + 1) % colors.size()])
			"cases":
				for j in 3:
					_add("board", Transform3D(basis * Basis(Vector3.RIGHT, -0.3).scaled(Vector3(0.1, 0.17, 0.02)), p + basis * Vector3(-0.14 + j * 0.14, 0.09, 0.0)), colors[(k + j) % colors.size()])
			"flowers":
				_add("ball", Transform3D(Basis().scaled(Vector3(0.16, 0.22, 0.16)), p + Vector3(0, 0.1, 0)), Color(0.25, 0.4, 0.2))
				for j in 3:
					_add("ball", Transform3D(Basis().scaled(Vector3.ONE * 0.1), p + basis * Vector3(-0.06 + j * 0.06, 0.26, 0.03 * j)), c)
			"steamers":
				for j in 2 + k % 2:
					_add("drum", Transform3D(Basis().scaled(Vector3(0.36, 0.12, 0.36)), p + Vector3(0, 0.07 + j * 0.13, 0)), colors[0])
			"bowls":
				_add("drum", Transform3D(Basis().scaled(Vector3(0.34, 0.1, 0.34)), p + Vector3(0, 0.05, 0)), Color(0.9, 0.88, 0.82))
				_add("ball", Transform3D(Basis().scaled(Vector3(0.28, 0.1, 0.28)), p + Vector3(0, 0.1, 0)), c)
			"grill":
				if k == 0:
					_add("board", Transform3D(basis.scaled_local(Vector3(2.6, 0.12, 0.4)), origin + basis * Vector3(0, top + 0.06, 0.0)), Color(0.12, 0.11, 0.1))
					_add("glow", Transform3D(basis.scaled_local(Vector3(2.4, 0.03, 0.3)), origin + basis * Vector3(0, top + 0.13, 0.0)), Color(1.0, 0.35, 0.05))
				for j in 3:
					_add("board", Transform3D(basis.scaled_local(Vector3(0.04, 0.03, 0.34)), p + basis * Vector3(-0.12 + j * 0.12, 0.17, 0)), c)
	# A chalk price board over the kit's own counter board, its prices
	# chalked in lines of different lengths.
	var chalk := [Color(0.1, 0.16, 0.12), Color(0.12, 0.1, 0.1), Color(0.35, 0.12, 0.1), Color(0.1, 0.12, 0.2)][index % 4] as Color
	_add("board", Transform3D(basis.scaled_local(Vector3(1.26, 0.56, 0.03)), origin + basis * Vector3(0, 0.55, 0.88)), chalk)
	for j in 3:
		var line := 0.5 + 0.25 * ((index + j * 2) % 3)
		_add("board", Transform3D(basis.scaled_local(Vector3(line, 0.035, 0.01)), origin + basis * Vector3(-0.5 + line * 0.5, 0.7 - j * 0.14, 0.9)), Color(0.92, 0.9, 0.82))
	var name_at := origin + basis * Vector3(0, 2.58, 1.42)
	var l: Label3D = b._label(b.dressing, "StallSign%d" % index, ware[0], name_at, yaw, 46, Color(1.0, 0.95, 0.85))
	l.outline_modulate = Color(0.1, 0.06, 0.04)
	# Dropped goods in front of every third stall: something rolled off.
	if index % 3 == 1:
		var c0: Color = colors[0]
		for j in 4:
			var q := origin + basis * Vector3(-0.8 + j * 0.45, 0.05, 1.9 + 0.25 * (j % 2))
			if kind == "cases":
				_add("board", Transform3D(Basis(Vector3.UP, j * 0.9).scaled(Vector3(0.1, 0.02, 0.17)), q - Vector3(0, 0.04, 0)), colors[j % colors.size()])
			else:
				_add("ball", Transform3D(Basis().scaled(Vector3.ONE * 0.12), q), c0)


## Crates stacked across some island ends (solid, flush with the stalls).
func _island_crates() -> void:
	var solid := Node3D.new()
	solid.name = "MarketCrates"
	b.geo.add_child(solid)
	for end in CRATE_ENDS:
		var s: float = end[1]
		var base := Vector3(end[0] + s * (ISLAND_HALF + 0.42), 0, 0.0)
		b._collider(solid, "Crates%d%s" % [int(end[0]), "W" if s < 0.0 else "E"], Vector3(0.9, 0.9, 5.0), base + Vector3(-s * 0.05, 0.45, 0))
		for k in 7:
			var z := -2.1 + k * 0.7
			var tall := k % 3 != 1
			var tint := WOOD.darkened(0.12 * (k % 3))
			_add("crate", Transform3D(Basis(Vector3.UP, 0.12 * (k % 3) - 0.1).scaled(Vector3(0.8, 0.45, 0.62)), base + Vector3(0, 0.225, z)), tint)
			if tall:
				_add("crate", Transform3D(Basis(Vector3.UP, 0.2 - 0.1 * (k % 2)).scaled(Vector3(0.7, 0.45, 0.6)), base + Vector3(0, 0.675, z)), tint.lightened(0.1))


## Strings of paper lanterns across the street, between the bulb cables,
## each tied to a hook bracket on both facades.
func _lantern_strings() -> void:
	var colors := [Color(1.0, 0.18, 0.12), Color(1.0, 0.55, 0.12), Color(1.0, 0.85, 0.35)]
	var k := 0
	for x: float in LANTERN_X:
		var a := Vector3(x, 6.6, FACE_N + 0.1)
		var c := Vector3(x, 6.6, FACE_S - 0.1)
		b._cable(a, c, 1.0, 12)
		for e in [a, c]:
			_add("board", Transform3D(Basis().scaled(Vector3(0.12, 0.2, 0.22)), Vector3(e.x, e.y, signf(e.z) * 7.98)), STEEL.darkened(0.3))
		for i in range(1, 8):
			var t := i / 8.0
			var p := a.lerp(c, t) - Vector3(0, 1.0 * sin(PI * t), 0)
			_add("lantern", Transform3D(Basis().scaled(Vector3(0.36, 0.46, 0.36)), p + Vector3(0, -0.3, 0)), colors[(i + k) % colors.size()])
		k += 1


# --- batching ------------------------------------------------------------------

func _add(kind: String, xf: Transform3D, color: Color) -> void:
	if not _batches.has(kind):
		var xforms: Array[Transform3D] = []
		var cols: Array[Color] = []
		_batches[kind] = [_mesh(kind), xforms, cols]
	_batches[kind][1].append(xf)
	_batches[kind][2].append(color)


func _mesh(kind: String) -> Mesh:
	match kind:
		"glow":
			var g := BoxMesh.new()
			g.material = b._tinted("market_glow", 0.4, 1.6)
			return g
		"window":
			var w := BoxMesh.new()
			w.material = b._tinted("market_window", 0.5, 0.8)
			return w
		"lantern":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 10
			s.rings = 5
			s.material = b._tinted("market_lantern", 0.5, 1.4)
			return s
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 4
			s.material = b._tinted("market_goods", 0.55)
			return s
		"drum":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			c.material = b._tinted("market_goods", 0.55)
			return c
		"crate":
			var k := BoxMesh.new()
			k.material = b._tinted("market_crate", 0.85, 0.0, "city_grime", 1.0)
			return k
	var box := BoxMesh.new()
	box.material = b._tinted("market_board", 0.7)
	return box


func _flush() -> void:
	for kind in _batches:
		var entry: Array = _batches[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = entry[0]
		var xforms: Array[Transform3D] = entry[1]
		var cols: Array[Color] = entry[2]
		mm.instance_count = xforms.size()
		for k in xforms.size():
			mm.set_instance_transform(k, xforms[k])
			mm.set_instance_color(k, cols[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Market_" + String(kind)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind == "crate" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.dressing.add_child(mmi)
