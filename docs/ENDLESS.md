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

Ashfall City (update 10) has 21 entrances: 5 in the square and 4 in every other district.
Precinct 9 has two gates (`Gate_precinct`, `Gate_precinct2`) and the Broadcast Tower two
(`Gate_tower`: the Market's north alley, `Gate_tower2`: the Metro's east stairs), so every
district is a loop; paying at either gate of a district opens both. Two `upgrade_bench`
markers: Ashfall Square (7.5, 0, 7) facing +Z, beside the loadout station, and the Broadcast
Tower (48, 0, -46) at yaw 90. The generator bakes each bench's footprint
(`BenchFootprint_<district>`, 2.4 x 1.1 x 1.2 m) off the navmesh.

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
| Entrances | Marker3D in group `enemy_spawn` with meta `district` (StringName): at least 4 per district, 5 in the start district, around the edges and out of the player's usual sight lines |
| Gates | `EndlessGate` nodes (`scripts/endless/endless_gate.gd`): `district` = the district it opens; children `Frame`, `Door`, `Blocker` (StaticBody3D), `Zone` (Area3D, both sides), `NavLink*` (NavigationLink3D, disabled). A district may have several gates; paying at any opens all of them |
| District areas | Area3D in group `endless_district_area`, meta `district`: boxes covering each district (the HUD names the district the player walks into; the spawn planner knows where the player is) |
| Features | Marker3D in group `endless_feature`, meta `kind` and `district`: `trap_fire`, `trap_shock`, `supply_drop`, `upgrade_bench`. The director builds the feature at the marker. A bench's front (where the player stands) faces the marker's +Z; it is solid, about 2.3 x 1.05 m, with 2 m clear in front, so the map's bake keeps its footprint off the navmesh (one in the start district beside, not on, the loadout station; one in the Broadcast Tower) |
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
`city_endless_final` loop, a red BOSS banner); the wave after a boss (11, 21, 31...) is a
**BREATHER** (0.55x size, a slow trickle of mostly shamblers from one street, a smaller crowd,
no surge, a green banner) to restock, upgrade and open a gate on; every other 5th is a **HORDE**
(three streets at once, 1.2x size, a surge, an orange banner); waves 1-4 are standard,
standard, rush, standard, then 6-9 standard, siege, ambush, bounty; from there every ten waves
read x1 breather, x2 standard, x3 rush, x4 crossfire (ranged), x5 horde, x6 standard, x7 siege,
x8 ambush, x9 bounty, x0 boss: pressure rises toward each horde and boss and eases after them.
A wave's zombies are split by role (regular, fast, heavy, special = the open districts'
own) by its kind's mix; a role with nothing open hands its share to the regulars, heavies join
from wave 3. Surges come from wave 6 (standard waves) and every horde, 3 + wave/5 zombies (at
most 8); rush and horde waves spawn in pairs from wave 12.

**Spawn choice** (the planner's strict rules, docs/ROUNDS.md): a zombie never appears at an
entrance in the player's view or within 14 m of them; only the 5 nearest valid entrances (by
walking route) are in play, so a big city never means long empty walks; a wave works 2 streets
at a time (3 for a horde, ambush or ranged wave, 1 for a breather) chosen in different
directions from the player and kept while they stay valid; a zombie still more than 46 m of
route away is brought, once, to a near entrance out of sight. A surge is telegraphed 4.5 s
ahead with a siren, a marker on its entrance and "SURGE INCOMING — PRECINCT 9, BEHIND YOU".

**Scaling** (`EndlessRules`, all tunable in `data/endless/endless_city.tres`), before the
difficulty's own multipliers (update 10 values):

