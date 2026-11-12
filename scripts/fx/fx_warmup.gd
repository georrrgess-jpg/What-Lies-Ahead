class_name FxWarmup
extends Node3D
## Draws every effect and enemy type once (including every cosmetic kill
## effect and tracer style, and each weapon in its equipped cosmetics), right
## in front of the camera, while
## the screen is still faded in from black at level start. The GPU compiles a
## shader the first time a material is drawn; without this, that compile
## happened mid-fight on the first hit, kill, reload or zombie spawn and showed
## up as a hitch. Frees itself after a few frames.

const FRAMES := 4

var _frames := 0


func _init() -> void:
	# Frees itself after a few frames even if the game is paused straight away.
	process_mode = Node.PROCESS_MODE_ALWAYS


## camera: the player's camera. enemies: EnemyData used by this level.
func run(camera: Camera3D, enemies: Array, weapons: Array) -> void:
	var fwd := -camera.global_transform.basis.z
	var at := camera.global_position + fwd * 2.5
	# Everything is parented here, so it all disappears when this node frees.
	var parent := self
	# Particles, flashes, tracers, popups, score text.
	Fx.hit_pop(parent, at, -fwd, true)
	Fx.impact(parent, at, -fwd, Color(0.3, 0.95, 1.0))
	Fx.kill_burst(parent, at)
	Fx.confetti(parent, at)
	Fx.ticket_popup(parent, at, 1234567890)
	Fx.tracer(parent, at - fwd, at + fwd * 6.0, Color(0.3, 0.95, 1.0), 0.05)
	# Every cosmetic kill effect and tracer style (their meshes and materials).
	for it in Cosmetics.items_for(&"kill_effect"):
		KillEffects.play(parent, at, it, false)
	for it in Cosmetics.items_for(&"tracer"):
		TracerStyles.draw(parent, at - fwd, at + fwd * 6.0, 0.05, it)
	var label := Label3D.new()
	label.font = UiKit.display_font()
	label.font_size = 96
	label.text = "HEADSHOT +0123456789 x.%"
	label.outline_size = 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = at
	# One of each enemy, with the hit tint on, so their materials compile too.
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	var i := 0
	for data in enemies:
		var z: Zombie = scene.instantiate()
		z.setup(data, null, 1.0)
		z.warmup_only = true
		z.position = at + camera.global_transform.basis.x * (i - enemies.size() * 0.5) * 0.8 + Vector3.DOWN * 1.0
		parent.add_child(z)
		z.set_physics_process(false)
		z.flash_now()
		i += 1
	# Each weapon's viewmodel wearing the player's cosmetics (finish shaders,
	# arms, charm, sticker) with its hologram reload material, plus the halo,
	# beacon and holo shaders.
	for w in weapons:
		if w.viewmodel == null:
			continue
		var m: Node3D = w.viewmodel.instantiate()
		parent.add_child(m)
		WeaponCosmetics.apply(m, w, Cosmetics.weapon_loadout(w.id))
		m.global_position = at + Vector3.UP * 0.3
		m.scale = Vector3.ONE * 0.2
		for holo in m.find_children("*Holo", "MeshInstance3D", true, false):
			var sm := ShaderMaterial.new()
			sm.shader = load(WeaponView.HOLO_SHADER)
			(holo as MeshInstance3D).material_override = sm
	for shader_path in ["res://art/shaders/bulb_halo.gdshader", "res://art/shaders/beacon.gdshader", "res://art/shaders/portal_swirl.gdshader"]:
		var q := MeshInstance3D.new()
		q.mesh = QuadMesh.new()
		var sm := ShaderMaterial.new()
		sm.shader = load(shader_path)
		q.material_override = sm
		parent.add_child(q)
		q.global_position = at


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()
