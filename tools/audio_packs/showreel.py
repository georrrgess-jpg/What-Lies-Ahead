"""The trailer score and the startup score.

    python tools/gen_audio.py showreel --music     (the trailer; drop --music to also write cine_startup)

showreel_trailer: a 41.6 s epic trailer cue plus a 1.8 s ring-out (43.4 s),
150 BPM (a beat is 0.4 s, a bar 1.6 s), D minor lifting to D major, written
to the locked cue sheet of the in-engine trailer (scripts/cinematics): every
hit's transient starts on its mark's sample. The motif is the game's own: the
menu theme's hook (menu.HOOK), in minor on a detuned music box and on the
drop's lead (doubled by the band-organ calliope), in major for the finale.

     0.0  cold open  drone and sea wind from silence, the motif on a music box
                     running down; heartbeat on the beats from 1.6
     3.2  flashes    pulse doubles, tick-tock, a taiko + clang per flash, riser
     4.8  suck-back  a reversed crash into silence (the roar's breath), a sub
                     swell and a reversed choir inhale into
     6.0  IMPACT     sub boom, punch, metal, brass + choir stab; logo hold with
                     a ticking hat, a lift into
     8.0  15 worlds  the groove: taiko pattern, 16th hats, gallop bass, a whoosh
                     into every cut (0.4 s grid) and a clang on it; string
                     ostinato growing, choir from 11.2, a roll into
    14.0  alphas     a heavy hit + brass/choir stab at 14.0 14.8 15.6 16.4 (Dm Bb
                     Gm A), pounding eighths, a snare roll into nothing
    17.2  cut-out    dead silence but a reversed choir swell
    17.6  DROP       big kick/snare/taiko, distorted gallop bass, the motif on the
                     lead + calliope, choir, crashes, ducking on every kick
    22.0  slow-mo    a deep whomp, the whole band low-passed to 320 Hz, opening
                     back up to the hit at 22.8
    27.2  Endless    four on the floor, toms in double time, the choir climbing a
                     step a beat, a snare roll into
    30.4  stop-hit   the stop-hit, a tension chord (D minor over an E-flat rub),
                     heartbeat and clock
    32.0  arsenal    a 16th pluck arp over Bb then C, a bell glint on every beat
    35.2  FINALE     the biggest hit, the full theme in D major (brass, lead,
                     choir, calliope), half-time drums, D | Bb C |
    38.4  SLAM       the final slam on D major, ringing down under the music box
                     closing the motif; the picture fades at 41.6

Mastered as a one-shot by write_music (names ending in _trailer): -14 LUFS,
sample peaks under -2 dBFS, only a 28 Hz high-pass; the pack voices and glues
the mix itself (sidechain ducking, hall/room reverb, mono lows, bus compressor).

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
# showreel_trailer: the score
# ---------------------------------------------------------------------------

BPM = 150.0
BEAT = 60.0 / BPM            # 0.4 s
BAR = 4 * BEAT               # 1.6 s
STEP = BEAT / 4              # a sixteenth, 0.1 s
LENGTH = 41.6                # the picture (it fades to black here)
TOTAL = 43.4                 # the file: the picture plus the ring-out
WORK = TOTAL + 4.0           # render buffer (reverb tails never wrap onto the start)

# The locked marks (docs: the trailer cue sheet). Every hit's transient starts on the sample.
IMPACT = 6.0
GROOVE = 8.0
ALPHAS = (14.0, 14.8, 15.6, 16.4)
CUT = 17.2
DROP = 17.6
SLOWMO = (22.0, 22.8)
ENDLESS = 27.2
STOP = 30.4
YOURS = 32.0
FINALE = 35.2
SLAM = 38.4
HITS = (IMPACT, GROOVE) + ALPHAS + (DROP, SLOWMO[0], SLOWMO[1], ENDLESS, STOP, YOURS, FINALE, SLAM)

# Chords: bass root (semitones from A4) and triad. D minor, with the finale lifting to D major.
CH = {"Dm": (-31, (0, 3, 7)), "Bb": (-35, (0, 4, 7)), "F": (-28, (0, 4, 7)), "C": (-33, (0, 4, 7)),
      "Gm": (-38, (0, 3, 7)), "A": (-36, (0, 4, 7)), "D": (-31, (0, 4, 7))}
# The carnival motif: the menu theme's hook (menu.HOOK), here in D minor: (semis, beat, beats).
HOOK_MINOR = [(0, 0, 0.5), (5, 0.5, 0.5), (8, 1, 1.5), (7, 2.5, 0.5), (5, 3, 0.5), (7, 3.5, 0.5)]
HOOK_MAJOR = [(0, 0, 0.5), (5, 0.5, 0.5), (9, 1, 1.5), (7, 2.5, 0.5), (5, 3, 0.5), (7, 3.5, 0.5)]
# The drop: six bars, one chord each (the last splits Bb | A), the motif as the lead.
DROP_BARS = ["Dm", "Bb", "F", "C", "Dm", "Bb"]
DROP_LEAD = [
    HOOK_MINOR,
    [(5, 0, 1.5), (1, 1.5, 1.5), (0, 3, 0.5), (1, 3.5, 0.5)],
    [(3, 0, 0.5), (8, 0.5, 0.5), (12, 1, 1.5), (10, 2.5, 0.5), (8, 3, 2.0)],      # the long note rides the slow-mo
    [(7, 1, 0.5), (10, 1.5, 0.5), (12, 2, 1), (10, 3, 0.5), (7, 3.5, 0.5)],
    HOOK_MINOR,
    [(8, 0, 1), (5, 1, 1), (4, 2, 1.5), (0, 3.5, 0.5)],
]
FINALE_LEAD = [(s, b, ln) for s, b, ln in HOOK_MAJOR] + [(5, 4, 1), (8, 5, 1), (7, 6, 1), (10, 7, 1), (9, 8, 6)]


def _hz(semis):
    return 440.0 * 2 ** (semis / 12.0)


def _sine_of(freq):
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def _drop_to(f0, f1, seconds, tau):
    """A frequency curve falling exponentially from f0 towards f1."""
    return f1 + (f0 - f1) * np.exp(-t_axis(seconds) / tau)


def _voicing(name, kind):
    root, tri = CH[name]
    if kind == "pad":
        return [root + 12, root + 24 + tri[0], root + 24 + tri[1], root + 24 + tri[2]]
    if kind == "brass":
        return [root, root + 12, root + 19, root + 24, root + 24 + tri[1]]
    if kind == "choir":
        return [root + 24, root + 24 + tri[1], root + 31, root + 36]
    raise ValueError(kind)


# ---------------------------------------------------------------------------
# Instruments (band-limited oscillators and additive partials: nothing aliases)
# ---------------------------------------------------------------------------

# Struck steel plate modes (ratio, gain, decay seconds): a dark anvil-and-girder clang.
METAL = ((1.0, 1.0, 1.4), (1.593, 0.75, 1.0), (2.136, 0.6, 0.8), (2.653, 0.5, 0.6), (3.156, 0.4, 0.5),
         (3.92, 0.32, 0.38), (4.61, 0.24, 0.3), (5.47, 0.18, 0.22), (6.92, 0.12, 0.15))


def _metal(base, seconds=2.2, decay=1.0):
    """A metal hit: inharmonic plate partials, a strike burst and a little grit."""
    x = additive(base * (1.0 + 0.012 * np.exp(-t_axis(seconds) / 0.05)), None,
                 [(r, g, d * decay) for r, g, d in METAL if base * r < 4800])
    strike = band(noise(seconds), base * 4.0, base * 2.0) * np.exp(-t_axis(seconds) / 0.025)
    return np.tanh(1.4 * (x * 0.55 + strike * 1.6)) * adsr(seconds, 0.0004, seconds, 1.0, 0.08)


def _sub(seconds=2.8, f0=68.0, f1=29.0, tau=0.4, decay=1.0):
    """The sub boom: a sine falling an octave and more, softly saturated."""
    x = _sine_of(_drop_to(f0, f1, seconds, tau)) * adsr(seconds, 0.0015, decay, 0.0, 0.4)
    return np.tanh(1.8 * x) / np.tanh(1.8)


def _impact(size=1.0):
    """A trailer impact (mono): sub boom, a chest punch, a low body thump, a
    short crack and a metal clang, all starting on the same sample."""
    d = 3.2 + size
    out = silence(d)
    place(out, _sub(d, 64 + 10 * size, 27, 0.35 + 0.15 * size, 0.7 + 0.6 * size), 0.0, 0.5)
    punch = _sine_of(_drop_to(190, 50, 0.4, 0.035)) * adsr(0.4, 0.0006, 0.09, 0.0, 0.06)
    place(out, np.tanh(2.0 * punch), 0.0, 0.6)
    place(out, filt(noise(0.7), low=650, high=55) * adsr(0.7, 0.0008, 0.11 + 0.05 * size, 0.0, 0.1), 0.0, 1.7)
    place(out, filt(noise(0.06), low=5200, high=1100) * adsr(0.06, 0.0003, 0.007, 0.0, 0.01), 0.0, 2.0)
    place(out, band(noise(0.12), 2300, 1100) * adsr(0.12, 0.0003, 0.025, 0.0, 0.02), 0.0, 1.4)
    place(out, _metal(98.0, 2.6, 0.8 + 0.4 * size), 0.0, 0.6)
    place(out, _metal(147.0 * 1.003, 2.0, 0.6 + 0.3 * size), 0.0, 0.35)
    return out


def _brass_note(semis, seconds, bright=3200.0, attack=0.018, decay=0.3, sustain=0.5, release=0.25):
    """Brass: detuned band-limited saws plus a pulse, a pitch scoop into the
    note, a filter that opens on the attack and closes, delayed vibrato."""
    f = _hz(semis)
    t = t_axis(seconds)
    curve = f * 2 ** ((-0.4 * np.exp(-t / 0.025) + 0.07 * np.clip((t - 0.3) / 0.4, 0, 1) * np.sin(2 * np.pi * 5.0 * t)) / 12)
    raw = supersaw(curve, None, 3, 0.09) * 0.85 + bl_osc(curve, None, "square", 0.42) * 0.3
    dark = filt(raw, low=max(220.0, f * 1.6))
    opened = filt(raw, low=bright)
    x = dark + (opened - dark) * np.maximum(np.exp(-t / 0.14), 0.22)
    return filt(np.tanh(1.7 * x), low=6000) * adsr(seconds, attack, decay, sustain, release)


def _brass_chord(name_or_notes, seconds, **kw):
    notes = _voicing(name_or_notes, "brass") if isinstance(name_or_notes, str) else name_or_notes
    return sum(_brass_note(s, seconds, **kw) for s in notes) / len(notes) ** 0.5


VOWEL_AH = ((720.0, 130.0, 1.0), (1100.0, 160.0, 0.55), (2500.0, 240.0, 0.2), (3300.0, 280.0, 0.07))
VOWEL_OH = ((480.0, 110.0, 1.0), (850.0, 150.0, 0.5), (2450.0, 240.0, 0.1))


def _choir_note(semis, seconds, attack=0.3, release=0.6, vowel=VOWEL_AH, singers=5):
    """A section of voices on one note: detuned saws with their own slow
    vibrato through vowel formants, a little breath."""
    f = _hz(semis)
    t = t_axis(seconds)
    vib = 2 ** (0.11 * np.sin(2 * np.pi * (4.7 + rng.uniform(-0.3, 0.3)) * t + rng.uniform(0, 6.28)) / 12)
    src = supersaw(f * vib, None, singers, 0.2)
    x = sum(band(src, c, w) * g for c, w, g in vowel) * 3.2 + filt(src, low=500) * 0.35
    breath = band(noise(seconds), 1500, 700) * 0.04
    return (x + breath) * adsr(seconds, attack, seconds, 1.0, release)


def _choir(notes, seconds, **kw):
    """(left, right): two different sections of the same chord."""
    if isinstance(notes, str):
        notes = _voicing(notes, "choir")
    return [sum(_choir_note(s, seconds, **kw) for s in notes) / len(notes) ** 0.5 for _ in range(2)]


def _spad(notes, seconds, cutoff=1400.0, attack=0.6, release=0.8):
    if isinstance(notes, str):
        notes = _voicing(notes, "pad")
    x = sum(supersaw(_hz(s), seconds, 3, 0.12) for s in notes)
    return filt(x, low=cutoff, slope=1.5) * adsr(seconds, attack, 1.5, 0.8, release) / len(notes) ** 0.5


def _strings(semis, seconds, bright=2600.0):
    """A short spiccato string note (the ostinato)."""
    x = supersaw(_hz(semis), seconds, 3, 0.1)
    return filt(x, low=bright, slope=1.5) * adsr(seconds, 0.006, 0.07, 0.25, 0.04)


def _tremolo(notes, seconds, rate=12.5, cutoff=2200.0):
    """Tremolo strings: a held chord bowed at a sixteenth-ish rate."""
    t = t_axis(seconds)
    x = sum(supersaw(_hz(s), seconds, 3, 0.14) for s in notes) / len(notes) ** 0.5
    bow = 0.6 + 0.4 * np.abs(np.sin(np.pi * rate * t))
    return filt(x, low=cutoff, slope=1.5) * bow * adsr(seconds, 0.15, seconds, 1.0, 0.1)


def _bass(semis, seconds, bright=1200.0, drive=1.6, grit=0.0):
    """Synth bass: saw + pulse with a plucked filter, a clean sine sub, and for
    the drop a distorted mid layer that small speakers can hear."""
    f = _hz(semis)
    t = t_axis(seconds)
    raw = bl_osc(f, seconds, "saw") * 0.6 + bl_osc(f, seconds, "square", 0.45) * 0.4
    dark, opened = filt(raw, low=260), filt(raw, low=bright)
    x = np.tanh(drive * (dark + (opened - dark) * np.exp(-t / 0.06))) * 0.75
    x += bl_osc(f, seconds, "sine") * 0.4
    if grit:
        x += filt(np.tanh(5.0 * raw), low=2200, high=320) * grit * (0.55 + 0.45 * np.exp(-t / 0.08))
    return x * adsr(seconds, 0.003, 0.16, 0.75, 0.02)


def _lead_note(semis, seconds, cutoff=3600.0):
    """The drop's lead: two detuned voices and a sine, delayed vibrato, warm."""
    f = _hz(semis)
    t = t_axis(seconds)
    curve = f * 2 ** (0.15 * np.clip((t - 0.18) / 0.3, 0, 1) * np.sin(2 * np.pi * 5.6 * t) / 12)
    v = (bl_osc(curve * 2 ** (0.07 / 12), None, "saw") + bl_osc(curve * 2 ** (-0.07 / 12), None, "square", 0.32) * 0.6
         + bl_osc(curve, None, "sine") * 0.5)
    return filt(np.tanh(1.5 * filt(v, low=cutoff, slope=1.5)), low=6000) * adsr(seconds, 0.008, 0.3, 0.8, 0.06)


