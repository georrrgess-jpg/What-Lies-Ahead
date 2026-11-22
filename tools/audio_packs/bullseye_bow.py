"""The Bullseye Longbow (update 24 primary): a carnival recurve. The draw is a
rising wooden creak with the string's stretch, the loose a deep string thrum
and a feathered whoosh, arrows land with a woody thunk (a quiver in its
tail); the Bullseye adds a bright gallery bell. The nock is a cloth rustle
from the quiver, a light tap on the shelf and a crisp plastic click. All
names start with "bb_" (audio/mix.tres puts the loose on "weapon", the
thunk, pin and Bullseye bell on "impact", the rest on "handling").

    python tools/gen_audio.py bullseye_bow
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HANDLE, HEAVY, HIT, punched

MUSIC = {}
LOOPS = {}


def _creak(d, f0, f1, grit=1.0, seed=1):
    """Wood under load: a slow pitched groan made of tiny stick-slip ticks."""
    rs = np.random.default_rng(seed)
    t = t_axis(d)
    freq = f0 + (f1 - f0) * (t / d) ** 1.3
    out = silence(d)
    phase = 0.0
    i = 0
    while True:
        at = phase
        if at >= d - 0.01:
            break
        k = min(len(freq) - 1, int(at * SR))
        tick = click(0.006, rs.uniform(900, 1500), rs.uniform(0.25, 0.6) * grit)
        place(out, tick, at, 1.0)
        phase += 1.0 / max(20.0, freq[k]) * rs.uniform(0.8, 1.2)
        i += 1
    body = band(out, 700, 500) * 1.6 + tone(f0 * 0.5, d, "tri") * 0.08 * env(d, 0.05, d, sustain=0.5, power=1.0)
    return body


def _thrum(d, f=96.0, gain=1.0):
    """A plucked bowstring: a low fundamental with a few decaying partials and a buzz."""
    out = silence(d)
    for n, a in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.08)):
        out += tone(f * n * (1 + 0.002 * n), d) * a * env(d, 0.001, d / (0.8 + n * 0.5), power=1.6)
    buzz = band(noise(d), f * 9, f * 4) * env(d, 0.001, d * 0.25, power=2.0) * 0.25
    return (out + buzz) * gain


def _whoosh(d, f0=2200, f1=700, gain=1.0):
    """An arrow leaving: a feathered hiss that drops in pitch."""
    t = t_axis(d)
    centre = f0 + (f1 - f0) * t / d
    out = np.zeros_like(t)
    src = noise(d)
    # A moving band: blend a few fixed bands by where the centre is.
    for c in (2400, 1600, 1100, 750):
        w = np.clip(1.0 - np.abs(centre - c) / 700.0, 0.0, 1.0)
        out += band(src, c, c * 0.5) * w
    return out * env(d, 0.012, d, power=1.5) * gain


def _wood_knock(freq, d=0.14, gain=1.0):
    body = (tone(freq, d) + tone(freq * 2.6, d) * 0.3) * env(d, 0.0006, d * 0.55, power=2.4)
    snap_ = band(noise(d), freq * 3.0, freq) * env(d, 0.0004, 0.015, power=2.0) * 1.2
    return (body + snap_) * gain


def _bell(freq, d=0.6, gain=1.0):
    """A small brass gallery bell."""
    out = silence(d)
    for ratio, a in ((1.0, 1.0), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1)):
        out += tone(freq * ratio, d) * a * env(d, 0.001, d / (1 + ratio * 0.4), power=1.4)
    return out * gain


@punched(HEAVY, thump_hz=(110.0, 45.0))
def bb_fire():
    """The loose: the string slaps forward and thrums, the arrow whooshes away."""
    d = 0.55
    out = silence(d)
    place(out, _sub_thump(160, 60, 0.2, 0.06) * 0.9, 0.0, 1.0)
    place(out, _thrum(0.5, 92.0, 1.0), 0.0, 1.0)
    place(out, _wood_knock(380, 0.08, 0.5), 0.0, 1.0)
    place(out, _whoosh(0.32, 2600, 900, 0.7), 0.01, 1.0)
    return crush(filt(out, low=7500), 1.2)


def bb_draw():
    """The draw: the limbs creak as they load and the string stretches, over the charge time."""
    d = 0.78
    out = _creak(d, 30, 75, 1.0, seed=3) * env(d, 0.06, d, sustain=0.8, power=1.0, release=0.04)
    stretch = sweep(140, 210, d, "tri") * 0.12 * env(d, 0.15, d, sustain=0.7, power=1.0, release=0.05)
    place(out, click(0.01, 1800, 0.25), 0.0, 1.0)
    return filt(out + stretch, low=5000)


@punched(CUE)
def bb_ready():
    """Full draw: the Bullseye window opens with a soft high ping."""
    out = silence(0.35)
    place(out, _bell(1568, 0.3, 0.35), 0.0, 1.0)
    return filt(out, low=9000)


@punched(HIT)
def bb_bullseye():
    """A Bullseye loosed: a bright gallery bell over a little sparkle."""
    d = 0.8
    out = silence(d)
    place(out, _bell(1175, 0.75, 0.6), 0.0, 1.0)
    place(out, _bell(1760, 0.6, 0.35), 0.05, 1.0)
    place(out, band(noise(0.3), 7000, 2500) * env(0.3, 0.004, 0.3, power=2.0) * 0.12, 0.0, 1.0)
    return filt(out, low=11000)


@punched(HIT, hp=60.0)
def bb_thunk():
    """An arrow strikes scenery: a woody thunk and the shaft's quick buzz."""
    d = 0.4
    out = _sub_thump(140, 70, d, 0.05) * 0.9
    place(out, _wood_knock(300, 0.14, 1.0), 0.0, 1.0)
    t = t_axis(0.3)
    buzz = tone(48.0, 0.3, "saw") * (0.5 + 0.5 * np.sin(2 * np.pi * 34 * t)) * env(0.3, 0.004, 0.3, power=1.6) * 0.18
    place(out, filt(buzz, low=1800), 0.02, 1.0)
    return crush(filt(out, low=6000), 1.3)


