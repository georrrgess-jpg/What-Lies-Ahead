"""The T-Minus Six (update 12 secondary): a pocket rocket launchpad. Toy
rocketry: a crisp 'fwoomp' and fizz per rocket, mission-control beeps for the
paint locks (each one higher), soft firework pops, and gantry hums and rail
clicks for the reload. All names start with "tm6_" (audio/mix.tres puts the
shots on "weapon", the pops on "impact", the rest on "handling").

    python tools/gen_audio.py t_minus_six
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _fizz(d, centre=3200, width=2600, gain=1.0):
    """A rocket motor's hiss with a fast crackle."""
    t = t_axis(d)
    crackle = 0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 47 * t))
    return band(noise(d), centre, width) * crackle * env(d, 0.004, d, power=1.2, release=d * 0.3) * gain


def _beep(freq, d, gain=1.0):
    """A clean console beep: square plus a sine an octave up, click-free."""
    return (tone(freq, d, "square") * 0.35 + tone(freq * 2, d) * 0.2) * env(d, 0.002, d, power=0.6, release=0.02) * gain


def tm6_fire():
    """The trigger: a punchy tube 'fwoomp', a snap and the rocket fizzing off."""
    d = 0.42
    out = _sub_thump(190, 60, d, 0.07) * 1.4
    place(out, filt(noise(0.05), high=900, low=6000) * env(0.05, 0.0004, 0.02, power=2.0) * 0.9, 0.0, 1.0)
    place(out, sweep(900, 260, 0.12, "tri", 0.7) * env(0.12, 0.002, 0.1, power=1.8) * 0.4, 0.0, 1.0)
    place(out, _fizz(0.36, 3000, 2400, 0.4), 0.02, 1.0)
    return fx.fire(out, 8901, 2600, 0.7, (100, 38, 0.15, 1.2), 0.4, 0.06, 0.32, 1.3, 8000)


def tm6_launch():
    """One more rocket of the swarm leaving the pod: a light 'tsoo' and fizz."""
    d = 0.3
    out = _sub_thump(240, 110, d, 0.04) * 0.6
    place(out, sweep(1300, 600, 0.1, "tri", 0.6) * env(0.1, 0.001, 0.08, power=1.8) * 0.3, 0.0, 1.0)
    place(out, _fizz(0.26, 3600, 2200, 0.45), 0.01, 1.0)
    return fx.fire(out, 8911, 3000, 0.3, (140, 70, 0.04, 0.4), 0.15, 0.04, 0.2, 1.1, 8500)


def tm6_lock():
    """A lock: a bright console beep (the game raises its pitch per lock)."""
    d = 0.11
    return filt(_beep(1320, d, 0.9), low=7000)


def tm6_lock_full():
    """Every rocket painted: a double beep that rises, 'ready'."""
    out = silence(0.26)
    place(out, _beep(1320, 0.08, 0.8), 0.0, 1.0)
    place(out, _beep(1760, 0.12, 0.9), 0.1, 1.0)
    return filt(out, low=7500)


def tm6_pop():
    """A rocket finds its mark: a tight firework pop, a crackle and a thud."""
    d = 0.4
    out = _sub_thump(150, 55, d, 0.08) * 1.2
    place(out, filt(noise(0.08), high=300, low=5000) * env(0.08, 0.0005, 0.04, power=1.8) * 1.0, 0.0, 1.0)
    t = t_axis(0.3)
    sparkle = band(noise(0.3), 5000, 3000) * (np.random.default_rng(7).random(len(t)) > 0.985) * 3.0
    place(out, sparkle * env(0.3, 0.01, 0.3, power=1.5), 0.03, 0.5)
    return fx.fire(out, 8921, 3000, 0.6, (110, 40, 0.12, 1.0), 0.32, 0.06, 0.3, 1.4, 8500, 0.3)


def tm6_count():
    """One step of the countdown strip: a short low blip."""
    return filt(_beep(660, 0.07, 0.7), low=6000)


def tm6_ready():
    """Go for launch: a rising three-note chirp over a latch clack."""
    out = silence(0.4)
    place(out, clunk(300, 0.06, 0.6), 0.0, 1.0)
    for i, f in enumerate((880, 1175, 1568)):
        place(out, _beep(f, 0.07, 0.6), 0.03 + i * 0.06, 1.0)
    fx.place_at(out, fx.punch(0.12, 160, 70, 0.05, 0.3), 0.0)
    return filt(out, low=8000)


def tm6_gantry():
    """The hologram gantry projecting: a rising shimmer and hum."""
    d = 0.5
    hum = sweep(180, 360, d, "tri", 0.8) * env(d, 0.05, d, power=1.0, release=0.12) * 0.35
    shimmer = band(noise(d), 5200, 2000) * env(d, 0.12, d, power=1.0, release=0.15) * 0.18
    return filt(hum + shimmer, low=9000)


def tm6_rail():
    """A rocket slides down the rail and clicks into its tube."""
    d = 0.16
    slide = band(noise(d), 2400, 1200) * env(d, 0.01, 0.1, power=1.2) * 0.3
    out = slide.copy()
    place(out, click(0.02, 2600, 0.8), 0.1, 1.0)
    place(out, clunk(420, 0.05, 0.4), 0.1, 1.0)
    fx.place_at(out, fx.tick(8931, 2800, gain=0.6), 0.1)
    return filt(out, low=8000)


def tm6_equip():
    """Raised: the dish servo whirs and the console boots with a blip."""
    out = silence(0.4)
    place(out, sweep(300, 900, 0.22, "tri", 0.7) * env(0.22, 0.01, 0.22, power=1.0) * 0.25, 0.0, 1.0)
    place(out, clunk(280, 0.06, 0.6), 0.2, 1.0)
    place(out, _beep(1175, 0.06, 0.5), 0.26, 1.0)
    fx.place_at(out, fx.tick(8941, 2600, gain=0.7), 0.2)
    fx.place_at(out, fx.holo(0.16, 700, 1600, 8942, 0.14), 0.05)
    return filt(out, low=8000)


def tm6_reload():
    """The pod tips up, the gantry hums on and the latch opens (the rails and the count play on their own)."""
    out = silence(0.9)
    place(out, clunk(220, 0.1), 0.05, 0.8)
    place(out, click(0.02, 1800, 0.5), 0.12, 1.0)
    place(out, band(noise(0.3), 1500, 800) * env(0.3, 0.03, 0.3, power=1.0) * 0.2, 0.15, 1.0)
    return filt(out, low=8000)


SOUNDS = [tm6_fire, tm6_launch, tm6_lock, tm6_lock_full, tm6_pop, tm6_count, tm6_ready, tm6_gantry, tm6_rail, tm6_equip, tm6_reload]

VARIANTS = [(tm6_fire, (0.95, 1.05)), (tm6_launch, (0.92, 1.08)), (tm6_pop, (0.9, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
