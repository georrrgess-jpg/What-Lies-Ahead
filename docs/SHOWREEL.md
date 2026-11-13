# The showreel (animated short) and the startup screen

A 70-second trailer made in the engine from the game's real levels, zombies,
operators, weapons, skins and effects. It plays from the title screen (WATCH
TRAILER, or as an attract mode), and renders to a video.

| What | Where |
| --- | --- |
| API for the menu: `available()`, `play(host, finished)`, `attract_delay()` | `scripts/cinematics/showreel.gd` (`Showreel`) |
| The shot list (staging of every shot) | `scripts/cinematics/showreel_shots.gd` |
| Timeline player: sets, cuts, music, skip, hand-back to the menu | `scripts/cinematics/cine_player.gd` (`CinePlayer`) |
| Per-shot toolkit: camera moves, slow motion, actors, kills, effects | `scripts/cinematics/cine_stage.gd` (`CineStage`) |
| Letterbox, flashes, wipes, iris, kinetic type (UI kit) | `scripts/cinematics/cine_overlay.gd`, `art/shaders/cine_wipe.gdshader` |
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

## Shot list (120 BPM, a bar is 2 s)

| Time | Shot | Set | What | Music |
| --- | --- | --- | --- | --- |
| **Act I: cold open** | | | | |
| 0.0-3.5 | open_pier | Prize Pier | Low dolly along the sunset boardwalk, two tourists shamble; "THE PIER WAS QUIET." | drone, heartbeat |
| 3.5-6.0 | open_eyes | Prize Pier | Push in on a tourist's face; a cyan glint in the eyes, it roars | Spark chime at 5.0 |
| 6.0-8.0 | open_spark | Prize Pier | Ground-level shot of the horde; a Spark bursts out of a head and flies at the lens; white flash | reverse swell |
| 8.0-10.0 | title | Prize Pier | Logo slams in, shake; crane up over zombies walking at camera | **HIT** |
| **World tour** | | | | |
| 10-12 | world_pier | Prize Pier | Ferris wheel, name card BOARDWALK BREAKOUT | tom + crash on every cut |
| 12-14 | world_neon | Neon Skyline | Rooftops at night, punks below; NEON ROOFTOPS | |
| 14-16 | world_tidal | Tidal Tunnels | The kelp atrium and shark tank; ABYSS AQUARIUM | |
| 16-18 | world_dune | Launch Pad 9 | Crane up the rocket on its mount; DUNE SPACEPORT | |
| 18-20 | world_frost | Summit Lodge | The lodge under the aurora; FROSTPEAK RESORT | |
| **The cast** | | | | |
| 20-22 | cast_yeti | Summit Lodge | The Yeti climbs in (Emerge) and roars, low angle, shake | hits |
| 22-24 | cast_bruiser | Prize Pier | Tracking shot on the Boardwalk Bruiser in front of the ferris wheel | riser |
| 24-26 | cast_horde | Prize Pier | All 15 zombie types march at camera in slow motion; "15 KINDS OF TROUBLE" | snare roll |
| **Act II: the drop, kills** | | | | |
| 26-28 | kill_headshot | Prize Pier | Close side shot, slow motion: a pistol bolt, the head pops into confetti; HEADSHOT! | **DROP** |
| 28-30 | kill_sweep | Prize Pier | First person with the Ion Carbine: a sweep drops five, each in a different kill effect (hearts, pixel, firework, coins, neon ring); MULTI-KILL x5 | |
| 30-32 | kill_cryo | Prize Pier | The Cryo Beam freezes three (real `StatusEffects`), they shatter; FREEZE / SHATTER! | |
| 32-34 | kill_arc | Prize Pier | Chain lightning jumps through five; CHAIN LIGHTNING | |
| 34-36 | kill_rail | Neon Skyline | Rail Lancer charges and pierces a line of four, slow motion; PIERCE | |
| 36-38 | kill_lobber | Neon Skyline | A gumball arcs in and blows a ring of five apart; BOOM! | |
| 38-40 | kill_alpha | Neon Skyline | Captain Lockdown, the Neon Skyline alpha, soaks cannon hits, falls to a rail shot in slow motion with a firework kill effect; ALPHA DOWN! | |
| **The arsenal** | | | | |
| 40-44 | arsenal | Studio | Wipe; all 8 weapons on the turntable, one per beat, each in an animated/showcase finish with its name | tom run |
| 44-46 | skins | Studio | Ion Carbine close-up, a charm swinging; the finish flips every 8th note through wireframe, marble, the mastery camos (gold, diamond, prismatic) and more; "N COSMETICS" (real count) | |
| 46-48 | sights | Studio | Comet Cannon in profile, the sight flips: holo ring, heart, long scope | |
| **Operators** | | | | |
| 48-51 | operators | Studio | Wipe; the nine operators strike their Pose in a line, dolly across | |
| 51-54 | op_action | Prize Pier | Chase camera on GL1TCH running (Run-loop) with a Synthwave carbine, stops, aims (AimIdle) and fires (Fire) at a zombie; pixel kill | |
| 54-56 | op_victory | Prize Pier | Victory, Wave and Pose from three operators, confetti | |
| **Sparks and progression** | | | | |
| 56-58 | sparks | Prize Pier | Five pops by the loadout station, Sparks fly into the lens, the counter ticks up; "EVERY ZOMBIE STOLE A SPARK. TAKE IT BACK." | |
| 58-62 | progress | Studio | Midway Maestro on the plinth; LEVEL UP, RANK UP, NEW UNLOCK, CHALLENGE COMPLETE cards on the beat with their real stings | |
| **Act III: title card** | | | | |
| 62-70 | finale | Prize Pier | Flash; three operators hold the line against the horde, the camera cranes out to the sunset; logo, feature chips (real counts), PLAY NOW marquee at 66, fade at 68.6 | **HIT** 62, **HIT** 66 |

Not in the reel (no clip for it yet): slide, mantle and vault, and the reload
flourishes; the alpha stands in for the bosses until they exist.

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

Timing run (set load times, worst frames): add `--showreel-report=1` (works headless).
A still at a time from the menu: `-- --shot=x.png --shot-scene=showreel --shot-times=27,41`.

## The startup screen

`IntroOverlay` (about 8 s, then holds): a Spark ignites in the dark (0-1.4 s);
four 0.8 s vignettes on the studio set cut on the score's hits (a zombie roars,
a galaxy-skinned carbine spins, a headshot pops into a firework, three
operators pose) with a kinetic word each; the logo slams in as a marquee sign
with chasing bulbs over the live menu backdrop (4.6 s), the tagline and the
feature counts (from `GameData`) pop in, then PRESS ANY KEY (7.2 s). The first
key skips to that end state, the next opens the menu. The vignette models load
on threads behind the opening sting. Frames: `--shot-scene=intro --shot-times=0.7,1.8,...`.
