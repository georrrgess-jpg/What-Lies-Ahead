class_name Operators
extends RefCounted
## Operators (the "avatar" cosmetic slot): playable characters shown in the
## Locker, on the player card and on the main menu. They also set the look of
## the first-person arms unless a gloves skin is equipped.
##
## An operator item's params: {"model": "res://art/models/operator_x.glb",
## "arm_pattern": "stripes", ...}; its `colors` are its arm scheme
## [glove, plate, cuff, sleeve, accent] (see WeaponCosmetics.apply_arms).
## Models follow the material naming contract in art/blender/build_operators.py:
## OpBody (vertex-coloured body), FxHolo*, FxGold* and FxGlass* surfaces get
## shaders here.
##
## Clips: Idle, Run, AimIdle (loops), Pose, Fire, Victory, Wave (one-shots);
## play() takes the name with or without "-loop". Sockets: WeaponSocket (right
## hand; a weapon model parented there sits in both hands in AimIdle / Fire)
## and HeadSocket (head centre).

const DEFAULT_MODEL := "res://art/models/operator_boardwalk_ranger.glb"
const HOLO_SHADER := "res://art/shaders/skin_hologram.gdshader"
const GOLD_SHADER := "res://art/shaders/skin_gold.gdshader"
const GLASS_SHADER := "res://art/shaders/skin_glass.gdshader"
const BODY_SHADER := "res://art/shaders/operator_body.gdshader"
const OP_HOLO_SHADER := "res://art/shaders/operator_hologram.gdshader"
const OP_GOLD_SHADER := "res://art/shaders/operator_gold.gdshader"
const OP_GLASS_SHADER := "res://art/shaders/operator_glass.gdshader"
## Speed (m/s) at which the Run clip's planted feet do not slide; scale the
## clip by move_speed / RUN_SPEED.
const RUN_SPEED := 2.8

static var _materials := {}


## The operator the player is wearing: the equipped one, else the default
## (null only if no operator items exist).
static func equipped() -> CosmeticItem:
	return Cosmetics.equipped_or_default(&"avatar")


static func model_path(item: CosmeticItem) -> String:
	if item and item.params.has("model") and ResourceLoader.exists(String(item.params["model"])):
		return String(item.params["model"])
	return DEFAULT_MODEL


## A new instance of the operator's model with its special materials applied
## and the idle animation playing.
static func instantiate(item: CosmeticItem) -> Node3D:
	var scene := load(model_path(item)) as PackedScene
	var root: Node3D = scene.instantiate()
	apply_materials(root)
	play_idle(root)
	return root


## Gives every surface of an operator model its runtime material: the body
## shader on OpBody (vertex colours), and the hologram / gold / glass shaders
## on FxHolo* / FxGold* / FxGlass*. Glowing accents keep their own material.
static func apply_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if base == null:
				continue
			var special := _operator_material(base)
			if special:
				mi.set_surface_override_material(i, special)


static func _operator_material(base: BaseMaterial3D) -> Material:
	var mat_name := String(base.resource_name)
	var path := ""
	if mat_name == "OpBody":
		path = BODY_SHADER
	elif mat_name.begins_with("FxHolo"):
		path = OP_HOLO_SHADER
	elif mat_name.begins_with("FxGold"):
		path = OP_GOLD_SHADER
	elif mat_name.begins_with("FxGlass"):
		path = OP_GLASS_SHADER
	if path == "":
		return null
	var key := "op|%s|%s|%s" % [path, mat_name, base.albedo_color.to_html()]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(path)
		if path != BODY_SHADER:
			m.set_shader_parameter("shell_color", base.albedo_color)
		if path == OP_HOLO_SHADER:
			m.set_shader_parameter("trim_color", base.albedo_color)
			m.set_shader_parameter("is_trim", mat_name.contains("Accent"))
		_materials[key] = m
	return _materials[key]


## The shader material standing in for a named Fx* material (null if none).
static func special_material(base: BaseMaterial3D) -> Material:
	var mat_name := String(base.resource_name)
	var path := ""
	if mat_name.begins_with("FxHolo"):
		path = HOLO_SHADER
	elif mat_name.begins_with("FxGold"):
		path = GOLD_SHADER
	elif mat_name.begins_with("FxGlass"):
		path = GLASS_SHADER
	if path == "":
		return null
	var key := path + "|" + base.albedo_color.to_html()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(path)
		m.set_shader_parameter("shell_color", base.albedo_color)
		m.set_shader_parameter("trim_color", base.albedo_color.lerp(Color(1.0, 0.25, 0.65), 0.6))
		_materials[key] = m
	return _materials[key]


static func animation_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func _clip(anim: AnimationPlayer, base_name: String) -> String:
	if anim.has_animation(base_name):
		return base_name
	return base_name + "-loop" if anim.has_animation(base_name + "-loop") else ""


static func play_idle(root: Node) -> void:
	var anim := animation_player(root)
	if anim == null:
		return
	var clip := _clip(anim, "Idle")
	if clip != "":
		anim.play(clip)
		# Start somewhere random so several operators never breathe in sync.
		anim.seek(randf() * anim.current_animation_length, true)


## Plays the operator's one-shot flourish, then returns to idle.
static func play_pose(root: Node) -> void:
	var anim := animation_player(root)
	if anim == null or not anim.has_animation("Pose"):
		return
	anim.play("Pose", 0.15)
	var idle := _clip(anim, "Idle")
	if idle != "":
		anim.queue(idle)


## Plays a clip by name ("Run", "AimIdle", "Fire", "Victory", "Wave", ...).
## One-shots return to `then` (default Idle) when they finish; "" holds the last frame.
static func play(root: Node, clip_name: String, then := "Idle", blend := 0.15) -> void:
	var anim := animation_player(root)
	if anim == null:
		return
	var clip := _clip(anim, clip_name.trim_suffix("-loop"))
	if clip == "":
		return
	anim.play(clip, blend)
	var next := _clip(anim, then) if then != "" else ""
	if next != "" and next != clip and anim.get_animation(clip).loop_mode == Animation.LOOP_NONE:
		anim.queue(next)


## The node a held weapon is parented to (null on models without one).
static func weapon_socket(root: Node) -> Node3D:
	return root.find_child("WeaponSocket", true, false) as Node3D


## The node at the centre of the head (+Z = where the face looks).
static func head_socket(root: Node) -> Node3D:
	return root.find_child("HeadSocket", true, false) as Node3D


## Puts a weapon model (origin at its grip, -Z forward) in the operator's
## hands. Hide its first-person arms first (WeaponCosmetics.prepare_preview).
static func hold_weapon(root: Node, weapon_model: Node3D) -> void:
	var socket := weapon_socket(root)
	if socket == null:
		return
	if weapon_model.get_parent():
		weapon_model.get_parent().remove_child(weapon_model)
	socket.add_child(weapon_model)
	weapon_model.transform = Transform3D.IDENTITY
