"""Megamall Midnight (World 6) sound pack: Midnight Mall music and ambience, the
Mall Walker, Food Court Flinger and Night Manager voices and tells, the soda
lob, and the power cut.

    python tools/gen_audio.py mall

    audio/music/midnight_mall_loop.ogg   30 s retro mall-pop loop: electric piano
                                         sevenths, a slap bass, gated snare and a
                                         shimmering synth arpeggio, two sections
    audio/music/midnight_mall_final.ogg  its final-wave variant (driving bass,
                                         sixteenth hats, claps, a lead line)
    audio/music/mall_ambience.ogg        16 s bed: the air-con hum, the fountain,
                                         a buzzing light and a distant escalator
    audio/sfx/mall_*.wav                 enemy, effect and power-cut sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def epiano(freq, seconds, gain=1.0):
    """FM electric piano: a bell-ish tine over a warm body, slow decay."""
    t = t_axis(seconds)
    index = 1.6 * np.exp(-t * 5.0) + 0.25
    mod = np.sin(2 * np.pi * freq * t) * index
    body = np.sin(2 * np.pi * freq * t + mod)
    tine = np.sin(2 * np.pi * freq * 7.0 * t) * np.exp(-t * 18.0) * 0.18
    return (body + tine) * env(seconds, 0.003, seconds * 0.9, power=1.6) * gain


def chord_stab(semis, seconds, gain=1.0):
    return sum(epiano(note(s), seconds, gain * (1.0 - 0.08 * i)) for i, s in enumerate(semis))


def slap_bass(freq, seconds):
    t = t_axis(seconds)
    x = np.sin(2 * np.pi * freq * t) * 0.9 + osc(2 * np.pi * freq * t, "saw") * 0.35
    pop = band(noise(seconds), 2200, 900) * np.exp(-t * 60.0) * 0.25
    return filt(x, low=1100) * env(seconds, 0.002, seconds * 0.7, power=1.5) + pop


def arp_synth(freq, seconds, gain=1.0):
    """Bright, short square-ish pluck for the arpeggio."""
    t = t_axis(seconds)
    x = osc(2 * np.pi * freq * t, "square") * 0.5 + osc(2 * np.pi * freq * 1.005 * t, "saw") * 0.4
    return filt(x, low=3600) * env(seconds, 0.002, seconds * 0.5, power=2.0) * gain


def pad(semis, seconds):
    out = sum(tone(note(s), seconds, "tri", 0.004, 4.0 + i * 0.6) for i, s in enumerate(semis))
    return filt(out, low=1800) * env(seconds, seconds * 0.3, seconds * 1.5, power=0.6, release=seconds * 0.2)


def gated_snare(seconds=0.26):
    body = band(noise(seconds), 1700, 1200) * 0.9 + tone(190, seconds) * 0.4
    gate = (t_axis(seconds) < seconds * 0.7).astype(float)
    return body * gate * env(seconds, 0.001, seconds * 1.5, power=0.9)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def midnight_mall_loop(intense=False):
    """128 BPM, F major. Section A (bars 1-8): Fmaj7 - Em7 - Dm7 - Cmaj7 with
    electric-piano stabs, a slap bass and a gated snare. Section B (bars
    9-16): Bbmaj7 - Am7 - Gm7 - C7sus with a rising arpeggio and a melody.

    intense=True is the final-wave variant (midnight_mall_final): sixteenth
    hats, claps, an eighth-note driving bass, crashes and risers, and the lead
    over both sections. Same tempo and length, so the game cross-fades in time."""
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(130, 45, 0.22, "sine", 0.45) * env(0.22, 0.001, power=2.2)
    place(kick, kick_click(0.3), 0.0)
    snare = gated_snare()
    hat = filt(noise(0.05), high=8500) * env(0.05, 0.0005, power=2.8)
    open_hat = filt(noise(0.2), high=7000) * env(0.2, 0.001, power=1.5)
    hand_clap, crash = clap(), cymbal()
    # Roots from A4 with seventh-chord shapes.
    chords_a = [(-16, (0, 4, 7, 11)), (-17, (0, 3, 7, 10)), (-19, (0, 3, 7, 10)), (-21, (0, 4, 7, 11))]   # Fmaj7 Em7 Dm7 Cmaj7
    chords_b = [(-11, (0, 4, 7, 11)), (-12, (0, 3, 7, 10)), (-14, (0, 3, 7, 10)), (-21, (0, 5, 7, 10))]   # Bbmaj7 Am7 Gm7 C7sus
    lead_phrases = [
        [(7, 0.0, 1.5), (9, 1.5, 0.5), (11, 2.0, 1.0), (14, 3.0, 1.0)],
        [(12, 0.0, 2.0), (11, 2.0, 1.0), (7, 3.0, 1.0)],
        [(9, 0.0, 1.0), (7, 1.0, 1.0), (5, 2.0, 1.5), (4, 3.5, 0.5)],
        [(7, 0.0, 3.0), (2, 3.0, 1.0)],
    ]
    for bar in range(bars):
        section_b = bar >= 8
        busy = section_b or intense
        root, shape = (chords_b if section_b else chords_a)[bar % 4]
        t0 = bar * 4 * beat
        if intense and bar % 4 == 0:
            both(crash, t0, 0.1, 0.6)
        if bar % 8 == 7:
            both(riser(2 * beat), t0 + 2 * beat, 0.06 if not intense else 0.09, 0.4)
        for b in range(4):
            both(kick, t0 + b * beat, 0.55 if (b % 2 == 0 or intense) else 0.0)
            if b in (1, 3):
                both(snare, t0 + b * beat, 0.3)
                if intense:
                    both(hand_clap, t0 + b * beat, 0.14, 0.45)
            sub = 4 if intense else 2
            for h in range(sub):
                both(hat, t0 + (b + h / sub) * beat, 0.07 if h % 2 == 0 else 0.1, 0.65)
            if busy and b == 3:
                both(open_hat, t0 + (b + 0.5) * beat, 0.07, 0.6)
        # Electric-piano stabs: a syncopated two-bar rhythm.
        for at in ((0.0, 1.5), (1.5, 0.5), (2.5, 1.0)) if bar % 2 == 0 else ((0.5, 1.0), (2.0, 1.5), (3.5, 0.5)):
            both(chord_stab([root + 12 + s for s in shape], at[1] * beat * 1.4, 0.55), t0 + at[0] * beat, 0.16, 0.4)
        # Slap bass (an eighth-note drive when intense).
        pattern = [(0.0, 0, 0.75), (0.75, 12, 0.25), (1.5, 0, 0.5), (2.5, 7, 0.5), (3.0, 0, 0.5), (3.5, 12, 0.5)]
        if intense:
            pattern = [(e * 0.5, 12 if e % 4 == 3 else 0, 0.45) for e in range(8)]
        for at, off, ln in pattern:
            both(slap_bass(note(root - 12 + off), ln * beat), t0 + at * beat, 0.5)
        # Arpeggio up the chord in section B (and softly under A when intense).
        if busy:
            for e in range(8):
                s = root + 24 + shape[e % 4] + (12 if e >= 4 else 0)
                both(arp_synth(note(s), beat * 0.45, 0.6), t0 + e * beat * 0.5, 0.09 if section_b else 0.06, 0.2 + 0.6 * (e / 7.0))
        both(pad([root + s for s in shape], 4 * beat), t0, 0.12)
        # Lead melody over B (and over A in the final-wave variant).
        if section_b or intense:
            for semis, at, length in lead_phrases[bar % 4]:
                both(epiano(note(root + 12 + semis), length * beat * 1.2, 1.0), t0 + at * beat, 0.16, 0.55)
                both(arp_synth(note(root + 24 + semis), length * beat, 0.25), t0 + at * beat, 0.16, 0.55)
    return fold_loop(left, right, d)


def mall_ambience():
    """16 s seamless bed: air-con hum, the fountain, a buzzing light, a distant
    escalator and the odd clatter from the food court. Kept dark (little
    high-frequency noise) so the loop stays small."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 60 * t) * 0.5 + np.sin(2 * np.pi * 120 * t) * 0.3 + np.sin(2 * np.pi * 180 * t) * 0.1)
    air = filt(rng.uniform(-1, 1, n), low=500, high=60) * 0.8
    water_l = band(rng.uniform(-1, 1, n), 1100, 500) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 3.2) ** 2)
    water_r = band(rng.uniform(-1, 1, n), 1250, 550) * (0.6 + 0.4 * np.cos(2 * np.pi * t / 4.0) ** 2)
    buzz = filt(osc(2 * np.pi * 120 * t, "saw"), low=700) * 0.05 * (0.5 + 0.5 * (np.sin(2 * np.pi * t / 4.0) > 0.7))
    left = hum * 0.08 + air * 0.5 + water_l * 0.3 + buzz
    right = hum * 0.08 + air * 0.5 + water_r * 0.3 + buzz * 0.6
    # The escalator: a slow rhythmic rumble of steps.
    steps = filt(rng.uniform(-1, 1, n), low=240) * (0.5 + 0.5 * np.sin(2 * np.pi * t * 1.25)) ** 4 * 0.5
    right += steps * 0.6
    left += steps * 0.3
    # Distant clatter: a dropped tray, a rolling cup.
    for at, pitch in ((4.5, 900), (11.0, 700)):
        hit = band(noise(0.35), pitch * 2, pitch) * env(0.35, 0.001, 0.25, power=1.8)
        place(left, hit, at, 0.06)
        place(right, hit, at + 0.03, 0.04)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Mall Walker
