"""The trailer (showreel) track and the startup sting.

    python tools/gen_audio.py showreel

showreel_trailer: 70 s at 120 BPM (one bar = 2 s), A minor, written against the
shot list in docs/SHOWREEL.md. Every cut lands on a bar or a beat:

     0-8   intro   drone, heartbeat kick, a Spark chime at 6, reverse swell
     8     HIT     the title slam (boom, crash, brass stab)
     8-26  build   four-on-the-floor from 10, a hit every bar (world tour,
                   then the cast), riser and snare roll 22-26
    26     DROP    the kills: full beat, gallop bass, lead, claps
    40     shift   the arsenal: same groove, arp on top, a hit every beat 40-44
    48     lift    operators, then Sparks and progression
    62     HIT     the final title card, pad and tail
    66     HIT     "PLAY NOW", decaying to silence at 70

cine_startup: the 8.5 s startup sequence (scripts/ui/intro_overlay.gd): a boot
sting, four montage hits at 1.4 / 2.2 / 3.0 / 3.8, the logo slam at 4.6, three
feature ticks and a held chord.
"""
from gen_audio import *  # noqa: F401,F403

BPM = 120.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
LENGTH = 70.0

# Chord roots in semitones from A4 with their triads.
AM, F, C, G, EM, DM = (-12, (0, 3, 7)), (-16, (0, 4, 7)), (-9, (0, 4, 7)), (-14, (0, 4, 7)), (-17, (0, 3, 7)), (-19, (0, 3, 7))
BUILD = [AM, F, C, G]
DROP = [AM, F, C, G, F, G, EM, AM]


def _kick():
    k = sweep(150, 42, 0.22, "sine", 0.5) * env(0.22, 0.001, power=2.0)
    place(k, kick_click(0.4), 0.0)
    return k


def _snare():
    return (filt(noise(0.16), high=1500) * 0.8 + tone(190, 0.16) * 0.4) * env(0.16, 0.001, power=2.2)


def _hat(open_hat=False):
    d = 0.2 if open_hat else 0.05
    return filt(noise(d), high=6800) * env(d, 0.0005, power=1.5 if open_hat else 2.5)


def _boom(d=2.4):
    """The cut-on hit: a sub drop, a noise slam and a metallic tail."""
    out = silence(d)
    place(out, sweep(95, 28, 1.6, "sine", 0.35) * env(1.6, 0.002, 1.4, power=1.4), 0.0, 1.4)
    place(out, filt(noise(0.5), low=3000) * env(0.5, 0.001, 0.3, power=2.0), 0.0, 0.7)
    place(out, cymbal(d) * 0.5, 0.0, 1.0)
    return out


def _tom(pitch):
    return sweep(pitch, pitch * 0.5, 0.35, "sine", 0.6) * env(0.35, 0.001, power=1.8)


def _brass(root, triad, d, gain=1.0):
    out = silence(d)
    for s in triad:
        f = note(root + 12 + s)
        x = tone(f, d, "saw") + tone(f * 1.007, d, "saw") * 0.8
        place(out, filt(x, low=2800) * env(d, 0.01, d * 0.8, sustain=0.3, power=1.2, release=0.08), 0.0, gain)
    return out


def _chime(at_note, d=1.4):
    out = silence(d)
    for ratio, g, decay in ((1.0, 1.0, 0.9), (2.0, 0.5, 0.5), (2.76, 0.35, 0.35), (5.4, 0.2, 0.18)):
        place(out, tone(note(at_note) * ratio, d, "sine") * env(d, 0.002, d * decay, power=1.8) * g, 0.0)
    return out


def _reverse_swell(d):
    t = t_axis(d)
    x = filt(noise(d), high=900) * (t / d) ** 3
    x += tone(note(-24), d, "saw") * (t / d) ** 2 * 0.15
    return x * np.clip((d - t) / 0.01, 0.0, 1.0)


