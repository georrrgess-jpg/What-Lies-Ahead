class_name TutorialShots
extends RefCounted
## Screenshot staging for onboarding (scripts/dev/screenshot.gd hands over):
##   --shot-scene=tutorial --shot-step=<n|id>   Boot Camp at step n, the player posed for it
##                                              (--shot-step=finale: the graduation card)
##   --shot-scene=first_run [--shot-card=<k>]   the welcome flow on the menu (k = 3: the choice)
##   --shot-scene=coach --shot-page=<id>        a page's coach mark (title / play: the guided deploy)
##   --shot-scene=welcome_back                  the returning-player card (staged back pay)
##   --shot-scene=hint                          a hint card over Prize Pier
## --shot-frames=n waits longer before the capture.

## Where the player stands for each step: [feet, yaw degrees, pitch degrees].
const POSES := {
	"look": [Vector3(0, 0.1, 4.0), 38.0, 8.0], "move": [Vector3(0, 0.1, 2.0), 0.0, -8.0],
	"sprint": [Vector3(0, 0.1, -5.0), 0.0, -2.0], "jump": [Vector3(0, 0.1, -24.0), 0.0, -6.0],
	"mantle": [Vector3(0, 0.1, -32.5), 0.0, -4.0], "vault": [Vector3(0, 1.3, -38.5), 0.0, -8.0],
	"slide": [Vector3(0, 0.1, -47.5), 0.0, -2.0], "shoot": [Vector3(0, 0.1, -63.9), 0.0, -2.0],
	"ads": [Vector3(0, 0.1, -63.9), 0.0, 1.5], "headshot": [Vector3(0, 0.1, -63.9), 0.0, 0.0],
	"reload": [Vector3(0, 0.1, -63.9), 6.0, -2.0], "switch": [Vector3(0, 0.1, -63.9), 0.0, -2.0],
	"zombies": [Vector3(4.0, 0.1, -61.0), -90.0, 0.0], "dodge": [Vector3(22.0, 0.1, -40.0), -168.0, 0.0],
	"special": [Vector3(26.0, 0.1, -48.0), -80.0, 0.0], "station": [Vector3(27.0, 0.1, -46.2), 0.0, -6.0],
	"wave": [Vector3(22.0, 0.1, -46.0), -150.0, 0.0], "portal": [Vector3(31.0, 0.1, -36.0), -142.0, -4.0],
}


static func run(shot: Node, kind: String) -> void:
	match kind:
		"tutorial":
			await _tutorial(shot)
		"first_run":
			await shot._wait(10)
			var menu := shot.get_tree().current_scene
			Onboarding.begin_first_run(menu)
			await shot._wait(4)
			var card: int = int(shot._arg("card", "0"))
			if card > 0:
				menu.get_node("FirstRunFlow")._show_card(card)
			await shot._capture(int(shot._arg("frames", "30")))
		"coach":
			await shot._wait(10)
			var menu := shot.get_tree().current_scene
			var page: String = shot._arg("page", "title")
			if page in ["title", "play"]:
				Onboarding.set_guide_step("play")
			else:
				Onboarding._sec()["seen"] = []
			menu._show(page, false)
			await shot._capture(int(shot._arg("frames", "40")))
		"welcome_back":
			await shot._wait(10)
			Profile.section("economy")["legacy"] = {"items": [], "sparks": 1850, "old_level": 12}
			Onboarding.begin_first_run(shot.get_tree().current_scene)
			await shot._capture(int(shot._arg("frames", "30")))
		"hint":
			Game.start_level(&"prize_pier", &"ion_carbine")
			await shot._wait(40)
			HintCard.show_hint(shot.get_tree().current_scene, OnboardingHub.HINTS[&"first_break"][0], OnboardingHub.HINTS[&"first_break"][1])
			await shot._capture(int(shot._arg("frames", "30")))


static func _tutorial(shot: Node) -> void:
	Onboarding.start_tutorial()
	var director: TutorialRun = null
	while director == null or director.course == null:
		await shot.get_tree().process_frame
		director = shot.get_tree().get_first_node_in_group("run_director") as TutorialRun
	await shot._wait(4)
	var course := director.course
	var want: String = shot._arg("step", "0")
	if want == "finale":
		course.finish()
		await shot._capture(int(shot._arg("frames", "40")))
		return
	if want == "all":
		# Every step in one launch: <shot>_<nn>_<id>.png, then the finale.
		for i in course.step_count():
			await _pose(shot, course, i)
			await shot._wait(int(shot._arg("frames", "75")))
			await RenderingServer.frame_post_draw
			var file := String(shot.path).get_basename() + "_%02d_%s.png" % [i, course.current_id()]
			shot.get_viewport().get_texture().get_image().save_png(file)
			print("[shot] saved %s" % file)
		course.finish()
		shot.path = String(shot.path).get_basename() + "_finale.png"
		await shot._capture(40)
		return
	await _pose(shot, course, int(want) if want.is_valid_int() else _index_of(course, want))
	await shot._capture(int(shot._arg("frames", "75")))


static func _pose(shot: Node, course: TutorialCourse, index: int) -> void:
	Input.action_release("aim")
	course.stage(index)
	var pose: Array = POSES[course.current_id()]
	var player := course.player
	player.global_position = pose[0]
	player.velocity = Vector3.ZERO
	player.set_look(deg_to_rad(pose[1]), deg_to_rad(pose[2]))
	if course.current_id() in ["ads", "headshot"]:
		Input.action_press("aim")
	await shot._wait(1)


static func _index_of(course: TutorialCourse, id: String) -> int:
	for i in course.step_count():
		if TutorialCourse.step(i)["id"] == id:
			return i
	return 0
