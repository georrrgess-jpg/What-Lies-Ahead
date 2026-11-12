# What Lies Ahead

A single-player, first-person arcade zombie survival game made with Godot 4.

Five worlds, each one level: hold the ground around a loadout station through eight
waves, spend tickets between waves, then follow the exit lights to the portal and step
through. Clearing a level unlocks the next world.

| # | World | Level | Setting | New enemies |
| --- | --- | --- | --- | --- |
| 1 | Boardwalk Breakout | Prize Pier | Sunset amusement pier | Tourist Shambler, Lifeguard Runner, Boardwalk Bruiser |
| 2 | Neon Rooftops | Neon Skyline | Rainy rooftops above an arcade city, at night | Neon Punk, Hover Courier, Riot Bruiser |
| 3 | Abyss Aquarium | Tidal Tunnels | After-hours aquarium: glass tunnels, tanks and a kelp atrium | Deep Diver, Mascot Inker, Jelly Head |
| 4 | Dune Spaceport | Launch Pad 9 | Golden-hour desert spaceport around a rocket on its launch mount | Space Cadet, Jetpack Mechanic, Irradiated Hazmat |
| 5 | Frostpeak Resort | Summit Lodge | Twilight ski resort under the aurora | Ski Racer, Yeti, Frozen Tourist |

![Reference art (left) and the game (right)](references/comparison.png)

## Launching

**From the editor (recommended while developing)**

1. Install **Godot 4.7.1** (standard build, not .NET). Any 4.7.x should work.
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
   The first open imports the assets, which takes a few minutes.
3. Press **F5** (Run Project). The game opens with its startup sequence, then the menu.

The project uses the **Compatibility (OpenGL)** renderer, the lightest desktop option.

**From a build**: zipped builds are in [`builds/`](builds/).

| File | Platform | Status |
| --- | --- | --- |
| `WhatLiesAhead-linux-x86_64.zip` | Linux x86_64 | Smoke-tested (see *Verification*) |
| `WhatLiesAhead-windows-x86_64.zip` | Windows x86_64 | Exported, **not run** (no Windows machine here) |

Unzip and run the single executable. On Linux you may need `chmod +x WhatLiesAhead.x86_64`.
The Windows build is unsigned, so SmartScreen may ask for confirmation.

## Controls

| Action | Input |
| --- | --- |
| Move | W A S D |
| Look | Mouse |
| Sprint (forward) | Shift |
| Jump | Space (a short grace period after leaving a ledge, and a buffered press) |
| Slide | C or Ctrl while sprinting (jump out of a slide to keep its speed) |
| Fire | Left mouse button |
| Aim down sights | Right mouse button (hold) |
| Reload | R |
| Switch weapon | 1 / 2, or the mouse wheel |
| Start the next wave early | F |
| At the loadout station: energy top-up / snack heal | E / Q |
| At the loadout station: swap the held weapon | Z / X (or ← / →) |
| Pause | Esc or P |

All of these are Godot InputMap actions (*Project → Project Settings → Input Map*); the
two station swap actions are added at start-up by `scripts/weapons/loadout.gd` if the
project does not define them. **Settings** (main menu or pause menu) has mouse and
aim sensitivity, field of view, reticle style and colour, volumes, camera shake,
flashes, a High/Low graphics preset and fullscreen.

## How a run works

- **Preparation → Wave → Break → … → Extraction**, with **Defeat** reachable from any wave.
- **Two weapons.** You carry a primary and a secondary (chosen in the **Arsenal**). Each
  keeps its own ammo for the whole run. Switching cancels a reload.
- **The loadout station** (the kiosk with the tall beacon; a waypoint points to it during
  breaks) sells an energy top-up for both weapons and one snack heal per break, and swaps
  the held weapon for any unlocked one for free. Every break also gives a small free
  refill, and a weapon that runs completely dry slowly recharges, so you are never left
  helpless.
- After the final wave the portal opens and the exit lights switch on. You must step
  through the portal to clear the level.
- **Score.** Kills score points, multiplied by headshots and by your combo (keep
  killing within about three seconds). Multi-kills, long shots, close calls, wave clears
  and flawless waves add bonuses. Your best score per level is saved and shown on the
  Play page.
