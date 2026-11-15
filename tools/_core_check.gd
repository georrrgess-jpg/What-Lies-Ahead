extends SceneTree
## Scratch: loads every script named on the command line; parse errors print as SCRIPT ERROR.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var s = load(arg)
		print("CHECK %s %s" % [arg, "ok" if s and s.can_instantiate() else "FAILED"])
	quit()
