class_name DuneCountdown
extends Label3D
## The launch countdown clock on Launch Pad 9's gantry. It counts down while
## the run is on and switches to a flashing "GATE OPEN" once the exit
## portal opens.

## Where the clock starts (seconds); it wraps back here after reaching zero.
@export var start_seconds := 540.0
@export var go_text := "GATE OPEN"
@export var go_color := Color(0.35, 1.0, 0.6)
## Text size of the go message relative to the clock digits (it is longer).
@export var go_scale := 0.78

var _left := 0.0
var _shown := -1
var _go := false
var _blink := 0.0
var _count_color := Color.WHITE


func _ready() -> void:
	_left = start_seconds
	_count_color = modulate
	_show_time()


func _process(delta: float) -> void:
	if _go:
		_blink += delta
		modulate = go_color if fmod(_blink, 1.0) < 0.7 else go_color.darkened(0.6)
		return
	var portal := get_tree().get_first_node_in_group("portal") as ExitPortal
	if portal and portal.active:
		_go = true
		text = go_text
		pixel_size *= go_scale
		return
	_left -= delta
	if _left <= 0.0:
		_left = start_seconds
	_show_time()


func _show_time() -> void:
	var whole := int(ceil(_left))
	if whole == _shown:
		return
	_shown = whole
	text = "T-%02d:%02d" % [whole / 60, whole % 60]
	modulate = _count_color
