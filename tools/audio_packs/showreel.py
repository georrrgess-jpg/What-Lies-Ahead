"""The trailer (showreel) track and the startup score.

    python tools/gen_audio.py showreel

showreel_trailer: 72 s at 120 BPM (one bar = 2 s), A minor, written against the
shot list in docs/SHOWREEL.md. Every cut lands on a bar or a beat:

     0-12  cold open  warm and low, building slowly: a soft pad fades up from
                      silence with sea wind and a distant carnival organ; a deep
                      heartbeat from 4 s, doubling at 9; a low swell and a breath
                      before 12. No chimes, cymbals, noise sweeps or clicks:
                      nothing above the bed, nothing bright (see _intro)
    12     BOOM       the title: a sub drop, a dark thump, a low brass chord
    16-26  build      the beat comes in under the world tour; a whoosh and a low
                      tom on each whip pan (18, 20, 22), a boom for the yeti (24)
    26-28  breath     the horde in slow motion: bass pulse and a riser only
    28     DROP       the kills: full beat, gallop bass, lead, claps
    42     shift      the arsenal: arp on top, a soft tom per weapon 42-46
    54     lift       operators
    62     HIT        the final title card, pad and tail
    66     HIT        "PLAY NOW", decaying to silence at 72

cine_startup: the 8.5 s startup screen (scripts/ui/intro_overlay.gd), in the
same voice: a pad and the distant organ rise from silence, four soft low
pulses under the montage cuts (1.4 / 2.2 / 3.0 / 3.8), the low boom and a warm
chord for the logo at 4.6, three soft plucks as the feature chips land.
"""
from gen_audio import *  # noqa: F401,F403

BPM = 120.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
LENGTH = 72.0
TITLE = 12.0
DROP_AT = 28.0

# Chord roots in semitones from A4 with their triads.
AM, F, C, G, EM, DM, E = (-12, (0, 3, 7)), (-16, (0, 4, 7)), (-9, (0, 4, 7)), (-14, (0, 4, 7)), (-17, (0, 3, 7)), (-19, (0, 3, 7)), (-17, (0, 4, 7))
BUILD = [AM, F, C, G]
DROP = [AM, F, C, G, F, G, EM, AM]
# The distant organ's waltz (semitones from A4, beats).
WALTZ = [(7, 1), (3, 0.5), (0, 0.5), (2, 1), (-1, 1), (0, 1.5), (-5, 0.5), (0, 1), (3, 1), (7, 1), (12, 1.5), (10, 0.5),
         (8, 1), (7, 1), (3, 1), (5, 1), (2, 1), (-1, 1)]


def _kick():
    k = sweep(150, 42, 0.22, "sine", 0.5) * env(0.22, 0.001, power=2.0)
    place(k, kick_click(0.25), 0.0)
    return k


def _snare():
    return (filt(noise(0.16), high=1500, low=7000) * 0.8 + tone(190, 0.16) * 0.4) * env(0.16, 0.001, power=2.2)


def _hat(open_hat=False):
    d = 0.2 if open_hat else 0.05
    return filt(noise(d), high=6800, low=11000) * env(d, 0.0005, power=1.5 if open_hat else 2.5)


def _soft_crash(d=1.6):
    """A darker crash than the core cymbal: band-limited, slower attack."""
    n = noise(d)
    return filt(n, high=2500, low=7000) * env(d, 0.006, d, power=2.8)


def _boom(d=2.4):
    """The cut-on hit for the drop and the end card: sub drop, thump, a dark crash."""
    out = silence(d)
    place(out, sweep(95, 28, 1.6, "sine", 0.35) * env(1.6, 0.002, 1.4, power=1.4), 0.0, 1.4)
    place(out, filt(noise(0.5), low=1800) * env(0.5, 0.002, 0.3, power=2.0), 0.0, 0.6)
    place(out, _soft_crash(d) * 0.5, 0.0, 1.0)
    return out


def _low_boom(d=4.0):
    """A cinematic low boom: a sub drop with a soft attack, a dark thump and
    a long body. Nothing above ~600 Hz."""
    out = silence(d)
    place(out, sweep(68, 29, d, "sine", 0.4) * env(d, 0.012, d * 0.9, power=1.6), 0.0, 1.3)
    place(out, sweep(110, 45, 0.6, "sine", 0.6) * env(0.6, 0.008, 0.5, power=2.0), 0.0, 0.6)
    place(out, filt(noise(1.2), low=240) * env(1.2, 0.015, 1.0, power=2.2), 0.0, 1.6)
    return out


