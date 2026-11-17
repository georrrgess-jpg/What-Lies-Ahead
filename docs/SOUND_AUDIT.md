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

Flags: louder than the family median by > 5 dB or quieter by > 8 dB; > 6 % above
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
| cue (waves, gates, bosses, Endless events) | -18 .. -10 | boss slams and the boss defeat may reach -9 |
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

## Weapons (hand-off to snd_wpn_a / snd_wpn_b)

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
