"""The Tin Sergeant (update 23 primary): a toy-chest launcher that fires
wind-up tin soldiers. Nursery-tin sounds: a hollow toy-cannon 'pomf' with a
bugle honk per shot, a ratchet whirring as a soldier is wound, a bright tin
tick per marching step (thinned out in the game), a tinny clank as one lands,
and the pop: a springy snap, a cymbal-ish tin crash and a little drum. Bugle
calls for "Fall in!", the inspect's salute and its rare parade fanfare. All
names start with "ts_" (audio/mix.tres puts the shot on "weapon", the pop and
the landing on "impact", the rest on "handling").

    python tools/gen_audio.py tin_sergeant
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HANDLE, HEAVY, HIT, punched

G4 = 392.0


def _bugle(freq, d, gain=1.0, vib=0.0):
    """One brassy bugle note: odd and even partials with a breathy attack."""
    t = t_axis(d)
    wob = 1.0 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / d * 2.0, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * wob) / SR
    body = sum(np.sin(phase * k) * a for k, a in ((1, 1.0), (2, 0.6), (3, 0.42), (4, 0.25), (5, 0.14), (6, 0.08)))
    breath = band(noise(d), freq * 3, freq) * 0.12 * env(d, 0.002, 0.06, power=1.5)
    return (body * 0.3 + breath) * env(d, 0.018, d, sustain=0.75, power=1.0, release=0.04) * gain


def _call(notes, gain=1.0):
    """A bugle call: [(semitones above G4, start, length), ...]."""
    end = max(at + ln for _, at, ln in notes) + 0.25
    out = silence(end)
    for semi, at, ln in notes:
        place(out, _bugle(G4 * 2 ** (semi / 12), ln, gain, vib=0.006), at, 1.0)
    return out


def _tin(freq, d=0.18, gain=1.0):
    """A struck tin plate: inharmonic, bright, quick."""
    partials = [(1, 1.0), (1.59, 0.6), (2.14, 0.45), (2.92, 0.3), (3.6, 0.2)]
    out = sum(tone(freq * r, d) * a * env(d, 0.0005, d * (0.9 - 0.12 * i), power=2.2) for i, (r, a) in enumerate(partials))
    return out * 0.4 * gain


def _ratchet(d, rate0, rate1, gain=1.0, seed=3):
    """A clockwork ratchet: clicks speeding from rate0 to rate1 a second over a whirr."""
    out = silence(d)
    rs = np.random.default_rng(seed)
    t = 0.0
    while t < d - 0.02:
        place(out, click(0.01, rs.uniform(2600, 3400), 0.35), t, 1.0)
        place(out, _tin(rs.uniform(1700, 2100), 0.03, 0.25), t, 1.0)
        t += 1.0 / (rate0 + (rate1 - rate0) * t / d)
    whirr = band(noise(d), 900, 500) * 0.14 * env(d, 0.03, d, sustain=0.8, power=1.0, release=0.05)
    return (out + whirr) * gain


@punched(HEAVY, thump_hz=(120.0, 45.0))
def ts_fire():
    """The shot: a hollow toy-cannon pomf out of the bugle, a short honk and the spring's clank."""
    d = 0.55
    out = _sub_thump(160, 60, d, 0.12) * 1.3
    place(out, band(noise(0.08), 700, 500) * env(0.08, 0.0005, 0.07, power=2.0) * 0.9, 0.0, 1.0)
    place(out, _bugle(G4 * 0.75, 0.12, 0.55), 0.01, 1.0)
    place(out, _tin(820, 0.15, 0.6), 0.0, 1.0)
    place(out, click(0.02, 1900, 0.5), 0.0, 1.0)
    return crush(filt(out, low=6500), 1.2)


@punched(HIT)
def ts_pop():
    """A soldier pops: a springy snap, a tin crash and a snare-drum rattle."""
    d = 0.7
    out = _sub_thump(150, 55, d, 0.09) * 1.3
    place(out, click(0.015, 2400, 0.9), 0.0, 1.0)
    place(out, sweep(300, 900, 0.12, "tri", 0.6) * env(0.12, 0.002, 0.12, power=1.2) * 0.35, 0.0, 1.0)
    crash = band(noise(0.5), 5200, 3500) * env(0.5, 0.001, 0.5, power=2.6) * 0.45
    place(out, crash, 0.005, 1.0)
    place(out, _tin(640, 0.3, 0.8), 0.0, 1.0)
    place(out, _tin(910, 0.25, 0.5), 0.01, 1.0)
    snare = band(noise(0.18), 2500, 1800) * env(0.18, 0.001, 0.12, power=1.8) * 0.4
    place(out, snare, 0.06, 1.0)
    return crush(filt(out, low=9000), 1.3)


