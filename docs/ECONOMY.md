# Economy and progression

How Arcade Tokens, player levels, weapon mastery, contracts and the shop fit together, the
numbers behind them, and the API the menus read. Everything is data: tune it in
`data/progression/` and check the result with `python3 tools/economy_model.py`.

## The idea in one paragraph

The zombies hoard the arcade's tokens: every one carries an **Arcade Token** ("Token" for
short). Pop it and its token spins out to you. Arcade Tokens are the permanent base currency
(still `sparks` in code, saves, price fields and stat ids; display names come from
`Wallet.CURRENCY`). Repeated Prize Prints recycle into **Capsule Credits** (`tokens` in
the prints save), a separate currency for the Credit Counter. Arcade Tokens come from
playing (kills, waves, clears, leftover tickets), from progress (every player level, every mastery rank) and from
**contracts**, and they buy **cosmetics only**. Weapons and anything that changes combat
come from player levels. Two reward tracks run side by side: things you **earn** (a
reward at every level, world sets for clears, mastery camos, milestone rewards) and
things you **buy** (the animated finishes, energy cells, gloves, charms, kill effects,
tracers, some decals, banners and titles, and sights).

## Earning Arcade Tokens

All amounts are in `data/progression/economy.tres` (`EconomyRules`).

| Source | Arcade Tokens | Notes |
| --- | --- | --- |
| Popping a zombie | ticket value / 10, at least 1 | 1 for tourists, runners and punks, 2 for specials, 4-5 for heavies |
| Headshot finishing blow | +1 | |
| Every 10th kill of a combo | +5 | |
| Wave cleared | 15 | +15 if the wave was flawless |
| Level cleared | 150, +25 per world after the first (Prize Pier 150 to Sky Harbor 375) | first clear of a level: +150, once |
| Tickets left at the portal | 1 per 20 tickets | only when the level is cleared |
| Player level L | 50 + 5 L | +100 on every fifth level |
| Mastery rank R | 10 + 10 R | 650 for a weapon's ten ranks |
| Contract | 40-60 | plus 300-500 XP |
| Milestone | 100-250 | once each, plus XP |

Kills, waves, the clear and the tickets are multiplied by `Difficulty.reward_scale()`
(fractions carry over, so a scale below 1 still adds up). Level, mastery, contract and
milestone payouts are fixed. A defeat keeps everything banked so far and loses only
the clear bonus and the ticket cash-in.

**Tickets, score and Arcade Tokens.** Tickets stay the run-only currency of the loadout
station. Whatever is left when you step through the portal still turns into score
(`WaveSet.ticket_score_rate`) and is now also cashed into Arcade Tokens. A clear earns about
1,800-2,600 tickets, so buying nothing is worth roughly 100 Arcade Tokens on top of the 500-700 a
clear pays: a heal or an overshield costs you 12-30 Arcade Tokens, dying costs the clear bonus,
the cash-in and the rest of the run. Spending to survive is the right call; hoarding is a
small, real reward for a clean run.

**In the world.** `scripts/economy/sparks_hud.gd` (HUD widget `data/ui/hud_sparks.tres`)
shows it: stars burst out of the zombie, home to the player (`SparkField`: one MultiMesh,
pooled, a short trail per star) and land in the run counter at the bottom centre, with a
pickup tick that climbs a semitone per pickup while they keep coming. Payouts that are
not stars (wave clear, level-up, contract) add up in one "+N" above the counter. The
results screen (`data/ui/results_sparks.tres`) counts up the run's Arcade Tokens with the
breakdown and the contracts.

## Spending Arcade Tokens

**A weapon bought outright.** A weapon whose `WeaponData.token_price` is above 0 can be
bought in the Arsenal while it is still locked (BUY · <price> TOKENS on its button; the
save keeps it as the grant `weapon:<id>`, like a kept weapon). Only the **Ringmaster** has
one: **50,000 Arcade Tokens**, the other way in besides level 50 + 15,000 kills + Endless
wave 25. It is far above every cosmetic price on purpose: the best gun in the game.

**The price rule.** Every price is a multiple of 250 Arcade Tokens (`EconomyRules.price_step`)
and at least its rarity's ladder price: **Common 250, Rare 750, Epic 1,500,
Legendary 3,000** (`EconomyRules.prices`). The rarities do not overlap (the dearest
rare costs less than the cheapest epic, and so on). An ordinary item costs its ladder
price; a **showpiece** costs more, and the very best items each have their own price,
ranked by how much they show on screen (operators, then animated finishes, gloves, kill
effects and tracers, then cells, sights and charms, then decals, banners and titles):

| Price | Item | |
| --- | --- | --- |
| 20,000 | Madame Fortuna | Mythic operator (the dearest item of the shop, never discounted) |
| 10,000 | Wind-Up Wally | operator (the dearest Legendary) |
| 9,500 | Pixel Pal | operator |
| 9,000 | Quicksilver | animated finish |
| 8,500 | Holo Foil | animated finish |
| 8,000 | Lava Flow | animated finish |
| 7,750 | Insert Coin | animated finish (arcade screen; set with the Extra Life cell and Pixel Stream tracer) |
| 7,500 | Prism Shards | gloves (crystal model, hologram) |
| 7,000 | Event Horizon | kill effect |
| 6,750 | Koi Pond | animated finish (set with the Koi Circle cell and Koi Dash tracer) |
| 6,500 | Coin Shower | kill effect |
| 6,000 | Golden Touch | gloves |
| 5,500 | Marquee Lights | animated finish |
| 5,000 | Holo Hands | gloves |
| 4,500 | Thunderhead | animated finish |
| 4,000 | Golden Comet | tracer |
| 3,750 | Solar Flare | animated finish |
| 3,500 | Spectrum Rush | energy cell |
| 3,250 | Corrupted | animated finish |
| 3,000 | the other legendaries | Prism Core, Gemcut, Golden Ticket, Champion, Holo Diamond, Holo Heart, Signal Lost, Spiral Galaxy, The Final Boss, Ticket Roll, Pixel Stream |

