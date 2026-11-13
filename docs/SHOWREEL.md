# The showreel (animated short) and the startup screen

A 72-second trailer made in the engine from the game's real levels, zombies,
operators, weapons, skins and effects. It plays from the title screen (WATCH
TRAILER, or as an attract mode), and renders to a video.

| What | Where |
| --- | --- |
| API for the menu: `available()`, `play(host, finished)`, `attract_delay()` | `scripts/cinematics/showreel.gd` (`Showreel`) |
| The shot list (staging of every shot) and the featured items (ids at the top) | `scripts/cinematics/showreel_shots.gd` |
| Timeline player: sets, cuts, music, skip, hand-back to the menu | `scripts/cinematics/cine_player.gd` (`CinePlayer`) |
| Per-shot toolkit: camera moves, whip pans, speed ramps, relighting, focus, flares, actors, kills | `scripts/cinematics/cine_stage.gd` (`CineStage`) |
| Lens and colour grade, letterbox, flashes, wipes, title cards (UI kit) | `scripts/cinematics/cine_overlay.gd`, `art/shaders/cine_grade.gdshader`, `art/shaders/cine_wipe.gdshader` |
| The studio set (arsenal, line-up) | `scripts/cinematics/cine_studio.gd` |
| Music: `showreel_trailer` and the startup score `cine_startup` | `tools/audio_packs/showreel.py` (`python3 tools/gen_audio.py showreel`) |
| Start straight into the reel / contact-sheet frames / timings | `scripts/cinematics/showreel_render.gd` (`-- --showreel ...`) |
| Render the video and contact sheet | `tools/render_showreel.sh` |
| Menu hand-back check (headless) | `scripts/cinematics/showreel_probe.gd` |
| Startup screen | `scripts/ui/intro_overlay.gd` (`IntroOverlay`) |

## How it works

* The reel is a list of `CineShot`s (id, set, length, a `build(stage)` method).
  `CinePlayer` lays them end to end and keeps its clock on unscaled time, so
  cuts stay on the music's beat even in slow motion.
* **Sets** are level scenes (scenery only: the `RunDirector` is removed, as on
  the menu backdrop) or the code-built studio. They load on the engine's loader
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
  ramp: a quick drop into slow motion on an impact, a slow climb out.
* **First person** uses the game's own viewmodel (`WeaponView`): sway, kick,
  the muzzle flash and the weapon's real reload, with gloves on the arms.
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

