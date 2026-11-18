"""Pirate Cove (World 13) sound pack: Skull Harbor music and ambience, the
Deckhand, Powder Monkey and Captain Barnacle voices, cutlasses, powder kegs,
cannons and the Broadside.

    python tools/gen_audio.py cove

    audio/music/skull_harbor_loop.ogg   32 s sunset sea shanty (4/4, 120 BPM, D minor):
                                        a squeezebox lead, a tin whistle answer,
                                        plucked double bass, stomps and claps
    audio/music/skull_harbor_final.ogg  its final-wave variant (war drums on the
                                        beat, a snare drive, low brass stabs and
                                        the whistle doubled an octave up)
    audio/music/cove_ambience.ogg       12 s: waves lapping the quay, gulls, creaking
                                        timber and rigging, a far ship's bell
    audio/sfx/cove_*.wav                enemy, cutlass, keg, cannon and broadside sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def squeezebox(semis, seconds, gain=1.0):
    """Concertina: two slightly detuned reeds per note with a bellows swell."""
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        reed = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sign(np.sin(2 * np.pi * f * 1.005 * t + 0.4)) * 0.5
        out += filt(reed, low=2400) * 0.3
    swell = 0.75 + 0.25 * np.sin(np.pi * np.clip(t / seconds, 0, 1))
    return out * swell * env(seconds, 0.02, seconds, power=0.5, release=0.05) * gain


def whistle(freq, seconds, gain=1.0):
    """Tin whistle: a pure, slightly breathy tone with a late vibrato."""
    t = t_axis(seconds)
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1)
    x = np.sin(2 * np.pi * freq * vib * t) + 0.12 * np.sin(4 * np.pi * freq * t)
    breath = band(noise(seconds), freq * 2, freq * 0.8) * 0.08
    return (x + breath) * env(seconds, 0.015, seconds, power=0.5, release=0.04) * gain


def pluck_bass(freq, seconds):
    """Plucked double bass: a woody thump that decays."""
    t = t_axis(seconds)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) * np.exp(-t * 8)
    return audible_bass(filt(x, low=1200), 0.32) * env(seconds, 0.004, seconds, power=1.6)


def stomp(seconds=0.22):
    """A boot on the deck: a low thud and a wooden knock."""
    t = t_axis(seconds)
    thud = sweep(95, 50, seconds, "sine", 0.5) * np.exp(-t * 16)
    knock = band(noise(seconds), 700, 400) * np.exp(-t * 40) * 0.5
    return thud + knock


def clap(seconds=0.14):
    t = t_axis(seconds)
    burst = sum(band(noise(seconds), 1800, 1200) * np.exp(-((t - k * 0.011) / 0.004) ** 2) for k in range(3))
    return burst + band(noise(seconds), 1500, 1000) * np.exp(-t * 30) * 0.4


def war_drum(freq, seconds=0.6):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t * (1.0 + 0.06 * np.exp(-t * 25)))
    return (body + filt(noise(seconds), low=600) * 0.5 * np.exp(-t * 35)) * env(seconds, 0.002, seconds * 0.7, power=1.8)


def snare(seconds=0.16):
    t = t_axis(seconds)
    return band(noise(seconds), 3000, 2500) * np.exp(-t * 22) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.4


def low_brass(semis, seconds=0.4):
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        ph = 2 * np.pi * f * t
        out += filt(np.tanh(2.4 * (np.sin(ph) + 0.5 * np.sin(2 * ph))), low=2200) * 0.3
    return out * env(seconds, 0.015, seconds * 0.8, power=1.2)


def bell(freq, seconds=2.0):
    """A ship's bell: inharmonic partials with a long ring."""
    t = t_axis(seconds)
    return sum(np.sin(2 * np.pi * freq * r * t) * a * np.exp(-t * d) for r, a, d in ((1.0, 1.0, 1.4), (2.4, 0.5, 2.6), (3.9, 0.3, 4.0),
                                                                                       (5.4, 0.15, 6.0)))


