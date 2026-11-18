extends Node3D
## Ghost Train's own shader warm-up, alongside FxWarmup at level start (while
## the screen fades in from black): as soon as the player's camera exists it
## draws the Bedsheet Ghost's see-through fade material and a Pumpkin Head's
## bomb in front of it for a few frames, so neither compiles mid-fight on its
## first use. Only in a run (the menu backdrop has no run director). Frees
## itself.

const FRAMES := 4
const GIVE_UP_FRAMES := 300
const FADE_SHADER := "res://art/shaders/fright_ghost_fade.gdshader"

var _frames := 0
var _placed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_frames += 1
	if _placed:
		if _frames >= FRAMES:
			queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	if camera and get_tree().get_first_node_in_group("run_director"):
		_place(camera)
	elif _frames > GIVE_UP_FRAMES:
		queue_free()


func _place(camera: Camera3D) -> void:
	_placed = true
	_frames = 0
	var at := camera.global_position - camera.global_transform.basis.z * 2.5
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	var fade := ShaderMaterial.new()
	fade.shader = load(FADE_SHADER)
	fade.set_shader_parameter(&"alpha", 0.5)
	quad.material_override = fade
	add_child(quad)
	quad.global_position = at
	FrightPumpkinShell.throw(self, at + Vector3.UP * 0.3, at, 0.5, 0.2)