@punched(HIT)
def bb_pin():
    """A Bullseye pins a zombie: a heavy thwack with a ring of the bell."""
    d = 0.5
    out = _sub_thump(130, 55, d, 0.08) * 1.1
    place(out, _wood_knock(240, 0.12, 0.9), 0.0, 1.0)
    place(out, _bell(988, 0.4, 0.25), 0.02, 1.0)
    return crush(filt(out, low=7000), 1.3)


def bb_letdown():
    """The arm gives out: the string eases forward with a falling creak."""
    d = 0.5
    out = _creak(d, 60, 22, 0.8, seed=7) * env(d, 0.02, d, power=1.3)
    return filt(out, low=4500, high=160)


@punched(CUE)
def bb_pickup():
    """An arrow back in the quiver: a quick wooden rattle and a bright blip."""
    out = silence(0.3)
    place(out, _wood_knock(900, 0.06, 0.5), 0.0, 1.0)
    place(out, _wood_knock(1200, 0.05, 0.35), 0.035, 1.0)
    place(out, blip(1318, 0.09, "tri", gain=0.35), 0.05, 1.0)
    place(out, blip(1976, 0.12, "tri", gain=0.3), 0.11, 1.0)
    return filt(out, low=9000)


@punched(HANDLE)
def bb_reach():
    """Reaching for the quiver: a cloth swish."""
    d = 0.22
    return filt(band(noise(d), 1500, 1100) * env(d, 0.05, d, power=1.4) * 0.6, low=6000)


def bb_quiver():
    """An arrow drawn from the quiver: feathers brushing and shafts rattling."""
    d = 0.32
    out = band(noise(d), 2600, 1800) * env(d, 0.03, d, power=1.3) * 0.45
    for i, f in enumerate((1300, 1650, 1100)):
        place(out, _wood_knock(f, 0.05, 0.25), 0.04 + i * 0.05, 1.0)
    return filt(out, low=8000)


def bb_rest():
    """The arrow laid on the shelf: a light tap and a short slide."""
    d = 0.18
    out = _wood_knock(1500, 0.05, 0.5)
    out = np.concatenate([out, silence(d - len(out) / SR)]) if len(out) < int(d * SR) else out
    place(out, band(noise(0.1), 3000, 1500) * env(0.1, 0.01, 0.1, power=1.5) * 0.2, 0.03, 1.0)
    return filt(out, low=8000)


@punched(HANDLE)
def bb_nock():
    """The nock clicks onto the string: a crisp plastic snap and a soft string tick."""
    out = silence(0.2)
    place(out, click(0.012, 3200, 0.9), 0.0, 1.0)
    place(out, click(0.01, 2100, 0.5), 0.012, 1.0)
    place(out, _thrum(0.15, 180.0, 0.25), 0.01, 1.0)
    return filt(out, low=9000)


@punched(HANDLE)
def bb_equip():
    """Taking up the bow: a wooden knock on the grip and the string's low hum."""
    out = silence(0.45)
    place(out, _wood_knock(420, 0.1, 0.7), 0.0, 1.0)
    place(out, _thrum(0.4, 98.0, 0.35), 0.03, 1.0)
    return filt(out, low=6000)


def bb_twang():
    """Inspect: the string plucked and left to ring."""
    return filt(_thrum(0.9, 110.0, 0.9), low=6000)


def bb_spin():
    """Inspect: the bow spun on its grip, a whoosh round and a knock as it is caught."""
    d = 0.55
    out = _whoosh(0.4, 900, 1800, 0.45)
    out = np.concatenate([out, silence(d - 0.4)])
    place(out, _wood_knock(380, 0.1, 0.5), 0.42, 1.0)
    return filt(out, low=6000)


SOUNDS = [bb_fire, bb_draw, bb_ready, bb_bullseye, bb_thunk, bb_pin, bb_letdown, bb_pickup, bb_reach, bb_quiver, bb_rest, bb_nock,
          bb_equip, bb_twang, bb_spin]
VARIANTS = [(bb_fire, (0.95, 1.05)), (bb_thunk, (0.9, 1.1))]
