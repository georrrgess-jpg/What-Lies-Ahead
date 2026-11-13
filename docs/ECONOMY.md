# Economy and progression

How Sparks, player levels, weapon mastery, contracts and the shop fit together, the
numbers behind them, and the API the menus read. Everything is data: tune it in
`data/progression/` and check the result with `python3 tools/economy_model.py`.

## The idea in one paragraph

Every zombie carries a stolen **Spark** (the glow in its eyes). Pop it and the Spark flies
to you. Sparks are the permanent currency: they come from playing (kills, waves, clears,
leftover tickets), from progress (every player level, every mastery rank) and from
**contracts**, and they buy **cosmetics only**. Weapons and anything that changes combat
come from player levels. Two reward tracks run side by side: things you **earn** (a
reward at every level, world sets for clears, mastery camos, milestone rewards) and
things you **buy** (the animated finishes, energy cells, gloves, charms, kill effects,
tracers, some decals, banners and titles, and sights).

## Earning Sparks

All amounts are in `data/progression/economy.tres` (`EconomyRules`).

| Source | Sparks | Notes |
| --- | --- | --- |
| Popping a zombie | ticket value / 10, at least 1 | 1 for tourists, runners and punks, 2 for specials, 4-5 for heavies |
| Headshot finishing blow | +1 | |
| Every 10th kill of a combo | +5 | |
| Wave cleared | 15 | +15 if the wave was flawless |
| Level cleared | 150, +25 per world after the first | first clear of a level: +150, once |
| Tickets left at the portal | 1 per 20 tickets | only when the level is cleared |
| Player level L | 50 + 5 L | +100 on every fifth level |
| Mastery rank R | 10 + 10 R | 650 for a weapon's ten ranks |
| Contract | 40-60 | plus 300-500 XP |
| Milestone | 100-250 | once each, plus XP |

Kills, waves, the clear and the tickets are multiplied by `Difficulty.reward_scale()`
(fractions carry over, so a scale below 1 still adds up). Level, mastery, contract and
milestone payouts are fixed. A defeat keeps everything banked so far and loses only
the clear bonus and the ticket cash-in.

**Tickets, score and Sparks.** Tickets stay the run-only currency of the loadout
station. Whatever is left when you step through the portal still turns into score
(`WaveSet.ticket_score_rate`) and is now also cashed into Sparks. A clear earns about
1,800-2,600 tickets, so buying nothing is worth roughly 100 Sparks on top of the 500-700 a
clear pays: a heal or an overshield costs you 12-30 Sparks, dying costs the clear bonus,
the cash-in and the rest of the run. Spending to survive is the right call; hoarding is a
small, real reward for a clean run.

**In the world.** `scripts/economy/sparks_hud.gd` (HUD widget `data/ui/hud_sparks.tres`)
shows it: stars burst out of the zombie, home to the player (`SparkField`: one MultiMesh,
pooled, a short trail per star) and land in the run counter at the bottom centre, with a
pickup tick that climbs a semitone per pickup while they keep coming. Payouts that are
not stars (wave clear, level-up, contract) add up in one "+N" above the counter. The
results screen (`data/ui/results_sparks.tres`) counts up the run's Sparks with the
breakdown and the contracts.

## Spending Sparks

Price ladder by rarity: **Common 250, Rare 650, Epic 1,500, Legendary 3,000**
(`EconomyRules.prices`). The two best items of each shop section (one for sights and titles) are
**showpieces** at about three times their old price: **Rare 1,250, Epic 2,800,
Legendary 5,600** (`EconomyRules.premium_prices`): Holo Foil and Lava Flow (finishes),
8-Bit (sight), Prism Core and Heartbeat (cells), Golden Touch and Holo Hands (gloves),
Golden Ticket and Plush Zombie (charms), Coin Shower and Starburst (kill effects), Golden
Comet and Rainbow Road (tracers), Holo Diamond and Holo Heart (decals), Signal Lost and
Lava Lamp (banners), Prize Hoarder (title). Every price is on one of the two ladders
(the probe checks it). An item is in the shop when its `CosmeticItem.price` is above 0;
it is owned once bought. A `requirement` on a priced item only gates the purchase (sights
that open at a mastery rank).

