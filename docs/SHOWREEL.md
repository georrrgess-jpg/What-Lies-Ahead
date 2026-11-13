# The showreel (animated short) and the startup screen

An 88-second trailer made in the engine from the game's real levels, zombies,
operators, weapons, skins and effects. It plays from the title screen (WATCH
TRAILER, or as an attract mode), and renders to a video.

| What | Where |
| --- | --- |
| API for the menu: `available()`, `play(host, finished)`, `attract_delay()` | `scripts/cinematics/showreel.gd` (`Showreel`) |
| The shot list (staging of every shot) and the featured items (ids at the top) | `scripts/cinematics/showreel_shots.gd` |
| Timeline player: sets, cuts, music, skip, hand-back to the menu | `scripts/cinematics/cine_player.gd` (`CinePlayer`) |
| Per-shot toolkit: camera moves (dolly, orbit, follow, spline), whip pans, speed ramps, relighting, focus, flares, actors, kills | `scripts/cinematics/cine_stage.gd` (`CineStage`) |
| First-person weapon without a player: `WeaponView.staged_aim`, `staged_sprint`/`slide`/`mantle`, `staged_gait`, `refit_sight()` | `scripts/player/weapon_view.gd` |
| The Eruption twist on cue: `LavaEruption.erupt_now()`, `strike_at(point)` | `scripts/props/lava_eruption.gd` |
| Lens and colour grade, letterbox, flashes, wipes, title cards (UI kit) | `scripts/cinematics/cine_overlay.gd`, `art/shaders/cine_grade.gdshader`, `art/shaders/cine_wipe.gdshader` |
| The studio set (arsenal, line-up) | `scripts/cinematics/cine_studio.gd` |
| Music: `showreel_trailer` and the startup score `cine_startup` | `tools/audio_packs/showreel.py` (`python3 tools/gen_audio.py showreel`) |
| Start straight into the reel / contact-sheet frames / timings | `scripts/cinematics/showreel_render.gd` (`-- --showreel ...`) |
| Render the video and contact sheet | `tools/render_showreel.sh` |
| Stutter check of a rendered video (repeated frames, hitches, speed jumps per shot) | `tools/video_motion_report.py` |
| Menu hand-back check (headless) | `scripts/cinematics/showreel_probe.gd` |
| Startup screen | `scripts/ui/intro_overlay.gd` (`IntroOverlay`) |

## How it works

* The reel is a list of `CineShot`s (id, set, length, a `build(stage)` method).
  `CinePlayer` lays them end to end and keeps its clock on unscaled time, so
  cuts stay on the music's beat even in slow motion.
* **Sets** are level scenes (scenery only: the `RunDirector` is removed, as on
  the menu backdrop; Boot Camp's comes from `data/tutorial/`) or the
  code-built studio. They load on the engine's loader
  threads and are instantiated on a worker thread four shots ahead, attached at
  their first cut and freed after their last, so at most three are alive.
* Each shot's actors hang off one node that is freed at the cut (effects spawn
  under it). Zombies are the real `Zombie` scene with no target: they never
  chase; the shot moves them and plays their clips. Kills go through
  `Zombie.take_hit`, so death clips, the head pop, confetti, freezes and
  shatters are the game's own; kill-effect cosmetics are played with
  `KillEffects.play`, tracers with `WeaponFx.shot`, beams with `BeamVisual`,
  chains with `LightningBolt`, blasts with `WeaponFx.explosion`, Sparks with
  `SparkField`. Everything is referenced by id, so the reel shows whatever the
  models, maps and effects look like today.
* **Warm-up, so no cut hitches.** Before the first frame the player holds
  black while `FxWarmup` draws one of every enemy, kill effect, tracer,
  projectile and weapon (their shaders compile there), and the heavy shots
  (`CineShot.prebuild`, the list `BUILT_AHEAD`: first-person views, line-ups,
  hordes) are built one per frame, hidden and paused; their cut only shows
  them. A shot's effects on the frame, the grade and the light all go through
  `stage.at(0.0, ...)` (so building it early touches nothing on screen) and
  its set is handed over at the cut (`stage.set_root`). Each level set, once
  instantiated, is drawn twice into a small offscreen view of its own from its
  menu camera before its cut, so its materials compile there and not on the
  cut. A video trims the warm-up frames.
