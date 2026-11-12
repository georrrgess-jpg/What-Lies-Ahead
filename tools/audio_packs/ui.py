"""UI pack: the sounds of the menu kit (scripts/ui/kit/ui_sound.gd). Short,
soft and pitched in one key so chains of them (hover, tab, select, equip)
never clash with the menu theme.

    python3 tools/gen_audio.py ui
"""
import gen_audio
from gen_audio import *  # noqa: F401,F403


def rand(lo, hi, n=None):
    return gen_audio.rng.uniform(lo, hi, n)


def soft(freq, seconds, shape="sine", decay=None, gain=1.0):
    """A rounded blip with a slightly softer attack than blip()."""
    return tone(freq, seconds, shape) * env(seconds, 0.004, decay or seconds * 0.9) * gain


def ui_back():
    """Two notes stepping down: leaving, closing."""
    out = silence(0.16)
    place(out, soft(note(12), 0.07, "tri"), 0.0, 0.7)
    place(out, soft(note(5), 0.11, "tri"), 0.045, 0.7)
    return filt(out, low=4500)


def ui_tab():
    """A wooden tick with a small pitched tail: tabs and option segments."""
    out = silence(0.09)
    place(out, click(0.018, 2200, 0.7), 0.0)
    place(out, soft(note(14), 0.07, "sine", 0.05), 0.004, 0.45)
    return out


def ui_select():
    """Glassy pluck: an item card was picked."""
    out = silence(0.14)
    place(out, click(0.012, 3600, 0.4), 0.0)
    place(out, soft(note(17), 0.12, "sine", 0.1), 0.0, 0.5)
    place(out, soft(note(29), 0.08, "sine", 0.05), 0.0, 0.18)
    return out


def ui_equip():
    """Latch and a rising pair of notes: something was equipped."""
    out = silence(0.3)
    place(out, clunk(170, 0.08, 0.7), 0.0)
    place(out, click(0.02, 2800, 0.5), 0.01)
    place(out, soft(note(12), 0.1, "square", 0.08), 0.05, 0.35)
    place(out, soft(note(19), 0.16, "square", 0.14), 0.11, 0.35)
    return filt(out, low=5200)


def ui_deny():
    """Two dull low buzzes: not possible."""
    out = silence(0.22)
    for i in range(2):
        place(out, tone(note(-14), 0.07, "square") * env(0.07, 0.003, 0.07, power=0.7), i * 0.1, 0.45)
    return filt(out, low=1400)


def ui_confirm():
    """Bright major third up: yes, claimed."""
    out = silence(0.36)
    place(out, soft(note(12), 0.1, "square", 0.09), 0.0, 0.4)
    place(out, soft(note(16), 0.1, "square", 0.09), 0.07, 0.4)
    place(out, soft(note(24), 0.2, "sine", 0.18), 0.14, 0.5)
    return filt(out, low=6000)


def ui_open():
    """A quick upward breath: a dialog opened."""
    d = 0.16
    air = filt(noise(d), low=5000, high=900) * env(d, 0.05, d, power=1.0) * 0.5
    return air + sweep(320, 640, d, "sine", 0.7) * env(d, 0.02, d) * 0.3


def ui_toast():
    """Two soft bell notes."""
    out = silence(0.4)
    place(out, soft(note(19), 0.22, "sine", 0.2), 0.0, 0.4)
    place(out, soft(note(24), 0.3, "sine", 0.28), 0.09, 0.4)
    return out


def ui_tick():
    """One step of a number counting up."""
    return click(0.012, 3000, 0.5) + np.pad(soft(note(24), 0.008, "sine"), (0, int(SR * 0.012) - int(SR * 0.008))) * 0.2


def ui_purchase():
    """Register ring: Sparks spent."""
    out = silence(0.55)
    place(out, clunk(150, 0.09, 0.7), 0.0)
    for i, semi in enumerate((19, 24, 31)):
        place(out, soft(note(semi), 0.3, "sine", 0.26), 0.05 + i * 0.055, 0.38)
    sparkle = (rand(0, 1, int(SR * 0.4)) > 0.993).astype(float) * rand(-1, 1, int(SR * 0.4))
    place(out, filt(sparkle, high=5000) * env(0.4, 0.02, 0.4, power=1.0) * 1.6, 0.1)
    return out


def ui_sparks():
    """A handful of Sparks landing: quick rising glints."""
    out = silence(0.34)
    for i, semi in enumerate((24, 28, 31, 36)):
        place(out, soft(note(semi), 0.12, "sine", 0.1), i * 0.045, 0.32)
    return out


SOUNDS = [ui_back, ui_tab, ui_select, ui_equip, ui_deny, ui_confirm, ui_open, ui_toast, ui_tick, ui_purchase, ui_sparks]
VARIANTS = []

# gen_audio exports a MUSIC folder path via *; this pack has no music or loops.
MUSIC = {}
LOOPS = {}
