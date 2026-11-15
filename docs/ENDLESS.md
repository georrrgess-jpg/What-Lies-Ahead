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
| `precinct` | Precinct 9 | 500 | `riot_shield` |
| `metro` | Metro Line | 750 | `tunnel_crawler` |
| `market` | Neon Market | 1000 | `firebug` |
| `tower` | Broadcast Tower | 1500 | more `city_bruiser`; the boss's lair |

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