@punched(HIT, thump_gain=0.2)
def ts_land():
    """A soldier lands: a tinny clank and a little bounce."""
    out = silence(0.3)
    place(out, _tin(700, 0.16, 0.8), 0.0, 1.0)
    place(out, clunk(260, 0.07, 0.5), 0.0, 1.0)
    place(out, _tin(860, 0.1, 0.35), 0.07, 1.0)
    return filt(out, low=8000)


def ts_wind():
    """Winding up: the key's ratchet whirring faster, a ding when it is wound."""
    d = 0.6
    out = _ratchet(0.5, 12, 30, 0.9)
    out = np.concatenate([out, silence(d - 0.5)])
    place(out, _tin(1568, 0.25, 0.22), 0.48, 1.0)
    return filt(out, low=9000)


def ts_tick():
    """One marching step: a bright tin tick."""
    out = silence(0.07)
    place(out, click(0.008, 3000, 0.8), 0.0, 1.0)
    place(out, band(noise(0.03), 2200, 1400) * env(0.03, 0.0005, 0.02, power=2.0) * 0.5, 0.0, 1.0)
    place(out, tone(760, 0.04) * env(0.04, 0.0005, 0.025, power=2.4) * 0.3, 0.0, 1.0)
    return filt(out, low=9500)


@punched(CUE)
def ts_fall_in():
    """'Fall in!': a quick three-note bugle call."""
    return filt(_call([(0, 0.0, 0.1), (4, 0.11, 0.1), (7, 0.22, 0.26)], 0.8), low=7000)


def ts_salute():
    """The inspect's salute: a short bugle flourish."""
    return filt(_call([(7, 0.0, 0.14), (7, 0.16, 0.07), (12, 0.25, 0.14), (7, 0.42, 0.12), (12, 0.56, 0.4)], 0.6), low=7000)


def ts_fanfare():
    """The rare parade: a fanfare over a snare roll and a cymbal."""
    out = _call([(0, 0.0, 0.12), (4, 0.13, 0.12), (7, 0.26, 0.12), (12, 0.39, 0.3), (7, 0.72, 0.1), (12, 0.84, 0.6)], 0.6)
    roll = silence(len(out) / SR)
    for i in range(36):
        place(roll, band(noise(0.04), 2600, 1800) * env(0.04, 0.001, 0.03, power=2.0) * (0.12 + 0.1 * i / 36), i * 0.03, 1.0)
    place(out, roll, 0.0, 1.0)
    place(out, band(noise(0.8), 6000, 4000) * env(0.8, 0.002, 0.8, power=2.0) * 0.3, 0.84, 1.0)
    return filt(out, low=8500)


@punched(HANDLE)
def ts_reload():
    """The reload's start: the chest tips over with a wooden clack and a ratchet catch."""
    out = silence(0.35)
    place(out, clunk(210, 0.09, 0.7), 0.0, 1.0)
    place(out, click(0.02, 2200, 0.5), 0.05, 1.0)
    place(out, _tin(980, 0.12, 0.3), 0.06, 1.0)
    return filt(out, low=7000)


@punched(HANDLE)
def ts_equip():
    """Raised: the hatch flips open, the key clicks twice and a bugle toot."""
    out = silence(0.5)
    place(out, clunk(280, 0.06, 0.6), 0.0, 1.0)
    for i in range(2):
        place(out, click(0.014, 2800, 0.4), 0.08 + i * 0.06, 1.0)
    place(out, _bugle(G4, 0.14, 0.4), 0.24, 1.0)
    return filt(out, low=7000)


SOUNDS = [ts_fire, ts_pop, ts_land, ts_wind, ts_tick, ts_fall_in, ts_salute, ts_fanfare, ts_reload, ts_equip]

VARIANTS = [(ts_fire, (0.95, 1.05)), (ts_pop, (0.9, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
