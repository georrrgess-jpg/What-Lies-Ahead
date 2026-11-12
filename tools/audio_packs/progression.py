"""Progression sounds: level-up fanfare, a rank-up sting per mastery tier,
challenge complete, XP banked and the XP bar tick.

    python tools/gen_audio.py progression
"""
from gen_audio import *  # noqa: F401,F403  (tone, blip, env, place, silence, note, ...)


def _bell(freq, seconds, gain=1.0, bright=1.0):
    """Struck bell: inharmonic partials with their own decays."""
    out = silence(seconds)
    for ratio, g, decay in ((1.0, 1.0, 0.9), (2.0, 0.5, 0.5), (2.76, 0.35 * bright, 0.35), (5.4, 0.2 * bright, 0.18)):
        place(out, tone(freq * ratio, seconds, "sine") * env(seconds, 0.002, seconds * decay, power=1.8) * g, 0.0)
    return out * gain


def _brass(freq, seconds, gain=1.0):
    """Bright synth-brass stab: detuned saws through a closing filter."""
    body = (tone(freq, seconds, "saw") + tone(freq * 1.006, seconds, "saw") * 0.8 + tone(freq * 0.5, seconds, "square") * 0.3)
    body = filt(body, low=3200)
    return body * env(seconds, 0.012, seconds, sustain=0.35, power=1.2, release=0.08) * gain


def _sparkle(seconds, start_note, count, step, gain=0.3):
    out = silence(seconds)
    for i in range(count):
        place(out, blip(note(start_note + (i * 5) % 17), 0.18, "sine", 0.12), i * step, gain)
    return out


def prog_level_up():
    """Account level-up: rising brass arpeggio into a held major chord with sparkles."""
    out = silence(2.2)
    for i, n in enumerate((0, 4, 7, 12)):
        place(out, _brass(note(n - 12), 0.22), i * 0.09, 0.45)
    for n in (0, 4, 7, 12):
        place(out, _brass(note(n - 12), 1.3), 0.38, 0.3)
    place(out, _bell(note(24), 1.6, 0.5), 0.38)
    place(out, _sparkle(1.6, 24, 10, 0.07, 0.22), 0.45)
    place(out, sweep(160, 50, 0.5, "sine") * env(0.5, 0.004, power=1.6), 0.38, 0.7)
    return out


def _sting(notes, base, bell_note, sparkle_count=0, length=1.2, shape_gain=0.5):
    out = silence(length)
    for i, n in enumerate(notes):
        place(out, _brass(note(base + n), 0.18 if i < len(notes) - 1 else 0.6), i * 0.08, shape_gain)
    place(out, _bell(note(bell_note), length - 0.1, 0.45), (len(notes) - 1) * 0.08)
    if sparkle_count:
        place(out, _sparkle(length * 0.7, bell_note, sparkle_count, 0.05, 0.18), (len(notes) - 1) * 0.08)
    return out


def prog_rank_bronze():
    """Warm two-note sting."""
    return _sting((0, 7), -12, 12, length=0.9)


def prog_rank_silver():
    """Brighter three-note sting with a bell."""
    return _sting((0, 4, 7), -10, 16, length=1.0)


def prog_rank_gold():
    """Triumphant four notes and a shimmer of gold."""
    return _sting((0, 4, 7, 12), -8, 19, sparkle_count=6, length=1.3)


def prog_rank_diamond():
    """Crystal: high bells cascading over a bright chord."""
    out = _sting((0, 7, 12, 16), -5, 24, sparkle_count=10, length=1.5, shape_gain=0.4)
    for i, n in enumerate((28, 31, 35, 40)):
        place(out, _bell(note(n), 0.5, 0.18, bright=1.4), 0.3 + i * 0.07)
    return out


def prog_rank_prismatic():
    """Top tier: a rising sweep into a full chord, bells and a sparkle cascade."""
    out = silence(2.3)
    rise = sweep(200, 1600, 0.45, "saw", 1.6) * env(0.45, 0.2, 0.9, power=0.5, release=0.05)
    place(out, filt(rise, low=4000), 0.0, 0.25)
    place(out, filt(noise(0.45), high=3000) * env(0.45, 0.4, 0.9, power=0.5, release=0.05), 0.0, 0.12)
    for n in (0, 4, 7, 11, 14):
        place(out, _brass(note(n - 12), 1.5), 0.45, 0.22)
    for i, n in enumerate((19, 24, 28, 31, 36)):
        place(out, _bell(note(n), 1.2, 0.25, bright=1.3), 0.45 + i * 0.06)
    place(out, _sparkle(1.5, 31, 16, 0.06, 0.16), 0.5)
    place(out, sweep(140, 45, 0.6, "sine") * env(0.6, 0.004, power=1.6), 0.45, 0.6)
    return out


def prog_challenge():
    """Achievement: two bright bells and a soft whoosh."""
    out = silence(1.1)
    place(out, band(noise(0.35), 2500, 1400) * env(0.35, 0.15, 0.35, power=1.0), 0.0, 0.25)
    place(out, _bell(note(19), 0.9, 0.6), 0.12)
    place(out, _bell(note(26), 0.9, 0.55), 0.24)
    place(out, blip(note(31), 0.2, "square", 0.08), 0.24, 0.12)
    return out


def prog_xp_bank():
    """XP banked: a coin-like double chime."""
    out = silence(0.5)
    place(out, blip(note(24), 0.12, "square", 0.06), 0.0, 0.35)
    place(out, _bell(note(31), 0.4, 0.5), 0.05)
    place(out, _bell(note(36), 0.35, 0.4), 0.11)
    return out


def prog_xp_tick():
    """Tiny soft tick while the XP bar fills (pitch is raised in game)."""
    out = blip(note(28), 0.035, "sine", 0.025)
    return place(out, click(0.01, 4200), 0.0, 0.25)


SOUNDS = [prog_level_up, prog_rank_bronze, prog_rank_silver, prog_rank_gold, prog_rank_diamond,
          prog_rank_prismatic, prog_challenge, prog_xp_bank, prog_xp_tick]
# Defined here so the names imported from gen_audio (MUSIC is its folder path,
# VARIANTS its core list) are not mistaken for this pack's.
VARIANTS = []
LOOPS = {}
MUSIC = {}
