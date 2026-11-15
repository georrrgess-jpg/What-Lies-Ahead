"""Ground Control (ground_control), the radar-ping primary: sonar pings,
rising charge whines, radar beeps, a crackling overcharge and a satellite
docking chime. Round and glassy rather than shrill. All names start with
"gc_" (audio/mix.tres puts the shots on "weapon", strikes and bounces on
"impact", the rest on "handling").

    python tools/gen_audio.py ground_control
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump


def _ping(freq, d, gain=1.0, decay=1.6):
    """A sonar ping: a pure tone with a soft octave and a slow ring-out."""
    body = tone(freq, d) + tone(freq * 2.0, d) * 0.18 + tone(freq * 3.01, d) * 0.06
    return body * env(d, 0.002, d, power=decay) * gain


def _whoomp(d, f0, f1, gain=1.0):
    """The ring leaving the dish: a low swept thump under a breathy rush."""
    rush = band(noise(d), 900, 900) * env(d, 0.004, d * 0.7, power=1.4) * 0.35
    return (_sub_thump(f0, f1, d, d * 0.45) * 1.2 + rush) * gain


def gc_fire():
    """A ping: the dish thumps and a bright sonar note rings away."""
    d = 0.55
    out = _whoomp(0.3, 220, 90, 0.9)
    out = np.concatenate([out, silence(d - 0.3)])
    place(out, _ping(1320, 0.5, 0.55), 0.0, 1.0)
    place(out, _ping(990, 0.4, 0.25), 0.03, 1.0)
    return filt(out, low=7500)


def gc_fire_big():
    """The full charge on top of the ping: a deep, wide sonar boom."""
    d = 0.9
    out = _whoomp(0.5, 140, 45, 1.1)
    out = np.concatenate([out, silence(d - 0.5)])
    place(out, _ping(440, 0.85, 0.5, decay=1.2), 0.0, 1.0)
    place(out, _ping(660, 0.6, 0.22), 0.05, 1.0)
    return filt(out, low=6000)


def gc_feedback():
    """The overcharged feedback blast: a screeching squeal folding into a boom."""
    d = 0.9
    t = t_axis(0.35)
    squeal = osc(2 * np.pi * np.cumsum(2400 - 1600 * (t / 0.35)) / SR, "tri") * env(0.35, 0.005, 0.35, power=1.2) * 0.35
    out = _whoomp(0.55, 120, 40, 1.3)
    out = np.concatenate([out, silence(d - 0.55)])
    place(out, squeal, 0.0, 1.0)
    place(out, crush(band(noise(0.4), 3000, 2500), 3.0) * env(0.4, 0.002, 0.25) * 0.25, 0.0, 1.0)
    place(out, _ping(523, 0.8, 0.45, decay=1.3), 0.04, 1.0)
    return filt(out, low=7000)


def gc_charge():
    """Charging: a rising radar whine with a quickening pulse (0.8 s to full)."""
    d = 0.85
    t = t_axis(d)
    freq = 260 + 900 * (t / d) ** 1.4
    whine = osc(2 * np.pi * np.cumsum(freq) / SR, "tri") * 0.25
    pulse = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(6 + 18 * t / d) / SR)
    return filt(whine * pulse * env(d, 0.04, d, power=0.5, release=0.04), low=5000)


def gc_ready():
    """Full charge: a two-note lock-on chirp."""
    out = silence(0.25)
    place(out, _ping(1568, 0.12, 0.4, decay=2.5), 0.0, 1.0)
    place(out, _ping(2093, 0.15, 0.4, decay=2.5), 0.06, 1.0)
    return out


def gc_step():
    """A charge step: one short radar beep (pitched up per step in game)."""
    return _ping(1175, 0.12, 0.5, decay=2.8)


def gc_overcharge():
    """Overcharged: an electric crackle over a warbling feedback tone."""
    d = 0.7
    t = t_axis(d)
    crackle = band(noise(d), 4000, 3000) * (np.random.default_rng(31).random(len(t)) > 0.985) * 3.0
    warble = tone(1900, d, "tri", vibrato=0.04, vib_rate=11.0) * 0.18
    return filt((crackle + warble) * env(d, 0.01, d, power=0.8, release=0.05), low=8000)


def gc_stall():
    """Stalled: the whine dies in a fizz of static and a dull clunk."""
    d = 0.8
    t = t_axis(d)
    die = osc(2 * np.pi * np.cumsum(1200 * np.exp(-t * 4.0) + 60) / SR, "tri") * env(d, 0.003, 0.5, power=1.2) * 0.3
    hiss = band(noise(d), 2500, 3000) * env(d, 0.01, d, power=0.7) * 0.25
    out = die + hiss
    place(out, clunk(150, 0.12, 0.7), 0.05, 1.0)
    return filt(out, low=7000)


def gc_bounce():
    """A ring echoing off a wall: a glassy reflected ping with a tail."""
    d = 0.5
    out = _ping(880, d, 0.5)
    place(out, _ping(880, 0.3, 0.2), 0.09, 1.0)
    return filt(out, low=6500)


def gc_strike():
    """A ring passing through a zombie: a soft thud and a blip."""
    d = 0.22
    thud = _sub_thump(180, 90, d, 0.05) * 0.8
    return filt(thud + _ping(1760, d, 0.22, decay=3.0), low=6500)


def gc_equip():
    """Raised: the dish clacks, the radar beeps twice."""
    out = silence(0.4)
    place(out, clunk(260, 0.07, 0.6), 0.0, 1.0)
    place(out, _ping(1320, 0.1, 0.3, decay=3.0), 0.15, 1.0)
    place(out, _ping(1760, 0.12, 0.3, decay=3.0), 0.24, 1.0)
    return out


def gc_sat():
    """The hologram satellite printing in: a shimmering descending sweep."""
    d = 0.6
    t = t_axis(d)
    glide = osc(2 * np.pi * np.cumsum(2600 - 1400 * t / d) / SR, "sine") * 0.2
    shimmer = band(noise(d), 5000, 2000) * 0.08 * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t))
    return filt((glide + shimmer) * env(d, 0.05, d, power=0.8, release=0.08), low=8000)


def gc_dock():
    """The satellite docks: a magnetic clunk and a lime ping."""
    out = silence(0.45)
    place(out, clunk(200, 0.1, 0.8), 0.0, 1.0)
    place(out, _ping(988, 0.4, 0.35), 0.02, 1.0)
    return filt(out, low=7000)


def gc_chime():
    """Signal back: a rising three-note radar chime."""
    out = silence(0.55)
    for i, f in enumerate((880, 1109, 1319)):
        place(out, _ping(f, 0.3, 0.32, decay=2.0), i * 0.07, 1.0)
    return out


def gc_reload():
    """The reload bed: the meter drops, the satellite hums down, the bars tick in."""
    out = silence(2.0)
    place(out, clunk(190, 0.1, 0.7), 0.24, 1.0)
    place(out, band(noise(0.5), 700, 500) * env(0.5, 0.1, 0.5, power=0.8) * 0.15, 0.4, 1.0)
    place(out, clunk(240, 0.1, 0.8), 1.8, 1.0)
    return filt(out, low=7000)


SOUNDS = [gc_fire, gc_fire_big, gc_feedback, gc_charge, gc_ready, gc_step, gc_overcharge, gc_stall, gc_bounce, gc_strike,
          gc_equip, gc_sat, gc_dock, gc_chime, gc_reload]

VARIANTS = [(gc_fire, (0.95, 1.05)), (gc_strike, (0.92, 1.08)), (gc_bounce, (0.94, 1.06))]

LOOPS = {}
MUSIC = {}