* **Framing on any screen.** Shots are framed for 16:9. On a narrower screen
  the camera keeps the 16:9 width (`CineStage.lens_fov`) and the letterbox bars
  keep the same picture aspect (1920 x 888), so nothing framed to the sides is
  cut off; on a wider one more shows at the sides. Type is clamped inside the
  bars with a margin (`CineOverlay._inside`).
* While it plays, the scene it was started over (the menu) leaves the tree, so
  nothing of it renders or hears input, and the menu theme and ambience pause.
  Ending or skipping (any key, click or button) puts all of it back: the
  current scene, its camera, the music, `Engine.time_scale`.

## The look

* **Grade**: every shot picks a look (`overlay.grade`: dusk, day, night,
  studio, golden) for one full-screen pass of `cine_grade.gdshader` drawn
  over the 3D frame and under the type: lift, gain, contrast, saturation and
  a vignette. The same pass fakes a shallow depth of field
  (`overlay.focus`, `stage.focus_on`: a blur growing away from a point; a
  rack focus is a tween between two points), the smear of a whip pan
  (`stage.whip`) and anamorphic flares pinned to a world point
  (`stage.flare_at`: the low sun, a pair of eyes, an impact). The blurs only
  sample while switched on; each cut resets the lens.
* **Light**: `stage.lighting(ambient, exposure, glow, sun)` relights a level
  set for one shot (a copy of its Environment, restored at the next cut):
  the cold open drops the ambient and the sun so the cast reads as shapes
  against the dusk sky and the bulbs bloom through the game's own glow.
* **Time**: `stage.slowmo(from, to, scale, ramp_in, ramp_out)` is a speed
  ramp: a quick drop into slow motion on an impact, a slow climb out. The
  camera and the titles run on the reel's own (unscaled) clock, so a ramp
  never jolts the camera; only the world slows.
* **Smooth moves**: `stage.spline(keys)` runs the camera through
  `[time, position, look_at]` keys on a Catmull-Rom curve whose tangents are
  scaled by the key spacing, so its speed never jumps at a key (the
  first-person mantle, vault and slide is one such curve). Shakes run at
  4-6 Hz so they read as a jolt at 30 fps, not as frame-to-frame jitter.
* **First person** uses the game's own viewmodel (`WeaponView`): sway, kick,
  the muzzle flash and the weapon's real reload, with gloves on the arms; with
  no player behind it `staged_aim` brings the real sight to the eye on the same
  eye line the game aims along (its reticle lit), and `staged_sprint`,
  `staged_slide`, `staged_mantle` and `staged_gait` drive the movement poses
  and the run bob.
* **Words**: none in the cold open. A few title cards in the kit's sign face
  (`overlay.title_card`: a spaced kicker over a title, fading and drifting in)
  and small spaced captions for place and item names (`overlay.caption`).

## Featured items

The constants at the top of `showreel_shots.gd` pick every featured item by
id: the operator line-up (front row = newest), the action hero and squads,
the kill effects and tracers of the kill shots, the gloves, the arsenal's
animated finishes, the finishes the camera lingers on with their cells, the
charm rigs (weapon, finish, charm, cell, decal) and the sights. Swap an id
there; counts on the cards come from `GameData`.

## Shot list (120 BPM, a bar is 2 s)

Three acts in 88 s: the owner-approved wordless dusk opening and the title;
the ten worlds (each of the five new ones gets its landmark and then its alpha
on a hit) and the whole cast; then the drop into play (kills, sights, Boot Camp
and the moves, a bounty and its Sparks, an alpha), what you make yours (the
arsenal, finishes and the Shop, sights, operators) and the title card.

