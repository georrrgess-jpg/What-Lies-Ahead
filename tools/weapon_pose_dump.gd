extends SceneTree
## Samples every weapon's reload animation and writes where each part of the
## viewmodel is at each sample, for the intersection audit
## (art/blender/audit_weapons.py):
##
##   godot --headless --path . --script res://tools/weapon_pose_dump.gd -- <out.json> [--samples=25]
##
## out.json: {weapon_id: {"times": [...], "parts": {node: [[12 floats of the
## node's transform in model space (Godot axes), visible 0/1], ...]}}}
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const VIEW_SCRIPT := "res://scripts/player/weapon_view.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out_path := ""
	var samples := 25
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--samples="):
			samples = int(a.trim_prefix("--samples="))
		elif out_path == "":
			out_path = a
	var result := {}
	for w in root.get_node("GameData").weapons():
		var view: Node3D = load(VIEW_SCRIPT).new()
		root.add_child(view)
		view.show_weapon(w)
		view.set_process(false)
		var model: Node3D = view.model
		view.play_reload(w, 1.0)
		var tween: Tween = view._reload_tween
		tween.pause()
		var nodes := model.find_children("*", "MeshInstance3D", true, false)
		var parts := {}
		var times := []
		for i in samples + 1:
			if i > 0:
				tween.custom_step(1.0 / samples)
			times.append(float(i) / samples)
			for n in nodes:
				var mi := n as MeshInstance3D
				if mi.get_parent().name == "WeaponCharm" or mi.name.begins_with("@"):
					continue
				var xf := Transform3D.IDENTITY
				var shown := true
				var p: Node = mi
				while p and p != model:
					xf = (p as Node3D).transform * xf
					shown = shown and (p as Node3D).visible
					p = p.get_parent()
				var row := [xf.basis.x.x, xf.basis.x.y, xf.basis.x.z, xf.basis.y.x, xf.basis.y.y, xf.basis.y.z,
					xf.basis.z.x, xf.basis.z.y, xf.basis.z.z, xf.origin.x, xf.origin.y, xf.origin.z, 1 if shown else 0]
				if not parts.has(String(mi.name)):
					parts[String(mi.name)] = []
				parts[String(mi.name)].append(row)
		result[String(w.id)] = {"times": times, "parts": parts}
		view.queue_free()
		await process_frame
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("[weapon_pose_dump] wrote ", out_path)
	quit()