- **Reading a fight.** Every enemy attack is telegraphed: a melee swipe winds up and only
  lands in front of the zombie, and ranged and special attacks (sprays, lobbed ink,
  snowballs, leaps, electric charges, rushes) have their own wind-up animation, sound and
  often a ground marker. An orange arc around the reticle warns about anything winding
  up off-screen; a red arc points at whatever just hit you. A headshot during a
  ranged wind-up cancels it, and so do a freeze or a heavy shotgun stagger. Zombies flank
  and spread across routes, and when a squad-mate dies nearby they enrage briefly.
- **World mechanics.** Neon Punks are beaten by closing in (up close they swipe instead
  of spraying); Riot Bruisers block frontal body shots until their shield breaks; Deep
  Divers' helmets shrug off headshots until cracked; Jelly Heads discharge an electric
  ring; Irradiated Hazmats leave a radiation cloud; Summit Lodge has a slippery frozen pond
  and a final-wave whiteout.

## Weapons

| Weapon | Type | Unlock | Notes |
| --- | --- | --- | --- |
| Pulse Pistol | Pistol | Start | Accurate first shot, quick handling |
| Ion Carbine | Carbine | Start | Automatic all-rounder |
| Scatter Blaster | Shotgun | Start | Nine pellets; a heavy volley staggers a zombie out of its wind-up |
| Comet Hand Cannon | Hand cannon | Player level 2 | Three-round burst revolver |
| Arc Coil | Arc thrower | Player level 4 | Chain lightning that locks onto the zombie nearest the crosshair |
| Bumper Lobber | Launcher | Player level 6 | Bouncing gumball bombs with splash; shows its landing arc when aiming |
| Frostbite Cryo Beam | Beam | Player level 8 | Chills, then freezes: frozen zombies cannot attack and take +60% damage |
| Rail Lancer | Railgun | Player level 11 | Charge shot that pierces a line of zombies |

Every weapon has its own model, holographic reload animation, sounds, reticle and
aim-down-sights behaviour. Fire modes are data (`WeaponData` fields for burst, charge,
beam, projectile and splash, pierce, chain, chill/shock and heat), implemented once in
`scripts/player/weapon_controller.gd` and `scripts/weapons/`.

## Progression and cosmetics

- **Player level** (1–50): account XP from kills, waves, clears, first clears and
  challenges. Levels unlock weapons and cosmetics. Shown on the HUD and the Career page.
- **Weapon mastery**: 10 ranks per weapon in Bronze, Silver, Gold, Diamond and Prismatic
  tiers, earned by using that weapon. Ranks unlock mastery camos and badges.
- **Challenges** (Career page): account goals and per-weapon goals (headshots, long
  shots, combos, clean clears…) that pay XP and cosmetics.
- **Locker**: 190 cosmetics in ten categories. Operators (nine characters that also set your
  first-person arms), weapon finishes (including animated shader skins), energy cells,
  decals, charms, gloves, kill effects, tracers, banners and titles. Weapon items are
  equipped per weapon. Everything shows in a live preview; double-click to equip.
- **Results screen**: score count-up with breakdown, mastery XP per weapon, the Career
  card (XP bar, level-ups, challenges completed, new rewards) and your player card.
- Progress is kept whether you win, lose or quit from the pause menu.

## Main menu

The startup sequence (pulse line, rising synthwave sun, the title dropping in letter by
letter, then a portal iris into the menu) plays once per session; any key skips it. The
menu sits over a live, slowly drifting 3D view of the selected world. Pages: **Play**
(world carousel, level details, best score, loadout, Deploy), **Arsenal** (weapon stats,
mastery and the two-slot loadout), **Locker**, **Career** and **Settings**.

## Editing the game data

Everything you would normally tune is a Godot Resource under `data/`. Open a file in the
Inspector, or edit the `.tres` text directly. Content is **discovered by folder**: drop a
new file in and it appears; there is no catalog to edit.

