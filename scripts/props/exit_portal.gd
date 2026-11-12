class_name ExitPortal
extends Node3D
## The level exit. Dormant until the final wave is cleared; then it lights up
## and the player must step through it to finish the run.

signal entered

var active := false

@onready var trigger: Area3D = $Trigger
@onready var swirl: Node3D = get_node_or_null("Swirl")
@onready var light: OmniLight3D = get_node_or_null("Light")
@onready var hum: AudioStreamPlayer3D = get_node_or_null("Hum")


func _ready() -> void:
	add_to_group("portal")
	trigger.body_entered.connect(_on_body_entered)
	_apply()


func activate() -> void:
	if active:
		return
	active = true
	_apply()
	get_tree().call_group("exit_lights", "set_lit", true)
	if hum:
		var s := Sfx.stream(&"portal_hum")
		if s:
			if s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = int(s.get_length() * s.mix_rate)
			hum.stream = s
			hum.play()
	# The player may already be standing in the doorway.
	for body in trigger.get_overlapping_bodies():
		_on_body_entered(body)


func _apply() -> void:
	if swirl:
		swirl.visible = active
	if light:
		light.visible = active


func _on_body_entered(body: Node3D) -> void:
	if active and body is Player:
		entered.emit()
