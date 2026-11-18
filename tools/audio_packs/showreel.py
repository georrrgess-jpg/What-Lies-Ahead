"""The trailer score and the startup score.

    python tools/gen_audio.py showreel --music     (the trailer; drop --music to also write cine_startup)

showreel_trailer: "What Lies Ahead", a 56.0 s trailer cue plus a 2.5 s
ring-out (58.5 s) at 120 BPM (a beat is 0.5 s, a bar 2.0 s), written to the
locked cue sheet of the in-engine trailer: every hit's transient starts on its
mark's sample. It is the game's own tune: the menu theme's hook (menu.HOOK,
A-D-F#-E-D-E) in D minor for the cold open, the groove and the drop, and in
D major for the finale. The arrangement is data (HARMONY, the melodies, the
drum patterns, HITS); the instruments and the studio are in _trailer_kit.py.

     0.0  cold open  wind and a low drone from silence; the hook on a detuned
                     music box running down; a heartbeat sub on the beats from 3.0
     5.0  flashes    a taiko + struck metal on every flash, string tremolo
                     climbing, a riser; 7.0 a reversed choir + cymbal swell
                     sucks into dead silence at 7.5
     8.0  LOGO SLAM  impact (sub drop, body, metal, crack, rumble), brass +
                     choir on D minor, glockenspiel bulbs snapping on
    10.0  15 worlds  the groove (Dm Gm Bb A): taiko/kick/snare, 16th gallop
                     bass, spiccato string ostinato, the hook on low brass, a
                     high string counter-melody, a clank on every cut
    17.5  stop-hit   on A; 18-22 the five alphas: impact + brass/choir stabs on
                     a climbing bass (Dm C/E F Gm A) over pounding eighths
    23.0  the cast   a sustained Bb brass/choir chord swelling, then the A
                     pedal, a riser and a snare roll; silence at 25.5 with a
                     reversed whoosh into
    26.0  THE DROP   full band: distorted bass, the hook on a supersaw lead
                     doubled by the band organ, choir, brass counter-line,
                     strings; 27.5 the WINNER hit; 29.0 RELOADS (a glint on each
                     reload's snap); 34.0 the slide's whoosh
    35.0  half-time  the band low-passed, a thud at 36.0, opening back into
    37.0  mayhem     the hook again, kills accented
    40.0  ENDLESS    double-time toms, four on the floor, the choir climbing
    44.0  stop-hit   a tension chord (D minor rubbing on E-flat), heartbeat, clock
    46.0  yours      a lighter groove: pluck + music-box arpeggio, bells on the
                     beats, the organ rising over Bb C Bb C
    50.0  FINALE     the biggest hit; the hook in D major on brass, lead, choir
                     and organ over D Bm G A, heroic half-time drums
    53.0  SLAM       the final slam on D major, ringing; the music box closes
                     the hook, a last bell and boom at 56.0 under the tagline

Mastered as a one-shot by write_music (names ending in _trailer): -14 LUFS,
sample peaks under -2 dBFS, only a 28 Hz high-pass; this pack mixes it itself
(per-bus EQ, convolution hall and room, sidechain ducking under the hits and
kicks, bus compression, mono lows, saturation).

cine_startup: the 8.5 s startup screen (scripts/ui/intro_overlay.gd), in the
menu theme's key (D major, see menu.py): a pad (Bm, then A) and the theme's
hook on a distant calliope rise from silence, four soft low pulses under the
montage cuts (1.4 / 2.2 / 3.0 / 3.8), the low boom and a D chord for the logo
at 4.6, three soft plucks (the hook's first notes) as the feature chips land,
so the menu theme starts on the chord the startup ends on.
"""
from gen_audio import *  # noqa: F401,F403
import menu


# ---------------------------------------------------------------------------
# The startup score's instruments (cine_startup)
# ---------------------------------------------------------------------------

def _sea(d):
    """Wind and surf: low noise breathing slowly."""
    t = t_axis(d)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 6.5) ** 2
    return filt(noise(d), low=420, high=60) * swell


def _distant(x):
    """Far away: high frequencies gone and a smear of early reflections."""
    x = filt(x, low=1500, high=150)
    out = x * 0.35
    for d, g in ((0.031, 0.5), (0.053, 0.42), (0.089, 0.36), (0.137, 0.3), (0.211, 0.24), (0.33, 0.18), (0.47, 0.12)):
        i = int(d * SR)
        out[i:] += x[:-i] * g
    return out


def _heartbeat():
    """A deep, soft double pulse (no click)."""
    out = silence(0.7)
    beat = sweep(62, 40, 0.35, "sine", 0.6) * env(0.35, 0.012, 0.32, power=1.6)
    place(out, beat, 0.0, 1.0)
    place(out, beat, 0.27, 0.6)
    return out


def _tom(pitch, d=0.35):
    return sweep(pitch, pitch * 0.5, d, "sine", 0.6) * env(d, 0.003, power=1.8)


def _low_boom(d=4.0):
    """A cinematic low boom: a sub drop with a soft attack, a dark thump and
    a long body. Nothing above ~600 Hz."""
    out = silence(d)
    place(out, sweep(68, 29, d, "sine", 0.4) * env(d, 0.012, d * 0.9, power=1.6), 0.0, 1.3)
    place(out, sweep(110, 45, 0.6, "sine", 0.6) * env(0.6, 0.008, 0.5, power=2.0), 0.0, 0.6)
    place(out, filt(noise(1.2), low=240) * env(1.2, 0.015, 1.0, power=2.2), 0.0, 1.6)
    return out


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




# ---------------------------------------------------------------------------
# showreel_trailer: the score. The timeline is the locked cue sheet; the
# arrangement is data (harmony, melodies, drum patterns), the instruments
# and the studio are _trailer_kit.
# ---------------------------------------------------------------------------

import _trailer_kit as K  # noqa: E402

BPM = 120.0
BEAT = 60.0 / BPM            # 0.5 s
BAR = 4 * BEAT               # 2.0 s
STEP = BEAT / 4              # a sixteenth, 0.125 s
LENGTH = 56.0                # the picture (it fades to black here)
TOTAL = 58.5                 # the file: the picture plus the ring-out
WORK = TOTAL + 3.5           # render buffer (reverb tails stay inside it)

# The locked hits (seconds) and how hard each one ducks the band under it.
HITS = ((5.0, 0.5), (8.0, 1.0), (10.0, 0.6), (17.5, 0.8), (18.0, 0.7), (19.0, 0.7), (20.0, 0.75), (21.0, 0.8),
        (22.0, 0.85), (23.0, 0.6), (26.0, 1.0), (27.5, 0.6), (29.0, 0.6), (35.0, 0.6), (36.0, 0.8), (37.0, 0.7),
        (40.0, 0.8), (44.0, 0.9), (46.0, 0.4), (50.0, 1.0), (53.0, 1.0), (56.0, 0.5))
# Before each hit the band takes a breath (seconds; 0.05 unless listed): the last slams get a real gap.
BREATH = {50.0: 0.09, 53.0: 0.13, 56.0: 0.12}
SILENT = ((7.5, 8.0), (25.5, 26.0))          # dead silence (the roar's breath, the cut before the drop)

