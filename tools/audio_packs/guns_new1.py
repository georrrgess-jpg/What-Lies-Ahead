"""Update-7 primaries: Gumball Drum Popper (weap_popper_*), Whirligig
(weap_whirl_*) and Riptide Harpoon (weap_rip_*). Punchy but soft on top:
the bodies sit below 3 kHz and the brightest layers are short. The reloads
only carry the moments the shared reload_* sounds don't (their scripts time
reload_clunk, reload_spin and friends), so the pack stays small.

    python tools/gen_audio.py guns_new1
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import punch

MUSIC = {}


def _air(d, centre=1400, width=1200, gain=1.0):
    return band(noise(d), centre, width) * gain


# ---------------------------------------------------------------------------
# Gumball Drum Popper
# ---------------------------------------------------------------------------

def weap_popper_fire():
    """A round cork 'pop' with a rubbery bwip and a soft thump under it."""
    d = 0.22
    pop = sweep(720, 170, d, "sine", 0.35) * env(d, 0.0008, 0.09, power=2.0) * 1.1
    bwip = sweep(260, 620, 0.07, "tri", 0.7) * env(0.07, 0.002, 0.07, power=1.6) * 0.35
    puff = filt(noise(d), low=1800) * env(d, 0.0005, 0.035, power=2.2) * 0.9
    thump = _sub_thump(130, 55, d, 0.09) * 0.9
    out = pop + puff + thump
    place(out, bwip, 0.004, 1.0)
    return punch(crush(filt(out, low=5000), 1.5), snap_gain=0.22, snap_hz=2600, thump_gain=0.5, thump_hz=(150, 60),
                 thump_decay=0.05, slap=(0.026,), slap_gain=0.13, room_gain=0.08, room_s=0.12, seed="popper")


def weap_popper_bounce():
    """Gumball ricochet: a quick rubber 'boink' that bends up."""
    d = 0.14
    boink = sweep(520, 880, d, "sine", 0.5) * env(d, 0.001, 0.11, power=1.8)
    body = tone(330, d, "tri") * env(d, 0.001, 0.05, power=2.0) * 0.3
    out = boink + body
    place(out, click(0.01, 1800), 0.0, 0.35)
    return punch(out, snap_gain=0.15, snap_hz=2200, thump_gain=0.3, thump_hz=(200, 90), thump_decay=0.03,
                 duck=0.15, slap=(0.022,), slap_gain=0.1, room_gain=0.0, seed="popper_bounce")


def weap_popper_pop():
    """A gumball bursting: a soft snap and a bubbly blip."""
    d = 0.16
    snap = filt(noise(d), high=900, low=4200) * env(d, 0.0004, 0.025, power=2.0) * 0.8
    blip_ = sweep(950, 380, 0.09, "sine", 0.5) * env(0.09, 0.001, 0.08, power=1.6) * 0.6
    out = snap
    place(out, blip_, 0.003, 1.0)
    return punch(out, snap_gain=0.2, snap_hz=2400, thump_gain=0.45, thump_hz=(160, 60), thump_decay=0.05,
                 slap=(0.03,), slap_gain=0.12, room_gain=0.1, room_s=0.15, seed="popper_pop")


def weap_popper_reload():
    """Drum release and a gumball rattle as it spins out (the rest is shared reload sounds)."""
    out = silence(0.9)
    place(out, click(0.02, 2200), 0.2, 0.8)                                          # release
    place(out, clunk(300, 0.06), 0.21, 0.5)
    rng = np.random.default_rng(31)
    for i in range(16):                                                              # rattle while spinning
        place(out, blip(rng.uniform(700, 1500), 0.04, "tri", 0.03), 0.24 + i * 0.022 + rng.uniform(0, 0.01), 0.22)
    place(out, _air(0.25, 900, 700, 0.4) * env(0.25, 0.02, power=1.0), 0.6, 1.0)      # drum drops away
    return out


# ---------------------------------------------------------------------------
# Whirligig
# ---------------------------------------------------------------------------

def weap_whirl_fire():
    """One round of the stream: a short low 'thup' with a little tick on top."""
    d = 0.11
    thup = sweep(230, 95, d, "sine", 0.5) * env(d, 0.0008, 0.05, power=2.0)
    grit = filt(noise(d), low=2400) * env(d, 0.0005, 0.02, power=2.0) * 0.7
    tick = click(0.008, 1900) * 0.25
    out = thup + grit
    place(out, tick, 0.0, 1.0)
    return punch(crush(out, 1.6), snap_gain=0.18, snap_hz=2400, snap_ms=1.5, thump_gain=0.3, thump_hz=(150, 70),
                 thump_decay=0.025, duck=0.15, slap=(0.019,), slap_gain=0.08, room_gain=0.0, shelf_db=-4.0,
                 seed="whirl")


def weap_whirl_spin():
    """Seamless motor whir with the ticker clacking over the wheel's pegs."""
    d = 1.0
    t = t_axis(d)
    motor = osc(2 * np.pi * 110 * t, "saw") * 0.16 + np.sin(2 * np.pi * 220 * t) * 0.18
    motor = filt(motor, low=1600)
    hum = _air(d, 700, 500, 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t))
    out = motor + hum
    for i in range(12):                                                              # ticker clacks
        place(out, click(0.012, 1400), i / 12.0, 0.5)
        place(out, blip(620, 0.03, "tri", 0.025), i / 12.0, 0.25)
    return loopable(out, 0.1)


def weap_whirl_windup():
    """Spin-up: a rising motor whine and quickening clacks."""
    d = 0.42
    whine = filt(sweep(120, 520, d, "saw", 0.8), low=1800) * env(d, 0.03, d, sustain=0.6, power=0.7) * 0.35
    out = whine + _air(d, 900, 600, 0.2) * env(d, 0.05, power=0.8)
    at = 0.0
    gap = 0.07
    while at < d - 0.02:
        place(out, click(0.01, 1500), at, 0.45)
        at += gap
        gap = max(0.025, gap * 0.8)
    return out


