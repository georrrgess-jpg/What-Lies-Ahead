extends SceneTree
## Charm stress test: hangs every charm on every weapon, shakes the viewmodel
## hard through the hip, sprint and aim poses and through a reload, and
## measures how far any point of the charm gets past the limits WeaponCharm
## promises (the weapon's side, the swing along the barrel, the drop below the
## lug) and how close it comes to the hands and forearms.
##
##   godot --headless --path . --script res://tools/weapon_charm_stress.gd
##
## Prints one line per weapon (the worst charm for each number) and
## "CHARM STRESS OK" or "CHARM STRESS FAILED". The reach it reports must stay
## inside the zone art/blender/audit_weapons.py keeps clear (CHARM_DROP,
## CHARM_SWING). Script mode compiles this file before the autoloads exist,
## so it only uses untyped references to game classes.

const VIEW_SCRIPT := "res://scripts/player/weapon_view.gd"
const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"
const CHARM_DIR := "res://data/cosmetics/charms"
const FRAMES := 300
const STANDOFF := 0.018
## The zone the model audit keeps clear of weapon parts.
const ZONE_DROP := 0.115
const ZONE_SWING := 0.07
## Real thickness of the gloves and sleeves the capsule stands in for.
const ARM_BODY := 0.062


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var charms := []
	for file in DirAccess.get_files_at(CHARM_DIR):
		if file.ends_with(".tres"):
			charms.append(load(CHARM_DIR + "/" + file))
	var failed := false
	for w in root.get_node("GameData").weapons():
		var worst := {"side": 0.0, "swing": 0.0, "drop": 0.0, "arm": 1.0, "side_charm": "", "arm_charm": ""}
		for charm in charms:
			_shake(w, charm, worst)
		var ok: bool = worst.side <= 0.0005 and worst.swing <= ZONE_SWING and worst.drop <= ZONE_DROP and worst.arm >= ARM_BODY
		failed = failed or not ok
		print("[charm] %-16s through side %.1f mm (%s)  swing %.0f mm  drop %.0f mm  nearest arm axis %.0f mm (%s)  %s" % [
			w.id, worst.side * 1000.0, worst.side_charm, worst.swing * 1000.0, worst.drop * 1000.0, worst.arm * 1000.0, worst.arm_charm,
			"ok" if ok else "FAIL"])
	print("CHARM STRESS FAILED" if failed else "CHARM STRESS OK")
	quit()


func _shake(w, charm, worst: Dictionary) -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var view: Node3D = load(VIEW_SCRIPT).new()
	rig.add_child(view)
	view.show_weapon(w)
	view.set_process(false)
	var model: Node3D = view.model
	var loadout: Dictionary = root.get_node("Cosmetics").weapon_loadout(w.id)
	loadout["charm"] = charm
	load(COSMETICS_SCRIPT).apply(model, w, loadout)
	var swing: Node3D = model.find_child("WeaponCharm", true, false)
	var anchor: Node3D = model.find_child("CharmPoint", true, false)
	if swing == null or anchor == null:
		rig.free()
		return
	swing.set_process(false)
	var mesh_node: MeshInstance3D = swing.get_child(0)
	var points := _sample(mesh_node.mesh)
	# A turning part (WeaponCharm.add_spinner) is measured where it is each frame.
	var spinner: MeshInstance3D = mesh_node.get_child(0) if mesh_node.get_child_count() > 0 else null
	var spin_points := _sample(spinner.mesh) if spinner else PackedVector3Array()
	var arms := []
	for side in ["L", "R"]:
		arms.append([model.find_child("Arm" + side, true, false), model.find_child("Elbow" + side, true, false)])
	var out: Vector3 = swing._out
	var holder: Node3D = view._holder
	var tween: Tween = null
	for f in FRAMES:
		var t := f / 60.0
		var base_pos: Vector3 = w.view_position
		var base_rot: Vector3 = w.view_rotation_degrees
		if f >= 100 and f < 160:
			base_pos += Vector3(-0.07, -0.06, 0.03)
			base_rot += Vector3(-14.0, 26.0, 16.0)
		elif f >= 160 and f < 200:
			base_pos = -view._eye_local
			base_rot = Vector3.ZERO
		if f == 200:
			view.play_reload(w, 1.5)
			tween = view._reload_tween
			tween.pause()
		if tween and f > 200:
			tween.custom_step(1.0 / 60.0)
		var amp := 1.0 if f < 200 else 0.35
		holder.position = base_pos + Vector3(sin(t * 19.0) * 0.07, sin(t * 23.0) * 0.05, sin(t * 13.0) * 0.05) * amp
		holder.rotation_degrees = base_rot + Vector3(sin(t * 17.0) * 16.0, sin(t * 11.0) * 28.0, sin(t * 14.0) * 34.0) * amp
		swing._process(1.0 / 60.0)
		var to_model := model.global_transform.affine_inverse()
		var ring: Vector3 = to_model * swing.global_position
		var xf: Transform3D = to_model * mesh_node.global_transform
		var all := points.duplicate()
		for p in spin_points:
			all.append(spinner.transform * p)
		for p in all:
			var q := xf * p - ring
			var side := -(q.dot(out) + STANDOFF)
			if side > worst.side:
				worst.side = side
				worst.side_charm = String(charm.id)
			worst.swing = maxf(worst.swing, absf(q.z))
			worst.drop = maxf(worst.drop, -q.y)
		for pair in arms:
			if pair[0] == null or pair[1] == null or not pair[0].is_visible_in_tree():
				continue
			var a: Vector3 = to_model * pair[0].global_position
			var b: Vector3 = a + (to_model * pair[1].global_position - a) * 2.0
			var ab := b - a
			for p in all:
				var v := xf * p
				var k := clampf((v - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var dist := v.distance_to(a + ab * k)
				if dist < worst.arm:
					worst.arm = dist
					worst.arm_charm = String(charm.id)
	rig.free()


func _sample(mesh: Mesh) -> PackedVector3Array:
	var points := PackedVector3Array()
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 9):
			points.append(verts[i])
	return points
