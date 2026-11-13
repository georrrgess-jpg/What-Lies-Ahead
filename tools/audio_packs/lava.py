"""Volcano Isle (World 9) sound pack: Lava Lagoon music and ambience, the Fire
Dancer, Tiki Bartender and Kahuna Krakatoa voices, coconuts and the eruption.

    python tools/gen_audio.py lava

    audio/music/lava_lagoon_loop.ogg    ~34 s island loop: ukulele strums, a
                                        steel-guitar slide lead, log drums and shakers
    audio/music/lava_lagoon_final.ogg   its final-wave variant (war drums, conch
                                        calls, a driving tom pattern)
    audio/music/lava_ambience.ogg       surf on the beach, the lava river's bubbling
                                        rumble, torch crackle and night birds
    audio/sfx/lava_*.wav                enemy and effect sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def uke(freq, seconds, bright=1.0):
    """Nylon-string pluck: soft harmonics that die quickly, a little body thump."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for k in range(1, 8):
        out += np.sin(2 * np.pi * freq * k * t) * (1.0 / k ** 1.3) * bright ** (k - 1) * np.exp(-t * (3.0 + 1.6 * k))
    return out * env(seconds, 0.003, seconds * 2.5, power=0.4, release=0.02)


def strum(semis, seconds, down=True, gain=1.0):
    """A ukulele strum across a chord (strings 12 ms apart)."""
    out = silence(seconds + 0.06)
    order = semis if down else list(reversed(semis))
    for i, s in enumerate(order):
        place(out, uke(note(s), seconds, 1.0), i * 0.012, gain * 0.5)
    place(out, band(noise(0.04), 5000, 3000) * env(0.04, 0.001, power=2.0), 0.0, gain * 0.25)
    return out


def steel(f0, f1, seconds):
    """Lap-steel slide: a glide between two notes with a slow vibrato."""
    t = t_axis(seconds)
    glide = np.clip(t / 0.12, 0, 1)
    f = (f0 + (f1 - f0) * glide) * (1.0 + 0.008 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.3, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return filt(x, low=3200) * env(seconds, 0.02, seconds * 1.6, power=0.5, release=0.08)


def log_drum(freq, seconds=0.35):
    """Hollow slit-drum knock."""
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.7 * t) * np.exp(-t * 30)
    return body * env(seconds, 0.001, seconds * 0.6, power=2.0)


def tom(freq, seconds=0.4):
    return sweep(freq * 1.6, freq, seconds, "sine", 0.3) * env(seconds, 0.001, seconds * 0.7, power=2.0)


def shaker(seconds=0.09):
    return band(noise(seconds), 6500, 3000) * env(seconds, 0.01, seconds, power=1.5)