| Time | Shot | Set | What | Music |
| --- | --- | --- | --- | --- |
| **Act I: cold open (no words)** | | | | |
| 0-6 | open_sunset | Prize Pier | Fade up from black; a low crane past a lamp post toward the Ferris wheel at dusk, a lone tourist shambles across in silhouette; sun flare | pad from silence, sea wind, a distant band organ |
| 6-9 | open_eyes | Prize Pier | Slow push on the tourist's face, pink rim light; its eyes catch cyan light (flare), a slow silent roar; shallow focus | deep heartbeat |
| 9-12 | open_horde | Prize Pier | Ground level, slow motion: feet pass the lens, the focus racks to the horde walking out of the sunset | heartbeat doubles, low swell, a breath |
| 12-16 | title | Prize Pier | Crane up out of the horde to the Ferris wheel; the logo rises in (no slam), dusk grade warms to gold | **low boom** |
| **Ten worlds** | | | | |
| 16-18 | world_neon | Neon Skyline | Rooftops at night, punks below; whip pan out | the beat comes in |
| 18-20 | world_tidal | Tidal Tunnels | Whip in to the shark tank, whip out | whoosh + low tom |
| 20-22 | world_dune | Launch Pad 9 | Whip in, crane up the rocket, whip out | whoosh + low tom |
| 22-24 | world_frost | Summit Lodge | Whip in to the lodge under the aurora, whip out | whoosh + low tom |
| 24-26 | world_mall | Midnight Mall | Whip in; down from the glass dome toward the Moonfall Fountain as Mall Walkers and Flingers come | whoosh + low tom |
| 26-27 | alpha_mall | Midnight Mall | The Night Manager walks at a low lens, name card | boom |
| 27-29 | world_temple | Lost Temple | Rising toward the Jade Idol's carved face at golden hour; explorers and Overgrowns | low tom |
| 29-30 | alpha_temple | Lost Temple | The Idol Keeper | boom |
| 30-32 | world_candy | Candy Works | Low across the factory floor to the colossal gumball machine; Gummy Bears and a Taffy Puller | low tom |
| 32-33 | alpha_candy | Candy Works | The Confectioner | boom |
| 33-35 | world_lava | Lava Lagoon | Mount Kahuna erupts (the Eruption twist): the sky flares, ember bombs drop into their glowing rings among the fire dancers | low tom |
| 35-36 | alpha_lava | Lava Lagoon | Kahuna Krakatoa, the eruption still glowing | boom |
| 36-38 | world_sky | Sky Harbor | Across the hub isle to the airship Cumulus at its mooring; Sky Divers and Balloon Vendors | low tom |
| 38-39 | alpha_sky | Sky Harbor | Captain Cumulus on the dock isle | boom |
| 39-42 | cast_horde | Prize Pier | Twenty kinds of zombie from all ten worlds march at the lens in slow motion; card "N kinds of trouble" | breath: pulse, riser, snare |
| **Act II: the drop, play** | | | | |
| 42-44 | kill_headshot | Prize Pier | Speed ramp to 0.12x into a Neon Tube bolt to the head; the pop in slow motion | **DROP** |
| 44-47 | kill_sweep | Prize Pier | First person (Data Rain carbine, Iron Knuckle gloves): five kills in five kill effects and tracers, then the real reload | |
| 47-49 | ads | Prize Pier | Aim down sights: the cannon comes up to the eye, the Gemcut optic's reticle lights on a far head, the view zooms, a headshot in slow motion | |
| 49-51 | boot_camp | Boot Camp | Up the training midway past its arches as an operator sprints the course; card "Boot Camp" | |
| 51-54 | moves | Boot Camp | First person on one camera curve: mantle onto the crates, vault the barrier, slide under the low sign | whoosh on the slide |
| 54-56 | kill_cryo | Prize Pier | The Cryo Beam freezes three (real `StatusEffects`); they shatter in slow motion | |
| 56-58 | kill_lobber | Neon Skyline | A gumball arcs in, a ring of five blown apart, speed ramp and flare | |
| 58-60 | bounty | Prize Pier | The golden bounty runner bolts and drops to a headshot (Jackpot kill effect); its Sparks fly to the lens and the counter ticks up; card "Bounty" | |
| 60-62 | kill_alpha | Neon Skyline | Captain Lockdown soaks cannon hits, falls to a rail shot in slow motion with the Event Horizon kill effect | |
| **Make it yours** | | | | |
| 62-66 | arsenal | Studio | All 8 weapons on the turntable, one per beat, each in a new animated finish; card "The arsenal" | arp, a soft tom per weapon |
| 66-70 | finishes | Studio | Macro glide along the carbine; four animated finishes with cells and the Ferris wheel charm; card "N cosmetics / Sparks buy them in the Shop" | |
| 70-72 | sights | Studio | The cannon in profile, the sight swaps on each beat (match cuts); whip out | whoosh |
| 72-75 | operators | Studio | Whip in; the 18 operators in two rows (newest in front) strike their poses under pink and cyan rims; card "N operators" low in frame | lift |
| 75-78 | op_action | Prize Pier | Chase camera on Wind-Up Wally running, aiming and firing (Gift Ribbon tracer), Pinata Party kill, slow motion; whip out | whoosh |
| **Act III: title card** | | | | |
| 78-88 | finale | Prize Pier | Three operators hold the line at dusk as the horde comes; crane up and back; logo, feature chips (real counts and the three difficulties), PLAY NOW marquee at 82, fade at 86.4 | **HIT** 78, **HIT** 82 |

