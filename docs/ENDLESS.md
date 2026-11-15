# Endless mode

Endless is a survival mode on its own map, **Ashfall City** (`data/endless/endless_city.tres`,
`scenes/levels/endless_city.tscn`): a burnt-out, abandoned city at dusk under ash and smoke.
The waves never run out and scale up; the run ends when the player falls. The city is split
into **districts** behind locked **gates**: the player pays a district's price in tickets
(the in-run currency) at one of its gates to open it for the rest of the run. Each district
opened widens the map, wakes its entrances and adds its own zombies to the spawn pool. Endless
is open from player level 1.

This page is the contract between the systems that make up the mode. Ids listed here are
fixed: saves, data and scenes refer to them.

## Data

* `LevelData.endless: EndlessRules` (null for story levels). Endless levels live in
  `data/endless/`, belong to no world and have no wave set. `GameData.endless_levels()` lists
  them; `GameData.level(id)` finds them.
* `EndlessRules`: `districts` (start district first), `base_enemies`, `boss_id`, `boss_every`.
* `EndlessDistrict`: `id`, `display_name`, `blurb`, `price` (tickets, 0 = open at start),
  `enemies` (join the pool when open), `accent_color`.

| District id | Name | Price (tickets, tunable) | Adds |
| --- | --- | --- | --- |
| `ashfall_square` | Ashfall Square (start: loadout station) | 0 | `city_shambler`, `city_runner`, `city_bruiser` |
| `precinct` | Precinct 9 | 600 | `riot_shield` |
| `metro` | Metro Line | 1000 | `tunnel_crawler` |
| `market` | Neon Market | 1400 | `firebug` |
| `tower` | Broadcast Tower | 1800 | more `city_bruiser`; the boss's lair |

Boss: `the_wrecker`, every `boss_every` (10) waves.

## Records and unlocks

`EndlessRecords` (profile section `"endless"`): `best_wave`, `best_score`, `best_by_difficulty`,
`runs`, `opened` (districts opened at least once). Requirement kinds:

* `ENDLESS_WAVE` (21): best Endless wave >= `amount`. "Reach wave 10 in Endless".
* `ENDLESS_DISTRICT` (22): district `target` opened at least once. "Open Metro Line in Endless".

Rewards: the city camos (weapon finishes, `fin_city_*`), the Endless primary weapon
(`hubcap_boomerang`, reach wave 10) and the **Mythic** finish (`CosmeticItem.Rarity.MYTHIC`,
reach wave 30). Mythic is the rarity above Legendary; it is earned, never sold.

## The map's scene contract

| What | How |
| --- | --- |
| Player spawn | one Marker3D in group `player_spawn`, in the start district |
| Loadout station | the usual `PrizeKiosk` (group `kiosk`) in the start district; no exit portal |
| Entrances | Marker3D in group `enemy_spawn` with meta `district` (StringName): at least 3 per district, 4 in the start district, out of the player's sight lines like every other map |
| Gates | `EndlessGate` nodes (`scripts/endless/endless_gate.gd`): `district` = the district it opens; children `Frame`, `Door`, `Blocker` (StaticBody3D), `Zone` (Area3D, both sides), `NavLink*` (NavigationLink3D, disabled). A district may have several gates; paying at any opens all of them |
| District areas | Area3D in group `endless_district_area`, meta `district`: boxes covering each district (the HUD names the district the player walks into; the spawn planner knows where the player is) |
| Features | Marker3D in group `endless_feature`, meta `kind` and `district`: `trap_fire`, `trap_shock`, `supply_drop`. The director builds the feature at the marker |
| Navigation | one NavigationRegion3D baked **with every gate shut**; every district's island kept (drop only small junk islands); the gates' NavLinks join the islands once opened |

## Sounds (names are fixed; tools/audio_packs/endless.py)

Music: `city_endless_loop`, `city_endless_final` (boss waves); ambience `city_ambience`;
`city_fire_crackle` (positional loop for burning wrecks). Effects: `end_gate_open`,
`end_gate_denied`, `end_gate_sting` (a district opens), `end_district_enter`,
`end_wave_horn` (wave start), `end_supply_incoming`, `end_supply_land`, `end_trap_ready`,
`end_trap_fire`, `end_trap_shock`, `end_boss_siren`, `end_new_best`.

## How a run plays (code: `scripts/endless/`, `RunDirector`)

`RunDirector` runs an endless level with an `EndlessDirector` child (`endless`): there is no
wave list, portal, checkpoint or continue. `total_waves()` is 0 (the HUD shows "WAVE 14" with
no "of N"). Preparation, then wave, break, wave... with the loadout station open in every
break (prices from `EndlessRules.economy`, a `WaveSet` whose wave list stays empty). The run
ends when the player falls: the tickets left are cashed into score, and
`EndlessRecords.record(result)` saves runs, best score, best wave (overall and per difficulty)
and districts opened. Best wave and districts are also noted the moment they happen, so their
unlocks land mid-run (Progression collects them at once).

