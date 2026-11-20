extends RefCounted
## Tin Sergeant march stills (a --shot-run script for a level scene): three
## zombies stand 14 m ahead, four soldiers are thrown 4 m out and march on
## them. Saves <shot> from the player's eye (with the "Fall in!" flag planted
## when --shot-ads=1) WAIT seconds after the throw, and <shot>_close.png from
## a low camera beside the squad.
##
##   godot --path . --rendering-driver opengl3 -- --shot=/tmp/m.png --shot-weapon=tin_sergeant \
##       --shot-run=res://scripts/dev/tin_march_shot.gd

const WAIT := 1.7
const SOLDIERS := 4


func run(shot: Node, director: RunDirector) -> void:
	var player := director.get_tree().get_first_node_in_group("player") as Player
	var tree := director.get_tree()
	var fwd := -player.global_transform.basis.z.slide(Vector3.UP).normalized()
	var side := fwd.cross(Vector3.UP)
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for i in 3:
		var z: Zombie = scene.instantiate()
		z.setup(GameData.enemy(&"tourist_shambler"), player, 1.0)
		z.position = player.global_position + fwd * 14.0 + side * (i - 1) * 2.5
		director._enemies_root.add_child(z)
		director._alive.append(z)
		z.speed = 0.0
		z.skip_emerge()
	await tree.physics_frame
	var level := player.get_parent()
	for i in SOLDIERS:
		var from := player.global_position + Vector3.UP * 1.4 + side * (i - 1.5) * 0.4
		TinSoldier._take(level).begin(player.weapons, player.weapons.current, from, fwd * 4.0 + side * (i - 1.5) * 0.6 + Vector3.UP * 3.0)
	if shot.call(&"_arg", "ads", "0") == "1":
		TinSoldier.set_rally(player.weapons, player.global_position + fwd * 9.0)
	var t := 0.0
	while t < WAIT:
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	await RenderingServer.frame_post_draw
	tree.root.get_viewport().get_texture().get_image().save_png(shot.path)
	var squad := TinSoldier.live(player.weapons)
	if squad.is_empty():
		return
	var cam := Camera3D.new()
	cam.fov = 40.0
	level.add_child(cam)
	var at := squad[0].global_position
	cam.look_at_from_position(at + side * 2.2 - fwd * 1.0 + Vector3.UP * 0.6, at + Vector3.UP * 0.3)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	tree.root.get_viewport().get_texture().get_image().save_png(String(shot.path).get_basename() + "_close.png")
