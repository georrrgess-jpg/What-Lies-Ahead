# The trailer (in-engine showreel) and the startup screen

A 56-second trailer (and the score's 2.5 s ring-out on black) made in the engine from the game's real levels, zombies,
alphas, operators, weapons (with their real reloads), skins and effects, cut to
a 120 BPM score (v2: v1 ran 41.6 s at 150 BPM; the owner found it a little short
and fast, so v2 keeps the drive but gives every big point a moment to land: a
card on its hit, a held hero shot, a speed ramp). It plays from the title screen (WATCH TRAILER, or as an
attract mode), and renders to a video.

| What | Where |
| --- | --- |
| API for the menu: `available()`, `play(host, finished)`, `attract_delay()` | `scripts/cinematics/showreel.gd` (`Showreel`) |
| The shot list (staging of every shot) and the featured items (ids at the top) | `scripts/cinematics/showreel_shots.gd` |
| Timeline player: sets, cuts, music, skip, hand-back to the menu | `scripts/cinematics/cine_player.gd` (`CinePlayer`) |
| Per-shot toolkit: camera moves (dolly, orbit, follow, spline), whip pans, speed ramps, relighting, focus, flares, actors, kills | `scripts/cinematics/cine_stage.gd` (`CineStage`) |
| First-person weapon without a player: `WeaponView.staged_aim`, `staged_sprint`/`slide`/`mantle`, `staged_gait`, `refit_sight()`, `play_reload()` + `seek_reload()` (a reload showcase leans the rig in and turns it about the gun, so each reload is seen from its own angle with the arms still running out of frame: `ShowreelShots._showcase`) | `scripts/player/weapon_view.gd` |
| The Ticket Ripper's WINNER pop without damage: `TicketRipperBurst.show_at(parent, at)` | `scripts/weapons/ticket_ripper_burst.gd` |
| The Eruption twist on cue: `LavaEruption.erupt_now()`, `strike_at(point)` | `scripts/props/lava_eruption.gd` |
| Lens and colour grade, letterbox, flashes, fades, backdrop, section cards, title cards, stamps, tags, counters (UI kit) | `scripts/cinematics/cine_overlay.gd`, `art/shaders/cine_grade.gdshader`, `art/shaders/cine_wipe.gdshader` |
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
  chains with `LightningBolt`, blasts with `WeaponFx.explosion`, Arcade Tokens with
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
  cut. Sets too heavy to enter the tree mid-reel (`EARLY_SETS`: Ashfall
  City, whose set-up took a 90 ms frame when it loaded during the Coin-Op
  and aim-down-sights shots) load and warm behind the black
  (`CinePlayer.early_sets`), and every letter of the display face is drawn
  once at each size the cards use (`TYPE_SIZES`, `CineOverlay.warm_type`), so
  no card rasterises its glyphs on its cut. A video trims the warm-up frames.
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
  ramp on every impact: the alphas' roars, the 15 WORLDS stop-hit, the march
  of the cast, the WINNER round on 27.5 (0.18x), the Cryo shatter, the gumball
  blast, the Wrecker's roar, the Last Ride charge, the finale; the aim-down-
  sights shot runs at 0.6x through the half time (35.0-37.0) and the headshot
  drops to 0.15x exactly on 36.0. The camera and the titles run
  on the reel's own (unscaled) clock, so a ramp never jolts the camera, and
  reloads (tweens on the game clock) slow with the world.
* **Cuts**: every cut lands on a beat (0.5 s). The world montage moves at a
  constant speed (linear dollies) with a short white accent on each cut; each
  world's own zombies walk at the lens a few metres in front of it (spots
  checked against the level's floor, so they stand on it and fill the lower
  third). The stop-hit on 17.5 carries the toy shop's push on at a crawl
  under the 15 WORLDS card.
* **First person** uses the game's own viewmodel (`WeaponView`): sway, kick,
  the muzzle flash and the weapon's real reload (`play_reload`; a showcase
  cuts in on its middle with `seek_reload`), with gloves on the arms; a reload
  close-up leans the viewmodel toward the middle of the frame and narrows the
  lens. `staged_aim` brings the real sight to the eye, and `staged_sprint`,
  `staged_slide`, `staged_mantle` and `staged_gait` drive the movement poses.
