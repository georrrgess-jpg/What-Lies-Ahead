class_name Showreel
extends RefCounted
## The game's in-engine animated short (trailer): a real-time montage of the
## worlds, zombies, weapons, kills and skins. The title screen offers it when
## available() is true and may run it as an attract mode when left idle.


## True when the short can be played.
static func available() -> bool:
	return false


## Plays the short full-screen on top of `host` (any node in the tree). Any
## key skips it. `finished` is called when it ends or is skipped.
static func play(_host: Node, finished: Callable = Callable()) -> void:
	if finished.is_valid():
		finished.call()