def _tom(pitch, d=0.35):
    return sweep(pitch, pitch * 0.5, d, "sine", 0.6) * env(d, 0.003, power=1.8)


def _whoosh(d=0.45):
    """A whip-pan swish: noise through a band sliding up and back down, soft edges."""
    n = noise(d)
    t = t_axis(d)
    lo = filt(n, low=700, high=180)
    hi = filt(n, low=1800, high=500)
    k = np.sin(np.pi * t / d) ** 2
    return (lo * (1 - k) + hi * k) * k * 0.9


def _brass(root, triad, d, gain=1.0, cutoff=2800, attack=0.01):
    out = silence(d)
    for s in triad:
        f = note(root + 12 + s)
        x = tone(f, d, "saw") + tone(f * 1.007, d, "saw") * 0.8
        place(out, filt(x, low=cutoff) * env(d, attack, d * 0.8, sustain=0.3, power=1.2, release=0.08), 0.0, gain)
    return out


def _pad(root, triad, d, cutoff=900, attack=1.5, release=1.0):
    """A warm pad: three detuned saws per note, low-passed, slow in and out."""
    x = silence(d)
    for s in triad:
        f = note(root + s)
        for detune in (0.996, 1.0, 1.004):
            x += tone(f * detune, d, "saw", 0.002, 0.3)
    shape = np.minimum(np.clip(t_axis(d) / attack, 0, 1), np.clip((d - t_axis(d)) / release, 0, 1)) ** 1.5
    return filt(x, low=cutoff) * shape / 9.0


def _distant(x):
    """Far away: high frequencies gone and a smear of early reflections."""
    x = filt(x, low=1500, high=150)
    out = x * 0.35
    for d, g in ((0.031, 0.5), (0.053, 0.42), (0.089, 0.36), (0.137, 0.3), (0.211, 0.24), (0.33, 0.18), (0.47, 0.12)):
        i = int(d * SR)
        out[i:] += x[:-i] * g
    return out


def _organ(d, start_beat=0.0):
    """The carnival's band organ, playing a slow waltz a long way off."""
    out = silence(d)
    at = 0.0
    i = int(start_beat)
    while at < d:
        semis, beats = WALTZ[i % len(WALTZ)]
        ln = beats * BEAT * 1.5
        f = note(semis)
        x = tone(f, ln, "tri", 0.006, 5.5) + tone(f * 2, ln, "sine", 0.006, 5.5) * 0.35
        place(out, x * env(ln, 0.02, ln * 1.1, power=0.9), at, 0.5)
        # Oom-pah-pah under it.
        if i % 2 == 0:
            place(out, tone(note(semis - 24), BEAT, "tri") * env(BEAT, 0.01, BEAT * 0.8, power=1.5), at, 0.3)
        at += ln
        i += 1
    wow = 1.0 + 0.15 * np.sin(2 * np.pi * 0.23 * t_axis(d))
    return _distant(out * wow)


def _sea(d):
    """Wind and surf: low noise breathing slowly."""
    t = t_axis(d)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 6.5) ** 2
    return filt(noise(d), low=420, high=60) * swell


def _heartbeat():
    """A deep, soft double pulse (no click)."""
    out = silence(0.7)
    beat = sweep(62, 40, 0.35, "sine", 0.6) * env(0.35, 0.012, 0.32, power=1.6)
    place(out, beat, 0.0, 1.0)
    place(out, beat, 0.27, 0.6)
    return out