def surf(n, slow=4.5, shift=0.0):
    """Waves lapping: a low wash that swells and recedes with a hiss on top."""
    t = np.arange(n) / SR
    wash = filt(rng.uniform(-1, 1, n), low=700, high=60)
    hiss = filt(rng.uniform(-1, 1, n), low=5000, high=1500)
    swell = (0.5 + 0.5 * np.sin(2 * np.pi * t / slow + shift)) ** 2
    lap = (0.5 + 0.5 * np.sin(2 * np.pi * t / (slow * 0.5) + shift * 1.7)) ** 6
    return wash * (0.3 + 0.7 * swell) + hiss * (0.15 + 0.6 * lap) * 0.22


def gull(seconds=0.45, f0=1500):
    """A herring gull's cry: a sliding squeal with a rough edge."""
    t = t_axis(seconds)
    f = f0 * (1.0 + 0.25 * np.sin(np.pi * t / seconds)) * (1.0 - 0.3 * t / seconds)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sign(np.sin(3 * ph))
    return filt(x, low=4500, high=600) * env(seconds, 0.03, seconds, power=0.8, release=0.05)


def creak(f=200, seconds=0.5):
    return filt(sweep(f, f * 1.35, seconds, "saw", 0.6), low=1800, high=150) * env(seconds, 0.08, seconds * 0.8, power=1.0)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def skull_harbor_loop(intense=False):
    """120 BPM shanty, 16 bars (32 s) in D minor: Dm - C - Dm - A7 / Dm - C -
    F - A7 / Dm - Gm - C - F / Dm - C - A7 - Dm. A squeezebox carries the tune
    over plucked bass, stomps on 1 and 3 and claps on 2 and 4; a tin whistle
    answers each phrase. intense=True (skull_harbor_final) adds war drums on
    every beat, a snare drive, low brass stabs and the whistle doubled: same
    tempo and length, so the game cross-fades in time."""
    bpm = 120.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    # Roots relative to A4 (D = -7), chord tones as semitone offsets.
    dm, c, a7, f, gm = (-7, (0, 3, 7)), (-9, (0, 4, 7)), (0, (0, 4, 7, 10)), (-4, (0, 4, 7)), (-2, (0, 3, 7))
    prog = [dm, c, dm, a7, dm, c, f, a7, dm, gm, c, f, dm, c, a7, dm]
    # The tune: (semitones from A4, beat, length in beats) per bar.
    tune = [
        [(5, 0, 1), (5, 1, 0.5), (7, 1.5, 0.5), (8, 2, 1), (5, 3, 1)],
        [(3, 0, 1.5), (0, 1.5, 0.5), (3, 2, 1), (7, 3, 1)],
        [(8, 0, 1), (7, 1, 0.5), (5, 1.5, 0.5), (3, 2, 1), (5, 3, 1)],
        [(4, 0, 3), (0, 3, 1)],
        [(5, 0, 1), (5, 1, 0.5), (7, 1.5, 0.5), (8, 2, 1), (12, 3, 1)],
        [(10, 0, 1.5), (7, 1.5, 0.5), (3, 2, 1), (7, 3, 1)],
        [(8, 0, 1), (12, 1, 1), (10, 2, 1), (8, 3, 1)],
        [(7, 0, 2), (4, 2, 2)],
        [(5, 0, 1), (8, 1, 1), (12, 2, 1.5), (10, 3.5, 0.5)],
        [(10, 0, 1), (8, 1, 0.5), (7, 1.5, 0.5), (5, 2, 2)],
        [(7, 0, 1), (10, 1, 1), (14, 2, 1.5), (12, 3.5, 0.5)],
        [(12, 0, 1), (10, 1, 1), (8, 2, 2)],
        [(5, 0, 1), (5, 1, 0.5), (7, 1.5, 0.5), (8, 2, 1), (5, 3, 1)],
        [(3, 0, 1), (7, 1, 1), (10, 2, 1), (7, 3, 1)],
        [(4, 0, 1), (7, 1, 1), (4, 2, 1), (0, 3, 1)],
        [(5, 0, 3)],
    ]
    for bar in range(bars):
        root, chord = prog[bar]
        t0 = bar * 4 * beat
        bass_root = root - 12 if root < -2 else root - 24
        for b, step in ((0, 0), (1, 7), (2, 12), (3, 7)):
            both(pluck_bass(note(bass_root + step), beat * 0.9), t0 + b * beat, 0.5, 0.45)
        for b in (0, 2):
            both(stomp(), t0 + b * beat, 0.4, 0.5)
        for b in (1, 3):
            both(clap(), t0 + b * beat, 0.3, 0.65)
        for b in (0.5, 1.5, 2.5, 3.5):
            both(squeezebox([root + 12 + k for k in chord[:3]], beat * 0.4, 0.5), t0 + b * beat, 0.17, 0.35)
        for semis, at, length in tune[bar]:
            both(squeezebox([semis], length * beat * 0.95), t0 + at * beat, 0.45, 0.55)
        if bar % 4 == 3 or intense:
            for semis, at, length in tune[(bar + 3) % 16][:2]:
                both(whistle(note(semis + 12), length * beat * 0.9), t0 + (at + 2.0) * beat if at < 2 else t0 + at * beat, 0.16, 0.72)
        if intense:
            for b in range(4):
                both(war_drum(note(bass_root - 12), 0.5), t0 + b * beat, 0.32 if b % 2 == 0 else 0.22, 0.45)
            for s in range(8):
                both(snare(0.1), t0 + s * beat * 0.5, 0.06 + 0.012 * (s % 4), 0.35)
            if bar % 2 == 1:
                both(low_brass([root - 12 + k for k in chord[:3]]), t0 + 3 * beat, 0.22, 0.5)
            if bar % 8 == 7:
                both(cymbal(1.4), t0 + 3.5 * beat, 0.08, 0.6)
        elif bar % 8 == 7:
            both(cymbal(1.2), t0 + 3.5 * beat, 0.04, 0.6)
    return fold_loop(left, right, d)