The other five alphas are represented by Captain Lockdown, the twists by the
Eruption (the others are lighting changes the grade would hide); the loadout
station stands on Boot Camp's course and the Shop is named on its card.

## Smoothness

`tools/video_motion_report.py` decodes a render small and grey and measures
every pair of frames: the picture change, the camera's motion (phase
correlation on a 4x3 grid of tiles) and what is left after undoing the pan. It
flags repeated frames (`dup`), one-frame camera stops (`freeze`), one-frame
speed spikes or drops (`jump`), lasting speed steps (`jerk`), parts of the
picture that hold still for a frame (`step`) and repeats right after a cut
(`cut-hold`), each with its time and shot, and prints a table per shot.
`tools/render_showreel.sh` runs it on every render. Whip pans, hit flashes and
muzzle flashes show up as `jerk`/`jump`/`step` by design; a `dup`, `freeze` or
`cut-hold` is always a bug.

The movie maker renders each segment from a fresh start; the join keeps
exactly `(to - from) x 30` frames of each, so no frame repeats at a join and
the picture stays on the music's beat to the end (the 72 s render repeated the
last frame of every segment, with its audio, and drifted five frames off the
beat by the end).

## Rendering the video

```bash
tools/render_showreel.sh            # media/what-lies-ahead-showreel.mp4 + ...-sheet.jpg
tools/render_showreel.sh --to 16    # a test of the first 16 s
```

Godot's movie maker (`--write-movie`, `--fixed-fps 30`, OpenGL under xvfb)
renders segments of whole shots into `build/showreel/`; a finished segment is
kept, so the command can be re-run after an interruption (delete the folder
after changing shots). The segments are joined, scaled to 1280x720 and encoded
(H.264 at about 2.2 Mbit/s, AAC), about 24 MB. The software renderer takes
roughly half a minute per second of film.

Contact-sheet frames without a video (fast, low resolution):

```bash
xvfb-run -a godot --rendering-driver opengl3 --path . --fixed-fps 10 --resolution 640x360 \
    --script res://scripts/cinematics/showreel_render.gd -- --showreel --showreel-sheet=/tmp/sheet
```

Add `--showreel-sheet-at=0.2,0.6,0.92` for several frames per shot, and
`--showreel-from=s --showreel-to=s` for a part of the reel.
Timing run (set load times, worst frames, the worst frame at each cut against
the median frame): add `--showreel-report=1` (works headless).
A still at a time from the menu: `-- --shot=x.png --shot-scene=showreel --shot-times=27,41`.

## The startup screen

`IntroOverlay` (about 8 s, then holds): a Spark glows up in the dark with a
soft ring (0-1.4 s); four 0.8 s vignettes on the studio set cut on the score's
low pulses (a zombie, the carbine in Marquee Lights with the Ferris wheel
charm, a Disco Fever kill, three new operators posing), no words; the logo
rises in as a marquee sign with chasing bulbs over the live menu backdrop
(4.6 s), the tagline and the feature counts (from `GameData`) fade in, then
PRESS ANY KEY (7.2 s). The score (`cine_startup`) is the trailer's opening in
miniature: a pad and the distant organ from silence, soft low pulses, the low
boom and a warm chord, three soft plucks under the chips; nothing bright or
sharp. The first key skips to the end state, the next opens the menu. The
vignette models load on threads behind the first second. Frames:
`--shot-scene=intro --shot-times=0.7,1.8,...`.
