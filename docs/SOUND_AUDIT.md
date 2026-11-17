# Sound audit (update 14)

A full audit of the game's sound design: every one of the 745 sound effects and 35
music/ambience loops measured, drawn as a spectrogram, compared with its family and
with the house targets below, and the outliers retuned in their generators.

## Method

`python3 tools/sound_audit.py` (numpy + ffmpeg) measures every file and combines it
with `audio/mix.tres` and the call sites (via `tools/audio_mix_report.py`):

| column | what it is |
|---|---|
| peak / rms / crest | sample peak, RMS of the active part, peak - rms (punch) |
| lufs | loudness estimate: loudest 400 ms K-weighted block (loops: gated integrated) |
| cent | spectral centroid (brightness) |
| hf4 / hf8 | share of the energy above 4 / 8 kHz (harshness) |
| tone | strongest narrow tone and its share of the energy (whistles) |
| low80 | share of the energy below 80 Hz (mud; small speakers cannot play it) |
| dc / clip / click | DC offset, full-scale samples, start/end or loop-seam jump |
| **eff** | the **in-game level**: loudest K-weighted 100 ms + loudest gameplay call volume + mix (category gain + trim) + bus, positional sounds 4 m away; loops: integrated loudness at the level's volume |

`--csv` writes every column (`docs/sound_audit/before.csv`, `after.csv`); `--sheets <dir>`
draws a log-frequency spectrogram (30 Hz - 18 kHz, -80..0 dBFS, guides at 100 Hz, 1 kHz,
10 kHz) of every file, tiled per family, each tile labelled with its length and `eff`;
flagged sounds have a red label. A family is the sound's mix category.

Flags: above its family's house ceiling (`HOUSE_MAX`, the top of the bands below) or
above -9 ("over band"); louder than the family median by > 5 dB or quieter by > 8 dB; > 6 % above
8 kHz or > 30 % above 4 kHz; a narrow tone above 1.2 kHz holding > 25 % of the energy
(not counted for UI, confirm, cue and kill-effect chimes); > 35 % below 80 Hz (not
counted for thumps, bosses, music and beds); a click > 5 % of the peak; DC; clipping;
a centroid more than 1.5 octaves off the family median ("bright"/"dull": a hint, read
it with the sheet).

## House targets

Toy-arcade, warm and punchy, never piercing. Levels are `eff` (dB at the output).

| family | band (eff dB) | notes |
|---|---|---|
| weapon (fire) | -20 .. -14 | fast autos (8+ shots/s) at most -17; one big single shot or explosion at most -11 |
| handling (reload, equip, ready) | -24 .. -16 | |
| confirm (hitmarker, kill, headshot, combo) | -21 .. -16 | |
| impact | -21 .. -13 | |
| kill_effect (cosmetics) | -23 .. -17 | |
| enemy_voice | -21 .. -16 | groans sit under the guns |
| enemy_attack / telegraph / special | -18 .. -11 | warnings must cut through; still under -9 |
| cue (waves, gates, bosses, Endless events) | -18 .. -10 | boss slams, the Wrecker's impact and the boss defeat may reach -9 |
| player (steps, hurt, dash) | -27 .. -17 | |
| ui | -22 .. -14 | hover/tick micro-sounds -30 .. -24 |
| ambience emitters (loops in the world) | -26 .. -16 | |
| music | -27 +/- 1 (LUFS at the level volume) | mastered to -15 LUFS (final waves -14) |
| ambience beds | -32 +/- 1 | mastered to -18 LUFS |

- **Ceiling**: no sound above -9 eff, and nothing repeated 10x a second above -17.
- **Brightness**: at most 6 % of the energy above 8 kHz and 30 % above 4 kHz (designed
  hisses and sprays up to 45 % above 4 kHz, still under 8 % above 8 kHz).
- **Whistles**: no single tone above 1.2 kHz holding more than 25 % of a non-chime sound;
  chimes and pings keep their fundamental under ~2.5 kHz.
- **Low end**: under 35 % below 80 Hz except thumps, bosses and beds; every one-shot has
  energy in 100-400 Hz so it reads on small speakers.
- **Pitch/key**: tonal cues in concert pitch (A440), the music's A-minor/C-major world;
  enemy voices between ~80 and ~1,000 Hz fundamental, chimes 500 Hz - 2.5 kHz.
- **Clean edges**: 3 ms fade in, 10 ms fade out on every one-shot; loops seamless.

## What the audit found

Run on all 745 effects and 35 loops (`docs/sound_audit/before.csv`, sheets in
`docs/sound_audit/before/`). The music and the ambience beds were already in band
(every loop within 1 dB, mastered by `gen_audio.master`) and no one-shot clipped or
clicked at its edges (`write_wav` fades them). What stood out:

1. **A broken pack.** `tools/audio_packs/bosses.py` called `filt(x, lo, hi)` meaning a
   band-pass, but `filt` takes the low-pass corner first: every band became a sub
   low-pass plus a high high-pass. `rounds_boss_defeat` was **completely silent**
   (peak -inf: the alpha died without a sound), `rounds_boss_roar` was 100 % below 80 Hz
   (a felt-not-heard rumble, inaudible on laptop speakers yet the loudest cue at -7.7),
   `rounds_boss_thunder` was only its 4.5 kHz crack (84 % above 4 kHz, its rumble gone),
   and stone/charge/geyser/splash/zone-hit/plate-break lost their bodies.
   Sheet: `before/cue_1.jpg` (the boss row) vs `after/cue_1.jpg`.
2. **Too loud for the game**: the Endless siren loop at -9.3 (the loudest loop, 11 dB over
   the other emitters), the Ashfall Wrecker's impact -5.9 and the riot bash -7.3 (louder
   than any gun), the alpha's beam/slam/pound/roar/surface at -7.4 .. -7.9, the Mall
   walker's whistle -7.7, prize-capsule shake/shine -9.5/-10 in a menu, the tutorial dings
   -10.3.