def cove_ambience():
    """12 s seamless bed: waves lapping the quay, gulls, timber and rigging
    creaks, a far ship's bell."""
    d = 12.0
    n = int(SR * (d + 1.0))
    left = surf(n, 4.0, 0.0) * 0.7
    right = surf(n, 4.6, 1.9) * 0.7
    for at, f0, side in ((1.2, 1500, 0), (1.7, 1650, 0), (5.6, 1350, 1), (9.1, 1550, 1), (9.5, 1700, 1)):
        place(left if side == 0 else right, gull(rng.uniform(0.35, 0.55), f0), at, 0.05)
    for at in (2.8, 7.1, 10.4):
        place(left, creak(rng.uniform(170, 240), 0.6), at, 0.05)
        place(right, creak(rng.uniform(260, 320), 0.4), at + 0.4, 0.03)
    place(right, bell(note(-5), 3.0), 6.2, 0.025)
    place(left, bell(note(-5), 3.0), 6.2, 0.018)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Deckhand
# ---------------------------------------------------------------------------

def cove_deckhand_growl_1():
    return groan(150, 0.7, glide=0.4, formants=((700, 160), (1600, 260)), rasp=0.45, wobble=0.08)


def cove_deckhand_growl_2():
    return groan(130, 0.8, glide=-0.35, formants=((650, 150), (1500, 240)), rasp=0.5, wobble=0.1)


