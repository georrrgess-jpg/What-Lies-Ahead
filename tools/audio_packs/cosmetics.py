"""Cosmetics pack: Locker equip clicks (one flavour per category), selection
and unlock stings, and the sound layers of the cosmetic kill effects.

    python tools/gen_audio.py cosmetics
"""
import gen_audio
from gen_audio import *  # noqa: F401,F403


def rand(lo, hi, n=None):
    """Random numbers from the generator gen_audio reseeds for each variant."""
    return gen_audio.rng.uniform(lo, hi, n)


def bell(freq, seconds, decay=None, gain=1.0, ratios=(1.0, 2.76, 5.4, 8.93), weights=(1.0, 0.5, 0.25, 0.12)):
    """Inharmonic struck-metal tone (bells, coins, chimes)."""
    out = silence(seconds)
    for r, w in zip(ratios, weights):
        out += tone(freq * r, seconds) * env(seconds, 0.001, (decay or seconds) / (0.6 + r * 0.25), power=1.5) * w
    return out * gain


def shimmer(seconds, centre=7000, density=0.992, gain=1.0):
    """Sparse glittery ticks."""
    n = int(SR * seconds)
    ticks = (rand(0, 1, n) > density).astype(float) * rand(-1, 1, n)
    return filt(ticks, low=centre * 1.6, high=centre * 0.5) * env(seconds, 0.01, seconds, power=1.2) * gain * 3.0


def whoosh(seconds, f0=300, f1=3000, gain=1.0):
    n = noise(seconds)
    t = t_axis(seconds)
    shaped = np.sin(np.pi * t / seconds) ** 2
    lo = filt(n, low=f1, high=f0)
    return lo * shaped * gain


def arpeggio(semis, step, length, shape="square", gain=1.0, low=5000):
    d = step * len(semis) + length
    out = silence(d)
    for i, s in enumerate(semis):
        place(out, blip(note(s), length, shape, length * 0.9), i * step, 1.0)
    return filt(out, low=low) * gain


# --- Locker -----------------------------------------------------------------

def cos_select():
    out = silence(0.06)
    place(out, click(0.03, 3200, 0.6), 0.0)
    place(out, blip(note(19), 0.05, "sine") * 0.35, 0.0)
    return out


def cos_unequip():
    return sweep(900, 420, 0.14, "tri", 0.7) * env(0.14, 0.002, 0.13) * 0.6


def cos_equip_operator():
    """Hero stab: a whoosh up into a bright major chord."""
    d = 0.75
    out = silence(d)
    place(out, whoosh(0.3, 400, 5000, 0.6), 0.0)
    chord = sum(tone(note(s), 0.5, "saw") for s in (3, 7, 10, 15)) * env(0.5, 0.004, 0.45, power=1.4)
    place(out, filt(chord, low=3800) * 0.35, 0.18)
    place(out, bell(note(27), 0.5, gain=0.25), 0.2)
    return out


def cos_equip_finish():
    """Spray-paint hiss and a shiny ding."""
    d = 0.6
    out = silence(d)
    place(out, filt(noise(0.28), high=4000, low=11000) * env(0.28, 0.01, 0.28, power=0.8) * 0.5, 0.0)
    place(out, bell(note(24), 0.4, gain=0.5), 0.2)
    place(out, shimmer(0.35, 9000, gain=0.3), 0.22)
    return out


def cos_equip_charm():
    """A little jingle on a chain."""
    d = 0.5
    out = silence(d)
    for i, s in enumerate((31, 35, 38)):
        place(out, bell(note(s), 0.3, gain=0.45), i * 0.06)
    for i in range(5):
        place(out, click(0.015, 5200, 0.4), 0.02 + i * 0.035)
    return out


def cos_equip_cell():
    """Power-up hum rising into a zap."""
    d = 0.55
    out = silence(d)
    hum = sweep(110, 440, 0.4, "saw", 0.6) * env(0.4, 0.02, 0.4, power=0.6)
    place(out, filt(hum, low=2500) * 0.6, 0.0)
    place(out, sweep(2200, 600, 0.12, "square", 0.5) * env(0.12, 0.001, 0.12) * 0.35, 0.36)
    place(out, shimmer(0.2, 8000, gain=0.25), 0.36)
    return out


def cos_equip_decal():
    """Sticker peel and pat."""
    d = 0.35
    out = silence(d)
    place(out, filt(noise(0.12), high=2500, low=7000) * np.linspace(0.2, 1.0, int(SR * 0.12)) * 0.4, 0.0)
    place(out, clunk(180, 0.09, 0.7), 0.15)
    place(out, click(0.02, 1500, 0.5), 0.15)
    return out