# ---------------------------------------------------------------------------

def mall_walker_huff_1():
    """Out of breath: a rhythmic huffing groan."""
    d = 0.8
    g = groan(150, d, glide=0.15, formants=((620, 160), (1500, 260)), rasp=0.35, wobble=0.06)
    puff = (np.sin(2 * np.pi * 5.0 * t_axis(d)) > 0.0).astype(float)
    return g * (0.55 + 0.45 * puff) + band(noise(d), 1800, 1200) * puff * 0.15 * env(d, 0.05, d, power=0.8)


def mall_walker_huff_2():
    return groan(175, 0.6, glide=-0.3, formants=((700, 180), (1700, 300)), rasp=0.4, wobble=0.08)


def mall_walker_whistle():
    """The burst tell: two sharp coach-whistle trills and a sneaker squeak."""
    d = 0.7
    out = silence(d)
    for at, ln in ((0.0, 0.16), (0.22, 0.3)):
        trill = 1.0 + 0.5 * (np.sin(2 * np.pi * 34 * t_axis(ln)) > 0)
        w = tone(2900, ln, "sine") * trill * env(ln, 0.005, ln, power=0.6, release=0.03)
        w += band(noise(ln), 2900, 500) * 0.3 * env(ln, 0.005, ln, power=0.8)
        place(out, w, at, 0.7)
    squeak = sweep(1400, 2300, 0.12, "sine") * env(0.12, 0.003, 0.1, power=1.0)
    place(out, squeak, 0.58, 0.5)
    return out