def cove_cutlass_draw():
    """The lunge telegraph: steel scraping out of a scabbard, a low growl."""
    d = 0.8
    t = t_axis(d)
    scrape = band(noise(d), 4200, 2200) * (0.4 + 0.6 * np.sin(np.pi * np.clip(t / 0.5, 0, 1))) * np.exp(-np.maximum(t - 0.5, 0) * 12)
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((2300, 0.3), (3700, 0.2), (5100, 0.1))) * env(d, 0.35, d, power=1.2)
    voice = np.concatenate([groan(120, 0.6, glide=0.3, formants=((600, 140), (1300, 220)), rasp=0.5, wobble=0.06), silence(d - 0.6)])
    return scrape * 0.7 + ring * 0.35 + voice * 0.5


def cove_cutlass_lunge():
    """The lunge: a fast whoosh and a bright slash."""
    d = 0.5
    t = t_axis(d)
    whoosh = band(noise(d), 1600, 1200) * np.exp(-((t - 0.12) / 0.08) ** 2) * 1.3
    slash = sweep(5200, 2400, 0.12, "sine", 0.6) * env(0.12, 0.002, 0.1, power=1.5)
    out = whoosh
    place(out, slash, 0.1, 0.35)
    return out


# ---------------------------------------------------------------------------
# Powder Monkey
# ---------------------------------------------------------------------------

def cove_monkey_cackle_1():
    out = silence(0.8)
    for k in range(4):
        place(out, groan(330 + 30 * k, 0.14, glide=0.6, formants=((900, 200), (2300, 360)), rasp=0.35, wobble=0.1), k * 0.15, 0.8)
    return out


def cove_monkey_cackle_2():
    out = silence(0.7)
    for k in range(3):
        place(out, groan(380 - 25 * k, 0.16, glide=-0.4, formants=((1000, 220), (2500, 380)), rasp=0.3, wobble=0.12), k * 0.18, 0.8)
    return out


def cove_fuse_light():
    """The keg telegraph: a match strike, then a fizzing, spitting fuse."""
    d = 1.0
    t = t_axis(d)
    strike = band(noise(0.12), 3500, 2500) * env(0.12, 0.004, 0.1, power=1.2)
    fizz = band(noise(d), 6000, 3500) * (0.5 + 0.5 * (rng.uniform(0, 1, len(t)) > 0.7)) * np.clip((t - 0.1) / 0.2, 0, 1)
    out = fizz * 0.45
    place(out, strike, 0.0, 1.0)
    place(out, groan(360, 0.35, glide=0.5, formants=((950, 200), (2400, 360)), rasp=0.3, wobble=0.1), 0.45, 0.4)
    return out


def cove_keg_throw():
    """The keg leaves the hands: a heave, a whoosh and the fuse fizzing past."""
    d = 0.6
    t = t_axis(d)
    whoosh = band(noise(d), 900, 600) * np.exp(-((t - 0.15) / 0.12) ** 2)
    fizz = band(noise(d), 6000, 3000) * np.exp(-t * 3) * 0.3
    return whoosh * 1.2 + fizz


def cove_keg_blast():
    """The keg blows: a round boom, a crack, splinters and a confetti pop."""
    d = 1.2
    t = t_axis(d)
    boom = sweep(90, 35, d, "sine", 0.4) * np.exp(-t * 4.5)
    crack = filt(noise(d), low=3000, high=200) * np.exp(-t * 18)
    out = crush(boom * 1.2 + crack * 0.7, 1.6)
    for k in range(6):
        place(out, clunk(rng.uniform(400, 900), 0.06), 0.12 + k * 0.05, 0.15)
    place(out, band(noise(0.2), 5000, 3000) * env(0.2, 0.002, 0.18, power=1.4), 0.05, 0.3)
    return out


# ---------------------------------------------------------------------------
# Captain Barnacle and the cannons
# ---------------------------------------------------------------------------

def cove_barnacle_bellow():
    """The captain's telegraph: a huge 'yarr' over a ship's bell."""
    d = 1.3
    body = groan(62, d, glide=0.35, formants=((380, 100), (820, 160)), rasp=0.6, wobble=0.06)
    out = crush(body, 1.4)
    place(out, bell(note(-17), 1.0), 0.0, 0.25)
    return out


