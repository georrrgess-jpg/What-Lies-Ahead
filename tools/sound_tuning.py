"""House tuning: a per-sound post-process applied by tools/gen_audio.py as it
writes each file (write_wav, write_loop_wav, write_music), so a retune found by
the sound audit (tools/sound_audit.py, docs/SOUND_AUDIT.md) is reproducible and
survives any regeneration.

TUNING maps a sound name (its _b/_c takes inherit it) to:
    hp      high-pass (Hz, 4th order): clears rumble small speakers turn into mud
    lp      low-pass (Hz, 4th order): takes the fizz and whistle off the top
    bells   ((centre Hz, gain dB, Q), ...): peaking EQ
    shelf   (corner Hz, gain dB): gentle high shelf (negative = darker)
    pitch   playback-rate factor (1.12 = about two semitones up, and shorter)
    drive   soft saturation (tanh) before the EQ: gives a pure sub sine the
            harmonics that let small speakers play it
    seam    loops only: crossfade (ms) of the loop's last stretch into its
            start, so the end flows into the start without a click (the loop
            gets that much shorter)
Volume is not set here (write_wav normalises the peak): it lives in the
per-sound trims of audio/mix.tres.

    python3 tools/gen_audio.py <pack> --only=name1,name2   rewrite just those files
    python3 tools/gen_audio.py --tuned                       rewrite every sound listed here
"""
import re

import numpy as np

SR = 44100

# Punch for sounds whose energy sat below 80 Hz (inaudible on small speakers,
# mud on big ones): clear the sub, lift the 120-180 Hz body.
_PUNCH = {"drive": 2.5, "hp": 75.0, "bells": ((140.0, 3.0, 0.9),)}
_DEEP_PUNCH = {"drive": 3.0, "hp": 70.0, "bells": ((120.0, 4.0, 0.8), (300.0, 2.0, 1.0))}

_FOURTH = 2 ** (5 / 12)

TUNING = {
    # The Strike Zone's rolling loop clicked at its seam (the jump at the wrap
    # was larger than 93 % of the loop's own sample steps; now 23 %). The
    # audit's seam "click" also flags hub_spin_loop, yoyo_roll_loop and
    # weap_cryo_loop, but their wraps are ordinary steps (20-55th percentile).
    "sz_roll_loop": {"seam": 40.0},
    "hub_spin_loop": {"seam": 40.0},
    # Mud -> punch (audit: > 35 % of the energy below 80 Hz).
    "rounds_boss_pound": dict(_DEEP_PUNCH, pitch=_FOURTH),     # a 75 Hz sine thump -> 100 Hz
    "rounds_boss_defeat": dict(_DEEP_PUNCH, pitch=_FOURTH),    # (a fourth keeps the fanfare on the A440 grid)
    "rounds_boss_roar": _PUNCH,
    "rounds_boss_charge": _PUNCH,
    "rounds_boss_stone": dict(_PUNCH, pitch=_FOURTH),
    "rounds_boss_geyser": _PUNCH,
    "rounds_surge_hit": dict(_PUNCH, pitch=_FOURTH),
    "rounds_wave_siege": _PUNCH,
    "lava_eruption_rumble": dict(_DEEP_PUNCH, pitch=1.6),        # a 56 Hz drone -> 90 Hz
    "end_trap_fire": _PUNCH,
    "end_supply_land": dict(_PUNCH, pitch=_FOURTH),
    "end_boss_siren": {"hp": 70.0},
    "cz_wrecker_engine": dict(_PUNCH, pitch=1.25),
    "cz_wrecker_charge": dict(_PUNCH, pitch=_FOURTH),
    "move_land_heavy": dict(_PUNCH, pitch=_FOURTH),
    "city_blast_far": _DEEP_PUNCH,
    "city_buzz_loop": {"pitch": 2.0},                       # a 54 Hz drone -> a 108 Hz mains buzz
    "heartbeat": {"pitch": 1.35, "drive": 2.0, "hp": 45.0, "bells": ((150.0, 4.0, 0.8),)},
    "aqua_ambience": {"hp": 50.0, "bells": ((90.0, -3.0, 0.8),)},
    # Harsh -> warm (audit: > 6 % above 8 kHz or > 30 % above 4 kHz).
    "rounds_boss_thunder": {"lp": 6500.0, "shelf": (3000.0, -3.0)},
    "jungle_thunder": {"lp": 6000.0, "shelf": (2500.0, -4.0)},
    "dune_ambience": {"lp": 7000.0},
    "mall_soda_shake": {"lp": 6000.0, "shelf": (3000.0, -2.0)},
    "mall_soda_splash": {"lp": 6500.0, "shelf": (3000.0, -2.0)},
    "neon_spray_hiss": {"lp": 7500.0},
    "frost_ice_shatter": {"lp": 8000.0, "shelf": (4000.0, -3.0)},
    "aqua_jelly_charge": {"lp": 8000.0},
    "dune_jet_burn": {"lp": 7000.0, "hp": 60.0},
    "cz_crawler_hiss_1": {"lp": 6000.0},
    "dune_cadet_radio_1": {"hp": 250.0, "lp": 5500.0},
    "dune_cadet_radio_2": {"hp": 250.0, "lp": 5500.0},
    "cos_equip_charm": {"lp": 8000.0, "shelf": (4000.0, -3.0)},
    "cos_kill_coins": {"lp": 9000.0, "shelf": (4000.0, -2.0)},
    "cos_kill_snow": {"lp": 8000.0, "shelf": (4000.0, -2.0)},
    "city_sparks_loop": {"shelf": (4000.0, -3.0)},
    # Whistles (one pure tone above 2 kHz holding most of the sound) -> lower.
    "mall_walker_whistle": {"pitch": 0.75, "lp": 4000.0},
    "frost_ice_chip": {"pitch": 0.8},
}


