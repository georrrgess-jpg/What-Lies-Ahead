"""Ashfall City zombies (Endless mode) sound pack: the city's rank and file,
the Riot Shield, the Tunnel Crawler, the Firebug and The Wrecker.

    python tools/gen_audio.py city_zombies

    audio/sfx/cz_*.wav   voices, telegraphs and impacts (prefix "cz_")
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


def _clang(d=0.5, base=340.0, gain=1.0):
    """Inharmonic metallic strike."""
    t = t_axis(d)
    out = np.zeros_like(t)
    for ratio, decay, g in ((1.0, 0.35, 1.0), (2.43, 0.22, 0.6), (3.71, 0.16, 0.45), (5.89, 0.1, 0.3)):
        out += np.sin(2 * np.pi * base * ratio * t) * np.exp(-t / decay) * g
    out += filt(noise(d), high=2500) * env(d, 0.0005, 0.03, power=2.0) * 0.6
    return out * gain


def _thump(f0=150, f1=40, d=0.35, gain=1.0):
    return sweep(f0, f1, d, "sine", 0.5) * env(d, 0.001, d * 0.85, power=2.0) * gain


def _rubble(d=0.6, seed_gap=0.035, centre=900.0):
    """Debris settling: a patter of small knocks and grit."""
    out = silence(d)
    at = 0.0
    k = 0
    while at < d - 0.05:
        place(out, band(noise(0.05), centre + 260 * (k % 4), 380) * env(0.05, 0.001, power=2.4), at, 0.75 * (1 - at / d))
        at += seed_gap * (1.0 + 0.6 * ((k * 7) % 3))
        k += 1
    return out + filt(noise(d), low=500) * env(d, 0.005, d, power=1.2) * 0.5


# ---------------------------------------------------------------------------
# Rank and file
# ---------------------------------------------------------------------------

def cz_commuter_groan_1():
    """A weary office groan, like a Monday."""
    return groan(96, 1.2, glide=-0.32, formants=((560, 120), (1150, 180)), rasp=0.22, wobble=0.05)


def cz_commuter_groan_2():
    return groan(84, 1.0, glide=0.18, formants=((480, 110), (980, 170)), rasp=0.28, wobble=0.06)


def cz_courier_screech_1():
    return groan(330, 0.5, glide=0.5, formants=((950, 200), (2200, 360)), rasp=0.5, wobble=0.1)


def cz_courier_screech_2():
    return groan(290, 0.55, glide=-0.35, formants=((1000, 210), (2300, 380)), rasp=0.55, wobble=0.12)


def cz_worker_roar_1():
    return crush(groan(70, 1.1, glide=0.2, formants=((380, 100), (820, 150)), rasp=0.55, wobble=0.05), 1.3)


def cz_worker_roar_2():
    return crush(groan(62, 1.2, glide=-0.15, formants=((340, 100), (760, 140)), rasp=0.6, wobble=0.06), 1.3)


# ---------------------------------------------------------------------------
# Riot Shield
# ---------------------------------------------------------------------------

def cz_riot_bark_1():
    """A muffled bark through a gas mask."""
    return filt(groan(118, 0.6, glide=-0.2, formants=((520, 120), (1100, 160)), rasp=0.45, wobble=0.04), low=1800)


def cz_riot_bark_2():
    return filt(groan(104, 0.7, glide=0.25, formants=((480, 110), (1000, 150)), rasp=0.5, wobble=0.05), low=1700)


def cz_riot_block():
    """A shot thudding off the polycarbonate shield: a dull plastic knock with a
    short ring, softer than the Riot Bruiser's metal plate."""
    d = 0.28
    knock = band(noise(d), 1300, 500) * env(d, 0.0005, 0.06, power=2.0) * 1.4
    ring = _clang(d, 610, 0.5)
    out = knock + ring
    place(out, _thump(260, 120, 0.12, 0.5), 0.0, 1.0)
    return out


def cz_riot_shield_break():
    """The shield cracks across and the light bar dies with a sputter."""
    d = 1.0
    out = silence(d)
    for i in range(12):
        place(out, band(noise(0.07), 2200 + 380 * (i % 4), 800) * env(0.07, 0.001, power=2.2), 0.025 * i, 0.65 - 0.03 * i)
    place(out, _thump(180, 50, 0.35, 1.1), 0.0, 1.0)
    for i in range(5):
        place(out, tone(880 if i % 2 else 660, 0.06, "square") * env(0.06, 0.002, power=1.5) * 0.25, 0.2 + i * 0.11 + 0.02 * (i % 2), 1.0)
    return crush(filt(out, low=9000), 1.2)