def _intro(left, right):
    """0-12: the cold open. Low, warm and slowly building."""
    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    fade_in = lambda x, secs: x * np.clip(t_axis(len(x) / SR) / secs, 0, 1) ** 2  # noqa: E731
    both(fade_in(_sea(TITLE + 1.0), 3.0), 0.0, 0.16, 0.45)
    both(fade_in(_organ(TITLE - 0.2), 2.5) * np.clip((TITLE - 0.3 - t_axis(TITLE - 0.2)) / 3.0, 0.15, 1.0), 0.0, 0.2, 0.62)
    # Pads: A minor, then F, then E for the tension into the title.
    both(_pad(*AM, 6.5, cutoff=700, attack=3.0), 0.0, 0.55)
    both(_pad(*F, 3.5, cutoff=800, attack=0.8), 6.0, 0.55)
    swell = _pad(*E, 3.2, cutoff=1100, attack=2.6, release=0.15)
    both(swell, 8.8, 0.7)
    both(filt(noise(3.2), low=500, high=80) * np.clip(t_axis(3.2) / 3.0, 0, 1) ** 3 * np.clip((3.2 - t_axis(3.2)) / 0.15, 0, 1), 8.8, 0.35)
    # The heartbeat: once a second from 4 s, twice a second from 9 s, growing.
    hb = _heartbeat()
    at = 4.0
    while at < TITLE - 0.4:
        g = 0.25 + 0.5 * (at - 4.0) / (TITLE - 4.0)
        both(hb, at, g)
        at += 1.0 if at < 9.0 else 0.5
    # A low bass drone under it all.
    drone = sum(tone(note(r), TITLE, "sine") for r in (-36, -24)) * 0.5
    both(drone * np.clip(t_axis(TITLE) / 5.0, 0, 1) * np.clip((TITLE - t_axis(TITLE)) / 0.3, 0, 1), 0.0, 0.18)


