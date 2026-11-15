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

signal opened(gate: EndlessGate)

## The district this gate opens.
@export var district: StringName
## How the door goes: "shutter" (rolls up), "slide" (moves aside), "topple"
## (a barricade knocked flat).
@export var open_style: StringName = &"shutter"

var is_open := false


func _ready() -> void:
	add_to_group("endless_gate")
	_set_links(false)


## Opens the gate (no payment here: the director checks and spends tickets).
func open() -> void:
	if is_open:
		return
	is_open = true
	var blocker := get_node_or_null("Blocker")
	if blocker:
		blocker.queue_free()
	var door := get_node_or_null("Door") as Node3D
	if door:
		door.visible = false
	_set_links(true)
	opened.emit(self)


func _set_links(on: bool) -> void:
	for child in get_children():
		if child is NavigationLink3D:
			child.enabled = on