def cos_equip_gloves():
    """Velcro rip and a leather snap."""
    d = 0.4
    out = silence(d)
    rip = filt(noise(0.16), high=1200, low=6000)
    rip *= (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 70 * t_axis(0.16)))) * env(0.16, 0.005, 0.16, power=0.6)
    place(out, rip * 0.5, 0.0)
    place(out, clunk(260, 0.08, 0.6), 0.2)
    place(out, click(0.02, 2200, 0.6), 0.2)
    return out


def cos_equip_effect():
    """A cascade of magic sparkles."""
    d = 0.6
    out = silence(d)
    for i, s in enumerate((24, 28, 31, 36, 40)):
        place(out, blip(note(s), 0.12, "sine") * 0.35, i * 0.05)
    place(out, shimmer(0.5, 9000, gain=0.4), 0.05)
    return out


def cos_equip_tracer():
    """Pew, then a chime."""
    d = 0.5
    out = silence(d)
    place(out, sweep(3200, 500, 0.16, "saw", 0.5) * env(0.16, 0.001, 0.15) * 0.4, 0.0)
    place(out, bell(note(26), 0.35, gain=0.4), 0.12)
    return out


def cos_equip_banner():
    """Whoosh and a flag flutter."""
    d = 0.55
    out = silence(d)
    place(out, whoosh(0.35, 300, 3500, 0.6), 0.0)
    flutter = filt(noise(0.3), high=500, low=3000) * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * t_axis(0.3))) * env(0.3, 0.02, 0.3, power=1.0)
    place(out, flutter * 0.45, 0.18)
    return out


def cos_equip_title():
    """Ding-ding fanfare."""
    d = 0.6
    out = silence(d)
    place(out, bell(note(19), 0.4, gain=0.5), 0.0)
    place(out, bell(note(26), 0.45, gain=0.5), 0.12)
    place(out, arpeggio([14, 19, 23], 0.05, 0.12, "square", 0.25), 0.12)
    return out


def cos_unlock():
    """Locker unlock sting: rising arpeggio, sparkles and a bell."""
    d = 1.3
    out = silence(d)
    place(out, arpeggio([7, 11, 14, 19, 23, 26], 0.06, 0.16, "square", 0.45, low=4500), 0.0)
    pad = sum(tone(note(s), 0.8, "saw", 0.004, 5.0) for s in (19, 23, 26)) * env(0.8, 0.05, 0.8, power=1.2)
    place(out, filt(pad, low=3000) * 0.25, 0.36)
    place(out, bell(note(31), 0.9, gain=0.45), 0.36)
    place(out, shimmer(0.8, 9000, gain=0.45), 0.36)
    return out


# --- Kill effect layers --------------------------------------------------------

def cos_kill_pixel():
    """8-bit tumble."""
    return arpeggio([24, 19, 15, 12, 7], 0.035, 0.07, "square", 0.6, low=7000)


def cos_kill_neon_ring():
    """Synth shockwave: a resonant sweep down with hiss."""
    d = 0.5
    out = sweep(1800, 90, d, "saw", 0.5) * env(d, 0.002, 0.45, power=1.6)
    out = band(out, 900, 900) * 1.4 + filt(noise(d), high=3000) * env(d, 0.001, 0.2) * 0.3
    return out


def cos_kill_bubbles():
    """A handful of little bubble pops."""
    d = 0.6
    out = silence(d)
    for i in range(6):
        f = rand(500, 1100)
        pop = sweep(f, f * 2.4, 0.05, "sine", 0.7) * env(0.05, 0.001, 0.05, power=1.5)
        place(out, pop, rand(0.0, 0.45), rand(0.4, 0.8))
    return out


def cos_kill_snow():
    """Icy chimes over a soft gust."""
    d = 0.9
    out = silence(d)
    place(out, whoosh(0.6, 2000, 9000, 0.25), 0.0)
    for i, s in enumerate((31, 36, 34, 38)):
        place(out, bell(note(s), 0.5, gain=0.3, ratios=(1.0, 3.0, 5.2), weights=(1.0, 0.3, 0.15)), i * 0.07)
    return out


def cos_kill_starburst():
    """Bright shing."""
    d = 0.6
    out = silence(d)
    place(out, bell(note(28), 0.55, gain=0.6, ratios=(1.0, 1.5, 2.76, 4.1), weights=(1.0, 0.6, 0.4, 0.25)), 0.0)
    place(out, filt(noise(0.2), high=6000) * env(0.2, 0.001, 0.2) * 0.4, 0.0)
    place(out, shimmer(0.5, 10000, gain=0.4), 0.02)
    return out