def cz_riot_drum():
    """The bash telegraph: three baton strikes on the shield rim, a siren
    whoop rising under them, then a stamp."""
    d = 1.15
    out = silence(d)
    for i, at in enumerate((0.21, 0.46, 0.71)):
        place(out, _clang(0.25, 520 + 30 * i, 0.9) + band(noise(0.25), 900, 400) * env(0.25, 0.001, 0.05, power=2.0), at, 1.0)
    whoop = sweep(420, 900, d, "sine", 1.2) * env(d, 0.15, d, power=0.4, release=0.1)
    place(out, whoop * 0.22, 0.0, 1.0)
    place(out, _thump(140, 45, 0.3, 1.0), 0.98, 1.0)
    return out


def cz_riot_rush():
    """Charging boots and the shield cutting the air."""
    d = 0.8
    t = t_axis(d)
    whoosh = band(noise(d), 700, 350) * np.sin(np.pi * np.clip(t / d, 0, 1)) * 1.2
    out = whoosh.copy()
    for i in range(4):
        place(out, _thump(120, 50, 0.15, 0.8), 0.05 + i * 0.18, 1.0)
    return out


def cz_riot_bash():
    """The shield slams into something: a heavy thud and a plastic crack."""
    out = _thump(170, 38, 0.5, 1.4)
    place(out, band(noise(0.18), 1500, 700) * env(0.18, 0.001, 0.08, power=2.0), 0.0, 1.0)
    place(out, _clang(0.3, 430, 0.5), 0.0, 1.0)
    return crush(out, 1.4)


# ---------------------------------------------------------------------------
# Tunnel Crawler
# ---------------------------------------------------------------------------

def cz_crawler_hiss_1():
    """A wet hiss with a clicking throat."""
    d = 0.7
    hiss = band(noise(d), 4200, 1600) * env(d, 0.06, d, power=0.9, release=0.15)
    out = hiss * 0.8
    for i in range(7):
        place(out, click(0.02, 1400 + 120 * i, 0.6), 0.05 + i * 0.08, 1.0)
    return out + groan(210, d, glide=0.3, formants=((700, 150), (1800, 300)), rasp=0.8, wobble=0.15) * 0.35


def cz_crawler_hiss_2():
    d = 0.55
    hiss = band(noise(d), 3600, 1400) * env(d, 0.02, d, power=1.1, release=0.1)
    return hiss * 0.9 + groan(250, d, glide=-0.4, formants=((800, 160), (2000, 320)), rasp=0.8, wobble=0.18) * 0.35


def cz_crawler_skitter():
    """Claws scrabbling on concrete."""
    d = 0.45
    out = silence(d)
    for i in range(9):
        place(out, band(noise(0.025), 2600 + 400 * (i % 3), 900) * env(0.025, 0.0005, power=2.5), i * 0.045 + 0.01 * (i % 2), 0.9)
    return out


def cz_crawler_pounce():
    """The pounce telegraph: a rising, rattling shriek."""
    d = 0.65
    shriek = groan(260, d, glide=0.9, formants=((900, 200), (2300, 380)), rasp=0.7, wobble=0.2)
    rattle = band(noise(d), 2800, 900) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * t_axis(d)))) * env(d, 0.05, d, power=0.6)
    return shriek * 0.8 + rattle * 0.6


def cz_crawler_land():
    d = 0.35
    out = _thump(160, 60, 0.25, 0.9)
    out = np.concatenate([out, silence(d - 0.25)])
    place(out, cz_crawler_skitter()[: int(SR * 0.2)], 0.03, 0.7)
    return out


# ---------------------------------------------------------------------------
# Firebug
# ---------------------------------------------------------------------------

def cz_firebug_cackle_1():
    """A giggling cackle: short rising-falling yelps."""
    out = silence(0.8)
    for i in range(5):
        place(out, groan(240 + 25 * (i % 2), 0.13, glide=0.5 - i * 0.12, formants=((850, 200), (2000, 300)), rasp=0.35, wobble=0.1),
              0.02 + i * 0.14, 1.0 - 0.1 * i)
    return out