# Chords: (bass note, chord tones as semitones above it). Semitones from A4.
CHORDS = {
    "Dm": (-31, (0, 3, 7)), "D": (-31, (0, 4, 7)), "Bb": (-35, (0, 4, 7)), "C": (-33, (0, 4, 7)),
    "Gm": (-26, (0, 3, 7)), "A": (-36, (0, 4, 7)), "Asus": (-36, (0, 5, 7)), "F": (-28, (0, 4, 7)),
    "C/E": (-29, (-4, 0, 3)), "Bm": (-34, (0, 3, 7)), "G": (-38, (0, 4, 7)),
    "Dm/Eb": (-31, (0, 3, 7, 13)),          # the Last Ride tension: D minor rubbing on E-flat
}
# The harmony of the whole cue: (start second, chord).
HARMONY = [
    (0.0, "Dm"), (10.0, "Dm"), (11.0, "Bb"), (12.0, "Dm"), (14.0, "Gm"), (15.0, "C"), (16.0, "A"),
    (18.0, "Dm"), (19.0, "C/E"), (20.0, "F"), (21.0, "Gm"), (22.0, "A"), (23.0, "Bb"), (24.0, "Asus"), (24.75, "A"),
    (26.0, "Dm"), (28.0, "Bb"), (29.0, "C"), (30.0, "Gm"), (32.0, "A"), (34.0, "Dm"), (35.0, "Bb"), (36.0, "C"),
    (37.0, "Dm"), (38.0, "C"), (39.0, "Bb"), (39.5, "A"),
    (40.0, "Gm"), (41.0, "A"), (42.0, "Bb"), (43.0, "C"), (44.0, "Dm/Eb"),
    (46.0, "Bb"), (47.0, "C"), (48.0, "Bb"), (49.0, "C"),
    (50.0, "D"), (51.0, "Bm"), (52.0, "G"), (52.5, "A"), (53.0, "D"),
]

# The motif: the menu theme's hook (menu.HOOK, one bar: semitones, beat, beats), its minor form, and the
# developments used here.
HOOK_MAJOR = [tuple(n) for n in menu.HOOK]                                   # A D F# E D E
HOOK_MINOR = [(s - 1 if s == 9 else s, b, ln) for s, b, ln in HOOK_MAJOR]    # A D F  E D E
HOOK_FROM_BB = [(1, 0, 0.5), (5, 0.5, 0.5), (10, 1, 1.5), (8, 2.5, 0.5), (7, 3, 0.5), (8, 3.5, 0.5)]   # Bb D G F E F
HOOK_HIGH = [(5, 0, 0.5), (8, 0.5, 0.5), (13, 1, 1.5), (12, 2.5, 0.5), (10, 3, 0.5), (12, 3.5, 0.5)]   # D F Bb A G A

# Melodies: (bar start second, phrase). The groove's hook is on low brass (an octave down).
GROOVE_BRASS = [(12.0, HOOK_MINOR), (14.0, HOOK_FROM_BB), (16.0, [(4, 0, 1), (7, 1, 1), (12, 2, 1)])]
GROOVE_COUNTER = [(12.0, [(8, 0, 2), (10, 2, 1), (12, 3, 1)]), (14.0, [(13, 0, 2), (15, 2, 2)]), (16.0, [(16, 0, 3)])]
DROP_LEAD = [
    (26.0, HOOK_MINOR), (28.0, [(5, 0, 1), (8, 1, 1), (7, 2, 1.5), (3, 3.5, 0.5)]),
    (30.0, HOOK_FROM_BB), (32.0, [(7, 0, 1.5), (4, 1.5, 0.5), (7, 2, 1), (12, 3, 1)]),
    (34.0, [(17, 0, 1), (15, 1, 0.5), (13, 1.5, 0.5)]),
    (37.0, HOOK_MINOR), (39.0, [(13, 0, 1), (12, 1, 1)]),
    (40.0, HOOK_MINOR), (42.0, HOOK_HIGH),
]
YOURS_ORGAN = [(46.0, [(5, 0, 1), (8, 1, 1), (7, 2, 1), (10, 3, 1)]), (48.0, [(8, 0, 1), (13, 1, 1), (12, 2, 1), (15, 3, 1)])]
FINALE_LEAD = [(50.0, HOOK_MAJOR), (52.0, [(14, 0, 1), (16, 1, 1), (17, 2, 6)])]
FINALE_COUNTER = [(50.0, [(17, 0, 2), (16, 2, 2)]), (52.0, [(17, 0, 1), (19, 1, 1), (21, 2, 5)])]

# Drum patterns: sixteenth step (0-15 in a bar) -> velocity.
GROOVE_TAIKO = {0: 1.0, 3: 0.45, 6: 0.7, 8: 0.9, 10: 0.45, 11: 0.6, 14: 0.75}
GROOVE_KICK = {0: 1.0, 7: 0.45, 8: 0.85}
GROOVE_SNARE = {4: 0.7, 12: 0.85}
DROP_KICK = {0: 1.0, 6: 0.7, 8: 1.0, 11: 0.55, 14: 0.6}
DROP_SNARE = {4: 1.0, 12: 1.0}
DROP_TAIKO = {0: 1.0, 8: 0.8, 14: 0.55}
ENDLESS_TOMS = [(150, 1.0), (150, 0.55), (115, 0.8), (150, 0.55), (90, 0.9), (115, 0.6), (150, 0.7), (90, 0.6)]
SHAKE = (0.55, 0.22, 0.38, 0.22)
# Bass ostinati: one entry per sixteenth (semitones above the chord's bass, None = rest).
GALLOP = [0, None, 0, 0, 12, None, 0, 0, 0, None, 0, 0, 12, None, 7, 12]
# String ostinato: indices into the chord's four-note voicing.
OSTINATO = [2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 3, 2, 1, 0]
ARP = [0, 1, 2, 3, 4, 3, 2, 1, 0, 2, 1, 3, 2, 4, 3, 1]


def chord_at(t):
    name = HARMONY[0][1]
    for at, ch in HARMONY:
        if at <= t + 1e-9:
            name = ch
    return name


def voicing(name, lo, hi, limit=None):
    """Every chord tone between lo and hi (semitones from A4), lowest first."""
    bass, tones = CHORDS[name]
    pcs = {(bass + s) % 12 for s in tones}
    notes = [s for s in range(lo, hi + 1) if s % 12 in pcs]
    return notes[:limit] if limit else notes


def phrase_notes(phrases, shift=0):
    """[(semis, start s, seconds)] of a list of (bar start, phrase)."""
    return [(s + shift, bar + b * BEAT, ln * BEAT) for bar, ph in phrases for s, b, ln in ph]


