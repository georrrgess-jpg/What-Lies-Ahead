"""Sky Carnival (World 10) sound pack: Sky Harbor music and ambience, the Sky
Diver, Balloon Vendor and Captain Cumulus voices, the dive, balloons and the gale.

    python tools/gen_audio.py sky

    audio/music/sky_harbor_loop.ogg     30 s sunrise carnival waltz (3/4, 144 BPM):
                                        a calliope melody, glockenspiel sparkle,
                                        oom-pah-pah tuba and accordion, brushed snare
    audio/music/sky_harbor_final.ogg    its final-wave variant (timpani on every
                                        downbeat, a snare roll drive, brass stabs)
    audio/music/sky_ambience.ogg        16 s: wind over the islands, flapping
                                        bunting, creaking ropes, a far propeller hum
                                        and wind chimes
    audio/sfx/sky_*.wav                 enemy, dive, balloon and gale sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def calliope(freq, seconds, gain=1.0):
    """Steam-organ pipe: a breathy fundamental with octave and fifth ranks and
    a quick tremolo."""
    t = t_axis(seconds)
    trem = 1.0 + 0.12 * np.sin(2 * np.pi * 6.5 * t)
    x = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(4 * np.pi * freq * t) + 0.2 * np.sin(6 * np.pi * freq * t)
    breath = band(noise(seconds), freq * 2, freq) * 0.12
    return filt(x * trem + breath, low=4200) * env(seconds, 0.02, seconds, power=0.4, release=0.06) * gain


def glock(freq, seconds=0.9):
    """Glockenspiel: bright inharmonic bar partials, fast decay."""
    t = t_axis(seconds)
    x = sum(np.sin(2 * np.pi * freq * r * t) * a * np.exp(-t * d) for r, a, d in ((1.0, 1.0, 4.0), (2.76, 0.4, 9.0), (5.4, 0.2, 16.0)))
    return x * env(seconds, 0.001, seconds, power=1.0)


def tuba(freq, seconds):
    """Oom: a round brass bass note."""
    t = t_axis(seconds)
    x = np.tanh(1.6 * (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)))
    return audible_bass(filt(x, low=900), 0.3) * env(seconds, 0.015, seconds * 1.2, power=0.8, release=0.05)


def accordion(semis, seconds, gain=1.0):
    """Pah: a short reedy accordion chord (two slightly detuned reeds)."""
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        reed = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sign(np.sin(2 * np.pi * f * 1.004 * t)) * 0.5
        out += filt(reed, low=2600) * 0.25
    return out * env(seconds, 0.01, seconds, power=0.6, release=0.04) * gain


def brush(seconds=0.16):
    return band(noise(seconds), 4500, 3000) * env(seconds, 0.006, seconds, power=1.4)


def timpani(freq, seconds=0.9):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t * (1.0 + 0.04 * np.exp(-t * 20))) + 0.3 * np.sin(2 * np.pi * freq * 1.5 * t)
    return (body + filt(noise(seconds), low=500) * 0.4 * np.exp(-t * 30)) * env(seconds, 0.002, seconds * 0.8, power=1.6)


def brass_stab(semis, seconds=0.32):
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        ph = 2 * np.pi * f * t
        out += filt(np.tanh(2.2 * (np.sin(ph) + 0.5 * np.sin(2 * ph))), low=3200) * 0.3
    return out * env(seconds, 0.01, seconds * 0.8, power=1.2)


def wind_bed(n, seed_shift=0.0, slow=7.0):
    """Moving wind: low and high noise bands breathing at different rates."""
    t = np.arange(n) / SR
    lo = filt(rng.uniform(-1, 1, n), low=500, high=60)
    hi = filt(rng.uniform(-1, 1, n), low=2600, high=700)
    gust = (0.5 + 0.5 * np.sin(2 * np.pi * t / slow + seed_shift)) ** 2
    whistle = (0.5 + 0.5 * np.sin(2 * np.pi * t / (slow * 0.62) + 1.3 + seed_shift)) ** 4
    return lo * (0.35 + 0.65 * gust) + hi * whistle * 0.4


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def sky_harbor_loop(intense=False):
    """144 BPM waltz, 24 bars (30 s) in F major: F - C7 - F - Bb, then
    Gm - C7 - F - F, twice through with the tune an octave up the second time.
    Oom-pah-pah tuba and accordion, a brushed snare on 2 and 3, a calliope
    tune and glockenspiel sparkle. intense=True (sky_harbor_final) adds
    timpani on every downbeat, a snare drive, brass stabs and a counter-line:
    same tempo and length, so the game cross-fades in time."""
    bpm = 144.0
    beat = 60.0 / bpm
    bars = 24
    d = bars * 3 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    # Roots relative to A4 (F = -4), chord tones as semitone offsets.
    prog = [(-4, (0, 4, 7)), (-9, (0, 4, 7, 10)), (-4, (0, 4, 7)), (1, (0, 4, 7)),
            (-2, (0, 3, 7)), (-9, (0, 4, 7, 10)), (-4, (0, 4, 7)), (-4, (0, 4, 7))]
    # The tune: (semitones from A4, beat in bar, length in beats) per bar of the 8-bar phrase.
    tune = [
        [(-4, 0, 1), (0, 1, 1), (3, 2, 1)],
        [(3, 0, 2), (1, 2, 1)],
        [(0, 0, 1), (3, 1, 1), (8, 2, 1)],
        [(5, 0, 3)],
        [(1, 0, 1), (5, 1, 1), (10, 2, 1)],
        [(8, 0, 1), (6, 1, 1), (5, 2, 1)],
        [(3, 0, 1), (1, 1, 1), (-1, 2, 1)],
        [(0, 0, 3)],
    ]
    kick = sweep(110, 45, 0.25, "sine", 0.45) * env(0.25, 0.001, power=2.2)
    for bar in range(bars):
        root, chord = prog[bar % 8]
        t0 = bar * 3 * beat
        both(tuba(note(root - 12 if root < 0 else root - 24), beat * 0.9), t0, 0.95, 0.45)
        both(kick, t0, 0.5)
        both(kick_click(0.6), t0, 0.1)
        for b in (1, 2):
            both(accordion([root + 12 + c for c in chord], beat * 0.55), t0 + b * beat, 0.2, 0.62)
            both(brush(), t0 + b * beat, 0.16, 0.3)
        if bar % 2 == 1:
            both(tuba(note((root - 12 if root < 0 else root - 24) + 7), beat * 0.8), t0 + 2 * beat, 0.3, 0.45)
        octave = 12 if bar >= 8 and bar < 16 else 0
        for semis, at, length in tune[bar % 8]:
            both(calliope(note(semis + octave), length * beat * 0.95), t0 + at * beat, 0.24, 0.55)
            if bar >= 16 or intense:
                both(glock(note(semis + 24), 0.8), t0 + at * beat, 0.07, 0.7)
        if intense:
            both(timpani(note(root - 24 if root < 0 else root - 36), 0.9), t0, 0.42, 0.45)
            for s in range(6):
                both(brush(0.08), t0 + (1 + s / 3) * beat, 0.12 + 0.02 * s, 0.35)
            if bar % 4 == 3:
                both(brass_stab([root + c for c in chord]), t0 + 2 * beat, 0.24, 0.5)
            if bar % 8 == 7:
                both(cymbal(1.4), t0 + 3 * beat, 0.08, 0.6)
            for k, c in enumerate(chord[:3]):
                both(calliope(note(root + c), beat * 0.9, 0.6), t0 + k * beat, 0.08, 0.3)
        elif bar % 8 == 7:
            both(cymbal(1.2), t0 + 3 * beat, 0.04, 0.6)
    return fold_loop(left, right, d)


def sky_ambience():
    """16 s seamless bed: wind breathing over the islands, bunting flapping,
    rope creaks, a far propeller hum and a few wind chimes."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    left = wind_bed(n, 0.0) * 0.8
    right = wind_bed(n, 1.7) * 0.8
    hum = (np.sin(2 * np.pi * 46 * t) + 0.5 * np.sin(2 * np.pi * 92 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * t * 3.0) ** 2) * 0.05
    left += hum
    right += hum * 0.7
    for _ in range(28):
        at = rng.uniform(0, d - 0.5)
        flap = sum(band(noise(0.05), 900, 700) * env(0.05, 0.003, 0.04, power=1.5) for _ in range(1))
        for k in range(3):
            place(left if k % 2 else right, flap, at + k * 0.07, rng.uniform(0.05, 0.12))
    for at in (2.5, 7.8, 12.1):
        f = rng.uniform(180, 260)
        creak = sweep(f, f * 1.3, 0.5, "saw", 0.6) * env(0.5, 0.08, 0.4, power=1.0)
        place(left, filt(creak, low=1800, high=150), at, 0.05)
    for at in (4.0, 4.3, 4.5, 10.6, 10.9):
        place(right, glock(note(int(rng.integers(19, 31))), 1.2), at, 0.03)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Sky Diver