def conch(freq, seconds):
    """A conch-shell horn call: breathy, rising into the note."""
    t = t_axis(seconds)
    f = freq * (0.94 + 0.06 * np.clip(t / 0.25, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    breath = band(noise(seconds), freq * 3, freq) * 0.3
    return filt(x + breath, low=2400) * env(seconds, 0.12, seconds, power=0.6, release=0.25)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def lava_lagoon_loop(intense=False):
    """112 BPM, 16 bars in G major with a minor turn: G - Em - C - D, then
    Em - C - G - D. Ukulele strums on a calypso pattern, log drums and shakers,
    a walking bass and a lap-steel melody. intense=True (lava_lagoon_final)
    adds war toms on every beat, a tom gallop, conch calls and sixteenth
    shakers: same tempo and length, so the game cross-fades in time."""
    bpm = 112.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(120, 45, 0.22, "sine", 0.45) * env(0.22, 0.001, power=2.2)
    shake = shaker()
    ting = sum(tone(f, 0.25, "sine") * env(0.25, 0.001, 0.2, power=2.0) * a for f, a in ((3520, 1.0), (5280, 0.5), (7900, 0.3)))
    # Roots relative to A4 (G = -14), chord tones as semitone offsets.
    prog_a = [(-14, (0, 4, 7)), (-17, (0, 3, 7)), (-21, (0, 4, 7)), (-19, (0, 4, 7))]
    prog_b = [(-17, (0, 3, 7)), (-21, (0, 4, 7)), (-14, (0, 4, 7)), (-19, (0, 4, 7))]
    melody = [
        [(7, 0.0, 1.5, 4), (9, 1.5, 0.5, 9), (11, 2.0, 2.0, 11)],
        [(7, 0.0, 1.0, 7), (4, 1.0, 1.0, 4), (2, 2.0, 2.0, 0)],
        [(4, 0.0, 1.0, 4), (7, 1.0, 1.0, 7), (9, 2.0, 1.5, 12), (7, 3.5, 0.5, 7)],
        [(6, 0.0, 2.0, 2), (2, 2.0, 2.0, 2)],
    ]
    calypso = (0.0, 0.75, 1.5, 2.0, 2.75, 3.5)
    for bar in range(bars):
        section_b = bar >= 8
        root, triad = (prog_b if section_b else prog_a)[bar % 4]
        t0 = bar * 4 * beat
        chord = [root + 12 + s for s in (triad[0], triad[1], triad[2], 12)]
        for i, at in enumerate(calypso):
            both(strum(chord, beat * 0.9, down=i % 2 == 0, gain=0.9 if i in (0, 3) else 0.6), t0 + at * beat, 0.22, 0.35 + 0.3 * (i % 2))
        for b in range(4):
            both(kick, t0 + b * beat, 0.42 if b in (0, 2) else 0.25)
            for h in range(4 if intense else 2):
                both(shake, t0 + (b + h / (4 if intense else 2)) * beat, 0.2 if h % 2 else 0.28, 0.7)
            both(ting, t0 + (b + 0.5) * beat, 0.07, 0.3)
        # Log drums: a two-note figure answering the strum.
        for at, n in ((0.5, 5), (1.0, 0), (2.5, 7), (3.0, 5)):
            both(log_drum(note(root + 12 + n), 0.3), t0 + at * beat, 0.2, 0.25)
        # Walking bass.
        for e, n in enumerate((0, 7, 12, 7) if not section_b else (0, 4, 7, 9)):
            both(filt(uke(note(root - 12 + n), beat * 0.95, 0.5), low=700), t0 + e * beat, 0.62)
        if intense:
            for b in range(4):
                both(tom(90, 0.45), t0 + b * beat, 0.38, 0.45)
            for s in range(4):
                both(tom(150, 0.25), t0 + (3 + s * 0.25) * beat, 0.18 + 0.04 * s, 0.6)
            if bar % 4 == 0:
                both(conch(note(root + 12), 3 * beat), t0, 0.16, 0.4)
        # Lap-steel melody over section B (and over A when intense).
        if section_b or intense:
            for semis, at, length, target in melody[bar % 4]:
                both(steel(note(root + 12 + semis - 2), note(root + 12 + target), length * beat * 1.1), t0 + at * beat, 0.2, 0.6)
    return fold_loop(left, right, d)


def lava_ambience():
    """24 s seamless bed: surf rolling on the beach, the lava river's slow
    bubbling rumble, torch crackle and a few night birds."""
    d = 24.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    surf_l = filt(rng.uniform(-1, 1, n), low=1400, high=120)
    surf_r = filt(rng.uniform(-1, 1, n), low=1400, high=120)
    swell = (0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0 - 1.0)) ** 3
    swell_r = (0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0 + 0.5)) ** 3
    left = surf_l * (0.25 + 0.75 * swell) * 0.8
    right = surf_r * (0.25 + 0.75 * swell_r) * 0.8
    rumble = filt(rng.uniform(-1, 1, n), low=110) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 4.0))
    left += rumble * 0.6
    right += rumble * 0.6
    for _ in range(70):
        at = rng.uniform(0, d - 0.5)
        f = rng.uniform(70, 160)
        blub = sweep(f, f * 1.8, 0.18, "sine", 0.5) * env(0.18, 0.01, 0.15, power=1.5)
        place(left, blub, at, rng.uniform(0.05, 0.14))
        place(right, blub, at + 0.01, rng.uniform(0.05, 0.14))
    crackle = np.zeros(n)
    for _ in range(200):
        at = int(rng.uniform(0, n - 3000))
        ln = int(rng.uniform(80, 700))
        crackle[at:at + ln] += band(rng.uniform(-1, 1, ln), rng.uniform(1800, 5000), 1200) * np.exp(-np.arange(ln) / (ln * 0.25)) * rng.uniform(0.1, 0.35)
    left += crackle * 0.35
    right += crackle * 0.25
    for at, f0 in ((3.0, 2400), (9.5, 2800), (15.2, 2200), (20.1, 2600)):
        chirp = sum(sweep(f0, f0 * 1.3, 0.12, "sine") * env(0.12, 0.01, 0.1, power=1.5) * (1 if k % 2 else 0.7) for k in range(1))
        for k in range(3):
            place(left if k % 2 else right, chirp, at + k * 0.16, 0.05)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Fire Dancer
# ---------------------------------------------------------------------------

def lava_dancer_whoop_1():
    return groan(280, 0.55, glide=0.7, formants=((850, 180), (2000, 320)), rasp=0.4, wobble=0.1)


def lava_dancer_whoop_2():
    return groan(340, 0.5, glide=-0.4, formants=((900, 200), (2300, 360)), rasp=0.45, wobble=0.12)


def lava_dancer_spin():
    """The spin-up telegraph: whirling poi whooshes speeding up, a rising flame roar."""
    d = 0.95
    out = silence(d)
    at = 0.0
    gap = 0.22
    while at < d - 0.1:
        place(out, band(noise(0.16), 900 + at * 900, 500) * env(0.16, 0.05, 0.11, power=1.2), at, 0.7 + at)
        at += gap
        gap *= 0.8
    roar = filt(noise(d), low=1800, high=200) * env(d, 0.5, d * 1.2, power=0.6, release=0.05)
    return out + roar * 0.5