For sale (194 items, 277,350 Sparks, sights included, after the content update that
doubled the cosmetics): the original 69 (115,250 Sparks) plus 27 new weapon finishes,
5 operators, 9 gloves, and the new cells, charms, decals, sights, kill effects, tracers,
banners and titles that are not earned. New earned items use the item's own
`requirement` (lifetime kills, weapon mastery rank, best score, world clears). Earned, never sold: the
level track, the five world sets (36 items, on the first clear of each level, and World
Tourist for all five), mastery camos, cells and decals, milestone rewards, and quiet
goals for lifetime kills (15 items, 50 to 10,000 kills) and best score on Prize Pier
(5 items).

**Featured.** Four items a day are 25% off (`featured_count`, `featured_discount`;
rounded to 5 Sparks: 190, 490, 1,125, 2,250, and 940, 2,100, 4,200 for showpieces), one of
each rarity where possible. The selection depends only on the day and on what the
player did not own when the day's selection was first asked for; it is stored for the
day, so buying a featured item does not pull another one into the discount. It changes
at local midnight.

**NEW.** An item is flagged new in the shop while it is for sale, open, not looked at
yet, and either belongs to a slot listed in `EconomyRules.new_slots` (sights) or has a
requirement that has just been met.

## API for the menus

### `Wallet` (autoload)

| Member | |
| --- | --- |
| `balance() -> int` | Sparks to spend |
| `lifetime_earned() -> int` | Sparks ever earned |
| `can_afford(amount) -> bool` | |
| `earn(amount, source := &"")` | sources: `kill headshot combo wave flawless clear first_clear tickets level_up mastery contract milestone welcome` |
| `spend(amount, what := &"") -> bool` | saves the profile; false and no change if too expensive |
| `Wallet.format(n) -> String` | `"1,250"` |
| `run_total() -> int` | Sparks earned in the current or last run |
| `settle(result) -> Dictionary` | settles the run once (also on `Events.run_finished`); returns `{ total, lines: [[label, sparks]], balance_before, balance, tickets_cashed, victory }` |
| `rules: EconomyRules` | the numbers above |
| signals | `balance_changed(balance)`, `earned(amount, source)`, `spent(amount, what)`, `sparks_dropped(at, amount)`, `run_settled(summary)` |
| constants | `CURRENCY` "Sparks", `CURRENCY_SINGULAR`, `COLOR` (gold), `COLOR_GLOW` (cyan) |

`SparkIcon.new(px)` (`scripts/economy/spark_icon.gd`) is the Sparks symbol as a Control;
set `flash = 1.0` for a flare. Sounds: `eco_spark_tick`, `eco_spark_bank`, `eco_purchase`,
`eco_deny`, `eco_contract`.

### `ShopCatalog` (`scripts/economy/shop_catalog.gd`, static)

| Function | Returns |
| --- | --- |
| `sections()` | `Array[Dictionary]` of `{ "slot": StringName, "title": String, "items": Array[CosmeticItem] }` in display order (Weapon Finishes, Sights, Energy Cells, Gloves, Charms, Kill Effects, Tracers, Decals, Banners, Titles, Operators); empty sections are left out, new slots get a section automatically |
| `items(slot := &"")` | every priced item (owned or not), cheapest first |
| `for_sale(slot := &"")` | priced items not owned yet |
| `featured()` | today's featured items (`Array[CosmeticItem]`, may include ones bought today) |
| `is_featured(it)`, `discount(it)` | discount is 0-1 (0.25 when featured, else 0) |
| `price(it)` | what it costs now (discounts rounded to 5); `base_price(it)` is the full price |
| `seconds_to_rotation()`, `day()` | time to the next featured change; the local day number |
| `pick_featured(day)` | the selection a given day would produce (for previews and tests) |
| `is_open(it)` | its requirement, if any, allows buying; `lock_text(it)` says why not |
| `can_buy(it)`, `buy(it)` | for sale, open and affordable; buys at `price(it)` and picks the weapon context itself |
| `affordable()` | everything that can be bought right now |
| `is_new(it)`, `mark_seen(it)`, `new_count(slot := &"")` | NEW flags; call `Profile.save_profile()` after browsing |
| `progress(slot := &"")` | `Vector2i(owned, total)` |
| `remaining_cost()` | Sparks to buy everything still for sale |