Below that: epic showpieces at 2,500 (Stunt Ace, Ferris Wheel, Starburst, Rainbow Road,
Neon Tube, Heartbeat, Plush Zombie, 8-Bit, Zombie Eye, Hot Rod, Koi Dash) and 2,000 (Lava Lamp, Main
Character, Holo Tiger, Extra Life, Koi Circle), the epic ladder at 1,500; Halfpipe (operator) 1,250, Prize Hoarder 1,000,
the rare ladder at 750; Top Dog (operator) 500, the common ladder at 250. Operators
always cost more than anything else of their rarity. `tools/economy_probe.gd` checks the
rule, the non-overlapping rarities, that the 15 dearest items each have their own price
and that the dearest is an operator, the Mythic spotlight at 20,000 that is never
among the picks. An item is in the shop when its
`CosmeticItem.price` is above 0; it is owned once bought. A `requirement` on a priced
item only gates the purchase (sights that open at a mastery rank).

For sale (336 items, 497,000 Arcade Tokens, sights included and Madame Fortuna's 20,000; 269 items and
416,250 Arcade Tokens before the update 24 gear; 239 items and
376,500 Arcade Tokens before the update 16 skins and the two rewards the new guns moved to the Shop; 206 items
and 315,000 Arcade Tokens before the update 13 cosmetics and the Mythic operator; 277,350 before the
price rule):
the original 69 plus 31 new weapon finishes,
5 operators, 9 gloves, and the new cells, charms, decals, sights, kill effects, tracers,
banners and titles that are not earned. New earned items use the item's own
`requirement` (lifetime kills, weapon mastery rank, best score, world clears). Earned, never sold: the
level track, the world sets (on the first clear of each of the ten levels, and World
Tourist for clearing the first five), mastery camos, cells and decals, milestone rewards, and quiet
goals for lifetime kills (44 items, 50 to 20,000 kills) and best score on Prize Pier
(5 items).

**Update 13 showpieces** (animated, `art/shaders/finish_*.gdshader`; three sets with a
matching cell, `cell_fx.gdshaderinc` patterns 17-19, and tracer, `tracer_pattern.gdshader`
styles 8-10):

| Item | Rarity | How |
| --- | --- | --- |
| Insert Coin (finish), Extra Life (cell), Pixel Stream (tracer) | Legendary, Epic, Legendary | Shop: 7,750, 2,000, 3,000 |
| Koi Pond (finish), Koi Circle (cell), Koi Dash (tracer) | Legendary, Epic, Epic | Shop: 6,750, 2,000, 2,500 |
| Kintsugi (finish) | Legendary | the Gold Standard milestone (with its banner) |
| Golden Repair (Kintsugi cell) | Legendary | 15,000 lifetime kills |
| Gold Seam (Kintsugi tracer) | Legendary | Endless wave 35 |
| Clockwork (finish) | Legendary | 17,500 lifetime kills |
| Hot Rod (finish) | Epic | Shop: 2,500 |
| Holo Tiger (finish) | Epic | Shop: 2,000 |

**Update 16 skins** (19 weapon finishes and 4 gloves; the finishes are in `data/cosmetics/finishes`,
all `weapon_finish`; the world patterns live in `art/shaders/finish_world.gdshader`, the animated
showpieces each have their own `finish_*.gdshader`). 23 items are for sale (29,250 Arcade Tokens):

| Item | Rarity | How |
| --- | --- | --- |
| Tooled Leather, Sailcloth, Chainmail, Building Blocks, Glow Bones (world finishes) | Rare | Shop: 750 |
| Motherlode, Sunken Doubloons, Quartered Arms (world finishes) | Epic | Shop: 2,000 |
| Tin Robot, Jack-o'-Lantern (world finishes, animated) | Epic | Shop: 2,500 |
| Amber Mosaic, Boiler Plate, Berry Tartan, Sunset Tiger (finishes) | Rare | Shop: 750 |
| Confetti Pop, Picnic Gingham, Mint Candy (finishes) | Common | Shop: 250 |
| Sheriff's Gauntlets, Deckhand Wraps, Knight's Mail, Brick Mitts (gloves) | Rare | Shop: 750 |
| Treasure Map (finish that draws itself) | Legendary | Shop: 4,250 |
| Ghost Train (finish, rushing carriage windows) | Legendary | Shop: 3,500 |
| Jackpot (finish, slot-machine reels) | Legendary | 25,000 lifetime kills |
| Multiball (finish, pinball playfield) | Legendary | Endless wave 30 |

**Update 23 Mythic.** **Celestial Midway** (`fin_celestial_midway`, Mythic, earned at **50,000
lifetime kills**, twice Jackpot, the highest kill goal in the game; never sold): a midnight
sky seen in depth behind the weapon's glass (a nebula, three star fields and aurora ribbons
that slide past each other as the weapon turns), constellations that draw themselves in gold
into carnival shapes, and pierced gold filigree trim
(`art/shaders/finish_celestial_midway.gdshader`). It is the first finish that reacts in play:
a kill with the weapon wearing it sends a shooting star along it (`params.pulse`,
`scripts/cosmetics/finish_pulse.gd`), and "Reduce motion" holds its sky still.

**Update 24 gear** (78 cosmetics outside the prints: 67 for sale, 80,750 Arcade Tokens; 11 earned).
No level reward moved and no level gives anything new: the earned ones use lifetime kills, melee
kills, Endless waves and milestones (an extra reward on four milestones that already had one).
Looks: `art/shaders/finish_gear.gdshader` (12 patterns; 0-4 animated, held still by "Reduce motion"
and flaring on kills through `params.pulse`), reticles 25-34 in `sight_reticle.gdshaderinc` (spiral,
sonar, orbit and brackets move) on four new optics in `art/blender/build_sights.py` (Horseshoe, Crown,
Jar, Saturn), ten charms in `build_cosmetics.py`, six printed stickers in `decal_art.py`, kill effects
in `kill_effects.gd` (props in `fx_props.gd`, sounds `tools/audio_packs/gear.py`), tracer styles 11-16
in `tracer_pattern.gdshader`, glove patterns 14-17 in `skin_glove.gdshader`, banner styles 41-48 in
`art/shaders/skin_banner_gear.gdshader` and cell patterns 20-23 in `cell_fx.gdshaderinc`.
`tools/economy_probe.gd` (`gear`) checks the lists below.