def cove_barnacle_grunt_1():
    return groan(70, 0.8, glide=-0.2, formants=((380, 110), (800, 160)), rasp=0.55, wobble=0.05)


def cove_barnacle_grunt_2():
    return groan(60, 0.9, glide=0.15, formants=((340, 100), (720, 150)), rasp=0.6, wobble=0.06)


def cove_anchor_slam():
    """The anchor hits the stones: an iron clang, a thud and a chain rattle."""
    d = 1.4
    t = t_axis(d)
    clang = sum(np.sin(2 * np.pi * f * t) * a * np.exp(-t * k) for f, a, k in ((180, 1.0, 3.0), (437, 0.5, 5.0), (731, 0.3, 7.0), (1290, 0.2, 10.0)))
    thud = sweep(110, 40, 0.5, "sine", 0.5) * env(0.5, 0.001, 0.4, power=2.0)
    out = clang * 0.5
    place(out, thud, 0.0, 1.2)
    for k in range(7):
        place(out, clunk(rng.uniform(600, 1100), 0.05), 0.2 + k * 0.06, 0.2 - 0.02 * k)
    return out


def cove_cannon_boom():
    """A cannon fires from the galleon: a deep boom with a smoky tail."""
    d = 1.6
    t = t_axis(d)
    boom = sweep(70, 30, d, "sine", 0.35) * np.exp(-t * 3.0)
    blast = filt(noise(d), low=1400, high=40) * np.exp(-t * 6.0)
    return crush(boom * 1.3 + blast * 0.9, 1.8)


def cove_cannon_whistle():
    """An incoming cannonball: a falling whistle (the ring's warning)."""
    d = 1.2
    whistle_ = sweep(1900, 700, d, "sine", 0.8) * env(d, 0.15, d, power=0.5, release=0.05)
    air = band(noise(d), 1500, 900) * env(d, 0.5, d, power=0.5, release=0.04)
    return whistle_ * 0.5 + air * 0.35


def cove_cannon_impact():
    """The cannonball lands: a thump, cracking stones and a puff."""
    d = 0.9
    t = t_axis(d)
    thump = sweep(120, 40, 0.5, "sine", 0.5) * env(0.5, 0.001, 0.45, power=2.0)
    crack = filt(noise(d), low=2500, high=250) * np.exp(-t * 14)
    out = crack * 0.6
    place(out, thump, 0.0, 1.3)
    for k in range(4):
        place(out, clunk(rng.uniform(250, 500), 0.08), 0.06 + k * 0.07, 0.25)
    return out


def cove_broadside_call():
    """The Broadside begins: the ship's bell rung three times and a far horn."""
    d = 3.0
    out = silence(d)
    for k in range(3):
        place(out, bell(note(-5), 1.6), k * 0.45, 0.5)
    t = t_axis(1.4)
    horn = filt(np.tanh(2.2 * (np.sin(2 * np.pi * 73 * t) + 0.5 * np.sin(2 * np.pi * 146 * t))), low=1100) * env(1.4, 0.12, 1.4, power=0.6, release=0.2)
    place(out, horn, 1.4, 0.5)
    return out


SOUNDS = [
    cove_deckhand_growl_1, cove_deckhand_growl_2, cove_cutlass_draw, cove_cutlass_lunge,
    cove_monkey_cackle_1, cove_monkey_cackle_2, cove_fuse_light, cove_keg_throw, cove_keg_blast,
    cove_barnacle_bellow, cove_barnacle_grunt_1, cove_barnacle_grunt_2, cove_anchor_slam,
    cove_cannon_boom, cove_cannon_whistle, cove_cannon_impact, cove_broadside_call,
]

VARIANTS = []

MUSIC = {
    "skull_harbor_loop": skull_harbor_loop,
    "skull_harbor_final": lambda: skull_harbor_loop(intense=True),
    "cove_ambience": cove_ambience,
}
