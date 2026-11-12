class_name KillEffects
extends RefCounted
## The "kill_effect" cosmetics: what a zombie pops into on the killing blow.
## Fx.kill_effect() calls play() with the equipped item. An item names its
## effect in params.effect (see EFFECTS) and may override the colours; each
## effect also plays its own small sound layer ("cos_kill_<effect>").

const EFFECTS := ["confetti", "pixel", "neon_ring", "bubbles", "snow", "starburst", "coins", "firework", "hearts"]

const DEFAULT_COLORS := {
	"pixel": [Color(0.3, 1.0, 0.45), Color(0.25, 0.85, 1.0), Color(1.0, 0.3, 0.75), Color(1.0, 0.9, 0.2)],
	"neon_ring": [Color(1.0, 0.25, 0.7), Color(0.2, 0.95, 1.0)],
	"bubbles": [Color(0.55, 0.9, 1.0), Color(1.0, 0.6, 0.9), Color(0.75, 1.0, 0.8)],
	"snow": [Color.WHITE, Color(0.7, 0.9, 1.0), Color(0.55, 0.8, 1.0)],
	"starburst": [Color(1.0, 0.85, 0.25), Color.WHITE, Color(1.0, 0.55, 0.2)],
	"coins": [Color(1.0, 0.78, 0.25), Color(1.0, 0.86, 0.45)],
	"firework": [Color(1.0, 0.3, 0.45), Color(0.4, 0.8, 1.0), Color(1.0, 0.9, 0.3), Color(0.7, 1.0, 0.4)],
	"hearts": [Color(1.0, 0.3, 0.55), Color(1.0, 0.55, 0.75), Color(0.95, 0.15, 0.35)],
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
