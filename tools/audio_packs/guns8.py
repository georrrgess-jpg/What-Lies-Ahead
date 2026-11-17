"""Lane guns8 of update 8: the Teacup Twister (vortex launcher) and the Dunk
Tank (water pistol). Punchy and round, the top end rolled off so the Dunk
Tank's 12 shots a second never turn shrill. All names start with "gn8_"
(audio/mix.tres puts the fire sounds on "weapon", the whirl and pop on
"impact", the rest on "handling"). The reload sounds follow their reload
scripts' timelines (2.3 s and 1.7 s).

    python tools/gen_audio.py guns8
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import HEAVY, punched

MUSIC = {}
LOOPS = {}


def _whoosh(d, f0=500, f1=1800, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


def _ting(freq, d, gain=1.0):
    """A china cup struck: two inharmonic partials ringing out."""
    return (tone(freq, d) + tone(freq * 2.71, d) * 0.3 + tone(freq * 5.1, d) * 0.1) * env(d, 0.001, d, power=2.6) * gain


def _bloop(f0, f1, d, gain=1.0):
    """A water bubble: a quick upward-gliding sine."""
    return sweep(f0, f1, d, "sine", 0.6) * env(d, 0.002, d, power=2.2) * gain


def _splash(d, gain=1.0, seed=4):
    """Water hitting: soft filtered noise with a few droplets on top."""
    r = np.random.default_rng(seed)
    body = filt(noise(d), low=3200, high=350) * env(d, 0.002, d * 0.6, power=1.6)
    drops = (r.uniform(0, 1, int(SR * d)) < 0.0015).astype(float) * r.uniform(0.3, 1.0, int(SR * d))
    return (body + band(drops, 1800, 500) * 4.0) * gain


# ---------------------------------------------------------------------------
# Teacup Twister
# ---------------------------------------------------------------------------

@punched(HEAVY)
def gn8_twister_fire():
    """A hollow mortar 'thoonk' and the cup whirring off."""
    d = 0.5
    thoonk = _sub_thump(150, 55, d, 0.16) * 1.5
    pop = filt(noise(d), high=300, low=3000) * env(d, 0.0005, 0.03, power=2.0) * 0.8
    whirr = sweep(300, 640, d, "tri", 0.7) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t_axis(d))) * env(d, 0.01, 0.42, power=1.5) * 0.28
    clink = _ting(1320, 0.3, 0.2)
    out = thoonk + pop + whirr
    place(out, clink, 0.01, 1.0)
    return crush(filt(out, low=7000), 1.4)


def gn8_twister_whirl():
    """The whirl opening and spinning up for 1.8 s: a rising, wobbling whoosh over a calliope swirl."""
    d = 1.85
    t = t_axis(d)
    rise = np.clip(t / d, 0, 1)
    n = noise(d)
    wind = (band(n, 700, 400) * (1.0 - rise) + band(n, 1500, 600) * rise) * (0.55 + 0.45 * np.sin(2 * np.pi * (3 + 9 * rise) * t)) * env(d, 0.15, d, sustain=0.8, release=0.1, power=0.6) * 0.8
    swirl = sweep(220, 520, d, "tri", 1.2) * (0.5 + 0.5 * np.sin(2 * np.pi * (5 + 12 * rise) * t)) * 0.18 * env(d, 0.2, d, sustain=0.9, release=0.08, power=0.5)
    open_ = _sub_thump(120, 60, 0.4, 0.2) * 0.9
    out = wind + swirl
    place(out, open_, 0.0, 1.0)
    place(out, _ting(988, 0.6, 0.25), 0.02, 1.0)
    return filt(out, low=6500)


@punched(HEAVY, thump_hz=(95.0, 38.0))
def gn8_twister_pop():
    """The cup bursting: a round boom, a china crack and a puff of confetti."""
    d = 0.9
    boom = _sub_thump(120, 40, d, 0.35) * 1.6
    body = filt(noise(d), low=1800, high=60) * env(d, 0.001, 0.25, power=1.8) * 1.0
    crack = filt(noise(0.06), high=1200, low=6000) * env(0.06, 0.0005, 0.04, power=2.0) * 0.6
    out = boom + body
    place(out, crack, 0.0, 1.0)
    place(out, _ting(1568, 0.5, 0.2), 0.01, 1.0)
    place(out, band(noise(0.5), 2600, 900) * env(0.5, 0.02, 0.4, power=1.6) * 0.18, 0.05, 1.0)
    return crush(filt(out, low=7500), 1.5)


def gn8_twister_equip():
    """Raised: the carousel ratchets round a step and the cup chimes."""
    out = silence(0.45)
    for i in range(3):
        place(out, clunk(420 + 40 * i, 0.05), 0.04 + 0.06 * i, 0.4)
    place(out, _whoosh(0.18, 300, 900, 0.3), 0.0, 1.0)
    place(out, _ting(1175, 0.3, 0.25), 0.22, 1.0)
    return filt(out, low=8000)


def gn8_twister_reload():
    """2.3 s: roll-over clunk, four cups popping out, cups printing in and
    seating, the flick whirr slowing to a click and a china ding."""
    d = 2.3
    out = silence(d)
    place(out, clunk(240, 0.09), 0.2, 0.7)                                       # roll over, carousel unlocks
    place(out, _whoosh(0.5, 400, 1400, 0.25), 0.27, 1.0)                         # spin-out
    for i in range(4):
        place(out, _bloop(500 + 90 * i, 900 + 120 * i, 0.08, 0.35), 0.37 + 0.092 * i, 1.0)   # cups pop off
    place(out, band(noise(0.45), 2200, 800) * env(0.45, 0.06, power=1.0) * 0.22, 0.83, 1.0)  # print in
    place(out, clunk(330, 0.1), 1.33, 0.85)                                      # seated
    t = t_axis(0.6)
    flick = sweep(900, 300, 0.6, "tri", 0.6) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (26 - 30 * t / 0.6) * t))) * env(0.6, 0.005, 0.6, power=1.2) * 0.16
    place(out, flick, 1.58, 1.0)                                                 # flicked round, ratchet slowing
    place(out, clunk(520, 0.05), 2.1, 0.6)                                       # click to a stop
    place(out, _ting(1568, 0.5, 0.35), 2.12, 1.0)                                # ding
    place(out, _ting(2093, 0.4, 0.15), 2.17, 1.0)
    return filt(out, low=8500)


# ---------------------------------------------------------------------------
# Dunk Tank
# ---------------------------------------------------------------------------

def gn8_dunk_fire():
    """One pulse of the jet (fired 12 times a second): a soft wet 'pshh' with a low push."""
    d = 0.1
    psh = filt(noise(d), high=500, low=3600) * env(d, 0.002, 0.06, power=1.5) * 0.7
    push = _sub_thump(170, 90, d, 0.04) * 0.8
    gurgle = _bloop(380, 520, d, 0.12)
    return crush(filt(psh + push + gurgle, low=5500), 1.2)


def gn8_dunk_pump():
    """The pump sleeve stroking: a plastic slide and a little air gasp."""
    d = 0.18
    slide = band(noise(d), 1300, 500) * env(d, 0.01, 0.12, power=1.4) * 0.5
    gasp = filt(noise(d), low=2500, high=600) * env(d, 0.04, 0.12, power=1.2) * 0.3
    out = slide + gasp
    place(out, clunk(360, 0.04), 0.12, 0.35)
    return filt(out, low=6000)


def gn8_dunk_equip():
    """Raised: a slosh in the tank and a pump click."""
    out = silence(0.4)
    place(out, _splash(0.25, 0.4, seed=7), 0.0, 1.0)
    place(out, _bloop(300, 600, 0.12, 0.3), 0.05, 1.0)
    place(out, clunk(380, 0.05), 0.24, 0.5)
    return filt(out, low=6500)


def gn8_dunk_reload():
    """1.7 s: tank unlatched and dropping with a slosh, a new one printing in
    and seated, water rushing in, two pumps, a test squirt and the bullseye
    flipping with a dunk-tank bell."""
    d = 1.7
    out = silence(d)
    place(out, clunk(260, 0.08), 0.24, 0.6)                                      # unlatch
    place(out, _splash(0.3, 0.45, seed=9), 0.28, 1.0)                            # slosh as it drops
    place(out, band(noise(0.3), 2000, 700) * env(0.3, 0.05, power=1.0) * 0.2, 0.65, 1.0)   # print in
    place(out, clunk(320, 0.09), 1.02, 0.85)                                     # seated
    for i in range(4):
        place(out, _bloop(260 + 70 * i, 420 + 90 * i, 0.09, 0.22), 1.03 + 0.07 * i, 1.0)     # water rushing in
    place(out, gn8_dunk_pump(), 1.12, 0.6)
    place(out, gn8_dunk_pump(), 1.26, 0.6)
    place(out, filt(noise(0.25), high=500, low=3500) * env(0.25, 0.01, 0.2, power=1.4) * 0.5, 1.46, 1.0)  # squirt
    place(out, _ting(1397, 0.3, 0.3), 1.5, 1.0)                                  # bell
    return filt(out, low=8000)


SOUNDS = [gn8_twister_fire, gn8_twister_whirl, gn8_twister_pop, gn8_twister_equip, gn8_twister_reload,
          gn8_dunk_fire, gn8_dunk_pump, gn8_dunk_equip, gn8_dunk_reload]
VARIANTS = [(gn8_dunk_fire, (0.94, 1.06)), (gn8_twister_pop, (0.95, 1.05)), (gn8_twister_fire, (0.95, 1.05))]