A Shop page in outline:

```gdscript
for it in ShopCatalog.featured():            # the featured row
    card(it, ShopCatalog.price(it), ShopCatalog.base_price(it), ShopCatalog.discount(it))
for section in ShopCatalog.sections():       # one tab or shelf per section
    for it in section["items"]:
        var owned := not Cosmetics.is_for_sale(it)
        var locked := ShopCatalog.lock_text(it)      # "" when it can be bought
        var is_new := ShopCatalog.is_new(it)
if ShopCatalog.buy(it):                      # emits Cosmetics.purchased(it), saves
    Sfx.play(&"eco_purchase")
else:
    Sfx.play(&"eco_deny")
```

### `Cosmetics` (autoload), additions

`is_for_sale(it)`, `can_unlock_purchase(it, weapon_id)`, `price_of(it)` (same as
`ShopCatalog.price`), `can_buy(it, weapon_id)`, `buy(it, weapon_id)` (charges
`price_of(it)`), signal `purchased(item)`. Priced items are never reported by
`check_new_unlocks()` and are never "unlocked" toasts.

### `ContractBoard` (`scripts/progression/contract_board.gd`, static)

`active()` returns the three entries `{ "id", "weapon", "progress", "done" }`;
`title(entry)`, `describe(entry)` ("Get 20 headshot kills with the Ion Carbine"),
`progress(entry)`, `goal(entry)`, `fraction(entry)`, `is_done(entry)`, `template(entry)`
(the `Challenge` resource: `xp`, `sparks`, `mastery_xp`), `weapon(entry)`,
`completed_count()`. `CareerCards.contracts_row()` builds the three tiles.
`Progression.contract_completed(entry)` fires when one is finished;
`Progression.settle(result)` has `contracts` (finished this run) and `new_contracts`.

### `Progression` (autoload), additions

`MAX_LEVEL` is 40. `level_rewards(lvl)` (cosmetics, never priced ones),
`level_weapons(lvl)`, `level_sparks(lvl)`, `is_milestone_level(lvl)`, `reward_text(lvl)`,
`stamp(lvl)` / `stamp_kind(lvl)` (the weapon of a weapon level).

## Player levels

40 levels. XP from level L to L+1 is `1,800 + 400 (L - 1)` (`data/progression/rules.tres`),
366,600 XP in all. XP sources are unchanged (6% of the score, wave bonuses, 1,000 + 250
per world for a clear, 1,500 for a first clear), plus contracts and milestones; wave and
clear XP follow `Difficulty.reward_scale()`.

Every level pays Sparks and gives exactly one thing. Weapons: Comet Hand Cannon 2, Arc
Coil 4, Bumper Lobber 6, Frostbite Cryo Beam 9, Rail Lancer 12. Every fifth level is a
showpiece: Pixel Burst (kill effect) 5, Chrome Cherry 10, Midway Maestro (operator) 15,
Lifeguard 20, Marquee 25, Prize Gold (animated finish) 30, Champion's Crown 35, and at
40 the Arcade Champion operator with the Boardwalk Legend finish and title. The full
track is printed by the model.

## Weapon mastery

Ten ranks, shared curve (`data/progression/mastery_curve.tres`): 400, 1,200, 2,400,
4,000, 6,000, 8,500, 11,500, 15,500, 21,000, 28,000 XP (was 600 ... 38,000). A weapon
carried as the main for one clear reaches rank 2, and rank 10 after about 14 runs.
Tiers and rewards are unchanged (decal 1, Bronze 2, cell 3, Silver 4, finish 5, Silver
cell 6, Gold 7, Gold cell 8, Diamond 9, Prismatic 10); every rank also pays Sparks, and
sights can ask for a rank to be bought.

