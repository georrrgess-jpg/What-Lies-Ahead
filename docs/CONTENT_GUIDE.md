# Content guide: extending What Lies Ahead

Everything below can be added **without editing shared lists**. Content is
discovered by scanning folders at startup (`scripts/autoload/game_data.gd`).

## Folders that are scanned

| Folder | Type | Notes |
| --- | --- | --- |
| `data/weapons/*.tres` | `WeaponData` | Sorted by `sort_order`. `unlock` (Requirement) gates it. |
| `data/enemies/**/*.tres` | `EnemyData` | Use a subfolder per world, e.g. `data/enemies/neon_rooftops/`. |
| `data/worlds/*.tres` | `WorldData` | Sorted by `sort_order`; lists its `LevelData`s. `requirement` gates the world. |
| `data/cosmetics/**/*.tres` | `CosmeticItem` | Skins, finishes, gloves, kill effects, banners, titles... |
| `data/ui/*.tres` | `UiExtension` | Menu pages, HUD widgets, results-screen sections. |

Stable IDs (`id` fields) are saved in player profiles. Never rename one once
it exists.

## Unlocks: `Requirement`

`scripts/data/requirement.gd`. Kinds: `PLAYER_LEVEL`, `LEVEL_CLEARED`,
`WEAPON_RANK` (an empty `target` means "the weapon this item is equipped
on"), `TOTAL_KILLS`, `BEST_SCORE`, `GRANTED`, `CHALLENGE`, plus `all_of` to chain.
`is_met()` and `describe()` ("Reach player level 5") are all most UIs need.

## Profile data

`Profile.section("my_system")` returns a dictionary saved with the profile
(JSON types only). Call `Profile.save_profile()` after changes. Existing
sections: `cosmetics` (equipped, seen), `progression` (xp), `unlocks` (granted).

## Events

`Events` autoload: `run_started(director)`, `enemy_killed(enemy, weapon_id,
headshot, points)`, `wave_cleared(wave, total)`, `run_finished(result)`.
`run_finished` fires once per run, including when a run is abandoned from the
pause menu (`result["abandoned"] == true`). `result` is `RunDirector.result()`.

## Progression and mastery

* `Progression` autoload: `level()`, `xp()`, `level_progress()`, `add_xp()`,
  signal `level_up`. Account XP lives in `Profile.section("progression")`.
* `Mastery` autoload: per-weapon `xp/rank/kills`, `total_kills()`,
  `rewards(weapon_id)` (cosmetics gated on that weapon's rank), `grant()`.
  Ranks (10, in Bronze/Silver/Gold/Diamond/Prismatic tiers) come from the shared
  curve in `data/progression/mastery_curve.tres`, copied into every weapon's
  `rank_xp` at startup, so new weapons need no rank table of their own.
* Account XP rules (per kill, wave, clear, first clear) are in
  `data/progression/rules.tres`; challenges are `.tres` files in
  `data/progression/challenges/` (WEAPON challenges exist once per weapon).

## Cosmetics

* `CosmeticItem` (`scripts/data/cosmetic_item.gd`): `id`, `display_name`,
  `slot`, `weapon_id` (empty = fits all), `rarity`, `requirement`, `colors`,
  `params`.
* Slots in use: `weapon_finish`, `weapon_cell`, `weapon_decal`, `weapon_charm`
  (per weapon) and `gloves`, `kill_effect`, `tracer`, `banner`, `title`,
  `avatar` (global). New slots can be added.
* `Cosmetics` autoload: `items_for(slot, weapon_id)`, `is_owned`, `equip`,
  `equipped`, `weapon_loadout(weapon_id)`, `check_new_unlocks()`.
* Weapon models are recoloured by `scripts/player/weapon_cosmetics.gd` via
  their material names: `Shell`, `Trim`, `Cell`, `GunDark`, `GunSteel`,
  `GunPink`, and arms `Glove`, `GlovePlate`, `Cuff`, `Sleeve`.

## UI extensions (`data/ui/*.tres`, type `UiExtension`)

* `MENU_PAGE`: `script_ref` extends `MenuPage` (signals `back`, `open_page(id)`,
  method `refresh()`). Gets a title-screen button when `show_on_title`.
* `HUD_WIDGET`: a `Control` script with `bind(director: RunDirector, player: Player)`.
  Added full-screen on top of the HUD; position yourself with anchors.
* `RESULTS_SECTION`: a script with `static func build(result: Dictionary) -> Control`.

UI style lives in `UiKit` (`scripts/ui/ui_kit.gd`): palette constants,
`label`, `arcade_label`, `button`, `soft_button`, `box`, `progress`.

## Enemies

* `EnemyData.model_scene`: custom model. It needs an `AnimationPlayer` with
  clips `Idle`, `Walk`, `Run`, `Attack`, `Hit`, `Die` (a `-loop` suffix is
  fine) and the body mesh named `Outfit_<outfit>`. Optional accessory meshes
  `Acc_*` are picked through `accessory_slots`. The easiest route is to copy
  `art/blender/build_zombie.py` (same rig and clips) into your own build script.
* `EnemyData.behaviours`: `EnemyBehaviour` resources (`scripts/enemies/enemy_behaviour.gd`)
  with hooks `on_ready`, `on_physics` (return true to take over movement),
  `on_hit` (return damage to take), `on_attack`, `on_death`, and optional
  `is_winding_up()` so the HUD threat ring warns about it, and `interrupt()`
  (cancel a windup that has not been released yet; called by a cryo freeze or
  a heavy shotgun stagger through `Zombie.interrupt()`). Example:
  `scripts/enemies/behaviours/ranged_spit.gd`.
* `EnemyProjectile.launch(parent, from, target_pos, speed, damage, color, arc, size, shooter)`
  for slow, dodgeable projectiles.
* Per-enemy tuning: `score`, `tickets`, `xp`, `mass`, `flank_degrees`,
  `enrage_radius`, charge settings, `lunge_speed`.

## Weapons

* `WeaponData` holds all tuning, aiming (`ads_*`), reticle style, recoil,
  viewmodel placement and `reload_style` / `reload_script`.
* A viewmodel `.glb` follows the node contract documented at the top of
  `art/blender/build_weapons.py` (Shell, Cell, CellHolo, ArmL/ArmR, Muzzle,
  SightPoint, EjectPoint, VentPoint...).
* Custom reloads: `reload_script` with `func play(view: WeaponView, d: float)`
  using `view.track / at / glow_ramp / holo_build / solidify / burst /
  hide_part / register_part` (see `weapon_view.gd`).

## Levels

A level scene needs: a baked `NavigationRegion3D`; a `Marker3D` in group
`player_spawn`; `Marker3D`s in group `enemy_spawn`; a loadout station (any
scene using `scripts/props/prize_kiosk.gd` with `Zone`, `Body`, optional
`OpenGlow` nodes, e.g. `scenes/props/kiosk.tscn`); an exit portal
(`scenes/props/portal.tscn`); and a `Node` named `RunDirector` with
`scripts/run/run_director.gd`. Give the root `scripts/run/level_environment.gd`
and add a `WorldEnvironment` and `DirectionalLight3D` named `Sun`. Physics
layers: 1 world, 2 player, 3 enemies, 4 triggers, 5 player-only walls.
The easiest start is a generator like `tools/build_prize_pier.gd`. Run
generators **with a renderer** (`xvfb-run -a godot --rendering-driver opengl3
--path . --script res://tools/<generator>.gd`), never `--headless`: the
headless renderer keeps no MultiMesh instance data, so every MultiMesh in the
saved scene would be empty.

`LevelData` sets the scene, wave set, music, ambience, accent colour and
unlock requirement.

## Audio

Add a pack file in `tools/audio_packs/` (see the README there) and run
`python tools/gen_audio.py <pack>`. Name sounds with a prefix.

## Verification tools

* `godot --headless --path . --fixed-fps 60 -- --autoplay=clear --weapon=<id>`:
  bot plays the first level. Add `--level=<level_id>` for other levels.
* `godot --path . -- --shot=out.png [--shot-level=<id>] [--shot-pos=x,y,z --shot-yaw=deg ...]`:
  staged screenshots (see `scripts/dev/screenshot.gd`).
* `godot --path . --script res://tools/preview_model.gd -- out.png <model>`:
  model contact sheet.