# ---------------------------------------------------------------------------

def sky_diver_whoop_1():
    return groan(300, 0.55, glide=0.8, formants=((800, 180), (2100, 320)), rasp=0.35, wobble=0.1)


def sky_diver_whoop_2():
    return groan(360, 0.5, glide=-0.5, formants=((900, 200), (2400, 360)), rasp=0.4, wobble=0.12)


def sky_dive_whistle():
    """The dive telegraph: a slide whistle rising over a gathering rush of air."""
    d = 0.8
    whistle = sweep(600, 1800, d, "sine", 0.7) * env(d, 0.03, d * 1.2, power=0.5, release=0.04)
    air = band(noise(d), 1200, 900) * env(d, 0.4, d, power=0.6, release=0.03)
    return whistle * 0.6 + air * 0.5


def sky_dive_launch():
    """The vault: a whoosh up and away."""
    d = 0.6
    t = t_axis(d)
    return band(noise(d), 1400, 1000) * np.exp(-((t - 0.18) / 0.15) ** 2) * 1.4


def sky_chute_pop():
    """The canopy opens: a snapping fwump of fabric and a flutter."""
    d = 0.7
    snap = filt(noise(0.08), low=1800, high=150) * env(0.08, 0.002, power=1.5)
    out = silence(d)
    place(out, snap, 0.0, 1.4)
    place(out, sweep(160, 60, 0.25, "sine", 0.5) * env(0.25, 0.002, 0.2, power=2.0), 0.0, 0.9)
    for k in range(6):
        place(out, band(noise(0.04), 700, 500) * env(0.04, 0.003, power=1.4), 0.12 + k * 0.07, 0.5 - 0.06 * k)
    return out