3. **Mud** (energy below 80 Hz that small speakers cannot play): the alpha pound 85 %,
   the surge hit 68 %, the lava eruption 98 %, the far city blast 98 %, the wrecker engine
   75 % / charge 57 %, Endless trap fire 60 % / supply drop 55 % / boss siren 44 %, the
   heartbeat 98 %, the heavy landing 46 %, the city buzz loop (a 54 Hz drone).
4. **Harsh**: jungle thunder 36 % above 8 kHz, Dune's ambience bed 18 %, the Dune jet 16 %,
   the cosmetics charm 12 %, the frost shatter 9 %, the Dune cadet radio 8 %, soda
   shake/splash 52 %/43 % above 4 kHz.
5. **Whistles**: the Mall walker's whistle is a pure 2.9 kHz tone (93 % of its energy) at
   the loudest level in the game; the frost ice chip a 2.5 kHz ping (91 %).
6. **Lost**: crawler skitter -28.8, popcorn kill effect -28.4, gummy wobble -23.3, the UI
   tab/select/tick/hover -26 .. -37, tutorial blip -26.8.
7. **Does not match**: the boss family (sub rumbles among bright, toy cues), the city buzz
   (a drone among crackles), the prize-print sounds in no category (`misc`).

Weapon sounds are listed for the weapon lanes in "Weapons" below.

## What changed

- **Generator fix**: `bosses.py` uses `_bp(x, lo, hi)` (a real band-pass); the whole pack
  was regenerated (the 13 sounds that used it changed; the 6 without filters are
  byte-identical).
- **House tuning** (`tools/sound_tuning.py`, applied by `gen_audio.write_wav`,
  `write_loop_wav` and `write_music` before normalising/mastering, so it survives any
  regeneration): 37 entries. Sub thumps get `drive` (tanh saturation, harmonics a small
  speaker can play) + a 70-75 Hz high-pass + a 120-140 Hz lift, and the pure-sine ones a
  pitch of a fourth (75 Hz -> 100 Hz; a fourth keeps tonal ones on the A440 grid);
  harsh ones a 6-9 kHz low-pass and a -2 .. -4 dB shelf; the whistle a quarter lower.
- **Volume**: 43 per-sound trims (new or changed) in `audio/mix.tres` set each outlier into its family band;
  `prz_` (prize capsule / prints) categorised as `ui` (same bus gain, so level-neutral).
- `python3 tools/gen_audio.py <pack> --only=a,b` and `--tuned` rewrite just the named /
  tuned sounds (everything is still generated in order, so no other sound's random stream
  shifts and nothing else is rewritten).

### Families, before -> after (base sounds; eff = in-game dB)

| family | n | median eff before -> after | p10-p90 spread | flagged before -> after |
|---|---|---|---|---|
| ambience | 11 | -20.0 -> -18.1 | 14.8 -> 9.4 | 6 -> 4 |
| ambience_bed | 11 | -32.0 -> -31.9 | 0.2 -> 0.1 | 4 -> 2 |
| confirm | 4 | -19.0 -> -19.0 | 2.9 -> 2.9 | 0 -> 0 |
| cue | 69 | -14.3 -> -14.1 | 8.5 -> 7.5 | 26 -> 17 |
| enemy_attack | 18 | -14.1 -> -14.1 | 10.4 -> 7.7 | 10 -> 6 |
| enemy_special | 12 | -13.4 -> -13.4 | 10.2 -> 5.2 | 6 -> 6 |
| enemy_telegraph | 44 | -14.8 -> -14.8 | 6.2 -> 5.7 | 20 -> 14 |
| enemy_voice | 74 | -18.6 -> -18.6 | 3.3 -> 3.3 | 7 -> 5 |
| handling | 123 | -20.2 -> -20.2 | 10.0 -> 10.0 | 50 -> 50 |
| impact | 40 | -16.8 -> -16.8 | 15.2 -> 15.2 | 19 -> 19 |
| kill_effect | 28 | -20.2 -> -19.9 | 7.9 -> 6.4 | 9 -> 8 |
| music | 25 | -27.1 -> -27.1 | 1.0 -> 1.0 | 1 -> 1 |
| player | 14 | -23.2 -> -23.2 | 11.1 -> 11.1 | 9 -> 8 |
| ui | 62 | -17.2 -> -17.2 | 10.4 -> 9.8 | 15 -> 9 |
| weapon | 42 | -17.2 -> -17.2 | 9.1 -> 9.1 | 12 -> 12 |

Weapon, handling and impact are the weapon lanes' (unchanged here). The remaining flags
are mostly the "bright"/"dull" hints on sounds that are meant to be (boss rumbles, chimes,
hisses) and the micro UI ticks inside their -30 .. -24 band.

### Every change, before -> after

