"""Rounds sounds: a sting for every wave kind, the surge siren, the alpha's
entrance, windup, slam, volley, phase and fall, the bounty target's cues and
the checkpoint chime.

    python tools/gen_audio.py rounds
"""
from gen_audio import *  # noqa: F401,F403  (tone, sweep, noise, env, filt, place, silence, note, blip, jingle, ...)

MUSIC = {}
LOOPS = {}


def _brass(freq, seconds, gain=1.0, cutoff=2600):
    """Synth-brass stab: detuned saws through a low-pass."""
    body = tone(freq, seconds, "saw") + tone(freq * 1.007, seconds, "saw") * 0.8 + tone(freq * 0.5, seconds, "square") * 0.35
    return filt(body, low=cutoff) * env(seconds, 0.015, seconds, sustain=0.4, power=1.2, release=0.08) * gain


def _drum(pitch, seconds, gain=1.0):
    """Big tom: a falling sine with a short noise skin."""
    out = sweep(pitch * 1.8, pitch, seconds, "sine", 0.4) * env(seconds, 0.002, power=1.8)
    place(out, filt(noise(0.05), low=1800) * env(0.05, 0.001, power=2.0), 0.0, 0.35)
    return out * gain


def _bell(freq, seconds, gain=1.0):
    out = silence(seconds)
    for ratio, g, decay in ((1.0, 1.0, 0.9), (2.0, 0.5, 0.5), (2.76, 0.3, 0.35), (5.4, 0.15, 0.18)):
        place(out, tone(freq * ratio, seconds, "sine") * env(seconds, 0.002, seconds * decay, power=1.8) * g, 0.0)
    return out * gain


def _coins(count, start, step, gain=0.5):
    out = silence(count * step + 0.35)
    for i in range(count):
        place(out, _bell(note(start + (i * 7) % 12), 0.3, gain), i * step)
    return out


# --- wave kinds --------------------------------------------------------------------

def rounds_wave_rush():
    """Quick rising run: they are fast."""
    out = silence(0.8)
    for i, n in enumerate((-5, -2, 0, 3, 5, 7, 10, 12)):
        place(out, blip(note(n), 0.11, "square"), i * 0.05, 0.5)
    place(out, sweep(300, 1500, 0.45, "saw", 1.5) * env(0.45, 0.25, power=0.6, release=0.06), 0.0, 0.18)
    return out


def rounds_wave_siege():
    """Three heavy drums and a low brass fall: something big is coming."""
    out = silence(1.5)
    for i in range(3):
        place(out, _drum(62, 0.5), i * 0.26, 0.9)
    place(out, _brass(note(-29), 0.7, 0.6, 1400), 0.78)
    place(out, _brass(note(-34), 0.7, 0.5, 1200), 0.82)
    return out


def rounds_wave_ambush():
    """A reversed swell into a dissonant stab: from every side."""
    swell = (noise(0.5) * 0.4 + tone(note(-14), 0.5, "saw") * 0.6) * np.linspace(0.0, 1.0, int(SR * 0.5)) ** 2.5
    out = silence(1.2)
    place(out, filt(swell, low=3000), 0.0, 0.6)
    for n in (-14, -8, -1):
        place(out, _brass(note(n), 0.55, 0.4, 3200), 0.5)
    place(out, _drum(70, 0.4), 0.5, 0.8)
    return out


def rounds_wave_ranged():
    """Twangy two-note call: specialists at range."""
    out = silence(0.9)
    for i, n in enumerate((7, 4, 7, 12)):
        twang = sweep(note(n) * 1.06, note(n), 0.2, "tri", 0.3) * env(0.2, 0.002, power=1.4)
        place(out, twang, i * 0.12, 0.7)
        place(out, tone(note(n + 12), 0.14, "sine") * env(0.14, 0.002, power=2.0), i * 0.12, 0.2)
    return out


def rounds_wave_bounty():
    """Wave start with a shower of coins."""
    out = silence(1.1)
    place(out, jingle([-5, 0, 4, 7], 0.085, 0.2), 0.0, 0.6)
    place(out, _coins(6, 12, 0.07, 0.35), 0.3)
    return out


# --- surge -------------------------------------------------------------------------

def rounds_surge_siren():
    """Two-tone warning siren, twice."""
    out = silence(1.7)
    for i in range(2):
        up = sweep(520, 880, 0.36, "square", 0.8) * env(0.36, 0.02, sustain=0.8, power=1.0, release=0.04)
        down = sweep(880, 520, 0.36, "square", 1.2) * env(0.36, 0.02, sustain=0.8, power=1.0, release=0.04)
        place(out, filt(up, low=2600), i * 0.8, 0.4)
        place(out, filt(down, low=2600), i * 0.8 + 0.38, 0.4)
    return out


def rounds_surge_hit():
    """The surge lands: a gate slam and a crowd rumble."""
    out = silence(0.9)
    place(out, _drum(55, 0.6), 0.0, 1.0)
    place(out, filt(noise(0.7), low=420) * env(0.7, 0.05, power=1.2), 0.03, 0.5)
    return out


# --- alpha -------------------------------------------------------------------------

