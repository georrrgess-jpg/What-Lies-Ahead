"""Two update-8 sidearms: the Shutterbug (flash camera) and the Balloon
Darter (dart pistol). Punchy and short with the top end rolled off, so the
flash and the pops never turn shrill. All names start with "gn8b_"
(audio/mix.tres puts fire on "weapon", pops and the daze on "impact", the
rest on "handling").

    python tools/gen_audio.py guns8b
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _whoosh(d, f0=500, f1=1600, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


def _ting(freq, d, gain=1.0):
    """A small bell: two inharmonic partials ringing out."""
    return (tone(freq, d) + tone(freq * 2.76, d) * 0.3) * env(d, 0.001, d, power=2.4) * gain


def _ratchet(d, clicks, f=2200, slow=0.0, gain=1.0):
    """Evenly spaced (or slowing, `slow` > 0) mechanism clicks."""
    out = silence(d)
    for i in range(clicks):
        k = i / max(1, clicks - 1)
        at = d * 0.9 * (k + slow * (k * k - k))
        place(out, click(0.018, f) * (1.0 - 0.4 * k), at, gain)
    return out


def _squeak(f0, f1, d, gain=1.0):
    """A rubbery squeak: a gliding triangle with a fast wobble."""
    t = t_axis(d)
    wob = 1.0 + 0.04 * np.sin(2 * np.pi * 38 * t)
    freq = (f0 + (f1 - f0) * t / d) * wob
    return osc(2 * np.pi * np.cumsum(freq) / SR, "tri") * env(d, 0.01, d, power=1.2, release=0.02) * gain


# ---------------------------------------------------------------------------
# Shutterbug
# ---------------------------------------------------------------------------

def gn8b_shutter_fire():
    """The flash: a shutter snap, a soft bulb whump and a short capacitor sigh."""
    d = 0.5
    snap = (click(0.02, 1900, 1.0) + band(noise(0.02), 3200, 900) * env(0.02, 0.0004, power=2.5) * 0.6)
    whump = filt(noise(d), low=1600, high=90) * env(d, 0.002, 0.09, power=1.8) * 1.2
    thump = _sub_thump(150, 55, d, 0.12) * 1.3
    sigh = sweep(1500, 420, d, "sine", 0.5) * env(d, 0.01, 0.4, power=2.2) * 0.14
    out = whump + thump + sigh
    place(out, snap, 0.0, 0.9)
    place(out, click(0.016, 1500, 0.5), 0.045, 1.0)
    return fx.fire(out, 8301, 2800, 0.6, (110, 45, 0.12, 1.0), 0.3, 0.055, 0.3, 1.3, 6500)


def gn8b_shutter_daze():
    """Zombies seeing stars: a cartoon wobble of three little chimes."""
    d = 0.45
    out = silence(d)
    for i, f in enumerate((1320, 1180, 1040)):
        place(out, (tone(f, 0.16, "tri", vibrato=0.02, vib_rate=14) * env(0.16, 0.004, 0.16, power=1.8)) * 0.3, i * 0.08, 1.0)
    return filt(out, low=6000)


def gn8b_shutter_spin():
    """The new flash wheel spun by hand: clicks that slow to a stop."""
    d = 0.42
    out = _ratchet(d, 9, 1700, slow=0.8, gain=0.6)
    out += _whoosh(d, 300, 900, 0.2)
    return filt(out, low=7000)


def gn8b_shutter_wind():
    """The film lever thumbed back: a quick ratchet and a spring home."""
    d = 0.2
    out = _ratchet(d, 5, 2400, gain=0.5)
    place(out, clunk(420, 0.05, 0.4), 0.15, 1.0)
    return filt(out, low=7500)


def gn8b_shutter_ready():
    """The flash capacitor charges with a rising hum and chirps ready."""
    d = 0.5
    hum = sweep(380, 1250, d, "tri", 0.7) * env(d, 0.05, d, power=0.6, release=0.1) * 0.16
    out = hum
    place(out, _ting(1760, 0.22, 0.3), 0.3, 1.0)
    place(out, filt(noise(0.06), low=1800) * env(0.06, 0.001, power=2.0) * 0.5, 0.3, 1.0)
    return filt(out, low=7000)


def gn8b_shutter_equip():
    """Raised: the body taken in hand, the lens cap clicks, the flash hums up."""
    out = silence(0.45)
    place(out, _whoosh(0.12, 400, 1200, 0.35), 0.0, 1.0)
    place(out, clunk(300, 0.06), 0.1, 0.6)
    place(out, click(0.02, 2000, 0.5), 0.18, 1.0)
    place(out, sweep(500, 1100, 0.22, "tri", 0.7) * env(0.22, 0.03, power=1.2) * 0.12, 0.2, 1.0)
    fx.place_at(out, fx.tick(8341, 2400, gain=0.4), 0.1)
    fx.place_at(out, fx.holo(0.16, 700, 1500, 8342, 0.15), 0.2)
    return filt(out, low=7500)


def gn8b_shutter_reload():
    """The spent wheel pops off and is flicked away, a new one prints in and is pressed home."""
    out = silence(2.0)
    place(out, clunk(260, 0.08), 0.3, 0.7)                                          # wheel pops off
    place(out, filt(noise(0.25), low=1500) * env(0.25, 0.02, power=1.5) * 0.25, 0.32, 1.0)  # smoke puff
    place(out, _whoosh(0.15, 600, 1700, 0.35), 0.5, 1.0)                            # flicked away
    place(out, band(noise(0.2), 2100, 800) * env(0.2, 0.04, power=1.0), 0.8, 0.28)  # new one prints in
    place(out, clunk(320, 0.09), 1.18, 0.85)                                        # pressed home
    fx.place_at(out, fx.tick(8331, 2300), 0.3)
    fx.place_at(out, fx.holo(0.34, 600, 1700, 8332, 0.22), 0.8)
    fx.place_at(out, fx.latch(8333, 260), 1.18)
    return filt(out, low=8500)


# ---------------------------------------------------------------------------
# Balloon Darter
# ---------------------------------------------------------------------------

def gn8b_dart_fire():
    """A dart puffed out: an air 'pfft', a wooden thock and a short whizz."""
    d = 0.22
    pfft = band(noise(d), 1800, 900) * env(d, 0.001, 0.05, power=1.6) * 1.3
    thock = _sub_thump(260, 120, d, 0.05) * 1.1
    knock = filt(noise(d), low=3000, high=400) * env(d, 0.0005, 0.015, power=2.0) * 0.8
    whizz = sweep(1400, 900, d, "tri", 0.6) * env(d, 0.01, 0.12, power=2.0) * 0.1
    return fx.fire(pfft + thock + knock + whizz, 8401, 2600, 0.6, (130, 55, 0.07, 0.9), 0.16, 0.04, 0.22, 1.25, 7000)


def gn8b_dart_pump():
    """One pump of the plunger: a squeaky stroke and a hiss."""
    d = 0.22
    out = _squeak(500, 700, 0.12, 0.18)
    hiss = band(noise(d), 2500, 900) * env(d, 0.02, 0.18, power=1.3) * 0.35
    out = np.concatenate([out, silence(d - 0.12)]) + hiss
    place(out, click(0.015, 1600, 0.4), 0.11, 1.0)
    return filt(out, low=7500)


def gn8b_dart_equip():
    """Raised: the plunger cocked, a hiss from the helium tank."""
    out = silence(0.4)
    place(out, _whoosh(0.1, 400, 1300, 0.3), 0.0, 1.0)
    place(out, clunk(340, 0.06), 0.1, 0.6)
    place(out, band(noise(0.2), 2300, 800) * env(0.2, 0.02, power=1.5) * 0.3, 0.16, 1.0)
    fx.place_at(out, fx.tick(8441, 2500, gain=0.8), 0.1)
    fx.place_at(out, fx.holo(0.14, 650, 1400, 8442, 0.14), 0.16)
    return filt(out, low=7500)


def gn8b_dart_reload():
    """The empty clip drops and is swatted away, a full one prints in and is slapped home."""
    out = silence(1.9)
    place(out, clunk(230, 0.09), 0.28, 0.75)                                        # clip released
    place(out, _whoosh(0.14, 500, 1600, 0.35), 0.52, 1.0)                           # swatted away
    for i in range(3):                                                              # darts print in
        place(out, click(0.02, 1800 + i * 200, 0.25), 0.76 + i * 0.07, 1.0)
    place(out, band(noise(0.16), 2000, 700) * env(0.16, 0.03, power=1.0), 0.78, 0.28)
    place(out, clunk(270, 0.11), 1.1, 0.9)                                          # slapped home
    fx.place_at(out, fx.tick(8431, 2200), 0.28)
    fx.place_at(out, fx.holo(0.32, 560, 1600, 8432, 0.2), 0.76)
    fx.place_at(out, fx.latch(8433, 240, 0.6), 1.1)
    return filt(out, low=8500)


def gn8b_balloon_tie():
    """A balloon tied on and swelling: a short rubbery stretch."""
    return filt(_squeak(380, 620, 0.16, 0.35), low=6000)


def gn8b_balloon_pop():
    """The bunch pops: a sharp bang over a round thump and a patter of confetti."""
    d = 0.4
    bang = filt(noise(d), high=300, low=5500) * env(d, 0.0003, 0.02, power=2.0) * 1.3
    thump = _sub_thump(210, 70, d, 0.12) * 1.4
    tail = filt(noise(d), low=2500, high=200) * env(d, 0.004, 0.2, power=2.0) * 0.3
    patter = band((np.random.default_rng(5).uniform(0, 1, int(SR * d)) < 0.012).astype(float), 2400, 900) * 3.0
    patter *= env(d, 0.05, d, power=1.5) * 0.25
    return fx.fire(bang + thump + tail + patter, 8411, 3000, 0.6, (120, 45, 0.1, 0.9), 0.25, 0.05, 0.28, 1.4, 7000, 0.3)


SOUNDS = [
    gn8b_shutter_fire, gn8b_shutter_daze, gn8b_shutter_spin, gn8b_shutter_wind, gn8b_shutter_ready, gn8b_shutter_equip,
    gn8b_shutter_reload, gn8b_dart_fire, gn8b_dart_pump, gn8b_dart_equip, gn8b_dart_reload, gn8b_balloon_tie,
    gn8b_balloon_pop,
]

VARIANTS = [
    (gn8b_shutter_fire, (0.95, 1.05)), (gn8b_dart_fire, (0.94, 1.06)), (gn8b_balloon_pop, (0.9, 1.1)),
]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