def cz_firebug_cackle_2():
    out = silence(0.7)
    for i in range(4):
        place(out, groan(270 - 15 * i, 0.15, glide=0.4, formants=((900, 200), (2200, 320)), rasp=0.4, wobble=0.12), 0.03 + i * 0.16, 1.0)
    return out


def cz_firebug_light():
    """The throw telegraph: a lighter's flint, the rag catching with a whoomph,
    a fizzing fuse."""
    d = 1.0
    out = silence(d)
    place(out, click(0.03, 3200, 1.2), 0.0, 1.0)
    place(out, click(0.03, 2800, 0.9), 0.09, 1.0)
    catch = filt(noise(0.4), low=1500, high=150) * env(0.4, 0.03, 0.4, power=0.8)
    place(out, catch, 0.18, 1.0)
    fizz = band(noise(d - 0.3), 3800, 1500) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 13 * t_axis(d - 0.3))))
    place(out, fizz * env(d - 0.3, 0.05, d, power=0.5, release=0.05), 0.3, 0.5)
    return out


def cz_firebug_throw():
    """The heave, and the bottle whirring away end over end."""
    d = 0.7
    t = t_axis(d)
    whirr = band(noise(d), 900, 350) * (0.55 + 0.45 * np.sin(2 * np.pi * 11 * t)) * env(d, 0.02, d, power=0.7)
    out = whirr * 1.2
    place(out, groan(160, 0.3, glide=0.4, formants=((650, 150), (1500, 240)), rasp=0.4), 0.0, 0.5)
    return out


def cz_bottle_smash():
    """Glass shattering and the fuel going up in a soft whoomph of flame."""
    d = 1.1
    out = silence(d)
    for i in range(14):
        place(out, band(noise(0.06), 3400 + 500 * (i % 5), 1100) * env(0.06, 0.0005, power=2.2), 0.012 * i + 0.004 * (i % 3), 0.7 - 0.035 * i)
    whoomph = filt(noise(0.9), low=900, high=60) * env(0.9, 0.04, 0.9, power=0.9)
    place(out, whoomph, 0.05, 1.3)
    place(out, _thump(110, 40, 0.3, 0.8), 0.04, 1.0)
    crackle = (rng.uniform(0, 1, int(SR * 0.9)) > 0.996).astype(float) * rng.uniform(-1, 1, int(SR * 0.9))
    place(out, filt(crackle, high=2000) * 0.8, 0.2, 1.0)
    return out


# ---------------------------------------------------------------------------
# The Wrecker
# ---------------------------------------------------------------------------

def cz_wrecker_grunt_1():
    return crush(groan(56, 0.9, glide=-0.2, formants=((300, 90), (700, 140)), rasp=0.6, wobble=0.05), 1.4)


def cz_wrecker_grunt_2():
    return crush(groan(50, 1.0, glide=0.15, formants=((280, 90), (650, 130)), rasp=0.65, wobble=0.06), 1.4)


def cz_wrecker_roar():
    """A huge roar over a revving diesel."""
    d = 1.3
    body = groan(52, d, glide=0.35, formants=((310, 90), (690, 140)), rasp=0.65, wobble=0.07)
    t = t_axis(d)
    rpm = 28 + 30 * np.clip(t / 0.8, 0, 1)
    engine = np.sign(np.sin(2 * np.pi * np.cumsum(rpm) / SR)) * filt(noise(d), low=600) * 0.6 + np.sin(2 * np.pi * np.cumsum(rpm * 2) / SR) * 0.4
    return crush(body + filt(engine, low=500) * 0.5 * env(d, 0.1, d, power=0.6, release=0.2), 1.5)


def cz_wrecker_chain():
    """The swing telegraph: chain links rattling faster as the ball whirls."""
    d = 1.15
    out = silence(d)
    at, gap, k = 0.0, 0.12, 0
    while at < d - 0.06:
        place(out, _clang(0.08, 1400 + 220 * (k % 3), 0.5) + band(noise(0.08), 4000, 1500) * env(0.08, 0.001, power=2.0) * 0.6, at, 0.6 + at * 0.4)
        at += gap
        gap = max(0.045, gap * 0.9)
        k += 1
    whirl = band(noise(d), 500, 220) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(1.5 + 3.5 * t_axis(d) / d) / SR)) * env(d, 0.3, d, power=0.4)
    return out + whirl * 0.8