| | wave 1 | wave 5 | wave 10 | wave 15 | wave 20 | wave 30 | wave 40 | cap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| zombies (standard wave) | 9 | 13 | 19 | 24 | 30 | 41 | 50 | 50 |
| alive at once | 6 | 7 | 8 | 10 | 11 | 13 | 16 | 18 (`crowd_max`, the director's CROWD_LIMIT) |
| spawn interval (s) | 2.0 | 1.8 | 1.55 | 1.3 | 1.05 | 0.85 | 0.85 | 0.85 |
| health | x1.0 | x1.10 | x1.23 | x1.35 | x1.41 | x1.53 | x1.65 | x2.0 (+2.5%/wave to 15, +1.2% after) |
| damage | x1.0 | x1.02 | x1.05 | x1.08 | x1.11 | x1.17 | x1.2 | x1.2 |
| speed | x1.0 | x1.03 | x1.07 | x1.11 | x1.15 | x1.15 | x1.15 | x1.15 |
| kill tickets | x1.0 | x1.12 | x1.27 | x1.42 | x1.57 | x1.8 | x1.8 | x1.8 |

Heavies (`EnemyData.heavy`: bruisers, riot shields) take half the health and damage growth:
they are already the tanks. A district's heavy joins the heavies' share of a wave, its other
enemies the specials' share. The boss has its own curve: its data health (The Wrecker: 3400) x
`boss_health` (difficulty) x (0.6 + 0.35 per earlier visit): 2040 on wave 10, 3230 on 20, 4420
on 30, 5610 on 40 (Standard), with its escorts capped at 40% of the crowd while it stands. The
player's own power grows with the Upgrade Bench (below), so health stays flat and late waves
press with numbers, tempo and mixed specials, never with bullet sponges. Breaks are 20 s (28 s
before a boss), skippable as usual.

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

`upgrade_bench` (`EndlessBench`, built from chunky parts: a workbench with a hazard edge, a vice,
a pegboard of glowing tools, a neon UPGRADES sign naming the next tier and its price, and a
hologram weapon turning over the vice): standing at it shows "HOLD E · UPGRADE ION CARBINE TO
MK II · 1100 · MAGAZINE 32 → 48, FASTER RELOAD". Each press buys one tier of the weapon in hand
for the run (`EndlessUpgrades`; prices `bench_prices`, 500 / 1100 / 1800):

| Tier | Gives |
| --- | --- |
| Mk I | x1.3 damage (`bench_damage`) |
| Mk II | magazine x1.5 (loaded at once), reload time x0.7 |
| Mk III | x1.7 damage and a violet rim glow on the weapon (the boost glow's shader) |

Damage goes through `WeaponController.damage_multiplier` (`RunDirector.refresh_damage()`: the
station's damage boost times the tier of the weapon in hand); the magazine and reload are set on
the WeaponData for the run and put back when the run is left (`EndlessUpgrades.restore()`).

**Power-ups** (`EndlessPowerups`, `EndlessPowerup`): from wave 3 a kill has a 3% chance
(`powerup_chance`) to drop one, never two on the ground and never within 35 s of the last
(`powerup_gap`); the Wrecker always drops Max Ammo. A drop rings a chime, says "POWER-UP:
RAPID FIRE", gets a HUD marker and lies on the navmesh as a spinning, glowing token over a ring
of light with its name over it for 20 s (`powerup_life`), blinking faster through the last 5.
Never the same kind twice running; Max Ammo comes first when the player is low.

| Power-up | Effect |
| --- | --- |
| Double Tickets | kills pay twice for 20 s (`powerup_seconds`) |
| Max Ammo | both weapons full |
| Blast Wave | every zombie within 11 m is thrown back and takes 160 x wave health (heavies 60%, the boss 15%) |
| Rapid Fire | shots x0.6 apart and reloads x0.6 for 20 s |

A timed one taken again restarts its clock; nothing stacks or outlives the run. The HUD shows a
draining bar per timed power-up under the district chip.

**UI**: the Play page's last carousel slot is ENDLESS (`EndlessCard`): best wave and score,
best on the chosen difficulty, districts opened, the districts with their prices and the reward
track (`EndlessRewards`: every weapon and cosmetic whose requirement is ENDLESS_WAVE or
ENDLESS_DISTRICT, read from the catalog). In a run the HUD widget (`EndlessHud`,
`data/ui/hud_endless.tres`) shows the district the player is in and the best wave, gate, trap
and bench prompts, the supply and power-up markers, the power-up timers and the tier of the
weapon in hand ("ION CARBINE · MK II"), and for 12 s after a district opens a marker over its
middle (until the player walks in). Boss, horde and breather waves have their own banner colours
(`WaveData.banner_style`, `HudBanner.STYLES`). The results section (`EndlessResultsSection`,
`data/ui/results_endless.tres`) shows "WAVE 14 · NEW BEST", the districts, the upgrades bought
and power-ups taken, the rewards the run unlocked and the next one.

**Testing**: `tools/build_endless_testbed.gd` builds `scenes/levels/endless_testbed.tscn`, a
grey box of the five districts with every contract marker (a dev tool, not in the game).
`--autoplay=endless` (scripts/dev/endless_bot.gd) plays until it falls or `--max-seconds`,
buys in a break whichever is cheaper, the next gate or the next bench tier of the weapon in hand, when it can keep 150 tickets (the
overshield only with what is left over), arms a trap with 4+ zombies in it, picks up crates and
power-ups a short, quiet walk away, and logs `[dev] ENDLESS wave=..` per wave,
`[dev] ENDLESS spawns wave=.. dist= min= route= near14= in_view= entrances= reach=` (spawn
fairness: where each zombie appeared, whether in view or within 14 m, how long it took to reach
the player; a boss's minions are counted apart) and `[dev] ENDLESS RESULT wave=..` at the end;
`--scene=<path>` plays another scene for the endless level (the testbed), and `--god`,
`--difficulty`, `--start-wave` work as usual.

## Balance (bot, Ashfall City, ion carbine, max profile)

`--autoplay=endless --weapon=ion_carbine`, one run each (the bot keeps 150 tickets, buys gates
first, then the overshield; it does not use traps from the square). Tickets are what it held at
the wave start.

| Difficulty, aim error | Wave reached | Time | Districts opened on waves | Tickets at waves 5 / 10 / 15 / 20 |
| --- | --- | --- | --- | --- |
| Casual, 1.2 | 35 | 33:31 | 5, 8, 11, 16 | 426 / 822 / 789 / 1856 |
| Standard, 1.2 | 20 | 15:28 | 6, 9, 14, 19 | 388 / 218 / 273 / 352 |
| Hard, 1.2 | 14 | 10:06 | 6, 10 | 278 / 628 / - / - |
| Standard, 3.5 (human-like) | 10 (the Wrecker at 41%) | 6:01 | 6 | 388 / 518 / - / - |
| Hard, 3.5 | 12 | 9:13 | 6, 10 | 278 / 928 / - / - |

Deaths come from crowds (shamblers and runners) and the boss, not from long fights with single
zombies. The bot with a 3.5 degree aim error stands in the Wrecker's telegraphed moves (it only
steps out of slams), so its wall is wave 10; a player who sidesteps the bulldoze and debris goes
on.
