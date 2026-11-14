"""Prize Capsule and Prize Print sounds: the coin going in, the crank's
ratchet, the capsule rattling down the chute and wobbling, the pop, a reveal
chime per rarity, the shine meter's tick, the rare-print shimmer, the
trade-up press and Prize Tokens.

    python tools/gen_audio.py prints

Soft and round on purpose (the player hears them many times in a row):
sines and triangles, gentle attacks, everything low-passed below ~7 kHz, no
square waves, no harsh noise bursts. `prz_tick` and `prz_crank` are played at
rising pitches by the UI, so they carry no pitch movement of their own.
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


def _reveal(notes, seconds, sparkle, gain=0.5):
    out = silence(seconds)
    for i, n in enumerate(notes):
        place(out, _bell(note(n), seconds - i * 0.07, bright=0.25), i * 0.075, gain)
    if sparkle:
        for k in range(sparkle):
            place(out, _bell(note(notes[-1] + 12 + (k % 3) * 5), 0.35, 0.18, bright=0.1), 0.3 + k * 0.06, 1.0)
    return filt(out, low=7000)


def prz_reveal_0():
    """Common: a warm major third."""
    return _reveal((0, 4, 7), 0.9, 0)


def prz_reveal_1():
    """Rare: a brighter arpeggio."""
    return _reveal((2, 6, 9, 14), 1.0, 2)


def prz_reveal_2():
    """Epic: a rising arpeggio with a little sparkle."""
    return _reveal((3, 7, 10, 15, 19), 1.2, 4)


def prz_reveal_3():
    """Legendary: a full fanfare of bells with a sparkle shower."""
    out = _reveal((0, 4, 7, 12, 16, 19, 24), 1.6, 8, gain=0.45)
    place(out, _bell(note(-12), 1.5, bright=0.1), 0.0, 0.35)
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


def prz_tradeup():
    """The trade-up press: a soft whoosh into a low thump and a bell."""
    out = silence(0.9)
    place(out, filt(noise(0.35), low=2400, high=300) * env(0.35, 0.25, 0.1, power=1.5), 0.0, 0.3)
    place(out, clunk(110, 0.14), 0.33, 0.55)
    place(out, _bell(note(12), 0.5, bright=0.2), 0.36, 0.4)
    return out


def prz_token():
    """Prize Tokens: two soft wooden tokens clicking together and a chime."""
    out = silence(0.45)
    place(out, _tick(note(9), 0.05), 0.0, 0.6)
    place(out, _tick(note(12), 0.05), 0.07, 0.55)
    place(out, _bell(note(21), 0.35, bright=0.15), 0.1, 0.3)
    return filt(out, low=6500)


SOUNDS = [prz_insert, prz_crank, prz_rattle, prz_shake, prz_pop, prz_reveal_0, prz_reveal_1, prz_reveal_2, prz_reveal_3,
          prz_tick, prz_variant, prz_tradeup, prz_token]
VARIANTS = []
LOOPS = {}
MUSIC = {}
