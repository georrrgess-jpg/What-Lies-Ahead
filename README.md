# What Lies Ahead

A single-player, first-person arcade zombie survival game made with Godot 4.

**World 1 — Boardwalk Breakout · Level 1 — Prize Pier.** Pick a starter weapon, hold the
midway around the prize kiosk through eight waves, spend tickets between waves, then follow
the lit boardwalk to the portal and step through.

![Reference art (left) and the game (right)](references/comparison.png)

## Launching

**From the editor (recommended while developing)**

1. Install **Godot 4.7.1** (standard build, not .NET). Any 4.7.x should work.
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
   The first open imports the assets, which takes a minute.
3. Press **F5** (Run Project). The game starts at the main menu.

The project uses the **Compatibility (OpenGL)** renderer, the lightest desktop option.

**From a build** — zipped builds are in [`builds/`](builds/):

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
| Fire | Left mouse button |
| Reload | R |
| Start the next wave early | F |
| Buy energy top-up (at the kiosk) | E |
| Buy snack heal (at the kiosk) | Q |
| Swap weapon (at the kiosk) | 1 / 2 / 3 or mouse wheel |
| Pause | Esc or P |

All of these are Godot InputMap actions (*Project → Project Settings → Input Map*).
Mouse sensitivity, field of view, master/music/effects volume, camera shake, flashes, a
High/Low graphics preset and fullscreen are under **Settings** (main menu or pause menu).

## How a run works

- **Preparation → Wave → Break → … → Extraction**, with **Defeat** reachable from any wave.
- Kills earn **tickets** (run-only). During breaks the **Prize Kiosk** is open: stand next
  to it to buy a full energy top-up, buy one snack heal per break, or swap weapons for free.
- You carry one weapon at a time. Each weapon keeps its own ammo for the whole run, so
  swapping away and back never creates energy.
- Every break gives the held weapon a small free refill. If a weapon runs completely dry it
  slowly recharges on its own, so you are never left helpless.
- After the final wave the portal opens and the exit lights switch on. You must step
  through the portal to clear the level.
- **Mastery** is per weapon and permanent: XP for finishing blows, plus a wave-clear bonus
  for every weapon that scored a kill that wave. Ranks unlock three cosmetic rewards per
  weapon (decal, energy-cell colour, shell finish), equipped in the **Armory**. Progress is
  kept whether you win, lose or quit from the pause menu.

## Editing the game data

Everything you would normally tune is a Godot Resource under `data/`. Open a file in the
Inspector, or edit the `.tres` text directly.

| What | Where |
| --- | --- |
| Weapons (damage, fire rate, magazine, reserve, spread, recoil, reload time, mastery ranks and rewards, viewmodel placement) | `data/weapons/pulse_pistol.tres`, `ion_carbine.tres`, `scatter_blaster.tres` |
| Enemy variants (health, speed, damage, attack timing, tickets, XP, outfit, sounds) | `data/enemies/tourist_shambler.tres`, `lifeguard_runner.tres` |
| Waves for Prize Pier (enemy counts per wave, spawn pacing, speed scale, banners) **and** the kiosk economy (prices, heal amount, break length, free refill, wave XP bonus) | `data/levels/prize_pier_waves.tres` |
| Level entry (name, scene, wave set, unlock requirement) | `data/levels/prize_pier.tres` |
| World entry (name and its list of levels) | `data/worlds/boardwalk_breakout.tres` |
| Catalog (list of worlds, weapons and enemies) | `data/catalog.tres` |

The field meanings are documented in the scripts in `scripts/data/` (`weapon_data.gd`,
`enemy_data.gd`, `wave_data.gd`, `wave_set.gd`, `level_data.gd`, `world_data.gd`).

IDs such as `pulse_pistol` or `prize_pier` are **stable IDs** used by save files. Change
display names freely, but do not rename an `id` after players have saves.

## Adding another level

The catalog is data-driven; no code changes are needed.

1. **Make the scene.** Create `scenes/levels/<your_level>.tscn`. Easiest: duplicate
   `prize_pier.tscn` and rework it. A level scene must contain:
   - a `NavigationRegion3D` with a baked navigation mesh covering the walkable floor
     (static collision on physics layer 1 = "world");
   - one `Marker3D` in the group **`player_spawn`**;
   - several `Marker3D`s in the group **`enemy_spawn`**, placed beyond the main walking loop;
   - an instance of `scenes/props/kiosk.tscn` and one of `scenes/props/portal.tscn`;
   - a plain `Node` with `scripts/run/run_director.gd` attached (it runs the level and
     creates the player and HUD).
   - Optional: give the root `scripts/run/level_environment.gd` so the graphics preset
     applies, and add `scripts/props/exit_light.gd` meshes along the route to the portal.