| Item | Rarity | How |
| --- | --- | --- |
| Fizzy Pop (finish, animated: rising bubbles, foam head, fizz surges on kills) | Legendary | Shop: 4,250 |
| Plasma Globe (finish, animated: wandering lightning in dark glass, brass base) | Legendary | Endless wave 40 (with the Plasma Brain title) |
| Firefly Meadow, Hypno Spin (finishes, animated) | Epic | Shop: 2,500 |
| Cotton Candy Cloud (finish, animated floss) | Epic | the Combo Artist milestone |
| Carnival Glass (finish, a sheen that shifts with the view) | Epic | Shop: 2,000 |
| Prize Plush, Card Shark (finishes) | Rare | Shop: 750 |
| Bumper Car (finish, glinting metal flake) | Rare | Shop: 1,000 |
| Gallery Wood (finish) | Rare | 11,000 lifetime kills |
| Popcorn Box, Strongman (finishes) | Common | Shop: 250 |
| Royal Crown; Firefly Jar, Saturn Ring (sights, animated reticles) | Epic | Shop: 2,000; 2,500 |
| Hypnotist, Lock-On (animated reticles); Admit One, Bone Sight, Thunderclap | Rare | Shop: 1,000, 1,250; 750 |
| Pro Circuit (sight) | Common | Shop: 250 |
| Lucky Horseshoe (sight) | Rare | the Headhunter milestone |
| Merry-Go-Round (charm, the horses go round); Magician's Hat | Epic | Shop: 2,500; 1,500 |
| Paper Lantern, Fortune Cookie, Lucky Eight, Squeaky Horn (charms) | Rare | Shop: 750 |
| Swirl Pop, Pretzel, Corn Dog (charms) | Common | Shop: 250 |
| Strongman's Barbell (charm) | Rare | 500 melee kills |
| Ta-Da! (kill effect) | Legendary | Shop: 3,750 |
| Gumball Burst; Firefly Release, Fifty-Two Pickup (kill effects) | Epic | Shop: 1,500; 2,000 |
| Hoopla, Shaken Soda (kill effects) | Rare | Shop: 1,000 |
| Film Reel, Firefly Trail; Synthwave (tracers) | Epic | Shop: 1,500; 2,000 |
| Zigzag, Bunting; Star Chain (tracers) | Rare | Shop: 750; 1,000 |
| Card Shark, Firefly Mitts (gloves) | Epic | Shop: 1,500 |
| Lovestruck, Strongman, Argyle Gent (gloves) | Rare | Shop: 750 |
| Big Top (gloves) | Common | Shop: 250 |
| Plasma Globe (banner) | Legendary | Shop: 3,000 |
| Big Top, Card Shark, Bumper Cars; Lantern Festival (banners) | Epic | Shop: 1,500; 2,000 |
| Firefly Field, Pop the Cap (banners) | Rare | Shop: 750 |
| Carousel (banner) | Epic | 30,000 lifetime kills |
| Lights, Camera, Carnage (title) | Epic | Shop: 1,500 |
| Sideshow Superstar, Card Shark, Firefly Catcher (titles) | Rare | Shop: 750 |
| Fizz Whiz, Hat Trick (titles) | Common | Shop: 250 |
| Strongman; Center Ring; Plasma Brain; Big Top Legend (titles) | Rare; Epic; Legendary; Legendary | 1,500 melee kills; the Well-Rounded milestone; Endless wave 40; 40,000 lifetime kills |
| Ace of Spades, Firefly Jar, Magic Hat (decals) | Rare | Shop: 750 |
| Big Top, Bottle Cap (decals) | Common | Shop: 250 |
| Lucky Horseshoe (decal) | Rare | the Spotless Shift milestone |
| Hypno Cell, Atomic Orbit (cells) | Epic | Shop: 1,500 |
| Firefly Cell; Candy Floss Cell (cells) | Rare | Shop: 750; 1,000 |

**Featured.** Four items a day are 20% off (`featured_count`, `featured_discount`).
On the 250 rule a 20% cut is always a round number: 200, 600, 1,200, 2,400, and 2,600 to
8,000 for the showpieces (`EconomyRules.discounted()` rounds to 50 below 1,000 and to
100 above, which these prices never need), so the "20% OFF" on the card is exact. One of
each rarity where possible. The selection depends only on the day and on what the
player did not own when the day's selection was first asked for; it is stored for the
day, so buying a featured item does not pull another one into the discount. It changes
at local midnight.

**Mythic.** Mythic (`CosmeticItem.Rarity.MYTHIC`, above Legendary) is earned (in
Endless, and Celestial Midway at 50,000 lifetime kills), with one exception sold in the shop: **Madame Fortuna**, the fortune-teller
operator, at 20,000 Arcade Tokens, twice Wind-Up Wally and the dearest item. She has no ladder
price (the rule's floor for Mythic is 0) and stays out of the daily picks: the Shop
shows her in its own spotlight before today's picks (`ShopCatalog.spotlight()`,
`scripts/ui/shop_spotlight.gd`: a glowing red-gold frame under a MYTHIC ribbon), always
at full price. Saving for her takes about 18 runs from a new profile (1,137 Arcade Tokens a
run in the first 15) or 28 after the level cap (723 a run). Everywhere she is shown
in 3D (Locker, Shop, home menu, player card) she wears her animated Mythic aura
(`scripts/cosmetics/operator_aura.gd`).

