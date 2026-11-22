"""The Claw Grabber (claw_grabber), a prize claw machine pistol: every shot is
a spring-loaded launch (a hard mechanical clack, a short low punch, the cable
paying out with a rising zip and a small arcade chirp, in a dry room); the
grab is a chrome clamp biting shut with a two-note "you got it" ding; the
clank is the claw gripping scenery, the slip the claw scraping off something
too heavy with a sour falling squeal; the reel is the winch dragging the
player in (a motor whine climbing over a ratchet); home is the claw clicking
into the chute; prize_win a little jackpot arpeggio over ticket rattle when a
Prized zombie dies; servo the claw machine's motor; jackpot the rare inspect's
win fanfare. The reload (2.2 s) is a token clinking into the slot and
rattling down, the marquee waking with a chime run, the winch reeling the
claw up and lowering it on a servo whirr, the prongs snapping shut and the
joystick flicked. All names start with "clw_" (audio/mix.tres puts the shot on
"weapon", the grab, prize win and slip on "impact", the rest on "handling").

    python tools/gen_audio.py claw_grabber
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _ding(freq, d, gain=1.0):
    """A small bright arcade bell (inharmonic partials falling fast)."""
    out = silence(d)
    for ratio, g in ((1.0, 1.0), (2.0, 0.35), (2.76, 0.18), (5.4, 0.08)):
        out += tone(freq * ratio, d) * env(d, 0.0008, d / ratio ** 0.5, power=2.0) * g
    return out * gain


def _servo(d, f0, f1, seed, gain=1.0):
    """A small geared motor: a buzzy whine gliding f0 -> f1 with gear chatter."""
    rng = np.random.default_rng(seed)
    whine = sweep(f0, f1, d, "saw") * 0.35 + sweep(f0 * 2.01, f1 * 2.01, d, "square") * 0.12
    chatter = band(noise(d), 1800, 900) * (0.5 + 0.5 * np.sin(np.linspace(0, d * 90.0 * np.pi, len(whine)))) * 0.25
    out = filt(whine + chatter, high=200, low=5200)
    out *= env(d, 0.02, None, sustain=1.0, release=0.04)
    return out * gain * (0.9 + 0.1 * rng.uniform())


def _zip(d, f0, f1, seed, gain=1.0):
    """The cable paying out: a filtered noise zip sweeping up."""
    n = fx.hiss(d, seed)
    t = np.linspace(0, 1, len(n))
    out = np.zeros_like(n)
    for k in range(6):
        seg = slice(int(len(n) * k / 6), int(len(n) * (k + 1) / 6))
        centre = f0 + (f1 - f0) * (k + 0.5) / 6
        out[seg] = band(n, centre, centre * 0.5)[seg]
    return out * (1.0 - t) ** 1.5 * gain


def clw_fire():
    """Spring launch: mechanical clack, low punch, cable zip, a tiny arcade chirp."""
    d = 0.3
    out = _sub_thump(170, 60, d, 0.05) * 0.8
    fx.place_at(out, fx.tick(9501, 2400, 0.012, 1.3), 0.0)
    place(out, clunk(260, 0.06, 0.7), 0.0, 1.0)
    place(out, _zip(0.22, 1400, 5200, 9502, 0.55), 0.012, 1.0)
    place(out, sweep(1300, 2100, 0.05, "square") * env(0.05, 0.001, 0.04) * 0.12, 0.02, 1.0)
    return fx.fire(out, 9511, 2600, 0.7, (130, 50, 0.07, 0.8), 0.16, 0.04, 0.2, 1.25, 7800, 0.3)


def clw_grab():
    """The claw bites shut on a zombie: a chrome clamp and a two-note 'got it' ding."""
    d = 0.45
    out = silence(d)
    place(out, clunk(180, 0.08, 0.9), 0.0, 1.0)
    fx.place_at(out, fx.tick(9521, 3000, 0.01, 1.2), 0.0)
    fx.place_at(out, fx.tick(9522, 2200, 0.012, 0.9), 0.018)
    place(out, _ding(1319, 0.22, 0.32), 0.05, 1.0)
    place(out, _ding(1760, 0.3, 0.3), 0.13, 1.0)
    return filt(out, low=8500)


def clw_clank():
    """The claw grips scenery: a hard metal clank."""
    d = 0.2
    out = silence(d)
    place(out, clunk(220, 0.07, 0.8), 0.0, 1.0)
    for ratio, g in ((1.0, 0.3), (2.7, 0.2), (4.3, 0.12)):
        place(out, tone(860 * ratio, 0.16) * env(0.16, 0.0005, 0.05 / ratio ** 0.4, power=2.0) * g, 0.0, 1.0)
    fx.place_at(out, fx.tick(9531, 2800, 0.01, 1.0), 0.0)
    return filt(out, low=8000)


def clw_slip():
    """The claw scrapes off something too heavy: a metal scrape and a sour falling squeal."""
    d = 0.5
    out = silence(d)
    scrape = filt(fx.hiss(0.3, 9541), high=1500, low=6500) * env(0.3, 0.005, 0.25, power=1.4) * 0.5
    place(out, scrape, 0.0, 1.0)
    place(out, sweep(900, 420, 0.4, "square") * env(0.4, 0.01, 0.35) * 0.14, 0.04, 1.0)
    place(out, sweep(950, 445, 0.4, "square") * env(0.4, 0.01, 0.35) * 0.1, 0.04, 1.0)
    return filt(out, low=7000)


def clw_reel():
    """The winch drags the player in: a motor whine climbing over a ratchet."""
    d = 0.6
    out = _servo(d, 220, 520, 9551, 0.8)
    for i in range(12):
        fx.place_at(out, fx.tick(9552 + i, 2000 + 60 * i, 0.008, 0.45), 0.02 + i * 0.045)
    return filt(out, low=7000)


def clw_home():
    """The claw clicks back into the chute."""
    out = silence(0.12)
    fx.place_at(out, fx.latch(9571, 260, 0.8), 0.0)
    fx.place_at(out, fx.tick(9572, 2600, 0.01, 0.6), 0.03)
    return filt(out, low=7500)


def clw_prize_win():
    """A Prized zombie is won: a little jackpot arpeggio over a rattle of tickets."""
    d = 0.7
    out = silence(d)
    for i, f in enumerate((1047, 1319, 1568, 2093)):
        place(out, _ding(f, 0.3, 0.28), i * 0.06, 1.0)
    rattle = filt(fx.hiss(0.4, 9581), high=2500, low=7000) * env(0.4, 0.01, 0.3, power=1.6) * 0.2
    place(out, rattle, 0.02, 1.0)
    return filt(out, low=9000)


def clw_servo():
    """The claw machine's crane motor (inspect)."""
    return _servo(0.4, 300, 380, 9591, 0.9)