def _calliope(semis, seconds):
    """The band organ's pipe (the menu theme's calliope)."""
    return menu.calliope(semis, seconds)


def _music_box(semis, seconds=1.0, wow=0.0, flat=0.0):
    """A music-box tine; `wow` wobbles the pitch (semitones), `flat` detunes it."""
    t = t_axis(seconds)
    curve = _hz(semis + flat) * 2 ** (wow * np.sin(2 * np.pi * 3.1 * t + rng.uniform(0, 6.28)) / 12)
    partials = [(1, 1.0, 0.7), (2, 0.22, 0.25), (3.0, 0.08, 0.1), (4.2, 0.05, 0.05), (5.4, 0.025, 0.03)]
    return additive(curve, None, [p for p in partials if _hz(semis) * p[0] < 4500]) * adsr(seconds, 0.0015, seconds, 1.0, 0.05)


def _bell(semis, seconds=1.4):
    """A soft glint: a bell an octave over the arp, its highs short-lived and
    nothing above 6 kHz."""
    f = _hz(semis)
    partials = [(1, 1.0, 0.9), (2.0, 0.35, 0.4), (2.76, 0.25, 0.22), (4.07, 0.1, 0.1), (5.43, 0.05, 0.06)]
    return additive(f, seconds, [p for p in partials if f * p[0] < 6000]) * adsr(seconds, 0.002, seconds, 1.0, 0.1)