## Contracts and milestones

**Contracts** (`data/progression/contracts/*.tres`, `Challenge` resources) are the
day-to-day goals: three at a time, each doable in a run or two, each paying Sparks and
XP. A finished contract stays ticked until the run ends, then a new one is dealt, so
there are always exactly three. A new profile starts with the three simplest (pop 100
zombies, clear 8 waves, 30 headshot kills); after that the pick is random among
templates that are not on the board and track a different stat. `param` is the player
level a template needs. Weapon contracts (`scope = WEAPON`) are dealt for one weapon,
usually one of the two carried, and also pay mastery XP. Stats: `kills headshots
multi_kills longshots close_calls heavy_kills sparks flawless_waves waves clears
best_combo run_score`.

**Milestones** (`data/progression/challenges/*.tres`) are the eleven long-term account
goals; they pay XP and Sparks once, and seven of them unlock a cosmetic
(`Requirement.Kind.CHALLENGE`, unchanged). The per-weapon challenges (5 x 8 weapons)
became weapon contracts; the Career page went from 52 goals to 14.

**Fewer notices.** Level-up and rank-up toasts wait until no wave is running, several
levels or ranks gained at once share one toast (with the Sparks they paid), they play
one at a time and at most three wait. Contracts show as a compact list between waves
and for a moment when one is completed.

## Old saves

Profile version 2 -> 3 (`Profile._migrate` flags the save; `LegacyGrant` runs once when
the game data is loaded):

1. Every cosmetic the save owned under its old rule stays owned: the old rules of all
   114 re-gated or now-priced items are in `scripts/economy/legacy_unlocks.gd`, and what
   they held is granted outright (equipped items stay equipped).
2. XP is kept. The new curve is cheaper at every level, so the level only goes up (old
   50 becomes 40); where a weapon would have been lost (old level 9, 10), XP is raised
   to that weapon's new level.
3. Mastery XP is kept; every new rank threshold is lower.
4. Back pay: the Sparks the new rules pay for the levels, mastery ranks and first clears
   the save already has (source `welcome`).

`godot --headless --path . --script res://tools/economy_probe.gd` checks this against
four old-format saves in `tools/fixtures/economy/`; their `.expected.json` files were
produced by the pre-economy game itself. The same probe covers earning, buying, the
featured rotation and the contracts.

## The model

`python3 tools/economy_model.py [--rev=<commit>] [--runs=N] [--markdown]` reads the data
files and plays a typical player on paper: sessions of two clears and one defeat (dying
on wave 5), the worlds in order and then in rotation, two weapons carried (the main
takes 65% of the kills) and the main rotating through the unlocked weapons; 35%
headshots, combo multiplier 1.35, the first two waves flawless, half the tickets kept.
`--rev` runs it on the data of any commit, which is how the "before" column was made.

| | Before | After |
| --- | --- | --- |
| Level cap | 50 | 40 |
| XP to the cap | 562,450 | 366,600 |
| Clears to the cap | 78 (116 runs) | 48 (71 runs) |
| Player level after the first session (3 runs) | 5 | 7 |
| All 8 weapons unlocked | level 9, 4 clears | level 12, 5 clears (7 runs) |
| Cosmetics unlocked by the first run | 23 | 11 |
| Mastery rank after the first run as a main | 2 | 2 |
| Runs as a main to mastery rank 10 | 19 | 14 |
| Goals on the Career page | 52 | 14 (3 contracts + 11 milestones) |
| Currency | none | Sparks: 55,700 earned by the cap |
| Items for sale | 0 | 194, 277,350 Sparks (69 and 47,150 before the price rise and the new cosmetics) |
| Clears to buy everything | - | 109 (163 runs; 38 clears before the price rise) |
| Runs of saving from a new profile to afford | - | a common or a rare 1, an epic 2, a legendary 4, a 5,600 showpiece 5 |
| Sparks per run | - | 988 in the first 15 runs, 637 after the cap |
| Sparks per session of three runs | - | 2,835 in the first five sessions, 1,862 after the cap |

