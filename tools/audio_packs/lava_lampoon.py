"""The Volcano Isle primary, the Lava Lampoon (lava_lampoon): a lava-lamp
blaster. Gloopy, warm and a bit groovy: molten "bloops" with a fizzing hiss,
sizzling splats, and a reload of glass, gold threads, sloshing wax and a funky
chime when the lamp twist-locks. All names start with "weap_lava_"
(audio/mix.tres puts the shot on "weapon", the splat on "impact" and the rest
on "handling").

    python tools/gen_audio.py lava_lampoon
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, FAST, HANDLE, HIT, punched


def _bloop(f0, f1, d, gain=1.0):
    """A molten bubble: a fat sine dropping in pitch with a soft rounded attack."""
    body = sweep(f0, f1, d, "sine", curve=0.6) + sweep(f0 * 2.01, f1 * 2.0, d, "tri", curve=0.6) * 0.2
    return body * env(d, 0.004, d, power=1.7) * gain


def _sizzle(d, gain=1.0, centre=5200):
    return band(noise(d), centre, 3200) * env(d, 0.003, d, power=1.2) * gain


def _bubbles(d, count, f_lo, f_hi, gain=1.0, seed=3):
    rnd = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        f = rnd.uniform(f_lo, f_hi)
        place(out, _bloop(f, f * 1.6, 0.05, 0.25), rnd.uniform(0.0, d - 0.06), 1.0)
    return out * gain


def _chime(freqs, step, d, gain=1.0):
    out = silence(d)
    for i, f in enumerate(freqs):
        place(out, (tone(f, 0.4, "tri") + tone(f * 2, 0.4) * 0.25) * env(0.4, 0.003, 0.4, power=1.8) * 0.35, i * step, 1.0)
    return out * gain


@punched(FAST, thump_hz=(130.0, 55.0))
def weap_lava_fire():
    """A molten glob spat out: a fat bloop, a thump and a fizz off the muzzle."""
    d = 0.26
    out = _sub_thump(150, 60, d, 0.06) * 0.9
    place(out, _bloop(520, 170, 0.16, 0.85), 0.0, 1.0)
    place(out, _sizzle(0.16, 0.18), 0.01, 1.0)
    place(out, click(0.015, 1400, 0.35), 0.0, 1.0)
    return crush(filt(out, low=7000), 1.4)


@punched(HIT)
def weap_lava_splat():
    """The glob lands: a wet splat and a hiss of sizzling lava."""
    d = 0.4
    splat = filt(noise(d), low=2200, high=150) * env(d, 0.001, 0.07, power=2.0) * 0.8
    out = splat + _sizzle(d, 0.32, 4200)
    place(out, _bloop(260, 120, 0.1, 0.5), 0.0, 1.0)
    return filt(out, low=8000)


@punched(HANDLE)
def weap_lava_pop():
    """The reload starts: the cap pops off like a cork, the glass rings."""
    d = 0.35
    out = silence(d)
    place(out, _bloop(900, 300, 0.06, 0.8), 0.0, 1.0)
    place(out, click(0.02, 2400, 0.7), 0.0, 1.0)
    place(out, tone(2350, 0.3, "sine") * env(0.3, 0.002, 0.3, power=2.4) * 0.12, 0.01, 1.0)
    return filt(out, low=9000)


def weap_lava_unscrew():
    """Gold threads ratcheting round with a squeak of glass."""
    d = 0.42
    out = silence(d)
    for i in range(7):
        place(out, click(0.012, 2000 + (i % 2) * 400, 0.35), i * 0.052, 1.0)
    t = t_axis(d)
    squeak = tone(1300, d, "tri", vibrato=0.04, vib_rate=11) * env(d, 0.05, d, power=1.0, release=0.08) * 0.08
    return filt(out + squeak * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t)), low=8000)


def weap_lava_lift():
    """The hologram ring hums up under the lamp."""
    d = 0.5
    hum = sweep(180, 360, d, "tri") * 0.3 + sweep(360, 720, d) * 0.1
    shimmer = band(noise(d), 3000, 1400) * 0.06
    return filt((hum + shimmer) * env(d, 0.12, d, power=0.9, release=0.1), low=6000)


def weap_lava_flip():
    """The lamp cartwheels: a soft whoosh with the wax sloshing inside."""
    d = 0.45
    t = t_axis(d)
    whoosh = band(noise(d), 900, 700) * env(d, d * 0.45, d, power=0.8, release=d * 0.4) * 0.5
    slosh = filt(noise(d), low=600, high=120) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)) * env(d, 0.1, d, power=1.0) * 0.4
    return filt(whoosh + slosh, low=6000)


def weap_lava_glug():
    """The spent wax sinks into one lump: a run of deep glugs."""
    d = 0.5
    return filt(_bubbles(d, 6, 140, 260, 1.3), low=5000)


@punched(CUE)
def weap_lava_lock():
    """Twist-lock: a solid gold clunk, a ratchet click and a warm two-note chime."""
    d = 0.55
    out = _sub_thump(190, 80, d, 0.07)
    place(out, clunk(240, 0.12, 1.0), 0.0, 1.0)
    place(out, click(0.02, 1900, 0.6), 0.03, 1.0)
    place(out, _chime((659, 988), 0.06, 0.5, 0.8), 0.04, 1.0)
    return filt(out, low=8000)


def weap_lava_ripple():
    """The glow ripples up the lamp: a rising, bubbly shimmer."""
    d = 0.5
    out = _chime((523, 659, 784, 1047), 0.055, d, 0.6)
    place(out, _bubbles(0.35, 5, 600, 1200, 0.6, seed=8), 0.0, 1.0)
    return filt(out, low=9000)


@punched(CUE)
def weap_lava_groovy():
    """Active reload: a funky wah up (a saw through a rising band) and a bright chord."""
    d = 0.6
    body = tone(196, d, "saw") * 0.25 + tone(294, d, "saw") * 0.12
    out = silence(d)
    steps = 6
    seg = 0.06
    for i in range(steps):
        part = band(body, 400 + i * 260, 500)[: int(SR * seg * 2)]
        place(out, part * env(seg * 2, seg * 0.8, seg * 2, power=1.0, release=seg * 0.8), i * seg, 1.0)
    out *= env(d, 0.005, d, power=1.1)
    place(out, _chime((784, 988, 1175, 1568), 0.035, 0.55, 0.9), 0.05, 1.0)
    return filt(out, low=9000)


def weap_lava_miss():
    """Too early: a dull glass tonk."""
    d = 0.25
    out = clunk(160, 0.12, 0.7)
    place(out, tone(420, 0.2, "sine") * env(0.2, 0.002, 0.2, power=2.6) * 0.25, 0.0, 1.0)
    return filt(out, low=5000)


@punched(HANDLE)
def weap_lava_equip():
    """Raised: a glass clink and the lamp bubbling awake."""
    d = 0.45
    out = silence(d)
    place(out, tone(1900, 0.25, "sine") * env(0.25, 0.002, 0.25, power=2.4) * 0.2, 0.0, 1.0)
    place(out, click(0.015, 2600, 0.4), 0.0, 1.0)
    place(out, _bubbles(0.35, 5, 220, 480, 1.0, seed=5), 0.08, 1.0)
    return filt(out, low=8000)


SOUNDS = [weap_lava_fire, weap_lava_splat, weap_lava_pop, weap_lava_unscrew, weap_lava_lift, weap_lava_flip, weap_lava_glug,
          weap_lava_lock, weap_lava_ripple, weap_lava_groovy, weap_lava_miss, weap_lava_equip]

VARIANTS = [(weap_lava_fire, (0.94, 1.06)), (weap_lava_splat, (0.9, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
