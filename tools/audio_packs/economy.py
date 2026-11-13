"""Sparks economy sounds: the pickup tick of a Spark reaching the player, a
bigger chime for bulk payouts, the shop's purchase jingle, a soft refusal and
the contract-complete sting.

    python tools/gen_audio.py economy

`eco_spark_tick` is played at a rising pitch while pickups keep coming (one
semitone per pickup, see scripts/economy/sparks_hud.gd), so it is short, pure
and has no pitch movement of its own.
"""
from gen_audio import *  # noqa: F401,F403  (tone, blip, env, place, silence, note, ...)


def _glass(freq, seconds, gain=1.0):
    """A small glassy ping: a sine with two quiet inharmonic partials."""
    out = silence(seconds)
    for ratio, g, decay in ((1.0, 1.0, 1.0), (2.0, 0.35, 0.6), (3.01, 0.18, 0.4)):
        place(out, tone(freq * ratio, seconds, "sine") * env(seconds, 0.0015, seconds * decay, power=2.2) * g, 0.0)
    return out * gain


def eco_spark_tick():
    """One Spark picked up: a bright, very short ping with a soft click on top."""
    out = silence(0.16)
    place(out, _glass(note(15), 0.15), 0.0, 0.8)
    place(out, click(0.012, 5200), 0.0, 0.25)
    return out


def eco_spark_bank():
    """A bulk payout (wave clear, level-up, contract): three quick rising pings."""
    out = silence(0.55)
    for i, n in enumerate((7, 12, 19)):
        place(out, _glass(note(n), 0.36 - i * 0.04), i * 0.055, 0.6)
    place(out, band(noise(0.3), 7000, 3000) * env(0.3, 0.004, 0.25, power=2.5), 0.08, 0.12)
    return out


def eco_purchase():
    """Bought with Sparks: a coin-drawer clunk, then a sparkling major arpeggio."""
    out = silence(1.1)
    place(out, clunk(170, 0.1), 0.0, 0.5)
    for i, n in enumerate((3, 7, 10, 15, 19)):
        place(out, _glass(note(n), 0.5), 0.05 + i * 0.06, 0.5)
    place(out, _glass(note(27), 0.7), 0.36, 0.35)
    place(out, band(noise(0.5), 8000, 4000) * env(0.5, 0.01, 0.4, power=2.0), 0.3, 0.1)
    return out


def eco_deny():
    """Cannot afford it: two soft falling notes (never harsh)."""
    out = silence(0.32)
    place(out, blip(note(-2), 0.12, "sine", 0.1), 0.0, 0.55)
    place(out, blip(note(-7), 0.16, "sine", 0.14), 0.11, 0.55)
    return filt(out, low=2600)


def eco_contract():
    """Contract complete: a stamp thump and a bright two-note confirmation."""
    out = silence(0.8)
    place(out, clunk(120, 0.12), 0.0, 0.6)
    place(out, _glass(note(10), 0.3), 0.04, 0.55)
    place(out, _glass(note(17), 0.6), 0.15, 0.6)
    place(out, _glass(note(29), 0.5), 0.15, 0.2)
    return out


SOUNDS = [eco_spark_tick, eco_spark_bank, eco_purchase, eco_deny, eco_contract]
VARIANTS = []
LOOPS = {}
MUSIC = {}