def mall_walker_burst():
    """The burst: fast sneaker squeaks over a whoosh."""
    d = 0.95
    out = band(noise(d), 900, 600) * env(d, 0.05, d, power=0.8, release=0.25) * 0.6
    for k in range(5):
        at = 0.05 + k * 0.16
        place(out, sweep(1500 + 200 * (k % 2), 2400, 0.08, "sine") * env(0.08, 0.002, 0.07, power=1.0), at, 0.35)
    return out


# ---------------------------------------------------------------------------
# Food Court Flinger
# ---------------------------------------------------------------------------

def mall_flinger_groan_1():
    return groan(105, 0.9, glide=-0.2, formants=((560, 140), (1200, 200)), rasp=0.3, wobble=0.05)


def mall_flinger_groan_2():
    """A groan that rises like an order call."""
    return groan(120, 0.8, glide=0.4, formants=((640, 160), (1350, 220)), rasp=0.35, wobble=0.07)


def mall_soda_shake():
    """The lob tell: ice rattling in a big cup and a rising fizz."""
    d = 0.9
    out = silence(d)
    for _ in range(18):
        at = rng.uniform(0.0, 0.7)
        place(out, band(noise(0.03), rng.uniform(2500, 4500), 800) * env(0.03, 0.0005, power=2.0), at, rng.uniform(0.3, 0.6))
    fizz = filt(noise(d), high=5000) * env(d, 0.3, d * 1.2, power=0.6, release=0.1)
    return out + fizz * 0.35


