"""The two carnival sidearms of update 7: the Sparkler (firework machine
pistol) and the Ring Toss (hoop launcher). Punchy and short, with the top
end rolled off so the Sparkler's fast fire never turns shrill. All names
start with "gn2_" (audio/mix.tres puts fire on "weapon", the rest on
"handling" or "impact").

    python tools/gen_audio.py guns_new2
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _laser_layer, _shimmer, _sub_thump


def _fizz(d, density=0.04, centre=3200, seed=11):
    """Firework fizz: sparse crackles through a soft band, no hiss on top."""
    r = np.random.default_rng(seed)
    pops = (r.uniform(0, 1, int(SR * d)) < density).astype(float) * r.uniform(-1, 1, int(SR * d))
    return band(pops, centre, centre * 0.55) * 5.0 + band(noise(d), centre * 0.8, 900) * 0.35


def _whoosh(d, f0=500, f1=1800, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


def _ting(freq, d, gain=1.0):
    """A small bell: two inharmonic partials ringing out."""
    return (tone(freq, d) + tone(freq * 2.76, d) * 0.35 + tone(freq * 5.4, d) * 0.12) * env(d, 0.001, d, power=2.4) * gain


# ---------------------------------------------------------------------------
# Sparkler
# ---------------------------------------------------------------------------

def gn2_sparkler_fire():
    """One spark round: a tight pop, a short downward zip and a crackle (fired 14 times a second)."""
    d = 0.11
    pop = filt(noise(d), high=900, low=5200) * env(d, 0.0004, 0.018, power=2.0) * 1.1
    zip_ = _laser_layer(1900, 520, d, 0.5, "tri") * env(d, 0.0008, 0.05, power=2.0) * 0.32
    sub = _sub_thump(190, 80, d, 0.045) * 0.9
    crackle = _fizz(d, 0.06, 2800, seed=3) * env(d, 0.003, 0.1, power=1.6) * 0.3
    return crush(filt(pop + zip_ + sub + crackle, low=7500), 1.35)


def gn2_sparkler_equip():
    """Raised: a lighter-wheel rasp and a fizzing catch."""
    out = silence(0.4)
    place(out, _whoosh(0.12, 400, 1400, 0.4), 0.0, 1.0)
    place(out, filt(_fizz(0.08, 0.2, 2400, seed=5), low=6000) * env(0.08, 0.002, power=1.2), 0.1, 0.5)
    place(out, clunk(300, 0.06), 0.16, 0.5)
    place(out, _fizz(0.22, 0.05, 3000, seed=6) * env(0.22, 0.03, power=1.4), 0.18, 0.35)
    return filt(out, low=8000)


def gn2_sparkler_reload():
    """Canister pops off and tumbles, a new one prints in and clicks home (the match and fuse are their own sounds)."""
    out = silence(1.6)
    place(out, clunk(260, 0.08), 0.2, 0.7)                                         # canister release
    place(out, _whoosh(0.16, 600, 1800, 0.35), 0.22, 1.0)                          # it tumbles away
    place(out, band(noise(0.2), 2200, 800) * env(0.2, 0.04, power=1.0), 0.6, 0.3)  # new one prints in
    place(out, clunk(320, 0.09), 0.86, 0.85)                                       # seats
    place(out, _whoosh(0.12, 300, 900, 0.3), 1.36, 1.0)                            # match flicked away
    return filt(out, low=9000)


def gn2_sparkler_match():
    """Strike-anywhere match: a scratch and the soft whoomph of the flame catching."""
    d = 0.6
    out = silence(d)
    scratch = band(noise(0.07), 2600, 1400) * env(0.07, 0.004, power=1.0) * 0.8
    place(out, scratch, 0.0, 1.0)
    whoomph = filt(noise(0.35), low=1200, high=120) * env(0.35, 0.02, 0.3, power=1.4) * 0.9
    place(out, whoomph, 0.05, 1.0)
    place(out, _fizz(0.4, 0.03, 2600, seed=8) * env(0.4, 0.02, power=1.8), 0.08, 0.35)
    return filt(out, low=8000)


def gn2_sparkler_fizz():
    """The fuse catching: a fizzing rush that runs down the canister and settles to a crackle."""
    d = 0.7
    rush = _fizz(d, 0.09, 3000, seed=9) * env(d, 0.02, 0.6, power=1.3)
    swell = band(noise(d), 1800, 900) * env(d, 0.06, 0.4, power=1.2) * 0.35
    lift = sweep(500, 1300, d, "sine", 0.6) * env(d, 0.03, 0.35, power=1.6) * 0.12
    return filt(rush * 0.6 + swell + lift, low=8000)


# ---------------------------------------------------------------------------
# Ring Toss
# ---------------------------------------------------------------------------

def gn2_ring_fire():
    """The flipper slaps and the hoop spins off with a rising whirr."""
    d = 0.42
    slap = filt(noise(d), high=700, low=4500) * env(d, 0.0004, 0.025, power=2.0) * 1.0
    thump = _sub_thump(160, 60, d, 0.1) * 1.2
    whirr = sweep(260, 520, d, "tri", 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 34 * t_axis(d))) * env(d, 0.01, 0.38, power=1.6) * 0.3
    air = band(noise(d), 1500, 700) * env(d, 0.01, 0.3, power=1.5) * 0.35
    return crush(filt(slap + thump + whirr + air, low=8000), 1.3)


def gn2_ring_ricochet():
    """The hoop clangs off a zombie: a ringing hoop note over a soft thud."""
    d = 0.32
    thud = filt(noise(d), low=1200) * env(d, 0.001, 0.05, power=2.0) * 0.8
    ring = _ting(1180, d, 0.45)
    zing = sweep(1500, 2300, d, "sine", 0.5) * env(d, 0.002, 0.12, power=2.0) * 0.12
    return filt(thud + ring + zing, low=8500)


def gn2_ring_bounce():
    """Off a wall: a hollow plastic bonk."""
    d = 0.18
    bonk = sweep(520, 300, d, "tri", 0.5) * env(d, 0.001, 0.09, power=2.0) * 0.6
    knock = filt(noise(d), low=2500, high=300) * env(d, 0.0005, 0.03, power=2.0) * 0.7
    return filt(bonk + knock, low=7000)


def gn2_ring_catch():
    """Home again: the hoop drops over the peg with a carnival ding."""
    d = 0.55
    out = silence(d)
    place(out, clunk(340, 0.07), 0.0, 0.6)
    place(out, _ting(1568, 0.5, 0.45), 0.01, 1.0)
    place(out, _ting(2093, 0.4, 0.22), 0.07, 1.0)
    return filt(out, low=9000)


def gn2_ring_toss():
    """The reload flourish: the hoop flipped up and spinning."""
    d = 0.4
    flip = clunk(380, 0.06)
    whirr = sweep(700, 380, d, "tri", 1.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t_axis(d))) * env(d, 0.02, 0.36, power=1.2) * 0.25
    out = whirr.copy()
    place(out, flip, 0.0, 0.7)
    return filt(out, low=7500)


def gn2_ring_equip():
    """Raised: a hoop rolling round the cradle and settling."""
    d = 0.42
    roll = sweep(300, 620, d, "tri", 0.7) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_axis(d))) * env(d, 0.03, 0.4, power=1.0) * 0.25
    out = roll.copy()
    place(out, clunk(300, 0.06), 0.3, 0.6)
    place(out, _ting(1320, 0.12, 0.15), 0.31, 1.0)
    return filt(out, low=8000)


def gn2_ring_reload():
    """Spine drops out, the hand swats it away, a new stack prints in and is shoved home."""
    out = silence(1.9)
    place(out, clunk(220, 0.09), 0.28, 0.75)                                        # spine released
    place(out, _whoosh(0.14, 500, 1600, 0.35), 0.5, 1.0)                            # swatted away
    for i in range(4):                                                              # hoops print in
        place(out, _ting(990 + i * 130, 0.08, 0.08), 0.75 + i * 0.07, 1.0)
    place(out, band(noise(0.16), 2000, 700) * env(0.16, 0.03, power=1.0), 0.8, 0.3)
    place(out, clunk(260, 0.11), 1.14, 0.9)                                         # shoved home
    return filt(out, low=8500)


SOUNDS = [
    gn2_sparkler_fire, gn2_sparkler_equip, gn2_sparkler_reload, gn2_sparkler_match, gn2_sparkler_fizz,
    gn2_ring_fire, gn2_ring_ricochet, gn2_ring_bounce, gn2_ring_catch, gn2_ring_toss, gn2_ring_equip, gn2_ring_reload,
]

VARIANTS = [
    (gn2_sparkler_fire, (0.94, 1.06)), (gn2_ring_fire, (0.95, 1.05)), (gn2_ring_ricochet, (0.92, 1.1)),
]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
