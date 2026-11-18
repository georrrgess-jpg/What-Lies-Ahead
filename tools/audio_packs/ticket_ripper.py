"""The level-12 SMG primary, the Ticket Ripper (ticket_ripper): an arcade
prize-ticket dispenser that fires. Fast, papery and mechanical: each shot is
a tight clack of the dispenser, a paper snap and a small punchy "tk", soft
enough to sit under the big single shots at 15 a second; the Winner! streak
gets arcade bells, the reload a ratchet crank, a spool pop, a hologram
shimmer, a solid clunk and a paper rip. All names start with "tkr_"
(audio/mix.tres puts the shot on "weapon", the pop on "impact" and the rest
on "handling").

    python tools/gen_audio.py ticket_ripper
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, FAST, HANDLE, HIT, MID, punched


def _paper(d, centre=2400, width=1800, gain=1.0, seed=1):
    """A short snap of paper: band-passed noise with a fast fall."""
    rnd = np.random.default_rng(seed)
    n = int(SR * d)
    w = rnd.standard_normal(n)
    return band(w, centre, width) * env(d, 0.0008, d * 0.45, power=2.2) * gain


def _rip(d, gain=1.0, seed=4):
    """Paper tearing: noise chopped into fast, uneven fibre crackles."""
    rnd = np.random.default_rng(seed)
    n = int(SR * d)
    t = np.arange(n) / SR
    w = rnd.standard_normal(n)
    grain = np.clip(np.sin(2 * np.pi * (70 + 50 * t / d) * t + rnd.uniform(0, 6)) + rnd.uniform(-0.4, 0.4, n) * 0.6, 0.0, None)
    body = band(w, 2200, 2200) * grain + filt(w, low=900, high=200) * 0.25
    return body * env(d, 0.01, d, power=0.9, release=d * 0.3) * gain


def _bell(freqs, step, d, gain=1.0):
    """Arcade prize bells: a tri tone and a soft octave for each note."""
    out = silence(d)
    for i, f in enumerate(freqs):
        ring = (tone(f, 0.45, "tri") + tone(f * 2.0, 0.45) * 0.18 + tone(f * 3.01, 0.45) * 0.06) * env(0.45, 0.002, 0.45, power=1.7)
        place(out, ring * 0.35, i * step, 1.0)
    return out * gain


def _ratchet(count, step, f=1700, gain=1.0):
    d = count * step + 0.05
    out = silence(d)
    for i in range(count):
        place(out, click(0.012, f + (i % 2) * 300, 0.4), i * step, 1.0)
        place(out, clunk(300 + (i % 3) * 40, 0.04, 0.25), i * step, 1.0)
    return out * gain


@punched(FAST, thump_hz=(160.0, 70.0), thump_gain=0.3)
def tkr_fire():
    """One ticket fired: the dispenser's clack, a paper snap and a small punchy "tk"."""
    d = 0.14
    out = _sub_thump(170, 75, d, 0.03) * 0.8
    place(out, click(0.012, 1500, 0.5), 0.0, 1.0)
    place(out, _paper(0.05, 2300, 1600, 0.45), 0.002, 1.0)
    place(out, sweep(900, 320, 0.05, "tri", curve=0.6) * env(0.05, 0.001, 0.04, power=1.8) * 0.35, 0.0, 1.0)
    return filt(out, low=6500)


@punched(MID, thump_hz=(130.0, 55.0), thump_gain=0.5)
def tkr_winner():
    """The golden WINNER ticket: a fatter shot, a whoosh of gold and a jackpot bell chord."""
    d = 0.5
    out = _sub_thump(140, 55, d, 0.06)
    place(out, click(0.015, 1300, 0.7), 0.0, 1.0)
    place(out, _paper(0.08, 2000, 1500, 0.5, seed=7), 0.0, 1.0)
    place(out, sweep(1200, 300, 0.12, "saw", curve=0.6) * env(0.12, 0.001, 0.1, power=1.6) * 0.18, 0.0, 1.0)
    place(out, _bell((784, 988, 1175), 0.025, 0.45, 0.8), 0.02, 1.0)
    return filt(out, low=8000)


@punched(HIT)
def tkr_pop():
    """The ticket burst: a papery pop and a flutter of tickets with a bright ding."""
    d = 0.6
    out = silence(d)
    place(out, _sub_thump(180, 70, 0.2, 0.05), 0.0, 1.0)
    place(out, _paper(0.07, 1800, 1400, 0.9, seed=9), 0.0, 1.0)
    rnd = np.random.default_rng(11)
    for _ in range(12):
        place(out, _paper(0.025, rnd.uniform(1500, 3000), 900, rnd.uniform(0.15, 0.35), seed=int(rnd.integers(1, 999))), rnd.uniform(0.03, 0.45), 1.0)
    place(out, _bell((880, 1047), 0.05, 0.5, 0.3), 0.03, 1.0)
    return filt(out, low=8000)


