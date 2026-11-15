"""Prize Capsule and Prize Print sounds: the coin going in, the crank's
ratchet, the capsule rattling down the chute and wobbling, the pop, the
opening cue (prz_build swelling under the wobble, prz_reveal_<rarity>
resolving it), the camera whoosh, the trait stamps, the shine sweep, a
special serial, the rare-print shimmer, Prize Tokens, and Prize Fusion (the
trade-up: pods, charge, data streams, hologram and its own sting).

    python tools/gen_audio.py prints

Soft and round on purpose (the player hears them many times in a row):
sines, plucks and pads from the band-limited helpers (bl_osc, pluck, adsr),
gentle attacks, the effects low-passed below ~7 kHz and the cues rolled off
above ~10 kHz (air, never fizz), no square waves, no harsh noise bursts. `prz_tick`, `prz_crank` and
`prz_fuse_slot` are played at rising pitches by the UI.
"""
from gen_audio import *  # noqa: F401,F403  (tone, blip, env, place, silence, note, ...)


def _bell(freq, seconds, gain=1.0, bright=0.3):
    """A soft mallet bell: a sine with gentle inharmonic partials."""
    out = silence(seconds)
    for ratio, g, decay in ((1.0, 1.0, 1.0), (2.0, bright, 0.55), (2.76, bright * 0.45, 0.35), (4.07, bright * 0.18, 0.2)):
        place(out, tone(freq * ratio, seconds, "sine") * env(seconds, 0.004, seconds * decay, power=2.0) * g, 0.0)
    return out * gain


def _tick(freq, seconds=0.05, gain=1.0):
    """A small wooden tick: a short triangle blip with a soft click."""
    out = blip(freq, seconds, "tri", seconds * 0.6) * 0.8
    place(out, band(noise(0.012), 2200, 1200) * env(0.012, 0.0005, power=3.0), 0.0, 0.25)
    return out * gain


def _plastic(seconds, centre, gain=1.0):
    """A hollow plastic knock (the capsule against the chute)."""
    body = tone(centre, seconds, "sine") * env(seconds, 0.001, seconds * 0.5, power=2.5)
    place(body, band(noise(seconds), centre * 2.2, centre) * env(seconds, 0.001, seconds * 0.3, power=3.0), 0.0, 0.35)
    return body * gain


def prz_insert():
    """A coin into the machine: a soft drop, a roll and a little latch."""
    out = silence(0.42)
    place(out, _tick(note(14), 0.06), 0.0, 0.5)
    for i, t in enumerate((0.07, 0.12, 0.16, 0.19)):
        place(out, _plastic(0.05, 900 - i * 60), t, 0.35 - i * 0.05)
    place(out, clunk(260, 0.08), 0.28, 0.35)
    return filt(out, low=6500)


def prz_crank():
    """One ratchet step of the crank (played six times per turn, rising)."""
    out = silence(0.09)
    place(out, _tick(note(-3), 0.05), 0.0, 0.7)
    place(out, _plastic(0.04, 520), 0.01, 0.3)
    return filt(out, low=5000)


def prz_rattle():
    """The capsule tumbling down the chute and settling in the tray."""
    out = silence(0.75)
    t = 0.0
    gap = 0.05
    for i in range(9):
        place(out, _plastic(0.06, 760 + (i % 3) * 90), t, 0.5 - i * 0.035)
        t += gap
        gap *= 1.18
    place(out, clunk(180, 0.1), t, 0.3)
    return filt(out, low=6000)


def prz_shake():
    """The capsule wobbling before it opens: a soft hollow double knock."""
    out = silence(0.2)
    place(out, _plastic(0.07, 680), 0.0, 0.55)
    place(out, _plastic(0.07, 610), 0.07, 0.4)
    return filt(out, low=5500)


def prz_pop():
    """The capsule pops open: a round cork-like pop and a soft airy puff."""
    out = silence(0.5)
    place(out, sweep(520, 180, 0.09, "sine") * env(0.09, 0.001, 0.07, power=2.0), 0.0, 0.8)
    place(out, filt(noise(0.35), low=3500, high=400) * env(0.35, 0.01, 0.25, power=2.0), 0.01, 0.18)
    place(out, _bell(note(19), 0.4, bright=0.15), 0.04, 0.2)
    return out


def prz_tick():
    """One step of the shine meter (played at a rising pitch)."""
    return _tick(note(19), 0.04, 0.8)


