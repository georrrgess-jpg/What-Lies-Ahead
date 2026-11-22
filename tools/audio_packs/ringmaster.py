"""The Ringmaster (update 24 primary, the hard unlock): a brass, crimson and
gold circus assault rifle with a three-ring spinning drum. Each shot is a
tight, heavy rifle crack with a brassy ring off the drum's rims and a short
snare snap, firm enough to read as the best gun in the game yet short so it
sits in the autofire band. The Spotlight meter fills to a circus bell
chord; calling the Main Event is a cymbal swell and a brass "ta-da", its end
a falling slide whistle; every kill in it pops a party popper. The drum
swap: a latch, a rattling drop, a hologram shimmer, a slap and a clunk, the
drum spinning up to a run of marquee chimes, the charging handle's rack.
The inspect: a hat whoosh and the Curtain Call's fanfare on a drum roll.
All names start with "rm_" (audio/mix.tres puts the shot on "weapon", the
pop on "impact", the meter cues on "confirm", the rest on "handling").

    python tools/gen_audio.py ringmaster
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, FAST, HANDLE, HIT, punched

C5 = 523.25


def _brass(freq, d, gain=1.0, vib=0.0):
    """One brassy note: a bright harmonic stack with a breathy attack."""
    t = t_axis(d)
    wob = 1.0 + vib * np.sin(2 * np.pi * 5.8 * t) * np.clip(t / d * 2.0, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * wob) / SR
    body = sum(np.sin(phase * k) * a for k, a in ((1, 1.0), (2, 0.7), (3, 0.5), (4, 0.32), (5, 0.2), (6, 0.12), (7, 0.07)))
    breath = band(noise(d), freq * 3, freq) * 0.1 * env(d, 0.002, 0.05, power=1.5)
    return (body * 0.26 + breath) * env(d, 0.014, d, sustain=0.75, power=1.0, release=0.05) * gain


def _bell(freq, d=0.6, gain=1.0):
    """A circus bell: inharmonic partials with a long ring."""
    partials = [(1, 1.0), (2.0, 0.45), (2.76, 0.35), (4.07, 0.2), (5.4, 0.1)]
    out = sum(tone(freq * r, d) * a * env(d, 0.001, d * (0.95 - 0.12 * i), power=1.8) for i, (r, a) in enumerate(partials))
    return out * 0.32 * gain


def _snare(d=0.12, gain=1.0, seed=5):
    rnd = np.random.default_rng(seed)
    w = rnd.standard_normal(int(SR * d))
    return (band(w, 2800, 2200) * 0.8 + band(w, 900, 400) * 0.3) * env(d, 0.0008, d * 0.6, power=2.0) * gain


def _cymbal(d, gain=1.0, swell=False, seed=9):
    rnd = np.random.default_rng(seed)
    w = rnd.standard_normal(int(SR * d))
    shape = env(d, d * 0.85, d, power=1.4) if swell else env(d, 0.002, d, power=2.4)
    return band(w, 6500, 4500) * shape * 0.5 * gain


def _ratchet(count, step, f=1800, gain=1.0):
    d = count * step + 0.05
    out = silence(d)
    for i in range(count):
        place(out, click(0.01, f + (i % 2) * 260, 0.4), i * step, 1.0)
        place(out, clunk(320 + (i % 3) * 30, 0.035, 0.22), i * step, 1.0)
    return out * gain


def _fire(seed):
    d = 0.2
    rnd = np.random.default_rng(seed)
    out = _sub_thump(150, 58, d, 0.035) * 1.05
    place(out, click(0.01, 1700 + rnd.uniform(-80, 80), 0.6), 0.0, 1.0)
    place(out, band(noise(0.05), 1800, 1500) * env(0.05, 0.0004, 0.03, power=2.2) * 0.75, 0.0, 1.0)
    place(out, _snare(0.07, 0.35, seed=seed), 0.002, 1.0)
    # The brass rims ring for a moment off every shot.
    ring = (tone(1320 + rnd.uniform(-20, 20), 0.12) * 0.5 + tone(1980, 0.12) * 0.25) * env(0.12, 0.0005, 0.08, power=2.0) * 0.12
    place(out, ring, 0.004, 1.0)
    return crush(filt(out, low=7200), 1.25)


@punched(FAST, thump_hz=(140.0, 55.0), thump_gain=0.42, thump_decay=0.04)
def rm_fire():
    """One round: a heavy, tight rifle crack, a snare snap and a brassy ring off the drum."""
    return _fire(1)


@punched(FAST, thump_hz=(140.0, 55.0), thump_gain=0.42, thump_decay=0.04)
def rm_fire_b():
    """Variant: another seed for the crack and the ring."""
    return _fire(2)


@punched(FAST, thump_hz=(140.0, 55.0), thump_gain=0.42, thump_decay=0.04)
def rm_fire_c():
    """Variant: a third seed."""
    return _fire(3)


@punched(HIT)
def rm_pop():
    """A confetti pop: a party-popper bang, a paper flutter and a toy-horn toot."""
    d = 0.55
    out = _sub_thump(190, 70, 0.2, 0.05)
    place(out, click(0.012, 2400, 0.8), 0.0, 1.0)
    place(out, band(noise(0.06), 3200, 2400) * env(0.06, 0.0005, 0.04, power=2.0) * 0.8, 0.0, 1.0)
    rnd = np.random.default_rng(12)
    for _ in range(10):
        f = rnd.uniform(1800, 3600)
        place(out, band(noise(0.02), f, 900) * env(0.02, 0.0005, 0.015, power=2.0) * rnd.uniform(0.1, 0.25), rnd.uniform(0.03, 0.4), 1.0)
    place(out, _brass(C5 * 1.5, 0.12, 0.35), 0.03, 1.0)
    return filt(out, low=8500)


@punched(CUE)
def rm_ready():
    """The meter is full: a three-bell circus chord, rising."""
    out = silence(0.8)
    for i, f in enumerate((C5, C5 * 1.26, C5 * 1.5)):
        place(out, _bell(f, 0.6, 0.8), i * 0.07, 1.0)
    return filt(out, low=9000)


@punched(CUE, thump_gain=0.35)
def rm_call():
    """The Main Event: a cymbal swell into a brass ta-da over a bass drum."""
    out = silence(1.1)
    place(out, _cymbal(0.32, 0.6, swell=True), 0.0, 1.0)
    place(out, _sub_thump(110, 45, 0.4, 0.12) * 1.2, 0.3, 1.0)
    place(out, _brass(C5, 0.12, 0.7), 0.3, 1.0)
    place(out, _brass(C5 * 1.5, 0.5, 0.7, vib=0.008), 0.43, 1.0)
    place(out, _brass(C5 * 1.26, 0.5, 0.5, vib=0.008), 0.43, 1.0)
    place(out, _cymbal(0.6, 0.5), 0.43, 1.0)
    return filt(out, low=9000)


def rm_end():
    """The Main Event is over: a soft falling slide whistle."""
    d = 0.5
    body = sweep(1400, 600, d, "sine", curve=0.8) * env(d, 0.02, d, power=1.3) * 0.3
    return filt(body, low=6000)


@punched(HANDLE)
def rm_reload():
    """The reload starts: the rifle rolls over with a brass rattle."""
    out = silence(0.3)
    place(out, clunk(240, 0.07, 0.6), 0.0, 1.0)
    place(out, _ratchet(2, 0.04, 2200, 0.6), 0.03, 1.0)
    return filt(out, low=7000)


@punched(HANDLE)
def rm_latch():
    """The drum latch: a spring-loaded brass clack."""
    out = silence(0.2)
    place(out, click(0.012, 2600, 0.8), 0.0, 1.0)
    place(out, clunk(300, 0.06, 0.6), 0.004, 1.0)
    return filt(out, low=7500)


@punched(HANDLE)
def rm_drop():
    """The spent drum spins out: a whirr winding down and the rattle of the fall."""
    d = 0.5
    out = silence(d)
    whirr = sweep(900, 300, 0.35, "saw", curve=0.7) * env(0.35, 0.01, 0.35, power=1.2) * 0.06
    place(out, filt(whirr, low=3000), 0.0, 1.0)
    place(out, _ratchet(6, 0.05, 1500, 0.5), 0.02, 1.0)
    return filt(out, low=6500)


def rm_holo():
    """The fresh drum prints in: a rising hologram shimmer."""
    d = 0.5
    body = sweep(600, 1800, d, "tri", curve=0.6) * 0.1 + band(noise(d), 6000, 3000) * 0.08
    return filt(body * env(d, 0.08, d, power=1.0, release=0.1), low=9000)


@punched(HANDLE, thump_gain=0.3)
def rm_slap():
    """The drum slapped home: a palm smack and a heavy brass clunk."""
    out = silence(0.35)
    place(out, band(noise(0.04), 1500, 1200) * env(0.04, 0.0005, 0.03, power=2.0) * 0.8, 0.0, 1.0)
    place(out, clunk(180, 0.1, 0.9), 0.006, 1.0)
    place(out, _bell(1760, 0.2, 0.25), 0.01, 1.0)
    return filt(out, low=7000)


def rm_spin():
    """The rings spin up: a rising whirr and a run of marquee chimes."""
    d = 0.9
    out = silence(d)
    whirr = sweep(300, 1100, 0.6, "saw", curve=0.6) * env(0.6, 0.05, 0.6, power=1.0, release=0.15) * 0.05
    place(out, filt(whirr, low=3500), 0.0, 1.0)
    notes = (C5, C5 * 1.12, C5 * 1.26, C5 * 1.5, C5 * 1.68, C5 * 2.0)
    for i, f in enumerate(notes):
        place(out, _bell(f * 1.5, 0.3, 0.35), 0.06 + i * 0.06, 1.0)
    return filt(out, low=9500)


@punched(HANDLE)
def rm_rack():
    """The charging handle: a two-part metallic rack."""
    out = silence(0.25)
    place(out, click(0.014, 2100, 0.7), 0.0, 1.0)
    place(out, band(noise(0.06), 3000, 1800) * env(0.06, 0.002, 0.05, power=1.6) * 0.4, 0.004, 1.0)
    place(out, clunk(260, 0.06, 0.6), 0.05, 1.0)
    return filt(out, low=7500)


def rm_hat():
    """The inspect's hat tip: a quick whoosh and a felt pat."""
    d = 0.35
    whoosh = band(noise(d), 1400, 1200) * env(d, 0.08, d, power=1.2, release=0.06) * 0.25
    out = whoosh
    place(out, clunk(420, 0.04, 0.2), 0.28, 1.0)
    return filt(out, low=6000)