def rounds_boss_intro():
    """Ominous low brass fanfare over a drum roll."""
    out = silence(2.3)
    for i in range(8):
        place(out, _drum(58, 0.3), i * 0.09, 0.3 + 0.07 * i)
    for i, n in enumerate((-29, -29, -26, -22)):
        place(out, _brass(note(n), 0.5 if i < 3 else 1.1, 0.55, 1900), 0.75 + i * 0.26)
        place(out, _brass(note(n - 12), 0.5 if i < 3 else 1.1, 0.45, 1200), 0.75 + i * 0.26)
    place(out, sweep(90, 38, 0.9, "sine") * env(0.9, 0.004, power=1.4), 1.53, 0.8)
    return out


def rounds_boss_windup():
    """Rising growl while the alpha rears up."""
    d = 1.1
    growl = sweep(70, 190, d, "saw", 1.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_axis(d)))
    out = filt(growl, low=1500) * np.linspace(0.2, 1.0, int(SR * d)) ** 1.5
    place(out, sweep(400, 1100, d, "sine", 2.0) * np.linspace(0.0, 0.25, int(SR * d)), 0.0)
    return fade(out, 0.02, 0.03)


def rounds_boss_slam():
    """The shockwave: a deep impact and a ring of debris."""
    out = silence(1.2)
    place(out, sweep(120, 30, 0.8, "sine", 0.5) * env(0.8, 0.002, power=1.3), 0.0, 1.0)
    place(out, filt(noise(0.6), low=900) * env(0.6, 0.002, power=1.6), 0.0, 0.7)
    place(out, filt(noise(0.9), high=2500) * env(0.9, 0.08, power=2.2), 0.05, 0.2)
    return out


def rounds_boss_volley():
    """A fan of orbs leaves in quick succession."""
    out = silence(0.7)
    for i in range(4):
        place(out, sweep(1100 - i * 60, 380, 0.22, "saw", 0.6) * env(0.22, 0.003, power=1.5), i * 0.06, 0.4)
    place(out, sweep(160, 60, 0.3, "sine") * env(0.3, 0.003, power=1.5), 0.0, 0.6)
    return out


def rounds_boss_phase():
    """The alpha calls its horde: a roar-like fall and a horn."""
    out = silence(1.5)
    roar = sweep(240, 90, 0.9, "saw", 0.7) * (0.65 + 0.35 * np.sin(2 * np.pi * 31 * t_axis(0.9)))
    place(out, filt(roar, low=1700) * env(0.9, 0.03, power=1.1, release=0.1), 0.0, 0.7)
    place(out, _brass(note(-17), 0.8, 0.5, 2400), 0.45)
    place(out, _brass(note(-22), 0.8, 0.45, 2000), 0.45)
    return out


def rounds_boss_down():
    """The alpha falls: a big hit, then a bright fanfare."""
    out = silence(2.4)
    place(out, sweep(140, 34, 0.9, "sine", 0.5) * env(0.9, 0.002, power=1.3), 0.0, 0.9)
    for i, n in enumerate((-12, -8, -5, 0)):
        place(out, _brass(note(n), 0.2, 0.5, 3400), 0.35 + i * 0.1)
    for n in (-12, -5, 0, 4):
        place(out, _brass(note(n), 1.3, 0.3, 3400), 0.78)
    place(out, _coins(9, 12, 0.06, 0.25), 0.85)
    return out


# --- bounty and checkpoint ---------------------------------------------------------

def rounds_bounty_spawn():
    """A bright teasing run: catch me if you can."""
    out = silence(0.9)
    for i, n in enumerate((12, 16, 19, 24, 19, 24)):
        place(out, _bell(note(n), 0.3, 0.4), i * 0.07)
    return out


def rounds_bounty_claimed():
    """Cash register: a clunk and a shower of coins."""
    out = silence(1.2)
    place(out, clunk(180, 0.1), 0.0, 0.7)
    place(out, _coins(9, 12, 0.055, 0.4), 0.06)
    place(out, _brass(note(0), 0.5, 0.3, 3600), 0.1)
    return out


def rounds_bounty_lost():
    """It got away: a short descending wobble."""
    out = silence(0.7)
    for i, n in enumerate((7, 4, 0, -5)):
        place(out, tone(note(n), 0.16, "tri", 0.03, 9.0) * env(0.16, 0.004, power=1.3), i * 0.1, 0.5)
    return out


def rounds_checkpoint():
    """Checkpoint reached: two bells, a fifth apart, and a soft chord."""
    out = silence(1.4)
    place(out, _bell(note(7), 0.9, 0.5), 0.0)
    place(out, _bell(note(14), 1.1, 0.5), 0.18)
    for n in (-5, 2, 7):
        place(out, tone(note(n), 1.0, "sine") * env(1.0, 0.05, power=1.5), 0.18, 0.12)
    return out


SOUNDS = [
    rounds_wave_rush, rounds_wave_siege, rounds_wave_ambush, rounds_wave_ranged, rounds_wave_bounty,
    rounds_surge_siren, rounds_surge_hit,
    rounds_boss_intro, rounds_boss_windup, rounds_boss_slam, rounds_boss_volley, rounds_boss_phase, rounds_boss_down,
    rounds_bounty_spawn, rounds_bounty_claimed, rounds_bounty_lost, rounds_checkpoint,
]
VARIANTS = []