@punched(CUE)
def tkr_ready():
    """A winner is printed: a two-note arcade ding-ding."""
    d = 0.5
    out = _bell((1047, 1568), 0.08, d, 1.0)
    place(out, click(0.01, 1800, 0.3), 0.0, 1.0)
    return filt(out, low=8000)


def tkr_break():
    """The streak breaks: a quick, soft descending buzz (not a punishment)."""
    d = 0.28
    body = sweep(420, 180, d, "square", curve=0.7) * 0.12 + sweep(210, 90, d, "tri") * 0.2
    return filt(body * env(d, 0.005, d, power=1.4), low=2500)


@punched(HANDLE)
def tkr_crank():
    """The reload starts: the dispenser crank ratchets round."""
    return filt(_ratchet(5, 0.045, 1600), low=7000)


@punched(HANDLE)
def tkr_door():
    """The counter door: a latch clack and a short hinge creak."""
    d = 0.3
    out = silence(d)
    place(out, clunk(260, 0.08, 0.8), 0.0, 1.0)
    place(out, click(0.012, 1900, 0.5), 0.0, 1.0)
    creak = tone(620, 0.16, "tri", vibrato=0.06, vib_rate=26) * env(0.16, 0.03, 0.16, power=1.0) * 0.08
    place(out, creak, 0.03, 1.0)
    return filt(out, low=6000)


@punched(HANDLE)
def tkr_eject():
    """The empty spool pops off the axle and flutters away."""
    d = 0.45
    out = silence(d)
    place(out, sweep(500, 900, 0.06, "sine") * env(0.06, 0.002, 0.06, power=1.6) * 0.6, 0.0, 1.0)
    place(out, clunk(200, 0.08, 0.6), 0.0, 1.0)
    whoosh = band(noise(0.3), 900, 700) * env(0.3, 0.12, 0.3, power=0.9, release=0.1) * 0.35
    place(out, whoosh, 0.05, 1.0)
    return filt(out, low=6000)


def tkr_holo():
    """The hologram roll prints in: a rising shimmer hum with a sparkle of bells."""
    d = 0.55
    hum = sweep(220, 440, d, "tri") * 0.3 + sweep(440, 880, d) * 0.08
    shimmer = band(noise(d), 2600, 1200) * 0.05
    out = (hum + shimmer) * env(d, 0.15, d, power=0.9, release=0.1)
    place(out, _bell((659, 784, 988), 0.07, 0.4, 0.35), 0.15, 1.0)
    return filt(out, low=6500)


@punched(CUE)
def tkr_snap():
    """The fresh roll snaps onto the axle: a solid clunk, a ratchet tick and a bell."""
    d = 0.5
    out = _sub_thump(190, 80, d, 0.07)
    place(out, clunk(230, 0.12, 1.0), 0.0, 1.0)
    place(out, _ratchet(2, 0.03, 1700, 0.6), 0.02, 1.0)
    place(out, _bell((880,), 0.0, 0.45, 0.5), 0.04, 1.0)
    return filt(out, low=8000)


@punched(HANDLE)
def tkr_tear():
    """The operator tears off the leading ticket: a crisp paper rip."""
    d = 0.22
    out = _rip(d, 1.0)
    place(out, _paper(0.03, 1900, 1200, 0.5, seed=13), d * 0.8, 1.0)
    return filt(out, low=7000)


@punched(HANDLE)
def tkr_equip():
    """Raised: a crank tick, a paper riffle and a little ding."""
    d = 0.45
    out = silence(d)
    place(out, _ratchet(2, 0.04, 1600, 0.8), 0.0, 1.0)
    place(out, _rip(0.12, 0.35, seed=8), 0.08, 1.0)
    place(out, _bell((1175,), 0.0, 0.35, 0.35), 0.16, 1.0)
    return filt(out, low=7000)


SOUNDS = [tkr_fire, tkr_winner, tkr_pop, tkr_ready, tkr_break, tkr_crank, tkr_door, tkr_eject, tkr_holo, tkr_snap,
          tkr_tear, tkr_equip]

VARIANTS = [(tkr_fire, (0.94, 1.06)), (tkr_pop, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