class Mix:
    """Stereo buses with hall and room sends."""
    BUSES = ("drums", "hits", "bass", "sub", "strings", "brass", "choir", "lead", "carnival", "fx", "breath")

    def __init__(self, seconds):
        self.n = int(SR * seconds)
        self.bus = {k: np.zeros((self.n, 2)) for k in self.BUSES}
        self.hall = np.zeros((self.n, 2))
        self.room = np.zeros((self.n, 2))
        self.kicks = []

    def add(self, bus, x, at, gain=1.0, pan=0.5, hall=0.0, room=0.0):
        x = np.asarray(x, dtype=np.float64)
        if x.ndim == 1:
            x = K.stereo(x, pan)
        i = int(round(at * SR))
        m = min(len(x), self.n - i)
        if m <= 0:
            return
        y = x[:m] * gain
        self.bus[bus][i:i + m] += y
        if hall:
            self.hall[i:i + m] += y * hall
        if room:
            self.room[i:i + m] += y * room

    def kick(self, at, vel=1.0):
        self.add("drums", K.kick(0.5, vel), at, 0.55, room=0.05)
        self.kicks.append(at)


# ---------------------------------------------------------------------------
# Parts that recur
# ---------------------------------------------------------------------------

def _hit(m, at, size=1.0, metal=150.0, crash=0.5, taiko=0.8):
    m.add("hits", K.impact(size, 5.0, metal), at, 0.62, hall=0.22)
    if crash:
        m.add("drums", K.crash(3.0, crash), at, 0.28, pan=0.6, hall=0.12)
    if taiko:
        m.add("drums", K.taiko(52, 1.6, taiko), at, 0.5, hall=0.15)
    m.kick(at, 1.0)


def _stab(m, at, name, seconds=0.9, vel=1.0, choir=True, brass_gain=0.32, choir_gain=0.5):
    """Brass + choir chord stab."""
    m.add("brass", K.brass(voicing(name, -19, -1, 5), seconds, vel=vel, attack=0.012, release=seconds * 0.6, sustain=0.45),
          at, brass_gain, hall=0.3)
    if choir:
        m.add("choir", K.choir(voicing(name, -12, 8, 5), seconds + 0.4, "ah", attack=0.02, release=0.5, singers=5),
              at, choir_gain, hall=0.35)


def _drums(m, start, bars, kick, snare, taiko=None, shaker=0.12, hats=0.0, fill=False, since=0.0, until=1e9):
    """`bars` bars of a pattern from `start`; events outside [since, until) are left out."""
    for bar in range(bars):
        t0 = start + bar * BAR
        for step in range(16):
            at = t0 + step * STEP
            if not since - 1e-6 <= at < until - 1e-6:
                continue
            if step in kick:
                m.kick(at, kick[step])
            if step in snare:
                m.add("drums", K.snare(0.45, snare[step]), at, 0.3, pan=0.47, room=0.18, hall=0.04)
            if taiko and step in taiko:
                m.add("drums", K.taiko(64 if step % 8 else 56, 1.2, taiko[step]), at, 0.38, pan=0.5, hall=0.1, room=0.1)
            if shaker:
                m.add("drums", K.shaker(0.09, SHAKE[step % 4]), at, shaker, pan=0.62, room=0.1)
            if hats:
                m.add("drums", K.hat(0.07, SHAKE[step % 4]), at, hats, pan=0.38, room=0.06)
        if fill and bar == bars - 1:
            for k in range(8):
                m.add("drums", K.tom(150 - 10 * k, 0.6, 0.5 + 0.06 * k), t0 + BAR / 2 + k * STEP, 0.3,
                      pan=0.7 - 0.05 * k, room=0.15)


def _bass_line(m, start, end, pattern, gain=0.32, grit=0.0, length=0.11, vel=1.0):
    t = start
    while t < end - 1e-6:
        step = int(round((t - start) / STEP)) % len(pattern)
        off = pattern[step]
        if off is not None:
            bass = CHORDS[chord_at(t)][0]
            body, sub = K.bass_note(bass + off, length + 0.02, vel * (1.0 if step % 4 == 0 else 0.8), 1.6, grit)
            m.add("bass", body, t, gain)
            m.add("sub", sub, t, gain * 0.9)
        t += STEP


def _ostinato(m, start, end, lo=-10, gain=0.22, vel=0.8, pattern=OSTINATO):
    t = start
    while t < end - 1e-6:
        step = int(round((t - start) / STEP))
        notes = voicing(chord_at(t), lo, lo + 15, 4)
        s = notes[pattern[step % len(pattern)] % len(notes)]
        accent = 1.0 if step % 4 == 0 else 0.75
        pan = 0.32 if step % 2 == 0 else 0.68
        m.add("strings", K.spiccato(s, 0.14, vel * accent), t, gain, pan=pan, hall=0.12, room=0.1)
        t += STEP


def _pads(m, start, end, kind, lo, hi, gain, limit=5, vowel="ah", hall=0.3):
    """Sustained chords following HARMONY between start and end."""
    edges = [t for t, _ in HARMONY if start < t < end]
    spans = list(zip([start] + edges, edges + [end]))
    for a, b in spans:
        notes = voicing(chord_at(a), lo, hi, limit)
        d = b - a + 0.5
        if kind == "choir":
            x = K.choir(notes, d, vowel, attack=0.3, release=0.5)
        elif kind == "strings":
            x = K.strings(notes, d, attack=0.35, release=0.5)
        elif kind == "tremolo":
            x = K.tremolo(notes, d, attack=0.15)
        else:
            x = K.stereo(K.brass(notes, d, vel=0.6, attack=0.12, release=0.45, sustain=0.85))
        bus = "brass" if kind == "brass" else ("choir" if kind == "choir" else "strings")
        m.add(bus, x, a, gain, hall=hall)


def _lead_phrases(m, phrases, gain=0.3, organ=0.0, shift=0):
    for bar, ph in phrases:
        beats = [(s + shift, bar / BEAT + b, ln) for s, b, ln in ph]
        x, at = K.lead(beats, BEAT, cutoff=2800)
        m.add("lead", K.haas(x, 9.0), at, gain, hall=0.18, room=0.1)
        if organ:
            for s, start, ln in phrase_notes([(bar, ph)], shift):
                m.add("carnival", K.organ(s, ln * 0.95 + 0.03), start, organ, pan=0.62, hall=0.2)


def _brass_line(m, phrases, shift=0, gain=0.3, vel=0.85):
    for s, start, ln in phrase_notes(phrases, shift):
        m.add("brass", K.brass_note(s, ln + 0.08, vel=vel, attack=0.025, release=0.12, sustain=0.8), start, gain,
              pan=0.45, hall=0.25)


def _string_line(m, phrases, gain=0.2, shift=0):
    for s, start, ln in phrase_notes(phrases, shift):
        m.add("strings", K.strings([s, s - 12], ln + 0.35, attack=0.2, release=0.35, bright=3600, players=6), start, gain,
              hall=0.3)


def _roll(m, start, end, g0=0.1, g1=0.35, accel=True):
    """A snare roll from eighths to thirty-seconds, rising."""
    t = start
    while t < end - 0.01:
        u = (t - start) / (end - start)
        m.add("drums", K.snare(0.25, 0.4 + 0.6 * u, tone=0.5), t, g0 + (g1 - g0) * u, pan=0.45, room=0.2)
        t += (0.25 if u < 0.33 else 0.125 if u < 0.7 else 0.0625) if accel else 0.0625


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