def weap_whirl_reload():
    """Overheat vent: a hiss, then the spent canister pops out."""
    out = silence(0.75)
    place(out, filt(noise(0.4), high=1800, low=6000) * env(0.4, 0.01, 0.35, power=1.2), 0.0, 0.4)   # vent
    place(out, sweep(420, 900, 0.07, "sine") * env(0.07, 0.002, power=1.5), 0.55, 0.5)              # canister pops
    return out


def weap_whirl_jackpot():
    """The hand-flicked wheel ticks down and lands on a 'ding-ding'."""
    out = silence(0.8)
    at, gap = 0.0, 0.025
    while at < 0.5:
        place(out, click(0.012, 1500), at, 0.42)
        place(out, blip(700, 0.03, "tri", 0.025), at, 0.2)
        at += gap
        gap *= 1.2
    place(out, blip(note(19), 0.3, "sine", 0.24), 0.5, 0.35)
    place(out, blip(note(26), 0.25, "sine", 0.2), 0.58, 0.3)
    return out


# ---------------------------------------------------------------------------
# Riptide Harpoon
# ---------------------------------------------------------------------------

def weap_rip_fire():
    """Pneumatic 'thoonk', a burst of air and the line paying out."""
    d = 0.5
    thoonk = sweep(150, 55, d, "sine", 0.45) * env(d, 0.001, 0.2, power=1.8) * 1.4
    blast = _air(d, 1100, 1400, 1.0) * env(d, 0.001, 0.12, power=1.8)
    line = filt(sweep(1300, 520, 0.3, "saw", 0.6), low=2600) * env(0.3, 0.01, 0.28, power=1.2) * 0.18
    clang = sum(tone(f, 0.35) * g for f, g in ((410, 0.5), (1030, 0.3), (1720, 0.12))) * env(0.35, 0.0008, 0.3, power=2.4)
    out = thoonk + blast
    place(out, line, 0.04, 1.0)
    place(out, clang, 0.0, 0.35)                                                   # the steel harpoon leaving
    return punch(crush(out, 1.5), snap_gain=0.35, snap_hz=2600, snap_ms=4.0, thump_gain=0.45, thump_hz=(110, 42),
                 thump_decay=0.12, duck=0.3, slap=(0.04, 0.085), slap_gain=0.18, room_gain=0.16, room_s=0.3,
                 seed="riptide")


def weap_rip_charge():
    """Pressure building: a rising hiss and hum, with the line creaking tight."""
    d = 1.0
    t = t_axis(d)
    k = np.clip(t / 0.6, 0.0, 1.0)
    hum = np.sin(2 * np.pi * np.cumsum(70 + 90 * k) / SR) * 0.35
    hiss = _air(d, 2000, 1500, 1.0) * (0.04 + 0.16 * k)
    out = hum + hiss
    for i, at in enumerate((0.12, 0.3, 0.45, 0.56)):
        place(out, band(noise(0.05), 600 + i * 120, 300) * env(0.05, 0.005, power=1.5) * 0.5, at, 1.0)
    return out


def weap_rip_ready():
    """Full charge: a small brass clink."""
    out = silence(0.45)
    place(out, sweep(420, 180, 0.08, "sine") * env(0.08, 0.001, power=2.5), 0.0, 0.45)   # the latch locks
    place(out, blip(1320, 0.22, "sine", 0.2), 0.02, 0.35)
    place(out, blip(1980, 0.18, "sine", 0.16), 0.03, 0.2)
    place(out, blip(2640, 0.25, "sine", 0.22), 0.09, 0.12)                         # hologram glint
    place(out, click(0.01, 2600), 0.0, 0.3)
    return punch(out, snap_gain=0.0, thump_gain=0.2, thump_hz=(180, 90), thump_decay=0.04, duck=0.0,
                 slap=(0.03,), slap_gain=0.12, room_gain=0.14, room_s=0.25, seed="rip_ready")


def weap_rip_reel():
    """The reel ratchets the catch in: a quickening zip of clicks."""
    out = silence(0.45)
    at, gap = 0.0, 0.05
    while at < 0.4:
        place(out, click(0.01, 1300 + at * 900), at, 0.5)
        at += gap
        gap = max(0.018, gap * 0.85)
    place(out, _air(0.4, 900, 600, 0.25) * env(0.4, 0.05, power=1.0), 0.0, 1.0)
    return out


def weap_rip_reload():
    """The air tank unscrews on a ratchet and lets go with a hiss."""
    out = silence(0.75)
    for i in range(5):                                                                # unscrew ratchet
        place(out, click(0.01, 1700), 0.28 + i * 0.05, 0.4)
    place(out, filt(noise(0.3), high=2000, low=6000) * env(0.3, 0.01, 0.28, power=1.2), 0.45, 0.4)   # hiss
    return out


SOUNDS = [
    weap_popper_fire, weap_popper_bounce, weap_popper_pop, weap_popper_reload,
    weap_whirl_fire, weap_whirl_windup, weap_whirl_reload, weap_whirl_jackpot,
    weap_rip_fire, weap_rip_charge, weap_rip_ready, weap_rip_reel, weap_rip_reload,
]

VARIANTS = [
    (weap_popper_fire, (0.94, 1.07)), (weap_popper_bounce, (0.9, 1.12)), (weap_popper_pop, (0.92, 1.1)),
    (weap_whirl_fire, (0.95, 1.05)), (weap_rip_fire, (0.95, 1.05)),
]

LOOPS = {"weap_whirl_spin": weap_whirl_spin}
