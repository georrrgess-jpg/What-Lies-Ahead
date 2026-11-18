# The trailer (in-engine showreel) and the startup screen

A 41.6-second trailer (and a 1.6 s ring-out on black) made in the engine from the game's real levels, zombies,
alphas, operators, weapons (with their real reloads), skins and effects, cut to
a 150 BPM score. It plays from the title screen (WATCH TRAILER, or as an
attract mode), and renders to a video.

| What | Where |
| --- | --- |
| API for the menu: `available()`, `play(host, finished)`, `attract_delay()` | `scripts/cinematics/showreel.gd` (`Showreel`) |
| The shot list (staging of every shot) and the featured items (ids at the top) | `scripts/cinematics/showreel_shots.gd` |
| Timeline player: sets, cuts, music, skip, hand-back to the menu | `scripts/cinematics/cine_player.gd` (`CinePlayer`) |
| Per-shot toolkit: camera moves (dolly, orbit, follow, spline), whip pans, speed ramps, relighting, focus, flares, actors, kills | `scripts/cinematics/cine_stage.gd` (`CineStage`) |
| First-person weapon without a player: `WeaponView.staged_aim`, `staged_sprint`/`slide`/`mantle`, `staged_gait`, `refit_sight()`, `play_reload()` + `seek_reload()` | `scripts/player/weapon_view.gd` |
| The Ticket Ripper's WINNER pop without damage: `TicketRipperBurst.show_at(parent, at)` | `scripts/weapons/ticket_ripper_burst.gd` |
| The Eruption twist on cue: `LavaEruption.erupt_now()`, `strike_at(point)` | `scripts/props/lava_eruption.gd` |
| Lens and colour grade, letterbox, flashes, fades, backdrop, title cards, stamps, tags, counters (UI kit) | `scripts/cinematics/cine_overlay.gd`, `art/shaders/cine_grade.gdshader`, `art/shaders/cine_wipe.gdshader` |
| The studio set (arsenal, line-up, prints) | `scripts/cinematics/cine_studio.gd` |
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
  code-built studio. They load on the engine's loader threads and are
  instantiated on a worker thread four shots ahead, and for every shot that
  starts within the next 3.2 s (`LOOKAHEAD_SECONDS`, so a run of one-beat
  cuts across fifteen worlds is loaded in time); a set is attached at its
  first cut and freed after its last.
* Each shot's actors hang off one node that is freed at the cut (effects spawn
  under it). Zombies are the real `Zombie` scene with no target: they never
  chase; the shot moves them and plays their clips, and they show from
  their first frame (`Zombie.skip_emerge`). Kills go through
  `Zombie.take_hit`, so death clips, the head pop, confetti, freezes and
  shatters are the game's own; kill-effect cosmetics are played with
  `KillEffects.play`, tracers with `WeaponFx.shot`, beams with `BeamVisual`,
  chains with `LightningBolt`, blasts with `WeaponFx.explosion`, Sparks with
  `SparkField`. Everything is referenced by id, so the reel shows whatever the
  models, maps and effects look like today.
* **Warm-up, so no cut hitches.** Before the first frame the player holds
  black while `FxWarmup` draws one of every enemy, kill effect, tracer,
  projectile and weapon (their shaders compile there), and the heavy shots
  (`CineShot.prebuild`, the list `BUILT_AHEAD`: nearly every shot of this
  reel) are built one per frame, hidden and paused; their cut only shows
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
  studio, golden, and for this reel dark, ember and blood) for one
  full-screen pass of `cine_grade.gdshader` drawn over the 3D frame and under
  the type: lift, gain, contrast, saturation and a vignette. *Dark* crushes
  the cold open so a muzzle flash or a hologram lights the frame; *ember* is
  Ashfall City's hot orange; *blood* is Last Ride's red. The same pass fakes a
  shallow depth of field (`overlay.focus`, `stage.focus_on`), the smear of a
  whip pan (`stage.whip`) and anamorphic flares pinned to a world point
  (`stage.flare_at`: the low sun, a pair of eyes, a blast). Each cut resets the
  lens.
* **Light**: `stage.lighting(ambient, exposure, glow, sun)` relights a level
  set for one shot (restored at the next cut): the cold open drops the
  ambient to near black; the title brings the glow up in eight steps on the
  16ths after the slam, so the pier's bulbs snap on. Shots add their own
  lights: the muzzle flash that lights each lunging zombie, the cyan glow of a
  hologram reload on the hands (pinned to the lens), pink and cyan rims on the
  alphas and the line-up.