2. **Make the waves.** Duplicate `data/levels/prize_pier_waves.tres` and edit it.
3. **Make the level entry.** Duplicate `data/levels/prize_pier.tres`; set a new `id`,
   `display_name`, `scene_path` and `wave_set`. To lock it behind another level, set
   `requires_level` to that level's `id` (for example `prize_pier`).
4. **List it.** Add the new level resource to the `levels` array of
   `data/worlds/boardwalk_breakout.tres`. For a new world, create a `WorldData` resource and
   add it to `worlds` in `data/catalog.tres`.

The level then appears on the Play screen, locked until its requirement is cleared. Best
wave and completion are saved per level `id` automatically.

## Project layout

```
project.godot            Godot project (input map, autoloads, renderer)
data/                    Editable game data (see above)
scenes/
  levels/prize_pier.tscn   The level: geometry, navigation, spawn markers, kiosk, portal
  player/player.tscn       First-person player (camera, weapon controller, viewmodel)
  enemies/zombie.tscn      Shared zombie; the variant comes from EnemyData
  props/kiosk.tscn         Prize kiosk     props/portal.tscn   Exit portal
  ui/                      main_menu, hud, pause_menu, results
scripts/
  autoload/   profile (save), game_data (catalog), settings, mastery, sfx, game (scene flow)
  data/       Resource classes for weapons, enemies, waves, levels, worlds
  player/     player.gd, weapon_controller.gd (shared combat), weapon_view.gd, cosmetics
  enemies/    zombie.gd (navigation, avoidance, attacks, stall detection)
  run/        run_director.gd (run state machine, waves, kiosk economy, mastery commits)
  props/      kiosk, portal, exit lights, Ferris wheel
  ui/         HUD, menus, armory, settings, results, shared UiKit theme
  fx/         tracers and particle bursts
  dev/        automated playtest bot and screenshot tool (inactive in normal play)
art/
  blender/    Blender sources: build_*.py scripts and the .blend files they write
  models/     Exported .glb models used by the game
  textures/   Sky panorama and deck planks        shaders/  Ocean and portal shaders
  fonts/      Lilita One and Baloo 2 (SIL Open Font License, licences included)
audio/        Synthesised sound effects (.wav) and loops (.ogg), bus layout
tools/        Generators: level blockout, textures, audio, model previewer
references/   Art reference, in-game screenshot and the side-by-side comparison
builds/       Zipped desktop builds
```

Persistent state lives only in the save file, never in level scenes.

## Saves

Progress is stored in `user://profile.json` (versioned):

- Linux: `~/.local/share/godot/app_userdata/What Lies Ahead/profile.json`
- Windows: `%APPDATA%\Godot\app_userdata\What Lies Ahead\profile.json`
- macOS: `~/Library/Application Support/Godot/app_userdata/What Lies Ahead/profile.json`

It holds per-weapon mastery (XP, kills), equipped cosmetics, best wave and completion per
level, and settings. It is written at every wave boundary, on defeat, on extraction and
when you leave a run. A missing file starts a fresh profile. An unreadable file is set
aside as `profile.json.unreadable-<date>` and a fresh profile is started.

## Art, audio and level pipelines

All art and audio in this repository is original and generated by the scripts below. The
only third-party assets are the two fonts (see *Third-party assets*).

**Models (Blender).** Each script in `art/blender/` builds its models from code, saves an
editable `.blend` next to itself and exports an engine-ready `.glb` to `art/models/`.

```bash
blender --background --python art/blender/build_props.py        # rail, lamp, planter, palm, bench, booth, gates, arcade, coaster, portal arch
blender --background --python art/blender/build_kiosk.py
blender --background --python art/blender/build_ferris_wheel.py
blender --background --python art/blender/build_weapons.py      # three viewmodels with arms
blender --background --python art/blender/build_zombie.py       # one rig, two outfits, six clips
```

They were written for Blender 5.3 (run here through the `bpy` Python module:
`pip install bpy`, then `python art/blender/build_props.py`). In the `.blend` files the
*Source* collection holds the parts with live bevel modifiers, and *Export* holds the baked,
joined meshes that were written to the `.glb`. You can also edit a `.blend` by hand and
export the *Export* collection as glTF. Naming contracts the game relies on are described at
the top of `build_weapons.py` and `build_zombie.py`. `art/blender/` has a `.gdignore`, so
Godot does not try to import the `.blend` files.

