"""The Coin-Op (coin_op), an arcade token machine pistol: every token is a
tight brass "chik" (the coin mech clacking over, a short metallic glint, a
low thump) that fires 12-15 times a second, so it stays dark and short and
sits under the big single shots; the Free Play payout is a slot-machine
ka-ching (a rising coin-bell arpeggio over a hopper chunk and tokens
clattering into a tray), the tilt a pinball TILT buzzer, and the reload a
slap on the coin return, a rattle of spent tokens, a hologram roll printing
in, the crack of the roll breaking open and a stack of tokens dropping into
the slot. All names start with "cop_" (audio/mix.tres puts the shot on
"weapon", the payout on "impact", the rest on "handling").

    python tools/gen_audio.py coin_op
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _glint(freq, d, gain=1.0, decay=None):
    """A brass token's ring: inharmonic partials with a fast decay (no long whistle)."""
    out = silence(d)
    for ratio, g in ((1.0, 1.0), (2.41, 0.5), (3.93, 0.25), (5.6, 0.1)):
        out += tone(freq * ratio, d) * env(d, 0.0006, (decay or d) / ratio ** 0.5, power=2.2) * g
    return out * gain


def _coin_bell(freq, d, gain=1.0):
    """A small coin-machine bell (the payout's notes): warm partials, a medium ring."""
    out = silence(d)
    for ratio, g in ((1.0, 1.0), (2.0, 0.25), (2.76, 0.3), (5.4, 0.08)):
        out += tone(freq * ratio, d) * env(d, 0.001, d / ratio ** 0.45, power=1.8) * g
    return out * gain


def _clatter(d, count, seed, lo=1700.0, hi=3000.0, gain=1.0):
    """Tokens tumbling into a tray: little glints and ticks at random moments."""
    rng = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        f = rng.uniform(lo, hi)
        at = rng.uniform(0.0, max(0.01, d - 0.08))
        place(out, _glint(f, 0.07, 0.16, 0.04), at, 1.0)
        place(out, fx.tick(int(rng.integers(1, 10000)), f * 0.7, 0.012, 0.5), at, 1.0)
    return filt(out, low=6500) * gain


def _mech(seed, gain=1.0):
    """The coin mech clacking over: a hollow plastic-and-brass knock."""
    d = 0.05
    knock = (tone(420, d, "tri") + tone(1130, d) * 0.25) * env(d, 0.0005, 0.022, power=2.6)
    place(knock, fx.tick(seed, 2100, 0.012, 1.4), 0.0, 1.0)
    return knock * gain


def cop_fire():
    """One token (12-15 a second): mech clack, a short brass glint and a low thump."""
    d = 0.1
    out = _sub_thump(200, 85, d, 0.04) * 0.85
    place(out, _mech(9101, 1.1), 0.0, 1.0)
    place(out, _glint(1240, 0.07, 0.34, 0.03), 0.004, 1.0)
    place(out, filt(noise(d), high=900, low=4200) * env(d, 0.0004, 0.016, power=2.2) * 0.9, 0.0, 1.0)
    return fx.fire(out, 9111, 3200, 0.45, (135, 62, 0.035, 0.65), 0.07, 0.03, 0.12, 1.35, 7000, 0.22)


def cop_payout():
    """Free Play: a hopper chunk, a rising coin-bell arpeggio and tokens clattering into the tray."""
    d = 0.75
    out = silence(d)
    place(out, clunk(170, 0.1, 0.7), 0.0, 1.0)
    place(out, _sub_thump(140, 70, 0.12, 0.06) * 0.6, 0.0, 1.0)
    for i, f in enumerate((1047.0, 1319.0, 1568.0)):
        place(out, _coin_bell(f, 0.26 - i * 0.03, 0.2), 0.035 + i * 0.055, 1.0)
    place(out, _clatter(0.5, 12, 9121, gain=1.2), 0.06, 1.0)
    return fx.fire(out, 9131, 2800, 0.3, (120, 55, 0.08, 0.7), 0.25, 0.05, 0.2, 1.1, 7500, 0.2)


def cop_tilt():
    """TILT: a pinball buzzer (dark, short) and the cabinet's thunk."""
    d = 0.32
    buzz = filt(tone(110, d, "square") * 0.45 + tone(220, d, "square") * 0.25 + tone(440, d, "saw") * 0.12, low=3200, high=140)
    buzz *= env(d, 0.004, d, sustain=0.6, release=0.08, power=1.0) * (0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 30 * t_axis(d))))
    out = buzz * 0.55
    place(out, clunk(130, 0.1, 0.6), 0.0, 1.0)
    return filt(out, low=5000)


def cop_equip():
    """Raised: a token flipped and caught, the mech clacks, the marquee hums on."""
    out = silence(0.36)
    place(out, _glint(1500, 0.18, 0.22, 0.12), 0.0, 1.0)
    place(out, _mech(9141, 0.7), 0.12, 1.0)
    place(out, _mech(9142, 0.6), 0.17, 1.0)
    fx.place_at(out, fx.holo(0.14, 500, 1100, 9143, 0.12), 0.18)
    fx.place_at(out, fx.latch(9144, 220, 0.8), 0.2)
    return filt(out, low=7500) * 1.5


def cop_reload():
    """Coin return (1.55 s): the slap, spent tokens rattling out, a hologram roll printing in,
    the roll cracked open, tokens dropping into the slot, the wheel ratcheting and the ka-ching."""
    out = silence(1.55)
    slap = filt(noise(0.06), high=250, low=2600) * env(0.06, 0.0005, 0.03, power=2.4)
    place(out, slap + _sub_thump(170, 90, 0.06, 0.03) * 0.7, 0.3, 1.0)        # the hand slaps the paddle
    place(out, clunk(260, 0.08, 0.6), 0.32, 1.0)                                # the flap kicks open
    place(out, _clatter(0.32, 8, 9151, 1500, 2600, 0.8), 0.33, 1.0)            # spent tokens rattle out
    fx.place_at(out, fx.holo(0.3, 600, 1500, 9152, 0.16), 0.46)               # the roll prints in
    crack = filt(noise(0.05), high=900, low=5000) * env(0.05, 0.0004, 0.02, power=2.2)
    place(out, crack, 0.82, 0.8)                                                # the roll cracks open
    place(out, _clatter(0.12, 4, 9153, 2200, 3200, 0.5), 0.83, 1.0)
    for i in range(6):                                                          # tokens drop into the slot
        place(out, _glint(1700 + 90 * i, 0.06, 0.13, 0.03), 0.9 + i * 0.045, 1.0)
        fx.place_at(out, fx.tick(9160 + i, 2400, 0.01, 0.6), 0.9 + i * 0.045)
    for i in range(8):                                                          # the star wheel ratchets
        place(out, click(0.01, 1900 + 60 * i, 0.22 - 0.015 * i), 1.03 + i * 0.03 * (1.0 + i * 0.08), 1.0)
    place(out, clunk(230, 0.1, 0.7), 1.3, 1.0)                                  # the credit lands
    place(out, _coin_bell(1319.0, 0.3, 0.28), 1.32, 1.0)
    place(out, _coin_bell(1760.0, 0.26, 0.2), 1.37, 1.0)
    fx.place_at(out, fx.latch(9171, 240), 1.3)
    return filt(out, low=8000)


SOUNDS = [cop_fire, cop_payout, cop_tilt, cop_equip, cop_reload]

VARIANTS = [(cop_fire, (0.95, 1.05)), (cop_payout, (0.97, 1.03))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