def _cold_open(m):
    """0-8: wind and drone from silence, the hook on a music box running
    down, a heartbeat on the beats, the flashes, the suck into silence."""
    w = K.wind(7.6)
    t = K.taxis(7.6)[:, None]
    m.add("fx", w * np.clip(t / 2.0, 0, 1) * (1 - 0.4 * np.clip((t - 5) / 2, 0, 1)), 0.0, 0.16, hall=0.1)
    dr = K.drone(-43, 7.6) * np.clip(K.taxis(7.6) / 2.5, 0, 1) ** 1.5
    m.add("bass", dr, 0.0, 0.32)
    m.add("strings", K.strings(voicing("Dm", -19, -7, 4), 4.6, attack=2.5, release=0.6, bright=1400), 0.6, 0.16, hall=0.4)
    # The hook on a detuned music box, slowing and sagging like a mechanism running down.
    for s, b, ln in HOOK_MINOR:
        stretch = 1.0 + 0.07 * b
        at = 0.5 + b * BEAT * stretch
        m.add("carnival", K.music_box(s + 12, 1.6, wow=-0.06 * b - 0.05), at, 0.34, pan=0.42 + 0.04 * b, hall=0.55)
    m.add("carnival", K.music_box(5 + 12, 2.0, wow=-0.4, vel=0.6), 2.95, 0.3, pan=0.6, hall=0.6)
    # Reload in the dark: the heartbeat on every beat (lub on the bar's beats, dub between).
    for i, at in enumerate((3.0, 3.5, 4.0, 4.5)):
        m.add("bass", K.heartbeat(1.0 if i % 2 == 0 else 0.7), at, 0.55)
    m.add("strings", K.tremolo(voicing("Dm", -19, -7, 3), 2.0, attack=1.6), 3.0, 0.12, hall=0.3)
    # Flashes: a drum and a strike of metal on each, the strings climbing a semitone a flash.
    for k, at in enumerate((5.0, 5.5, 6.0, 6.5)):
        m.add("drums", K.taiko(56 + 4 * k, 1.2, 0.8 + 0.07 * k), at, 0.55, hall=0.18)
        m.add("hits", K.metal(210 + 45 * k, 1.4, 0.6, 1.0), at, 0.24, pan=0.3 + 0.13 * k, hall=0.3)
        m.kick(at, 0.8)
        top = -7 + k
        m.add("strings", K.tremolo([-19, -12 + k, top, top + 3], 0.62, attack=0.04, bright=3400), at, 0.17, hall=0.3)
    m.add("fx", K.riser(2.5, top=6500), 5.0, 0.14, hall=0.1)
    # 7.0 the roar's breath: a reversed choir + brass chord and a reversed crash swell into 7.5.
    swell = K.choir(voicing("Dm", -12, 5, 5), 2.2, "ah", attack=0.01, release=1.5)
    swell[:, 0] += K.brass(voicing("Dm", -19, -7, 3), 2.2, vel=0.9, attack=0.01, release=1.5)
    swell[:, 1] += K.brass(voicing("Dm", -19, -7, 3), 2.2, vel=0.9, attack=0.01, release=1.5)
    swell = K.convolve(np.concatenate([swell, np.zeros((SR, 2))]), K.hall_ir(2.5, seed=21)) + 0.3 * np.concatenate([swell, np.zeros((SR, 2))])
    m.add("fx", K.reverse_swell(swell, 0.5), 7.0, 0.65)
    m.add("fx", K.stereo(K.reverse_cymbal(1.0)), 6.5, 0.2)


def _logo(m):
    """8.0 the slam: impact, brass and choir on D minor, bulbs snapping on."""
    _hit(m, 8.0, 1.25, 140.0, crash=0.8, taiko=1.0)
    m.add("hits", K.boom(4.0, 1.0), 8.0, 0.35)
    _stab(m, 8.0, "Dm", 2.2, 1.0, brass_gain=0.36, choir_gain=0.55)
    m.add("strings", K.tremolo(voicing("Dm", -19, 5, 6), 2.1, attack=0.02, bright=3200), 8.0, 0.14, hall=0.3)
    m.add("bass", K.drone(-31, 2.1) * np.clip((2.1 - K.taxis(2.1)) / 0.3, 0, 1), 8.0, 0.25)
    for k, s in enumerate((17, 20, 24, 29)):
        m.add("carnival", K.glock(s, 1.2, 0.9), 8.375 + k * STEP, 0.16, pan=0.3 + 0.13 * k, hall=0.35)
    m.add("fx", K.stereo(K.reverse_cymbal(1.0)), 9.0, 0.18)
    _roll(m, 9.0, 10.0, 0.05, 0.22)
    for at, f0 in ((9.5, 70), (9.75, 64)):
        m.add("drums", K.taiko(f0, 0.9, 0.7), at, 0.35, room=0.15)


def _worlds(m):
    """10.0-17.5: the groove under the fifteen worlds."""
    _hit(m, 10.0, 0.6, 260.0, crash=0.6, taiko=0.9)
    _drums(m, 10.0, 4, GROOVE_KICK, GROOVE_SNARE, GROOVE_TAIKO, shaker=0.1, fill=True)
    _bass_line(m, 10.0, 17.5, GALLOP, gain=0.28)
    _ostinato(m, 10.0, 17.5, lo=-10, gain=0.2, vel=0.8)
    _brass_line(m, GROOVE_BRASS, shift=-12, gain=0.36, vel=0.8)
    _string_line(m, GROOVE_COUNTER, gain=0.11)
    _pads(m, 14.0, 17.5, "choir", -12, 5, 0.28, 4, vowel="oh")
    _pads(m, 10.0, 14.0, "strings", -19, -5, 0.12, 4)
    # An accent on every cut: a clank of metal and a low tom, alternating sides.
    for k in range(15):
        at = 10.0 + k * BEAT
        if k:
            m.add("hits", K.metal(320 + 37 * (k % 5), 0.6, 0.25, 0.7), at, 0.13, pan=0.25 if k % 2 else 0.75, room=0.2)
            m.add("drums", K.tom(98 if k % 2 else 82, 0.5, 0.7), at, 0.2, pan=0.5, room=0.15)
    m.add("fx", K.riser(1.5, top=7000), 16.0, 0.12)
    _roll(m, 16.5, 17.5, 0.06, 0.25)
    # 17.5 the stop-hit on A.
    _hit(m, 17.5, 0.85, 170.0, crash=0.5, taiko=0.9)
    _stab(m, 17.5, "A", 0.5, 1.0, brass_gain=0.34, choir_gain=0.45)


def _alphas(m):
    """18-23: five alphas, five hits on a climbing bass, pounding eighths."""
    for k, (at, name) in enumerate(((18.0, "Dm"), (19.0, "C/E"), (20.0, "F"), (21.0, "Gm"), (22.0, "A"))):
        _hit(m, at, 0.75 + 0.07 * k, 150.0 + 25 * k, crash=0.55 if k in (0, 4) else 0.3, taiko=1.0)
        _stab(m, at, name, 0.95, 0.9 + 0.03 * k, brass_gain=0.34 + 0.01 * k, choir_gain=0.48)
        bass = CHORDS[name][0]
        body, sub = K.bass_note(bass, 0.9, 1.0, 1.8)
        m.add("bass", body, at, 0.3)
        m.add("sub", sub, at, 0.35)
        for e in range(1, 4):              # pounding eighths after the hit (low strings, toms, bass)
            t = at + e * 0.25
            m.add("bass", K.spiccato(bass + 12, 0.2, 0.9) + K.spiccato(bass + 24, 0.2, 0.7), t, 0.3)
            m.add("drums", K.tom(85 + 8 * k, 0.4, 0.45 + 0.1 * e), t, 0.24, pan=0.4 + 0.1 * e, room=0.15)
            m.add("drums", K.hat(0.06, 0.6), t + 0.125, 0.07, pan=0.35)
        m.kick(at + 0.5, 0.7)
        m.add("drums", K.snare(0.4, 0.8), at + 0.5, 0.22, room=0.2)
    m.add("fx", K.stereo(K.reverse_cymbal(0.75)), 22.25, 0.16)