* **Time**: `stage.slowmo(from, to, scale, ramp_in, ramp_out)` is a speed
  ramp on every impact: the WINNER round, the Cryo shatter, the gumball
  blast, the Last Ride charge, the finale; the headshot through the sight
  drops to 0.2x exactly on the 22.0 half-time. The camera and the titles run
  on the reel's own (unscaled) clock, so a ramp never jolts the camera, and
  reloads (tweens on the game clock) slow with the world.
* **Cuts**: every cut lands on a beat (0.4 s). The world montage moves at a
  constant speed (linear dollies) with a short white accent on each cut, and
  the last four carry the "15 worlds" title across their cuts
  (`overlay.stamp(..., pop = false)`).
* **First person** uses the game's own viewmodel (`WeaponView`): sway, kick,
  the muzzle flash and the weapon's real reload (`play_reload`; a showcase
  cuts in on its middle with `seek_reload`), with gloves on the arms; a reload
  close-up leans the viewmodel toward the middle of the frame and narrows the
  lens. `staged_aim` brings the real sight to the eye, and `staged_sprint`,
  `staged_slide`, `staged_mantle` and `staged_gait` drive the movement poses.
* **Words**: none in the first six seconds. Fast type for fast cuts:
  `overlay.stamp` (a big title that slams in in 0.14 s: alpha names, Endless,
  Last Ride), `overlay.tag` (a small kicker and name sliding in low left in
  0.1 s: each world's number and name, each weapon), `overlay.counter` (the
  wave count), `overlay.backdrop` (black under the type), and the game's own
  UI pieces placed on the type layer (`overlay.place`: the capsule machine).

## Featured items

The constants at the top of `showreel_shots.gd` pick every featured item by
id: the fifteen worlds (camera move and their own zombies), the four alphas,
the four lunging zombies, the reloads (Rail Lancer in the dark; Ticket
Ripper, Lava Lampoon, T-Minus Six and Coin-Op in the drop), the line-up
(Madame Fortuna in the centre), the finale squad and their guns, the kill
effects, tracers and gloves, the eight weapons of the arsenal and their
animated Legendary finishes (Jackpot, Ghost Train, Treasure Map, Multiball,
Marquee Lights, Thunderhead, Galaxy) and the Mythic Last Light, the sight and
the print. Counts on the cards (worlds, weapons, zombies, alphas, operators,
cosmetics) come from `GameData`.

## Shot list (150 BPM: a beat is 0.4 s, a bar 1.6 s; 41.6 s and a ring-out)

The music (`showreel_trailer`) is written to these times; the section
boundaries and the bold hits are locked.