**NEW.** An item is flagged new in the shop while it is for sale, open, not looked at
yet, and either belongs to a slot listed in `EconomyRules.new_slots` (sights) or has a
requirement that has just been met.

## API for the menus

### `Wallet` (autoload)

| Member | |
| --- | --- |
| `balance() -> int` | Arcade Tokens to spend |
| `lifetime_earned() -> int` | Arcade Tokens ever earned |
| `can_afford(amount) -> bool` | |
| `earn(amount, source := &"")` | sources: `kill headshot combo wave flawless clear first_clear tickets level_up mastery contract milestone welcome` |
| `spend(amount, what := &"") -> bool` | saves the profile; false and no change if too expensive |
| `Wallet.format(n) -> String` | `"1,250"` |
| `run_total() -> int` | Arcade Tokens earned in the current or last run |
| `settle(result) -> Dictionary` | settles the run once (also on `Events.run_finished`); returns `{ total, lines: [[label, sparks]], balance_before, balance, tickets_cashed, victory }` |
| `rules: EconomyRules` | the numbers above |
| signals | `balance_changed(balance)`, `earned(amount, source)`, `spent(amount, what)`, `sparks_dropped(at, amount)`, `run_settled(summary)` |
| constants | `CURRENCY` "Arcade Tokens", `CURRENCY_SINGULAR`, `CURRENCY_SHORT` "Tokens", `COLOR` (gold), `COLOR_GLOW` (cyan) |

`SparkIcon.new(px)` (`scripts/economy/spark_icon.gd`) is the Arcade Tokens symbol as a Control;
set `flash = 1.0` for a flare. Sounds: `eco_spark_tick`, `eco_spark_bank`, `eco_purchase`,
`eco_deny`, `eco_contract`.

### `ShopCatalog` (`scripts/economy/shop_catalog.gd`, static)

| Function | Returns |
| --- | --- |
| `sections()` | `Array[Dictionary]` of `{ "slot": StringName, "title": String, "items": Array[CosmeticItem] }` in display order (Weapon Finishes, Sights, Energy Cells, Gloves, Charms, Kill Effects, Tracers, Decals, Banners, Titles, Operators); empty sections are left out, new slots get a section automatically |
| `items(slot := &"")` | every priced item (owned or not), cheapest first |
| `for_sale(slot := &"")` | priced items not owned yet |
| `featured()` | today's featured items (`Array[CosmeticItem]`, may include ones bought today) |
| `is_featured(it)`, `discount(it)` | discount is 0-1 (0.2 when featured, else 0) |
| `price(it)` | what it costs now (`EconomyRules.discounted`: a featured price is exactly 20% off and round); `base_price(it)` is the full price |
| `seconds_to_rotation()`, `day()` | time to the next featured change; the local day number |
| `pick_featured(day)` | the selection a given day would produce (for previews and tests) |
| `is_open(it)` | its requirement, if any, allows buying; `lock_text(it)` says why not |
| `can_buy(it)`, `buy(it)` | for sale, open and affordable; buys at `price(it)` and picks the weapon context itself |
| `affordable()` | everything that can be bought right now |
| `is_new(it)`, `mark_seen(it)`, `new_count(slot := &"")` | NEW flags; call `Profile.save_profile()` after browsing |
| `progress(slot := &"")` | `Vector2i(owned, total)` |
| `remaining_cost()` | Arcade Tokens to buy everything still for sale |

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

`MAX_LEVEL` is 50. `level_rewards(lvl)` (cosmetics, never priced ones),
`level_weapons(lvl)`, `level_sparks(lvl)`, `is_milestone_level(lvl)`, `reward_text(lvl)`,
`stamp(lvl)` / `stamp_kind(lvl)` (the weapon of a weapon level).

## Player levels

50 levels. XP from level L to L+1 is `1,800 + 400 (L - 1)` (`data/progression/rules.tres`),
366,600 XP to level 40 and 558,600 to level 50. XP sources are unchanged (6% of the score, wave bonuses, 1,000 + 250
per world for a clear, 1,500 for a first clear), plus contracts and milestones; wave and
clear XP follow `Difficulty.reward_scale()`.

Every level pays Arcade Tokens and gives exactly one thing. Weapons: Comet Hand Cannon 2, Arc
Coil 4, Bumper Lobber 6, Frostbite Cryo Beam 9, ... Rail Lancer 34, Balloon Darter 37,
Bullseye Longbow 41, Teacup Twister 43 (the full list is in the README). Every fifth level is a
showpiece: Pixel Burst (kill effect) 5, Chrome Cherry 10, Midway Maestro (operator) 15,
Lifeguard 20, Marquee 25, Prize Gold (animated finish) 30, Champion's Crown 35, and at
40 the Arcade Champion operator with the Boardwalk Legend finish and title, Teacup Ride
(animated finish) 45, and at 50 the Grand Finale animated finish with the Living Legend
title. The full track is printed by the model.

**Levels 41-50** (update 12). The curve is unchanged, so levels 1-40 cost exactly what
they did. One reward per level: 41 the Bullseye Longbow (update 24; Harlequin Tea, the finish
41 gave until then, moved to the Shop at 1,500), 42 Peppermint Tea Cell, 43
Teacup Twister (moved from 12; 12 gave the Midway Regular title until update 16, when the Ticket Ripper took level 12
and the title moved to the Shop at 750), 44 Spinning Teacup
(charm with a spinning cup), 45 Teacup Ride (animated finish, `finish_teacups.gdshader`),
46 Tea Swirl (banner), 47 Last Ride Home (title), 48 Hall of Fame (decal), 49 Starlight
Cell, 50 Grand Finale (animated finish, `finish_fireworks.gdshader`) and Living Legend
(title). Level Arcade Tokens follow the same rule (255 at 41 up to 400 at 50).