def prz_variant():
    """A rare print: a soft shimmering chord swell."""
    seconds = 1.2
    out = silence(seconds)
    for i, n in enumerate((7, 11, 14, 19, 23)):
        shimmer = tone(note(n), seconds, "sine", vibrato=0.004, vib_rate=6.0 + i)
        place(out, shimmer * env(seconds, 0.12, seconds * 0.8, power=1.6) * 0.22, i * 0.03)
    for k in range(6):
        place(out, _bell(note(26 + (k * 5) % 12), 0.3, bright=0.1), 0.15 + k * 0.08, 0.15)
    return filt(out, low=7000)


def prz_token():
    """Prize Tokens: two soft wooden tokens clicking together and a chime."""
    out = silence(0.45)
    place(out, _tick(note(9), 0.05), 0.0, 0.6)
    place(out, _tick(note(12), 0.05), 0.07, 0.55)
    place(out, _bell(note(21), 0.35, bright=0.15), 0.1, 0.3)
    return filt(out, low=6500)



# ---------------------------------------------------------------------------
# The opening cue: prz_build swells under the capsule's wobble (the reveal
# starts it part-way in, so its peak always lands on the burst), then
# prz_reveal_<rarity> resolves it: Common light, Legendary triumphant.
# Key of D; soft mallets, plucks and a warm pad; Legendary adds soft brass.
# ---------------------------------------------------------------------------

D = -7  # D4, in semitones from A4


def _glide(f0, f1, seconds, curve=1.0):
    """A per-sample frequency glide for bl_osc."""
    k = (t_axis(seconds) / max(seconds, 1e-9)) ** curve
    return f0 + (f1 - f0) * k


def _pad(semis, seconds, attack=0.4, gain=1.0, bright=1600.0):
    """A warm pad chord: three detuned band-limited saws per note and a sine,
    low-passed, slow attack."""
    out = silence(seconds)
    for n in semis:
        f = note(n)
        voice = sum(bl_osc(f * 2 ** (d / 1200.0), seconds, "saw", phase=rng.uniform()) for d in (-7, 0, 7)) / 3.0
        out += voice * 0.5 + bl_osc(f, seconds, "sine") * 0.4
    out = filt(out, low=bright) * adsr(seconds, attack, seconds, 1.0, min(0.5, seconds * 0.4))
    return out * gain / max(1, len(semis))


def _brass(semis, seconds, gain=1.0):
    """Soft brass: band-limited saws that swell, a touch of delayed vibrato."""
    out = silence(seconds)
    t = t_axis(seconds)
    for n in semis:
        f = note(n) * (1.0 + 0.003 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.3, 0, 1))
        out += bl_osc(f, None, "saw") * 0.6 + bl_osc(f, None, "sine") * 0.5
    voiced = filt(out, low=2600) * 0.6 + filt(out, low=900) * 0.4
    return voiced * adsr(seconds, 0.06, 0.4, 0.75, min(0.25, seconds * 0.4)) * gain / max(1, len(semis))


def _timp(freq, seconds=0.9, gain=1.0):
    """A soft timpani: a sine that sags a little in pitch and a felt thump."""
    body = sweep(freq * 1.06, freq, seconds, "sine", 0.3) * env(seconds, 0.003, seconds, power=2.2)
    place(body, filt(noise(0.05), low=600) * env(0.05, 0.001, power=2.0), 0.0, 0.25)
    return body * gain