Where the Sparks come from, up to the cap: zombies 22%, level clears 17%, waves 17%,
level-ups 12%, contracts 8%, mastery ranks 8%, headshots 5%, tickets 5%, milestones 3%,
combos 3%, first clears 1%.

The first twelve runs (after; "The run buys" is what that run's Sparks alone would buy):

| Run | Level | Result | XP | Player level | Sparks | Saved (if unspent) | The run buys | Unlocks |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Prize Pier | clear | 7628 | 4 (+3) | 1143 | 1143 | 1 rare | Life Ring, Gold Star, Surf Rescue, Boardwalk Boss +7 more |
| 2 | Neon Skyline | clear | 7433 | 6 (+2) | 1253 | 2396 | 1 rare | Neon Grid, Crimson Core, Neon Heart, Circuit Pulse +10 more |
| 3 | Tidal Tunnels | defeat w5 | 2076 | 7 (+1) | 429 | 2825 | 1 common | Racing Stripes, Pier Rat, Ion r3, Scatter r2 |
| 4 | Tidal Tunnels | clear | 12034 | 9 (+2) | 1673 | 4498 | 1 epic | High Tide, Starry Starfish, Seashell, Tidal Glass +10 more |
| 5 | Launch Pad 9 | clear | 7870 | 11 (+2) | 1324 | 5822 | 2 rares | Deep Space, Pocket Rocket, Ringed Planet, Galaxy +8 more |
| 6 | Summit Lodge | defeat w5 | 4832 | 12 (+1) | 722 | 6544 | 1 rare | Bullseye Cell, Ticket Taker, Rail Lancer, Bumper r2 |
| 7 | Summit Lodge | clear | 10876 | 13 (+1) | 1455 | 7999 | 2 rares | Aurora, Glacier, Snow Globe, Snowflake +9 more |
| 8 | Prize Pier | clear | 8578 | 14 (+1) | 1158 | 9157 | 1 rare | Spotless, Sweeper, Lime Laser, Lemonade Cell +1 more |
| 9 | Neon Skyline | defeat w5 | 3330 | 15 (+1) | 629 | 9786 | 2 commons | Midway Maestro |
| 10 | Neon Skyline | clear | 5933 | 16 (+1) | 988 | 10774 | 1 rare | Funnel Cake Fiend, Pulse r4, Ion r4 |
| 11 | Tidal Tunnels | clear | 6684 | 17 (+1) | 1083 | 11857 | 1 rare | Pawprint, Ion r5, Scatter r4 |
| 12 | Launch Pad 9 | defeat w5 | 2515 | 17 | 409 | 12266 | 1 common | Midnight Run, Scatter r5, Comet r4 |

Measured against the game: a bot clear of Prize Pier from a new profile (near-perfect
aim, 82 headshots, every wave flawless, which a person will not match) paid 1,625 Sparks
and 9,862 XP and ended on level 5; the model's typical player gets 1,143 Sparks, 7,628 XP
and level 4 from the same run. A bot defeat on wave 7 of Tidal Tunnels paid 584 Sparks.

## Tuning

| To change | Edit |
| --- | --- |
| What anything pays in Sparks, the price ladder, the featured count and discount | `data/progression/economy.tres` |
| The level curve and XP payouts | `data/progression/rules.tres` |
| The mastery curve | `data/progression/mastery_curve.tres` |
| A contract or milestone | `data/progression/contracts/`, `data/progression/challenges/` |
| What a level gives | the `PLAYER_LEVEL` requirement of a cosmetic (price 0), or a weapon's `unlock` |
| Whether an item is sold | its `price` (0 = earned through its `requirement`) |

After a change run the model, and the probe (`tools/economy_probe.gd`) for the rules it
checks. Do not edit `scripts/economy/legacy_unlocks.gd`: it records the rules old saves
were earned under.
