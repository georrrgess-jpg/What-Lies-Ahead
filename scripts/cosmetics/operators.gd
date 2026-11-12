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
## FxHolo*, FxGold* and FxGlass* surfaces get shaders here.

const DEFAULT_MODEL := "res://art/models/operator_boardwalk_ranger.glb"
const HOLO_SHADER := "res://art/shaders/skin_hologram.gdshader"
const GOLD_SHADER := "res://art/shaders/skin_gold.gdshader"
const GLASS_SHADER := "res://art/shaders/skin_glass.gdshader"

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


## Swaps the FxHolo / FxGold / FxGlass surfaces for their shaders.
static func apply_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if base == null:
				continue
			var special := special_material(base)
			if special:
				mi.set_surface_override_material(i, special)


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