| sound | change | eff | % >4k / >8k | % <80 Hz | strongest tone |
|---|---|---|---|---|---|
| aqua_ambience | hp+eq | -31.9 -> -31.9 | 0/0 -> 0/0 | 65 -> 49 | 66% @ 54 -> 50% @ 54 Hz |
| aqua_jelly_charge | lp | -16.5 -> -16.8 | 34/7 -> 28/2 | 0 -> 0 | 5% @ 452 -> 6% @ 452 Hz |
| candy_gummy_wobble | trim | -23.3 -> -18.3 | 0/0 -> 0/0 | 0 -> 0 | 57% @ 118 -> 57% @ 118 Hz |
| city_blast_far | drive+hp+eq, trim | -15.7 -> -17.0 | 0/0 -> 0/0 | 98 -> 77 | 99% @ 65 -> 79% @ 65 Hz |
| city_buzz_loop | pitch | -20.3 -> -18.1 | 0/0 -> 0/0 | 77 -> 0 | 78% @ 54 -> 77% @ 97 Hz |
| city_siren_loop | trim | -9.3 -> -16.8 | 0/0 -> 0/0 | 0 -> 0 | 24% @ 646 -> 24% @ 646 Hz |
| city_sparks_loop | shelf, trim | -26.7 -> -23.8 | 28/2 -> 21/1 | 0 -> 0 | 27% @ 118 -> 32% @ 118 Hz |
| city_thunder | trim | -11.9 -> -12.9 | 0/0 -> 0/0 | 27 -> 27 | 38% @ 65 -> 38% @ 65 Hz |
| cos_equip_charm | lp+shelf, trim | -15.1 -> -16.1 | 19/12 -> 7/1 | 0 -> 0 | 29% @ 3951 -> 32% @ 3951 Hz |
| cos_kill_coins | lp+shelf | -20.2 -> -19.6 | 18/3 -> 12/0 | 0 -> 0 | 28% @ 2412 -> 30% @ 2412 Hz |
| cos_kill_ghost | trim | -15.9 -> -17.9 | 0/0 -> 0/0 | 0 -> 0 | 60% @ 398 -> 60% @ 398 Hz |
| cos_kill_popcorn | trim | -28.4 -> -21.9 | 5/0 -> 5/0 | 0 -> 0 | 4% @ 1421 -> 4% @ 1421 Hz |
| cos_kill_snow | lp+shelf | -17.2 -> -17.0 | 9/5 -> 3/1 | 0 -> 0 | 24% @ 3951 -> 25% @ 3521 Hz |
| cos_kill_thunder | trim | -24.8 -> -20.8 | 1/0 -> 1/0 | 15 -> 15 | 51% @ 108 -> 51% @ 108 Hz |
| cz_crawler_hiss_1 | lp | -19.2 -> -19.3 | 34/1 -> 27/0 | 0 -> 0 | 3% @ 700 -> 3% @ 700 Hz |
| cz_crawler_hiss_2 | trim | -14.0 -> -17.0 | 24/0 -> 24/0 | 0 -> 0 | 3% @ 3262 -> 3% @ 3262 Hz |
| cz_crawler_skitter | trim | -28.8 -> -22.8 | 10/0 -> 10/0 | 0 -> 0 | 6% @ 2616 -> 6% @ 2616 Hz |
| cz_riot_bash | trim | -7.3 -> -10.8 | 0/0 -> 0/0 | 4 -> 4 | 63% @ 129 -> 63% @ 129 Hz |
| cz_wrecker_charge | pitch+drive+hp+eq, trim | -10.0 -> -10.9 | 0/0 -> 0/0 | 57 -> 0 | 83% @ 75 -> 88% @ 108 Hz |
| cz_wrecker_debris | trim | -8.8 -> -10.8 | 2/1 -> 2/1 | 25 -> 25 | 95% @ 97 -> 95% @ 97 Hz |
| cz_wrecker_engine | pitch+hp | -13.2 -> -12.8 | 0/0 -> 0/0 | 75 -> 44 | 77% @ 43 -> 56% @ 65 Hz |
| cz_wrecker_impact | trim | -5.9 -> -9.4 | 0/0 -> 0/0 | 35 -> 35 | 68% @ 86 -> 68% @ 86 Hz |
| dune_ambience | lp | -32.1 -> -31.9 | 19/18 -> 2/0 | 50 -> 61 | 50% @ 43 -> 61% @ 43 Hz |
| dune_cadet_radio_1 | hp+lp | -18.2 -> -17.3 | 11/8 -> 1/0 | 0 -> 0 | 22% @ 657 -> 24% @ 657 Hz |
| dune_cadet_radio_2 | hp+lp | -18.0 -> -17.7 | 9/7 -> 1/0 | 0 -> 0 | 24% @ 689 -> 26% @ 689 Hz |
| dune_jet_burn | hp+lp | -12.7 -> -13.6 | 19/16 -> 3/1 | 32 -> 26 | 32% @ 65 -> 26% @ 65 Hz |
| end_boss_siren | hp | -15.8 -> -16.4 | 0/0 -> 0/0 | 44 -> 18 | 45% @ 65 -> 19% @ 65 Hz |
| end_supply_land | pitch+drive+hp+eq, trim | -15.7 -> -13.6 | 0/0 -> 0/0 | 55 -> 6 | 75% @ 75 -> 81% @ 97 Hz |
| end_trap_fire | drive+hp+eq, trim | -14.4 -> -13.6 | 0/0 -> 1/0 | 60 -> 24 | 67% @ 65 -> 31% @ 75 Hz |
| frost_ice_chip | pitch | -18.3 -> -17.5 | 9/1 -> 9/0 | 0 -> 0 | 91% @ 2476 -> 91% @ 1981 Hz |
| frost_ice_shatter | lp+shelf | -13.4 -> -13.2 | 26/9 -> 16/1 | 1 -> 1 | 29% @ 129 -> 38% @ 129 Hz |
| heartbeat | pitch+drive+hp+eq | -22.5 -> -20.1 | 0/0 -> 0/0 | 98 -> 65 | 99% @ 54 -> 97% @ 75 Hz |
| jungle_thunder | lp+shelf | -14.4 -> -16.6 | 46/36 -> 4/0 | 19 -> 33 | 23% @ 86 -> 39% @ 86 Hz |
| lava_bomb_whistle | trim | -9.6 -> -11.1 | 0/0 -> 0/0 | 0 -> 0 | 12% @ 1292 -> 12% @ 1292 Hz |
| lava_eruption_rumble | pitch+drive+hp+eq, trim | -13.2 -> -12.0 | 1/1 -> 0/0 | 98 -> 33 | 98% @ 54 -> 96% @ 86 Hz |
| mall_soda_shake | lp+shelf | -17.9 -> -18.4 | 52/3 -> 41/0 | 0 -> 0 | 3% @ 4091 -> 3% @ 4091 Hz |
| mall_soda_splash | lp+shelf | -18.9 -> -19.4 | 43/4 -> 30/0 | 0 -> 0 | 18% @ 926 -> 24% @ 926 Hz |
| mall_walker_whistle | pitch+lp, trim | -7.7 -> -12.4 | 0/0 -> 0/0 | 0 -> 0 | 93% @ 2896 -> 94% @ 2175 Hz |
| move_land_heavy | pitch+drive+hp+eq | -22.0 -> -19.5 | 0/0 -> 1/0 | 46 -> 2 | 98% @ 86 -> 97% @ 108 Hz |
| neon_spray_hiss | lp | -17.3 -> -16.0 | 73/7 -> 69/1 | 0 -> 0 | 3% @ 4694 -> 4% @ 4694 Hz |
| onb_blip | trim | -26.8 -> -21.8 | 2/0 -> 2/0 | 0 -> 0 | 54% @ 1378 -> 54% @ 1378 Hz |
| onb_complete | trim | -10.6 -> -13.1 | 7/0 -> 7/0 | 0 -> 0 | 17% @ 2218 -> 17% @ 2218 Hz |
| onb_ding | trim | -10.3 -> -13.3 | 3/0 -> 3/0 | 0 -> 0 | 84% @ 1755 -> 84% @ 1755 Hz |
| onb_step | trim | -13.0 -> -15.0 | 2/0 -> 2/0 | 0 -> 0 | 21% @ 2638 -> 21% @ 2638 Hz |
| prog_xp_tick | trim | -32.0 -> -28.0 | 0/0 -> 0/0 | 0 -> 0 | 92% @ 2218 -> 92% @ 2218 Hz |
| prz_shake | trim | -9.5 -> -14.0 | 0/0 -> 0/0 | 0 -> 0 | 80% @ 614 -> 80% @ 614 Hz |
| prz_shine | trim | -10.0 -> -14.0 | 0/0 -> 0/0 | 0 -> 0 | 19% @ 1174 -> 19% @ 1174 Hz |
| rounds_boss_beam | trim | -7.4 -> -10.4 | 0/0 -> 0/0 | 0 -> 0 | 17% @ 237 -> 17% @ 237 Hz |
| rounds_boss_charge | band-pass fix, drive+hp+eq, trim | -9.2 -> -10.7 | 0/0 -> 1/0 | 70 -> 41 | 100% @ 75 -> 60% @ 75 Hz |
| rounds_boss_charge_windup | band-pass fix | -13.4 -> -12.7 | 0/0 -> 0/0 | 0 -> 5 | 7% @ 474 -> 59% @ 97 Hz |
| rounds_boss_dazed | trim | -9.1 -> -11.1 | 0/0 -> 0/0 | 0 -> 0 | 23% @ 1184 -> 23% @ 1184 Hz |
| rounds_boss_defeat | band-pass fix, pitch+drive+hp+eq, trim | -120.3 -> -9.0 | 0/0 -> 0/0 | 0 -> 33 | 0% @ 0 -> 94% @ 86 Hz |
| rounds_boss_geyser | band-pass fix, drive+hp+eq | -13.8 -> -11.3 | 0/0 -> 13/2 | 39 -> 20 | 68% @ 75 -> 39% @ 86 Hz |
| rounds_boss_plate_break | band-pass fix | -13.8 -> -14.1 | 0/0 -> 1/0 | 0 -> 0 | 57% @ 1249 -> 56% @ 1249 Hz |
| rounds_boss_pound | band-pass fix, pitch+drive+hp+eq, trim | -7.7 -> -9.7 | 0/0 -> 0/0 | 85 -> 19 | 100% @ 75 -> 97% @ 97 Hz |
| rounds_boss_roar | band-pass fix, drive+hp+eq, trim | -7.7 -> -10.2 | 0/0 -> 0/0 | 100 -> 17 | 100% @ 65 -> 47% @ 86 Hz |
| rounds_boss_slam | trim | -7.5 -> -9.4 | 1/1 -> 1/1 | 52 -> 52 | 94% @ 86 -> 94% @ 86 Hz |
| rounds_boss_splash | band-pass fix | -10.7 -> -11.5 | 0/0 -> 1/0 | 0 -> 0 | 65% @ 226 -> 46% @ 226 Hz |
| rounds_boss_stone | band-pass fix, pitch+drive+hp+eq, trim | -12.7 -> -11.8 | 0/0 -> 0/0 | 47 -> 2 | 98% @ 86 -> 93% @ 108 Hz |
| rounds_boss_surface | band-pass fix, trim | -7.9 -> -10.5 | 0/0 -> 1/0 | 0 -> 0 | 85% @ 129 -> 78% @ 129 Hz |
| rounds_boss_thunder | band-pass fix, lp+shelf | -13.3 -> -14.0 | 84/39 -> 14/1 | 0 -> 13 | 2% @ 4554 -> 24% @ 183 Hz |
| rounds_boss_zone_hit | band-pass fix | -9.8 -> -11.0 | 0/0 -> 1/0 | 5 -> 5 | 95% @ 118 -> 94% @ 118 Hz |
| rounds_surge_hit | pitch+drive+hp+eq, trim | -10.3 -> -11.2 | 0/0 -> 0/0 | 68 -> 2 | 100% @ 75 -> 98% @ 97 Hz |
| rounds_wave_siege | drive+hp+eq | -13.7 -> -11.6 | 0/0 -> 0/0 | 39 -> 20 | 79% @ 86 -> 81% @ 86 Hz |
| sky_dive_whistle | trim | -9.0 -> -11.0 | 0/0 -> 0/0 | 0 -> 0 | 8% @ 1174 -> 8% @ 1174 Hz |
| sky_gale_horn | trim | -8.9 -> -10.9 | 0/0 -> 0/0 | 16 -> 16 | 88% @ 108 -> 88% @ 108 Hz |
| ui_hover | trim | -31.5 -> -28.0 | 0/0 -> 0/0 | 0 -> 0 | 99% @ 1314 -> 99% @ 1314 Hz |
| ui_select | trim | -25.9 -> -21.9 | 0/0 -> 0/0 | 0 -> 0 | 99% @ 1174 -> 99% @ 1174 Hz |
| ui_tab | trim | -27.8 -> -23.8 | 0/0 -> 0/0 | 0 -> 0 | 99% @ 991 -> 99% @ 991 Hz |
| ui_tick | trim | -37.1 -> -30.1 | 15/3 -> 15/3 | 0 -> 0 | 6% @ 2713 -> 6% @ 2713 Hz |

