class_name Showreel
extends RefCounted
## The game's in-engine animated short (trailer): a real-time montage of the
## worlds, zombies, weapons, kills and skins (shot list: docs/SHOWREEL.md,
## staging: ShowreelShots). The title screen offers it when available() is
## true and may run it as an attract mode after attract_delay() idle seconds.
##
## Rendering to a video (tools/render_showreel.sh) runs this script's entry
## point with the user argument --showreel:
##   godot --path . --script res://scripts/cinematics/showreel_render.gd -- --showreel [--showreel-from=s] [--showreel-to=s]

const ATTRACT_DELAY := 75.0


## True when the short can be played.
static func available() -> bool:
	return ResourceLoader.exists("res://audio/music/showreel_trailer.ogg")


## Seconds of idling on the title screen before the menu may start the short
## as an attract mode.
static func attract_delay() -> float:
	return ATTRACT_DELAY


## Plays the short full-screen on top of `host` (any node in the tree). Any
## key skips it. `finished` is called when it ends or is skipped, after the
## scene underneath, its music and input are back.
static func play(host: Node, finished: Callable = Callable()) -> CinePlayer:
	var p := make()
	p.on_finished = finished
	host.get_tree().root.add_child.call_deferred(p)
	return p


## A player loaded with the showreel's shots (not yet in the tree).
static func make() -> CinePlayer:
	var p := CinePlayer.new()
	p.shots = ShowreelShots.build()
	return p


## Total length in seconds.
static func length() -> float:
	var t := 0.0
	for s in ShowreelShots.build():
		t += s.length
	return t
