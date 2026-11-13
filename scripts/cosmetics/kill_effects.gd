class_name KillEffects
extends RefCounted
## The "kill_effect" cosmetics: what a zombie pops into on the killing blow.
## Fx.kill_effect() calls play() with the equipped item. An item names its
## effect in params.effect (see EFFECTS) and may override the colours; each
## effect also plays its own small sound layer ("cos_kill_<effect>").

const EFFECTS := ["confetti", "pixel", "neon_ring", "bubbles", "snow", "starburst", "coins", "firework", "hearts",
	"balloon", "disco", "jackpot", "voxel", "ghost", "snow_globe", "black_hole", "tickets", "pinata"]

const DEFAULT_COLORS := {
	"pixel": [Color(0.3, 1.0, 0.45), Color(0.25, 0.85, 1.0), Color(1.0, 0.3, 0.75), Color(1.0, 0.9, 0.2)],
	"neon_ring": [Color(1.0, 0.25, 0.7), Color(0.2, 0.95, 1.0)],
	"bubbles": [Color(0.55, 0.9, 1.0), Color(1.0, 0.6, 0.9), Color(0.75, 1.0, 0.8)],
	"snow": [Color.WHITE, Color(0.7, 0.9, 1.0), Color(0.55, 0.8, 1.0)],
	"starburst": [Color(1.0, 0.85, 0.25), Color.WHITE, Color(1.0, 0.55, 0.2)],
	"coins": [Color(1.0, 0.78, 0.25), Color(1.0, 0.86, 0.45)],
	"firework": [Color(1.0, 0.3, 0.45), Color(0.4, 0.8, 1.0), Color(1.0, 0.9, 0.3), Color(0.7, 1.0, 0.4)],
	"hearts": [Color(1.0, 0.3, 0.55), Color(1.0, 0.55, 0.75), Color(0.95, 0.15, 0.35)],
	"balloon": [Color(1.0, 0.45, 0.75), Color(1.0, 0.85, 0.3), Color(0.35, 0.85, 1.0), Color(0.6, 1.0, 0.45)],
	"disco": [Color(1.0, 0.35, 0.8), Color(0.3, 0.9, 1.0), Color(1.0, 0.9, 0.35), Color(0.65, 0.45, 1.0)],
	"jackpot": [Color(1.0, 0.8, 0.25), Color(1.0, 0.95, 0.75)],
	"voxel": [Color(0.25, 1.0, 0.9), Color(1.0, 0.3, 0.85), Color(0.6, 0.95, 1.0)],
	"ghost": [Color(0.92, 0.9, 1.0), Color(0.75, 0.7, 1.0)],
	"snow_globe": [Color.WHITE, Color(0.75, 0.92, 1.0)],
	"black_hole": [Color(0.7, 0.35, 1.0), Color(0.3, 0.85, 1.0), Color(1.0, 0.85, 1.0)],
	"tickets": [Color(1.0, 0.42, 0.3), Color(1.0, 0.75, 0.25), Color(1.0, 0.4, 0.65), Color(0.3, 0.85, 0.8)],
	"pinata": [Color(1.0, 0.3, 0.6), Color(0.55, 1.0, 0.3), Color(1.0, 0.6, 0.15), Color(0.2, 0.85, 1.0), Color(1.0, 0.9, 0.25)],
}


static func effect_of(item: CosmeticItem) -> String:
	return String(item.params.get("effect", "confetti")) if item else "confetti"


static func colors_for(item: CosmeticItem, effect: String) -> Array:
	if item and not item.colors.is_empty():
		return Array(item.colors)
	return DEFAULT_COLORS.get(effect, [Color.WHITE])