def showreel_trailer():
    n = LENGTH + 3.0
    left, right = silence(n), silence(n)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick, snare, hat, ohat, hand_clap = _kick(), _snare(), _hat(), _hat(True), clap()
    boom = _boom()

    # Intro: drone and heartbeat, the Spark chime, the swell into the title.
    drone = sum(tone(note(r), 8.0, "saw", 0.003, 0.3) for r in (-36, -24, -17)) * env(8.0, 2.0, 12.0, power=0.5, release=0.3)
    both(filt(drone, low=500), 0.0, 0.12)
    for b in range(4):
        both(kick, b * BAR, 0.32)
        both(kick, b * BAR + 0.28, 0.18)
    both(_chime(15), 5.0, 0.18, 0.6)
    both(_chime(22, 1.8), 6.5, 0.12, 0.4)
    both(_reverse_swell(2.0), 6.0, 0.45)

    # Hits that the cuts land on.
    for at, g in ((8.0, 0.9), (62.0, 0.95), (66.0, 0.8)):
        both(boom, at, g)
    both(_brass(-12, (0, 7, 12), 1.4), 8.0, 0.22)
    both(_brass(-12, (0, 3, 7), 2.6), 62.0, 0.2)
    both(_brass(-9, (0, 4, 7), 3.6), 66.0, 0.2)
    for i, at in enumerate((10.0, 12.0, 14.0, 16.0, 18.0)):
        both(_tom(130 - i * 8), at, 0.5)
        both(cymbal(0.9) * 0.6, at, 0.3, 0.3 + 0.1 * i)
    for at in (20.0, 22.0, 24.0):
        both(boom, at, 0.45)
    both(riser(4.0), 22.0, 0.35, 0.55)
    for s in range(16):
        both(snare, 24.0 + s * BEAT * 0.25, 0.08 + 0.015 * s)
    both(boom, 26.0, 1.0)
    for b in range(8):
        both(_tom(150), 40.0 + b * BEAT, 0.2, 0.3 + 0.05 * b)

    # Groove: build (10-26), drop (26-62).
    for bar in range(5, 31):
        t0 = bar * BAR
        drop = t0 >= 26.0
        root, triad = (DROP[(bar - 13) % 8] if drop else BUILD[(bar - 5) % 4])
        if t0 >= 24.0 and t0 < 26.0:
            continue
        if drop and bar % 4 == 1:
            both(cymbal(1.4), t0, 0.12, 0.4)
        for b in range(4):
            both(kick, t0 + b * BEAT, 0.5)
            if drop and b in (1, 3):
                both(snare, t0 + b * BEAT, 0.28)
                both(hand_clap, t0 + b * BEAT, 0.16, 0.45)
            for h in range(4 if drop else 2):
                both(hat, t0 + (b + h / (4.0 if drop else 2.0)) * BEAT, 0.08 + (0.06 if h % 2 else 0.0), 0.62)
            if drop:
                both(ohat, t0 + (b + 0.5) * BEAT, 0.05, 0.7)
        steps = 16 if drop else 8
        for e in range(steps):
            octave = (e % 4 == 2) if drop else (e % 2 == 1)
            ln = BAR / steps * 0.95
            x = tone(note(root - 12 + (12 if octave else 0)), ln, "tri") * env(ln, 0.004, ln * 1.2, power=1.0)
            both(audible_bass(x), t0 + e * BAR / steps, 0.4)
        pad = sum(tone(note(root + s), BAR, "saw", 0.003, 4.0) for s in triad)
        both(filt(pad, low=1600 if drop else 900) * env(BAR, 0.3, BAR * 2, power=0.5, release=0.3), t0, 0.05)
        arp_steps = 16 if t0 >= 40.0 else 8
        for e in range(arp_steps):
            semis = triad[e % 3] + (12 if (e // 3) % 2 else 0)
            ln = BAR / arp_steps * 0.8
            x = tone(note(root + 12 + semis), ln, "square") * env(ln, 0.003, BEAT * 0.4, power=1.4)
            both(filt(x, low=5000), t0 + e * BAR / arp_steps, 0.07, 0.25 + 0.5 * (e % 2))
        if drop and bar % 2 == 1:
            phrase = [(7, 0.0, 1.0), (12, 1.0, 0.5), (10, 1.5, 0.5), (7, 2.0, 1.0), (3, 3.0, 1.0)] if bar % 4 == 1 \
                else [(5, 0.0, 1.0), (7, 1.0, 1.0), (12, 2.0, 2.0)]
            for semis, at, length in phrase:
                ln = length * BEAT * 0.95
                x = tone(note(semis), ln, "saw", 0.006, 5.5) * env(ln, 0.01, length * BEAT * 1.4, power=0.8, release=0.05)
                both(filt(x, low=3400), t0 + at * BEAT, 0.11, 0.55)
    # Outro pad under the title card.
    tail = sum(tone(note(r), 8.0, "saw", 0.003, 4.0) for r in (-12, -5, 0, 3)) * env(8.0, 0.4, 5.0, power=0.6, release=1.0)
    both(filt(tail, low=1800), 62.0, 0.07)
    stereo = np.stack([left, right], axis=1)
    fade_out = np.clip((LENGTH + 0.5 - t_axis(n)) / 3.5, 0.0, 1.0)[:, None]
    return (stereo * fade_out)[: int(LENGTH * SR)]


def cine_startup():
    """The startup sequence's own score (mono one-shot)."""
    d = 8.5
    out = silence(d)
    place(out, click(0.02, 3200), 0.0, 0.8)
    place(out, sweep(80, 1800, 0.6, "sine", 2.5) * env(0.6, 0.01, 0.7, power=0.7) * 0.3, 0.02)
    place(out, _chime(19, 1.2), 0.35, 0.35)
    place(out, _reverse_swell(1.0), 0.4, 0.4)
    for i, at in enumerate((1.4, 2.2, 3.0, 3.8)):
        place(out, _tom(140 - 12 * i), at, 0.7)
        place(out, filt(noise(0.25), low=4000) * env(0.25, 0.001, 0.2, power=2.0), at, 0.4)
        place(out, _kick(), at, 0.6)
    place(out, riser(0.8), 3.8, 0.5)
    boom = _boom(3.0)
    place(out, boom[: len(boom)], 4.6, 1.0)
    place(out, _brass(-12, (0, 7, 12), 1.6), 4.6, 0.35)
    for i, at in enumerate((5.6, 6.1, 6.6)):
        place(out, blip(note(12 + 5 * i), 0.12, "square", 0.1), at, 0.25)
        place(out, _kick(), at, 0.3)
    chord = sum(tone(note(r), 2.0, "saw", 0.003, 4.0) for r in (-12, -5, 0, 4)) * env(2.0, 0.2, 2.0, power=0.6, release=0.4)
    place(out, filt(chord, low=1800), 6.5, 0.12)
    return out


SOUNDS = [cine_startup]
LOOPS = {}
MUSIC = {"showreel_trailer": showreel_trailer}