Accepted on purpose: `player_hurt` (-15.2) sits above the player band (it must cut
through a fight); `mall_walker_whistle` and `frost_ice_chip` remain single tones (that is
what they are) but lower and quieter; `cine_startup` is the showreel's intro, not
gameplay; `heartbeat` keeps a low body (65 % below 80 Hz, now with audible harmonics).

### Sheets

Every family, before and after: `docs/sound_audit/before/<family>_<page>.jpg` and
`docs/sound_audit/after/<family>_<page>.jpg` (log frequency 30 Hz - 18 kHz upwards, time
left to right, -80 .. 0 dBFS; label: name, length, in-game level; red label = flagged).
Changed families: `cue_1`, `cue_2`, `enemy_attack_1`, `enemy_special_1`,
`enemy_telegraph_1`, `enemy_voice_*`, `ambience_1`, `ambience_bed_1`, `kill_effect_1`,
`player_1`, `ui_*`, `impact_1` (frost chip).

### Re-running

    python3 tools/sound_audit.py --csv docs/sound_audit/after.csv --sheets docs/sound_audit/after
    python3 tools/audio_mix_report.py --all      # the per-call-site mix report the audit builds on


## Weapons (hand-off to snd_wpn_a / snd_wpn_b)

`python3 tools/sound_audit_weapons.py [audit.csv]` checks each weapon's fire sound
against its ceiling (-17 for a fast auto, -14, -11 for a big shot every 0.4 s or slower)
and floor (-20, -22 for a fast auto).