def _cast(m):
    """23-26: a sustained Bb chord swelling, the A pedal, the riser, the cut."""
    _hit(m, 23.0, 0.6, 190.0, crash=0.7, taiko=0.9)
    rise = np.clip(0.5 + 0.5 * K.taxis(1.3) / 1.0, 0, 1)
    m.add("brass", K.stereo(K.brass(voicing("Bb", -23, -2, 6), 1.3, vel=0.8, attack=0.04, release=0.4, sustain=0.9) * rise),
          23.0, 0.42, hall=0.35)
    m.add("choir", K.choir(voicing("Bb", -11, 10, 6), 1.4, "ah", attack=0.2, release=0.4), 23.0, 0.5, hall=0.4)
    body, sub = K.bass_note(-35, 1.0, 0.9, 1.6)
    m.add("bass", body, 23.0, 0.28)
    m.add("sub", sub, 23.0, 0.35)
    # The A pedal under the riser: sus4 resolving, tremolo strings, brass swelling, bass eighths.
    _pads(m, 24.0, 25.5, "tremolo", -24, 0, 0.18, 6)
    _pads(m, 24.0, 25.5, "brass", -19, -3, 0.3, 4)
    _pads(m, 24.0, 25.5, "choir", -12, 7, 0.4, 5)
    for e in range(6):
        body, sub = K.bass_note(-36, 0.22, 0.8 + 0.04 * e, 1.6)
        m.add("bass", body, 24.0 + e * 0.25, 0.28)
        m.add("sub", sub, 24.0 + e * 0.25, 0.3)
    for e in range(3):
        m.kick(24.0 + e * 0.5, 0.7 + 0.1 * e)
    m.add("fx", K.riser(1.5, top=8000, pitched=(-24, -17, -12)), 24.0, 0.2)
    _roll(m, 24.0, 25.5, 0.06, 0.3)
    m.add("drums", K.taiko(60, 0.8, 0.8), 25.0, 0.4)
    m.add("drums", K.taiko(70, 0.8, 0.9), 25.25, 0.42)
    # In the silence: a reversed whoosh into the drop (quiet until its last moment).
    m.add("breath", K.reverse_swell(K.whoosh(0.32, 0.12, 300, 3200), 0.32), 25.68, 0.3)
    m.add("breath", K.stereo(K.reverse_cymbal(0.32)), 25.68, 0.16)


def _drop(m):
    """26-35: the drop, the WINNER hit, the reloads, the slide."""
    _hit(m, 26.0, 1.2, 130.0, crash=0.9, taiko=1.0)
    m.add("hits", K.boom(3.0, 0.8), 26.0, 0.25)
    _drums(m, 26.0, 4, DROP_KICK, DROP_SNARE, DROP_TAIKO, shaker=0.08, hats=0.06, fill=True)
    _drums(m, 34.0, 1, {0: 1.0, 6: 0.6}, {4: 0.8}, {0: 0.8}, shaker=0.08, hats=0.05, until=35.0)
    _bass_line(m, 26.0, 35.0, GALLOP, gain=0.3, grit=0.8)
    _ostinato(m, 26.0, 35.0, lo=-7, gain=0.17, vel=0.9)
    _lead_phrases(m, DROP_LEAD[:5], gain=0.3, organ=0.2)
    _pads(m, 26.0, 35.0, "choir", -12, 7, 0.32, 5)
    _pads(m, 26.0, 35.0, "brass", -19, -5, 0.16, 4)
    _pads(m, 26.0, 35.0, "strings", -19, -3, 0.08, 5)
    m.add("fx", K.stereo(K.reverse_cymbal(1.0)), 26.5, 0.1)
    # 27.5 the golden WINNER round: a glockenspiel run up into a hit and a bell.
    for k, s in enumerate((17, 20, 24, 29)):
        m.add("carnival", K.glock(s, 0.8, 0.8), 27.0 + k * STEP, 0.12, pan=0.3 + 0.12 * k, hall=0.3)
    _hit(m, 27.5, 0.65, 330.0, crash=0.5, taiko=0.0)
    m.add("carnival", K.bell(5, 2.5, 0.9), 27.5, 0.12, hall=0.4)
    # 29.0 RELOADS: a hit and a stab, then a glint (glock + a mechanism tick) on each reload's snap.
    _hit(m, 29.0, 0.7, 240.0, crash=0.5, taiko=0.8)
    _stab(m, 29.0, "C", 0.5, 0.9, choir=False, brass_gain=0.3)
    for k, at in enumerate((29.0, 30.0, 31.0, 32.0)):
        m.add("carnival", K.glock((24, 22, 27, 29)[k], 1.0, 0.9), at, 0.13, pan=0.35 + 0.1 * k, hall=0.3)
        m.add("hits", K.tick(1.0, 2600 + 300 * k), at, 0.2, pan=0.6 - 0.1 * k, room=0.25)
        m.add("hits", K.metal(500 + 60 * k, 0.5, 0.2, 0.8), at, 0.1, pan=0.5, room=0.2)
    # 33-35 the movement: a vault at 33 and the slide's whoosh into 34.
    m.add("drums", K.tom(120, 0.6, 1.0), 33.0, 0.3, room=0.15)
    m.add("fx", K.whoosh(0.7, 0.62, 300, 3800), 33.55, 0.45)


def _halftime(m):
    """35-37: half-time, the band filtered down at 35, a thud at 36, opening back up into 37."""
    _hit(m, 35.0, 0.6, 280.0, crash=0.4, taiko=0.0)
    m.add("hits", K.boom(2.5, 0.8), 35.0, 0.45)
    m.add("hits", K.boom(3.0, 1.1), 36.0, 0.7)
    m.add("hits", K.taiko(48, 1.8, 1.0), 36.0, 0.6, hall=0.25)
    m.add("hits", K.metal(110, 2.0, 0.8, 0.8), 36.0, 0.18, hall=0.3)
    m.add("hits", K.snare(0.6, 1.0), 36.0, 0.25, hall=0.2)
    _pads(m, 35.0, 37.0, "choir", -12, 7, 0.4, 5)
    _pads(m, 35.0, 37.0, "strings", -19, 2, 0.16, 6)
    for at in (35.0, 36.0):
        body, sub = K.bass_note(CHORDS[chord_at(at)][0], 0.95, 0.9, 1.8, 0.6)
        m.add("bass", body, at, 0.3)
        m.add("sub", sub, at, 0.4)
    _lead_phrases(m, [(35.0, [(12, 0, 2), (15, 2, 1.6)])], gain=0.2)
    m.add("fx", K.riser(1.0, top=7500), 36.0, 0.16)
    m.add("fx", K.stereo(K.reverse_cymbal(1.0)), 36.0, 0.2)
    _roll(m, 36.5, 37.0, 0.08, 0.25, accel=False)