def cos_kill_coins():
    """A spill of coins."""
    d = 0.9
    out = silence(d)
    for i in range(9):
        f = rand(1900, 3200)
        place(out, bell(f, 0.18, gain=rand(0.25, 0.5), ratios=(1.0, 2.4, 4.7), weights=(1.0, 0.5, 0.3)), 0.03 + i * rand(0.04, 0.09))
    return out


def cos_kill_firework():
    """Rocket whistle."""
    d = 0.3
    return sweep(900, 2600, d, "sine", 0.8) * env(d, 0.01, d, power=0.4, release=0.04) * 0.5 + filt(noise(d), high=3000) * env(d, 0.002, d) * 0.15


def cos_kill_firework_pop():
    """Bang and crackle."""
    d = 0.9
    out = silence(d)
    place(out, sweep(160, 40, 0.3, "sine", 0.4) * env(0.3, 0.001, 0.25) * 0.9, 0.0)
    place(out, filt(noise(0.2), low=2500) * env(0.2, 0.001, 0.12) * 0.7, 0.0)
    crackle = (rand(0, 1, int(SR * 0.7)) > 0.997).astype(float) * rand(-1, 1, int(SR * 0.7))
    place(out, filt(crackle, high=1500) * env(0.7, 0.05, 0.7, power=1.0) * 2.5, 0.15)
    return out


def cos_kill_hearts():
    """A cute boing and two soft notes."""
    d = 0.6
    out = silence(d)
    boing = sweep(220, 520, 0.18, "sine", 0.5) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t_axis(0.18))) * env(0.18, 0.003, 0.18)
    place(out, boing * 0.6, 0.0)
    place(out, blip(note(16), 0.2, "sine") * 0.4, 0.12)
    place(out, blip(note(21), 0.3, "sine") * 0.4, 0.22)
    return out


# --- Newer kill effect layers (soft: low-passed, short, nothing shrill) ----------

def cos_kill_balloon():
    """A rubbery squeak as the poodle twists up, then a soft pop."""
    d = 0.75
    out = silence(d)
    squeak = tone(520, 0.3, "tri", vibrato=0.06, vib_rate=22.0) * env(0.3, 0.04, 0.3, power=1.2)
    place(out, filt(squeak * (1.0 + 0.4 * sweep(1.0, 3.0, 0.3)), low=2500) * 0.5, 0.02)
    pop = filt(noise(0.08), low=3000, high=200) * env(0.08, 0.0005, 0.06, power=3.0)
    place(out, pop, 0.48, 0.9)
    place(out, sweep(260, 90, 0.12, "sine") * env(0.12, 0.001, 0.1) * 0.6, 0.48)
    return out


def cos_kill_disco():
    """A warm chord stab and a little glass tinkle as the ball shatters."""
    d = 0.9
    out = silence(d)
    chord = sum(tone(note(s), 0.4, "saw") for s in (-5, -1, 2, 7)) * env(0.4, 0.004, 0.38, power=1.6)
    place(out, filt(chord, low=1800) * 0.4, 0.0)
    for i in range(6):
        place(out, filt(bell(rand(1800, 2600), 0.25, gain=0.25, ratios=(1.0, 2.4), weights=(1.0, 0.3)), low=5000), 0.47 + i * 0.035)
    return out


def cos_kill_jackpot():
    """Reels clunk to a stop, three dings, then a few coins."""
    d = 0.95
    out = silence(d)
    for i in range(3):
        place(out, click(0.025, 1400, 0.6), 0.05 + i * 0.09)
        place(out, bell(note(12 + i * 4), 0.3, gain=0.35, ratios=(1.0, 2.0, 3.0), weights=(1.0, 0.3, 0.1)), 0.08 + i * 0.09)
    for i in range(5):
        place(out, filt(bell(rand(1500, 2200), 0.16, gain=0.25, ratios=(1.0, 2.4), weights=(1.0, 0.4)), low=5000), 0.42 + i * rand(0.04, 0.07))
    return out


def cos_kill_voxel():
    """A soft digital fall: a stepped arpeggio down over a filtered sweep."""
    d = 0.6
    out = silence(d)
    place(out, arpeggio([12, 7, 3, 0, -5, -9], 0.05, 0.06, "square", 0.45, low=3000), 0.0)
    place(out, sweep(900, 160, 0.45, "tri") * env(0.45, 0.01, 0.45, power=1.4) * 0.3, 0.02)
    return out


