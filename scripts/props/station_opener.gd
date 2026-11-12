class_name StationOpener
extends Node
## Animates part of a loadout station's model as the station opens and closes
## (a shutter that swings up into an awning, a hatch that drops into a ramp),
## and shows some nodes only while open (an OPEN sign) or only while closed.
## Add it as a direct child of a PrizeKiosk scene; several openers may share one
## station.

## The hinged node (usually a node inside the imported model). Its pose in the
## scene is the closed pose.
@export var hinge: NodePath
## The hinged node's rotation while open, in degrees.
@export var open_rotation_degrees := Vector3.ZERO
## Seconds to swing between the two poses.
@export var duration := 0.6
## Easing of the opening swing (BACK overshoots a little; BOUNCE suits a ramp that hits the ground).
@export var open_transition := Tween.TRANS_BACK
## Nodes visible only while the station is open (they appear once it has opened).
@export var show_when_open: Array[NodePath] = []
## Nodes visible only while the station is closed (they appear once it has closed).
@export var show_when_closed: Array[NodePath] = []

var _hinge: Node3D
var _closed_rotation := Vector3.ZERO
var _tween: Tween
var _snap := true


func _ready() -> void:
	_hinge = get_node_or_null(hinge) as Node3D
	if _hinge:
		_closed_rotation = _hinge.rotation
	var station := get_parent() as PrizeKiosk
	if station:
		station.open_changed.connect(_on_open_changed)


func _on_open_changed(open: bool) -> void:
	if _tween:
		_tween.kill()
	# Signs of the state being left go away at once; the new state's appear
	# when the swing ends.
	_set_visible(show_when_open if not open else show_when_closed, false)
	var target := open_rotation_degrees * (PI / 180.0) if open else _closed_rotation
	if _snap or _hinge == null:
		_snap = false
		if _hinge:
			_hinge.rotation = target
		_set_visible(show_when_open if open else show_when_closed, true)
		return
	_tween = create_tween().set_trans(open_transition if open else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hinge, "rotation", target, duration)
	_tween.tween_callback(_set_visible.bind(show_when_open if open else show_when_closed, true))


func _set_visible(paths: Array[NodePath], value: bool) -> void:
	for path in paths:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.visible = value