| What | Where |
| --- | --- |
| Weapons (damage, fire rate, magazine, spread, recoil, ADS, fire mode, unlock, viewmodel placement) | `data/weapons/*.tres` |
| Enemies (health, speed, damage, attack timing, behaviours, flanking, outfit and accessories) | `data/enemies/*.tres`, `data/enemies/<world>/*.tres` |
| Waves and the station economy (counts, pacing, banners, prices, heals, refills) | `data/levels/<level>_waves.tres` |
| Level entry (name, scene, waves, music, ambience, menu camera, loading tips, unlock) | `data/levels/<level>.tres` |
| World entry (name, tagline, colours, levels, unlock) | `data/worlds/*.tres` |
| Account XP rules, mastery curve, challenges | `data/progression/` |
| Cosmetics | `data/cosmetics/<category>/*.tres` |
| Menu pages, HUD widgets, results sections | `data/ui/*.tres` |

The field meanings are documented in the scripts in `scripts/data/`.
**[docs/CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md)** describes every extension point:
requirements and unlocks, cosmetics, progression, events, menu pages, HUD widgets,
results sections, enemy behaviours and projectiles, the weapon reload API, the level
contract and audio packs.

IDs such as `pulse_pistol` or `prize_pier` are **stable IDs** used by save files. Change
display names freely, but do not rename an `id` after players have saves.

## Adding another level

1. **Make the scene.** Write a generator like `tools/build_neon_skyline.gd` (or duplicate
   a level scene and rework it). The contract is in the content guide: a baked
   `NavigationRegion3D`, a `player_spawn` marker, `enemy_spawn` markers, a loadout
   station using `scripts/props/prize_kiosk.gd`, an exit portal and a `RunDirector` node.
2. **Make the waves.** Duplicate one of the `data/levels/*_waves.tres` files.
3. **Make the level entry.** Duplicate a `data/levels/<level>.tres`, set a new `id`,
   `scene_path`, `wave_set` and `requirement`.
4. **List it in a world.** Add it to a world's `levels`, or create a new
   `data/worlds/<world>.tres` with a `sort_order` and a `requirement`.

## Project layout

```
project.godot            Godot project (input map, autoloads, renderer)
data/                    Editable game data (see above)
scenes/
  levels/                One scene per level, written by the tools/build_*.gd generators
  player/, enemies/      First-person player; the shared zombie (variant from EnemyData)
  props/                 Loadout stations and portals for each world
  ui/                    main_menu, hud, pause_menu, results
scripts/
  autoload/   profile (save), game_data (folder scan), settings, events, unlocks,
              progression, mastery, cosmetics, sfx, game (scene flow)
  data/       Resource classes (weapons, enemies, waves, levels, worlds, requirements,
              cosmetics, UI extensions)
  player/     player (movement, ADS, jump, slide), weapon_controller (shared combat),
              weapon_view (viewmodel and reload animations), weapon_cosmetics
  weapons/    loadout, fire-mode helpers, status effects, projectiles, beam/arc/rail
              visuals, per-weapon reload scripts, Arsenal page
  enemies/    zombie.gd, EnemyBehaviour base, projectiles, behaviours/ per world
  run/        run_director (run state machine, waves, station economy), score_keeper,
              level environments
  progression/  run tracker, challenges, Career page, HUD widget, results card
  cosmetics/  operators, kill effects, tracers, charms, player card, Locker support
  ui/         HUD, menus, intro, menu backdrop, loading screen, settings, results
  fx/         tracers, particle bursts, effect warm-up
  dev/        automated playtest bot and screenshot tool (inactive in normal play)
art/
  blender/    Blender sources: build_*.py scripts and the .blend files they write
  models/     Exported .glb models used by the game
  textures/   Generated skies and surfaces        shaders/  All game shaders
  fonts/      Lilita One and Baloo 2 (SIL Open Font License, licences included)
audio/        Synthesised sound effects (.wav) and music/ambience loops (.ogg)
tools/        Level generators, texture and audio generators, model previewer
references/   Art reference, in-game screenshot and the side-by-side comparison
builds/       Zipped desktop builds
```

Persistent state lives only in the save file, never in level scenes.

## Saves

Progress is stored in `user://profile.json` (versioned; version 1 saves are migrated):

- Linux: `~/.local/share/godot/app_userdata/What Lies Ahead/profile.json`
- Windows: `%APPDATA%\Godot\app_userdata\What Lies Ahead\profile.json`
- macOS: `~/Library/Application Support/Godot/app_userdata/What Lies Ahead/profile.json`

It holds account XP, per-weapon mastery, challenge progress, owned and equipped
cosmetics, the loadout, best wave, best score and completion per level, and settings. It
is written at every wave boundary, on defeat, on extraction, when you leave a run and
when you equip something. A missing file starts a fresh profile. An unreadable file is
set aside as `profile.json.unreadable-<date>` and a fresh profile is started.