def rm_fanfare():
    """The Curtain Call: a drum roll into a brass fanfare and a cymbal."""
    notes = [(0, 0.0, 0.12), (4, 0.14, 0.12), (7, 0.28, 0.12), (12, 0.42, 0.32), (9, 0.78, 0.12), (12, 0.92, 0.7)]
    end = 1.9
    out = silence(end)
    for i in range(40):
        place(out, _snare(0.04, 0.12 + 0.12 * i / 40, seed=20 + i), i * 0.026, 1.0)
    for semi, at, ln in notes:
        place(out, _brass(C5 * 2 ** (semi / 12), ln, 0.6, vib=0.007), 0.3 + at, 1.0)
    place(out, _cymbal(0.9, 0.5), 1.22, 1.0)
    return filt(out, low=9000)


@punched(HANDLE)
def rm_equip():
    """Raised: the drum clicks round a notch, a bell ting and the handle tapped."""
    out = silence(0.45)
    place(out, _ratchet(3, 0.035, 2000, 0.6), 0.0, 1.0)
    place(out, _bell(C5 * 2, 0.35, 0.4), 0.12, 1.0)
    place(out, click(0.012, 2300, 0.4), 0.2, 1.0)
    return filt(out, low=8000)


SOUNDS = [rm_fire, rm_fire_b, rm_fire_c, rm_pop, rm_ready, rm_call, rm_end, rm_reload, rm_latch, rm_drop, rm_holo, rm_slap,
          rm_spin, rm_rack, rm_hat, rm_fanfare, rm_equip]

VARIANTS = [(rm_pop, (0.92, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
