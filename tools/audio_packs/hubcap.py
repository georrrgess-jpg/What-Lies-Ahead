"""The Endless reward primary, the Road Rager (hubcap_boomerang): a hot-rod
pitching machine that flings spinning hubcaps. Tyre squeals, tin-plate
clangs and a whirring disc, short and punchy with the top end rolled off so
the metal never turns shrill. All names start with "hub_" (audio/mix.tres
puts the throw on "weapon", strikes, clangs and the pile-up on "impact", the
rest on "handling").

    python tools/gen_audio.py hubcap
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HIT, MID, punched


def _whoosh(d, f0=500, f1=1600, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


def _clang(freq, d, gain=1.0, decay=2.2):
    """Struck sheet metal: a few inharmonic partials over a noisy hit."""
    partials = ((1.0, 1.0), (2.32, 0.55), (3.61, 0.32), (5.1, 0.16))
    out = silence(d)
    for ratio, g in partials:
        out += tone(freq * ratio, d) * env(d, 0.0008, d / (ratio ** 0.5), power=decay) * g
    hit = filt(noise(d), high=800, low=5000) * env(d, 0.0004, 0.025, power=2.0) * 0.6
    return (out + hit) * gain


def _squeal(f0, f1, d, gain=1.0):
    """A short tyre chirp: a gliding, slightly rough tone."""
    t = t_axis(d)
    freq = f0 + (f1 - f0) * np.sqrt(t / d)
    rough = 1.0 + 0.12 * np.sin(2 * np.pi * 90 * t)
    body = osc(2 * np.pi * np.cumsum(freq * rough) / SR, "tri")
    hiss = band(noise(d), 2200, 900) * 0.3
    return (body * 0.7 + hiss) * env(d, 0.01, d, power=1.1, release=0.03) * gain


@punched(MID, thump_hz=(160.0, 60.0))
def hub_throw():
    """The throw: the tyres bite with a chirp, a sprung thunk, the disc whips away."""
    d = 0.5
    chirp = _squeal(900, 1500, 0.12, 0.45)
    whip = _whoosh(0.32, 700, 2200, 0.55)
    out = _sub_thump(170, 70, d, 0.08) * 1.3
    place(out, clunk(260, 0.08, 0.6), 0.0, 1.0)
    place(out, chirp, 0.0, 1.0)
    place(out, whip, 0.03, 1.0)
    place(out, _clang(620, 0.18, 0.18), 0.0, 1.0)
    return crush(filt(out, low=6500), 1.25)


@punched(HIT)
def hub_strike():
    """The hubcap slicing through a zombie: a bright clank and a meaty chop."""
    d = 0.3
    chop = filt(noise(d), low=1800, high=120) * env(d, 0.001, 0.05, power=2.0) * 0.9
    thump = _sub_thump(200, 90, d, 0.06) * 0.9
    return crush(filt(_clang(880, d, 0.45, decay=3.0) + chop + thump, low=6500), 1.3)


@punched(HIT, shelf_db=-3.0)
def hub_clang():
    """Off a wall: a big hollow clang with a scrape."""
    d = 0.45
    scrape = band(noise(d), 2600, 1200) * env(d, 0.002, 0.18, power=1.4) * 0.25
    return filt(_clang(410, d, 0.8) + scrape, low=6000)


@punched(CUE)
def hub_catch():
    """Caught: the magnet clacks shut and the hubcap rings in its seat."""
    d = 0.4
    out = silence(d)
    place(out, clunk(330, 0.07, 0.8), 0.0, 1.0)
    place(out, click(0.02, 1700, 0.7), 0.0, 1.0)
    place(out, _clang(990, 0.32, 0.3, decay=2.6), 0.01, 1.0)
    return filt(out, low=7000)


def hub_pileup():
    """Four in one throw: a gold ring-up, two quick rising chimes over a clank."""
    d = 0.5
    out = silence(d)
    for i, f in enumerate((784, 1175)):
        place(out, (tone(f, 0.3, "tri") + tone(f * 2, 0.3) * 0.2) * env(0.3, 0.003, 0.3, power=1.8) * 0.4, i * 0.07, 1.0)
    place(out, _clang(560, 0.3, 0.25), 0.0, 1.0)
    return filt(out, low=7000)


def hub_flip():
    """The reload flip: a thumb flick and the disc fluttering through the air."""
    d = 0.32
    t = t_axis(d)
    flutter = band(noise(d), 1200, 600) * (0.55 + 0.45 * np.sin(2 * np.pi * 26 * t)) * env(d, 0.02, d, power=1.0) * 0.45
    out = flutter.copy()
    place(out, click(0.02, 2100, 0.5), 0.0, 1.0)
    return filt(out, low=6000)


def hub_equip():
    """Raised: the tyres spin up with a rev and the magnet clacks."""
    out = silence(0.45)
    place(out, _squeal(400, 900, 0.3, 0.3), 0.0, 1.0)
    place(out, clunk(300, 0.06, 0.6), 0.22, 1.0)
    place(out, _clang(1050, 0.18, 0.15), 0.24, 1.0)
    return filt(out, low=7000)


def hub_reload():
    """Pit stop: the rack wrenched off, a new one printed in and slammed home, the tyres rev."""
    out = silence(1.9)
    place(out, clunk(210, 0.1), 0.26, 0.8)                                          # rack wrenched off
    place(out, _whoosh(0.16, 400, 1400, 0.35), 0.4, 1.0)                            # tossed away
    for i in range(3):                                                              # hubcaps print in
        place(out, click(0.02, 1500 + i * 220, 0.25), 0.74 + i * 0.07, 1.0)
    place(out, band(noise(0.18), 1800, 700) * env(0.18, 0.03, power=1.0), 0.76, 0.25)
    place(out, clunk(250, 0.12), 1.13, 0.95)                                        # slammed home
    place(out, _squeal(500, 1200, 0.24, 0.3), 1.63, 1.0)                            # the tyres rev
    return filt(out, low=8000)


def hub_spin_loop():
    """The disc in flight: a whirring wobble over a low hum (seamless)."""
    d = 0.6
    t = t_axis(d + 0.1)
    whirr = band(noise(d + 0.1), 700, 400) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t)) * 0.6
    hum = tone(110, d + 0.1, "tri") * 0.18 + tone(220, d + 0.1) * 0.08
    return loopable(filt(whirr + hum, low=3500), 0.1)


SOUNDS = [hub_throw, hub_strike, hub_clang, hub_catch, hub_pileup, hub_flip, hub_equip, hub_reload]

VARIANTS = [(hub_throw, (0.95, 1.05)), (hub_strike, (0.92, 1.08)), (hub_clang, (0.93, 1.07))]

LOOPS = {"hub_spin_loop": hub_spin_loop}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