| | Cap 40 | Cap 50 |
| --- | --- | --- |
| XP to the cap | 366,600 | 558,600 |
| Clears to the cap (typical player) | 40 (60 runs) | 64 (95 runs) |
| All weapons unlocked | 35 clears, level 37 | 47 clears (70 runs), level 43 |
| Arcade Tokens earned by the cap | 55,965 | 84,697 |
| Arcade Tokens per run, first 15 runs / after the cap | 1,126 / 744 | 1,124 / 737 |

**Saves from before the cap went up** (`scripts/economy/cap_raise.gd`, once per profile,
marked by `level_cap` in the progression section). XP is kept and XP banked past level 40
counts: a save at 40 moves straight to the level its XP buys (a save with 17,400 or more
spare XP is at 41 or above), the Arcade Tokens of those levels are paid once (source `level_up`,
recorded in `cap_raise`), and their cosmetics unlock through their own requirements. A save
that already had the Teacup Twister (XP for level 12) keeps it: `weapon:teacup_twister` is
granted and `GameData.is_weapon_unlocked` honours it. A pre-economy save is left to
`LegacyGrant`, whose back pay already covers every level up to 50.

## Weapon mastery

Ten ranks, shared curve (`data/progression/mastery_curve.tres`): 400, 1,200, 2,400,
4,000, 6,000, 8,500, 11,500, 15,500, 21,000, 28,000 XP (was 600 ... 38,000). A weapon
carried as the main for one clear reaches rank 2, and rank 10 after about 14 runs.
Tiers and rewards are unchanged (decal 1, Bronze 2, cell 3, Silver 4, finish 5, Silver
cell 6, Gold 7, Gold cell 8, Diamond 9, Prismatic 10); every rank also pays Arcade Tokens, and
sights can ask for a rank to be bought.

## Contracts and milestones

**Contracts** (`data/progression/contracts/*.tres`, `Challenge` resources) are the
day-to-day goals: three at a time, each doable in a run or two, each paying Arcade Tokens and
XP. A finished contract stays ticked until the run ends, then a new one is dealt, so
there are always exactly three. A new profile starts with the three simplest (pop 100
zombies, clear 8 waves, 30 headshot kills); after that the pick is random among
templates that are not on the board and track a different stat. `param` is the player
level a template needs. Weapon contracts (`scope = WEAPON`) are dealt for one weapon,
usually one of the two carried, and also pay mastery XP. Stats: `kills headshots
multi_kills longshots close_calls heavy_kills sparks flawless_waves waves clears
best_combo run_score`.

**Milestones** (`data/progression/challenges/*.tres`) are the eleven long-term account
goals; they pay XP and Arcade Tokens once, and seven of them unlock a cosmetic
(`Requirement.Kind.CHALLENGE`, unchanged). The per-weapon challenges (5 x 8 weapons)
became weapon contracts; the Career page went from 52 goals to 14.

**Fewer notices.** Level-up and rank-up toasts wait until no wave is running, several
levels or ranks gained at once share one toast (with the Arcade Tokens they paid), they play
one at a time and at most three wait. Contracts show as a compact list between waves
and for a moment when one is completed.

## Old saves

Profile version 2 -> 3 (`Profile._migrate` flags the save; `LegacyGrant` runs once when
the game data is loaded):

1. Every cosmetic the save owned under its old rule stays owned: the old rules of all
   114 re-gated or now-priced items are in `scripts/economy/legacy_unlocks.gd`, and what
   they held is granted outright (equipped items stay equipped).
2. XP is kept. The new curve is cheaper at every level, so the level only goes up (old
   50 became 40, and is 50 again since the cap went back to 50); where a weapon would have been lost (old level 9, 10), XP is raised
   to that weapon's new level.
3. Mastery XP is kept; every new rank threshold is lower.
4. Back pay: the Arcade Tokens the new rules pay for the levels, mastery ranks and first clears
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
| Currency | none | Arcade Tokens: 55,700 earned by the cap |
| Items for sale | 0 | 239, 376,500 Arcade Tokens (69 and 47,150 before the price rise and the new cosmetics) |
| Clears to buy everything | - | about 344 (516 runs): the 259 (388 runs) of the 283,250-Token shop, scaled to 376,500 |
| Runs of saving from a new profile to afford | - | a common or a rare 1, an epic 2, a legendary 4, the cheapest showpiece above the ladder (3,250) 4, a 6,500 showpiece 7, the dearest Legendary (Wind-Up Wally, 10,000) 9, the Mythic Madame Fortuna (20,000) about 18 |
| Arcade Tokens per run | - | 1,137 in the first 15 runs, 723 after the cap |
| Arcade Tokens per session of three runs | - | 3,412 in the first five sessions, 2,170 after the cap |

The price rule of update 6 (multiples of 250, 20% featured, a spread at the top) moved
the shop from 277,350 to 283,250 Arcade Tokens (+2%) and the runs to afford each ladder price
not at all; before it, 20 items cost exactly 5,600 and 10 cost 2,800 (the 1,250 / 2,800 /
5,600 showpieces took 2, 4 and 5 runs of saving). Ten worlds since update 5: the rows
above come from the current model.

Where the Arcade Tokens come from, up to the cap: zombies 22%, level clears 17%, waves 17%,
level-ups 12%, contracts 8%, mastery ranks 8%, headshots 5%, tickets 5%, milestones 3%,
combos 3%, first clears 1%.