## Art, audio and level pipelines

All art and audio in this repository is original and generated by the scripts below. The
only third-party assets are the two fonts (see *Third-party assets*).

**Models (Blender).** Each script in `art/blender/` builds its models from code, saves an
editable `.blend` next to itself and exports an engine-ready `.glb` to `art/models/`.
They were written for Blender 5.3 and run here through the `bpy` Python module
(`pip install bpy`, then `python art/blender/<script>.py`), or with
`blender --background --python art/blender/<script>.py`.

| Scripts | Builds |
| --- | --- |
| `build_props.py`, `build_kiosk.py`, `build_ferris_wheel.py` | Prize Pier props, kiosk, Ferris wheel |
| `build_weapons.py`, `build_weapons_arsenal.py` | The eight weapon viewmodels with arms |
| `build_zombie.py` | Shared zombie rig, outfits and clips |
| `build_neon_*.py`, `build_aqua_*.py`, `build_dune_*.py`, `build_frost_*.py` | Each world's props, station, scenery and zombies |
| `build_operators.py`, `build_cosmetics.py` | Operators; charms and sticker decals |

In the `.blend` files the *Source* collection holds the parts with live bevel
modifiers, and *Export* holds the baked meshes written to the `.glb`. Naming contracts
the game relies on (`Muzzle`, `SightPoint`, `CharmPoint`, animated part names, clip
names) are described at the top of `build_weapons.py` and `build_zombie.py`.
`art/blender/` has a `.gdignore`, so Godot does not try to import the `.blend` files.

**Textures and audio** (need numpy, Pillow and ffmpeg):

```bash
python tools/gen_textures.py                 # Prize Pier sky and deck
python tools/gen_textures_neon.py            # likewise _aqua, _dune, _frost
python tools/gen_audio.py                    # core sounds and music
python tools/gen_audio.py neon aqua dune frost weapons progression cosmetics   # packs
```

**Levels.** Each level has a generator in `tools/` (`build_prize_pier.gd`,
`build_neon_skyline.gd`, `build_tidal_tunnels.gd`, `build_launch_pad.gd`,
`build_summit_lodge.gd`) that writes its scene and bakes navigation. Run them **with a
renderer**, not `--headless`: the headless renderer keeps no MultiMesh instance data, so
repeated props (lights, railings, trees) would be saved empty.

```bash
xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_neon_skyline.gd
```

(Drop `xvfb-run -a` on a desktop.) A generator **overwrites** its scene. If you prefer to
edit a scene by hand in the editor, stop running its generator (and re-bake navigation
from the `NavigationRegion3D` after moving collision).

**Checking assets.** `tools/preview_model.gd` prints a model's node tree, bounds and clips
and renders a contact sheet; see the comment at the top of the file.

## Automated playtests (developer tools)

The game can play itself through the real input pipeline. These are how the build was
verified; they do nothing unless you pass the arguments after `--`.

```bash
# Full run with a bot on any level, then back to the menu (fast, no window)
godot --headless --fixed-fps 60 --path . -- --autoplay=clear --level=neon_skyline --weapon=ion_carbine --then=menu

godot --headless --fixed-fps 60 --path . -- --autoplay=defeat --then=retry   # lose, press Retry
godot --headless --fixed-fps 60 --path . -- --autoplay=clear --swap           # station swaps every break
godot --headless --fixed-fps 60 --path . -- --autoplay=clear --switch         # slot switching mid-reload
godot --headless --fixed-fps 60 --path . -- --autoplay=route                  # crowd routing test
godot --path . -- --autoplay=pause                                           # pause menu flow (needs a window)
godot --path . --resolution 1672x941 -- --shot=out.png                        # reference-angle screenshot
godot --path . -- --shot=menu.png --shot-scene=locker --shot-locker=avatar     # any menu page
```

Add `--profile=/some/file.json` to keep test runs away from your real save. All options are
listed at the top of `scripts/dev/dev_driver.gd` and `scripts/dev/screenshot.gd`.

## Exporting a build

`export_presets.cfg` defines **Linux** and **Windows Desktop** presets. Install the export
templates (*Editor → Manage Export Templates*), then use *Project → Export*, or:

