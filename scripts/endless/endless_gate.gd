class_name EndlessGate
extends Node3D
## A locked gate between two districts of an Endless map. The player pays the
## district's price in tickets (EndlessDistrict.price) while standing in the
## gate's zone; the gate opens for the rest of the run, the zombies' paths
## through it switch on and the district behind it wakes up.
##
## Node layout (built by the map's generator; docs/ENDLESS.md):
##   EndlessGate            this script, `district` = the district it opens
##     Frame                static visual (posts, fence, barricade frame)
##     Door                 the visual that moves away when it opens
##     Blocker              StaticBody3D (collision layer 1) removed on open
##     Zone                 Area3D on both sides: where the player can pay
##     NavLink, NavLink2..  NavigationLink3D across the threshold, disabled
##                          until open (the navmesh is baked with the gate shut)
##
## The EndlessDirector hands it its district (bind()); the gate then shows a
## price sign over the door, tells the director when the player stands in its
## zone, shakes when the player cannot pay and plays its open animation
## (`open_style`) with dust, sparks and the district sting.

signal opened(gate: EndlessGate)

## The district this gate opens.
@export var district: StringName
## How the door goes: "shutter" (rolls up), "slide" (moves aside), "topple"
## (a barricade knocked flat).
@export var open_style: StringName = &"shutter"

const OPEN_SECONDS := {&"shutter": 1.5, &"slide": 1.2, &"topple": 0.75}
const DUST := [Color(0.55, 0.5, 0.46), Color(0.42, 0.38, 0.35), Color(0.7, 0.64, 0.56)]
const SPARKS := [Color(1.0, 0.85, 0.4), Color(1.0, 0.55, 0.15), Color(1.0, 1.0, 0.8)]

var is_open := false
## True while the player stands in the gate's zone.
var player_inside := false
var data: EndlessDistrict

var _sign: Label3D
var _price: Label3D
var _door_box := AABB(Vector3(-3, 0, -0.2), Vector3(6, 4.5, 0.4))
var _door_home := Vector3.ZERO
var _shake: Tween


func _ready() -> void:
	add_to_group("endless_gate")
	_set_links(false)
	var zone := get_node_or_null("Zone") as Area3D
	if zone:
		zone.body_entered.connect(_on_zone.bind(true))
		zone.body_exited.connect(_on_zone.bind(false))
	var door := get_node_or_null("Door") as Node3D
	if door:
		_door_home = door.position
		var box := _bounds(door, door.transform)
		if box.size != Vector3.ZERO:
			_door_box = box


## Called by the director with the gate's district: builds the price sign.
func bind(district_data: EndlessDistrict) -> void:
	data = district_data
	if data == null or _sign:
		return
	_sign = _label(data.display_name.to_upper(), 64, data.accent_color, 0.0)
	_price = _label("%d TICKETS" % data.price, 44, Color(1.0, 0.82, 0.3), -0.42)


## What the HUD prompt says while the player stands here ({} once open).
func prompt() -> Dictionary:
	if is_open or data == null:
		return {}
	return {"action": "open %s" % data.display_name, "price": data.price, "accent": data.accent_color}


## The player tried to open it without the tickets.
func deny() -> void:
	Sfx.play_at(&"end_gate_denied", global_position + Vector3.UP * 1.5, -2.0)
	var door := get_node_or_null("Door") as Node3D
	if door == null:
		return
	if _shake and _shake.is_valid():
		_shake.kill()
	door.position = _door_home
	_shake = create_tween()
	for i in 4:
		var side := 0.07 if i % 2 == 0 else -0.07
		_shake.tween_property(door, "position", _door_home + door.transform.basis.x.normalized() * side, 0.04)
	_shake.tween_property(door, "position", _door_home, 0.05)
	if _price:
		var flash := create_tween()
		flash.tween_property(_price, "modulate", Color(1.0, 0.3, 0.3), 0.08)
		flash.tween_property(_price, "modulate", Color.WHITE, 0.35)


## Opens the gate (no payment here: the director checks and spends tickets).
## `animate` false snaps it open (a second gate of a district already paid for
## opens with its own animation too, so it is true there as well).
func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	player_inside = false
	var blocker := get_node_or_null("Blocker")
	if blocker:
		blocker.queue_free()
	_set_links(true)
	if _sign:
		var tw := create_tween()
		tw.tween_property(_sign, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(_price, "modulate:a", 0.0, 0.3)
	var door := get_node_or_null("Door") as Node3D
	if door:
		if animate:
			_animate_door(door)
		else:
			door.visible = false
	opened.emit(self)


func _animate_door(door: Node3D) -> void:
	var at := global_transform * Vector3(_door_box.get_center().x, 0.2, _door_box.get_center().z)
	Sfx.play_at(&"end_gate_open", at + Vector3.UP * 1.5, 0.0, 1.0, 14.0)
	var seconds: float = OPEN_SECONDS.get(open_style, 1.2)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
	match open_style:
		&"topple":
			# A barricade goes over backwards (away from the side the player stands on).
			var away := -1.0 if _player_side() > 0.0 else 1.0
			tw.set_ease(Tween.EASE_IN)
			tw.tween_property(door, "rotation:x", door.rotation.x + away * PI * 0.5, seconds)
			tw.tween_callback(_burst.bind(at, DUST, 46, 4.0, 0.12))
			tw.tween_property(door, "position:y", door.position.y - 0.35, 0.5).set_ease(Tween.EASE_OUT)
		&"slide":
			tw.set_ease(Tween.EASE_IN_OUT)
			var side := door.transform.basis.x.normalized() * (_door_box.size.x * 0.96)
			tw.tween_property(door, "position", _door_home + side, seconds)
		_:
			# A roll-up shutter: it climbs and rolls up into its drum.
			tw.set_ease(Tween.EASE_IN_OUT)
			var h := _door_box.size.y
			tw.tween_property(door, "position:y", _door_home.y + h * 0.86, seconds)
			tw.parallel().tween_property(door, "scale:y", door.scale.y * 0.14, seconds)
	_burst(at, DUST, 34, 3.0, 0.14)
	_burst(at + Vector3.UP * _door_box.size.y * 0.5, SPARKS, 28, 6.0, 0.05)


## +1 if the player is in front of the gate (local +Z), -1 behind, 0 if unknown.
func _player_side() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return 0.0
	return signf((global_transform.affine_inverse() * player.global_position).z)


func _burst(at: Vector3, colors: Array, amount: int, speed: float, size: float) -> void:
	EndlessProps.burst(get_parent(), at, Vector3.UP, colors, amount, speed, 1.1, size, 80.0)


func _label(text: String, font_size: int, color: Color, drop: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiKit.display_font()
	l.font_size = font_size
	l.pixel_size = 0.008
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.02, 0.06, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.modulate = color.lerp(Color.WHITE, 0.15)
	l.position = Vector3(_door_box.get_center().x, _door_box.end.y + 0.9 + drop, _door_box.get_center().z)
	add_child(l)
	return l


func _on_zone(body: Node3D, inside: bool) -> void:
	if body is Player:
		player_inside = inside and not is_open


func _set_links(on: bool) -> void:
	for child in get_children():
		if child is NavigationLink3D:
			child.enabled = on


## The bounds of every mesh under `node`, in this gate's space.
func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = xform * (node as MeshInstance3D).get_aabb()
		first = false
	for child in node.get_children():
		if child is Node3D:
			var b := _bounds(child, xform * (child as Node3D).transform)
			if b.size == Vector3.ZERO:
				continue
			box = b if first else box.merge(b)
			first = false
	return box