def cz_wrecker_swing():
    """The ball scything past: a deep, heavy whoosh."""
    d = 0.8
    t = t_axis(d)
    whoosh = band(noise(d), 300, 160) * np.exp(-((t - 0.25) / 0.16) ** 2) * 2.0 + band(noise(d), 700, 300) * np.exp(-((t - 0.3) / 0.12) ** 2)
    place(whoosh, _thump(90, 40, 0.5, 0.4), 0.1, 1.0)
    return whoosh


def cz_wrecker_impact():
    """Ball meets player: a crunching iron boom."""
    d = 0.9
    out = _thump(120, 30, 0.7, 1.5)
    out = np.concatenate([out, silence(d - 0.7)])
    place(out, _clang(0.6, 210, 0.7), 0.0, 1.0)
    place(out, _rubble(0.6), 0.05, 0.6)
    return crush(out, 1.6)


def cz_wrecker_engine():
    """The bulldoze telegraph: a diesel engine revving up hard."""
    d = 1.25
    t = t_axis(d)
    rpm = 22 + 55 * np.clip(t / d, 0, 1) ** 1.6
    phase = 2 * np.pi * np.cumsum(rpm) / SR
    chug = np.sign(np.sin(phase)) * 0.5 + np.sin(phase * 2) * 0.3 + filt(noise(d), low=400) * (0.5 + 0.5 * np.sin(phase))
    horn = (tone(233, d * 0.4, "saw") + tone(277, d * 0.4, "saw")) * env(d * 0.4, 0.02, d * 0.4, power=0.3, release=0.05)
    out = filt(chug, low=900) * env(d, 0.05, d, power=0.3, release=0.05)
    place(out, filt(horn, low=1800) * 0.35, d * 0.58, 1.0)
    return crush(out, 1.5)


def cz_wrecker_charge():
    """The charge itself: engine at full roar, treads grinding."""
    d = 1.4
    t = t_axis(d)
    phase = 2 * np.pi * np.cumsum(np.full_like(t, 78.0)) / SR
    roar = filt(np.sign(np.sin(phase)) * 0.4 + filt(noise(d), low=700) * 0.8, low=1000)
    grind = band(noise(d), 1800, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * 0.4
    return crush((roar + grind) * env(d, 0.04, d, power=0.4, release=0.25), 1.4)


def cz_wrecker_debris():
    """A slab of concrete crashing down and breaking up."""
    d = 1.0
    out = _thump(140, 32, 0.5, 1.6)
    out = np.concatenate([out, silence(d - 0.5)])
    place(out, filt(noise(0.2), high=700) * env(0.2, 0.001, 0.15, power=2.0), 0.0, 0.9)
    place(out, _rubble(0.8, 0.03, 1100), 0.04, 0.8)
    return crush(out, 1.4)


SOUNDS = [
    cz_commuter_groan_1, cz_commuter_groan_2, cz_courier_screech_1, cz_courier_screech_2, cz_worker_roar_1, cz_worker_roar_2,
    cz_riot_bark_1, cz_riot_bark_2, cz_riot_block, cz_riot_shield_break, cz_riot_drum, cz_riot_rush, cz_riot_bash,
    cz_crawler_hiss_1, cz_crawler_hiss_2, cz_crawler_skitter, cz_crawler_pounce, cz_crawler_land,
    cz_firebug_cackle_1, cz_firebug_cackle_2, cz_firebug_light, cz_firebug_throw, cz_bottle_smash,
    cz_wrecker_grunt_1, cz_wrecker_grunt_2, cz_wrecker_roar, cz_wrecker_chain, cz_wrecker_swing, cz_wrecker_impact,
    cz_wrecker_engine, cz_wrecker_charge, cz_wrecker_debris,
]

VARIANTS = [
    (cz_riot_block, (0.92, 1.08)), (cz_crawler_skitter, (0.9, 1.12)), (cz_bottle_smash, (0.92, 1.06)),
    (cz_wrecker_debris, (0.9, 1.1)),
]

LOOPS = {}

MUSIC = {}