## Plays `item`'s kill effect at `at` (null = the default confetti pop).
static func play(parent: Node, at: Vector3, item: CosmeticItem, with_sound := true) -> void:
	var effect := effect_of(item)
	var cols := colors_for(item, effect)
	match effect:
		"pixel": _pixel(parent, at, cols)
		"neon_ring": _neon_ring(parent, at, cols)
		"bubbles": _bubbles(parent, at, cols)
		"snow": _snow(parent, at, cols)
		"starburst": _starburst(parent, at, cols)
		"coins": _coins(parent, at, cols)
		"firework": _firework(parent, at, cols)
		"hearts": _hearts(parent, at, cols)
		"balloon": _balloon(parent, at, cols)
		"disco": _disco(parent, at, cols)
		"jackpot": _jackpot(parent, at, cols)
		"voxel": _voxel(parent, at, cols)
		"ghost": _ghost(parent, at, cols)
		"snow_globe": _snow_globe(parent, at, cols)
		"black_hole": _black_hole(parent, at, cols)
		"tickets": _tickets(parent, at, cols)
		"pinata": _pinata(parent, at, cols)
		_:
			Fx.kill_burst(parent, at)
			return
	if with_sound:
		Sfx.play_at(StringName("cos_kill_" + effect), at, -4.0, randf_range(0.95, 1.06))


static func _pixel(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.cube(), cols, {"count": 42, "speed": Vector2(2.5, 6.5), "life": Vector2(0.45, 0.85),
		"size": Vector2(0.1, 0.14), "gravity": Vector3(0, -7.0, 0), "drag": 2.6, "quantize": 0.1, "grow": 0.0})
	FxSwarm.spawn(parent, at, FxShapes.cube(), [Color.WHITE, cols[0]], {"count": 10, "speed": Vector2(0.4, 1.2), "life": Vector2(0.15, 0.3),
		"size": Vector2(0.18, 0.24), "gravity": Vector3.ZERO, "quantize": 0.1, "grow": 0.0})
	_flash(parent, at, FxShapes.cube(), cols[0].lerp(Color.WHITE, 0.4), 0.5, 1.4, 0.14)


static func _neon_ring(parent: Node, at: Vector3, cols: Array) -> void:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var facing := (cam.global_position - at).normalized() if cam else Vector3.BACK
	_ring(parent, at, facing, cols[0], 0.0)
	_ring(parent, at, facing, cols[1 % cols.size()], 0.08)
	_ring(parent, at, Vector3.UP, cols[1 % cols.size()], 0.03)
	FxSwarm.spawn(parent, at, FxShapes.cube(), cols + [Color.WHITE], {"count": 22, "shape": "ring", "speed": Vector2(7.0, 10.0),
		"life": Vector2(0.22, 0.38), "size": Vector2(0.09, 0.12), "stretch": Vector3(0.25, 0.25, 2.2), "align": true, "drag": 3.5,
		"gravity": Vector3.ZERO})
	_flash(parent, at, FxShapes.ball(), cols[0], 0.3, 1.0, 0.12)


static func _bubbles(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.bubble(), cols, {"count": 16, "shape": "up", "spread": 75.0, "speed": Vector2(0.8, 2.4),
		"life": Vector2(0.8, 1.5), "size": Vector2(0.14, 0.32), "gravity": Vector3(0, 1.4, 0), "drag": 2.2, "wobble": 0.7,
		"pop": true, "grow": 0.18, "jitter": 0.25, "spin": 0.0})
	FxSwarm.spawn(parent, at, FxShapes.ball(), [Color.WHITE] + cols, {"count": 14, "speed": Vector2(2.0, 4.0), "life": Vector2(0.25, 0.45),
		"size": Vector2(0.03, 0.05), "gravity": Vector3(0, -5.0, 0), "drag": 2.0})


static func _snow(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.snowflake(), cols, {"count": 28, "speed": Vector2(1.4, 4.0), "life": Vector2(1.1, 1.7),
		"size": Vector2(0.2, 0.34), "gravity": Vector3(0, -0.7, 0), "drag": 2.6, "spin": 3.0, "wobble": 0.4, "grow": 0.1})
	_ring(parent, at + Vector3.DOWN * 0.3, Vector3.UP, Color(0.7, 0.92, 1.0), 0.0)
	FxSwarm.spawn(parent, at, FxShapes.cube(), [Color.WHITE, Color(0.75, 0.95, 1.0)], {"count": 18, "speed": Vector2(1.0, 3.0),
		"life": Vector2(0.4, 0.9), "size": Vector2(0.03, 0.05), "gravity": Vector3(0, -1.0, 0), "drag": 2.0, "blink": 7.0})
	_flash(parent, at, FxShapes.ball(), Color(0.85, 0.95, 1.0), 0.4, 1.5, 0.22)


