class_name CineShot
extends RefCounted
## One shot of a cinematic: which set it plays on, how long it lasts and the
## callable that stages it (`build.call(stage: CineStage)`).

## Short name (contact sheets, logs, --shot-time).
var id := ""
## A level id (its scene is the set) or "studio" (CineStudio).
var set_id := ""
var length := 2.0
var build: Callable
## Filled in by CinePlayer: when the shot starts on the timeline.
var start := 0.0
## Keeps the object `build` belongs to alive (a Callable does not).
var source: RefCounted


static func make(shot_id: String, on_set: String, seconds: float, staging: Callable) -> CineShot:
	var s := CineShot.new()
	s.id = shot_id
	s.set_id = on_set
	s.length = seconds
	s.build = staging
	s.source = staging.get_object() as RefCounted
	return s
