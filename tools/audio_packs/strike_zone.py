"""The Strike Zone (update 13 primary): a bowling-alley ball launcher. Deep
rumbling rolls on maple boards, hollow wooden pin knocks and a big crash with
an arcade fanfare for a strike; the kicker thwacks and the ball return
clunks. Low and woody, the top end rolled off. All names start with "sz_"
(audio/mix.tres puts the roll on "weapon", pins, the strike, wall bonks,
landings and the gutter on "impact", the rest on "handling").

    python tools/gen_audio.py strike_zone
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HANDLE, HEAVY, HIT, punched


def _rumble(d, f=70.0, gain=1.0):
    """A heavy ball rolling on boards: a low wobbling hum, rough noise and board-seam ticks."""
    t = t_axis(d)
    hum = tone(f, d, "tri") * 0.5 + tone(f * 2.03, d) * 0.22
    rough = filt(noise(d), low=420, high=40) * 1.4
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * 7.0 * t)
    ticks = silence(d)
    for i in range(int(d * 18)):
        place(ticks, click(0.012, 900, 0.18), i / 18.0, 1.0)
    return (hum + rough) * wob * gain + filt(ticks, low=2500) * gain


def _knock(freq, d=0.12, gain=1.0):
    """One hollow wooden knock (a pin): a short resonant body over a woody click."""
    body = (tone(freq, d) + tone(freq * 2.7, d) * 0.35) * env(d, 0.0006, d * 0.6, power=2.6)
    wood = band(noise(d), freq * 1.8, freq * 0.6) * env(d, 0.0004, 0.02, power=2.0) * 1.4
    return (body + wood) * gain


def _crash(d, count, spread, gain=1.0, seed=3):
    """A clatter of pins: knocks of varied pitch tumbling over `spread` seconds."""
    rs = np.random.default_rng(seed)
    out = silence(d)
    for i in range(count):
        at = spread * (i / count) ** 1.6 + rs.uniform(0, 0.012)
        place(out, _knock(rs.uniform(650, 1400), 0.12, rs.uniform(0.35, 0.8)), at, 1.0)
    return out * gain


def _ding(freq, d=0.35, gain=1.0):
    return (tone(freq, d, "tri") + tone(freq * 2, d) * 0.25) * env(d, 0.002, d, power=1.8) * gain


@punched(HEAVY, thump_hz=(95.0, 38.0))
def sz_fire():
    """The roll: the kicker thwacks, the ball drops out of the chamber and rumbles off."""
    d = 0.6
    out = _sub_thump(150, 55, d, 0.18) * 1.3
    place(out, clunk(190, 0.1, 0.8), 0.0, 1.0)
    place(out, _knock(420, 0.1, 0.5), 0.0, 1.0)
    place(out, _rumble(0.5, 62.0, 0.5) * env(0.5, 0.05, 0.5, power=1.2), 0.06, 1.0)
    return crush(filt(out, low=5000), 1.3)


def sz_charge():
    """Winding up: the ball spins up in the chamber with a ratcheting whirr."""
    d = 0.55
    t = t_axis(d)
    whirr = band(noise(d), 500, 300) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(8 + 40 * t / d) / SR)) * 0.7
    hum = sweep(90, 230, d, "tri") * 0.35
    out = (whirr + hum) * env(d, 0.08, d, sustain=0.6, power=1.0, release=0.03)
    for i in range(6):
        place(out, click(0.012, 1600 + i * 150, 0.25), 0.04 + i * 0.075, 1.0)
    return filt(out, low=5000)


@punched(CUE)
def sz_ready():
    """Fully wound: the lane lights ding twice."""
    out = silence(0.45)
    place(out, _ding(988, 0.3, 0.5), 0.0, 1.0)
    place(out, _ding(1319, 0.32, 0.45), 0.07, 1.0)
    return filt(out, low=7000)


def sz_roll_loop():
    """The ball rolling down the lane (seamless)."""
    d = 0.9
    return loopable(filt(_rumble(d + 0.1, 66.0), low=2600), 0.1)


@punched(HIT, hp=60.0)
def sz_thud():
    """The ball lands on the floor: a deep thud and a wooden knock."""
    d = 0.35
    out = _sub_thump(120, 45, d, 0.2) * 1.4
    place(out, _knock(300, 0.12, 0.45), 0.0, 1.0)
    return crush(filt(out, low=3500), 1.4)


@punched(HIT)
def sz_pin():
    """Bowling a zombie over: a hollow pin knock and a little clatter."""
    d = 0.35
    out = _sub_thump(170, 80, d, 0.07) * 0.9
    place(out, _knock(900, 0.14, 0.9), 0.0, 1.0)
    place(out, _crash(0.3, 4, 0.12, 0.5, seed=5), 0.015, 1.0)
    return crush(filt(out, low=6000), 1.3)


@punched(HEAVY)
def sz_strike():
    """STRIKE: a big crash of pins and an arcade fanfare rising over it."""
    d = 1.3
    out = _crash(d, 22, 0.5, 1.0, seed=9)
    place(out, _sub_thump(140, 50, 0.4, 0.2), 0.0, 1.2)
    for i, f in enumerate((523, 659, 784, 1047)):
        place(out, (tone(f, 0.4, "square") * 0.25 + tone(f * 2, 0.4) * 0.12) * env(0.4, 0.004, 0.4, power=1.6), 0.18 + i * 0.08, 0.55)
    place(out, _ding(2093, 0.6, 0.35), 0.5, 1.0)
    return filt(out, low=7500)


@punched(HIT)
def sz_bonk():
    """Off a wall: a heavy, hollow bonk."""
    d = 0.4
    out = _sub_thump(110, 60, d, 0.16) * 1.2
    place(out, _knock(240, 0.2, 0.9), 0.0, 1.0)
    place(out, clunk(160, 0.14, 0.5), 0.0, 1.0)
    return crush(filt(out, low=4000), 1.3)


def sz_gutter():
    """Into the gutter: a hollow rattle sliding down and a hologram fizzle."""
    d = 0.75
    t = t_axis(d)
    rattle = band(noise(d), 700, 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t)) * env(d, 0.02, d, power=1.3)
    drop = sweep(260, 70, d, "tri", 0.7) * env(d, 0.01, d, power=1.5) * 0.5
    fizz = band(noise(d), 3500, 1200) * env(d, 0.1, d, power=1.5) * 0.18
    return filt(rattle + drop + fizz, low=6000)


@punched(HANDLE)
def sz_reload():
    """The ball return opens: a mechanical whir and a latch."""
    out = silence(0.4)
    place(out, sweep(160, 320, 0.25, "tri") * env(0.25, 0.02, 0.25, power=1.2) * 0.4, 0.0, 1.0)
    place(out, click(0.02, 1300, 0.6), 0.02, 1.0)
    place(out, clunk(230, 0.08, 0.5), 0.2, 1.0)
    return filt(out, low=6000)


def sz_hop():
    """The loaded ball hops back into the side return."""
    out = silence(0.4)
    place(out, _knock(520, 0.1, 0.5), 0.0, 1.0)
    place(out, _sub_thump(140, 70, 0.25, 0.1), 0.19, 0.9)
    place(out, _knock(380, 0.12, 0.6), 0.2, 1.0)
    return filt(out, low=5000)


def sz_rail():
    """The hologram rail curls up: a rising shimmering hum."""
    d = 0.5
    hum = sweep(180, 520, d, "saw", 0.7) * 0.18 + sweep(360, 1040, d, "sine", 0.7) * 0.2
    shimmer = band(noise(d), 4200, 1500) * 0.15
    return filt((hum + shimmer) * env(d, 0.06, d, power=1.1, release=0.05), low=7000)


def sz_roll_up():
    """A fresh ball rolls up the rail: the rumble climbs, slows over the crest."""
    d = 0.7
    t = t_axis(d)
    level = np.clip(np.sin(np.pi * t / d) * 1.2, 0, 1)
    return filt(_rumble(d, 80.0) * level * 0.8, low=3000)


def sz_clunk():
    """The ball drops into the chamber: a heavy clunk and a ringing seat."""
    d = 0.45
    out = _sub_thump(130, 55, d, 0.15) * 1.2
    place(out, clunk(200, 0.12, 0.9), 0.0, 1.0)
    place(out, (tone(1180, 0.3) + tone(1770, 0.3) * 0.4) * env(0.3, 0.001, 0.3, power=2.4) * 0.2, 0.0, 1.0)
    return crush(filt(out, low=6000), 1.3)


def sz_spin():
    """The finger-hole spin: a quick whirr winding down."""
    d = 0.5
    t = t_axis(d)
    rate = 40 * (1 - t / d) ** 1.5 + 4
    whirr = band(noise(d), 650, 280) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(rate) / SR)) * env(d, 0.005, d, power=1.4)
    return filt(whirr, low=4000)


def sz_equip():
    """Raised: the kicker clacks, the balls shuffle and the lane lights ding."""
    out = silence(0.5)
    place(out, clunk(260, 0.07, 0.6), 0.0, 1.0)
    place(out, _knock(480, 0.1, 0.4), 0.08, 1.0)
    place(out, _ding(1175, 0.25, 0.3), 0.22, 1.0)
    return filt(out, low=7000)


SOUNDS = [sz_fire, sz_charge, sz_ready, sz_thud, sz_pin, sz_strike, sz_bonk, sz_gutter, sz_reload, sz_hop, sz_rail,
          sz_roll_up, sz_clunk, sz_spin, sz_equip]

VARIANTS = [(sz_fire, (0.95, 1.05)), (sz_pin, (0.9, 1.1)), (sz_bonk, (0.93, 1.07))]

LOOPS = {"sz_roll_loop": sz_roll_loop}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