static func _starburst(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.star(), cols, {"count": 16, "speed": Vector2(6.0, 10.0), "life": Vector2(0.4, 0.7),
		"size": Vector2(0.16, 0.26), "drag": 3.6, "gravity": Vector3(0, -2.0, 0), "spin": 7.0})
	FxSwarm.spawn(parent, at, FxShapes.cube(), [Color.WHITE, cols[0]], {"count": 12, "speed": Vector2(11.0, 14.0), "life": Vector2(0.12, 0.2),
		"size": Vector2(0.07, 0.09), "stretch": Vector3(0.3, 0.3, 4.0), "align": true, "drag": 4.0, "gravity": Vector3.ZERO})
	_flash(parent, at, FxShapes.quad(), cols[0], 0.4, 3.2, 0.3, FxShapes.star_flash_material(cols[0]))


static func _coins(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.coin(), cols, {"count": 16, "shape": "up", "spread": 38.0, "speed": Vector2(4.5, 7.0),
		"life": Vector2(1.1, 1.5), "size": Vector2(0.14, 0.18), "gravity": Vector3(0, -14.0, 0), "drag": 0.4, "spin": 16.0,
		"spin_axis": Vector3.RIGHT, "bounce": -1.0, "jitter": 0.1, "grow": 0.05})
	FxSwarm.spawn(parent, at, FxShapes.cube(), [Color.WHITE, cols[0]], {"count": 14, "speed": Vector2(1.0, 3.0), "life": Vector2(0.5, 0.8),
		"size": Vector2(0.04, 0.06), "gravity": Vector3(0, -1.5, 0), "blink": 8.0})
	_flash(parent, at, FxShapes.ball(), cols[0], 0.35, 1.2, 0.14)


static func _firework(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.ball(), [Color(1.0, 0.85, 0.5), Color.WHITE], {"count": 16, "shape": "up", "spread": 4.0,
		"speed": Vector2(6.5, 7.0), "life": Vector2(0.18, 0.26), "size": Vector2(0.08, 0.13), "drag": 0.5, "gravity": Vector3.ZERO,
		"stagger": 0.12})
	_flash(parent, at, FxShapes.ball(), cols[0], 0.2, 0.7, 0.12)
	if not parent.is_inside_tree():
		return
	# The burst follows on a timer owned by the parent, so it never outlives it.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.22
	parent.add_child(timer)
	timer.timeout.connect(_firework_burst.bind(parent, at + Vector3.UP * 1.5, cols))
	timer.timeout.connect(timer.queue_free)
	timer.start()


static func _firework_burst(parent: Node, top: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, top, FxShapes.ball(), cols, {"count": 44, "speed": Vector2(4.0, 5.5), "life": Vector2(0.7, 1.1),
		"size": Vector2(0.07, 0.1), "drag": 2.2, "gravity": Vector3(0, -3.0, 0)})
	FxSwarm.spawn(parent, top, FxShapes.cube(), [Color.WHITE], {"count": 16, "speed": Vector2(1.5, 3.0), "life": Vector2(0.6, 1.0),
		"size": Vector2(0.03, 0.05), "gravity": Vector3(0, -2.0, 0), "blink": 9.0, "stagger": 0.25})
	_flash(parent, top, FxShapes.ball(), cols[0], 0.3, 1.6, 0.16)
	Sfx.play_at(&"cos_kill_firework_pop", top, -5.0, randf_range(0.95, 1.05))


static func _hearts(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.heart(), cols, {"count": 14, "shape": "up", "spread": 65.0, "speed": Vector2(2.0, 4.2),
		"life": Vector2(0.9, 1.3), "size": Vector2(0.17, 0.26), "gravity": Vector3(0, 0.9, 0), "drag": 2.6, "wobble": 0.5,
		"spin": 2.5, "spin_axis": Vector3.UP, "pop": true})
	_flash(parent, at, FxShapes.ball(), cols[1 % cols.size()], 0.35, 1.3, 0.16)


