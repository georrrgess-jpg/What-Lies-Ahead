# Rounds: waves, spawning, pacing, difficulty, checkpoints

How a run of a level is built, and where to change it. Code: `scripts/run/`
(`run_director.gd`, `spawn_planner.gd`, `pacing_director.gd`, `wave_twist.gd`,
`difficulty.gd`, `rounds_hud.gd`), `scripts/enemies/behaviours/alpha_boss.gd`.
Data: `data/levels/<level>_waves.tres` (`WaveSet` + `WaveData`),
`data/enemies/**/alpha_*.tres`.

## Shape of a level

Preparation, then waves with a break after each, then extraction through the
portal. Prize Pier has **6 waves**, the other nine worlds **7**. A wave lasts
30-50 s, so with breaks a good run takes about 6-7 minutes on Prize Pier (the
first level, straight after the tutorial) and 7-9 minutes elsewhere; the old
8 flat waves ran 9-11. Fewer, bigger waves leave room for each to be about
something, and the finale is a set piece instead of "wave 8, but more".

Every level uses the same arc, with its own cast:

| Wave | Prize Pier | Neon Skyline | Tidal Tunnels | Launch Pad 9 | Summit Lodge |
|---|---|---|---|---|---|
| 1 | Warm-up | Rooftop Welcome | Deep Divers | Hold the Apron | The Guests Are Frozen |
| 2 | The Crowd Gathers (first surge) | Courier Rush | Ink Battery (ranged) | Cadet Rush | Ski Patrol (rush) |
| 3 | Runner Rush | Tagger Crew (ranged) | Jelly Bloom (rush) | Jetpack Drop (ambush) | The Yeti Wakes (siege) |
| 4 | The Golden Lifeguard (bounty) **checkpoint** | The Golden Courier (bounty) **checkpoint** | Pressure Breach (ambush) **checkpoint** | The Golden Cadet (bounty) **checkpoint** | Avalanche (ambush) **checkpoint** |
| 5 | Jackpot Siege (twist: double tickets) | Blackout Ambush (twist: lights out) | The Golden Jelly (bounty) | Radiation Leak (siege) | The Golden Racer (bounty) |
| 6 | **Big Bruno** | Riot Line (siege) | Feeding Frenzy (twist: enraged horde) | Zero-G Scramble (twist: low gravity) | Cold Front (ranged) |
| 7 | | **Captain Lockdown** | **Inky the Great** | **Chief Burnout** | **Old Frostbite** (twist: whiteout) |

| Wave | Midnight Mall | Lost Temple | Candy Works | Lava Lagoon | Sky Harbor |
|---|---|---|---|---|---|
| 1 | After Hours | The Queue Line | First Shift | Aloha | Boarding Call |
| 2 | Power Walk (rush) | Vine Swingers (rush) | Conveyor Rush | Fire Dance (rush) | Freefall (rush) |
| 3 | Security Breach (siege) | The Overgrowth (siege) | Taffy Time (ranged) | Last Call (ranged) | Balloon Barrage (ranged) |
| 4 | Closing Time (ambush) **checkpoint** | Stampede (ambush) **checkpoint** | Shift Change (ambush) **checkpoint** | The Golden Dancer (bounty) **checkpoint** | The Golden Diver (bounty) **checkpoint** |
| 5 | Power Cut (twist: power cut) | The Golden Explorer (bounty) | The Golden Gummy (bounty) | Lava Flow (ambush) | Heavy Weather (siege) |
| 6 | The Golden Walker (bounty) | Monsoon (twist: monsoon) | Sugar Rush (twist: sugar rush) | Eruption (twist: eruption) | Gale Force (twist: gale) |
| 7 | **The Night Manager** | **The Idol Keeper** | **The Confectioner** | **Kahuna Krakatoa** | **Captain Cumulus** |

Breaks are 18 s (24 s before the finale, 14 s of preparation on Prize Pier,
12 s elsewhere) and can always be skipped with the start-wave key. The HUD
chip under the wave counter names the next wave during a break, so the
station purchase is a decision about what is coming.