def _taiko(f0=72.0, seconds=0.9, decay=0.26, skin=0.9):
    """A big drum: a pitched membrane (and its first overtone), a skin slap."""
    t = t_axis(seconds)
    f = f0 * (1 + 0.55 * np.exp(-t / 0.018))
    body = _sine_of(f) * 0.8 + 0.5 * _sine_of(f * 1.59) * np.exp(-t / 0.07) + 0.2 * _sine_of(f * 2.14) * np.exp(-t / 0.04)
    body *= adsr(seconds, 0.0008, decay, 0.0, 0.1)
    slap = filt(noise(seconds), low=1500, high=110) * adsr(seconds, 0.0005, 0.025, 0.0, 0.02)
    return np.tanh(1.5 * (body + slap * skin))


def _kick(seconds=0.45):
    t = t_axis(seconds)
    f = 44 + 125 * np.exp(-t / 0.028) + 380 * np.exp(-t / 0.0025)
    out = np.tanh(2.4 * _sine_of(f) * adsr(seconds, 0.0005, 0.15, 0.0, 0.06))
    place(out, kick_click(0.32, 2600), 0.0)
    return out


def _snare(seconds=0.45):
    t = t_axis(seconds)
    body = (np.sin(2 * np.pi * 182 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t / 0.05)
    rattle = filt(noise(seconds), low=5800, high=1100) * np.exp(-t / 0.11)
    out = (body * 0.6 + rattle) * adsr(seconds, 0.0008, seconds, 1.0, 0.05)
    place(out, clap(0.25), 0.004, 0.5)
    return out


def _hat(seconds=0.05, tail=0.25):
    n = noise(seconds)
    x = band(n, 7400, 1500) * 0.7 + band(n, 5200, 1100) * 0.5
    return x * adsr(seconds, 0.0006, seconds * tail, 0.0, 0.01) * 2.0


def _tick(high=True):
    """A clock's tick-tock (a woodblock)."""
    f = 1250.0 if high else 900.0
    return additive(f, 0.09, [(1, 1.0, 0.025), (2.42, 0.45, 0.012), (3.9, 0.2, 0.006)]) * adsr(0.09, 0.0005, 0.09, 1.0, 0.01)


def _crash(seconds=2.6):
    """A dark crash: band-limited, so it washes rather than hisses."""
    n = noise(seconds)
    x = filt(n, high=2400, low=7000) + band(n, 3900, 900) * 0.8
    return x * adsr(seconds, 0.002, seconds * 0.3, 0.0, 0.4) * 1.4


def _heart():
    """A heartbeat: a deep double thump."""
    out = silence(0.6)
    one = _sine_of(_drop_to(75, 42, 0.32, 0.05)) * adsr(0.32, 0.004, 0.09, 0.0, 0.08)
    one += filt(noise(0.32), low=180) * adsr(0.32, 0.002, 0.04, 0.0, 0.05) * 0.6
    place(out, one, 0.0, 1.0)
    place(out, one, 0.17, 0.6)
    return out


def _whoosh(pre=0.3, post=0.18):
    """A pass-by: band-passed noise climbing to its peak at `pre` (the cut)
    and falling away."""
    d = pre + post
    t = t_axis(d)
    n = noise(d)
    bank = [filt(n, low=c, high=c * 0.33) for c in (420.0, 760.0, 1300.0, 2200.0)]
    pos = np.where(t < pre, (t / pre) ** 1.4, 1.0 - 0.75 * (t - pre) / post) * (len(bank) - 1)
    lo = np.clip(np.floor(pos).astype(int), 0, len(bank) - 2)
    k = pos - lo
    stack = np.stack(bank)
    x = stack[lo, np.arange(len(t))] * (1 - k) + stack[lo + 1, np.arange(len(t))] * k
    e = np.where(t < pre, (t / pre) ** 2.4, np.exp(-(t - pre) / (post * 0.3)))
    return x * e * np.clip((d - t) / 0.01, 0, 1)


def _riser(seconds, semis_from=-19, octaves=2.0):
    """Noise climbing through the bands, a rising detuned tone under it."""
    t = t_axis(seconds)
    n = noise(seconds)
    centres = np.geomspace(250.0, 2600.0, 6)
    stack = np.stack([band(n, c, c * 0.4) for c in centres])
    pos = (t / seconds) ** 1.3 * (len(centres) - 1)
    lo = np.clip(np.floor(pos).astype(int), 0, len(centres) - 2)
    k = pos - lo
    idx = np.arange(len(t))
    hiss = stack[lo, idx] * (1 - k) + stack[lo + 1, idx] * k
    curve = _hz(semis_from) * 2 ** (octaves * (t / seconds) ** 1.6)
    tone_ = filt(supersaw(curve, None, 3, 0.25), low=2400)
    return (hiss * 1.6 + tone_ * 0.3) * (t / seconds) ** 2.4 * np.clip((seconds - t) / 0.03, 0, 1)


def _reverse_cymbal(seconds=1.2):
    """A reversed crash: swells and stops dead at its end."""
    t = t_axis(seconds)
    n = noise(seconds)
    x = filt(n, high=1800, low=7000) + band(n, 3800, 900) * 0.8
    return x * (t / seconds) ** 3.2 * np.clip((seconds - t) / 0.015, 0, 1) * 0.7


def _reverse_swell(notes, seconds=0.4):
    """A reversed chord tail ("suck-back"): a choir chord ringing into a hall,
    played backwards, so it swells into the downbeat and stops dead."""
    d = 1.6
    left, right = _choir(notes, d, attack=0.01, release=0.05)
    tail = np.exp(-t_axis(d) / 0.45)
    hiss = filt(noise(d), low=4000, high=500) * 0.25
    out = []
    for x in (left, right):
        y = ((x + hiss) * tail)[::-1][-int(SR * seconds):]
        y = y * np.clip(t_axis(seconds) / 0.05, 0, 1) * np.clip((seconds - t_axis(seconds)) / 0.003, 0, 1)
        out.append(y)
    return np.stack(out, axis=1)


def _drone(seconds):
    """The cold open's drone: D a long way down, slowly opening."""
    t = t_axis(seconds)
    x = bl_osc(_hz(-43), seconds, "sine") * 0.4 + supersaw(_hz(-31), seconds, 3, 0.08) * 0.5
    x += supersaw(_hz(-24), seconds, 3, 0.1) * 0.25
    dark = filt(x, low=170)
    opened = filt(x, low=650)
    k = (t / seconds) ** 2
    return dark + (opened - dark) * k


def _wind(seconds):
    """Sea wind (left, right): low noise breathing, a different gust per side."""
    t = t_axis(seconds)
    out = []
    for ph in (0.0, 1.7):
        swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / 3.3 + ph) ** 2
        out.append(filt(noise(seconds), low=700, high=90) * swell)
    return out