def mall_soda_throw():
    """A grunt and the whoosh of the cup leaving the hand."""
    d = 0.55
    out = band(noise(d), 800, 500) * env(d, 0.04, 0.3, power=1.0) * 1.3
    place(out, groan(130, 0.3, glide=-0.3, formants=((600, 150), (1250, 200)), rasp=0.4), 0.0, 0.5)
    return out


def mall_soda_splash():
    """The cup bursts: a wet slap and a fizzing hiss."""
    d = 0.8
    slap = band(noise(0.12), 900, 700) * env(0.12, 0.001, 0.1, power=1.5)
    fizz = filt(noise(d), high=4200) * env(d, 0.01, d, power=1.2)
    bubbles = sum(tone(rng.uniform(900, 2200), 0.05, "sine") * env(0.05, 0.002, power=2.0) for _ in range(1))
    out = fizz * 0.6
    place(out, slap, 0.0, 1.2)
    for _ in range(14):
        place(out, bubbles * 0.5, rng.uniform(0.05, 0.6), rng.uniform(0.15, 0.35))
    return out


# ---------------------------------------------------------------------------
# The Night Manager
# ---------------------------------------------------------------------------

def mall_manager_grunt_1():
    return groan(72, 0.8, glide=-0.2, formants=((380, 110), (800, 160)), rasp=0.5, wobble=0.05)


def mall_manager_grunt_2():
    return groan(64, 1.0, glide=0.15, formants=((350, 100), (740, 150)), rasp=0.55, wobble=0.06)


def mall_manager_whistle():
    """The Manager's burst tell: the store PA's two-note chime, then a growl."""
    d = 1.15
    out = silence(d)
    for at, s in ((0.0, 7), (0.32, 3)):
        ding = sum(tone(note(s) * r, 0.7, "sine") * env(0.7, 0.002, 0.6, power=1.8) * a for r, a in ((1.0, 1.0), (2.0, 0.3), (3.01, 0.12)))
        place(out, ding, at, 0.5)
    place(out, groan(70, 0.5, glide=0.3, formants=((380, 110), (800, 160)), rasp=0.6), 0.65, 0.6)
    return out


# ---------------------------------------------------------------------------
# Power cut
# ---------------------------------------------------------------------------

def mall_power_down():
    """The mains trip: a heavy breaker clunk, the hum dying away, a few pops."""
    d = 1.4
    out = silence(d)
    place(out, clunk(80, 0.35, 1.0), 0.0, 1.2)
    t = t_axis(d)
    f = 120 * np.exp(-t * 2.2) + 25
    hum = osc(2 * np.pi * np.cumsum(f) / SR, "saw") * env(d, 0.005, d, power=0.8)
    out += filt(hum, low=900) * 0.35
    for at in (0.15, 0.4, 0.55, 0.9):
        place(out, filt(noise(0.04), high=3000) * env(0.04, 0.0005, power=2.0), at, 0.3)
    return out


def mall_power_up():
    """Power back: a clunk, the hum swelling and the lights ticking on."""
    d = 1.2
    out = silence(d)
    place(out, clunk(110, 0.3, 1.0), 0.0, 1.0)
    t = t_axis(d)
    f = 30 + 90 * (1 - np.exp(-t * 3.0))
    hum = osc(2 * np.pi * np.cumsum(f) / SR, "saw") * env(d, 0.4, d, power=0.8, release=0.4)
    out += filt(hum, low=900) * 0.3
    for k in range(6):
        place(out, tone(2400 + 300 * k, 0.04, "sine") * env(0.04, 0.001, power=2.0), 0.25 + k * 0.1, 0.25)
    return out


SOUNDS = [
    mall_walker_huff_1, mall_walker_huff_2, mall_walker_whistle, mall_walker_burst,
    mall_flinger_groan_1, mall_flinger_groan_2, mall_soda_shake, mall_soda_throw, mall_soda_splash,
    mall_manager_grunt_1, mall_manager_grunt_2, mall_manager_whistle, mall_power_down, mall_power_up,
]

VARIANTS = [(mall_walker_huff_1, (0.92, 1.1))]

LOOPS = {}

MUSIC = {
    "midnight_mall_loop": midnight_mall_loop,
    "midnight_mall_final": lambda: midnight_mall_loop(intense=True),
    "mall_ambience": mall_ambience,
}