def sky_dive_land():
    """Touchdown on the planks: a thump, a wooden knock and a creak."""
    d = 0.6
    out = silence(d)
    place(out, sweep(150, 45, 0.3, "sine", 0.5) * env(0.3, 0.001, 0.25, power=2.0), 0.0, 1.3)
    place(out, clunk(220, 0.12), 0.0, 0.6)
    place(out, filt(sweep(240, 300, 0.3, "saw", 0.6), low=1600, high=150) * env(0.3, 0.05, 0.25, power=1.0), 0.15, 0.15)
    return out


# ---------------------------------------------------------------------------
# Balloon Vendor
# ---------------------------------------------------------------------------

def sky_vendor_groan_1():
    return groan(104, 1.0, glide=-0.2, formants=((520, 120), (1100, 180)), rasp=0.3, wobble=0.05)


def sky_vendor_groan_2():
    return groan(92, 1.1, glide=0.25, formants=((470, 110), (1000, 170)), rasp=0.35, wobble=0.08)


def sky_vendor_call():
    """The throw telegraph: a sing-song 'ballooons!' and a rubbery squeak."""
    d = 0.95
    out = np.concatenate([groan(150, 0.7, glide=0.45, formants=((650, 140), (1400, 220)), rasp=0.3, wobble=0.08), silence(d - 0.7)])
    squeak = sweep(900, 1500, 0.18, "sine", 0.6) * (1.0 + 0.5 * np.sin(2 * np.pi * 40 * t_axis(0.18))) * env(0.18, 0.01, 0.15, power=1.0)
    place(out, squeak, 0.55, 0.35)
    place(out, squeak[::-1], 0.75, 0.25)
    return out