# ---------------------------------------------------------------------------
# The mixer: buses, reverb sends, ducking, cut-outs, the slow-mo filter
# ---------------------------------------------------------------------------

class _Mix:
    BUSES = ("drums", "hits", "bass", "music", "lead", "fx", "breath")

    def __init__(self, seconds):
        self.n = int(SR * seconds)
        self.bus = {k: np.zeros((self.n, 2)) for k in self.BUSES}
        self.hall = np.zeros((self.n, 2))    # long, dark: impacts, brass, choir
        self.room = np.zeros((self.n, 2))    # shorter: drums, lead, keys

    def add(self, bus, x, at, gain=1.0, pan=0.5, hall=0.0, room=0.0):
        x = np.asarray(x, dtype=np.float64)
        if x.ndim == 1:
            x = x[:, None] * np.array([math.cos(pan * math.pi / 2), math.sin(pan * math.pi / 2)]) * math.sqrt(2)
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

    def add2(self, bus, left, right, at, gain=1.0, hall=0.0, room=0.0):
        m = min(len(left), len(right))
        self.add(bus, np.stack([left[:m], right[:m]], axis=1), at, gain, hall=hall, room=room)


def _duck(n, hits, depth, pre=0.04, release=0.45):
    """Sidechain gain: dips by `depth` over the `pre` seconds before each hit
    (a breath before the transient, so it lands on a clear floor) and swells
    back over `release` after it."""
    t = np.arange(n) / SR
    worst = np.zeros(n)
    for at in hits:
        a, b = int(SR * (at - pre)), min(n, int(SR * (at + release)))
        u = t[a:b] - at
        d = np.where(u < 0, depth * np.clip(1 + u / pre, 0, 1) ** 1.5, depth * np.clip(1 - u / release, 0, 1) ** 2)
        worst[a:b] = np.maximum(worst[a:b], d)
    return 1.0 - worst


def _gate(n, closed):
    """1, except 0 over each (start, end) span; 3 ms ramps, so a cut never clicks."""
    t = np.arange(n) / SR
    g = np.ones(n)
    for a, b in closed:
        g = np.minimum(g, np.clip((a - t) / 0.003, 0, 1) + np.clip((t - b + 0.003) / 0.003, 0, 1))
    return np.clip(g, 0, 1)


def _swept_lowpass(x, t0, t1, cutoff_at):
    """Low-passes x between t0 and t1 with a moving cutoff (Hz, a function of
    absolute time): a bank of zero-phase filtered copies, blended per sample
    in log-frequency. Outside the span (and wherever the cutoff is at the top)
    x is untouched."""
    a, b = int(SR * (t0 - 0.25)), int(SR * (t1 + 0.25))
    seg = x[a:b]
    t = (a + np.arange(len(seg))) / SR
    fc = np.clip(np.array([cutoff_at(v) for v in t]), 150.0, 20000.0)
    cut = np.geomspace(150.0, 20000.0, 14)
    bank = [filt_st(seg, c) for c in cut[:-1]] + [seg]
    pos = np.interp(np.log(fc), np.log(cut), np.arange(len(cut)))
    lo = np.clip(np.floor(pos).astype(int), 0, len(cut) - 2)
    k = (pos - lo)[:, None]
    stack = np.stack(bank)
    idx = np.arange(len(seg))
    out = x.copy()
    out[a:b] = stack[lo, idx] * (1 - k) + stack[lo + 1, idx] * k
    return out


def filt_st(x, low=None, high=None, slope=2.0):
    """filt() for an (n, 2) buffer."""
    return np.stack([filt(x[:, 0], low, high, slope), filt(x[:, 1], low, high, slope)], axis=1)