def cos_kill_ghost():
    """A friendly breathy 'ooo' that floats up and away."""
    d = 0.9
    out = silence(d)
    t = t_axis(0.8)
    pitch = 300 + 120 * np.sin(np.pi * t / 0.8)
    voice = np.sin(2 * np.pi * np.cumsum(pitch * (1 + 0.02 * np.sin(2 * np.pi * 6 * t))) / SR)
    voice = voice * env(0.8, 0.12, 0.8, power=2.0, release=0.2)
    place(out, filt(voice, low=1200) * 0.6, 0.02)
    place(out, filt(noise(0.8), low=1500, high=300) * env(0.8, 0.2, 0.8, power=1.0) * 0.15, 0.02)
    return out


def cos_kill_snow_globe():
    """Music-box notes inside the glass, then it pops with a soft chime."""
    d = 0.95
    out = silence(d)
    for i, s in enumerate((19, 23, 26, 31)):
        place(out, filt(bell(note(s), 0.35, gain=0.3, ratios=(1.0, 3.0), weights=(1.0, 0.2)), low=4500), i * 0.11)
    place(out, filt(noise(0.06), low=4000, high=500) * env(0.06, 0.0005, 0.05, power=3.0) * 0.6, 0.6)
    place(out, filt(bell(note(26), 0.35, gain=0.35), low=5000), 0.61)
    return out


def cos_kill_black_hole():
    """A deep whoomp that sucks in (rising noise), then a soft wink."""
    d = 0.9
    out = silence(d)
    place(out, sweep(220, 55, 0.55, "sine") * env(0.55, 0.05, 0.55, power=1.0) * 0.8, 0.0)
    suck = filt(noise(0.5), low=2500, high=300) * np.linspace(0.0, 1.0, int(SR * 0.5)) ** 2
    place(out, suck * 0.35, 0.03)
    place(out, sweep(120, 45, 0.18, "sine") * env(0.18, 0.001, 0.16) * 0.7, 0.53)
    place(out, filt(bell(note(19), 0.3, gain=0.3), low=4000), 0.54)
    return out


def cos_kill_tickets():
    """A ticket machine ratchet and a cheerful ding."""
    d = 0.8
    out = silence(d)
    for i in range(10):
        place(out, click(0.015, 1800, 0.5), i * 0.025)
    place(out, filt(bell(note(19), 0.45, gain=0.45, ratios=(1.0, 2.76), weights=(1.0, 0.3)), low=4500), 0.27)
    place(out, filt(noise(0.4), low=3000, high=800) * env(0.4, 0.05, 0.4, power=1.5) * 0.15, 0.3)
    return out


def cos_kill_pinata():
    """A papery thump and a rustle of streamers."""
    d = 0.7
    out = silence(d)
    place(out, sweep(150, 55, 0.16, "sine") * env(0.16, 0.001, 0.14) * 0.9, 0.0)
    place(out, filt(noise(0.06), low=2000, high=150) * env(0.06, 0.0005, 0.05, power=2.5) * 0.7, 0.0)
    for i in range(5):
        place(out, filt(noise(0.09), low=4000, high=1200) * env(0.09, 0.01, 0.09, power=1.5) * 0.25, 0.05 + i * rand(0.05, 0.09))
    return out


SOUNDS = [
    cos_select, cos_unequip, cos_unlock,
    cos_equip_operator, cos_equip_finish, cos_equip_charm, cos_equip_cell, cos_equip_decal, cos_equip_gloves,
    cos_equip_effect, cos_equip_tracer, cos_equip_banner, cos_equip_title,
    cos_kill_pixel, cos_kill_neon_ring, cos_kill_bubbles, cos_kill_snow, cos_kill_starburst, cos_kill_coins,
    cos_kill_firework, cos_kill_firework_pop, cos_kill_hearts,
    cos_kill_balloon, cos_kill_disco, cos_kill_jackpot, cos_kill_voxel, cos_kill_ghost, cos_kill_snow_globe,
    cos_kill_black_hole, cos_kill_tickets, cos_kill_pinata,
]

VARIANTS = [(cos_kill_bubbles, (0.92, 1.08)), (cos_kill_coins, (0.94, 1.06)), (cos_kill_pixel, (0.95, 1.05))]

# gen_audio exports a MUSIC folder path via *; this pack has no music or loops.
MUSIC = {}
LOOPS = {}
