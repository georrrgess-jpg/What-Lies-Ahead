class_name HudIcon
extends Control
## Small vector icons for the in-game UI (tickets, health, shield, energy,
## damage boost, zombies, time, the portal, the station). They are drawn from
## cached unit polygons, so drawing one allocates nothing.
##
##   row.add_child(HudIcon.make(&"ticket", 30.0, UiKit.AMBER))
##   HudIcon.paint(self, &"heart", Vector2(20, 20), 28.0, UiKit.RED)   # inside a _draw()

const KINDS: Array[StringName] = [&"ticket", &"heart", &"shield", &"bolt", &"boost", &"zombie", &"clock", &"portal", &"star", &"check", &"swap"]

static var _shapes := {}

var kind: StringName = &"star":
	set(v):
		kind = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


static func make(icon_kind: StringName, icon_size := 32.0, icon_color := Color.WHITE) -> HudIcon:
	var i := HudIcon.new()
	i.kind = icon_kind
	i.color = icon_color
	i.custom_minimum_size = Vector2(icon_size, icon_size)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	paint(self, kind, size * 0.5, minf(size.x, size.y), color)


## Draws icon `icon_kind`, `px` pixels across and centred on `at`, on `ci`
## (call it from that item's _draw()).
static func paint(ci: CanvasItem, icon_kind: StringName, at: Vector2, px: float, tint: Color) -> void:
	if _shapes.is_empty():
		_build_shapes()
	var ink := Color(UiKit.INK, tint.a * 0.9)
	ci.draw_set_transform(at, 0.0, Vector2(px, px))
	match icon_kind:
		&"clock":
			ci.draw_circle(Vector2.ZERO, 0.46, tint)
			ci.draw_circle(Vector2.ZERO, 0.33, ink)
			ci.draw_line(Vector2.ZERO, Vector2(0.0, -0.24), tint, 0.09)
			ci.draw_line(Vector2.ZERO, Vector2(0.17, 0.06), tint, 0.09)
		&"portal":
			ci.draw_arc(Vector2.ZERO, 0.4, 0.0, TAU, 28, tint, 0.13, true)
			ci.draw_circle(Vector2.ZERO, 0.15, tint)
		&"zombie":
			ci.draw_colored_polygon(_shapes[&"zombie"], tint)
			ci.draw_circle(Vector2(-0.17, -0.08), 0.1, ink)
			ci.draw_circle(Vector2(0.17, -0.08), 0.1, ink)
			ci.draw_line(Vector2(-0.16, 0.24), Vector2(0.16, 0.24), ink, 0.08)
		&"ticket":
			ci.draw_colored_polygon(_shapes[&"ticket"], tint)
			ci.draw_line(Vector2(0.14, -0.2), Vector2(0.14, 0.2), ink, 0.05)
			ci.draw_circle(Vector2(-0.16, 0.0), 0.1, ink)
		&"check":
			ci.draw_polyline(_shapes[&"check"], tint, 0.16, true)
		&"swap":
			ci.draw_colored_polygon(_shapes[&"swap"], tint)
			ci.draw_colored_polygon(_shapes[&"swap_b"], tint)
		&"boost":
			ci.draw_colored_polygon(_shapes[&"boost"], tint)
			ci.draw_colored_polygon(_shapes[&"boost_b"], tint)
		_:
			if _shapes.has(icon_kind):
				ci.draw_colored_polygon(_shapes[icon_kind], tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _build_shapes() -> void:
	_shapes[&"ticket"] = PackedVector2Array([Vector2(-0.5, -0.3), Vector2(0.5, -0.3), Vector2(0.5, -0.1), Vector2(0.4, 0.0),
		Vector2(0.5, 0.1), Vector2(0.5, 0.3), Vector2(-0.5, 0.3), Vector2(-0.5, 0.1), Vector2(-0.4, 0.0), Vector2(-0.5, -0.1)])
	_shapes[&"shield"] = PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.42, -0.34), Vector2(0.42, 0.04), Vector2(0.24, 0.32),
		Vector2(0.0, 0.5), Vector2(-0.24, 0.32), Vector2(-0.42, 0.04), Vector2(-0.42, -0.34)])
	_shapes[&"bolt"] = PackedVector2Array([Vector2(0.12, -0.5), Vector2(-0.32, 0.08), Vector2(-0.04, 0.08), Vector2(-0.14, 0.5),
		Vector2(0.32, -0.1), Vector2(0.04, -0.1)])
	var chevron := PackedVector2Array([Vector2(0.0, -0.48), Vector2(0.42, -0.08), Vector2(0.42, 0.14), Vector2(0.0, -0.26),
		Vector2(-0.42, 0.14), Vector2(-0.42, -0.08)])
	_shapes[&"boost"] = chevron
	_shapes[&"boost_b"] = _moved(chevron, Vector2(0.0, 0.34))
	_shapes[&"zombie"] = PackedVector2Array([Vector2(-0.3, -0.46), Vector2(0.3, -0.46), Vector2(0.44, -0.3), Vector2(0.44, 0.14),
		Vector2(0.3, 0.44), Vector2(-0.3, 0.44), Vector2(-0.44, 0.14), Vector2(-0.44, -0.3)])
	_shapes[&"check"] = PackedVector2Array([Vector2(-0.34, 0.02), Vector2(-0.1, 0.26), Vector2(0.36, -0.26)])
	var arrow := PackedVector2Array([Vector2(-0.46, -0.33), Vector2(0.14, -0.33), Vector2(0.14, -0.48), Vector2(0.48, -0.25),
		Vector2(0.14, -0.02), Vector2(0.14, -0.17), Vector2(-0.46, -0.17)])
	_shapes[&"swap"] = arrow
	var back := PackedVector2Array()
	for p in arrow:
		back.append(Vector2(-p.x, -p.y))
	_shapes[&"swap_b"] = back
	var heart := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		heart.append(Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) - 2.5) / 34.0)
	_shapes[&"heart"] = heart
	var star := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + PI * k / 5.0
		star.append(Vector2(cos(a), sin(a)) * (0.5 if k % 2 == 0 else 0.22))
	_shapes[&"star"] = star


static func _moved(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out
