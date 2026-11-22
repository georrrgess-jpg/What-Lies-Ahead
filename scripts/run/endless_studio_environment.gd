extends "res://scripts/run/level_environment.gd"
## Root script for Starlot Studios (the second Endless map, built by
## tools/build_endless_studio.gd). Does everything level_environment.gd does
## (graphics preset, bulb halos) and keeps the backlot alive at night:
##  - searchlights (group "city_searchlight", meta "yaw" and "phase", as the
##    city's generator builds them) sweeping the sky over the boulevard;
##  - the water tower's red beacon (group "studio_beacon") blinking;
##  - lights and neon that flicker now and then (group "studio_flicker":
##    an OmniLight3D dips, anything else blinks out);
##  - the bridge set's red alert lights (group "studio_alert") pulsing;
##  - paparazzi flashes at the step-and-repeat (group "studio_flash");
##  - the Monster Lot's storm machine (group "studio_lightning"): a cold
##    double flash over the castle and a roll of thunder after it.
## The marquee bulbs chase in their own shader (studio_marquee.gdshader).

const SWEEP := 0.75
const SWEEP_SPEED := 0.2
const BEACON_PERIOD := 1.8
const FLICKER_GAP := Vector2(2.0, 9.0)
const FLICKER_LENGTH := Vector2(0.05, 0.2)
const ALERT_PERIOD := 2.4
## Seconds between paparazzi bursts, flashes per burst, one flash's length.
const FLASH_GAP := Vector2(0.6, 3.5)
const FLASH_LENGTH := 0.07
const FLASH_ENERGY := 6.0
## The storm machine: seconds between strikes, the flash's peak energy, the
## thunder's delay.
const LIGHTNING_GAP := Vector2(14.0, 30.0)
const LIGHTNING_ENERGY := 9.0
const THUNDER_DELAY := Vector2(0.4, 1.2)
const THUNDER := &"city_thunder"

var _time := 0.0
var _searchlights: Array[Node3D] = []
var _beacons: Array[Node3D] = []
## Flickering nodes: [node, base energy (lights) or -1, next flicker, end].
var _flicker: Array = []
var _alerts: Array[OmniLight3D] = []
var _alert_energy: Array[float] = []
## Paparazzi lights: [light, next flash time].
var _flashes: Array = []
var _lightning: Array[OmniLight3D] = []
var _next_strike := 8.0
var _strike_at := -10.0
var _thunder_at := -1.0


func _ready() -> void:
	super()
	for node in get_tree().get_nodes_in_group("city_searchlight"):
		if node is Node3D and is_ancestor_of(node):
			_searchlights.append(node)
	for node in get_tree().get_nodes_in_group("studio_beacon"):
		if node is Node3D and is_ancestor_of(node):
			_beacons.append(node)
	for node in get_tree().get_nodes_in_group("studio_flicker"):
		if node is Node3D and is_ancestor_of(node):
			var base := (node as OmniLight3D).light_energy if node is OmniLight3D else -1.0
			_flicker.append([node, base, randf_range(FLICKER_GAP.x, FLICKER_GAP.y), 0.0])
	for node in get_tree().get_nodes_in_group("studio_alert"):
		if node is OmniLight3D and is_ancestor_of(node):
			_alerts.append(node)
			_alert_energy.append((node as OmniLight3D).light_energy)
	for node in get_tree().get_nodes_in_group("studio_flash"):
		if node is OmniLight3D and is_ancestor_of(node):
			_flashes.append([node, randf_range(FLASH_GAP.x, FLASH_GAP.y)])
	for node in get_tree().get_nodes_in_group("studio_lightning"):
		if node is OmniLight3D and is_ancestor_of(node):
			_lightning.append(node)


func _process(delta: float) -> void:
	_time += delta
	for s in _searchlights:
		s.rotation.y = float(s.get_meta("yaw", 0.0)) + sin(_time * SWEEP_SPEED + float(s.get_meta("phase", 0.0))) * SWEEP
	var beacon_on := fmod(_time, BEACON_PERIOD) < BEACON_PERIOD * 0.4
	for b in _beacons:
		b.visible = beacon_on
	_update_flicker()
	var pulse := 0.5 + 0.5 * sin(_time * TAU / ALERT_PERIOD)
	for i in _alerts.size():
		_alerts[i].light_energy = _alert_energy[i] * (0.25 + 0.75 * pulse)
	for entry in _flashes:
		var light: OmniLight3D = entry[0]
		if _time >= entry[1]:
			entry[1] = _time + randf_range(FLASH_GAP.x, FLASH_GAP.y)
			light.set_meta("until", _time + FLASH_LENGTH)
		light.light_energy = FLASH_ENERGY if _time < float(light.get_meta("until", 0.0)) else 0.0
	_update_lightning()


func _update_flicker() -> void:
	for entry in _flicker:
		var node: Node3D = entry[0]
		if _time >= entry[2]:
			entry[3] = _time + randf_range(FLICKER_LENGTH.x, FLICKER_LENGTH.y)
			entry[2] = entry[3] + randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
		var dark: bool = _time < entry[3]
		if entry[1] < 0.0:
			node.visible = not dark
		else:
			(node as OmniLight3D).light_energy = entry[1] * (0.2 if dark else 1.0)


## The storm machine's double flash: a bright strike, a dip, a second one.
func _update_lightning() -> void:
	if _lightning.is_empty():
		return
	if _time >= _next_strike:
		_strike_at = _time
		_next_strike = _time + randf_range(LIGHTNING_GAP.x, LIGHTNING_GAP.y)
		_thunder_at = _time + randf_range(THUNDER_DELAY.x, THUNDER_DELAY.y)
	var t := _time - _strike_at
	var level := 0.0
	if t < 0.08:
		level = 1.0
	elif t < 0.16:
		level = 0.15
	elif t < 0.3:
		level = 0.8 * (1.0 - (t - 0.16) / 0.14)
	for l in _lightning:
		l.light_energy = LIGHTNING_ENERGY * level
	if _thunder_at > 0.0 and _time >= _thunder_at:
		_thunder_at = -1.0
		var cam := get_viewport().get_camera_3d()
		var near := cam != null and cam.global_position.distance_to(_lightning[0].global_position) < 60.0
		Sfx.play(THUNDER, -6.0 if near else -16.0, randf_range(0.9, 1.1))