def clw_jackpot():
    """The rare inspect's win: a bright fanfare of bells."""
    d = 1.2
    out = silence(d)
    for i, f in enumerate((1047, 1319, 1568, 2093, 1568, 2093, 2637)):
        place(out, _ding(f, 0.35, 0.3), i * 0.08, 1.0)
    return filt(out, low=9500)


def clw_equip():
    """Drawn: the coin mech rattles, the marquee chimes on, the claw servo twitches."""
    out = silence(0.45)
    place(out, clunk(230, 0.06, 0.5), 0.0, 1.0)
    place(out, _ding(1568, 0.18, 0.18), 0.08, 1.0)
    place(out, _servo(0.16, 380, 460, 9601, 0.5), 0.2, 1.0)
    fx.place_at(out, fx.latch(9602, 240, 0.7), 0.36)
    return filt(out, low=8000) * 1.3


def clw_reload():
    """Insert token (2.2 s): the hand comes up, the token clinks into the slot and
    rattles down, the marquee wakes with a chime run, the winch reels the claw up and
    lowers it on a servo whirr, the prongs snap shut, the joystick is flicked."""
    out = silence(2.2)
    place(out, clunk(260, 0.05, 0.35), 0.14, 1.0)                                    # the hand leaves the grip
    fx.place_at(out, fx.tick(9611, 2600, 0.01, 0.6), 0.8)                             # token lines up on the slot
    place(out, _ding(2349, 0.09, 0.25), 0.99, 1.0)                                    # into the slot
    fx.place_at(out, fx.tick(9612, 3000, 0.008, 0.9), 0.99)
    rng = np.random.default_rng(9620)
    for i in range(5):                                                                # rattles down the chute
        at = 1.01 + i * 0.035 + rng.uniform(0.0, 0.01)
        place(out, _ding(rng.uniform(2100, 2900), 0.05, 0.12 - 0.015 * i), at, 1.0)
    for i, f in enumerate((1047, 1319, 1568, 2093, 2637)):                            # the marquee wakes
        place(out, _ding(f, 0.18, 0.16), 1.04 + i * 0.05, 1.0)
    place(out, _servo(0.24, 420, 260, 9630, 0.55), 1.1, 1.0)                          # winch reels the claw up
    place(out, _servo(0.26, 260, 480, 9631, 0.55), 1.42, 1.0)                         # and lowers it out
    place(out, clunk(200, 0.06, 0.6), 1.75, 1.0)                                      # prongs flex and snap shut
    fx.place_at(out, fx.latch(9632, 250, 0.9), 1.84)
    fx.place_at(out, fx.tick(9633, 2200, 0.01, 0.7), 1.86)                            # the joystick flick
    fx.place_at(out, fx.tick(9634, 1900, 0.01, 0.5), 1.94)
    return filt(out, low=8500)


SOUNDS = [clw_fire, clw_grab, clw_clank, clw_slip, clw_reel, clw_home, clw_prize_win, clw_servo, clw_jackpot,
          clw_equip, clw_reload]

VARIANTS = [(clw_fire, (0.95, 1.05)), (clw_grab, (0.97, 1.03)), (clw_clank, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