Weapon-owned sounds the audit flags (before). `eff` dB, centroid Hz, % above 4/8 kHz,
% below 80 Hz.

| sound | family | pack | eff | cent | hf4 / hf8 | low80 | flags |
|---|---|---|---|---|---|---|---|
| gc_equip | handling | ground_control | -25.4 | 1444 | 0.2 / 0.0 | 0 | whistle 1755Hz 43% |
| gc_overcharge | handling | ground_control | -23.8 | 2422 | 11.4 / 1.8 | 0 | whistle 1960Hz 28% |
| gc_ready | handling | ground_control | -14.6 | 2062 | 2.8 / 0.0 | 0 | loud+6 | whistle 2089Hz 74% |
| gc_sat | handling | ground_control | -11.6 | 2166 | 0.3 / 0.0 | 0 | loud+9 |
| gn2_ring_catch | handling | guns_new2 | -16.5 | 1937 | 9.8 / 0.3 | 0 | whistle 1572Hz 72% |
| gn2_sparkler_fizz | handling | guns_new2 | -21.6 | 2715 | 15.1 / 0.0 | 0 | bright 1.6oct |
| gn8_dunk_pump | handling | guns8 | -33.3 | 1263 | 0.1 / 0.0 | 0 | quiet-13 |
| gn8b_shutter_ready | handling | guns8b | -17.3 | 1373 | 2.9 / 0.0 | 0 | whistle 1755Hz 46% |
| hub_flip | handling | hubcap | -28.4 | 1223 | 0.0 / 0.0 | 0 | quiet-8 |
| hub_spin_loop | handling | hubcap | -15.4 | 188 | 0.0 / 0.0 | 0 | click 65% | dull 2.3oct |
| jp_clunk | handling | jack_pot | -24.5 | 314 | 0.0 / 0.0 | 0 | dull 1.5oct |
| jp_grab | handling | jack_pot | -29.1 | 2600 | 9.4 / 0.1 | 0 | quiet-9 | bright 1.5oct |
| jp_pluck | handling | jack_pot | -15.0 | 1114 | 0.1 / 0.0 | 0 | loud+5 |
| jp_poof | handling | jack_pot | -19.4 | 1996 | 1.5 / 0.0 | 0 | whistle 2089Hz 72% |
| jp_reload | handling | jack_pot | -20.8 | 261 | 0.0 / 0.0 | 0 | dull 1.8oct |
| mdm_reload | handling | markdown_marker | -19.1 | 1361 | 5.8 / 0.2 | 0 | whistle 1572Hz 47% |
| pcp_equip | handling | popcorn_popper | -27.4 | 1784 | 9.5 / 0.0 | 0 | whistle 2099Hz 27% |
| pcp_holo | handling | popcorn_popper | -12.1 | 536 | 0.3 / 0.0 | 0 | loud+8 |
| pcp_jam | handling | popcorn_popper | -17.9 | 2864 | 15.7 / 0.4 | 0 | whistle 2336Hz 31% | bright 1.7oct |
| pcp_scoop | handling | popcorn_popper | -17.3 | 4485 | 58.0 / 3.5 | 0 | hf4k 58% | bright 2.3oct |
| pcp_stage | handling | popcorn_popper | -19.9 | 1266 | 0.5 / 0.0 | 0 | whistle 1324Hz 56% |
| reload_materialize | handling | core | -16.4 | 1025 | 0.0 / 0.0 | 0 | whistle 1314Hz 29% |
| reload_spin | handling | core | -22.9 | 222 | 0.1 / 0.0 | 33 | dc | dull 2.0oct |
| sz_charge | handling | strike_zone | -20.9 | 198 | 0.0 / 0.0 | 0 | dull 2.2oct |
| sz_clunk | handling | strike_zone | -12.3 | 199 | 0.0 / 0.0 | 2 | loud+8 | dull 2.2oct |
| sz_hop | handling | strike_zone | -18.3 | 181 | 0.0 / 0.0 | 2 | dull 2.3oct |
| sz_rail | handling | strike_zone | -12.0 | 784 | 2.4 / 0.0 | 0 | loud+8 |
| sz_reload | handling | strike_zone | -22.1 | 310 | 0.0 / 0.0 | 0 | dull 1.6oct |
| sz_roll_up | handling | strike_zone | -14.7 | 117 | 0.0 / 0.0 | 37 | loud+6 | mud 37% | dull 3.0oct |
| tm6_lock | handling | t_minus_six | -14.3 | 1715 | 0.6 / 0.0 | 0 | loud+6 | whistle 1324Hz 78% |
| tm6_lock_full | handling | t_minus_six | -13.2 | 2110 | 4.1 / 0.2 | 0 | loud+7 | whistle 1755Hz 62% |
| weap_arc_reload | handling | weapons | -19.3 | 4315 | 37.6 / 26.3 | 0 | hf8k 26% | bright 2.2oct |
| weap_cryo_vent | handling | weapons | -16.5 | 5768 | 50.2 / 40.5 | 0 | hf8k 40% | bright 2.7oct |
| weap_lava_flip | handling | lava_lampoon | -14.9 | 908 | 0.0 / 0.0 | 1 | loud+5 |
| weap_lava_glug | handling | lava_lampoon | -16.3 | 248 | 0.0 / 0.0 | 0 | dull 1.9oct |
| weap_lava_lift | handling | lava_lampoon | -10.7 | 297 | 0.0 / 0.0 | 0 | loud+10 | dull 1.6oct |
| weap_lava_miss | handling | lava_lampoon | -22.6 | 262 | 0.0 / 0.0 | 0 | dull 1.8oct |
| weap_lava_pop | handling | lava_lampoon | -19.3 | 1180 | 0.0 / 0.0 | 0 | whistle 2347Hz 35% |
| weap_lava_ripple | handling | lava_lampoon | -14.2 | 866 | 0.1 / 0.0 | 0 | loud+6 |
| weap_rail_ready | handling | weapons | -15.8 | 3173 | 0.4 / 0.0 | 0 | whistle 2638Hz 59% | bright 1.8oct |
| weap_rail_reload | handling | weapons | -19.4 | 2434 | 19.6 / 15.9 | 0 | hf8k 16% |
| weap_rip_ready | handling | guns_new1 | -16.1 | 1474 | 0.0 / 0.0 | 0 | whistle 1324Hz 77% |
| weap_rip_reload | handling | guns_new1 | -23.0 | 3474 | 32.4 / 4.2 | 0 | hf4k 32% | bright 1.9oct |
| weap_ripsaw_idle | handling | ripsaw | -15.4 | 130 | 0.0 / 0.0 | 63 | mud 63% | click 8% | dull 2.8oct |
| weap_ripsaw_rev | handling | ripsaw | -16.9 | 142 | 0.0 / 0.0 | 46 | mud 46% | dull 2.7oct |
| weap_ripsaw_sputter | handling | ripsaw | -22.7 | 154 | 0.0 / 0.0 | 35 | dull 2.6oct |
| weap_ripsaw_start | handling | ripsaw | -21.6 | 213 | 0.0 / 0.0 | 39 | mud 39% | dull 2.1oct |
| weap_whirl_jackpot | handling | guns_new1 | -16.8 | 1579 | 0.8 / 0.6 | 0 | whistle 1314Hz 51% |
| yoyo_roll_loop | handling | yoyo_loco | -17.8 | 430 | 0.0 / 0.0 | 0 | click 25% |
| yoyo_whirl | handling | yoyo_loco | -14.3 | 714 | 0.0 / 0.0 | 0 | loud+6 |
| gc_bounce | impact | ground_control | -11.7 | 899 | 0.0 / 0.0 | 0 | loud+5 |
| gc_strike | impact | ground_control | -28.0 | 1272 | 0.1 / 0.0 | 0 | quiet-11 | whistle 1755Hz 66% |
| gn8_twister_pop | impact | guns8 | -7.4 | 126 | 0.1 / 0.0 | 31 | loud+9 | dull 2.5oct |
| gn8b_balloon_pop | impact | guns8b | -14.5 | 166 | 0.0 / 0.0 | 0 | dull 2.1oct |
| jp_boing | impact | jack_pot | -12.0 | 207 | 0.1 / 0.0 | 1 | dull 1.7oct |
| jp_punch | impact | jack_pot | -16.7 | 96 | 0.0 / 0.0 | 24 | dull 2.8oct |
| mdm_pop | impact | markdown_marker | -11.8 | 2016 | 9.1 / 0.3 | 0 | whistle 1572Hz 64% | bright 1.5oct |
| mdm_stick | impact | markdown_marker | -27.3 | 1664 | 0.0 / 0.0 | 0 | quiet-11 |
| pcp_pop | impact | popcorn_popper | -31.1 | 633 | 0.1 / 0.0 | 0 | quiet-14 |
| pcp_puff | impact | popcorn_popper | -27.5 | 2092 | 22.5 / 0.0 | 0 | quiet-11 | bright 1.6oct |
| sz_bonk | impact | strike_zone | -13.7 | 129 | 0.0 / 0.0 | 17 | dull 2.4oct |
| sz_thud | impact | strike_zone | -13.2 | 83 | 0.0 / 0.0 | 47 | mud 47% | dull 3.1oct |
| tm6_pop | impact | t_minus_six | -16.1 | 238 | 1.4 / 0.2 | 0 | dull 1.5oct |
| weap_cryo_freeze | impact | weapons | -17.9 | 4341 | 25.5 / 9.6 | 0 | hf8k 10% | whistle 3521Hz 49% | bright 2.6oct |
| weap_cryo_shatter | impact | weapons | -15.4 | 3970 | 54.1 / 0.2 | 0 | hf4k 54% | bright 2.5oct |
| yoyo_grind_loop | impact | yoyo_loco | -17.2 | 573 | 0.1 / 0.0 | 2 | click 7% |
| yoyo_hit | impact | yoyo_loco | -19.8 | 147 | 0.0 / 0.0 | 0 | dull 2.2oct |
| yoyo_trip | impact | yoyo_loco | -22.3 | 205 | 0.0 / 0.0 | 5 | dull 1.8oct |
| gc_fire | weapon | ground_control | -17.3 | 1023 | 0.0 / 0.0 | 0 | whistle 1324Hz 60% |
| mdm_fire | weapon | markdown_marker | -21.4 | 1718 | 0.2 / 0.0 | 0 | bright 2.1oct |
| sz_fire | weapon | strike_zone | -14.5 | 114 | 0.0 / 0.0 | 11 | dull 1.8oct |
| sz_roll_loop | weapon | strike_zone | -19.8 | 95 | 0.0 / 0.0 | 71 | mud 71% | click 70% | dull 2.1oct |
| tm6_launch | weapon | t_minus_six | -25.9 | 2740 | 25.6 / 0.1 | 0 | quiet-9 | bright 2.8oct |
| weap_arc_chain | weapon | weapons | -23.6 | 4234 | 55.3 / 1.6 | 0 | hf4k 55% | bright 3.4oct |
| weap_arc_fire | weapon | weapons | -17.5 | 1318 | 13.6 / 0.7 | 0 | bright 1.7oct |
| weap_cryo_loop | weapon | weapons | -20.2 | 2034 | 21.4 / 1.8 | 0 | click 17% | bright 2.4oct |
| weap_cryo_start | weapon | weapons | -17.3 | 1984 | 9.5 / 0.0 | 0 | bright 2.3oct |
| weap_lobber_boom | weapon | weapons | -11.0 | 345 | 2.1 / 1.7 | 37 | loud+6 | mud 37% |
| weap_rail_fire | weapon | weapons | -12.6 | 181 | 0.4 / 0.2 | 77 | mud 77% |
| weap_rip_reel | weapon | guns_new1 | -22.7 | 2158 | 7.4 / 5.8 | 0 | bright 2.4oct |