def tuning_for(name):
    """The entry for `name` or for the sound it is a take of (name_b, name_c)."""
    if name in TUNING:
        return TUNING[name]
    return TUNING.get(re.sub(r"_[bc]$", "", name))


def _gain(n, t):
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    g = np.ones_like(f)
    if t.get("hp"):
        g /= np.sqrt(1.0 + (t["hp"] / f) ** 8)
    if t.get("lp"):
        g /= np.sqrt(1.0 + (f / t["lp"]) ** 8)
    for fc, gain_db, q in t.get("bells", ()):
        a = 10 ** (gain_db / 40.0)
        w = f / fc
        g *= np.sqrt(((1 - w * w) ** 2 + (w * a / q) ** 2) / ((1 - w * w) ** 2 + (w / (a * q)) ** 2))
    if t.get("shelf"):
        fc, gain_db = t["shelf"]
        g *= 10 ** (gain_db * (f * f / (f * f + fc * fc)) / 20.0)
    return g


def _repitch(x, factor, loop):
    n = len(x)
    idx = np.arange(0, n - (0 if loop else 1), factor)
    src = np.arange(n + 1) if loop else np.arange(n)
    if x.ndim == 1:
        return np.interp(idx, src, np.concatenate([x, x[:1]]) if loop else x)
    return np.stack([np.interp(idx, src, np.concatenate([c, c[:1]]) if loop else c) for c in x.T], axis=1)


def apply(name, x, loop=False):
    """`x` (mono, or (n, 2)) with its tuning; untouched when it has none.
    One-shots are padded so the zero-phase EQ does not wrap the tail onto the
    attack; loops are filtered circularly so they stay seamless."""
    t = tuning_for(name)
    if not t:
        return x
    x = np.asarray(x, dtype=np.float64)
    if t.get("pitch"):
        x = _repitch(x, t["pitch"], loop)
    if t.get("drive"):
        x = np.tanh(t["drive"] * x / max(1e-9, np.max(np.abs(x)))) / np.tanh(t["drive"])
    if any(k in t for k in ("hp", "lp", "bells", "shelf")):
        pad = 0 if loop else int(0.25 * SR)
        n = len(x) + 2 * pad
        shape = (pad, pad) if x.ndim == 1 else ((pad, pad), (0, 0))
        spec = np.fft.rfft(np.pad(x, shape), axis=0)
        g = _gain(n, t)
        spec *= g if x.ndim == 1 else g[:, None]
        x = np.fft.irfft(spec, n, axis=0)[pad:pad + len(x) if pad else None]
    if loop and t.get("seam"):
        x = _seam(x, int(t["seam"] * SR / 1000.0))
    return x


def _seam(x, k):
    """Fades the last `k` samples into the first `k` and drops them: the new
    last sample is the one that came just before them, so the wrap is smooth."""
    if k <= 0 or 2 * k >= len(x):
        return x
    n = len(x)
    r = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, k))
    if x.ndim > 1:
        r = r[:, None]
    out = x[:n - k].copy()
    out[:k] = x[:k] * r + x[n - k:] * (1.0 - r)
    return out