| Time | Shot | Set | What | Music |
| --- | --- | --- | --- | --- |
| **Act I: cold open (no words)** | | | | |
| 0-6 | open_sunset | Prize Pier | Fade up from black; a low crane past a lamp post toward the Ferris wheel at dusk, a lone tourist shambles across in silhouette; sun flare | pad from silence, sea wind, a distant band organ |
| 6-9 | open_eyes | Prize Pier | Slow push on the tourist's face, pink rim light; its eyes catch cyan light (flare), a slow silent roar; shallow focus | deep heartbeat |
| 9-12 | open_horde | Prize Pier | Ground level, slow motion: feet pass the lens, the focus racks to the horde walking out of the sunset | heartbeat doubles, low swell, a breath |
| 12-16 | title | Prize Pier | Crane up out of the horde to the Ferris wheel; the logo rises in (no slam), dusk grade warms to gold | **low boom** |
| **Worlds** | | | | |
| 16-18 | world_neon | Neon Skyline | Rooftops at night, punks below; whip pan out | the beat comes in |
| 18-20 | world_tidal | Tidal Tunnels | Whip in to the shark tank, whip out | whoosh + low tom |
| 20-22 | world_dune | Launch Pad 9 | Whip in, crane up the rocket, whip out | whoosh + low tom |
| 22-24 | world_frost | Summit Lodge | Whip in to the lodge under the aurora | whoosh + low tom |
| **The cast** | | | | |
| 24-26 | cast_yeti | Summit Lodge | The Yeti climbs in and roars at a low lens, speed ramp | boom |
| 26-28 | cast_horde | Prize Pier | Every zombie type marches at the lens in slow motion; card "N kinds of trouble" | breath: pulse, riser, snare |
| **Act II: the drop, kills** | | | | |
| 28-30 | kill_headshot | Prize Pier | Speed ramp to 0.12x into a Neon Tube bolt to the head; the pop in slow motion | **DROP** |
| 30-33 | kill_sweep | Prize Pier | First person (WeaponView, Data Rain carbine, Iron Knuckle gloves): five kills in five kill effects and tracers, then the real reload | |
| 33-35 | kill_cryo | Prize Pier | The Cryo Beam freezes three (real `StatusEffects`); they shatter in slow motion | |
| 35-37 | kill_arc | Prize Pier | Chain lightning jumps through five, slowed | |
| 37-39 | kill_lobber | Neon Skyline | A gumball arcs in, a ring of five blown apart, speed ramp and flare | |
| 39-42 | kill_alpha | Neon Skyline | Captain Lockdown soaks cannon hits, falls to a rail shot in slow motion with the Event Horizon kill effect | |
| **The arsenal and its skins** | | | | |
| 42-46 | arsenal | Studio | All 8 weapons on the turntable, one per beat, each in a new animated finish; the turn carries across the cuts; card "The arsenal" | arp, a soft tom per weapon |
| 46-50 | finishes | Studio | Macro glide along the carbine; the camera lingers a beat-pair on each animated finish (Marquee Lights, Cathedral Glass, Quicksilver, Kaleidoscope) with an animated cell; the Ferris wheel charm turns | |
| 50-52 | charms | Studio | The camera trucks from a spinning saucer charm to the Ferris wheel charm; cells pulse, decals; card "N cosmetics" | |
| 52-54 | sights | Studio | The cannon in profile, the sight swaps on each beat (match cuts); whip out | |
| **Operators** | | | | |
| 54-57 | operators | Studio | Whip in; the 18 operators in two rows (newest in front) strike their poses under pink and cyan rims; card "N operators" | lift |
| 57-60 | op_action | Prize Pier | Chase camera on Wind-Up Wally running, aiming and firing (Gift Ribbon tracer), Pinata Party kill, slow motion; whip out | |
| 60-62 | op_squad | Prize Pier | Whip in; three operators open fire together, low and side-on, slow motion | |
| **Act III: title card** | | | | |
| 62-72 | finale | Prize Pier | Three operators hold the line at dusk as the horde comes; crane up and back; logo, feature chips (real counts), PLAY NOW marquee at 66, fade at 70.4 | **HIT** 62, **HIT** 66 |

Not in the reel (no clip for it yet): slide, mantle and vault; the alpha
stands in for the bosses until they exist.

## Rendering the video

```bash
tools/render_showreel.sh            # media/what-lies-ahead-showreel.mp4 + ...-sheet.jpg
tools/render_showreel.sh --to 16    # a test of the first 16 s
```

Godot's movie maker (`--write-movie`, `--fixed-fps 30`, OpenGL under xvfb)
renders segments of whole shots into `build/showreel/`; a finished segment is
kept, so the command can be re-run after an interruption (delete the folder
after changing shots). The segments are joined, scaled to 1280x720 and encoded
(H.264 at about 2.2 Mbit/s, AAC), about 20 MB. The software renderer takes
roughly half a minute per second of film.

Contact-sheet frames without a video (fast, low resolution):

```bash
xvfb-run -a godot --rendering-driver opengl3 --path . --fixed-fps 10 --resolution 640x360 \
    --script res://scripts/cinematics/showreel_render.gd -- --showreel --showreel-sheet=/tmp/sheet
```

Add `--showreel-sheet-at=0.2,0.6,0.92` for several frames per shot, and
`--showreel-from=s --showreel-to=s` for a part of the reel.
Timing run (set load times, worst frames): add `--showreel-report=1` (works headless).
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