```bash
godot --headless --path . --export-release "Linux" build/linux/WhatLiesAhead.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/WhatLiesAhead.exe
```

## Third-party assets

| Asset | Licence | Source |
| --- | --- | --- |
| Lilita One (font) | SIL Open Font License 1.1 (`art/fonts/LilitaOne-OFL.txt`) | Google Fonts, `github.com/google/fonts/tree/main/ofl/lilitaone` |
| Baloo 2 (font) | SIL Open Font License 1.1 (`art/fonts/Baloo2-OFL.txt`) | Google Fonts, `github.com/google/fonts/tree/main/ofl/baloo2` |

`references/boardwalk-breakout.png` is the art-direction reference supplied for the project;
it is not used by the game.

## Verification and known limits

What was run for this update, on a headless Linux container (4 vCPU, **no GPU**; rendering
used Mesa llvmpipe, a software rasteriser):

- Project import with Godot 4.7.1: no script errors.
- **Bot clears on every level.** Final regression after all changes, with the two starter
  weapons:

  | Level | Pulse Pistol | Ion Carbine |
  | --- | --- | --- |
  | Prize Pier | Cleared, 64 health left | Cleared, 44 |
  | Neon Skyline | Cleared, 45 | Cleared, 20 |
  | Tidal Tunnels | Lost on wave 6; two re-runs cleared (40, 70) | Cleared, 38 |
  | Launch Pad 9 | Cleared, 86 | Cleared, 54 |
  | Summit Lodge | Cleared, 16 | Lost on wave 6; two re-runs cleared (44, 68) |

  During integration the bot also cleared Neon Skyline with every one of the eight weapons
  (finishing with 20–68 health; the Arc Coil lost one of its three runs), and the new weapons on other worlds (Arc Coil in Tidal
  Tunnels, Bumper Lobber in Launch Pad 9 and Tidal Tunnels, Rail Lancer in Summit Lodge,
  Scatter Blaster in Tidal Tunnels). Those runs drove a balance pass: Neon Punks swipe up
  close instead of spraying point-blank, and the Scatter Blaster and Cryo Beam were buffed.
- **Flows**: defeat → Retry (fresh run state), clear → results → main menu, and the pause
  menu on a virtual display (resume recaptures the mouse; restart and main menu are clean).
- **Saves**: a save interrupted between writing and replacing is recovered from its
  `.tmp` copy; unreadable, partial and missing files start cleanly; version 1 saves migrate.
- **Visual checks** from staged screenshots: every level at player height and from its menu
  camera, the HUD mid-wave, the intro, title, Play, Arsenal, Locker and results screens,
  and (by the agents who built them) every weapon's hip, aim and reload poses, every
  enemy, kill effect, tracer and operator.
- **Code review**: two independent reviews of the merged update (gameplay runtime; menus
  and meta-progression). Their findings were fixed (see the git history).
- **Export smoke test**: see *Exporting a build*; the exported Linux build ran a bot clear
  and a rendered frame.

Not verified, or limited:

- **Real frame rate.** With no GPU here, the software rasteriser runs at a few frames per
  second. Draw calls (about 1,000–1,400) and triangles (150k–480k) per frame are modest,
  but smooth play is untested on real hardware.
- **Audio by ear.** Every sound and music loop is synthesised and was checked for length
  and level only. Nobody has listened to the mix; expect to adjust volumes.
- **Human playtesting.** Difficulty was tuned against a bot with near-perfect aim that never
  dodges projectiles. Results vary from run to run (the same level and weapon can finish
  on 20 or 60 health, and occasionally lose), and the later worlds are meant to be harder.
  Mouse feel, pacing and fairness still need a human pass.
- **Windows build** was exported but never run.
- Blender was driven through its Python module, so models were not touched up by hand.

Simplifications:

- Reload animations are code-driven keyframes on the viewmodel parts, not authored clips.
- UI layouts are built in code by their scripts rather than laid out as scene nodes.
- A zombie that gets wedged is moved back to an entrance by the stall failsafe; this is
  rare but can be seen if you are looking at it.
- Particles use a small script-driven system (`scripts/fx/fx_burst.gd`), because
  `CPUParticles3D` did not render with this renderer and driver; glows are additive halo
  quads for the same reason.
