"""Sparks economy sounds: the pickup tick of a Spark reaching the player, a
bigger chime for bulk payouts and the contract-complete sting.

    python tools/gen_audio.py economy

`eco_spark_tick` is played at a rising pitch while pickups keep coming (one
semitone per pickup, see scripts/economy/sparks_hud.gd), so it is short, pure
and has no pitch movement of its own.
"""
from gen_audio import *  # noqa: F401,F403  (tone, blip, env, place, silence, note, ...)


def _glass(freq, seconds, gain=1.0, overtones=1.0):
    """A small glassy ping: a sine with two quiet partials (`overtones` scales them)."""
    out = silence(seconds)
    for ratio, g, decay in ((1.0, 1.0, 1.0), (2.0, 0.35 * overtones, 0.6), (3.01, 0.18 * overtones, 0.4)):
        place(out, tone(freq * ratio, seconds, "sine") * env(seconds, 0.0015, seconds * decay, power=2.2) * g, 0.0)
    return out * gain


def eco_spark_tick():
    """One Spark picked up: a short, round coin 'plip' (G5, so even a full
    streak an octave and a bit up stays under 2 kHz) with a soft tick."""
    out = silence(0.13)
    place(out, _glass(note(10), 0.12, overtones=0.5), 0.0, 0.8)
    place(out, click(0.012, 2600), 0.0, 0.12)
    return out


def eco_spark_bank():
    """A bulk payout (wave clear, level-up, contract): three quick rising pings."""
    out = silence(0.55)
    for i, n in enumerate((7, 12, 19)):
        place(out, _glass(note(n), 0.36 - i * 0.04), i * 0.055, 0.6)
    place(out, band(noise(0.3), 7000, 3000) * env(0.3, 0.004, 0.25, power=2.5), 0.08, 0.12)
    return out


def eco_contract():
    """Contract complete: a stamp thump and a bright two-note confirmation."""
    out = silence(0.8)
    place(out, clunk(120, 0.12), 0.0, 0.6)
    place(out, _glass(note(10), 0.3), 0.04, 0.55)
    place(out, _glass(note(17), 0.6), 0.15, 0.6)
    place(out, _glass(note(29), 0.5), 0.15, 0.2)
    return out


SOUNDS = [eco_spark_tick, eco_spark_bank, eco_contract]
VARIANTS = []
LOOPS = {}
MUSIC = {}
