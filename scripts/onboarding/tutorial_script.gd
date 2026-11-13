class_name TutorialScript
extends RefCounted
## What Boot Camp says and asks, step by step: the checklist name, the
## objective, the keys to show and the guide's lines. The course
## (TutorialCourse) owns the logic of each step, keyed by `id`.
##
## Keys are input actions (shown with their first bound key) or one of the
## glyph tokens "WASD", "MOUSE", "LMB", "RMB", "WHEEL".
##
## The guide is BOLT, the midway's tin-plated barker-bot: loud, upbeat and
## very proud of the shooting gallery.

const GUIDE_NAME := "BOLT"
const GUIDE_ROLE := "Boot Camp barker-bot"

const SECTIONS := ["MOVES", "SHOOTING GALLERY", "LIVE FIRE"]

const STEPS := [
	{"id": "look", "section": 0, "title": "Look around", "objective": "Look straight at the three balloons to pop them.",
		"keys": [["MOUSE", "Look"]],
		"lines": ["Step right up, recruit! I'm BOLT, and this is Boot Camp.", "First trick: look around with the mouse. Stare at a balloon and it pops. Science!"]},
	{"id": "move", "section": 0, "title": "Walk", "objective": "Walk onto the glowing pad.",
		"keys": [["WASD", "Move"]],
		"lines": ["Lovely eyeballs. Now walk onto the glowing pad."]},
	{"id": "sprint", "section": 0, "title": "Sprint", "objective": "Sprint down the lane to the next pad.",
		"keys": [["sprint", "Hold to sprint"], ["WASD", "Move"]],
		"lines": ["Zombies shuffle. You should not. Hold Shift and sprint to the next pad!"]},
	{"id": "jump", "section": 0, "title": "Jump", "objective": "Jump over the hurdle.",
		"keys": [["jump", "Jump"]],
		"lines": ["Hurdle! Hop it. Mind the paint, it's fresh."]},
	{"id": "mantle", "section": 0, "title": "Climb", "objective": "Climb onto the crates: push toward them and jump.",
		"keys": [["jump", "Jump at a ledge"]],
		"lines": ["Crates! Walk at them and jump: you'll climb right up."]},
	{"id": "vault", "section": 0, "title": "Vault", "objective": "Run at the thin barrier and jump to vault it.",
		"keys": [["jump", "Jump at a run"]],
		"lines": ["Too thin to stand on, that one. Run at it and jump: you'll vault clean over."]},
	{"id": "slide", "section": 0, "title": "Slide", "objective": "Sprint, then slide under the low sign.",
		"keys": [["sprint", "Sprint"], ["slide", "Slide"]],
		"lines": ["Low sign ahead! Sprint, then press C to slide under. Very stylish. Very low."]},
	{"id": "shoot", "section": 1, "title": "Shoot", "objective": "Pop the five tin targets.",
		"keys": [["LMB", "Fire"]],
		"lines": ["Welcome to my shooting gallery! Click to fire. Pop all five tins."]},
	{"id": "ads", "section": 1, "title": "Aim down sights", "objective": "Hold aim and hit the far target twice.",
		"keys": [["RMB", "Hold to aim"], ["LMB", "Fire"]],
		"lines": ["See the big one at the back? Hold right mouse to aim down your sights. Steady... steady..."]},
	{"id": "headshot", "section": 1, "title": "Headshots", "objective": "Hit the three zombie cut-outs in the head.",
		"keys": [["RMB", "Aim"], ["LMB", "Fire"]],
		"lines": ["Zombie cut-outs! Go for the head: headshots score extra and shake loose bonus Sparks."]},
	{"id": "reload", "section": 1, "title": "Reload", "objective": "You are nearly empty: reload.",
		"keys": [["reload", "Reload"]],
		"lines": ["Running dry! Press R to reload. Never wait for the click."]},
	{"id": "switch", "section": 1, "title": "Switch weapon", "objective": "Switch to your sidearm and pop a target with it.",
		"keys": [["weapon_2", "Sidearm"], ["weapon_1", "Primary"], ["WHEEL", "Flip"]],
		"lines": ["You carry two weapons. Press 2 for the pistol and pop a tin with it. 1 brings the carbine back."]},
	{"id": "zombies", "section": 2, "title": "First zombies", "objective": "Go through the gate and pop the three zombies.",
		"keys": [["LMB", "Fire"], ["RMB", "Aim"]],
		"lines": ["Gate's open! Those are real zombies. Slow ones. I asked nicely.", "Every one carries a stolen Spark: pop it and the Spark is yours."]},
	{"id": "dodge", "section": 2, "title": "Dodge a charge", "objective": "The Bruiser roars, then charges: step aside and pop it.",
		"keys": [["WASD", "Sidestep"], ["sprint", "Sprint"]],
		"lines": ["Uh-oh. A Bruiser. When it roars, it charges in a straight line: sidestep, then pop it!"]},
	{"id": "special", "section": 2, "title": "Ranged special", "objective": "The Mascot Inker spits ink from range: use cover and pop it.",
		"keys": [["WASD", "Use cover"], ["LMB", "Fire"]],
		"lines": ["A Mascot Inker! It winds up and spits ink from afar. Break its line with a crate, then pop it."]},
	{"id": "station", "section": 2, "title": "Loadout station", "objective": "At the station: buy energy, a snack and an overshield, and swap a weapon.",
		"keys": [["interact", "Energy"], ["interact_alt", "Snack"], ["buy_overshield", "Overshield"], ["kiosk_next", "Swap"]],
		"lines": ["The Loadout Station! Between waves it sells energy, snacks and shields for tickets.", "Here's 600 tickets, on the house. Go shopping!"]},
	{"id": "wave", "section": 2, "title": "Mini wave", "objective": "Survive the mini wave.",
		"keys": [["LMB", "Fire"], ["reload", "Reload"]],
		"lines": ["Final exam: a mini wave! Keep moving, keep popping."]},
	{"id": "portal", "section": 2, "title": "Extract", "objective": "Follow the lights to the portal.",
		"keys": [["WASD", "Move"]],
		"lines": ["Wave cleared! In a real run that opens the portal. Follow the lights and step through!"]},
]

## Said when a step is done (one at random).
const CHEERS := ["Nailed it!", "Ding ding ding!", "Like a natural!", "Bravo, recruit!", "Textbook!", "The crowd goes mild!"]

const LINE_HURT := "Ooh, close one! Health is on the house in Boot Camp."
const LINE_NO_SPRINT := "That was a stroll! Hold Shift on the way. Go again, I'll wait."
const LINE_HIP_FIRE := "From the hip? Bold. Hold right mouse to aim, then fire."
const LINE_BODY_SHOT := "Higher! The head ring, recruit."
const LINE_SECTION_SKIPPED := "Skipping ahead? Fine by me. Show-off."
const LINE_SWAP_NONE := "Only one weapon to swap to? Level up and the rack fills up."
const LINE_DODGED := "Olé! Nice footwork."
const LINE_DONE := "You're a natural. Prize Pier needs you. Go get those Sparks back!"