Most important for the weapon lanes:
- **Loop seams click** (`click` = the jump at the loop point): `hub_spin_loop` 65 %,
  `sz_roll_loop` 70 %, `yoyo_roll_loop` 25 %, `weap_cryo_loop` 17 %, `yoyo_grind_loop`,
  `weap_ripsaw_idle`. Render them circularly (whole cycles, or cross-fade the end into
  the start).
- **Whistles** (one pure tone holding most of the energy): `gc_ready` 74 % at 2.1 kHz,
  `gc_equip`, `gc_strike`, `gc_fire` 60 % at 1.3 kHz, `tm6_lock` 78 %, `tm6_lock_full`,
  `weap_rip_ready` 77 %, `weap_rail_ready` 59 % at 2.6 kHz, `gn2_ring_catch` 72 %,
  `jp_poof` 72 %, `mdm_pop`, `mdm_reload`, `pcp_stage`, `weap_whirl_jackpot`,
  `weap_cryo_freeze` 49 % at 3.5 kHz. Give them a second partial or noise, or low-pass.
- **Harsh**: `weap_cryo_vent` 40 % above 8 kHz, `weap_arc_reload` 26 %, `weap_rail_reload`
  16 %, `weap_cryo_shatter` 54 % above 4 kHz, `weap_arc_chain` 55 %, `pcp_scoop` 58 %.