def _glue(x, thresh_db=-17.0, ratio=2.2, attack=0.006, release=0.22, block=64):
    """Bus compressor (feed-forward, RMS per 64-sample block): holds the mix
    together and lets the hits punch through without spiking."""
    n = len(x)
    nb = -(-n // block)
    p = np.pad((x * x).mean(axis=1), (0, nb * block - n)).reshape(nb, block).mean(axis=1)
    over = np.maximum(0.0, 10 * np.log10(p + 1e-12) - thresh_db) * (1 - 1 / ratio)
    ca, cr = math.exp(-block / (attack * SR)), math.exp(-block / (release * SR))
    g, cur = np.empty(nb), 0.0
    for i, v in enumerate(over):
        cur = v + (cur - v) * (ca if v > cur else cr)
        g[i] = cur
    per = np.interp(np.arange(n), (np.arange(nb) + 0.5) * block, g)
    return x * (10 ** (-per / 20))[:, None]


def _soft_clip(x, knee=0.55):
    """Linear below the knee, a tanh shoulder above: rounds the tallest peaks."""
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    return y


# ---------------------------------------------------------------------------
# The arrangement
# ---------------------------------------------------------------------------

def _cold_open(m):
    """0-6.0: drone and wind from silence, the motif on a detuned, running-down
    music box, the heartbeat from 1.6, tick-tock and a riser over the flashes
    (3.2-4.8), a reversed crash sucking into silence at 4.8; the roar's
    breath; the inhale into the impact."""
    d = 4.8
    t = t_axis(d)
    rise = np.clip(t / 1.6, 0, 1) ** 2 * (0.55 + 0.45 * (t / d) ** 2)
    m.add("fx", _drone(d) * rise, 0.0, 0.5)
    wl, wr = _wind(d)
    m.add2("fx", wl * rise, wr * rise, 0.0, 0.09)
    # The music box (the hook, half speed, then the answer), going flat as it runs down.
    box = HOOK_MINOR + [(3, 4, 1.0), (0, 5, 1.0), (-1, 6, 2.0)]
    for i, (s, b, ln) in enumerate(box):
        at = 0.3 + b * 2 * BEAT
        if at > 4.6:
            break
        x = _music_box(s + 12, 1.6, wow=0.18, flat=-0.08 * i - rng.uniform(0, 0.12))
        m.add("music", x, at, 0.16 * (1.0 - 0.08 * max(0, i - 4)), 0.62, hall=0.9)
    # The heartbeat on the beats, doubling over the flashes.
    hb = _heart()
    for b in range(4):
        m.add("hits", hb, 1.6 + b * BEAT, 0.42 + 0.06 * b)
    for k in range(8):
        m.add("hits", hb, 3.2 + k * 2 * STEP, 0.55 + 0.04 * k)
    # Tick-tock over the flashes, and an accent on each flash cut.
    for k in range(8):
        m.add("drums", _tick(k % 2 == 0), 3.2 + k * 2 * STEP, 0.16 + 0.02 * k, 0.35 if k % 2 else 0.65, room=0.3)
    for k, at in enumerate((3.2, 3.6, 4.0, 4.4)):
        m.add("drums", _taiko(66 - 3 * k, 0.9, 0.25), at, 0.5 + 0.08 * k, 0.5, room=0.4)
        m.add("hits", _metal(220.0 + 30 * k, 0.8, 0.25), at, 0.06, 0.3 + 0.13 * k, hall=0.6)
        m.add("fx", _whoosh(0.25, 0.12), at - 0.25, 0.12, 0.2 + 0.2 * k)
    m.add("fx", _riser(1.6, -26, 2.0), 3.2, 0.32, 0.5, hall=0.3)
    m.add("music", _tremolo([-31, -24, -19, -12], 1.6), 3.2, 0.2 * 1.0, hall=0.4)
    rc = _reverse_cymbal(1.0)
    m.add("fx", rc, d - 1.0, 0.3, 0.45)
    m.add("fx", _reverse_cymbal(1.0), d - 1.0, 0.3, 0.55)
    # The breath (4.8-6.0, after the cut): a sub swelling under the roar and an inhale into the hit.
    sw = 1.2
    ts = t_axis(sw)
    m.add("breath", bl_osc(_hz(-31), sw, "sine") * (ts / sw) ** 3 * np.clip((sw - ts) / 0.004, 0, 1), IMPACT - sw, 0.12)
    m.add("breath", _reverse_swell("Dm", 0.6), IMPACT - 0.6, 0.3)


def _title(m):
    """6.0: the BIG impact (sub boom, punch, metal, brass + choir stab), the
    logo hold over its tail, a ticking hat from 6.4, a lift into 8.0."""
    m.add("hits", _impact(1.2), IMPACT, 1.0, hall=0.35)
    m.add("music", _brass_chord("Dm", 1.9, attack=0.012, decay=0.35, sustain=0.45, release=0.6), IMPACT, 0.5, hall=0.5)
    cl, cr = _choir("Dm", 2.0, attack=0.02, release=0.5)
    m.add2("music", cl, cr, IMPACT, 0.4, hall=0.6)
    m.add("drums", _crash(3.2), IMPACT, 0.13, 0.4, hall=0.3)
    m.add("drums", _crash(3.2), IMPACT, 0.13, 0.6, hall=0.3)
    # The logo hold: choir and pad on Dm then Bb, the clock ticking.
    cl, cr = _choir("Bb", 1.2, attack=0.35, release=0.4, vowel=VOWEL_OH)
    m.add2("music", cl, cr, 6.9, 0.22, hall=0.6)
    m.add("music", _spad("Dm", 1.6, 900, 0.3, 0.5), 6.4, 0.18, hall=0.3)
    for k in range(8):
        m.add("drums", _hat(0.05), 6.4 + k * 2 * STEP, 0.06 + 0.012 * k, 0.65 if k % 2 else 0.35, room=0.2)
        m.add("drums", _tick(k % 2 == 0), 6.4 + k * 2 * STEP, 0.07, 0.5)
    for k in range(4):
        m.add("bass", _bass(-31, 0.18, 700), 7.2 + k * 2 * STEP, 0.35 + 0.05 * k)
    m.add("fx", _riser(0.8, -19, 1.0), 7.2, 0.18, 0.5)
    m.add("fx", _reverse_cymbal(0.6), GROOVE - 0.6, 0.25, 0.5)
    for k, at in enumerate((7.8, 7.9)):
        m.add("drums", _taiko(110, 0.5, 0.15), at, 0.18 + 0.06 * k, 0.4 + 0.2 * k, room=0.3)


# Taiko groove (per bar, sixteenth: (pitch Hz, gain)): low on the beats, mid on the backbeats, ghosts between.
TAIKO_BAR = {0: (64, 1.0), 3: (120, 0.35), 4: (92, 0.75), 6: (64, 0.55), 7: (120, 0.3), 8: (64, 0.9),
             10: (120, 0.35), 11: (120, 0.45), 12: (92, 0.8), 14: (64, 0.5), 15: (120, 0.4)}
GALLOP = (0, 2, 3)     # bass: "dum da-da" on every beat


def _world_groove(m, kicks):
    """8.0-14.0: the 15-world montage. Toms, 16th hats, the gallop bass, a
    whoosh into every cut (one per beat) and an accent on it; a string
    ostinato growing bar by bar, the choir from 11.2, building into the alphas."""
    order = ["Dm", "Bb", "F", "C"]
    for bar in range(4):
        t0 = GROOVE + bar * BAR
        name = order[bar]
        root = CH[name][0]
        lift = 0.75 + 0.1 * bar
        for step in range(16):
            at = t0 + step * STEP
            if at >= ALPHAS[0] - 1e-6:
                break
            if step in TAIKO_BAR:
                f, g = TAIKO_BAR[step]
                m.add("drums", _taiko(f, 0.8, 0.22 if f < 100 else 0.12), at, 0.62 * g * lift, 0.5 if f < 100 else 0.35 + 0.3 * (step % 2), room=0.35)
                if f < 70 and step in (0, 8):
                    kicks.append(at)
            m.add("drums", _hat(0.045), at, (0.05 if step % 2 == 0 else 0.032) * lift, 0.68, room=0.1)
            b, s = divmod(step, 4)
            if s in GALLOP:
                semis = root + (12 if b == 3 and s == 0 else 0)
                m.add("bass", _bass(semis, 0.19 if s == 0 else 0.09, 900 + 200 * bar, grit=0.15), at, 0.5)
            if step % 2 == 0:
                tones = _voicing(name, "pad")[1:]
                m.add("music", _strings(tones[(step // 2) % 3] + 12 * (step // 2 % 2), 0.19), at, 0.13 + 0.04 * bar,
                      0.15 if step % 4 else 0.85, room=0.4)
        m.add("music", _spad(name, BAR + 0.4, 1100 + 250 * bar, 0.2, 0.4), t0, 0.16, hall=0.2)
        if bar >= 2:
            cl, cr = _choir(name, BAR + 0.3, attack=0.25, release=0.3)
            m.add2("music", cl, cr, t0, 0.24 + 0.06 * (bar - 2), hall=0.5)
    # The cuts: a whoosh into each and an accent on it (alternating directions).
    for k in range(15):
        at = GROOVE + k * BEAT
        m.add("fx", _whoosh(0.28, 0.15), at - 0.28, 0.14 + 0.006 * k, 0.25 if k % 2 else 0.75)
        m.add("hits", _metal(196.0 if k % 2 else 165.0, 0.6, 0.18), at, 0.035 + 0.002 * k, 0.4 if k % 2 else 0.6, hall=0.4)
    m.add("hits", _impact(0.7), GROOVE, 0.85, hall=0.3)
    m.add("drums", _crash(2.4), GROOVE, 0.12, 0.45, hall=0.2)
    # The run-up into the alphas: a riser, a taiko roll and a reversed crash.
    m.add("fx", _riser(1.6, -14, 2.0), 12.4, 0.24, 0.5, hall=0.2)
    for k in range(8):
        m.add("drums", _taiko(130 - 5 * k, 0.4, 0.1), 13.2 + k * STEP, 0.2 + 0.04 * k, 0.3 + 0.05 * k, room=0.3)
    m.add("fx", _reverse_cymbal(0.8), ALPHAS[0] - 0.8, 0.3, 0.5)


def _alphas(m, kicks):
    """14.0-17.2: a heavy hit and a brass stab for each alpha (Dm Bb Gm A, the
    last one sharpening into a cliff), pounding eighths between, a roll into
    nothing at 17.2."""
    chords = ["Dm", "Bb", "Gm", "A"]
    for i, at in enumerate(ALPHAS):
        name = chords[i]
        m.add("hits", _impact(0.75 + 0.08 * i), at, 0.78 + 0.04 * i, hall=0.35)
        m.add("music", _brass_chord(name, 0.62, attack=0.01, decay=0.2, sustain=0.4, release=0.2), at, 0.5, hall=0.5)
        cl, cr = _choir(name, 0.75, attack=0.02, release=0.25)
        m.add2("music", cl, cr, at, 0.3, hall=0.6)
        m.add("drums", _crash(1.6), at, 0.08, 0.3 + 0.13 * i, hall=0.2)
        root = CH[name][0]
        for k in range(8):
            t = at + k * STEP
            m.add("drums", _hat(0.045), t, 0.045 if k % 2 == 0 else 0.03, 0.68)
            if k in (2, 4, 6):
                m.add("drums", _taiko(64 if k == 4 else 92, 0.6, 0.18), t, 0.45, 0.5, room=0.35)
            if k % 2 == 0:
                m.add("bass", _bass(root + (12 if k == 6 else 0), 0.18, 1100, grit=0.2), t, 0.5)
        kicks.append(at)
    m.add("music", _tremolo([-31, -19, -12, -7], 3.2, cutoff=2400), ALPHAS[0], 0.12, hall=0.3)
    # The roll into the cut-out (16.8-17.2), and the reversed swell inside it.
    for k in range(8):
        m.add("drums", _snare(0.2), 16.8 + k * 0.05, 0.12 + 0.03 * k, 0.4 + 0.03 * k, room=0.3)
    m.add("fx", _riser(0.8, -12, 1.0), 16.4, 0.18, 0.5)
    m.add("breath", _reverse_swell("Dm", DROP - CUT), CUT, 0.6)


def _drop(m, kicks):
    """17.6-27.2: THE DROP. Big kick and snare, a distorted gallop bass, the
    carnival motif on the lead (doubled by the band-organ calliope), choir
    pads, crashes. 22.0-22.8 is the slow-mo (see showreel_trailer)."""
    kick, snare = _kick(), _snare()
    for bar, name in enumerate(DROP_BARS):
        t0 = DROP + bar * BAR
        root = CH[name][0]
        for step in range(16):
            at = t0 + step * STEP
            slow = SLOWMO[0] - 1e-6 <= at < SLOWMO[1] - 1e-6
            b, s = divmod(step, 4)
            # Drums.
            if not slow:
                if step in (0, 6, 8, 10) or (bar % 2 == 1 and step == 15):
                    m.add("drums", kick, at, 0.85 if step in (0, 8) else 0.6)
                    kicks.append(at)
                if step in (4, 12):
                    m.add("drums", snare, at, 0.5, 0.5, room=0.5)
                    m.add("drums", _taiko(92, 0.6, 0.15), at, 0.3, 0.6, room=0.3)
                if step == 0:
                    m.add("drums", _taiko(60, 0.9, 0.25), at, 0.5, 0.5, room=0.3)
                m.add("drums", _hat(0.045), at, 0.05 if s == 2 else 0.032, 0.68, room=0.1)
                if s == 2:
                    m.add("drums", _hat(0.16, 0.35), at, 0.035, 0.3)
            # Bass: the gallop, the octave on the last beat; the last bar splits Bb | A.
            r = CH["A"][0] if bar == 5 and b >= 2 else root
            if s in GALLOP or (s == 1 and b == 3):
                semis = r + (12 if (b == 3 and s in (0, 2)) else 0)
                m.add("bass", _bass(semis, 0.19 if s == 0 else 0.09, 1500, drive=2.2, grit=0.55), at, 0.55)
        # Pads and choir under the chord, a brass stab on the downbeat.
        chord = name if bar < 5 else "Bb"
        m.add("music", _spad(chord, BAR + 0.4 if bar < 5 else BAR / 2 + 0.3, 1800, 0.05, 0.3), t0, 0.2, hall=0.25)
        cl, cr = _choir(chord, BAR if bar < 5 else BAR / 2, attack=0.08, release=0.3)
        m.add2("music", cl, cr, t0, 0.22, hall=0.4)
        if bar == 5:
            m.add("music", _spad("A", BAR / 2 + 0.3, 1800, 0.05, 0.3), t0 + BAR / 2, 0.14, hall=0.25)
            cl, cr = _choir("A", BAR / 2, attack=0.08, release=0.3)
            m.add2("music", cl, cr, t0 + BAR / 2, 0.17, hall=0.4)
        if bar in (0, 2, 4):
            m.add("music", _brass_chord(chord, 0.5, attack=0.008, decay=0.15, sustain=0.3, release=0.15), t0, 0.32, hall=0.4)
            m.add("drums", _crash(2.4), t0, 0.11, 0.35 + 0.15 * (bar // 2), hall=0.2)
        # The lead: the motif (plus the calliope an octave up, for the band organ).
        for semis, beat, beats in DROP_LEAD[bar]:
            at = t0 + beat * BEAT
            ln = beats * BEAT * 0.96
            m.add("lead", _lead_note(semis, ln + 0.05), at, 0.27, 0.5, room=0.45)
            m.add("lead", _calliope(semis + 12, ln), at, 0.075, 0.62, room=0.5)
    m.add("hits", _impact(1.0), DROP, 0.95, hall=0.35)
    m.add("music", _brass_chord("Dm", 0.9, attack=0.008, decay=0.3, sustain=0.35, release=0.3), DROP, 0.25, hall=0.4)
    # The slow-mo: a deep "whomp" at 22.0, a half-time heartbeat, the beat back at 22.8.
    m.add("hits", _sub(1.4, 90, 24, 0.25, 0.5), SLOWMO[0], 0.6)
    m.add("hits", _impact(0.4), SLOWMO[0], 0.55, hall=0.4)
    m.add("hits", filt(_whoosh(0.05, 0.75), low=900), SLOWMO[0] - 0.05, 0.4, 0.5, hall=0.6)
    m.add("hits", _heart(), SLOWMO[0] + 2 * BEAT * 0.5, 0.5)
    m.add("fx", _reverse_cymbal(0.5), SLOWMO[1] - 0.5, 0.3, 0.5)
    m.add("hits", _impact(0.6), SLOWMO[1], 0.75, hall=0.3)
    m.add("drums", _crash(2.2), SLOWMO[1], 0.12, 0.6, hall=0.2)
    # Into Endless: a riser over the last bar.
    m.add("fx", _riser(1.6, -12, 2.0), ENDLESS - 1.6, 0.22, 0.5, hall=0.2)
    m.add("fx", _reverse_cymbal(0.8), ENDLESS - 0.8, 0.28, 0.5)


def _endless(m, kicks):
    """27.2-30.4: Endless. Toms in double time, four on the floor, a choir
    climbing a step a beat over the D pedal, the snare rolling into 30.4."""
    kick, snare = _kick(), _snare()
    m.add("hits", _impact(0.85), ENDLESS, 0.85, hall=0.35)
    m.add("drums", _crash(2.6), ENDLESS, 0.13, 0.4, hall=0.2)
    top = [0, 1, 3, 5, 7, 8, 10, 12]
    for b in range(8):
        at = ENDLESS + b * BEAT
        m.add("drums", kick, at, 0.8)
        kicks.append(at)
        for s in range(4):
            t = at + s * STEP
            f = 64 if s == 0 else (120 if s % 2 else 92)
            m.add("drums", _taiko(f, 0.5, 0.16 if s == 0 else 0.09), t, (0.55 if s == 0 else 0.3) * (1 + 0.05 * b),
                  0.5 if s == 0 else (0.3 if s % 2 else 0.7), room=0.35)
            m.add("drums", _hat(0.045), t, 0.045 if s == 2 else 0.03, 0.68)
            semis = CH["Dm"][0] + (12 if s == 2 else 0)
            m.add("bass", _bass(semis, 0.09, 1400 + 120 * b, drive=2.2, grit=0.55), t, 0.5)
        if b < 4 and b % 2 == 1:
            m.add("drums", snare, at, 0.45, room=0.5)
        # The choir climbs: the top line a step a beat over D and A held below.
        voices = [-19, -12, top[b] - 9 if b < 4 else top[b] - 8, top[b]]
        cl, cr = _choir(voices, BEAT + 0.25, attack=0.06, release=0.22)
        m.add2("music", cl, cr, at, 0.28 + 0.04 * b, hall=0.5)
    m.add("music", _tremolo([-31, -19, -12, -7], 3.2, cutoff=2600), ENDLESS, 0.12, hall=0.3)
    for k in range(16):
        t = ENDLESS + 4 * BEAT + k * STEP * (1.0 if k < 8 else 1.0)
        m.add("drums", snare, t, 0.1 + 0.022 * k, 0.4 + 0.012 * k, room=0.4)
    m.add("fx", _riser(1.6, -12, 2.0), STOP - 1.6, 0.25, 0.5, hall=0.2)
    m.add("fx", _reverse_cymbal(0.8), STOP - 0.8, 0.3, 0.5)


def _last_ride(m):
    """30.4-32.0: the stop-hit, then a tension chord (D minor over an E-flat
    rub) with the clock and the heartbeat, sucking back into 32.0."""
    m.add("hits", _impact(1.1), STOP, 1.0, hall=0.4)
    tension = [-31, -24, -18, -12, -6]
    m.add("music", _brass_chord(tension, 1.6, attack=0.01, decay=0.5, sustain=0.5, release=0.3), STOP, 0.42, hall=0.5)
    m.add("music", _tremolo([-24, -18, -12, -6], 1.6, cutoff=2000), STOP, 0.16, hall=0.4)
    cl, cr = _choir([-19, -12, -6, -7], 1.6, attack=0.04, release=0.3, vowel=VOWEL_OH)
    m.add2("music", cl, cr, STOP, 0.2, hall=0.5)
    for b in range(1, 4):
        m.add("hits", _heart(), STOP + b * BEAT, 0.5)
    for k in range(6):
        m.add("drums", _tick(k % 2 == 0), STOP + 0.4 + k * 2 * STEP, 0.12, 0.35 if k % 2 else 0.65, room=0.3)
    m.add("fx", _reverse_cymbal(0.6), YOURS - 0.6, 0.22, 0.5)


def _make_it_yours(m, kicks):
    """32.0-35.2: the arsenal and the line-up. A sparkling 16th arp over Bb
    then C, a glint on every beat (one per weapon), a lighter groove, a run-up
    into the finale."""
    kick = _kick()
    m.add("hits", _impact(0.6), YOURS, 0.7, hall=0.3)
    m.add("drums", _crash(2.0), YOURS, 0.09, 0.6, hall=0.2)
    for b in range(8):
        at = YOURS + b * BEAT
        name = "Bb" if b < 4 else "C"
        root, tri = CH[name]
        tones = [root + 36 + tri[0], root + 36 + tri[1], root + 36 + tri[2], root + 48]
        for s in range(4):
            t = at + s * STEP
            semis = tones[(b * 4 + s) % 4 if b % 2 == 0 else (3 - s)]
            m.add("music", pluck(_hz(semis), 0.3, 10, 0.18, 1.3), t, 0.09, 0.25 if s % 2 else 0.75, room=0.5)
            m.add("drums", _hat(0.045), t, 0.04 if s == 2 else 0.026, 0.68)
            m.add("bass", _bass(root + (12 if s == 2 else 0), 0.09, 1100, grit=0.25), t, 0.42)
        m.add("music", _bell(tones[b % 4] + 12, 1.2), at, 0.07, 0.2 + 0.6 * (b % 2), hall=0.5)
        m.add("drums", kick, at, 0.7 if b % 2 == 0 else 0.55)
        kicks.append(at)
        if b % 2 == 1:
            m.add("drums", _snare(), at, 0.35, 0.5, room=0.5)
        m.add("fx", _whoosh(0.2, 0.12), at - 0.2, 0.07, 0.25 if b % 2 else 0.75)
    for name, at in (("Bb", YOURS), ("C", YOURS + BAR)):
        m.add("music", _spad(name, BAR + 0.3, 2000, 0.05, 0.3), at, 0.13, hall=0.25)
        cl, cr = _choir(name, BAR, attack=0.15, release=0.3)
        m.add2("music", cl, cr, at, 0.13, hall=0.4)
    for k in range(8):
        m.add("drums", _snare(0.2), FINALE - 0.8 + k * STEP, 0.08 + 0.035 * k, 0.4 + 0.03 * k, room=0.4)
    m.add("fx", _riser(1.6, -12, 2.0), FINALE - 1.6, 0.25, 0.5, hall=0.2)
    m.add("fx", _reverse_cymbal(1.0), FINALE - 1.0, 0.32, 0.5)


def _finale(m, kicks):
    """35.2: the biggest hit and the full theme in D major (the menu theme's
    key: the motif's minor third lifts), D | Bb C | D, epic half-time drums;
    38.4 the final slam and its ring-out, the music box closing the motif."""
    kick, snare = _kick(), _snare()
    m.add("hits", _impact(1.4), FINALE, 1.0, hall=0.4)
    m.add("drums", _crash(3.2), FINALE, 0.14, 0.35, hall=0.3)
    m.add("drums", _crash(3.2), FINALE, 0.14, 0.65, hall=0.3)
    chords = [("D", FINALE, BAR), ("Bb", FINALE + BAR, BEAT * 2), ("C", FINALE + BAR + 2 * BEAT, BEAT * 2)]
    for name, at, ln in chords:
        m.add("music", _brass_chord(name, ln + 0.15, attack=0.03, decay=0.6, sustain=0.6, release=0.2), at, 0.34, hall=0.45)
        cl, cr = _choir(name, ln + 0.2, attack=0.06, release=0.25)
        m.add2("music", cl, cr, at, 0.24, hall=0.55)
        m.add("music", _spad(name, ln + 0.3, 2000, 0.05, 0.3), at, 0.12, hall=0.25)
        root = CH[name][0]
        for k in range(int(round(ln / STEP))):
            s = k % 4
            if s in GALLOP:
                m.add("bass", _bass(root + (12 if k % 8 == 6 else 0), 0.19 if s == 0 else 0.09, 1500, drive=2.2, grit=0.5),
                      at + k * STEP, 0.55)
    # Half-time drums: big low drums on 1 and 3, the snare (and a taiko) on 3, hats.
    for b in range(8):
        at = FINALE + b * BEAT
        if b in (0, 2, 4, 6):
            m.add("drums", kick, at, 0.85)
            m.add("drums", _taiko(58, 1.0, 0.3), at, 0.6, 0.5, room=0.35)
            kicks.append(at)
        if b in (2, 6):
            m.add("drums", snare, at, 0.6, 0.5, room=0.6)
        for s in range(4):
            m.add("drums", _hat(0.045), at + s * STEP, 0.04 if s == 2 else 0.026, 0.68)
    for k in range(8):
        m.add("drums", _taiko(150 - 11 * k, 0.5, 0.12), SLAM - 0.8 + k * STEP, 0.26 + 0.03 * k, 0.75 - 0.06 * k, room=0.4)
    # The theme: brass section and choir on the motif, the calliope an octave up.
    for semis, beat, beats in FINALE_LEAD:
        at = FINALE + beat * BEAT
        ln = min(beats * BEAT * 0.97, 2.4)
        m.add("lead", _brass_note(semis - 12, ln + 0.1, bright=2600, attack=0.03, decay=0.4, sustain=0.75, release=0.12), at, 0.26, 0.45, room=0.3, hall=0.3)
        m.add("lead", _lead_note(semis, ln + 0.05), at, 0.22, 0.55, room=0.4)
        m.add("lead", _calliope(semis + 12, ln), at, 0.06, 0.62, room=0.5)
    m.add("fx", _reverse_cymbal(0.8), SLAM - 0.8, 0.32, 0.5)
    # 38.4: the final slam, the D major chord ringing out.
    m.add("hits", _impact(1.5), SLAM, 1.0, hall=0.45)
    m.add("drums", _crash(4.0), SLAM, 0.14, 0.35, hall=0.35)
    m.add("drums", _crash(4.0), SLAM, 0.14, 0.65, hall=0.35)
    ring = TOTAL - SLAM
    m.add("music", _brass_chord("D", 2.6, attack=0.01, decay=0.9, sustain=0.35, release=1.2), SLAM, 0.4, hall=0.6)
    cl, cr = _choir("D", ring - 0.4, attack=0.03, release=2.6)
    m.add2("music", cl, cr, SLAM, 0.24, hall=0.7)
    m.add("music", _spad([-19, -7, -3, 0, 5], ring - 0.3, 1500, 0.05, 2.8), SLAM, 0.18, hall=0.4)
    m.add("bass", _bass(-31, 2.2, 600) * np.exp(-t_axis(2.2) / 0.9), SLAM, 0.5)
    # The music box closes the motif in major over the logo.
    for i, (s, b, ln) in enumerate(HOOK_MAJOR + [(5, 4, 2.0)]):
        m.add("music", _music_box(s + 12, 1.8), 39.2 + b * BEAT, 0.2, 0.62, hall=0.9)


# The arranger's fader (seconds, dB): the cold open far under the rest, the
# logo hold settling, the montage building, a dip for the slow-mo, the
# finale on top. Changes at a hit land in the 5 ms before it.
FADER = ((0.0, -10.0), (4.8, -5.0), (5.995, -5.0), (6.0, 0.0), (7.0, -2.0), (7.995, -1.0), (8.0, -1.0),
         (13.99, 0.0), (14.0, -0.5), (17.595, -0.5), (17.6, 0.5), (21.995, 0.5), (22.06, -5.0), (22.4, -5.0),
         (22.8, 0.5), (27.195, 0.5), (27.2, 0.0), (30.395, 2.0), (30.4, 0.5), (31.995, -0.5), (32.0, 0.0),
         (35.195, 0.0), (35.2, 2.5), (38.4, 2.5), (39.4, 0.5), (41.6, -5.0), (TOTAL + 4.0, -8.0))


def _slowmo_cutoff(t):
    """22.0-22.8: the filter dives at 22.0, holds under the slow-mo, opens back up by 22.8."""
    a, b = SLOWMO
    if t < a or t >= b:
        return 20000.0
    if t < a + 0.06:
        return 20000.0 * (320.0 / 20000.0) ** ((t - a) / 0.06)
    if t < a + 0.4:
        return 320.0
    return 320.0 * (20000.0 / 320.0) ** (max(0.0, (t - a - 0.4) / 0.4) ** 1.8)


def showreel_trailer():
    m = _Mix(WORK)
    kicks = []
    _cold_open(m)
    _title(m)
    _world_groove(m, kicks)
    _alphas(m, kicks)
    _drop(m, kicks)
    _endless(m, kicks)
    _last_ride(m)
    _make_it_yours(m, kicks)
    _finale(m, kicks)
    n = m.n
    # Sidechain: everything tonal ducks under the hits (deep, slow) and the kicks (light, quick).
    duck_hits = _duck(n, HITS, 0.6, 0.04, 0.45)[:, None]
    pre_hits = _duck(n, HITS, 0.6, 0.04, 0.012)[:, None]
    duck_kick = pump(n, kicks, depth=0.3, release=0.16, attack=0.003)[:, None]
    hall = reverb(m.hall[:, 0], m.hall[:, 1], seconds=3.4, predelay=0.03, dark=2600, low_cut=180, seed=61)
    room = reverb(m.room[:, 0], m.room[:, 1], seconds=1.3, predelay=0.012, dark=3600, low_cut=250, seed=62)
    music = m.bus["music"]
    music = chorus(music.mean(axis=1)) * 0.55 + music * 0.6     # wider pads and choir
    mix = (m.bus["drums"] * 0.95 * pre_hits + m.bus["hits"] + m.bus["fx"] * duck_hits
           + (m.bus["bass"] + music) * duck_hits * duck_kick + m.bus["lead"] * duck_hits * (0.3 + 0.7 * duck_kick)
           + (hall * 0.55 * duck_kick + room * 0.4) * pre_hits)
    # The slow-mo filter, the fader, then the dead stops (4.8 into the black, 17.2 the cut-out).
    mix = _swept_lowpass(mix, SLOWMO[0], SLOWMO[1], _slowmo_cutoff)
    ft, fdb = zip(*FADER)
    mix = mix * (10 ** (np.interp(np.arange(n) / SR, ft, fdb) / 20))[:, None]
    mix = mix * _gate(n, ((4.8, IMPACT), (CUT, DROP)))[:, None] + m.bus["breath"]
    # Keep the low end in the middle (the side channel is high-passed at 140 Hz) and open up the rest.
    mid, side = (mix[:, 0] + mix[:, 1]) * 0.5, (mix[:, 0] - mix[:, 1]) * 0.5
    side = filt(side, high=140) * 1.4
    mix = np.stack([mid + side, mid - side], axis=1)
    # Voicing: a little less 200-400 Hz mud, a touch of presence, the air kept gentle.
    mix = eq(mix, bells=((50.0, -4.0, 0.7), (300.0, -2.0, 0.8), (1600.0, 2.0, 0.6), (3000.0, 1.5, 0.7), (9000.0, 0.0, 0.6)), shelf=(4500.0, 3.0))
    mix = _glue(mix / (np.max(np.abs(mix)) + 1e-9) * 0.9, thresh_db=-15.0, ratio=1.8)
    mix = _soft_clip(mix / (np.max(np.abs(mix)) + 1e-9) * 1.1)
    out = mix[: int(SR * TOTAL)]
    t = t_axis(TOTAL)
    return out * np.clip((TOTAL - t) / 1.2, 0, 1)[:, None] ** 2


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
