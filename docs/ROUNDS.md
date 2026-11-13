# Rounds: waves, spawning, pacing, difficulty, checkpoints

How a run of a level is built, and where to change it. Code: `scripts/run/`
(`run_director.gd`, `spawn_planner.gd`, `pacing_director.gd`, `wave_twist.gd`,
`difficulty.gd`, `rounds_hud.gd`), `scripts/enemies/behaviours/alpha_boss.gd`.
Data: `data/levels/<level>_waves.tres` (`WaveSet` + `WaveData`),
`data/enemies/**/alpha_*.tres`.

## Shape of a level

Preparation, then waves with a break after each, then extraction through the
portal. Prize Pier has **6 waves**, the other four worlds **7**. A wave lasts
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
then the alpha arrives ("BIG BRUNO — HAS ARRIVED" boss banner, and its health
bar with a notch at each phase in the HUD's top slot: `RoundsBossBar`,
`data/ui/hud_boss_bar.tres`). Surge and bounty markers and the close-out
pings are a full-screen overlay (`rounds_hud.gd`, `data/ui/hud_rounds.tres`).

| World | Alpha | Health (Standard) | Built on | Its patterns |
|---|---|---|---|---|
| Prize Pier | Big Bruno | 1800 | Boardwalk Bruiser | roar-then-charge; 3-orb lob; ground slam (the slowest: 1.3 s) |
| Neon Skyline | Captain Lockdown | 1900 + 500 shield | Riot Bruiser | riot shield (break it or aim over it); shield charge; 5-orb volley; ground slam |
| Tidal Tunnels | Inky the Great | 2100 | Mascot Inker (the world has no heavy) | 5-glob lobbed ink volley at range; a fan of 7 slow ink orbs at mid range; ground slam |
| Launch Pad 9 | Chief Burnout | 2000 | Jetpack Mechanic (no heavy) | jetpack hop with a 3 m landing blast; 3-flare volley; ground slam; a slow, heavy swing |
| Summit Lodge | Old Frostbite | 2200 | Yeti | big snowball lob; 3-snowball fan; ground slam |

Alpha health climbs with the worlds (the first one, right after the tutorial,
is the softest and the most telegraphed). The finale's horde lists its slow
regular first: that type opens the wave and is the one that keeps trickling in
as escorts while the alpha stands, so a finale is about the alpha, not about a
stream of runners.

Shared rules (`AlphaBossBehaviour`):

* **Ground slam**: with the player within 4.2 m it rears up while a ring
  grows on the floor to 5.5 m over 1.15 s, then the shockwave hits anyone
  standing inside. Back out, or jump it.
* **Volley**: it plants its feet for 1 s, then fires a fan of slow orbs.
* **Phases** at 66% and 33% health: it roars, gains 10% speed, and calls a
  pack of 5 through the nearest hidden entrances. Forcing a phase pays the
  player 20% of their reserve energy, so the fight never runs dry.
* While it stands, its escorts are capped at 40% of the wave's crowd, and keep
  trickling in (2 every 7 s) if the horde runs out.
* When it falls the horde breaks: nothing else spawns, and the usual
  close-out (below) brings the last few in.
* It moves with a capsule no bigger than a regular heavy (so it fits every
  doorway its horde uses) and is shot through a full-size one.

Everything is telegraphed (clip, sound, ring or glow, and the threat ring on
the HUD) and nothing is gory: alphas pop into confetti like everyone else.

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
| Enemy health | 80% | 100% | 120% |
| Alpha health | 70% | 100% | 100% |
| Enemy damage | 60% | 100% | 105% |
| Enemy speed | 95% | 100% | 105% |
| Crowd cap | 80% | 100% | 110% |
| Spawn interval | 120% | 100% | 90% |
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
grades (up to 60 a wave). Prices rise with the world (energy 150-190, heal
250-300, overshield 450-600, damage boost 400-600). A break usually affords
one small purchase or half a big one, so energy, a heal, the overshield and
the boost compete in every break; the Jackpot wave on Prize Pier is where a
new player first has enough for the overshield or the boost.

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