- **Mud**: `weap_rail_fire` 77 % below 80 Hz, `weap_ripsaw_idle` 63 %, `sz_roll_loop` 71 %,
  `sz_thud`, `weap_lobber_boom` 37 %: move the punch to 80-150 Hz.
- **Level**: `gn8_twister_pop` -7.4 and `weap_lobber_boom` -11 are the loudest weapon
  sounds; `weap_lava_lift` -10.7, `gc_sat`, `pcp_holo`, `sz_rail`, `sz_clunk` are handling
  sounds louder than most shots; `tm6_launch` -25.9, `pcp_pop` -31, `pcp_puff`, `mdm_stick`,
  `gn8_dunk_pump` -33 are lost.

## Final weapon check (after merging u15-snd_wpn_a and u15-snd_wpn_b)

Both weapon branches merged into this branch; `audio/mix.tres` conflict resolved by keeping
every trim from both sides (`empty_click` from snd_wpn_b, its owner). Re-audited
(`docs/sound_audit/after.csv`, `after/` sheets include the new weapon sounds) and only
weapon **trims** adjusted:

| sound | eff before trim | new trim | why |
|---|---|---|---|
| weap_cryo_start | -15.2 | -2.0 | an auto's start over the -17 auto ceiling |
| weap_rail_fire | -13.4 | -2.0 (was -1.5) | over -14 |
| weap_rip_fire | -13.7 | -1.5 (was -1.0) | over -14 |
| mdm_fire | -20.8 | +1.0 | under the -20 floor |
| yoyo_throw | -21.0 | -2.5 (was -3.5) | under the -20 floor |
| gc_sat, pcp_holo, sz_clunk, sz_rail, weap_lava_lift | -10.7 .. -12.4 | -3.0 .. -5.0 | handling cues louder than the guns; now -15.5 |
| weap_lava_flip, weap_lava_ripple, gc_ready, sz_roll_up, hub_spin_loop, weap_ripsaw_idle | -14.2 .. -15.4 | -0.5 .. -3.5 | over the -16 handling ceiling |
| gn8_twister_pop | -11.8 | -5.0 (was -4.0) | over the -13 impact ceiling |