## Wave kinds (`WaveData.kind`)

| Kind | What it is | How it spawns |
|---|---|---|
| `standard` | the world's regulars | two entrances at a time; flankers join late |
| `rush` | light, fast enemies in numbers | short interval, two entrances |
| `siege` | heavies first, then their escorts | one entrance at a time |
| `ambush` | everything at once | a pulse through every entrance |
| `ranged` | the world's specialists | spread evenly over all entrances, so they shoot from every side |
| `bounty` | a standard wave plus a bounty target | as standard; the target arrives behind the player |
| `finale` | the world's alpha and its horde | as standard; see below |

A wave is announced with the HUD banner (kicker "WAVE 3", title "RUNNER
RUSH", its one line of advice from `WaveData.hint` as the subtitle; the
director sends `"WAVE 3 — RUNNER RUSH: <hint>"` with `wave_started`), a sting
for its kind (`rounds_wave_<kind>`), and the round chip in the wave header.
During a break the chip reads the tier and the next round ("STANDARD · NEXT:
RUNNER RUSH", a `round` notice). Alpha entrances and falls use the
`banner_boss` style, clears `banner_cleared`, the portal `banner_portal`.

Other pieces a wave can carry, all set in its data:

* **Surge** (`surge_at`, `surge_count`): once that fraction of the wave has
  spawned, a siren sounds, the HUD names the entrance ("SURGE INCOMING — RIDE
  GATE") and marks it, and 3.5 s later the pack arrives through it together.
  The pack comes out of the wave's own list.
* **Bounty target** (`bounty`, `bounty_tickets`, `bounty_seconds`): a golden
  copy of the world's runner. It never attacks: it runs laps of the arena,
  keeping away from the player, for 40 s (8 s once it is the last thing
  alive). Pop it for the ticket prize; otherwise it slips away. A HUD marker
  follows it with the time left.
* **Twist** (`twist`): the place joins in for one wave.
  `jackpot` (Prize Pier) doubles kill tickets; `blackout` (Neon Skyline) dims
  the sky, ambient and sun to about a third so only the neon reads;
  `frenzy` (Tidal Tunnels) keeps the whole horde enraged; `low_gravity`
  (Launch Pad 9) cuts the player's gravity to 45% and makes leaps and jetpack
  hops 40% more frequent; `whiteout` (Summit Lodge) names the storm the
  level's weather prop brings in on the final wave.
* **Alpha** (`boss`, `boss_at`): see the next section.
* `rest_before`: a longer break before this wave.

## Finales: the alphas

Each world's last wave is led by a named, oversized version of its signature
enemy (`data/enemies/**/alpha_*.tres`: the base enemy's model at 1.4-1.5x,
one outfit colour, a fixed set of accessories, an additive glow, and a
pulsing ring under its feet). The first 45% of the horde is the opening act;
then the alpha arrives ("BIG BRUNO — HAS ARRIVED" boss banner), stops and
roars (a ring of light bursts out along the floor), and its health bar takes
the HUD's top slot (`RoundsBossBar`, `data/ui/hud_boss_bar.tres`): its name, a
notch at each phase, and under it its epithet and state ("THE PRIZE BOOTH
BULLY · PHASE 2/3 · ARMOURED", or "DAZED — SHOOT THE GLOW"); the bar pulses
when a phase starts. Surge and bounty markers and the close-out pings are a
full-screen overlay (`rounds_hud.gd`, `data/ui/hud_rounds.tres`).

Since update 8 every alpha has a **signature kit** built from reusable moves
(`scripts/enemies/behaviours/boss_*.gd`, configured per alpha in its data),
**three phases**, and a **defeat moment** (confetti fountains, a ring of
light and 0.9 s of slow motion).

| World | Alpha (epithet) | Health (Standard) | Signature kit (phase it unlocks) | Arena event | Aim reward |
|---|---|---|---|---|---|
| Prize Pier | Big Bruno (The Prize Booth Bully) | 2900 + 700 armour | prize booths thrown onto 3 marked spots around you; bull rush down a lane, then dizzy; ground pound with 2 rolling rings (2); booth barrage, 5 booths that follow you (3) | - | gold prize-belt plates; dizzy weak spot |
| Neon Skyline | Captain Lockdown (Riot Control) | 2900 + 500 shield | riot-shield charge (frontal shots do 15%), then shield down; 4 flashbangs; calls a shield line of 2 Riot Bruisers (2); 5-orb volley | lights out (3) | shoot around the shield; dizzy weak spot |
| Tidal Tunnels | Inky the Great (The Deep-Sea Diva) | 3100 | dives (cannot be hit), a ripple follows you and he bursts up under it with 4 tentacles; a line of tentacles from below that leaves slowing ink; tentacle cage around you (2); 7-orb ink fan | ink creeps in from the screen edges (2, 14 s; 3, for good) | - |
| Launch Pad 9 | Chief Burnout (The Launch Controller) | 3100 | rocket-boot dash that leaves a fire trail, then overheated; launch-pad jetpack dive; rocket barrage that follows you (2) | afterburners: 1.35x speed and tempo for 10 s (3) | overheated weak spot |
| Summit Lodge | Old Frostbite (The Abominable Host) | 3300 | ice walls rise around you (they block you for 7 s); frost pound with 2 rings; avalanche of 7 snowballs (3); big snowball | blizzard: you move at 82% for 14 s (2) | - |
| Midnight Mall | The Night Manager (After-Hours Security) | 3300 | flashlight sweep (a lit 140° beam; break line of sight); power walk; calls security, 3 Mall Walkers (2); clean-up: three charges in a row, then winded (3) | lights out for good (2) | winded weak spot |
| Lost Temple | The Idol Keeper (Guardian of the Idol) | 3300 + 900 armour | raises 4 stone pillars around you (cover, 9 s); idol laser: a low beam sweeping 120° (jump it or hide behind a pillar); a 300° sweep (3); vine lash | - | stone plates (headshots ignore them) |
| Candy Works | The Confectioner (Head of Candy R&D) | 3400 | gummy batch, 3 Gummy Bears (up to 4); syrup rush leaving a sticky trail, then dizzy; gumball drop that follows you; taffy yank; 5-orb volley | sugar rush: 1.4x speed and tempo for 12 s (3) | dizzy weak spot |
| Lava Lagoon | Kahuna Krakatoa (The Volcano's Voice) | 3500 | a line of lava geysers that leave burning lava; volcano stomp (1 ring); a ring of 6 geysers around you (2); geysers that follow you (3); coconut bombs | the sky goes red-dark (3) | - |
| Sky Harbor | Captain Cumulus (Admiral of the Sky Fleet) | 3600 | lightning that follows you; dive from on high; broadside, 5 cannonballs around you (2); 4-orb volley | gale: gusts lean on you from a new side every 4-5 s (2) | - |

Building blocks (each a `BossMove` resource in `AlphaBossBehaviour.moves`;
moves take turns, each unlocks at a phase, `move_gap` 1.4 s between them):

| Block | What it does | Counter |
|---|---|---|
| `BossStrikeZones` | a pattern of `BossZone` strikes: CHASE (each lands where you stand when it is placed), AROUND (on you and a ring around you), LINE (from the alpha out past you), SCATTER, RING_BOSS. A strike bursts up (column, spikes) or drops in (booth, ball); it can leave a patch (damage per second, slow) or a solid pillar (player_walls layer: blocks the player, not zombies or bullets) | step out of the circle (1.0-1.5 s); keep moving against CHASE |
| `BossShockwave` | pounds the floor N times, each sends a ring rolling outward | jump the ring |
| `BossCharge` | a lane grows through you (follows you, then locks), then it rushes along it; options: frontal `guard`, a `trail` of patches, `repeats`, `dazed` (stunned afterwards with a glowing weak spot: x1.75 damage) | step off the lane; punish the daze |
| `BossBeam` | an aiming line, then a beam sweeps an arc through you at a set height; optional spotlight | jump a low beam; hide behind scenery or a pillar |
| `BossSummon` | its own minions pop out around it (through the director, so they count toward the wave) | clear them |
| `BossBurrow` | it sinks (immune), a ripple follows you, stops and grows, and it bursts up there, optionally with a ring of strikes | keep moving, leave the ring |
| `BossArenaEvent` | at a phase: `darkness`, `gale`, `ink`, `chill`, `frenzy` | - |

Shared rules (`AlphaBossBehaviour`):

* **Phases** at 66% and 33% health: it stops and **roars** for 1.6 s (shots do
  25% meanwhile; a player within 6 m is shoved back), a hit never skips a
  phase, it gains 10% speed, its moves recharge 20% faster per phase, its
  phase's arena events start, and it calls a pack of 5 through the nearest
  hidden entrances. Forcing a phase pays the player 35% of their reserve
  energy (was 20%: the alphas are tougher now).
* **Armour plates** (Big Bruno, the Idol Keeper): body shots do 50% until the
  plates have soaked their armour; they pop off one by one with a clank.
  Headshots ignore them.
* **Ground slam**: with the player within 4.2 m it rears up while a ring
  grows on the floor to 5.5 m over 1.15 s, then the shockwave hits anyone
  standing inside. Back out, or jump it.
* **Volley**: it plants its feet for 1 s, then fires a fan of slow orbs.
* The first use of each move shows a callout naming the tell ("SIDESTEP THE
  BULL RUSH — HE'S DIZZY AFTER IT: SHOOT THE GLOW!"), so the fight teaches
  itself; every move has a wind-up clip, a sound (`tools/audio_packs/bosses.py`)
  and a floor marker or lane, and counts for the HUD threat ring.
* Nothing is cheesable from one spot: CHASE strikes, lanes and ripples are
  placed on the player wherever they stand (on a ledge too), so standing still
  is what gets hit; moving well clears every strike.
* While it stands, its escorts are capped at 40% of the wave's crowd, and keep
  trickling in (2 every 7 s) if the horde runs out.
* When it falls the horde breaks: nothing else spawns, and the usual
  close-out (below) brings the last few in.
* It moves with a capsule no bigger than a regular heavy (so it fits every
  doorway its horde uses) and is shot through a full-size one.

Everything is telegraphed (clip, sound, ring or glow, and the threat ring on
the HUD) and nothing is gory: alphas pop into confetti like everyone else.

Testing: the bot reads the floor markers the way a player does
(`AlphaBossBehaviour.escape_from()`: it steps out of marked circles, lanes and
the slam ring, and jumps rolling rings and low beams, `wants_jump()`), but it
never dodges projectiles and never uses cover. `--snap=<prefix>` also saves
`_move_<name>` and `_phase_<n>` stills; `tools/neon_stage_shot.gd` stages an
alpha with `--live=1 --boss-move=<name>` (that move next), `--boss-phase=n`,
`--boss-roar=1` (run with `--fixed-fps 60` so frames are game time).

## Spawn planner (map logic)

`SpawnPlanner` scores the level's `enemy_spawn` markers for every spawn:

1. **Not on top of the player**: an entrance whose walking route (navmesh
   path) to the player is under 13 m is out.
2. **Out of sight**: an entrance the player is looking at with a clear line
   loses 3 points; it is used only when nothing else is valid.
3. **No dead time**: every metre of route past 30 m costs 0.1.
4. **Spread**: each spawn loads its entrance (decays 0.22/s), so pressure
   moves between routes instead of queueing at one door.
5. **Fronts**: a wave works two entrances at a time (one for a siege, all for
   an ambush or a ranged wave), chosen apart from each other and re-read
   every 10 s as the player moves.
6. **Flankers late**: once 40% of a standard wave has spawned, enemies that
   flank widely (`flank_degrees >= 80`: runners, couriers, jellies, cadets,
   racers) take the entrance most behind the player.
7. **Closing out**: the last 3 spawns of a wave take the nearest valid
   entrance. Once nothing is left to spawn and 3 or fewer stand, they sprint
   (+35%) straight at the player, the HUD pings them, and one that is still
   more than 36 m of route away is brought to the nearest entrance while the
   player is looking elsewhere.
8. **Stalls**: a zombie that makes no progress for 5 s first steps back onto
   the nearest navmesh point and re-plans (a leap or a shove can leave it
   just off the mesh); only if that fails too does the director move it to
   an entrance (and remove it after two moves). Leap landings no longer
   replay the climb-in clip. Over the final 30-run grid this left one
   relocation (a ski racer that fell off Summit Lodge's edge).

## Pacing director

`PacingDirector` keeps a `stress` value (0 calm to 1 overwhelmed) from the
player's health and overshield, the zombies within 7 m, and the damage of the
last few seconds. It scales the spawn rate (`pace`) inside the bounds of the
difficulty:

* stress above 0.55: pace falls toward `pace_min` and the crowd cap shrinks
  by up to a quarter;
* health under 30% with 3 or more zombies in reach: spawning pauses, for at
  most `relief` seconds per wave;
* stress under 0.2 while the player keeps the crowd under 60% of its cap:
  pace rises toward `pace_max`, and past 1.15 the cap grows by 15%.

Pace moves 0.2 per second, so a wave breathes instead of switching.

## Difficulty (`Difficulty.TABLE`)

| | Casual | Standard | Hard |
|---|---|---|---|
| Enemy health | 80% | 100% | 112% |
| Alpha health | 70% | 100% | 100% |
| Enemy damage | 60% | 100% | 105% |
| Enemy speed | 95% | 100% | 105% |
| Crowd cap | 80% | 100% | 105% |
| Spawn interval | 120% | 100% | 95% |
| Special-attack cooldowns | 145% | 100% | 90% |
| Pace bounds (min-max) | 0.55-1.0 | 0.7-1.35 | 0.85-1.4 |
| Spawn pause for a player in trouble | 6 s per wave | 3.5 s | none |
| Health back at every wave clear | +20 | - | - |
| Ticket income | +25% (paid at the wave clear) | - | - |
| Rewards (`reward_scale()`: account XP, Sparks) | 80% | 100% | 130% |

Casual never presses, eases early, and tops the player up between waves: a
first-time player can make mistakes in every wave and still finish. Hard is
more, faster and angrier, with no safety net. Its alphas keep Standard health
(tougher escorts, more of them and faster specials already make the finale
harder) and its hits are only 5% heavier: the extra crowd is the threat, and a
player who dodges and dashes can still clear every world. The run score is not scaled, so
best scores stay comparable. The tier is shown on the HUD chip and is in the
result (`difficulty`, `difficulty_label`).

`Difficulty.effects(id)` returns the headline changes as short lines for a
menu; `Difficulty.color(id)` is the tier's accent.

## Wave grade

Each wave is graded at its clear from the health it cost (overshield hits do
not count): **S** untouched, **A** up to 20, **B** up to 45, **C** more. The
grade is in the clear banner ("WAVE 3 CLEARED · GRADE A") and pays tickets
(`WaveSet.grade_tickets`: 60 / 40 / 20 / 0), so playing clean feeds the
station.

## Checkpoint

Each wave set names a `checkpoint_wave` (wave 4 everywhere: the mid-point).
Clearing the wave before it shows "CHECKPOINT REACHED". If the run is lost on
that wave or later, the director sets `Game.checkpoint_wave`; the results
screen offers Continue while `Game.can_continue_run()` is true, and
`Game.continue_run()` restarts the level with `Game.resume_wave` set. The
continued run:

* starts in preparation before the checkpoint wave, at full health, with
  `checkpoint_tickets` (350-450) and the starting energy plus half a reserve;
* earns 75% rewards (`Difficulty.reward_scale()` includes it) and starts its
  score from zero;
* can be continued again if it is lost again.

Retry and Main Menu drop the checkpoint. The result carries `resumed_from`,
`checkpoint_wave` and `can_continue`.

## Station economy

Income is kill tickets, the bounty prize (150-225), the alpha (200) and wave
grades (up to 60 a wave). Every station price is a multiple of 25 and rises
(or holds) world by world:

| World | Energy | Heal | Overshield | Damage boost | Checkpoint tickets |
|---|---|---|---|---|---|
| Prize Pier | 150 | 250 | 450 | 400 | 350 |
| Neon Skyline | 150 | 250 | 450 | 425 | 375 |
| Tidal Tunnels | 175 | 275 | 450 | 450 | 400 |
| Launch Pad 9 | 175 | 275 | 500 | 500 | 425 |
| Summit Lodge | 200 | 300 | 600 | 600 | 450 |
| Midnight Mall | 200 | 325 | 625 | 625 | 475 |
| Lost Temple | 200 | 325 | 625 | 625 | 475 |
| Candy Works | 200 | 325 | 650 | 650 | 475 |
| Lava Lagoon | 200 | 325 | 650 | 650 | 475 |
| Sky Harbor | 225 | 350 | 700 | 675 | 500 |

A break usually affords one small purchase or half a big one, so energy, a
heal, the overshield and the boost compete in every break; the Jackpot wave on
Prize Pier is where a new player first has enough for the overshield or the
boost. A Standard clear earns about 1,800-2,600 tickets (the later worlds have
more and richer zombies) and the bot spends 1,500 on Prize Pier and 2,200-2,800
from Summit Lodge on.

## Result keys and signals added

`RunDirector.result()`: `difficulty`, `difficulty_label`, `reward_scale`,
`resumed_from`, `checkpoint_wave`, `can_continue`, `grades` (one letter per
cleared wave), `bosses_defeated`, `bounties_claimed`. Existing keys and the
`Events` bus are unchanged.

`RunDirector` signals: `surge_warning(point, seconds)`, `boss_changed(boss)`,
`bounty_changed(target)`, `wave_graded(number, grade, tickets)`. Queries:
`current_wave()`, `is_closing_out()`, `surge_point()`,
`bounty_seconds_left()`, and the public `boss`, `bounty`, `difficulty`,
`pacing`, `planner`.

## Testing with the bot

```
--difficulty=casual|standard|hard
--start-wave=N            jump to wave N
--continue                lose on purpose, continue from the checkpoint, play on (use with --start-wave=4 or later)
--snap=<prefix> [--snap-until=<event>]   stills of banner, surge, boss, slam, bounty, clear, continue (needs a renderer)
```

The bot logs every wave (`WAVE`), surge, alpha and bounty event, each wave's
grade with the damage taken per enemy type (`GRADE`), and in `RESULT` the
health left, grades, average pace and seconds of spawn pause.

## Validation (final grid)

Bot runs on the balanced build (update 4), one at a time, full runs from wave
1. Clears and the mean health left at the portal over the runs that cleared.
The bot aims well, never aims down sights, never dodges projectiles, never
dashes; it backs out of a slam ring. Single runs swing by about ±30.

| Level | Standard before | Standard after (8 weapons) | Hard after | Casual after |
|---|---|---|---|---|
| Prize Pier | 6/8, 46 | 10/10, 82 | 3/3, 71 | 1/1, 100 |
| Neon Skyline | 6/8, 37 | 14/15, 49 | 4/5, 18 | 1/1, 97 |
| Tidal Tunnels | 8/8, 58 | 9/10, 51 | 2/3, 43 | 1/1, 95 |
| Launch Pad 9 | 5/8, 50 | 10/10, 59 | 0/1 | 1/1, 78 |
| Summit Lodge | 3/8, 21 | 7/10, 47 | 2/5, 40 | 1/1, 100 |

Before, every Standard loss was in a finale, usually after waves the bot
cleared untouched (Big Bruno, 2800 health, was the toughest alpha of all).
After: Standard 50/55 (the remaining losses are finales and one early Tidal
Tunnels ink wave before the Inker was softened), Hard 11/17 (was 3/10 and 0/5),
Casual 5/5. `python3 tools/balance_report.py` prints the weapons' time-to-kill
table from data.

### Worlds 6-10 in scope (update 6)

The five new worlds were tuned on their own; this pass measured all ten
together (bot, max profile, one run per cell per weapon, Pulse Pistol and Ion
Carbine on Standard, the Ion Carbine on Hard and Casual). Clears, and the mean
health left over the clears; run time is in game seconds (waves and breaks).

| World | Alpha health | Standard before | Standard after | Hard before / after | Casual before / after | Run time (s) | Clear bonus (Sparks) |
|---|---|---|---|---|---|---|---|
| Prize Pier | 1800 | 2/2, 60 | 2/2, 55 | - | - | 220 | 150 |
| Neon Skyline | 1900 + 500 | 1/2, 82 | 2/2, 82 | - | - | 250 | 175 |
| Tidal Tunnels | 2100 | 2/2, 85 | 1/2, 28 | - | - | 280 | 200 |
| Launch Pad 9 | 2000 | 2/2, 87 | 2/2, 37 | - | - | 280 | 225 |
| Summit Lodge | 2200 | 2/2, 57 | 2/2, 66 | - | - | 280 | 250 |
| Midnight Mall | 2050 -> 2250 | 1/4, 73 | 2/2, 55 | 0/1 / 0/1 | 1/1, 90 / 1/1, 100 | 295 | 275 |
| Lost Temple | 2300 | 3/4, 53 | 2/2, 38 | 0/1 / 1/1, 49 | 1/1, 100 / 1/1, 100 | 300 | 300 |
| Candy Works | 2500 -> 2350 | 1/4, 70 | 2/2, 89 (3/3, 31 with the mezzanine navmesh) | 0/1 / 1/1, 42 | 1/1, 100 / 1/1, 100 | 405 -> 340 | 325 |
| Lava Lagoon | 2050 -> 2400 | 2/4, 36 | 1/2, 34 | 1/1, 49 / 1/1, 23 | 1/1, 100 / 1/1, 100 | 330 | 350 |
| Sky Harbor | 2700 -> 2500 | 2/4, 74 | 4/4, 41 | 0/1 / 1/1, 26 | 1/1, 100 / 1/1, 88 | 350 | 375 |

Before, the new worlds were a cliff after Summit Lodge (Standard 9/20 against
9/10 for worlds 1-5, nearly every loss in a finale: the Confectioner and the
Night Manager dealt 60-95 per finale, Lava Lagoon's and Lost Temple's escorts
40-45), and the alphas did not follow the curve (the Night Manager and Kahuna
Krakatoa had less health than Old Frostbite, Captain Cumulus jumped to 2,700).
After: Standard 11/12 for worlds 6-10. What changed: alpha health 2,250 /
2,300 / 2,350 / 2,400 / 2,500; the Night Manager swings for 16 and slams for 18,
the Confectioner swings for 20; Gummy Bears have 100 health (Candy Works' waves
ran 40% longer than anyone else's); finale caps 11 (Lost Temple, Lava Lagoon,
two shamblers fewer there), 13 (Candy Works), 14 with two Sky Divers fewer (Sky
Harbor); Sky Harbor's gale wave cap 13 with two shamblers fewer; Midnight Mall's
siege cap 10 with a walker fewer and a shambler fewer in wave 1. Station prices
are on multiples of 25 and rise world by world (see above). Candy Works' long
waves had a map cause: its navmesh was baked only up to 2.8 m, so the packing
mezzanine (3 m) and the Foreman's door spawn on it had none, and zombies that
came in up there crept along the deck until stall recovery dropped them to the
floor (93 s a run with 1-2 zombies left, against about 30 elsewhere). With the
deck baked (`tools/build_candy_works.gd`) the tail is 25 s and a Standard run
330-350 s instead of 400-430 (3/3 clears, 9-53 health left).