def _mayhem(m):
    """37-40: the full band again, the hook, kills accented."""
    _hit(m, 37.0, 0.9, 200.0, crash=0.8, taiko=1.0)
    _drums(m, 36.0, 2, DROP_KICK, DROP_SNARE, DROP_TAIKO, shaker=0.08, hats=0.06, since=37.0)   # bar 36-38 from 37
    _bass_line(m, 37.0, 40.0, GALLOP[8:] + GALLOP[:8], gain=0.3, grit=0.8)
    _ostinato(m, 37.0, 40.0, lo=-7, gain=0.17, vel=0.9)
    _lead_phrases(m, DROP_LEAD[5:7], gain=0.3, organ=0.2)
    _pads(m, 37.0, 40.0, "choir", -12, 7, 0.32, 5)
    _pads(m, 37.0, 40.0, "brass", -19, -5, 0.16, 4)
    for k, at in enumerate((38.0, 39.0)):
        m.add("hits", K.metal(260 + 80 * k, 1.0, 0.4, 1.0), at, 0.2, pan=0.35 + 0.3 * k, room=0.2)
        m.add("drums", K.tom(90 + 20 * k, 0.5, 1.0), at, 0.3, room=0.15)
    _stab(m, 39.5, "A", 0.5, 0.9, choir=False, brass_gain=0.26)
    m.add("fx", K.stereo(K.reverse_cymbal(0.5)), 39.5, 0.15)


def _endless(m):
    """40-44: ENDLESS: double-time toms, four on the floor, the choir climbing."""
    _hit(m, 40.0, 1.0, 170.0, crash=0.9, taiko=1.0)
    for e in range(32):
        at = 40.0 + e * STEP
        f0, v = ENDLESS_TOMS[e % 8]
        m.add("drums", K.tom(f0, 0.45, v * (0.75 + 0.25 * e / 31)), at, 0.24, pan=0.3 + 0.4 * ((e % 3) / 2), room=0.15)
        m.add("drums", K.hat(0.06, SHAKE[e % 4]), at, 0.06, pan=0.4)
    for b in range(8):
        m.kick(40.0 + b * BEAT, 1.0)
        if b % 2:
            m.add("drums", K.snare(0.45, 1.0), 40.0 + b * BEAT, 0.3, room=0.18)
    _bass_line(m, 40.0, 44.0, [0, None, 12, None, 0, None, 12, None, 0, None, 12, None, 0, 12, 0, 12], gain=0.32, grit=0.7)
    _ostinato(m, 40.0, 44.0, lo=-5, gain=0.16, vel=0.95)
    _lead_phrases(m, DROP_LEAD[7:], gain=0.3, organ=0.2)
    # The choir climbs: each chord voiced a step higher, louder.
    for k, at in enumerate((40.0, 41.0, 42.0, 43.0)):
        notes = voicing(chord_at(at), -9 + 2 * k, 9 + 2 * k, 5)
        m.add("choir", K.choir(notes, 1.4, "ah", attack=0.15, release=0.4), at, 0.32 + 0.05 * k, hall=0.35)
        m.add("brass", K.stereo(K.brass(voicing(chord_at(at), -19, -5, 4), 1.1, vel=0.75, attack=0.05, release=0.3, sustain=0.85)),
              at, 0.18, hall=0.25)
    m.add("fx", K.riser(1.5, top=8000), 42.5, 0.16)
    _roll(m, 43.0, 44.0, 0.1, 0.3)


def _last_ride(m):
    """44-46: the stop-hit and the tension chord, heartbeat and clock."""
    _hit(m, 44.0, 1.0, 120.0, crash=0.7, taiko=1.0)
    notes = voicing("Dm/Eb", -19, 1, 6)
    swell = np.clip(0.35 + 0.65 * (K.taxis(2.0) / 2.0) ** 2, 0, 1)
    m.add("brass", K.stereo(K.brass(voicing("Dm/Eb", -24, -8, 4), 2.0, vel=0.9, attack=0.01, release=0.2, sustain=0.6) * swell),
          44.0, 0.3, hall=0.3)
    m.add("choir", K.choir(notes, 2.1, "oo", attack=0.05, release=0.3), 44.0, 0.42, hall=0.4)
    m.add("strings", K.tremolo([-7, -6, 5, 6], 2.0, rate=15.0, attack=0.6, bright=3800), 44.0, 0.12, hall=0.3)
    m.add("bass", K.drone(-31, 2.05) * np.clip((2.05 - K.taxis(2.05)) / 0.05, 0, 1), 44.0, 0.3)
    for k, at in enumerate((44.5, 45.0, 45.5)):
        m.add("bass", K.heartbeat(0.9 + 0.05 * k), at, 0.5)
    for e in range(8):
        m.add("hits", K.tick(0.8, 3200 if e % 2 else 2400), 44.25 + e * 0.25, 0.12, pan=0.4 if e % 2 else 0.6, room=0.3)
    m.add("fx", K.riser(1.0, top=6000), 45.0, 0.1)


