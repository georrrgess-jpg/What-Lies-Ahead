"""Abyss Aquarium audio pack (World 3, Tidal Tunnels). All synthesised.

    tidal_tunnels_loop   music: 77 s dubby aquatic loop, 100 BPM, D dorian,
                         section A (pads, kalimba arps, sub pulse) and section
                         B (busier arps, vibraphone lead, shaker)
    tidal_tunnels_final  the final-wave variant: kick on every beat, sixteenth
                         shaker and arps throughout, an octave pluck, a lead in A
    aqua_ambience        ambience bed: pump hum, bubbling filters, water flow,
                         distant whale calls (written as music, .ogg)
    aqua_*               enemy sounds: diver regulator breaths, helmet clank and
                         crack, octopus gurgles and ink spit, jelly hums, charge
                         and zap

    python tools/gen_audio.py aqua
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import SR, rng


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def bubble(f0, seconds=0.09, rise=2.2, gain=1.0):
    """A single bubble 'bloop': a sine whose pitch rises as it decays."""
    t = t_axis(seconds)
    f = f0 * (1.0 + (rise - 1.0) * (t / seconds) ** 0.7)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.002, seconds, power=2.2) * gain


def bubbles(seconds, count, lo=350, hi=1400, seed=0):
    out = silence(seconds)
    r = np.random.default_rng(seed)
    for _ in range(count):
        d = r.uniform(0.04, 0.12)
        place(out, bubble(r.uniform(lo, hi), d), r.uniform(0, max(0.0, seconds - d)), r.uniform(0.25, 1.0))
    return out


def placew(buf, x, at, gain=1.0):
    """Mix x into buf at `at` seconds, wrapping the overflow to the start (seamless loops)."""
    i = int(SR * at) % len(buf)
    n = len(x)
    first = min(n, len(buf) - i)
    buf[i:i + first] += x[:first] * gain
    if n > first:
        rest = x[first:]
        while len(rest) > 0:
            k = min(len(rest), len(buf))
            buf[:k] += rest[:k] * gain
            rest = rest[k:]
    return buf


def whale(seconds=3.2, f0=210, f1=120):
    """A distant whale moan: slow glide with a formant and a slight warble."""
    t = t_axis(seconds)
    k = t / seconds
    f = f0 + (f1 - f0) * (0.5 - 0.5 * np.cos(np.pi * k)) + 18 * np.sin(2 * np.pi * 0.9 * t) * k
    v = osc(2 * np.pi * np.cumsum(f) / SR, "saw") * 0.5 + np.sin(2 * np.pi * np.cumsum(f) / SR)
    voice = band(v, 420, 160) * 3.0 + band(v, 900, 220) * 1.2 + filt(v, low=300) * 0.6
    return voice * env(seconds, seconds * 0.35, seconds * 1.1, power=0.8, release=seconds * 0.4)


def metal_ping(base, seconds, partials=(1.0, 2.63, 4.19, 5.4), decay=0.4):
    out = silence(seconds)
    for i, p in enumerate(partials):
        out += np.sin(2 * np.pi * base * p * t_axis(seconds)) * env(seconds, 0.001, decay / (1 + i * 0.6), power=1.6) / (1 + i * 0.5)
    return out


# ---------------------------------------------------------------------------
# Enemy sounds
# ---------------------------------------------------------------------------

def aqua_diver_breath_1():
    """Regulator: a hissing inhale, then an exhale burst of bubbles over a groan."""
    d = 1.6
    out = silence(d)
    inhale = filt(noise(0.55), high=2500, low=7000) * env(0.55, 0.25, 0.7, power=0.8, release=0.08)
    place(out, inhale * 0.5, 0.0)
    place(out, bubbles(0.8, 28, 300, 1100, seed=5) * 0.9, 0.62)
    place(out, groan(85, 0.8, glide=-0.2, formants=((400, 100), (900, 160)), rasp=0.35) * 0.5, 0.6)
    return out


def aqua_diver_breath_2():
    d = 1.4
    out = silence(d)
    place(out, filt(noise(0.4), high=3000, low=8000) * env(0.4, 0.15, 0.5, power=0.8, release=0.06) * 0.45, 0.0)
    place(out, bubbles(0.9, 34, 260, 900, seed=7), 0.42)
    place(out, groan(72, 0.9, glide=0.1, formants=((380, 90), (820, 150)), rasp=0.4) * 0.45, 0.45)
    return out


def aqua_helmet_clank():
    """A bullet glancing off brass: bright ping and a short thud."""
    d = 0.5
    out = metal_ping(880, d, decay=0.35) * 0.8
    place(out, clunk(180, 0.12), 0.0, 0.6)
    place(out, click(0.02, 4000), 0.0, 0.5)
    return out


def aqua_helmet_crack():
    """The visor gives: glass crunch, a big clang, a hiss of escaping air and bubbles."""
    d = 1.2
    out = silence(d)
    crack = filt(noise(0.18), high=2500) * env(0.18, 0.0005, 0.08, power=1.4)
    for k in range(6):
        place(out, click(0.015, 5000 + k * 700), 0.01 + k * 0.022, 0.7)
    place(out, crack * 1.2, 0.0)
    place(out, metal_ping(520, 0.9, decay=0.7) * 0.9, 0.02)
    place(out, filt(noise(0.7), high=1800, low=6000) * env(0.7, 0.02, 0.8, power=0.9) * 0.4, 0.08)
    place(out, bubbles(0.7, 26, 400, 1600, seed=11) * 0.7, 0.15)
    return crush(out, 1.3)


def aqua_octo_gurgle_1():
    """Wet, bubbly mascot groan."""
    d = 1.1
    v = groan(110, d, glide=-0.15, formants=((480, 140), (1100, 220)), rasp=0.3, wobble=0.12)
    t = t_axis(d)
    v = v * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t) ** 2)
    out = v + bubbles(d, 18, 200, 700, seed=3) * 0.5
    return out


def aqua_octo_gurgle_2():
    d = 0.9
    v = groan(140, d, glide=0.25, formants=((560, 150), (1300, 240)), rasp=0.35, wobble=0.15)
    t = t_axis(d)
    v = v * (0.55 + 0.45 * np.sin(2 * np.pi * 19 * t) ** 2)
    return v + bubbles(d, 14, 250, 800, seed=4) * 0.5


def aqua_ink_spit():
    """A wet 'ptoo' and splatter."""
    d = 0.6
    out = silence(d)
    place(out, sweep(700, 160, 0.16, "sine", 0.5) * env(0.16, 0.002, 0.18, power=1.5), 0.0, 0.9)
    place(out, band(noise(0.25), 1400, 700) * env(0.25, 0.002, 0.2, power=1.6) * 1.5, 0.01)
    place(out, bubbles(0.4, 16, 500, 1800, seed=9) * 0.6, 0.08)
    return out


def _electric(base, seconds, warble=6.0):
    t = t_axis(seconds)
    f = base * (1.0 + 0.04 * np.sin(2 * np.pi * warble * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = osc(ph, "square") * 0.6 + osc(ph * 2.01, "saw") * 0.3
    return filt(buzz, low=3200) * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * t))


def aqua_jelly_hum_1():
    """Electric, warbling moan from under the jellyfish hat."""
    d = 1.0
    v = groan(150, d, glide=-0.2, formants=((600, 150), (1500, 260)), rasp=0.2, wobble=0.1)
    return v * 0.8 + _electric(150, d) * env(d, 0.1, d * 1.2, power=0.8, release=0.3) * 0.35


def aqua_jelly_hum_2():
    d = 0.8
    v = groan(180, d, glide=0.2, formants=((700, 160), (1700, 280)), rasp=0.25, wobble=0.14)
    return v * 0.8 + _electric(180, d, 9.0) * env(d, 0.08, d * 1.2, power=0.8, release=0.25) * 0.35


def aqua_jelly_charge():
    """Rising crackling whine: the aura is about to fire."""
    d = 0.95
    t = t_axis(d)
    f = 220 * (1600 / 220) ** ((t / d) ** 1.4)
    ph = 2 * np.pi * np.cumsum(f) / SR
    whine = (osc(ph, "saw") * 0.5 + np.sin(ph * 0.5) * 0.5) * env(d, d * 0.9, d * 2.0, power=0.5, release=0.03)
    out = filt(whine, low=6000) * 0.7
    r = np.random.default_rng(21)
    for k in range(18):
        at = r.uniform(0.0, d - 0.03) ** 0.7 * d ** 0.3
        place(out, click(0.012, r.uniform(3000, 8000)), at, 0.5 + 0.5 * at / d)
    return out


def aqua_jelly_zap():
    """Discharge: a sharp crack, a buzzing drop and crackle."""
    d = 0.7
    out = silence(d)
    place(out, filt(noise(0.06), high=2000) * env(0.06, 0.0005, 0.05, power=1.2) * 1.4, 0.0)
    drop = sweep(1400, 90, 0.45, "square", 0.4) * env(0.45, 0.001, 0.5, power=1.4)
    place(out, filt(drop, low=5000) * 0.7, 0.0)
    place(out, _electric(95, 0.5, 13.0) * env(0.5, 0.002, 0.5, power=1.8) * 0.6, 0.02)
    r = np.random.default_rng(23)
    for k in range(10):
        place(out, click(0.01, r.uniform(2500, 9000)), r.uniform(0.02, 0.45), 0.6)
    return crush(out, 1.4)


SOUNDS = [
    aqua_diver_breath_1, aqua_diver_breath_2, aqua_helmet_clank, aqua_helmet_crack,
    aqua_octo_gurgle_1, aqua_octo_gurgle_2, aqua_ink_spit,
    aqua_jelly_hum_1, aqua_jelly_hum_2, aqua_jelly_charge, aqua_jelly_zap,
]

VARIANTS = [
    (aqua_diver_breath_1, (0.92, 1.07)), (aqua_octo_gurgle_1, (0.9, 1.1)), (aqua_jelly_hum_1, (0.92, 1.1)),
    (aqua_helmet_clank, (0.9, 1.12)), (aqua_jelly_zap, (0.93, 1.06)),
]


# ---------------------------------------------------------------------------
# Ambience
# ---------------------------------------------------------------------------

def aqua_ambience():
    """Life-support hum, bubbling filters, a slow water flow and far whale calls."""
    d = 32.0
    t = t_axis(d + 1.0)
    n = len(t)
    hum = sum(np.sin(2 * np.pi * f * t + p) * g for f, g, p in ((50, 1.0, 0.0), (100, 0.4, 1.0), (150, 0.18, 2.0), (75, 0.25, 0.4)))
    hum *= (0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t)) * 0.14
    flow_l = filt(rng.uniform(-1, 1, n), low=500, high=60) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9.0) ** 2)
    flow_r = filt(rng.uniform(-1, 1, n), low=500, high=60) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9.0 + 1.2) ** 2)
    left = hum + flow_l * 0.5
    right = hum * 0.9 + flow_r * 0.5
    # Bubbling filter streams, panned to either side, in bursts.
    for k, (start, pan) in enumerate(((0.5, 0.2), (4.0, 0.8), (9.5, 0.35), (14.0, 0.7), (19.0, 0.15), (23.5, 0.85), (28.0, 0.5))):
        b = bubbles(3.2, 45, 300, 1300, seed=40 + k) * 0.22
        place(left, b, start, 1.0 - pan)
        place(right, b, start, pan)
    # Distant whale calls with a long echo tail.
    for at, pan, f0, f1 in ((6.0, 0.3, 220, 130), (20.0, 0.7, 180, 105)):
        w = filt(whale(3.4, f0, f1), low=1500) * 0.35
        for e in range(4):
            place(left, w * (0.55 ** e), at + e * 0.42, (1.0 - pan) if e % 2 == 0 else pan)
            place(right, w * (0.55 ** e), at + e * 0.42, pan if e % 2 == 0 else (1.0 - pan))
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def tidal_tunnels_loop(intense=False):
    """100 BPM, D dorian. 32 bars (76.8 s): A = 16 bars of pads, kalimba arps
    and a sub pulse; B = 16 bars with 16th arps, a vibraphone lead and shaker.
    Every echo tail wraps around, so the loop is seamless. intense=True is the
    final-wave variant (same tempo and length, so the game cross-fades between
    the two in time)."""
    bpm = 100.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 32
    d = bars * bar
    left, right = silence(d), silence(d)

    def both(x, at, gain, pan=0.5):
        placew(left, x, at, gain * (1 - pan) * 2)
        placew(right, x, at, gain * pan * 2)

    # (root semitones from A4, chord tones)
    chords_a = [(-19, (0, 3, 7, 10, 14)), (-23, (0, 4, 7, 11, 14)), (-14, (0, 3, 7, 10, 14)), (-12, (0, 5, 7, 10, 12))]
    chords_b = [(-16, (0, 4, 7, 11, 14)), (-21, (0, 4, 7, 14, 16)), (-19, (0, 3, 7, 10, 14)), (-12, (0, 4, 7, 10, 13))]

    kick = sweep(110, 42, 0.32, "sine", 0.45) * env(0.32, 0.002, 0.3, power=2.0)
    place(kick, kick_click(0.3, 2600), 0.0)
    hat = filt(noise(0.06), high=6500) * env(0.06, 0.0008, 0.05, power=2.5)
    shaker = band(noise(0.08), 7000, 2500) * env(0.08, 0.01, 0.08, power=1.5)
    rim = band(noise(0.05), 2200, 600) * env(0.05, 0.0005, 0.04, power=2.0) + tone(820, 0.05) * env(0.05, 0.0005, 0.03) * 0.3

    def kalimba(semi, length):
        f = note(semi)
        x = np.sin(2 * np.pi * f * t_axis(length)) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t_axis(length)) * env(length, 0.001, 0.08)
        return x * env(length, 0.002, length * 0.8, power=2.2)

    def vibe(semi, length):
        f = note(semi)
        t = t_axis(length)
        x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4.0 * t) * env(length, 0.001, 0.15)
        return x * (0.85 + 0.15 * np.sin(2 * np.pi * 5.5 * t)) * env(length, 0.004, length * 1.1, power=1.2, release=0.05)

    for b in range(bars):
        section_b = b >= 16
        root, tones = (chords_b if section_b else chords_a)[(b // 2) % 4]
        t0 = b * bar
        # Pad: soft detuned chord, sidechained by the kick.
        if b % 2 == 0:
            plen = 2 * bar
            tp = t_axis(plen)
            pad_l = sum(np.sin(2 * np.pi * note(root + 12 + s) * 0.997 * tp) + 0.3 * osc(2 * np.pi * note(root + 12 + s) * tp, "tri") for s in tones[:4])
            pad_r = sum(np.sin(2 * np.pi * note(root + 12 + s) * 1.003 * tp) + 0.3 * osc(2 * np.pi * note(root + 12 + s) * 1.002 * tp, "tri") for s in tones[:4])
            duck = 1.0 - 0.45 * np.exp(-((tp % beat) / 0.18))
            shape = env(plen, 0.6, plen * 3.0, power=0.4, release=0.5) * duck
            placew(left, filt(pad_l * shape, low=1600) * 0.05, t0)
            placew(right, filt(pad_r * shape, low=1600) * 0.05, t0)
        # Sub bass pulse on 1 and the "and" of 2, with a fifth on 3 (its
        # harmonics carry it on small speakers); when intense, an eighth-note
        # octave pluck drives underneath.
        for at, semi, length in ((0.0, 0, 1.2), (1.5, 0, 0.45), (2.0, 7, 0.9), (3.5, 12 if section_b else 0, 0.4)):
            x = np.sin(2 * np.pi * note(root - 12 + semi) * t_axis(length * beat)) * env(length * beat, 0.01, length * beat * 1.1, power=1.2)
            both(audible_bass(x, 0.5), t0 + at * beat, 0.32)
        if intense:
            for k in range(8):
                ln = beat * 0.4
                x = osc(2 * np.pi * note(root + (12 if k % 2 else 0)) * t_axis(ln), "tri") * env(ln, 0.003, ln, power=1.6)
                both(filt(x, low=1800), t0 + k * beat * 0.5, 0.1, 0.4 if k % 2 else 0.6)
        # Drums: soft kick on 1 and 3, rim on 4, hats on the offbeats; shaker in
        # B. Intense: kick on every beat, rim on 2 and 4, sixteenth shaker and hats.
        for k in range(4) if intense else (0, 2):
            both(kick, t0 + k * beat, 0.5 if k == 0 else 0.42)
        for k in (1, 3) if intense else (3,):
            both(rim, t0 + k * beat, 0.18, 0.62)
        for k in range(4):
            both(hat, t0 + (k + 0.5) * beat, 0.12, 0.65)
            if intense:
                both(hat, t0 + (k + 0.25) * beat, 0.05, 0.4)
                both(hat, t0 + (k + 0.75) * beat, 0.05, 0.4)
        if section_b or intense:
            for k in range(16):
                both(shaker, t0 + k * beat * 0.25, 0.06 + 0.03 * (k % 2), 0.35)
        if b % 8 == 7 or (intense and b % 4 == 3):
            swell = filt(noise(bar * 0.5), high=600, low=4000) * env(bar * 0.5, bar * 0.48, bar * 0.6, power=0.5, release=0.02)
            both(swell, t0 + bar * 0.5, 0.09)
        # Kalimba arpeggio with a dub echo (3/8 delay, ping-pong); sixteenths in
        # B, and everywhere when intense.
        steps = 16 if section_b or intense else 8
        pattern = [0, 2, 4, 1, 3, 2, 4, 1] if b % 4 < 2 else [4, 2, 0, 3, 1, 2, 0, 3]
        for k in range(steps):
            semi = root + 24 + tones[pattern[k % 8] % len(tones)] + (12 if steps == 16 and k % 8 == 6 else 0)
            x = kalimba(semi, beat * 0.9)
            at = t0 + k * bar / steps
            pan = 0.3 if k % 2 == 0 else 0.7
            both(x, at, 0.07 if steps == 16 else 0.09, pan)
            for e in range(1, 4):
                both(filt(x, low=2600 - e * 500), at + e * beat * 0.75, 0.07 * 0.45 ** e, 1.0 - pan if e % 2 else pan)
        # Vibraphone lead in section B (two-bar phrases); when intense, section A
        # gets a vibraphone line on the chord tones.
        phrases = {0: [(14, 0.0, 1.0), (12, 1.0, 0.5), (10, 1.5, 0.5), (7, 2.0, 2.0)],
                   1: [(10, 0.0, 1.5), (12, 1.5, 0.5), (14, 2.0, 1.0), (17, 3.0, 1.0)],
                   2: [(19, 0.0, 1.0), (17, 1.0, 1.0), (14, 2.0, 0.5), (12, 2.5, 1.5)],
                   3: [(10, 0.0, 2.0), (12, 2.0, 0.5), (14, 2.5, 1.5)]}
        if section_b:
            lead = [(-7 + 12 + semi, at, length) for semi, at, length in phrases[b % 4]]
        elif intense:
            line = ((2, 0.0, 1.5), (1, 1.5, 0.5), (3, 2.0, 2.0)) if b % 2 == 0 else ((4, 0.0, 1.0), (2, 1.0, 1.0), (1, 2.0, 2.0))
            lead = [(root + 24 + tones[i], at, length) for i, at, length in line]
        else:
            lead = []
        for semi, at, length in lead:
            x = vibe(semi, length * beat)
            both(x, t0 + at * beat, 0.1, 0.55)
            both(filt(x, low=2200), t0 + at * beat + beat * 0.75, 0.04, 0.3)
        # A few bubbles drifting through the mix.
        if b % 4 == 1:
            bb = bubbles(1.6, 10, 500, 1500, seed=100 + b) * 0.05
            both(bb, t0 + beat, 1.0, 0.2 if b % 8 == 1 else 0.8)
    return np.stack([left, right], axis=1)


MUSIC = {
    "tidal_tunnels_loop": tidal_tunnels_loop,
    "tidal_tunnels_final": lambda: tidal_tunnels_loop(intense=True),
    "aqua_ambience": aqua_ambience,
}
