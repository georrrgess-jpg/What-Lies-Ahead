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
	# The level's impact marks (made now, not on the first shot) and their shader.
	ImpactMarks.warm_up(get_parent(), parent, at, -fwd)
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
	# One more, frozen (the hit-tint overlay above and the frost overlay are both overlays).
	if not enemies.is_empty():
		var frozen: Zombie = scene.instantiate()
		frozen.setup(enemies[0], null, 1.0)
		frozen.warmup_only = true
		frozen.position = at + Vector3.DOWN * 1.0
		parent.add_child(frozen)
		frozen.set_physics_process(false)
		_frost_look(frozen)
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
	# Projectiles in flight (ball, band and trail materials).
	for w in weapons:
		if w.projectile_speed > 0.0:
			WeaponProjectile.warm_up(parent, at + Vector3.DOWN * 0.3, w)
	_hidden_view_materials(camera, parent, at)
	# A muzzle-flash light: an omni light adds a lighting pass to everything it
	# touches, which is a different shader variant on this renderer.
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	parent.add_child(light)
	light.global_position = at + fwd * -1.0
	for shader_path in ["res://art/shaders/bulb_halo.gdshader", "res://art/shaders/beacon.gdshader", "res://art/shaders/portal_swirl.gdshader"]:
		var q := MeshInstance3D.new()
		q.mesh = QuadMesh.new()
		var sm := ShaderMaterial.new()
		sm.shader = load(shader_path)
		q.material_override = sm
		parent.add_child(q)
		q.global_position = at


## The frozen and chilled look on a zombie: the frost overlay on its skinned
## meshes and the ice crystal shell (see StatusEffects).
func _frost_look(z: Zombie) -> void:
	var overlay := ShaderMaterial.new()
	overlay.shader = load(StatusEffects.FROST_SHADER)
	overlay.set_shader_parameter("amount", 1.0)
	for mi in z.model_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = overlay
	var crystals := MeshInstance3D.new()
	crystals.mesh = StatusEffects._crystal_shell()
	crystals.material_override = StatusEffects._crystal_mat()
	z.add_child(crystals)


## Materials on the first-person view that start hidden (muzzle flash quads,
## lens glints) are drawn once on a small quad, since a hidden node is never
## drawn and so never compiled.
func _hidden_view_materials(camera: Camera3D, parent: Node3D, at: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	for g in camera.find_children("*", "GeometryInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi == null or mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var q := MeshInstance3D.new()
		q.mesh = quad
		q.material_override = mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
		parent.add_child(q)
		q.global_position = at


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()