**Waves** (`EndlessWaves`, deterministic per wave number): every `boss_every`-th (10th) wave is
the boss's (`the_wrecker`, kind `finale`: the alpha with its escorts and reinforcements, the
`city_endless_final` loop); every 5th is a **HORDE** (all entrances, 1.3x size, a surge);
waves 1-4 are standard, standard, rush, standard; the rest cycle standard, rush, siege, bounty,
ranged, standard, ambush, rush. A wave's zombies are split by role (regular, fast, heavy,
special = the open districts' own) by its kind's mix; a role with nothing open hands its share
to the regulars, heavies join from wave 3.

**Scaling** (`EndlessRules`, all tunable in `data/endless/endless_city.tres`), before the
difficulty's own multipliers:

| | wave 1 | wave 5 | wave 10 | wave 15 | wave 20 | wave 30 | cap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| zombies (standard wave) | 10 | 14 | 20 | 25 | 31 | 42 | 50 |
| alive at once | 7 | 8 | 10 | 12 | 14 | 17 | 18 (`crowd_max`, the director's CROWD_LIMIT) |
| spawn interval (s) | 2.0 | 1.8 | 1.55 | 1.3 | 1.05 | 0.85 | 0.85 |
| health | x1.0 | x1.12 | x1.27 | x1.42 | x1.5 | x1.65 | x2.0 (+3%/wave to 15, +1.5% after) |
| damage | x1.0 | x1.04 | x1.09 | x1.14 | x1.19 | x1.29 | x1.3 |
| speed | x1.0 | x1.03 | x1.07 | x1.11 | x1.15 | x1.15 | x1.15 |
| kill tickets | x1.0 | x1.08 | x1.18 | x1.28 | x1.38 | x1.5 | x1.5 |

Heavies (`EnemyData.heavy`: bruisers, riot shields) take half the health and damage growth:
they are already the tanks. A district's heavy joins the heavies' share of a wave, its other
enemies the specials' share. The boss has its own curve: its data health (The Wrecker: 3400) x `boss_health` (difficulty) x
(0.85 + 0.45 per earlier visit): 2890 on wave 10, 4420 on 20, 5950 on 30 (Standard). Crowd, speed and health all flatten, so late waves press with numbers and tempo, never
with bullet sponges. Breaks are 20 s (28 s before a boss), skippable as usual.

**Districts and gates** (`EndlessGate`): standing in a gate's `Zone` shows the HUD prompt
"HOLD E · OPEN PRECINCT 9 · 500" (red, with what is missing, when short). Holding interact for
0.5 s pays; short of tickets the door shakes with `end_gate_denied`. Paying opens every gate of
the district (its `open_style`: shutter rolls up, slide, topple; a kit door with
`play_open()`, `CityGateDoor`, animates itself), removes the blockers, enables
the NavLinks, wakes its `enemy_spawn` markers (`SpawnPlanner.set_points`), adds its enemies to
the pool and shows the district banner (`end_gate_sting`). The planner prefers the entrances of
the district the player stands in (`endless_district_area`, +2.5 score), and far entrances
cost points as on every map, so pressure follows the player through the city.

**Features** (built at `endless_feature` markers): `trap_fire` / `trap_shock` (`EndlessTrap`):
hold interact to pay `trap_price` (250); it burns or shocks every zombie inside its radius
(marker meta `radius`, default 4.5 m) for `trap_seconds` (15), then recharges for
`trap_cooldown` (40). Fire: 20 x wave health per 0.3 s; shock: 55 x wave health per 0.75 s plus
an interrupt; heavies take 60%. It never hurts the player. The kit's `city_trap_fire.glb` /
`city_trap_shock.glb` are used when present (flames, the kit's `CityFire`, on `Burner0-3`; arcs from
`Spark0-3`; the sign over `Console`); a crowd of five shamblers in an armed fire trap is gone
in about 3 s. `supply_drop` (`EndlessSupply`): after every 5th
wave a crate parachutes onto a drop marker in an open district (the player's own if it has
one); walking into it fills both weapons, heals 50 and pays 150 + 10 per wave tickets. A HUD
marker follows it.

**UI**: the Play page's last carousel slot is ENDLESS (`EndlessCard`): best wave and score,
best on the chosen difficulty, districts opened, the districts with their prices and the reward
track (`EndlessRewards`: every weapon and cosmetic whose requirement is ENDLESS_WAVE or
ENDLESS_DISTRICT, read from the catalog). In a run the HUD widget (`EndlessHud`,
`data/ui/hud_endless.tres`) shows the district the player is in and the best wave, gate and
trap prompts and the supply marker; the results section (`EndlessResultsSection`,
`data/ui/results_endless.tres`) shows "WAVE 14 · NEW BEST", the districts and the rewards the
run unlocked and the next one.

**Testing**: `tools/build_endless_testbed.gd` builds `scenes/levels/endless_testbed.tscn`, a
grey box of the five districts with every contract marker (a dev tool, not in the game).
`--autoplay=endless` (scripts/dev/endless_bot.gd) plays until it falls or `--max-seconds`,
buys a gate in a break when it can keep 150 tickets (and the overshield whenever it has 300 + 150), arms a trap with 4+ zombies in it, picks up
crates and logs `[dev] ENDLESS wave=..` per wave and `[dev] ENDLESS RESULT wave=..` at the end;
`--scene=<path>` plays another scene for the endless level (the testbed), and `--god`,
`--difficulty`, `--start-wave` work as usual.