def prz_build():
    """The wobble's swell (4 s, ending on its peak): a timpani roll and a
    plucked pentatonic run that both speed up, over a pad that rises a step
    and opens, and a shaker swell into the burst."""
    seconds = 4.0
    out = silence(seconds)
    t, gap, k = 0.0, 0.42, 0
    while t < seconds - 0.05:
        place(out, _timp(note(D - 12 if k % 2 == 0 else D - 5), 0.6), t, 0.15 + 0.55 * (t / seconds) ** 1.6)
        t += gap
        gap = max(0.06, gap * 0.9)
        k += 1
    scale = (0, 2, 4, 7, 9)
    t, gap, i = 0.2, 0.3, 0
    while t < seconds - 0.05:
        place(out, pluck(note(D + 12 + scale[i % 5] + 12 * ((i // 5) % 2)), 0.5, 10, 0.25, 1.2), t, 0.12 + 0.2 * (t / seconds))
        t += gap
        gap = max(0.07, gap * 0.9)
        i += 1
    ramp = np.clip(t_axis(seconds) / seconds, 0, 1)
    out += _pad((D, D + 4, D + 7), seconds, attack=3.2, gain=0.9, bright=1200.0) * (1.0 - ramp * 0.6)
    out += _pad((D + 2, D + 7, D + 11), seconds, attack=3.8, gain=0.7, bright=2600.0) * ramp
    place(out, filt(noise(seconds), low=4500, high=2000) * ramp ** 3 * 0.2, 0.0)
    return filt(out, low=10000)


def _resolve(chord, arp, seconds, timp=True, sparkle=0, brass=()):
    out = silence(seconds)
    if timp:
        place(out, _timp(note(D - 12), 1.2), 0.0, 0.6)
    for i, n in enumerate(arp):
        place(out, pluck(note(n), min(1.2, seconds), 12, 0.6, 1.1), i * 0.07, 0.3)
        place(out, _bell(note(n + 12), min(1.0, seconds), bright=0.15), i * 0.07 + 0.01, 0.12)
    place(out, _pad(chord, seconds, attack=0.15, bright=2200.0), 0.0, 0.8)
    for at, semis, length in brass:
        place(out, _brass(semis, length), at, 0.9)
    for k in range(sparkle):
        place(out, _bell(note(arp[-1] + 12 + (k * 7) % 12), 0.45, bright=0.1), 0.25 + k * 0.07, 0.12)
    return filt(out, low=10000)


def prz_reveal_0():
    """Common: a light, friendly D major chord and a little pluck run."""
    return _resolve((D, D + 4, D + 7), (D + 12, D + 16, D + 19), 1.4, timp=False)


def prz_reveal_1():
    """Rare: a brighter major-seventh lift with a shimmer."""
    return _resolve((D, D + 7, D + 11, D + 16), (D + 12, D + 16, D + 19, D + 23), 1.8, sparkle=3)


def prz_reveal_2():
    """Epic: up a step to E, a rising arpeggio and a sparkle shower."""
    e = D + 2
    return _resolve((e, e + 4, e + 7, e + 11), (e + 7, e + 12, e + 16, e + 19, e + 24), 2.4, sparkle=6)


def prz_reveal_3():
    """Legendary: a triumphant soft-brass fanfare (D - G - A - D) over
    timpani, then a held chord under a sparkle shower."""
    fanfare = ((0.0, (D, D + 7, D + 12), 0.32), (0.32, (D + 5, D + 9, D + 12), 0.2),
               (0.52, (D + 7, D + 11, D + 14), 0.28), (0.82, (D + 12, D + 16, D + 19), 2.6))
    out = _resolve((D, D + 4, D + 7, D + 12), (D + 12, D + 16, D + 19, D + 24, D + 28), 3.8, sparkle=10, brass=fanfare)
    for at in (0.52, 0.66, 0.82):
        place(out, _timp(note(D - 12 if at == 0.82 else D - 5), 1.4), at, 0.45)
    return out


def prz_whoosh():
    """The camera pushing in on the chute: a soft airy whoosh."""
    seconds = 0.6
    t = t_axis(seconds)
    air = noise(seconds)
    swell = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2
    return filt(filt(air, low=1800, high=300) * swell * 0.6 + filt(air, low=4200, high=1500) * swell ** 2 * 0.25, low=7000)


def prz_stamp():
    """A trait stamping in: a soft rubber-stamp thump and a paper slap."""
    out = silence(0.4)
    place(out, sweep(150, 70, 0.16, "sine") * env(0.16, 0.001, 0.15, power=2.0), 0.0, 0.9)
    place(out, filt(noise(0.06), low=2600, high=500) * env(0.06, 0.001, power=2.5), 0.0, 0.35)
    place(out, pluck(note(D + 7), 0.3, 6, 0.12), 0.01, 0.18)
    return filt(out, low=6000)


def prz_shine():
    """The shine sweeping across the print: a glassy rising shimmer."""
    seconds = 0.9
    out = silence(seconds)
    for i, n in enumerate((D + 19, D + 24, D + 28, D + 31, D + 36)):
        place(out, _bell(note(n), 0.5, bright=0.12), 0.05 + i * 0.09, 0.22)
    swell = np.sin(np.pi * np.clip(t_axis(seconds) / seconds, 0, 1))
    place(out, filt(noise(seconds), low=7000, high=3000) * swell * 0.06, 0.0)
    return filt(out, low=10000)


def prz_serial():
    """A low or lucky serial: a cascade of small bells over a warm chord."""
    seconds = 1.3
    out = silence(seconds)
    for k in range(9):
        place(out, _bell(note(D + 24 + (k * 5) % 12 - (k // 3) * 2), 0.5, bright=0.12), k * 0.05, 0.2)
    place(out, _pad((D + 12, D + 16, D + 19), seconds, attack=0.05, gain=0.6, bright=2600.0), 0.0)
    return filt(out, low=10000)


# ---------------------------------------------------------------------------
# Prize Fusion (the trade-up): electronic, still soft. A charge that sits on
# B minor resolves to D major when the new print forms.
# ---------------------------------------------------------------------------

def prz_fuse_slot():
    """A print locking into a fusion pod: a soft rounded blip (played rising)."""
    seconds = 0.22
    out = bl_osc(_glide(note(D + 12), note(D + 19), seconds), None, "sine") * adsr(seconds, 0.004, 0.08, 0.0, 0.05)
    place(out, bl_osc(note(D + 24), seconds, "sine") * adsr(seconds, 0.004, 0.05, 0.0, 0.05), 0.02, 0.25)
    return filt(out, low=6000)


def prz_fuse_charge():
    """The chamber spinning up (2.8 s): a rising hum, a whirr that speeds up
    with the rings, a low pad and ticks that close in."""
    seconds = 2.8
    ramp = np.clip(t_axis(seconds) / seconds, 0, 1)
    hum_f = _glide(note(D - 24), note(D - 12), seconds, 1.6)
    hum = filt(bl_osc(hum_f, None, "saw") * 0.4 + bl_osc(hum_f * 2, None, "sine") * 0.4, low=900) * (0.3 + 0.7 * ramp)
    whirr_phase = np.cumsum(3.0 + 18.0 * ramp ** 1.5) / SR
    whirr = bl_osc(_glide(note(D + 7), note(D + 19), seconds, 1.4), None, "sine") * (0.5 + 0.5 * np.sin(2 * np.pi * whirr_phase))
    out = hum + whirr * 0.18 * ramp + _pad((D - 3, D, D + 4), seconds, attack=2.0, gain=0.5, bright=1400.0)
    at, gap = 0.3, 0.32
    while at < seconds - 0.05:
        place(out, bl_osc(note(D + 24), 0.05, "sine") * adsr(0.05, 0.002, 0.02, 0.0, 0.02), at, 0.08 + 0.1 * at / seconds)
        at += gap
        gap = max(0.06, gap * 0.85)
    return filt(out, low=10000)


def prz_fuse_stream():
    """The prints dissolving into data streams (1.4 s): a fast sparkling
    arpeggio climbing the octaves over a soft airy rush."""
    seconds = 1.4
    out = silence(seconds)
    for i, n in enumerate((0, 3, 7, 10, 12, 15, 19, 22, 24, 27, 31, 34, 36)):
        place(out, pluck(note(D - 3 + n), 0.25, 6, 0.08, 1.4), i * 0.075, 0.2)
    place(out, filt(noise(seconds), low=5000, high=1200) * np.sin(np.pi * t_axis(seconds) / seconds) ** 2 * 0.12, 0.0)
    return filt(out, low=10000)


def prz_fuse_form():
    """The hologram scanning the new print into being (1.6 s): a resonant
    sweep up and a shimmering chord that settles."""
    seconds = 1.6
    t = t_axis(seconds)
    out = silence(seconds)
    rise = filt(bl_osc(_glide(note(D - 5), note(D + 19), seconds * 0.7, 0.7), None, "saw"), low=2400)
    place(out, rise * adsr(seconds * 0.7, 0.05, 0.4, 0.5, 0.2), 0.0, 0.3)
    shimmer = sum(bl_osc(note(n) * (1 + 0.004 * np.sin(2 * np.pi * (5 + i) * t)), None, "sine")
                  for i, n in enumerate((D + 12, D + 16, D + 19, D + 23)))
    out += shimmer * adsr(seconds, 0.5, seconds, 1.0, 0.4) * 0.12
    return filt(out, low=10000)


def prz_fuse_sting():
    """Prize Fusion's sting (2.6 s): a synth stab stepping from B minor to
    D major, a low drop, an arpeggio and a held chord."""
    seconds = 2.6
    out = silence(seconds)
    place(out, _pad((D - 3, D, D + 4), 0.35, attack=0.01, bright=2400.0), 0.0, 0.7)
    place(out, _pad((D, D + 4, D + 7, D + 12), seconds - 0.3, attack=0.02, bright=2800.0), 0.3, 0.8)
    place(out, sweep(90, 45, 0.3, "sine") * env(0.3, 0.002, 0.3, power=2.0), 0.3, 0.7)
    for i, n in enumerate((D + 12, D + 16, D + 19, D + 24, D + 28, D + 31)):
        place(out, pluck(note(n), 0.6, 8, 0.25, 1.3), 0.32 + i * 0.06, 0.22)
    return filt(out, low=10000)


SOUNDS = [prz_insert, prz_crank, prz_rattle, prz_shake, prz_pop, prz_reveal_0, prz_reveal_1, prz_reveal_2, prz_reveal_3,
          prz_tick, prz_variant, prz_token, prz_build, prz_whoosh, prz_stamp, prz_shine, prz_serial,
          prz_fuse_slot, prz_fuse_charge, prz_fuse_stream, prz_fuse_form, prz_fuse_sting]
VARIANTS = []
LOOPS = {}
MUSIC = {}