| Time | Shot | Set | What | Music |
| --- | --- | --- | --- | --- |
| **Cold open** | | | | |
| 0.0-1.6 | cold_open | Prize Pier | Out of black: a slow push on a tourist's face at dusk, pink rim; its eyes catch cyan light, it starts to roar | drone from silence, sea wind, the band organ detuned |
| 1.6-3.2 | dark_reload | Prize Pier | Near darkness, first person: the Rail Lancer's capacitor swap, the hologram's cyan glow lighting the hands; the charge rings snap on | the reload, close; heartbeat sub |
| 3.2-4.8 | lunge_0-3 | Neon Skyline, Tidal Tunnels, Launch Pad 9, Midnight Mall | Four 0.4 s flashes: a zombie of each world runs at the lens out of the dark, lit only by two muzzle flashes; the last one's head pops | riser, pulse doubles |
| 4.8-6.0 | roar | Prize Pier | A Boardwalk Bruiser in silhouette lifts its head and roars, red flare in its eyes; sinks to black | suck-back, a breath of silence |
| **6.0-8.0** | title | Prize Pier | **HIT 6.0**: white flash, the logo slams in with the tagline, the pier's lights come up in steps, crane toward the Ferris wheel over the horde | **big impact**, choir chord |
| **Fifteen worlds** | | | | |
| **8.0-14.0** | world_0-14 | each world's level | One world a beat in unlock order (Prize Pier to Toy Shop): a fast push on its landmark (the Ferris wheel, the shark tank, the rocket, the lodge, the Moonfall fountain, the Jade Idol, the gumball machine, the erupting volcano, the airship Cumulus, the Ghost Train, the mine-train loop, the Barnacle Queen, the toy castle, the toy shop) with its own zombies walking in; "World 07 · Jungle Expedition" low left; "15 worlds" over the last four | **the groove at 8.0**, an accent per cut |
| **Alphas** | | | | |
| **14.0-17.2** | alpha_0-3 | Ghost Train, Boomtown, Skull Harbor, Toy Shop | Ringmaster Rictus, Sheriff Rattlebones, Captain Barnacle, The Toymaker: a low lens pushing in as each roars, the frame jolts, the name slams in | **hits 14.0, 14.8, 15.6, 16.4** |
| **17.2-17.6** | lock_load | (black) | "Lock and load" on black | **cut-out** |
| **The drop: combat** | | | | |
| **17.6-19.2** | ripper | Prize Pier | **DROP**. First person, Ticket Ripper (Jackpot finish): 15 rounds a second through a pack, three drop, then the golden WINNER round pierces the last two and pops its ticket burst and WINNER! sign in slow motion | the drop |
| 19.2-20.0 | reload_lava | Lava Lagoon | Close on the Lava Lampoon's reload at dusk, in slow motion: the lamp lifts out on its hologram ring and cartwheels | |
| 20.0-20.8 | moves | Boot Camp | First person: out of a vault into a sprint and a slide under the DUCK! sign | whoosh |
| 20.8-21.6 | cryo | Prize Pier | The Cryo Beam freezes three; they shatter in slow motion | |
| 21.6-22.8 | ads | Prize Pier | Aim down sights: the Comet cannon's Gemcut optic lights on a far head; **22.0** the head pops at 0.2x | **slow motion 22.0-22.8** |
| 22.8-23.6 | reload_tminus | Launch Pad 9 | Close on the T-Minus Six's reload: rockets slide down the hologram gantry, the countdown, the pod flares | |
| 23.6-24.4 | lobber | Candy Works | A gumball arcs into a ring of five; the blast throws them apart in slow motion | |
| 24.4-25.6 | coin_op | Neon Skyline | First person, Coin-Op at night: a spray, a headshot pays FREE PLAY +4 TOKENS (ka-ching), then the coin-return reload | |
| 25.6-26.4 | parade | Midnight Mall | Three kills in three kill effects (Confetti Pop, Disco Fever, Pinata Party) and three tracers as the camera trucks past | |
| 26.4-27.2 | horde | Prize Pier | The horde charges the lens at a run, low at dusk | |
| **Endless, Last Ride** | | | | |
| **27.2-28.8** | city_wide | Ashfall City | A crane down over the burning square as the city's horde (Riot Shields, Tunnel Crawlers...) floods in; "Endless · Ashfall City" | **hit 27.2**, toms double |
| 28.8-30.4 | city_street | Ashfall City | Street level: runners and a Firebug at the lens, WAVE 5 counting to 30, the Wrecker roaring behind | rising choir |
| **30.4-32.0** | last_ride | Prize Pier | Blood-red grade: the Black Knight charges a low lens in slow motion with his knights; "Last Ride · the hardest difficulty", "No healing · no checkpoints / Double XP and Sparks" | **stop-hit 30.4** |
| **Make it yours** | | | | |
| **32.0-33.6** | arsenal | Studio | Eight weapons on the turntable, one a half beat, each in an animated Legendary (and the Mythic Last Light) finish, its name and the weapon count low left; "Make it yours" | **32.0**, a sparkle per beat |
| 33.6-34.4 | operators | Studio | The 19 operators posing in two rows, Madame Fortuna in her aura in the centre | |
| 34.4-35.2 | prints | Studio | Prize Prints: the capsule machine turns a Legendary capsule, a print lands on the plinth in a gold burst; the cosmetic count | |
| **Finale** | | | | |
| **35.2-41.6** | finale | Prize Pier | **HIT 35.2**: three operators (Madame Fortuna in the middle) hold the line at dusk as a horde of every world charges; slow motion, kill effects, crane up and back. **HIT 38.4**: the logo slams in, the feature chips (worlds, weapons, zombies, alphas, Endless, operators, Last Ride), PLAY NOW; fade to black on **41.6** | the full theme, final slam |
| 41.6-43.2 | ring_out | (black) | The tagline fades on black while the score rings out | ring-out |

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
tools/render_showreel.sh --to 14    # a test of the first 14 s (through the worlds)
```

Godot's movie maker (`--write-movie`, `--fixed-fps 30`, OpenGL under xvfb)
renders segments of whole shots into `build/showreel/`; a finished segment is
kept, so the command can be re-run after an interruption (delete the folder
after changing shots). The segments are joined, scaled to 1280x720 and encoded
(H.264 at about 2.2 Mbit/s, AAC), about 12 MB for the 41.6 s reel. The software renderer takes
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
