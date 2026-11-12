"""Arsenal weapons: fire, reload and special sounds for the five unlockable
weapons, plus the shared weapon-switch sound. All names start with "weap_".

    python tools/gen_audio.py weapons
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _laser_layer, _shimmer, _sub_thump


def _arc(d, density=0.03, centre=3500):
    """Crackling electric noise: sparse spikes through a band filter."""
    spikes = (np.random.default_rng(int(d * 1000) + int(centre)).uniform(0, 1, int(SR * d)) < density).astype(float)
    spikes *= np.random.default_rng(7).uniform(-1, 1, len(spikes))
    return band(spikes, centre, centre * 0.6) * 6.0 + filt(noise(d), high=4000) * 0.25


def _whoosh(d, f0=500, f1=1800, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

def weap_switch():
    """Weapon switch: a cloth whoosh down, a latch click and a bright power-up chirp."""
    out = silence(0.42)
    place(out, _whoosh(0.16, 300, 1400, 0.5), 0.0, 1.0)
    place(out, click(0.025, 3200), 0.14, 0.9)
    place(out, clunk(260, 0.08), 0.15, 0.6)
    place(out, sweep(900, 2600, 0.14, "sine", 0.7) * env(0.14, 0.01, 0.16, power=1.0) * 0.35, 0.2, 1.0)
    return out


# ---------------------------------------------------------------------------
# Comet Hand Cannon
# ---------------------------------------------------------------------------

def weap_cannon_fire():
    """Heavy, short hand-cannon crack with an amber zing (fired three times per burst)."""
    d = 0.3
    snap = filt(noise(d), high=2200) * env(d, 0.0003, 0.025, power=2.0) * 1.3
    zing = _laser_layer(1700, 260, d, 0.5, "square") * env(d, 0.0008, 0.11, power=2.0) * 0.35
    sub = _sub_thump(150, 40, d, 0.16) * 1.4
    body = filt(noise(d), low=1400) * env(d, 0.001, 0.08, power=2.0) * 0.8
    tail = _shimmer(d, 0.22, 4800) * 0.18
    return crush(snap + zing + sub + body + tail, 1.6)


def weap_cannon_reload():
    """Crane swings out, cores rattle out, speedloader prints and pushes in, spin and snap shut."""
    out = silence(1.7)
    place(out, clunk(240, 0.08), 0.17, 0.8)                                         # latch
    place(out, _whoosh(0.12, 800, 2000, 0.4), 0.2, 1.0)                             # swing out
    for i in range(6):                                                              # cores rattle out
        place(out, blip(1500 + i * 180, 0.05, "tri", 0.04), 0.46 + i * 0.022, 0.25)
        place(out, click(0.015, 4200), 0.47 + i * 0.022, 0.35)
    place(out, band(noise(0.18), 2600, 1000) * env(0.18, 0.02, power=1.0), 0.95, 0.4)  # loader slides
    place(out, clunk(300, 0.1), 1.23, 0.9)                                          # loader seats
    place(out, clunk(180, 0.14), 1.45, 1.0)                                         # snap shut
    place(out, charge(0.22, 600, 2200), 1.5, 0.35)
    return out


# ---------------------------------------------------------------------------
# Arc Coil
# ---------------------------------------------------------------------------

def weap_arc_fire():
    """Tesla zap: a crackling burst with a buzzing 50 Hz-ish body."""
    d = 0.17
    crackle = _arc(d, 0.05, 3800) * env(d, 0.001, 0.13, power=1.5)
    buzz = tone(95, d, "square") * env(d, 0.002, 0.12, power=1.4) * 0.3
    zap = sweep(2600, 700, d, "saw", 0.4) * env(d, 0.001, 0.06, power=2.0) * 0.25
    return crush(filt(crackle * 0.6 + buzz + zap, low=11000), 1.4)


def weap_arc_chain():
    """Smaller snapping arc for each chain jump."""
    d = 0.12
    snap = _arc(d, 0.06, 5200) * env(d, 0.0005, 0.08, power=2.0)
    tick = sweep(3800, 1600, d, "square", 0.5) * env(d, 0.0005, 0.03, power=2.0) * 0.25
    return crush(snap * 0.5 + tick, 1.3)


def weap_arc_reload():
    """Vents hiss, the capsule pops, a new one hums in, the claws snap with a crackle."""
    out = silence(1.9)
    place(out, filt(noise(0.4), high=2600) * env(0.4, 0.01, 0.35, power=1.2), 0.18, 0.5)  # vents
    place(out, sweep(500, 1400, 0.08, "sine") * env(0.08, 0.001, power=1.5), 0.4, 0.7)   # pop
    place(out, _whoosh(0.2, 600, 2200, 0.35), 0.45, 1.0)
    place(out, sweep(120, 360, 0.5, "saw", 1.2) * env(0.5, 0.2, 0.6, power=0.8) * 0.18, 0.95, 1.0)  # hum in
    place(out, clunk(220, 0.1), 1.5, 0.9)                                                # seat
    place(out, _arc(0.25, 0.05, 4200) * env(0.25, 0.001, 0.22, power=1.2) * 0.5, 1.63, 1.0)  # claws spark
    return out


# ---------------------------------------------------------------------------
# Bumper Lobber
# ---------------------------------------------------------------------------

def weap_lobber_fire():
    """Bouncy 'thoomp' with a rubbery pitch-up."""
    d = 0.42
    thoomp = sweep(160, 70, d, "sine", 0.5) * env(d, 0.002, 0.2, power=1.8) * 1.5
    boing = sweep(220, 520, 0.18, "tri", 0.6) * env(0.18, 0.003, 0.16, power=1.4) * 0.45
    puff = filt(noise(d), low=900) * env(d, 0.002, 0.1, power=2.0) * 0.7
    out = thoomp + puff
    place(out, boing, 0.03, 1.0)
    return crush(out, 1.4)


def weap_lobber_bounce():
    """Rubber ball bonk."""
    d = 0.22
    bonk = sweep(420, 260, d, "sine", 0.4) * env(d, 0.001, 0.15, power=2.0)
    spring = tone(780, d, "sine", vibrato=0.06, vib_rate=28) * env(d, 0.002, 0.18, power=1.6) * 0.3
    out = bonk + spring
    place(out, click(0.015, 2000), 0.0, 0.4)
    return out


def weap_lobber_boom():
    """Party-popper blast: a round boom, a paper crackle and a jingle of sparkle."""
    d = 1.0
    boom = _sub_thump(130, 32, d, 0.5) * 1.6
    blast = filt(noise(d), low=2200) * env(d, 0.001, 0.3, power=2.0) * 0.9
    crackle = filt((np.random.default_rng(11).uniform(0, 1, int(SR * d)) > 0.992).astype(float), high=3000) * env(d, 0.05, 0.8, power=1.0) * 1.2
    out = boom + blast + crackle
    for i, n in enumerate((19, 23, 26, 31)):
        place(out, blip(note(n), 0.18, "sine", 0.14), 0.08 + i * 0.05, 0.12)
    return crush(out, 1.5)


def weap_lobber_reload():
    """Lid pops, shells rattle out, gumballs tumble in, crank ratchets twice, lid slaps shut."""
    out = silence(2.4)
    place(out, clunk(330, 0.07), 0.22, 0.7)                                         # lid
    for i in range(5):                                                              # shells pop out
        place(out, sweep(500 + i * 60, 900 + i * 80, 0.06, "sine") * env(0.06, 0.002, power=1.5), 0.46 + i * 0.04, 0.4)
    for i in range(5):                                                              # gumballs drop in
        place(out, sweep(700, 380, 0.08, "sine", 0.5) * env(0.08, 0.001, power=2.0), 0.9 + i * 0.09, 0.45)
    for i in range(10):                                                             # crank ratchet
        place(out, click(0.012, 3000 + (i % 2) * 600), 1.55 + i * 0.044, 0.55)
    place(out, clunk(200, 0.12), 2.1, 1.0)                                          # slap shut
    return out


# ---------------------------------------------------------------------------
# Frostbite Cryo Beam
# ---------------------------------------------------------------------------

def weap_cryo_start():
    """Beam ignition: an icy whoosh up into a hiss."""
    d = 0.35
    whoosh = band(noise(d), 3000, 2000) * env(d, 0.01, 0.3, power=1.2) * 0.8
    rise = sweep(400, 2400, d, "sine", 0.6) * env(d, 0.005, 0.3, power=1.0) * 0.3
    return whoosh + rise


def weap_cryo_loop():
    """Seamless beam hum: airy hiss, a shimmering high choir and a low pulse."""
    d = 2.0
    t = t_axis(d)
    hiss = band(noise(d), 5200, 2600) * 0.35
    shimmer = sum(np.sin(2 * np.pi * f * t + p) * g for f, g, p in ((1760, 0.12, 0), (2217.5, 0.08, 1), (2637, 0.06, 2)))
    shimmer *= 0.7 + 0.3 * np.sin(2 * np.pi * 3.0 * t)
    pulse = np.sin(2 * np.pi * 110 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 4.0 * t)) * 0.25
    return hiss + shimmer + pulse


def weap_cryo_freeze():
    """A zombie freezing solid: crystalline crackle rising into a glassy ping."""
    d = 0.6
    crackle = filt((np.random.default_rng(5).uniform(0, 1, int(SR * d)) > 0.985).astype(float), high=4000) * env(d, 0.2, 0.5, power=0.8)
    out = crackle * 1.4
    place(out, sweep(1200, 3200, 0.3, "sine", 0.6) * env(0.3, 0.01, 0.35, power=1.0) * 0.3, 0.0, 1.0)
    place(out, blip(note(36), 0.3, "sine", 0.28), 0.28, 0.5)
    place(out, blip(note(43), 0.25, "sine", 0.22), 0.3, 0.3)
    return out


def weap_cryo_shatter():
    """Ice block shattering: glassy tinkles over a crunch."""
    d = 0.8
    crunch = filt(noise(d), high=1800, low=7000) * env(d, 0.001, 0.12, power=2.0) * 1.1
    out = crunch + _sub_thump(180, 60, d, 0.1) * 0.6
    rng = np.random.default_rng(23)
    for i in range(14):
        place(out, blip(rng.uniform(2400, 6200), 0.12, "sine", 0.1) * 0.3, 0.02 + rng.uniform(0, 0.5), 1.0)
    return out


def weap_cryo_vent():
    """Overheat vent / canister swap: big hiss, clamps, a tank clunk and a frosty re-pressurise."""
    out = silence(1.6)
    place(out, filt(noise(0.6), high=3000) * env(0.6, 0.01, 0.55, power=1.0), 0.05, 0.75)  # vent
    place(out, clunk(260, 0.08), 0.24, 0.7)                                              # clamps
    place(out, clunk(130, 0.18), 0.6, 0.8)                                               # tank drops
    place(out, band(noise(0.2), 2200, 900) * env(0.2, 0.03, power=1.0), 0.9, 0.45)        # new tank
    place(out, clunk(200, 0.12), 1.3, 1.0)                                               # locks
    place(out, sweep(800, 3000, 0.25, "sine", 0.6) * env(0.25, 0.01, 0.3, power=1.0) * 0.25, 1.32, 1.0)
    return out


# ---------------------------------------------------------------------------
# Rail Lancer
# ---------------------------------------------------------------------------

def weap_rail_charge():
    """Charging whine rising to a held, wobbling peak (stopped on release)."""
    d = 1.6
    t = t_axis(d)
    k = np.clip(t / 0.8, 0.0, 1.0)
    freq = 300 + 1700 * k ** 1.4 + 30 * np.sin(2 * np.pi * 9 * t) * k
    whine = osc(2 * np.pi * np.cumsum(freq) / SR, "saw") * 0.18
    sub = np.sin(2 * np.pi * np.cumsum(60 + 80 * k) / SR) * 0.35
    grit = band(noise(d), 3000, 1500) * (0.05 + 0.2 * k)
    return filt(whine, low=6000) + sub + grit


def weap_rail_ready():
    """Full-charge lock-in chime."""
    out = silence(0.4)
    place(out, blip(note(31), 0.25, "sine", 0.22), 0.0, 0.7)
    place(out, blip(note(38), 0.25, "sine", 0.2), 0.05, 0.5)
    place(out, click(0.02, 4800), 0.0, 0.5)
    return out


def weap_rail_fire():
    """The rail slug: a supersonic crack, a ringing metallic zing and a deep boom."""
    d = 1.1
    crack = filt(noise(d), high=2500) * env(d, 0.0002, 0.03, power=1.8) * 1.6
    zing = _laser_layer(5200, 900, d, 0.35, "saw") * env(d, 0.0005, 0.35, power=1.6) * 0.3
    ring = (tone(1850, d, "sine") * 0.4 + tone(2790, d, "sine") * 0.25) * env(d, 0.001, 0.8, power=2.2)
    boom = _sub_thump(110, 28, d, 0.6) * 1.7
    return crush(crack + zing + ring * 0.6 + boom, 1.6)


def weap_rail_reload():
    """Rails slide out and vent three times, capacitor drops, a new one slots in, rails slam home."""
    out = silence(2.2)
    place(out, band(noise(0.12), 1600, 700) * env(0.12, 0.01, power=1.2), 0.15, 0.6)   # rails out
    for at in (0.27, 0.53, 0.8):                                                     # three vents
        place(out, filt(noise(0.22), high=3200) * env(0.22, 0.005, 0.2, power=1.4), at, 0.45)
    place(out, clunk(150, 0.16), 0.75, 0.8)                                          # capacitor drops
    place(out, band(noise(0.2), 2400, 900) * env(0.2, 0.03, power=1.0), 1.25, 0.4)    # new one slides
    place(out, clunk(240, 0.1), 1.66, 0.9)                                           # latches
    place(out, clunk(110, 0.2), 1.96, 1.0)                                           # rails slam
    return out


SOUNDS = [
    weap_switch,
    weap_cannon_fire, weap_cannon_reload,
    weap_arc_fire, weap_arc_chain, weap_arc_reload,
    weap_lobber_fire, weap_lobber_bounce, weap_lobber_boom, weap_lobber_reload,
    weap_cryo_start, weap_cryo_freeze, weap_cryo_shatter, weap_cryo_vent,
    weap_rail_charge, weap_rail_ready, weap_rail_fire, weap_rail_reload,
]

VARIANTS = [
    (weap_cannon_fire, (0.95, 1.05)), (weap_arc_fire, (0.93, 1.07)), (weap_arc_chain, (0.9, 1.12)),
    (weap_lobber_boom, (0.93, 1.06)), (weap_lobber_bounce, (0.9, 1.12)), (weap_cryo_shatter, (0.92, 1.08)),
    (weap_rail_fire, (0.96, 1.04)),
]

LOOPS = {"weap_cryo_loop": lambda: loopable(weap_cryo_loop(), 0.4)}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