The first twelve runs (after; "The run buys" is what that run's Arcade Tokens alone would buy):

| Run | Level | Result | XP | Player level | Arcade Tokens | Saved (if unspent) | The run buys | Unlocks |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Prize Pier | clear | 7628 | 4 (+3) | 1143 | 1143 | 1 rare | Life Ring, Gold Star, Surf Rescue, Boardwalk Boss +7 more |
| 2 | Neon Skyline | clear | 7433 | 6 (+2) | 1253 | 2396 | 1 rare | Neon Grid, Crimson Core, Neon Heart, Circuit Pulse +10 more |
| 3 | Tidal Tunnels | defeat w5 | 2076 | 7 (+1) | 429 | 2825 | 1 common | Racing Stripes, Pier Rat, Ion r3, Scatter r2 |
| 4 | Tidal Tunnels | clear | 12034 | 9 (+2) | 1673 | 4498 | 1 epic | High Tide, Starry Starfish, Seashell, Tidal Glass +10 more |
| 5 | Launch Pad 9 | clear | 7870 | 11 (+2) | 1324 | 5822 | 2 rares | Deep Space, Pocket Rocket, Ringed Planet, Galaxy +8 more |
| 6 | Summit Lodge | defeat w5 | 4832 | 12 (+1) | 722 | 6544 | 1 rare | Bullseye Cell, Ticket Taker, Teacup Twister, Bumper r2 |
| 7 | Summit Lodge | clear | 10876 | 13 (+1) | 1455 | 7999 | 2 rares | Aurora, Glacier, Snow Globe, Snowflake +9 more |
| 8 | Prize Pier | clear | 8578 | 14 (+1) | 1158 | 9157 | 1 rare | Spotless, Sweeper, Lime Laser, Lemonade Cell +1 more |
| 9 | Neon Skyline | defeat w5 | 3330 | 15 (+1) | 629 | 9786 | 2 commons | Midway Maestro |
| 10 | Neon Skyline | clear | 5933 | 16 (+1) | 988 | 10774 | 1 rare | Funnel Cake Fiend, Pulse r4, Ion r4 |
| 11 | Tidal Tunnels | clear | 6684 | 17 (+1) | 1083 | 11857 | 1 rare | Pawprint, Ion r5, Scatter r4 |
| 12 | Launch Pad 9 | defeat w5 | 2515 | 17 | 409 | 12266 | 1 common | Midnight Run, Scatter r5, Comet r4 |

Measured against the game: a bot clear of Prize Pier from a new profile (near-perfect
aim, 82 headshots, every wave flawless, which a person will not match) paid 1,625 Arcade Tokens
and 9,862 XP and ended on level 5; the model's typical player gets 1,143 Arcade Tokens, 7,628 XP
and level 4 from the same run. A bot defeat on wave 7 of Tidal Tunnels paid 584 Arcade Tokens.

## Prize Prints

A **print** is one numbered, rolled copy of a weapon finish that drops from a **Prize
Capsule**. Two prints of one finish are never the same, and a print is its own
collectible: it neither grants nor removes the plain finish (the Shop still sells it,
the reward tracks still give it), and owning the plain finish never stops it dropping.
Code: `scripts/economy/prints/`; data: `data/prints/series_<n>.tres` (`PrintSeries`, listed
in `PrizePrints.SERIES_PATHS`); page: the **Prizes** tab (`data/ui/prizes.tres`, order 52,
between the Locker and the Shop).

**Series.** Two series are out: **Series 1 "Boardwalk"** (36 finishes that the Shop and
the reward tracks also give) and **Series 2 "Midnight Marquee"** (32 capsule-only
finishes, below). Every series shares the capsule rules: one capsule count, one luck
meter (it counts every capsule, whichever series it opens), one Capsule Credit balance,
and the same odds, prices and earnings (the probes check that the numbers match). The
player picks the series a capsule opens with the series tabs over the machine on the
CAPSULES tab (`PrizePrints.select_series`, saved as `series` in the prints section; a
save without one, or with an unknown id, opens the newest series). The machine is
painted for the series (`machine_colors`, `capsule_colors`), ODDS & INFO lists the picked
series' contents and the Credit Counter shelves the picked series. A trade-up mints from
the series most of its five prints came from (a tie goes to the newer). A print always
reads its own series (`PrizePrints.series_of(finish)`): the hero card names it.

**What a print rolls** (`PrintRoll`, all independent):

| Roll | Values | Odds | On the weapon |
| --- | --- | --- | --- |
| Pattern seed | 0-9,999 | uniform | where stripes, spots, camo and tiles fall: an offset, a small turn and a 0.86-1.16 scale of the pattern space; designs anchored to the model (racing stripes, stencil bands, candy paint) restyle by the seed instead |
| Shine | 0.000-1.000 | uniform | **Factory** below 0.60 (60%): faded paint, rubbed-through patches, scratches; **Polished** 0.60-0.90 (30%): glossier; **Mint** 0.90 and up (10%): a clear coat |
| Rare print | Glitter, Holo, Gold-ink Misprint | 1/20, 1/50, 1/100 (exclusive) | Glitter: metallic flecks that wink; Holo: an animated rainbow foil with a light sweep; Misprint: the pattern flipped and offset, shell and trim inks swapped, bands of inverted ink edged in gold leaf and gold splatter |
| Serial | per finish, counting up | - | every print of that finish ever minted on the profile (never reused); #001 First Edition, #002-#010 Low Serial, #007 / #077 / #777 Lucky 7s |
| Minted | the date | - | |

The print layer lives in `art/shaders/finish_common.gdshaderinc` (uniforms `print_on`,
`print_offset`, `print_angle`, `print_scale`, `print_seed`, `print_shine`,
`print_variant`): every `finish_*` shader runs `lp = print_xform(VERTEX)` and ends with
`PRINT_LAYER`. It is one pass; a plain finish pays one uniform branch.
`WeaponCosmetics.print_material()` makes one material per print and surface.

**Prize Capsules.** Earned: 1 per alpha defeated, 1 per bounty claimed, 1 for the day's
first clear, 1 for every third contract, 1 per milestone (`PrizePrints.settle(result)`
pays the run once, on `Events.run_finished` or the results section, whichever is first;
contracts and milestones pay as they happen). Bought: 500 Arcade Tokens each (on the price rule;
no real money). Published odds per capsule: **Common 62%, Rare 27%, Epic 9%,
Legendary 2%**. The **luck meter** guarantees an Epic or better within 10 capsules and a
Legendary within 40 (a forced Epic keeps Legendary's share of the top two); with it the
real rates are about 58 / 26 / 12.5 / 4%. Series 1 "Boardwalk" holds 36 finishes, all
`finish_*` shader finishes: 7 Common, 14 Rare, 11 Epic, 4 Legendary (Marquee Lights,
Quicksilver, Solar Flare, Thunderhead); level-track showpieces and mastery camos are left
out.

**Series 2 "Midnight Marquee"** (`data/prints/series_2.tres`, ids `fin_s2_*`): the fair
after midnight, 32 finishes made as one set, **capsule-only** (`exclusive`): never sold,
never a reward (price 0, a `GRANTED` requirement nothing grants, `params.unlock_text` /
`unlock_short` say "Capsule" in the Locker). The first print of a finish also unlocks its
plain finish in the Locker (the reveal says PLAIN FINISH UNLOCKED); repeats do not.

| Rarity | Finishes | Look |
| --- | --- | --- |
| Common (7) | Popcorn Stripe, Velvet Rope, Film Reel, Diner Checker, Usher's Houndstooth, Moon Polka, Starlit Pinstripe | bold painted patterns (`finish_s2_pattern.gdshader`, patterns 0-6) |
| Rare (12) | Picture Palace, Marquee Sunburst, Neon Zebra, Sequin Gown, Fortune Teller, Jukebox, Glow Leopard, High Roller, Pop Halftone, Lobby Terrazzo, Blackout Camo, Neon Argyle | patterns 7-18; Sequin Gown's sequins glint as it turns, Jukebox's bubbles rise |
| Epic (9) | Liquid Neon, Ticket Storm, Heartbeat, Magma Run, Overclock, Jelly Ballroom, Hypnotist, Firefly Field, Neon Rain | animated, one shader each (`finish_s2_<name>.gdshader`) |
| Legendary (4, the **chase prints**) | Event Horizon, Phoenix, Opening Night, Outrun | animated showpieces; a kill with the weapon makes each one react (discs flare, the fire roars, the flashbulbs pop, the grid flashes) |

The chase prints are listed in the series' `chase`: the hero card says CHASE PRINT and
ODDS & INFO marks them. Every animated Series 2 finish has `params.pulse`, so
`FinishPulse` holds it on a still frame with Settings "Reduce motion" and drives its
kill reaction (`motion` and `pulse` in `art/shaders/finish_s2.gdshaderinc`). Each is one
pass with no textures (value noise, a 3x3 Voronoi at most, small fixed loops), and the
print layer (`PRINT_LAYER`) reads on all of them: Glitter, Holo and Misprint included.

**Repeats, Capsule Credits, the Credit Counter.** A drop of a finish already held is a
repeat. With *auto-recycle repeats* on (the default, a toggle on the collection), a plain
repeat (Factory or Polished, no rare print, serial above #010) becomes Capsule Credits at
once and the reveal says so; a notable repeat is always kept. Any print can be recycled by
hand; favourites and worn prints never. Tokens: Common 1, Rare 3, Epic 8, Legendary 25.
The **Credit Counter** shelves one finish per rarity a day (the same all day, new at local
midnight) as a fresh print: Common 6, Rare 18, Epic 60, Legendary 200 tokens, each once a
day.

**Trade-up (Prize Fusion).** Five prints of one rarity (not favourites, not worn) become
one random print of the next rarity with fresh rolls; Legendary is the top. On the
TRADE-UP tab the picked prints sit in the five pods of the fusion machine
(`FusionChamber`; click a pod to take one out, AUTO-FILL picks the least special); FUSE
confirms with the five listed. The fusion plays full screen (`FusionReveal`), on purpose
nothing like a capsule: on a dark hologram grid the prints lock into the pods, the
holographic rings spin up and beams charge the core, the prints break up into slices
and streams of light that pour into it, the core flashes in the new rarity's colour and
a hologram scans the new print in from the bottom up; then its traits stamp in as below.
Sounds: `prz_fuse_slot`, `prz_fuse_charge`, `prz_fuse_stream`, `prz_fuse_form` and its
own sting, `prz_fuse_sting`.

**Wearing a print.** `PrizePrints.equip(print, weapon_id)` makes it that weapon's finish
everywhere `Cosmetics.weapon_loadout()` is read (first person, the Arsenal, the Locker
case, the player card): the loadout gains `"print"` and its `"finish"` is the print's
finish. Equipping a plain finish in the Locker takes the print off (the plain one shows
again). In the Locker a finish with prints shows a stack chip ("x3 PRINTS") and a button
over the case that opens those prints on the Prizes page.

**The page.** Five tabs: **CAPSULES** (the machine alone, big under a spotlight, with a
tab per series over it and a line on the picked series and how much of it is collected:
the luck meter and what earns capsules on its left; the capsules held, OPEN CAPSULE,
OPEN 5, BUY and the odds on its right), **COLLECTION** (every print in a wide grid, filtered by
rarity, grade and rare prints, five sorts, auto-recycle, and the inspect view
`PrintInspect`: wear, keep, recycle), **TRADE-UP**, **TOKEN COUNTER** and **ODDS & INFO**.
Code: `ui/prizes_page.gd` (tabs, the overlays, opening) and one `ui/prizes_*_view.gd`
per tab. The openings play full screen on a CanvasLayer above the menu.

**The opening** (`CapsuleReveal`). The machine fills the screen; the crank winds back and
makes one heavy turn (ratchet clicks) while the capsules churn, one rattles into the
lit chute and the camera pushes in on it. The capsule wobbles in the middle of the screen,
rocking harder and faster with light of its rarity leaking from the seam: 1.0 / 1.5 /
2.1 / 2.9 s from Common to Legendary, over the build cue `prz_build` (started part-way
in so its peak lands on the burst). It bursts (`RevealFx`: confetti, streamers, rings
and turning rays, by rarity; a banner COMMON / RARE! / EPIC! / LEGENDARY!; Legendary
turns the rays gold under a rain of gold) and the cue resolves, `prz_reveal_<rarity>`
(Common a light chord, Legendary a soft-brass fanfare over timpani). Then the hero card
(`PrintHero`): the print drops onto a 3D turntable (`PrintStage`, the Locker's stage) and
spins up while the camera eases in, a band of light sweeps its silhouette to show the
grade (dull for Factory, bright for Polished, twice for Mint), and the traits stamp in
one by one: GRADE with the shine meter, PRINT (a rare print gets its own flourish:
sparkles, a sweep in its colour, `prz_variant`), SERIAL rolling to its number (a low or
lucky one bursts in gold, `prz_serial`); then what became of a repeat and OPEN ANOTHER /
EQUIP / DONE. **OPEN 5** turns the crank once and drops five capsules in a row that
wobble and pop one after another, the rarest last, into their cards (click one for its
hero card). The first click, Enter or Esc jumps to the result; Esc closes. Sounds:
`prz_*` (`tools/audio_packs/prints.py`).

### API

| `PrizePrints` (static) | |
| --- | --- |
| `capsules()`, `tokens()`, `opened()`, `luck()` | `luck()`: `Vector2i(capsules to a guaranteed Epic, to a Legendary)` |
| `add_capsules(n)`, `can_buy_capsule()`, `buy_capsule()` | |
| `open_capsule()` | `{}` without a capsule, else `{ print, repeat, recycled, tokens, rarity, unlocked, lucky, series }` |
| `held()`, `get_print(id)`, `prints_of(finish_id)`, `holds(finish_id)`, `finish_of(p)`, `rarity(p)`, `grade(p)`, `is_notable(p)` | |
| `equip(p, weapon_id)`, `take_off(weapon_id)`, `equipped(weapon_id)`, `worn_on(p)`, `fits(p, weapon_id)` | |
| `set_favourite(p, on)`, `mark_seen(p)`, `new_count()`, `recycle(p)`, `can_recycle(p)`, `token_value(p)` | |
| `trade_up_problem(picked)`, `trade_up(picked)`, `trade_up_candidates(rarity)` | |
| `counter_shelf()`, `counter_price(fid)`, `counter_sold(fid)`, `buy_at_counter(fid)` | |
| `settle(result)` | `{ total, lines: [[label, n]], capsules }`, once per run |
| `set_auto_recycle(on)`, `series()`, `by_rarity(series = picked)` | `series()`: the series capsules open now |
| `all_series()`, `series_by_id(id)`, `select_series(id)`, `series_of(finish_id)`, `series_of_print(p)` | |
| `is_chase(finish_id)`, `collected(series)`, `trade_up_series(picked)` | `collected`: `Vector2i(finishes held, finishes)` |

`PrintLook`: `grade_name / grade_color / variant_name / variant_color / variant_odds /
serial_text ("#007") / serial_tag / minted_text / title / score / uniforms(p)`.
Signal: `Cosmetics.prints_changed`. Every change saves the profile.

**Save.** `Profile.section("prints")`, schema `v: 1`: `next_id, serials {finish: last},
list [prints], equipped {weapon: print id}, capsules, tokens, since_epic, since_legendary,
opened, minted, contracts, daily, auto_recycle, counter {day, sold}, earned`, and `series`
(the picked series id; missing = the newest).
`PrizePrints._migrate` fills what is missing, so a save from before prints loads with
none (checked by the probe).

**Checks.** `godot --headless --path . --script res://tools/print_probe.gd`: 10,000
capsules against the published odds, the luck meter (longest runs without an Epic 9 and
without a Legendary 39), 10,000 rolls of rare prints and grades, 10,000 capsules minted
into a profile (serials in order per finish, ids unique, only plain repeats recycled),
the save round trip and an old save, every action (equip, favourites, recycle,
trade-up, counter, buying, the run settlement), and the series together (each finish in
one series, shared rules, the pick saved and falling back to the newest, capsules of a
series drop only its finishes, the capsule-only unlock, majority trade-ups, chase prints
and Reduce motion). Locker stills of a series: `scripts/dev/prints_locker_tour.gd`. Stills: `tools/print_sheet.gd` (prints on
weapons), `tools/prizes_shots.gd` (every tab; the opening of each rarity, OPEN 5 and
Prize Fusion, frame by frame; `--shot-only=tabs` for other window sizes).

**The numbers** (`tools/economy_model.py`, the typical player, earned capsules only,
4,000 simulated players opening every capsule as it comes):

| | |
| --- | --- |
| Capsules per run: first 15 runs / runs 61-90 | 3.3 / 2.1 |
| Capsules per session of three runs: first five sessions / later | 9.9 / 6.3 |
| One capsule | 500 Arcade Tokens (a run pays 430-1,790: about two capsules) |
| Runs to the first Legendary print (median / 90%) | 7 / 11 |
| Runs to the first Holo (median / 90%) | 9 / 44 |
| Runs to the first Mint Holo (median / 90%) | 155 / 400+ |
| Runs to 200 Capsule Credits (a Legendary at the counter) | 53 / 60 |

The first sessions run high because the early milestones pay 2 each.

## Tuning

| To change | Edit |
| --- | --- |
| What anything pays in Arcade Tokens, the price ladder, the featured count and discount | `data/progression/economy.tres` |
| The level curve and XP payouts | `data/progression/rules.tres` |
| The mastery curve | `data/progression/mastery_curve.tres` |
| A contract or milestone | `data/progression/contracts/`, `data/progression/challenges/` |
| What a level gives | the `PLAYER_LEVEL` requirement of a cosmetic (price 0), or a weapon's `unlock` |
| Whether an item is sold | its `price` (0 = earned through its `requirement`) |
| Prize Capsules: odds, luck meter, rare prints, grades, capsule price and earnings, tokens, the counter, the series | `data/prints/series_<n>.tres` (the capsule rules match in every series) |
| A new print series | a `PrintSeries` in `data/prints/`, its path in `PrizePrints.SERIES_PATHS` |

After a change run the model, and the probe (`tools/economy_probe.gd`) for the rules it
checks. Do not edit `scripts/economy/legacy_unlocks.gd`: it records the rules old saves
were earned under.
