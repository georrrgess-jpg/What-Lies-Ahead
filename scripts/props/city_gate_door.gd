class_name CityGateDoor
extends Node3D
## Opening animation for the Ashfall City gate doors (art/models/city_gate_*_door.glb).
## Attach to the instanced door model (an EndlessGate's "Door"); the gate calls
## play_open(open_style) instead of hiding it. The moving parts are the model's
## child nodes, each pivoting at its origin (art/blender/build_city_gates.py):
##   shutter  Leaf          rolls up into the lintel (scales to nothing upwards)
##   slide    LeafL, LeafR  roll apart along X on the ground track
##   topple   Leaf          falls flat backwards (towards -Z) and settles

signal finished

## Used when play_open() gets no style.
@export var style: StringName = &"shutter"
@export var duration := 1.3
## How far each fence leaf rolls aside (metres).
@export var slide_distance := 3.1


func play_open(open_style: StringName = &"") -> void:
	var kind := open_style if open_style != &"" else style
	var tween := create_tween().set_parallel(true)
	match kind:
		&"slide":
			_slide(tween, "LeafL", -1.0)
			_slide(tween, "LeafR", 1.0)
		&"topple":
			var leaf := find_child("Leaf", true, false) as Node3D
			if leaf:
				var fall := tween.tween_property(leaf, "rotation:x", -PI * 0.5, duration * 0.7)
				fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.chain().tween_property(leaf, "rotation:x", -PI * 0.47, 0.12).set_trans(Tween.TRANS_SINE)
				tween.chain().tween_property(leaf, "rotation:x", -PI * 0.5, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_:
			var leaf := find_child("Leaf", true, false) as Node3D
			if leaf:
				var roll := tween.tween_property(leaf, "scale:y", 0.02, duration)
				roll.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func() -> void: finished.emit())


func _slide(tween: Tween, leaf_name: String, direction: float) -> void:
	var leaf := find_child(leaf_name, true, false) as Node3D
	if leaf == null:
		return
	var target := leaf.position.x + direction * slide_distance
	tween.tween_property(leaf, "position:x", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