def lava_dancer_dash():
    """The dash: a fiery whoosh with crackling sparks."""
    d = 1.3
    t = t_axis(d)
    whoosh = sum(band(noise(d), c, 600) * np.exp(-((t - at) / 0.22) ** 2) for c, at in ((800, 0.2), (1600, 0.42), (1000, 0.65)))
    flame = filt(noise(d), low=2500, high=300) * env(d, 0.03, d, power=0.8, release=0.2)
    sparks = (rng.uniform(0, 1, len(t)) > 0.995).astype(float) * rng.uniform(-1, 1, len(t))
    return whoosh * 1.3 + flame * 0.5 + filt(sparks, high=3000) * 0.6


# ---------------------------------------------------------------------------
# Tiki Bartender and coconuts
# ---------------------------------------------------------------------------

def lava_bartender_groan_1():
    return groan(100, 1.0, glide=-0.2, formants=((500, 120), (1050, 180)), rasp=0.3, wobble=0.05)


def lava_bartender_groan_2():
    return groan(88, 1.1, glide=0.2, formants=((450, 110), (950, 170)), rasp=0.35, wobble=0.08)


def lava_bartender_call():
    """The throw telegraph: a hoarse 'last call!' bellow and a coconut slosh."""
    d = 0.9
    out = groan(130, 0.7, glide=0.35, formants=((700, 150), (1500, 240)), rasp=0.45, wobble=0.06)
    out = np.concatenate([out, silence(d - 0.7)])
    place(out, band(noise(0.25), 500, 300) * env(0.25, 0.02, 0.2, power=1.2), 0.45, 0.5)
    return out


def lava_coconut_throw():
    """A heave and the thrum of a coconut tumbling away."""
    d = 0.6
    out = band(noise(d), 600, 400) * env(d, 0.04, 0.35, power=1.0) * 1.2
    place(out, log_drum(260, 0.2), 0.0, 0.5)
    return out


# ---------------------------------------------------------------------------
# Kahuna Krakatoa
# ---------------------------------------------------------------------------

def lava_kahuna_roar():
    """A huge chanting roar with a rumble of lava (the lava-bomb telegraph)."""
    d = 1.3
    body = groan(66, d, glide=0.3, formants=((340, 100), (720, 150)), rasp=0.6, wobble=0.06)
    rumble = filt(noise(d), low=300) * env(d, 0.1, d, power=0.8, release=0.3)
    return crush(body + rumble * 0.7, 1.5)


def lava_kahuna_grunt_1():
    return groan(72, 0.8, glide=-0.2, formants=((380, 110), (800, 160)), rasp=0.55, wobble=0.05)


def lava_kahuna_grunt_2():
    return groan(62, 0.9, glide=0.1, formants=((330, 100), (690, 150)), rasp=0.6, wobble=0.06)


# ---------------------------------------------------------------------------
# The eruption
# ---------------------------------------------------------------------------

def lava_eruption_rumble():
    """Mount Kahuna blows: a deep boom rolling into a long rumble."""
    d = 3.2
    boom = sweep(70, 28, 1.2, "sine", 0.5) * env(1.2, 0.005, 1.0, power=1.6)
    rumble = filt(noise(d), low=160) * env(d, 0.05, d, power=0.7, release=0.6)
    crack = filt(noise(0.3), high=800) * env(0.3, 0.001, power=2.0)
    out = rumble * 1.1
    place(out, boom, 0.0, 1.4)
    place(out, crack, 0.0, 0.5)
    return out


def lava_bomb_whistle():
    """An ember bomb on its way down: a falling whistle with a hiss."""
    d = 1.6
    whistle = sweep(1600, 700, d, "sine", 0.8) * env(d, 0.2, d * 1.3, power=0.5, release=0.05)
    hiss = band(noise(d), 3000, 1500) * env(d, 0.4, d, power=0.6, release=0.05)
    return whistle * 0.6 + hiss * 0.4


def lava_bomb_impact():
    """The bomb lands: a thump, a splash of sizzling embers."""
    d = 0.9
    thump = sweep(140, 40, 0.35, "sine", 0.5) * env(0.35, 0.001, 0.3, power=2.0)
    sizzle = band(noise(d), 4200, 2500) * env(d, 0.005, 0.7, power=1.2)
    out = sizzle * 0.7
    place(out, thump, 0.0, 1.3)
    place(out, filt(noise(0.12), high=600) * env(0.12, 0.001, power=2.0), 0.0, 0.8)
    return out


SOUNDS = [
    lava_dancer_whoop_1, lava_dancer_whoop_2, lava_dancer_spin, lava_dancer_dash,
    lava_bartender_groan_1, lava_bartender_groan_2, lava_bartender_call, lava_coconut_throw,
    lava_kahuna_roar, lava_kahuna_grunt_1, lava_kahuna_grunt_2,
    lava_eruption_rumble, lava_bomb_whistle, lava_bomb_impact,
]

VARIANTS = [
    (lava_dancer_whoop_1, (0.92, 1.1)), (lava_bartender_groan_1, (0.9, 1.08)), (lava_bomb_impact, (0.9, 1.1)),
]

MUSIC = {
    "lava_lagoon_loop": lava_lagoon_loop,
    "lava_lagoon_final": lambda: lava_lagoon_loop(intense=True),
    "lava_ambience": lava_ambience,
}