static func _balloon(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	var col: Color = cols[randi() % cols.size()]
	FxSwarm.spawn(parent, at, FxShapes.balloon_dog(), [col], {"count": 1, "shape": "up", "spread": 0.0, "speed": Vector2(1.4, 1.4),
		"life": Vector2(0.5, 0.5), "size": Vector2(1.0, 1.0), "gravity": Vector3.ZERO, "drag": 5.0, "face": face, "spin_axis": face,
		"spin": 0.0, "sway": 0.22, "sway_hz": 4.0, "grow": 0.3, "pop": true})
	var top := at + Vector3.UP * 0.3
	FxSwarm.spawn(parent, top, FxShapes.cube(), [col, col.darkened(0.25), col.lightened(0.2)], {"count": 20, "delay": 0.48,
		"speed": Vector2(3.0, 6.0), "life": Vector2(0.25, 0.45), "size": Vector2(0.07, 0.13), "stretch": Vector3(1.0, 0.12, 0.7),
		"gravity": Vector3(0, -9.0, 0), "drag": 3.0, "spin": 14.0, "grow": 0.0})
	FxSwarm.spawn(parent, top, FxShapes.ball(), cols + [Color.WHITE], {"count": 14, "delay": 0.48, "speed": Vector2(2.0, 4.5),
		"life": Vector2(0.25, 0.4), "size": Vector2(0.04, 0.07), "gravity": Vector3(0, -6.0, 0), "drag": 2.0, "grow": 0.0})
	_glow(parent, top, FxShapes.ring(), Color.WHITE, 0.5, 3.0, 0.22, 0.48, face)


static func _disco(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	var hang := at + Vector3.UP * 0.75
	_glow(parent, at, FxShapes.glow_ball(), cols[0], 0.4, 2.0, 0.14, 0.0)
	FxSwarm.spawn(parent, hang + Vector3.UP * 0.6, FxShapes.mirror_ball(), [Color.WHITE], {"count": 1, "shape": "up", "spread": 0.0,
		"speed": Vector2(-4.2, -4.2), "drag": 7.0, "life": Vector2(0.48, 0.48), "size": Vector2(0.6, 0.6), "gravity": Vector3.ZERO,
		"spin": 5.0, "steady": true, "spin_axis": Vector3.UP, "grow": 0.15, "pop": true})
	FxSwarm.spawn(parent, hang, FxShapes.beam(), cols, {"count": 8, "speed": Vector2.ZERO, "life": Vector2(0.36, 0.42),
		"size": Vector2(2.2, 2.6), "gravity": Vector3.ZERO, "spin": 4.5, "steady": true, "spin_axis": Vector3.UP, "grow": 0.25, "delay": 0.08})
	FxSwarm.spawn(parent, hang, FxShapes.tile(), [Color(0.85, 0.87, 0.95), Color.WHITE, cols[0], cols[1 % cols.size()]], {"count": 26,
		"delay": 0.47, "speed": Vector2(2.5, 5.5), "life": Vector2(0.3, 0.45), "size": Vector2(0.07, 0.1), "gravity": Vector3(0, -9.0, 0),
		"drag": 1.5, "spin": 16.0, "grow": 0.0})
	FxSwarm.spawn(parent, hang, FxShapes.star(), [Color.WHITE] + cols, {"count": 10, "delay": 0.47, "speed": Vector2(1.0, 3.0),
		"life": Vector2(0.25, 0.4), "size": Vector2(0.08, 0.12), "gravity": Vector3.ZERO, "drag": 2.0, "blink": 9.0, "spin": 6.0})
	_glow(parent, hang, FxShapes.star_quad(), cols[0].lerp(Color.WHITE, 0.5), 1.4, 1.6, 0.22, 0.47, face)


static func _jackpot(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	var right := Vector3.UP.cross(face).normalized()
	var mid := at + Vector3.UP * 0.55
	FxSwarm.spawn(parent, mid - right * 0.6, FxShapes.lucky_seven(), [Color.WHITE], {"count": 3, "shape": "line",
		"line_to": mid + right * 0.6, "even": true, "sweep": true, "stagger": 0.16, "speed": Vector2.ZERO, "gravity": Vector3.ZERO,
		"life": Vector2(0.7, 0.7), "size": Vector2(0.5, 0.5), "face": face, "spin_axis": right, "spin": 40.0, "steady": true,
		"reel": 0.28, "grow": 0.08, "pop": true})
	for dy in [-0.42, 0.42]:
		var row: Vector3 = mid + Vector3.UP * dy
		FxSwarm.spawn(parent, row - right * 0.85, FxShapes.ball(), cols, {"count": 9, "shape": "line", "line_to": row + right * 0.85,
			"even": true, "speed": Vector2.ZERO, "gravity": Vector3.ZERO, "life": Vector2(0.75, 0.75), "size": Vector2(0.09, 0.09),
			"blink": 5.0, "grow": 0.1})
	FxSwarm.spawn(parent, mid, FxShapes.coin(), [Color(1.0, 0.78, 0.25), Color(1.0, 0.86, 0.45)], {"count": 12, "shape": "up",
		"spread": 40.0, "speed": Vector2(4.0, 6.0), "delay": 0.38, "life": Vector2(0.35, 0.45), "size": Vector2(0.13, 0.17),
		"gravity": Vector3(0, -14.0, 0), "drag": 0.4, "spin": 16.0, "spin_axis": Vector3.RIGHT, "grow": 0.05})
	_glow(parent, mid, FxShapes.star_quad(), cols[0], 1.2, 1.5, 0.25, 0.36, face)


static func _voxel(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at + Vector3.DOWN * 0.15, FxShapes.cube(), cols, {"count": 64, "box": Vector3(0.6, 1.6, 0.4),
		"sweep_y": true, "stagger": 0.32, "shape": "up", "spread": 12.0, "speed": Vector2(1.2, 2.6), "life": Vector2(0.28, 0.42),
		"size": Vector2(0.1, 0.12), "gravity": Vector3(0, 3.0, 0), "drag": 0.5, "quantize": 0.1, "blink": 7.0, "grow": 0.0})
	FxSwarm.spawn(parent, at + Vector3.DOWN * 0.95, FxShapes.ring(), [Color(cols[0], 0.9)], {"count": 1, "shape": "up",
		"spread": 0.0, "speed": Vector2(4.4, 4.4), "drag": 0.0, "gravity": Vector3.ZERO, "life": Vector2(0.42, 0.42),
		"size": Vector2(1.1, 1.1), "face": Vector3.UP, "spin": 0.0, "grow": 0.1, "fade": true})
	_glow(parent, at, FxShapes.glow_ball(), cols[0], 0.5, 1.8, 0.16, 0.0)


static func _ghost(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	FxSwarm.spawn(parent, at, FxShapes.ball(), [Color.WHITE, Color(0.85, 0.85, 1.0)], {"count": 10, "speed": Vector2(0.6, 1.6),
		"life": Vector2(0.35, 0.6), "size": Vector2(0.14, 0.24), "gravity": Vector3(0, 0.6, 0), "drag": 2.5, "grow": 0.2})
	FxSwarm.spawn(parent, at, FxShapes.ghost(), [cols[0]], {"count": 1, "shape": "up", "spread": 0.0, "speed": Vector2(1.8, 1.8),
		"drag": 1.5, "gravity": Vector3(0, 0.4, 0), "life": Vector2(0.85, 0.85), "size": Vector2(0.8, 0.8), "face": face,
		"spin_axis": face, "spin": 0.0, "sway": 0.3, "sway_hz": 2.6, "grow": 0.18})
	FxSwarm.spawn(parent, at, FxShapes.star(), [cols[1 % cols.size()], Color.WHITE], {"count": 8, "speed": Vector2(0.8, 2.0),
		"life": Vector2(0.4, 0.7), "size": Vector2(0.05, 0.08), "gravity": Vector3(0, 1.0, 0), "drag": 2.0, "blink": 6.0, "stagger": 0.2})


static func _snow_globe(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	var g := at + Vector3.UP * 0.1
	var globe := {"count": 1, "speed": Vector2.ZERO, "gravity": Vector3.ZERO, "life": Vector2(0.62, 0.62), "size": Vector2(1.3, 1.3),
		"spin": 0.0, "spin_axis": Vector3.UP, "grow": 0.2, "pop": true}
	FxSwarm.spawn(parent, g, FxShapes.globe_base(), [Color.WHITE], globe)
	FxSwarm.spawn(parent, g, FxShapes.bubble(), [cols[1 % cols.size()]], globe)
	FxSwarm.spawn(parent, g, FxShapes.snowflake(), cols, {"count": 24, "jitter": 0.32, "speed": Vector2(0.2, 0.6), "orbit": 6.0,
		"life": Vector2(0.45, 0.6), "size": Vector2(0.08, 0.12), "gravity": Vector3(0, -0.5, 0), "drag": 1.0, "spin": 5.0,
		"grow": 0.15, "stagger": 0.05})
	FxSwarm.spawn(parent, g, FxShapes.cube(), [Color.WHITE, Color(0.8, 0.95, 1.0)], {"count": 16, "delay": 0.6,
		"speed": Vector2(2.0, 4.0), "life": Vector2(0.2, 0.3), "size": Vector2(0.03, 0.05), "gravity": Vector3(0, -4.0, 0),
		"blink": 9.0, "grow": 0.0})
	_glow(parent, g, FxShapes.star_quad(), Color(0.85, 0.95, 1.0), 1.3, 1.4, 0.22, 0.6, face)


static func _black_hole(parent: Node, at: Vector3, cols: Array) -> void:
	var face := _to_camera(parent, at)
	# The accretion rings lean back so they read as ellipses round the core.
	var tilt := (face + Vector3.UP * 1.6).normalized()
	FxSwarm.spawn(parent, at, FxShapes.ball(), [Color(0.03, 0.0, 0.06)], {"count": 1, "speed": Vector2.ZERO, "gravity": Vector3.ZERO,
		"life": Vector2(0.55, 0.55), "size": Vector2(0.42, 0.42), "spin": 0.0, "grow": 0.35, "pop": true})
	for k in 2:
		FxSwarm.spawn(parent, at, FxShapes.ring(), [Color(cols[k % cols.size()], 0.9 - k * 0.2)], {"count": 1, "speed": Vector2.ZERO,
			"gravity": Vector3.ZERO, "life": Vector2(0.55, 0.55), "size": Vector2(1.0 - k * 0.25, 1.0 - k * 0.25), "face": tilt,
			"spin": 0.0, "grow": 0.3, "pop": true})
	FxSwarm.spawn(parent, at, FxShapes.star(), cols, {"count": 30, "radius": 1.7, "speed": Vector2(-3.0, -3.4), "drag": 0.0,
		"gravity": Vector3.ZERO, "orbit": 4.0, "life": Vector2(0.42, 0.5), "size": Vector2(0.07, 0.11), "spin": 6.0,
		"stagger": 0.08, "grow": 0.1})
	_glow(parent, at, FxShapes.star_quad(), Color.WHITE, 1.6, 1.3, 0.2, 0.53, face)
	_glow(parent, at, FxShapes.ring(), cols[1 % cols.size()], 0.4, 4.0, 0.3, 0.53, face)
	FxSwarm.spawn(parent, at, FxShapes.cube(), [Color.WHITE] + cols, {"count": 12, "delay": 0.53, "speed": Vector2(4.0, 7.0),
		"life": Vector2(0.2, 0.3), "size": Vector2(0.04, 0.06), "gravity": Vector3.ZERO, "drag": 3.0, "blink": 9.0, "grow": 0.0})


static func _tickets(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.ticket(), cols, {"count": 18, "shape": "up", "spread": 42.0, "speed": Vector2(4.5, 7.0),
		"life": Vector2(0.65, 0.85), "size": Vector2(0.24, 0.3), "gravity": Vector3(0, -7.0, 0), "drag": 2.6, "spin": 9.0,
		"wobble": 1.2, "grow": 0.08, "stagger": 0.12})
	FxSwarm.spawn(parent, at, FxShapes.star(), [Color(1.0, 0.85, 0.3), Color.WHITE], {"count": 10, "speed": Vector2(1.5, 3.5),
		"life": Vector2(0.3, 0.5), "size": Vector2(0.07, 0.1), "gravity": Vector3(0, -2.0, 0), "drag": 2.5, "blink": 8.0, "spin": 6.0})
	_glow(parent, at, FxShapes.glow_ball(), Color(1.0, 0.75, 0.35), 0.4, 2.2, 0.16, 0.0)


static func _pinata(parent: Node, at: Vector3, cols: Array) -> void:
	FxSwarm.spawn(parent, at, FxShapes.candy(), cols, {"count": 16, "speed": Vector2(3.0, 5.5), "life": Vector2(0.6, 0.8),
		"size": Vector2(0.16, 0.2), "gravity": Vector3(0, -11.0, 0), "drag": 1.0, "spin": 10.0, "bounce": -1.0, "grow": 0.05})
	FxSwarm.spawn(parent, at, FxShapes.cube(), cols, {"count": 12, "shape": "up", "spread": 75.0, "speed": Vector2(5.0, 7.5),
		"life": Vector2(0.55, 0.75), "size": Vector2(0.4, 0.55), "stretch": Vector3(0.22, 0.03, 1.0), "align": true,
		"gravity": Vector3(0, -7.0, 0), "drag": 2.2})
	FxSwarm.spawn(parent, at, FxShapes.cube(), cols, {"count": 20, "speed": Vector2(2.0, 5.0), "life": Vector2(0.4, 0.7),
		"size": Vector2(0.05, 0.07), "stretch": Vector3(1.0, 0.15, 0.6), "gravity": Vector3(0, -4.0, 0), "drag": 2.5, "spin": 12.0})
	_glow(parent, at, FxShapes.glow_ball(), cols[0], 0.4, 2.0, 0.14, 0.0)


## Direction from `at` to the camera, levelled (props turn to face the player).
static func _to_camera(parent: Node, at: Vector3) -> Vector3:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam == null:
		return Vector3.BACK
	var d := cam.global_position - at
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


## A pooled additive flash (glow ball, star or ring) that swells by `expand`
## and fades over `life`, after `delay`; `face` turns flat ones to the camera.
static func _glow(parent: Node, at: Vector3, mesh: Mesh, color: Color, size: float, expand: float, life: float, delay: float,
		face := Vector3.ZERO) -> void:
	var strength := Settings.flash_scale()
	if strength < 0.05:
		return
	FxSwarm.spawn(parent, at, mesh, [Color(color, 0.85 * strength)], {"count": 1, "speed": Vector2.ZERO, "life": Vector2(life, life),
		"size": Vector2(size, size), "gravity": Vector3.ZERO, "spin": 0.0, "grow": 0.0, "expand": expand, "fade": true,
		"delay": delay, "face": face})


## An expanding ring facing `normal`, starting after `delay`.
static func _ring(parent: Node, at: Vector3, normal: Vector3, color: Color, delay: float) -> void:
	if not parent.is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	ring.mesh = FxShapes.ring()
	ring.material_override = FxShapes.additive_material(color)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = at
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
	ring.global_basis = Basis.looking_at(-normal, up)
	ring.scale = Vector3.ONE * 0.2
	ring.transparency = 1.0 if delay > 0.0 else 0.0
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "transparency", 0.0, 0.01).set_delay(delay)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.38).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.3).set_delay(delay + 0.1)
	tw.chain().tween_callback(ring.queue_free)


## A quick flash that swells from `from` to `to` (scale) and fades.
static func _flash(parent: Node, at: Vector3, mesh: Mesh, color: Color, from: float, to: float, time: float, material: Material = null) -> void:
	if not parent.is_inside_tree() or Settings.flash_scale() < 0.05:
		return
	var flash := MeshInstance3D.new()
	flash.mesh = mesh
	flash.material_override = material if material else FxShapes.additive_material(color)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = at
	flash.scale = Vector3.ONE * from
	flash.transparency = 1.0 - 0.85 * Settings.flash_scale()
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * to, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "transparency", 1.0, time)
	tw.chain().tween_callback(flash.queue_free)