def showreel_trailer():
    n = LENGTH + 3.0
    left, right = silence(n), silence(n)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick, snare, hat, ohat, hand_clap = _kick(), _snare(), _hat(), _hat(True), clap()
    boom = _boom()

    _intro(left, right)
    # The cold open sits well under the rest and grows into the title; the
    # bed dips for a breath in the last quarter second before the boom.
    t = t_axis(TITLE)
    level = np.interp(t, (0.0, 6.0, TITLE - 0.3, TITLE), (0.5, 0.55, 0.85, 0.2))
    left[: len(t)] *= level
    right[: len(t)] *= level

    # 12: the title boom and a long low chord under the crane.
    both(_low_boom(), TITLE, 1.0)
    both(_brass(-24, (0, 7, 12), 3.6, cutoff=900, attack=0.08), TITLE, 0.3)
    both(_pad(*AM, 4.4, cutoff=1200, attack=0.4, release=0.8), TITLE, 0.6)
    for b in range(4):
        both(_heartbeat(), TITLE + 2.0 + b * BEAT, 0.35)

    # Whip pans in the world tour, the yeti, the breath before the drop.
    for at in (18.0, 20.0, 22.0):
        both(_whoosh(), at - 0.22, 0.5, 0.3 + 0.2 * ((at - 18.0) / 2.0))
        both(_tom(110), at, 0.45)
    both(_low_boom(2.4), 24.0, 0.7)
    both(_whoosh(0.4), 53.8, 0.45, 0.4)
    both(_whoosh(0.4), 59.8, 0.45, 0.6)
    both(riser(2.0) * 0.8, 26.0, 0.3, 0.55)
    for s in range(8):
        both(snare, 27.0 + s * BEAT * 0.25, 0.05 + 0.015 * s)
    for b in range(4):
        both(_heartbeat(), 26.0 + b * BEAT, 0.5)

    # Hits that the cuts land on.
    for at, g in ((DROP_AT, 1.0), (62.0, 0.95), (66.0, 0.8)):
        both(boom, at, g)
        both(_low_boom(3.0), at, 0.5)
    both(_brass(-12, (0, 3, 7), 2.6), 62.0, 0.2)
    both(_brass(-9, (0, 4, 7), 3.6), 66.0, 0.2)
    for b in range(8):
        both(_tom(140), 42.0 + b * BEAT, 0.16, 0.3 + 0.05 * b)

    # Groove: build (16-26), breath (26-28), drop (28-62).
    for bar in range(8, 31):
        t0 = bar * BAR
        if 26.0 <= t0 < DROP_AT:
            root, triad = E
            pad = _pad(root, triad, BAR, cutoff=900, attack=0.5, release=0.2)
            both(pad, t0, 0.5)
            continue
        drop = t0 >= DROP_AT
        root, triad = (DROP[(bar - 14) % 8] if drop else BUILD[(bar - 8) % 4])
        if drop and bar % 4 == 2:
            both(_soft_crash(1.4), t0, 0.12, 0.4)
        for b in range(4):
            both(kick, t0 + b * BEAT, 0.5 if drop or t0 >= 18.0 else 0.3 + 0.1 * b)
            if drop and b in (1, 3):
                both(snare, t0 + b * BEAT, 0.28)
                both(hand_clap, t0 + b * BEAT, 0.14, 0.45)
            if drop or t0 >= 20.0:
                for h in range(4 if drop else 2):
                    both(hat, t0 + (b + h / (4.0 if drop else 2.0)) * BEAT, 0.06 + (0.05 if h % 2 else 0.0), 0.62)
            if drop:
                both(ohat, t0 + (b + 0.5) * BEAT, 0.04, 0.7)
        steps = 16 if drop else 8
        for e in range(steps):
            octave = (e % 4 == 2) if drop else (e % 2 == 1)
            ln = BAR / steps * 0.95
            x = tone(note(root - 12 + (12 if octave else 0)), ln, "tri") * env(ln, 0.004, ln * 1.2, power=1.0)
            both(audible_bass(x), t0 + e * BAR / steps, 0.4)
        pad = sum(tone(note(root + s), BAR, "saw", 0.003, 4.0) for s in triad)
        both(filt(pad, low=1600 if drop else 900) * env(BAR, 0.3, BAR * 2, power=0.5, release=0.3), t0, 0.05)
        if t0 >= 20.0:
            arp_steps = 16 if t0 >= 42.0 else 8
            for e in range(arp_steps):
                semis = triad[e % 3] + (12 if (e // 3) % 2 else 0)
                ln = BAR / arp_steps * 0.8
                x = tone(note(root + 12 + semis), ln, "square") * env(ln, 0.003, BEAT * 0.4, power=1.4)
                both(filt(x, low=3500), t0 + e * BAR / arp_steps, 0.06, 0.25 + 0.5 * (e % 2))
        if drop and bar % 2 == 0:
            phrase = [(7, 0.0, 1.0), (12, 1.0, 0.5), (10, 1.5, 0.5), (7, 2.0, 1.0), (3, 3.0, 1.0)] if bar % 4 == 2 \
                else [(5, 0.0, 1.0), (7, 1.0, 1.0), (12, 2.0, 2.0)]
            for semis, at, length in phrase:
                ln = length * BEAT * 0.95
                x = tone(note(semis), ln, "saw", 0.006, 5.5) * env(ln, 0.01, length * BEAT * 1.4, power=0.8, release=0.05)
                both(filt(x, low=3000), t0 + at * BEAT, 0.11, 0.55)
    # Outro pad under the title card.
    tail = sum(tone(note(r), 10.0, "saw", 0.003, 4.0) for r in (-12, -5, 0, 3)) * env(10.0, 0.4, 7.0, power=0.6, release=1.0)
    both(filt(tail, low=1800), 62.0, 0.07)
    stereo = np.stack([left, right], axis=1)
    fade_out = np.clip((LENGTH + 0.3 - t_axis(n)) / 3.5, 0.0, 1.0)[:, None]
    return (stereo * fade_out)[: int(LENGTH * SR)]


def cine_startup():
    """The startup screen's score (mono one-shot): warm, low, building."""
    d = 8.5
    out = silence(d)
    t = t_axis(d)
    place(out, _sea(d) * np.clip(t / 1.5, 0, 1), 0.0, 0.12)
    place(out, _organ(4.8) * np.clip(t_axis(4.8) / 1.0, 0, 1) * np.clip((4.8 - t_axis(4.8)) / 0.4, 0, 1), 0.0, 0.22)
    place(out, _pad(*AM, 3.2, cutoff=700, attack=1.0), 0.0, 0.5)
    place(out, _pad(*E, 1.6, cutoff=1000, attack=1.2, release=0.1), 3.0, 0.55)
    for i, at in enumerate((1.4, 2.2, 3.0, 3.8)):
        place(out, _heartbeat(), at, 0.45 + 0.1 * i)
        place(out, _tom(90 - 6 * i, 0.5), at, 0.35)
    place(out, _low_boom(3.9), 4.6, 1.0)
    place(out, _brass(-24, (0, 7, 12), 2.4, cutoff=1000, attack=0.06), 4.6, 0.35)
    for i, at in enumerate((5.6, 6.1, 6.6)):
        f = note(-12 + (0, 3, 7)[i])
        pluck = (tone(f, 0.5, "sine") + tone(f * 2, 0.5, "sine") * 0.3) * env(0.5, 0.004, 0.45, power=2.0)
        place(out, pluck, at, 0.25)
    chord = _pad(-12, (0, 7, 12, 15), 2.4, cutoff=1400, attack=0.4, release=0.8)
    place(out, chord, 6.1, 0.5)
    return out


SOUNDS = [cine_startup]
LOOPS = {}
MUSIC = {"showreel_trailer": showreel_trailer}