* **Words**: none in the first eight seconds. Every section lands on a card
  slammed on its hit (`overlay.card`: a dark band wipes across, the title
  punches in with a settling tilt while its band flashes the accent colour and cools,
  a rule wipes out under it; an alpha's epithet sits under its name): 15
  WORLDS, the five alphas, 42 ZOMBIES · 15 ALPHAS (the zombie kinds other
  than the alphas), LOCK AND LOAD, RELOADS,
  ENDLESS, LAST RIDE, MAKE IT YOURS, the operators and Prize Prints (counts
  from `GameData`). Fast type for fast cuts:
  `overlay.stamp` (a big title that slams in in 0.14 s: HEADSHOT), `overlay.tag` (a small kicker and name sliding in low left in
  0.1 s: each world's number and name, each weapon), `overlay.counter` (the
  wave count), `overlay.backdrop` (black under the type), and the game's own
  UI pieces placed on the type layer (`overlay.place`: the capsule machine).

## Featured items

The constants at the top of `showreel_shots.gd` pick every featured item by
id: the fifteen worlds (camera move, their own zombies and where they
stand), the five alphas, the four lunging zombies, the cast of the march, the
Last Ride alpha (Big Bruno), the reloads (Rail Lancer in the dark, the
Scatter Blaster's lock and load, and the four showcases: Lava Lampoon,
T-Minus Six, Coin-Op and Yo-Yo Loco, each with its level, eye, camera angle
and the part of the reload shown), the line-up (Madame Fortuna in the
centre), the finale squad, their guns and finishes, the kill effects, tracers
and gloves, the four weapons of the arsenal and their animated finishes
(Jackpot, Thunderhead, Galaxy and the Mythic Last Light), the sight and the
print. Counts on the cards (worlds, weapons, zombies, alphas, operators,
cosmetics) come from `GameData`.

## Shot list (v2, 120 BPM: a beat is 0.5 s, a bar 2.0 s; 56.0 s and a ring-out)

The music (`showreel_trailer`) is written to these times; the section
boundaries and the bold hits are locked.

| Time | Shot | Set | What | Music |
| --- | --- | --- | --- | --- |
| **Cold open** | | | | |
| 0.0-3.0 | cold_open | Prize Pier | Out of black: a slow push on a tourist's face at dusk, pink rim; its eyes catch cyan light, it starts to roar | drone from silence, wind, the motif on a detuned music box |
| 3.0-5.0 | dark_reload | Prize Pier | Near darkness, first person: the Rail Lancer's capacitor swap, the hologram's cyan glow lighting the hands; the rails slam home and the charge rings snap on at **5.0** | the reload, close; heartbeat sub |
| 5.0-7.0 | lunge_0-3 | Neon Skyline, Tidal Tunnels, Launch Pad 9, Midnight Mall | Four 0.5 s flashes: a zombie of each world runs at the lens out of the dark, lit only by two muzzle flashes; the last one's head pops | riser, a hit per flash |
| 7.0-8.0 | roar | Prize Pier | A Boardwalk Bruiser in silhouette roars, red flare in its eyes; black from **7.5** | reverse swell, **silence 7.5** |
| **8.0-10.0** | title | Prize Pier | **HIT 8.0**: white flash, the logo slams in with the tagline, the pier's lights come up in eight steps, crane toward the Ferris wheel over the horde | **huge impact**, choir chord |
| **Fifteen worlds** | | | | |
| **10.0-17.5** | world_0-14 | each world's level | One world a beat in unlock order (Prize Pier to Toy Shop): a fast push on its landmark with its own zombies walking at the lens; "World 07 · Jungle Expedition" low left | **the groove at 10.0**, an accent per cut |
| **17.5-18.0** | worlds_card | Toy Shop | The push carries on at a crawl (0.15x): **15 WORLDS** card | **stop-hit 17.5** |
| **Alphas** | | | | |
| **18.0-23.0** | alpha_0-4 | Ghost Train, Boomtown, Skull Harbor, Royal Faire, Toy Shop | Ringmaster Rictus, Sheriff Rattlebones, Captain Barnacle, The Black Knight, The Toymaker: a crash push up from a low lens as each roars in slow motion, the frame jolts, the name and epithet ("Champion of the lists") slam in | **hits 18, 19, 20, 21, 22** |
| **23.0-24.0** | cast | Prize Pier | One zombie of every world marching at a low lens in slow motion, two alphas towering behind: **42 ZOMBIES · 15 ALPHAS** | **23.0** brass, rising |
| 24.0-25.5 | lock_load | Prize Pier | In the dark, first person: the Scatter Blaster snaps shut and racks twice, lit by its own glints: **LOCK AND LOAD** | riser |
| **25.5-26.0** | silence | (black) | | **silence 25.5** |
| **The drop** | | | | |
| **26.0-29.0** | ripper | Prize Pier | **DROP**. First person, Ticket Ripper (Jackpot finish): fifteen rounds a second down the lane, three drop, then on **27.5** the golden WINNER round pierces the last two and pops its ticket burst at 0.18x while the lens closes in | **the drop**, **27.5** |
| **29.0-33.0** | reload_0-3 | Lava Lagoon, Launch Pad 9, Neon Skyline, Candy Works | **RELOADS**: four close, lit showcases, each from its own angle (the rig turns about the gun: the Lava Lampoon's lamp cartwheeling, turned to show its flank; the T-Minus Six's gantry, tipped toward the lens; the Coin-Op's coin return, rolled the other way; the Yo-Yo Loco's loop, rolled up); each reload's snap lands near the next cut | an accent on each cut |
| 33.0-35.0 | moves | Boot Camp | First person: a sprint, a vault over the hurdle, a sprint and, on 34.0, a slide under the DUCK! sign | whoosh into 34.0 |
| **35.0-37.0** | ads | Prize Pier | Aim down sights in half time: the Comet cannon's Gemcut optic lights on a far head; **36.0** the head pops at 0.15x, HEADSHOT | **half time**, thud on 36.0 |
| **37.0-40.0** | cryo, lobber, coin_op, parade | Prize Pier, Candy Works, Neon Skyline, Midnight Mall | The Cryo Beam freezes three and they shatter (1 s); a gumball blast throws a ring of five (1 s); Coin-Op FREE PLAY (0.5 s); three kills in three kill effects and tracers (0.5 s) | **37.0** full band |
| **Endless, Last Ride** | | | | |
| **40.0-44.0** | city_wide, city_street | Ashfall City | **ENDLESS**: a crane down over the burning square as the city's horde floods in; street level, WAVE 5 counting to 30, the Wrecker roars in slow motion | **40.0** double-time toms, choir |
| **44.0-46.0** | last_ride | Prize Pier | Blood-red grade, **LAST RIDE**: Big Bruno (The Prize Booth Bully) charges a low lens in slow motion with his pack; "No healing · no checkpoints / Double XP and Arcade Tokens" | **stop-hit 44.0** |
| **Make it yours** | | | | |
| **46.0-50.0** | arsenal, operators, prints | Studio | **MAKE IT YOURS**: four weapons on the turntable, one a beat, in Jackpot, Thunderhead, Galaxy and the Mythic Last Light; the 19 operators posing; Prize Prints: the capsule machine turns and a print lands in a gold burst | **46.0**, arp and bells |
| **Finale** | | | | |
| **50.0-53.0** | finale | Prize Pier | **HIT 50.0**: three operators (Madame Fortuna in the middle) hold the line at dusk, seen from a low lens in front of them that trucks round to their side as a horde of every world charges in slow motion | **biggest hit**, the theme in major |
| **53.0-56.0** | title_end | Prize Pier | **HIT 53.0**: crane up and back over the line; the logo slams in, the feature chips, PLAY NOW; fade to black on **56.0** | **final slam**, ring |
| 56.0-58.5 | ring_out | (black) | The tagline on black while the score rings out | ring-out |

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
tools/render_showreel.sh --to 18    # a test of the first 18 s (through the worlds)
```

Godot's movie maker (`--write-movie`, `--fixed-fps 30`, OpenGL under xvfb)
renders segments of whole shots into `build/showreel/`; a finished segment is
kept, so the command can be re-run after an interruption (delete the folder
after changing shots). The segments are joined, scaled to 1280x720 and encoded
(H.264 at about 2.2 Mbit/s, AAC), about 16 MB for the 58.5 s reel. The software renderer takes
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

`IntroOverlay` (about 8 s, then holds): an Arcade Token glows up in the dark with a
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
