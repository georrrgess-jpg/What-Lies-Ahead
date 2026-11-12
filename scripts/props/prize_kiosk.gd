class_name PrizeKiosk
extends Node3D
## The loadout station (the prize kiosk at the centre of the pier). Open during breaks: the run
## director sells ammo and heals and offers free weapon swaps while the player
## stands inside its zone.

signal player_entered
signal player_exited
signal open_changed(open: bool)

var open := false
var player_inside := false

@onready var zone: Area3D = $Zone
@onready var open_glow: Node3D = get_node_or_null("OpenGlow")

var _pulse := 0.0


var _beacon: LoadoutBeacon


func _ready() -> void:
	add_to_group("kiosk")
	_beacon = LoadoutBeacon.new()
	_beacon.name = "Beacon"
	add_child(_beacon)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	set_open(false)


func set_open(value: bool) -> void:
	open = value
	if _beacon:
		_beacon.set_open(value)
	if open_glow:
		open_glow.visible = value
	open_changed.emit(value)


func _process(delta: float) -> void:
	if open and open_glow:
		_pulse += delta * 2.5
		var s := 1.0 + sin(_pulse) * 0.015
		open_glow.scale = Vector3(s, 1.0, s)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_inside = true
		player_entered.emit()


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_inside = false
		player_exited.emit()
