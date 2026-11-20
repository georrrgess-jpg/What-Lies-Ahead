"""The Sarsaparilla Six (sarsaparilla_six), a soda-pop six-shooter: every shot
is a cork-gun bark (a hard wooden crack, a hollow pop like a cap leaving a
bottle, a short low punch and a dry saloon room) with a fizz hiss trailing
it; the Last Call is the same shot doubled by a big bottle pop and a long
fizzing gush with a cherry-bright ting; the hammer click is a dry
single-action ratchet; the cap ping a small crown cap landing on glass. The
reload (1.7 s) swings the cylinder out on its crane, rattles empty glass
bottles out, prints a hologram speed-loader, clicks it home in a puff of
fizz, flicks the cap (its ping plays separately, on the catch), ratchets the
cylinder back in spinning down and cocks the hammer. All names start with
"ssx_" (audio/mix.tres puts the shots on "weapon", the Last Call on
"impact", the rest on "handling").

    python tools/gen_audio.py sarsaparilla_six
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _fizz(d, seed, gain=1.0, centre=3600.0):
    """Soda fizz: band-limited hiss broken into tiny bubbles (random crackle)."""
    rng = np.random.default_rng(seed)
    n = fx.hiss(d, seed)
    body = band(n, centre, centre * 0.5) * 1.6
    pops = (rng.uniform(0, 1, len(n)) > 0.9965).astype(float)
    pops = filt(np.convolve(pops, np.hanning(40), mode="same"), high=1800, low=7000) * 2.2
    return (body + pops) * gain


def _pop(seed, pitch=520.0, gain=1.0):
    """A cap leaving a bottle: a hollow, falling 'thoop' with a dry tick."""
    d = 0.09
    out = (tone(pitch, d, "tri") * 0.6 + sweep(pitch * 1.4, pitch * 0.7, d) * 0.5) * env(d, 0.0008, 0.04, power=2.4)
    fx.place_at(out, fx.tick(seed, 1900, 0.012, 1.2), 0.0)
    return out * gain


def _ting(freq, d, gain=1.0):
    """A small bright glass or metal ting (short, its partials falling fast)."""
    out = silence(d)
    for ratio, g in ((1.0, 1.0), (2.32, 0.4), (4.1, 0.15)):
        out += tone(freq * ratio, d) * env(d, 0.0006, d / ratio ** 0.6, power=2.2) * g
    return out * gain


def _ratchet(seed, gain=1.0):
    """The single-action hammer: a dry two-stage click (sear, then the bolt)."""
    d = 0.06
    out = silence(d)
    fx.place_at(out, fx.tick(seed, 2300, 0.012, 1.1), 0.0)
    fx.place_at(out, fx.tick(seed + 1, 1700, 0.016, 1.3), 0.022)
    fx.place_at(out, clunk(300, 0.04, 0.25), 0.022)
    return out * gain


def ssx_fire():
    """One shot: wooden crack, a hollow cap pop, a short punch, fizz trailing in a dry room."""
    d = 0.24
    out = _sub_thump(190, 70, d, 0.05) * 0.9
    place(out, _pop(9301, 470, 0.7), 0.002, 1.0)
    place(out, filt(noise(d), high=700, low=4200) * env(d, 0.0003, 0.02, power=2.2) * 1.1, 0.0, 1.0)
    place(out, filt(_fizz(0.16, 9302, 0.22), low=6500) * env(0.16, 0.01, 0.12, power=1.6), 0.03, 1.0)
    return fx.fire(out, 9311, 2800, 0.85, (130, 52, 0.07, 0.9), 0.16, 0.05, 0.22, 1.3, 7600, 0.3)


def ssx_last_call():
    """The Last Call: a big bottle pop, a gush of fizz and a cherry-bright ting."""
    d = 0.7
    out = silence(d)
    place(out, _sub_thump(150, 55, 0.18, 0.08) * 0.9, 0.0, 1.0)
    place(out, _pop(9321, 360, 1.3), 0.0, 1.0)
    place(out, _pop(9322, 620, 0.6), 0.03, 1.0)
    gush = filt(_fizz(0.6, 9323, 0.5, 3200), low=6800) * env(0.6, 0.02, 0.5, power=1.4)
    place(out, gush, 0.04, 1.0)
    place(out, _ting(1175, 0.35, 0.22), 0.05, 1.0)
    place(out, _ting(1568, 0.3, 0.14), 0.09, 1.0)
    return fx.fire(out, 9331, 2400, 0.6, (120, 48, 0.1, 0.8), 0.22, 0.05, 0.22, 1.2, 7600, 0.25)


def ssx_click():
    """The hammer thumbed back (also the cylinder's ratchet)."""
    return filt(_ratchet(9341, 1.0), low=7000)


def ssx_cap_ping():
    """A crown cap landing on its bottle: a short tinny clink (crowded, inharmonic
    partials, no single whistle) and a glassy tick."""
    d = 0.22
    out = silence(d)
    for ratio, g, dec in ((1.0, 0.5, 0.07), (1.47, 0.55, 0.06), (2.08, 0.5, 0.05), (2.93, 0.4, 0.04), (3.71, 0.3, 0.03)):
        place(out, tone(1180 * ratio, d) * env(d, 0.0005, dec, power=2.0) * g, 0.0, 1.0)
    place(out, filt(fx.hiss(0.05, 9352), high=1500, low=6000) * env(0.05, 0.0004, 0.02, power=2.2) * 0.5, 0.0, 1.0)
    fx.place_at(out, fx.tick(9351, 2600, 0.01, 0.9), 0.0)
    fx.place_at(out, fx.tick(9353, 2200, 0.008, 0.5), 0.045)
    return filt(out, low=7000) * 0.6


def ssx_equip():
    """Drawn: the cylinder spun with the thumb (ratchet), a fizz, the hammer cocked."""
    out = silence(0.42)
    for i in range(5):
        fx.place_at(out, fx.tick(9361 + i, 2100 + 80 * i, 0.01, 0.7 - 0.08 * i), 0.02 + i * 0.03 * (1.0 + i * 0.25))
    place(out, filt(_fizz(0.2, 9366, 0.25), low=6500) * env(0.2, 0.02, 0.18, power=1.4), 0.08, 1.0)
    fx.place_at(out, _ratchet(9367, 1.1), 0.3)
    return filt(out, low=7500) * 1.4


def ssx_reload():
    """Speed-loader (1.8 s): crane out spinning, empties rattle out, hologram loader,
    clicked home in fizz, the cap flick, the cylinder in spinning down, the hammer cocked."""
    out = silence(1.8)
    place(out, clunk(240, 0.07, 0.55), 0.18, 1.0)                                   # the crane swings out
    for i in range(6):                                                               # spinning out
        fx.place_at(out, fx.tick(9371 + i, 2000 + 40 * i, 0.009, 0.45 - 0.05 * i), 0.19 + i * 0.03 * (1.0 + i * 0.3))
    rng = np.random.default_rng(9380)
    for i in range(5):                                                               # empty bottles tumble out
        at = 0.46 + i * 0.03 + rng.uniform(0.0, 0.015)
        place(out, _ting(rng.uniform(1600, 2300), 0.08, 0.18), at, 1.0)
        fx.place_at(out, fx.tick(9381 + i, 2400, 0.008, 0.4), at)
    fx.place_at(out, fx.holo(0.22, 520, 1250, 9390, 0.16), 0.54)                     # the loader prints in
    place(out, clunk(200, 0.08, 0.6), 0.83, 1.0)                                    # pushed home
    fx.place_at(out, fx.latch(9391, 230, 0.8), 0.83)
    place(out, filt(_fizz(0.3, 9392, 0.3), low=6800) * env(0.3, 0.01, 0.26, power=1.5), 0.84, 1.0)
    fx.place_at(out, fx.tick(9393, 1800, 0.012, 0.8), 1.04)                          # the thumb flicks the cap
    place(out, clunk(260, 0.07, 0.5), 1.37, 1.0)                                     # crane in
    for i in range(9):                                                               # spinning down on the ratchet
        fx.place_at(out, fx.tick(9400 + i, 2200 - 30 * i, 0.009, 0.5 - 0.03 * i), 1.38 + 0.02 * i * (1.0 + i * 0.22))
    fx.place_at(out, _ratchet(9410, 1.2), 1.58)                                       # the hammer cocked
    return filt(out, low=8000)


SOUNDS = [ssx_fire, ssx_last_call, ssx_click, ssx_cap_ping, ssx_equip, ssx_reload]

VARIANTS = [(ssx_fire, (0.94, 1.06)), (ssx_last_call, (0.97, 1.03)), (ssx_click, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