Every weapon fire sound now sits inside its band (`tools/sound_audit_weapons.py`):

| weapon | fire sound | ceiling | eff | crest | % >4 kHz | % <80 Hz |
|---|---|---|---|---|---|---|
| arc_coil | weap_arc_fire | -17 | -17.5 -> -17.1 | 12.2 -> 9.9 | 13.6 -> 6.3 | 0 -> 1 |
| balloon_darter | gn8b_dart_fire | -14 | -19.7 -> -19.1 | 11.0 -> 12.3 | 0.0 -> 0.0 | 0 -> 6 |
| bumper_lobber | weap_lobber_fire | -11 | -13.5 -> -13.6 | 6.0 -> 6.8 | 0.0 -> 0.0 | 0 -> 0 |
| comet_cannon | weap_cannon_fire | -11 | -13.6 -> -13.7 | 6.6 -> 9.3 | 1.2 -> 0.6 | 14 -> 28 |
| cryo_beam | weap_cryo_start | -17 | -17.3 -> -17.2 | 14.3 -> 12.3 | 9.5 -> 5.4 | 0 -> 0 |
| drum_popper | weap_popper_fire | -14 | -15.7 -> -15.7 | 7.7 -> 9.5 | 0.0 -> 0.0 | 5 -> 6 |
| dunk_tank | gn8_dunk_fire | -17 | -21.9 -> -22.0 | 12.5 -> 12.3 | 0.7 -> 0.6 | 0 -> 3 |
| ground_control | gc_fire | -14 | -17.3 -> -16.8 | 15.1 -> 12.8 | 0.0 -> 0.0 | 0 -> 0 |
| hubcap_boomerang | hub_throw | -11 | -17.2 -> -16.4 | 13.5 -> 12.6 | 0.3 -> 0.2 | 0 -> 0 |
| ion_carbine | carbine_fire | -17 | -18.4 -> -18.2 | 10.2 -> 10.5 | 4.8 -> 3.8 | 0 -> 0 |
| jack_pot | jp_fire | -11 | -16.3 -> -15.4 | 11.7 -> 11.1 | 0.0 -> 0.0 | 0 -> 23 |
| lava_lampoon | weap_lava_fire | -17 | -15.5 -> -17.2 | 8.9 -> 7.7 | 0.4 -> 0.2 | 0 -> 0 |
| markdown_marker | mdm_fire | -14 | -21.4 -> -19.8 | 14.5 -> 15.3 | 0.2 -> 0.1 | 0 -> 0 |
| popcorn_popper | pcp_fire | -17 | -17.8 -> -18.9 | 9.0 -> 8.1 | 0.1 -> 0.0 | 0 -> 0 |
| pulse_pistol | pistol_fire | -14 | -15.8 -> -15.2 | 9.7 -> 11.0 | 4.2 -> 1.5 | 0 -> 1 |
| rail_lancer | weap_rail_fire | -14 | -12.6 -> -13.9 | 6.0 -> 8.0 | 0.4 -> 0.3 | 77 -> 21 |
| ring_toss | gn2_ring_fire | -11 | -16.6 -> -15.2 | 12.9 -> 12.0 | 0.0 -> 0.0 | 0 -> 4 |
| riptide | weap_rip_fire | -14 | -13.7 -> -14.2 | 8.0 -> 8.5 | 0.0 -> 0.0 | 0 -> 1 |
| scatter_blaster | scatter_fire | -11 | -12.4 -> -13.1 | 6.1 -> 6.3 | 3.8 -> 2.5 | 5 -> 7 |
| shutterbug | gn8b_shutter_fire | -11 | -15.7 -> -14.7 | 11.4 -> 11.5 | 0.0 -> 0.0 | 0 -> 9 |
| sparkler | gn2_sparkler_fire | -17 | -21.0 -> -21.6 | 12.1 -> 13.2 | 2.5 -> 2.0 | 0 -> 1 |
| strike_zone | sz_fire | -14 | -14.5 -> -14.0 | 12.2 -> 11.4 | 0.0 -> 0.0 | 11 -> 13 |
| t_minus_six | tm6_fire | -14 | -17.3 -> -16.4 | 13.7 -> 12.7 | 5.6 -> 1.2 | 0 -> 1 |
| teacup_twister | gn8_twister_fire | -11 | -13.7 -> -13.3 | 9.9 -> 10.0 | 0.0 -> 0.0 | 0 -> 1 |
| toxic_ripsaw | weap_ripsaw_fire | -11 | -12.4 -> -12.7 | 7.6 -> 8.7 | 0.0 -> 0.0 | 1 -> 2 |
| whirligig | weap_whirl_fire | -17 | -21.3 -> -21.0 | 7.7 -> 6.8 | 0.0 -> 0.0 | 0 -> 0 |
| yoyo_loco | yoyo_throw | -14 | -23.1 -> -20.0 | 18.0 -> 13.1 | 0.4 -> 0.1 | 0 -> 2 |

Still open for the weapon sounds (generator work, not trims): loop seams that click
(`sz_roll_loop` 70 %, `hub_spin_loop` 65 %, `yoyo_roll_loop` 25 %, `weap_cryo_loop` 9 %,
`weap_ripsaw_idle` 8 %, `yoyo_grind_loop` 7 %) and single-tone "whistles" on ready/lock
cues (`weap_rip_ready` 76 %, `tm6_lock` 78 %, `gn2_ring_catch` 72 %, `jp_poof` 72 %,
`mdm_pop` 74 %, `weap_rail_ready` 65 % at 2.6 kHz).