def sky_balloon_throw():
    """A water balloon lobbed: a wobble of rubber and a slosh."""
    d = 0.55
    t = t_axis(d)
    wobble = np.sin(2 * np.pi * (220 + 60 * np.sin(2 * np.pi * 9 * t)) * t) * env(d, 0.01, 0.4, power=1.2)
    slosh = band(noise(d), 500, 350) * env(d, 0.03, 0.3, power=1.0)
    return wobble * 0.35 + slosh * 0.9


# ---------------------------------------------------------------------------
# Captain Cumulus
# ---------------------------------------------------------------------------

def sky_captain_roar():
    """The captain's dive telegraph: a huge bellow over a ship's horn."""
    d = 1.3
    body = groan(64, d, glide=0.3, formants=((360, 100), (760, 150)), rasp=0.55, wobble=0.06)
    t = t_axis(d)
    horn = filt(np.tanh(2.0 * (np.sin(2 * np.pi * 98 * t) + 0.6 * np.sin(2 * np.pi * 147 * t))), low=900) * env(d, 0.15, d, power=0.6, release=0.2)
    return crush(body + horn * 0.45, 1.4)


def sky_captain_grunt_1():
    return groan(74, 0.8, glide=-0.2, formants=((390, 110), (820, 160)), rasp=0.5, wobble=0.05)


def sky_captain_grunt_2():
    return groan(64, 0.9, glide=0.1, formants=((340, 100), (700, 150)), rasp=0.55, wobble=0.06)


# ---------------------------------------------------------------------------
# The gale
# ---------------------------------------------------------------------------

def sky_gale_horn():
    """The gale arrives: the airship's deep two-note horn and a rising wind."""
    d = 2.4
    t = t_axis(d)
    horn = np.zeros_like(t)
    for f, at, ln in ((82, 0.0, 1.0), (110, 1.05, 1.2)):
        tt = t_axis(ln)
        tone_ = np.tanh(2.2 * (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * 2 * f * tt) + 0.25 * np.sin(2 * np.pi * 3 * f * tt)))
        place(horn, filt(tone_, low=1400) * env(ln, 0.08, ln, power=0.5, release=0.15), at, 0.6)
    wind = filt(noise(d), low=1600, high=200) * (t / d) ** 1.5
    return horn + wind * 0.6


def sky_gale_gust():
    """A gust sweeping across the decks."""
    d = 1.6
    t = t_axis(d)
    centre = 500 + 900 * np.sin(np.pi * t / d)
    lo = filt(noise(d), low=1200, high=150)
    hi = band(noise(d), 1800, 1200)
    shape = np.sin(np.pi * t / d) ** 1.5
    return (lo * 0.8 + hi * 0.4 * (centre / 1400)) * shape


SOUNDS = [
    sky_diver_whoop_1, sky_diver_whoop_2, sky_dive_whistle, sky_dive_launch, sky_chute_pop, sky_dive_land,
    sky_vendor_groan_1, sky_vendor_groan_2, sky_vendor_call, sky_balloon_throw,
    sky_captain_roar, sky_captain_grunt_1, sky_captain_grunt_2,
    sky_gale_horn, sky_gale_gust,
]

VARIANTS = []

MUSIC = {
    "sky_harbor_loop": sky_harbor_loop,
    "sky_harbor_final": lambda: sky_harbor_loop(intense=True),
    "sky_ambience": sky_ambience,
}