def _yours(m):
    """46-50: MAKE IT YOURS: arpeggio and bells, a lighter groove, the organ rising."""
    m.kick(46.0, 0.9)
    m.add("drums", K.crash(3.0, 0.5), 46.0, 0.2, hall=0.15)
    m.add("carnival", K.bell(-7, 3.0, 1.0), 46.0, 0.16, hall=0.4)
    _drums(m, 46.0, 2, {0: 1.0, 8: 0.9}, {4: 0.6, 12: 0.7}, None, shaker=0.11)
    t = 46.0
    while t < 50.0 - 1e-6:
        step = int(round((t - 46.0) / STEP))
        notes = voicing(chord_at(t), -2, 17, 5)
        s = notes[ARP[step % 16] % len(notes)]
        m.add("carnival", K.pluck(s, 0.3, 0.9 if step % 4 == 0 else 0.7), t, 0.2, pan=0.35, hall=0.15)
        if step % 2 == 0:
            m.add("carnival", K.music_box(s + 12, 0.8, vel=0.7), t, 0.1, pan=0.68, hall=0.3)
        if step % 4 == 0:
            m.add("carnival", K.glock(voicing(chord_at(t), 17, 29, 3)[step // 4 % 3], 1.0, 0.8), t, 0.1, pan=0.55, hall=0.3)
        t += STEP
    _bass_line(m, 46.0, 50.0, [0, None, None, 0, None, None, 12, None, 0, None, None, 0, None, None, 12, None], gain=0.26)
    for s, start, ln in phrase_notes(YOURS_ORGAN):
        m.add("carnival", K.organ(s, ln * 0.92), start, 0.26, pan=0.5, hall=0.25)
    _pads(m, 48.0, 50.0, "strings", -19, 0, 0.13, 6)
    _pads(m, 48.0, 50.0, "choir", -12, 7, 0.32, 5, vowel="oh")
    m.add("fx", K.riser(1.5, top=8000), 48.5, 0.16)
    m.add("fx", K.stereo(K.reverse_cymbal(1.0)), 49.0, 0.2)
    _roll(m, 49.0, 50.0, 0.08, 0.3)


def _finale(m):
    """50-58.5: the biggest hit, the hook in D major, the final slam, the ring-out."""
    _hit(m, 50.0, 1.4, 120.0, crash=1.0, taiko=1.0)
    m.add("hits", K.boom(3.0, 1.0), 50.0, 0.3)
    m.add("carnival", K.bell(-7, 3.0, 1.0), 50.0, 0.18, hall=0.4)
    # Heroic half-time: taiko on one, a huge snare on three, toms into the slam.
    for bar in (50.0,):
        for step, (kind, v) in {0: ("t", 1.0), 6: ("k", 0.7), 8: ("s", 1.0), 10: ("t", 0.7), 14: ("t", 0.8)}.items():
            at = bar + step * STEP
            if kind == "t":
                m.add("drums", K.taiko(54, 1.4, v), at, 0.5, hall=0.15)
                m.kick(at, v)
            elif kind == "s":
                m.add("drums", K.snare(0.6, v), at, 0.36, room=0.25, hall=0.1)
                m.kick(at, 0.8)
            else:
                m.kick(at, v)
        for e in range(16):
            m.add("drums", K.hat(0.07, SHAKE[e % 4]), bar + e * STEP, 0.06, pan=0.4)
    m.kick(52.0, 1.0)
    m.add("drums", K.taiko(54, 1.4, 1.0), 52.0, 0.5, hall=0.15)
    for k in range(4):
        m.add("drums", K.tom(140 - 15 * k, 0.5, 0.8 + 0.05 * k), 52.5 + k * STEP, 0.3, pan=0.7 - 0.12 * k, room=0.15)
    _bass_line(m, 50.0, 53.0, [0, None, 0, None, 12, None, 0, None] * 2, gain=0.3, grit=0.5)
    _ostinato(m, 50.0, 53.0, lo=-7, gain=0.15, vel=0.9)
    # The theme: lead + organ, low brass in octaves, choir and brass chords, a high string counter-line.
    _lead_phrases(m, FINALE_LEAD, gain=0.3, organ=0.22)
    _brass_line(m, FINALE_LEAD, shift=-12, gain=0.3, vel=1.0)
    _string_line(m, FINALE_COUNTER, gain=0.12)
    _pads(m, 50.0, 53.0, "choir", -12, 9, 0.4, 6)
    _pads(m, 50.0, 53.0, "brass", -24, -7, 0.2, 4)
    m.add("fx", K.stereo(K.reverse_cymbal(0.5)), 52.5, 0.2)
    # 53.0 the final slam on D major, ringing.
    _hit(m, 53.0, 1.5, 110.0, crash=1.0, taiko=1.0)
    m.add("hits", K.boom(5.0, 1.2), 53.0, 0.3)
    notes = voicing("D", -19, 2, 6)
    m.add("brass", K.stereo(K.brass(notes, 3.2, vel=1.0, attack=0.012, release=2.2, sustain=0.55)), 53.0, 0.4, hall=0.4)
    m.add("choir", K.choir(voicing("D", -12, 9, 6), 4.5, "ah", attack=0.03, release=3.0), 53.0, 0.55, hall=0.45)
    m.add("strings", K.strings(voicing("D", -31, 9, 9), 5.5, attack=0.05, release=4.0, bright=3000), 53.0, 0.2, hall=0.4)
    body, sub = K.bass_note(-31, 3.0, 1.0, 1.4)
    m.add("bass", body * np.exp(-K.taxis(3.0) / 1.2), 53.0, 0.3)
    m.add("sub", sub * np.exp(-K.taxis(3.0) / 1.5), 53.0, 0.35)
    m.add("carnival", K.bell(5, 4.0, 1.0), 53.0, 0.14, hall=0.45)
    # The music box closes the hook (in major) over the ring; a last bell and boom on the fade to black.
    for s, b, ln in HOOK_MAJOR:
        m.add("carnival", K.music_box(s + 12, 1.6, vel=0.8), 54.0 + b * BEAT, 0.22, pan=0.45, hall=0.55)
    m.add("hits", K.impact(0.45, 3.0, 200.0), 56.0, 0.45, hall=0.3)
    m.add("carnival", K.music_box(17, 2.5, vel=0.9), 56.0, 0.24, pan=0.5, hall=0.55)
    m.add("carnival", K.bell(-7, 2.5, 0.9), 56.0, 0.16, hall=0.5)
    m.add("hits", K.metal(150, 2.5, 1.2, 1.0), 56.0, 0.14, hall=0.4)
    m.add("hits", K.crash(2.5, 0.4, dark=6000), 56.0, 0.12, hall=0.3)
    m.add("choir", K.choir(voicing("D", -19, 2, 5), 2.6, "oo", attack=0.08, release=2.0), 56.0, 0.3, hall=0.5)


# ---------------------------------------------------------------------------
# The mix
# ---------------------------------------------------------------------------

# Per-bus voicing: (high-pass Hz, ((bell Hz, dB, Q), ...)).
BUS_EQ = {
    "strings": (120.0, ((3000.0, -1.0, 0.8),)), "brass": (90.0, ((2800.0, -1.0, 0.9), (350.0, -1.5, 0.8))),
    "choir": (150.0, ((3200.0, -1.0, 0.8),)), "lead": (220.0, ((2700.0, -1.5, 0.9),)),
    "carnival": (280.0, ()), "fx": (150.0, ((4500.0, -2.0, 0.7),)), "bass": (45.0, ((250.0, -2.0, 0.8),)),
    "drums": (32.0, ((60.0, -4.5, 0.8), (4000.0, 2.0, 0.8))), "hits": (25.0, ((60.0, -3.5, 0.7),)),
}


BUS_GAIN = {"drums": 0.6, "hits": 0.75, "bass": 1.3, "sub": 0.38, "strings": 2.0, "brass": 1.0, "choir": 3.5,
            "lead": 1.4, "carnival": 0.8, "fx": 1.5}
# The fader (second, dB): a quiet open, the slam, the build, the half-time dip, Last Ride, the finale on top.
FADER = [(0.0, -10.0), (4.95, -8.0), (5.0, -5.0), (6.9, -3.0), (7.5, -2.0), (8.0, 1.5), (9.0, 0.0), (9.95, -1.0),
         (10.0, -3.0), (17.45, -2.0), (17.5, -1.0), (18.0, -1.5), (23.0, -0.5), (25.5, 0.0), (26.0, 0.5), (35.0, 0.5),
         (35.1, -2.0), (36.95, -2.0), (37.0, 0.5), (40.0, 1.0), (44.0, 1.0), (44.05, 0.0), (46.0, -1.0), (46.05, -3.0),
         (49.9, -1.0), (50.0, 2.0), (58.5, 2.0)]


def _voiced(x, bus):
    if bus not in BUS_EQ:
        return x
    hp_hz, bells = BUS_EQ[bus]
    x = K.hp(x, hp_hz)
    for fc, db, q in bells:
        x = K.eq_bell(x, fc, db, q)
    return x


def _halftime_filter(t):
    """Cutoff (Hz) of the band from 35 to 37: down to 380 Hz at once, opening back up to 37."""
    if t < 35.0 or t >= 37.0:
        return 20000.0
    if t < 35.08:
        return 20000.0 * (380.0 / 20000.0) ** ((t - 35.0) / 0.08)
    if t < 36.0:
        return 380.0
    return 380.0 * (18000.0 / 380.0) ** ((t - 36.0) / 1.0) ** 2.2


DEBUG = {}      # the voiced buses of the last render (tools/measure)


def showreel_trailer():
    K.reseed(2026)
    m = Mix(WORK)
    for section in (_cold_open, _logo, _worlds, _alphas, _cast, _drop, _halftime, _mayhem, _endless, _last_ride,
                    _yours, _finale):
        section(m)
    n = m.n
    b = {k: _voiced(v, k) * BUS_GAIN.get(k, 1.0) for k, v in m.bus.items()}
    DEBUG.clear()
    DEBUG.update(b)
    # Sidechain: the band ducks under every hit (deep) and pumps with the kicks (light); just
    # before each hit everything but the hit itself takes a breath, so the transient lands clean.
    under_hits = K.duck(n, HITS, 0.5, pre=0.002, release=0.5)[:, None]
    breath = np.ones(n)
    for t, _ in HITS:
        breath *= K.duck(n, [(t, 1.0)], 0.8, pre=BREATH.get(t, 0.05), release=0.012, shape=1.0)
    breath = breath[:, None]
    pump = K.duck(n, [(t, 1.0) for t in m.kicks], 0.25, pre=0.002, release=0.18)[:, None]
    hall = K.convolve(K.hp(m.hall, 160), K.hall_ir(3.4, 0.025, seed=61))
    room = K.convolve(K.hp(m.room, 200), K.hall_ir(1.1, 0.008, seed=62, rt=((300, 1.0), (2000, 0.8), (20000, 0.4))))
    drums = b["drums"] + K.compress(b["drums"], -30.0, 4.0, 0.002, 0.12) * 0.6        # parallel compression
    tonal = (b["strings"] + b["choir"]) * pump + b["brass"] * (0.4 + 0.6 * pump) + b["lead"] * (0.7 + 0.3 * pump) + b["carnival"]
    tonal = K.widen(tonal, 1.3)
    low = b["bass"] * pump + b["sub"] * (0.3 + 0.7 * pump)
    band = drums + (b["fx"] + tonal + low) * under_hits + (hall * 0.6 + room * 0.4) * (0.5 + 0.5 * under_hits)
    # The half-time filter (35-37) on the band (not the hits).
    band = _swept_lowpass(band, 34.9, 37.1, _halftime_filter)
    mix = band * breath + b["hits"]
    # The fader, the dead silences, then the reversed whoosh in the second one.
    ft, fdb = zip(*FADER)
    mix = mix * (10 ** (np.interp(np.arange(n) / SR, ft, fdb) / 20))[:, None]
    # Master: lows in mono, mud and harshness tamed, glue, gentle saturation. The silences are
    # gated last (after every zero-phase filter, so nothing rings into them); the reversed whoosh
    # in the second one comes in after the gate at the same gain.
    mix = K.mono_lows(mix, 150.0)
    mix = eq(mix, bells=((45.0, -2.5, 0.7), (280.0, -1.5, 0.8), (1800.0, 1.0, 0.7)), shelf=(9000.0, -1.5))
    gain = 1.0 / (np.max(np.abs(mix)) + 1e-9)
    mix = K.compress(mix * gain, -18.0, 1.8, 0.01, 0.25, knee=8.0)
    gain *= 1.2 / (np.max(np.abs(mix)) + 1e-9)
    mix = K.sat(mix * 1.2 / (np.max(np.abs(mix)) + 1e-9), 1.3)
    mix = mix * K.gate(n, SILENT)[:, None] + K.mono_lows(b["breath"], 150.0) * gain
    out = mix[: int(SR * TOTAL)]
    t = t_axis(TOTAL)
    return out * np.clip((TOTAL - t) / 1.8, 0, 1)[:, None] ** 2


def _swept_lowpass(x, t0, t1, cutoff_at):
    """Low-passes an (n, 2) buffer between t0 and t1 with a cutoff that moves
    (a function of absolute time); where the cutoff is at the top, x is untouched."""
    a, b = int(SR * t0), int(SR * t1)
    seg = x[a:b]
    t = (a + np.arange(len(seg))) / SR
    fc = np.array([cutoff_at(v) for v in t])
    wet = np.clip(np.log(19000.0 / fc) / np.log(19000.0 / 9000.0), 0, 1)
    out = x.copy()
    for c in range(2):
        out[a:b, c] = seg[:, c] + (K.tv_lowpass(seg[:, c], np.minimum(fc, 17000.0), 2.0) - seg[:, c]) * wet
    return out


def cine_startup():
    """The startup screen's score (mono one-shot): warm, low, building, and in
    the menu theme's key, so the menu music picks up where it ends."""
    d = 8.5
    out = silence(d)
    t = t_axis(d)
    place(out, _sea(d) * np.clip(t / 1.5, 0, 1), 0.0, 0.12)
    # The theme's hook on the distant calliope, as if from the far end of the pier.
    hook = silence(4.8)
    for bar, notes in enumerate(menu.VERSE[:2]):
        for s, at, ln in notes:
            place(hook, menu.calliope(s, ln * menu.BEAT * 0.96), 0.25 + bar * menu.BAR + at * menu.BEAT, 0.5)
    place(out, _distant(hook * np.clip((4.8 - t_axis(4.8)) / 0.5, 0, 1)), 0.0, 0.5)
    place(out, _pad(-10, (0, 3, 7), 3.2, cutoff=700, attack=1.0), 0.0, 0.5)           # Bm
    place(out, _pad(-12, (0, 4, 7), 1.6, cutoff=1000, attack=1.2, release=0.1), 3.0, 0.55)   # A
    for i, at in enumerate((1.4, 2.2, 3.0, 3.8)):
        place(out, _heartbeat(), at, 0.45 + 0.1 * i)
        place(out, _tom(90 - 6 * i, 0.5), at, 0.35)
    place(out, _low_boom(3.9), 4.6, 1.0)
    place(out, _brass(-31, (0, 7, 12), 2.4, cutoff=1000, attack=0.06), 4.6, 0.35)     # D
    for i, at in enumerate((5.6, 6.1, 6.6)):
        f = note(menu.HOOK[i][0] - 12)                                                 # the hook's first notes
        pluck_ = (tone(f, 0.5, "sine") + tone(f * 2, 0.5, "sine") * 0.3) * env(0.5, 0.004, 0.45, power=2.0)
        place(out, pluck_, at, 0.25)
    place(out, _pad(-7, (0, 7, 12, 16), 2.4, cutoff=1400, attack=0.4, release=0.8), 6.1, 0.5)   # D (open)
    return out




SOUNDS = [cine_startup]
LOOPS = {}
MUSIC = {"showreel_trailer": showreel_trailer}