**Textures and audio.**

```bash
python tools/gen_textures.py     # sky panorama, deck planks (needs numpy, Pillow)
python tools/gen_audio.py        # all sound effects and both loops (needs numpy, ffmpeg)
```

**Level blockout.** `tools/build_prize_pier.gd` holds the layout of Prize Pier (deck, rails,
entrances, props, spawn markers, lighting) and bakes the navigation mesh:

```bash
godot --headless --path . --script res://tools/build_prize_pier.gd
```

It **overwrites** `scenes/levels/prize_pier.tscn`. Use it to change the layout in bulk; if
you prefer to edit the scene by hand in the editor, stop running the script (and re-bake
navigation from the `NavigationRegion3D` after moving collision). Gameplay collision and
navigation are ordinary Godot nodes in the scene.

**Checking assets.** `tools/preview_model.gd` prints a model's node tree, bounds and clips
and renders a contact sheet; see the comment at the top of the file.

## Automated playtests (developer tools)

The game can play itself through the real input pipeline. These are how the build was
verified; they do nothing unless you pass the arguments after `--`.

```bash
# Full run with a bot, then back to the menu (fast, no window)
godot --headless --fixed-fps 60 --path . -- --autoplay=clear --weapon=ion_carbine --then=menu

godot --headless --fixed-fps 60 --path . -- --autoplay=defeat --then=retry   # lose, press Retry
godot --headless --fixed-fps 60 --path . -- --autoplay=clear --swap           # swap weapon every break
godot --headless --fixed-fps 60 --path . -- --autoplay=route                  # crowd routing test
godot --path . -- --autoplay=pause                                           # pause menu flow (needs a window)
godot --path . --resolution 1672x941 -- --shot=out.png                        # reference-angle screenshot
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

What was run for this handoff, on a headless Linux container (4 vCPU, **no GPU**; rendering
used Mesa llvmpipe, a software rasteriser):

- Project import and scene start-up with Godot 4.7.1, no script errors.
- Bot-played **full clears** with each starter weapon (all 141 zombies killed, portal
  entered, results shown, back to menu), and a clear that swaps weapon every break.
- Bot **defeat**, then **Retry** (new run starts with no tickets, wave 0, full health).
- **Pause menu** on a virtual display: mouse released on pause, recaptured on resume,
  restart and main menu both clean.
- **Persistence**: mastery, level completion and settings read back after a relaunch;
  unreadable, partial and missing save files all start cleanly.
- **Crowd routing**: 16 zombies clumped behind the kiosk split 8/8 between the two lanes and
  all reached the player.
- **Late-wave load** (final two waves, up to 11 zombies alive): scripts under 6 ms and
  physics 1–4 ms per frame; about 850–1,400 draw calls and 240k–490k triangles per frame at
  1920×1080.
- **Export smoke test**: the exported Linux build ran a full bot clear, defeat → retry, a
  rendered frame and a relaunch that read the saved progress.

Not verified, or limited:

- **Real frame rate.** With no GPU here, 1080p ran at 1–2 fps (High) and 5–7 fps (Low) on
  the software rasteriser. That says nothing about a normal graphics card; the draw-call
  and triangle counts above are modest, but smooth 1080p play is untested on real hardware.
- **Audio by ear.** Every sound is synthesised by `tools/gen_audio.py` and was checked for
  length and level only. Nobody has listened to the mix; expect to adjust volumes.
- **Human playtesting.** Difficulty and pacing were tuned against a bot (clears take it
  about 5–7 minutes because it starts waves early; it finishes with 8–100 health depending
  on the run and occasionally dies). A person has not played it, so mouse feel, the 8–12
  minute target and first-run fairness still need a human pass.
- **Windows build** was exported but never run.
- **No Godot or Blender MCP connection** was available. Blender was driven through its
  Python module, so the models were not touched up by hand in the Blender UI.

Placeholders and simplifications:

- Background shops on the beach are plain coloured boxes.
- Reload animations are code-driven tweens on the viewmodel parts (three distinct styles),
  not authored animation clips.
- UI layouts (HUD, menus) are built in code by their scripts rather than laid out as nodes
  in the scene files.
- Models use flat colours with one material per colour; materials are not shared between
  `.glb` files.
- A zombie that gets wedged is moved back to an entrance by the stall failsafe; this is
  rare but can be seen if you are looking at it.
