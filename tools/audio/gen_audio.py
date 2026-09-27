"""Procedural sound design for Late Return (numpy/scipy synthesis).

These are functional, mood-appropriate placeholder sounds generated from
filtered noise, envelopes and simple oscillators. They are meant to be
replaced by recorded foley later (see docs/art_asset_requirements.md), but
they are mixed to sit together and to make the stealth/noise systems audible.
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "audio")
rng = np.random.default_rng(1337)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(int(SR * d))


def brown(d):
    x = np.cumsum(rng.standard_normal(int(SR * d)))
    x = signal.detrend(x)
    return x / (np.max(np.abs(x)) + 1e-9)


def lp(x, f, order=2):
    b, a = signal.butter(order, min(f, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env(n, a=0.005, d=0.1, s=0.0, r=0.0, hold=0.0):
    """Attack / decay (exp) envelope over n samples."""
    tt = np.arange(n) / SR
    e = np.ones(n)
    ai = tt < a
    e[ai] = tt[ai] / max(a, 1e-6)
    rest = tt >= a + hold
    e[rest] = s + (1 - s) * np.exp(-(tt[rest] - a - hold) / max(d, 1e-6))
    if r > 0:
        rn = int(r * SR)
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def fade(x, fi=0.005, fo=0.02):
    x = x.copy()
    a = min(int(fi * SR), len(x) // 4)
    b = min(int(fo * SR), len(x) // 4)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def pad(x, d):
    return np.concatenate([x, np.zeros(int(SR * d))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def reverb(x, room=0.3, wet=0.25, decay=1.2):
    n = int(SR * decay)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * room))
    ir = lp(ir, 4000)
    ir /= np.sum(np.abs(ir)) ** 0.5 * 8
    w = signal.fftconvolve(x, ir)[: len(x) + n]
    return mix(x * (1 - wet * 0.5), w * wet)


def save(name, x, group="sfx", peak=0.9, stereo=False):
    x = norm(fade(x), peak)
    d = os.path.join(OUT, group)
    os.makedirs(d, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(d, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# player foley
# ---------------------------------------------------------------------------
def footstep(kind, i):
    d = 0.18
    thud = lp(noise(d), 380 + i * 30) * env(int(SR * d), 0.002, 0.03)
    grit = bp(noise(d), 1800, 6000) * env(int(SR * d), 0.001, 0.012) * (0.5 if kind != "soft" else 0.15)
    heel = np.sin(2 * np.pi * (90 + i * 7) * t(d)) * env(int(SR * d), 0.001, 0.02) * 0.6
    x = thud * 1.0 + grit + heel
    if kind == "run":
        x = x + 0.6 * bp(noise(d), 600, 3000) * env(int(SR * d), 0.001, 0.02)
    if kind == "soft":
        x = lp(x, 900) * 0.5
    return reverb(x, 0.08, 0.12, 0.3)


def rummage(d=1.9, kind="shelf"):
    buf = np.zeros(int(SR * d))
    n_events = int(d * (14 if kind != "glass" else 10))
    for k in range(n_events):
        at = rng.uniform(0, d - 0.15)
        ln = rng.uniform(0.04, 0.14)
        if kind == "box" or rng.random() < 0.5:
            # cardboard / paper rustle
            s = bp(noise(ln), 1500, 7000) * env(int(SR * ln), 0.005, ln / 3)
        else:
            # cans / plastic clack
            f = rng.uniform(900, 2600)
            s = (np.sin(2 * np.pi * f * t(ln)) * 0.5 + bp(noise(ln), f * 0.8, f * 1.6)) * env(int(SR * ln), 0.001, 0.02)
        if kind == "glass" and rng.random() < 0.3:
            f = rng.uniform(2500, 5200)
            s = np.sin(2 * np.pi * f * t(ln)) * env(int(SR * ln), 0.0005, 0.03) * 0.8
        place(buf, s * rng.uniform(0.3, 1.0), at)
    buf += lp(noise(d), 500) * 0.05
    return reverb(buf, 0.12, 0.2, 0.5)


def register_open():
    d = 1.4
    buf = np.zeros(int(SR * d))
    # drawer slide + ding
    slide = bp(noise(0.35), 400, 2500) * env(int(SR * 0.35), 0.02, 0.2)
    place(buf, slide, 0.3)
    thunk = lp(noise(0.12), 300) * env(int(SR * 0.12), 0.001, 0.03) * 1.5
    place(buf, thunk, 0.62)
    ding = np.sin(2 * np.pi * 2350 * t(0.6)) * env(int(SR * 0.6), 0.001, 0.25) * 0.25
    place(buf, ding, 0.62)
    for k in range(6):
        f = rng.uniform(3000, 6000)
        c = np.sin(2 * np.pi * f * t(0.08)) * env(int(SR * 0.08), 0.0005, 0.02) * 0.3
        place(buf, c, 0.8 + k * 0.07 + rng.uniform(0, 0.03))
    return reverb(buf, 0.1, 0.2, 0.4)


def click(f=2500, d=0.04, amp=1.0):
    return (np.sin(2 * np.pi * f * t(d)) * 0.5 + hp(noise(d), 2000) * 0.7) * env(int(SR * d), 0.0005, 0.006) * amp


def gunshot():
    d = 2.6
    n = int(SR * d)
    crack = hp(noise(0.04), 1500) * env(int(SR * 0.04), 0.0002, 0.008) * 1.2
    body = lp(noise(0.5), 1400) * env(int(SR * 0.5), 0.0005, 0.06)
    boom = np.sin(2 * np.pi * 55 * t(0.4) * (1 - 0.3 * t(0.4))) * env(int(SR * 0.4), 0.001, 0.09)
    x = mix(crack, body * 0.9, boom * 0.8)
    x = np.tanh(x * 2.5)
    # long city echo tail
    tail = np.zeros(n)
    for k, (dl, g) in enumerate([(0.18, 0.35), (0.42, 0.22), (0.75, 0.14), (1.2, 0.08)]):
        place(tail, lp(x, 2200 - k * 400) * g, dl)
    out = mix(x, tail)
    return reverb(out, 0.5, 0.35, 2.0)


def knife_swing():
    d = 0.22
    tt = t(d)
    sweep = bp(noise(d), 800, 5000) * np.sin(np.pi * tt / d) ** 2
    return sweep * 0.8


def knife_hit():
    d = 0.3
    x = lp(noise(d), 700) * env(int(SR * d), 0.001, 0.04)
    x += bp(noise(d), 200, 900) * env(int(SR * d), 0.002, 0.08) * 0.8
    return np.tanh(x * 2)


def breath(kind):
    if kind == "in":
        d = 0.55
        x = bp(noise(d), 500, 3200) * np.sin(np.pi * t(d) / d) ** 1.5
        return x * 0.6
    if kind == "out":
        d = 0.8
        x = bp(noise(d), 350, 2200) * env(int(SR * d), 0.05, 0.25)
        return x * 0.6
    if kind == "gasp":
        d = 0.5
        x = bp(noise(d), 600, 3800) * np.sin(np.pi * t(d) / d) ** 0.7
        voice = np.sin(2 * np.pi * (180 + 60 * t(d)) * t(d)) * np.sin(np.pi * t(d) / d) * 0.12
        return x + bp(voice, 150, 1500)
    if kind == "wake":
        d = 2.2
        buf = np.zeros(int(SR * d))
        place(buf, breath("in") * 0.8, 0.0)
        place(buf, breath("out") * 0.9, 0.6)
        place(buf, breath("in") * 0.5, 1.4)
        return buf
    raise ValueError(kind)


def hurt(i):
    d = 0.5
    tt = t(d)
    f0 = 150 + i * 25
    v = signal.sawtooth(2 * np.pi * (f0 + 40 * np.exp(-tt * 8)) * tt) * env(int(SR * d), 0.01, 0.15)
    v = bp(v, 200, 2200)
    hit = lp(noise(0.12), 500) * env(int(SR * 0.12), 0.001, 0.03)
    return mix(v * 0.7, hit)


def death():
    d = 2.0
    tt = t(d)
    v = signal.sawtooth(2 * np.pi * (140 - 50 * tt / d) * tt) * env(int(SR * d), 0.02, 0.6)
    v = bp(v, 150, 1600)
    fall = lp(noise(0.3), 300) * env(int(SR * 0.3), 0.001, 0.08)
    buf = np.zeros(int(SR * d))
    place(buf, v * 0.6, 0)
    place(buf, fall * 1.2, 0.9)
    return reverb(buf, 0.3, 0.3, 1.0)


# ---------------------------------------------------------------------------
# zombies
# ---------------------------------------------------------------------------
def voice(d, f0, f1, rough=0.6, formants=((500, 1200), (1600, 2600)), vib=5.0):
    tt = t(d)
    f = np.linspace(f0, f1, len(tt)) * (1 + 0.04 * np.sin(2 * np.pi * vib * tt)) * (1 + 0.03 * rng.standard_normal(len(tt)).cumsum() / len(tt) * 10)
    ph = np.cumsum(2 * np.pi * f / SR)
    src = signal.sawtooth(ph) * (1 - rough) + noise(d) * rough * 0.6
    src *= 1 + 0.5 * np.sin(2 * np.pi * rng.uniform(15, 30) * tt)  # jitter / fry
    out = sum(bp(src, lo, hi) for lo, hi in formants)
    return out


def groan(i):
    d = rng.uniform(1.2, 2.0)
    v = voice(d, rng.uniform(70, 95), rng.uniform(55, 75), rough=0.55, formants=((180, 700), (900, 1500)))
    v *= np.sin(np.pi * t(d) / d) ** 1.2
    return reverb(v, 0.25, 0.25, 1.0)


def growl():
    d = 0.9
    v = voice(d, 110, 90, rough=0.7, formants=((250, 900), (1000, 2000)), vib=9)
    v *= env(int(SR * d), 0.05, 0.4)
    return reverb(v, 0.2, 0.2, 0.8)


def alert():
    d = 0.7
    v = voice(d, 140, 210, rough=0.5, formants=((300, 1100), (1400, 2600)))
    v *= env(int(SR * d), 0.02, 0.3)
    return reverb(v, 0.2, 0.2, 0.8)


def roar():
    d = 2.2
    tt = t(d)
    v = voice(d, 120, 95, rough=0.65, formants=((250, 1000), (1100, 2400), (2600, 4200)), vib=11)
    shape = np.minimum(1, tt / 0.12) * np.exp(-np.maximum(0, tt - 0.9) / 0.5)
    v = np.tanh(v * shape * 3.0)
    return reverb(v, 0.6, 0.4, 2.2)


def zombie_attack():
    d = 0.6
    v = voice(d, 160, 110, rough=0.6, formants=((300, 1200), (1500, 2800)))
    v *= env(int(SR * d), 0.01, 0.2)
    swish = bp(noise(d), 700, 4000) * np.sin(np.pi * t(d) / d) ** 3 * 0.6
    return mix(v, swish)


def zombie_hit():
    d = 0.4
    x = lp(noise(d), 500) * env(int(SR * d), 0.001, 0.05)
    v = voice(0.3, 120, 80, 0.7) * env(int(SR * 0.3), 0.005, 0.1) * 0.6
    return mix(np.tanh(x * 2), v)


def zombie_death():
    d = 1.6
    v = voice(d, 100, 50, rough=0.6, formants=((200, 800), (900, 1700)))
    v *= env(int(SR * d), 0.02, 0.5)
    fall = lp(noise(0.35), 280) * env(int(SR * 0.35), 0.001, 0.09)
    buf = np.zeros(int(SR * d))
    place(buf, v, 0)
    place(buf, fall * 1.5, 0.7)
    return buf


def eating():
    d = 3.0
    buf = np.zeros(int(SR * d))
    for k in range(22):
        at = rng.uniform(0, d - 0.2)
        ln = rng.uniform(0.06, 0.18)
        s = lp(noise(ln), rng.uniform(600, 1400)) * env(int(SR * ln), 0.005, ln / 3)
        place(buf, s * rng.uniform(0.4, 1.0), at)
    buf += lp(voice(d, 70, 65, 0.8, ((150, 600),)), 800) * 0.25
    return buf


def zombie_step(i):
    d = 0.25
    x = lp(noise(d), 300 + i * 40) * env(int(SR * d), 0.004, 0.05)
    drag = bp(noise(d), 500, 2500) * env(int(SR * d), 0.03, 0.08) * 0.35
    return mix(x, drag)


# ---------------------------------------------------------------------------
# UI & misc
# ---------------------------------------------------------------------------
def blip(f, d=0.03, amp=0.5):
    return np.sign(np.sin(2 * np.pi * f * t(d))) * env(int(SR * d), 0.001, d / 3) * amp


def door_open():
    d = 1.3
    tt = t(d)
    creak_f = 300 + 150 * np.sin(2 * np.pi * 1.3 * tt) + 80 * rng.standard_normal(len(tt)).cumsum() / len(tt)
    creak = signal.sawtooth(np.cumsum(2 * np.pi * creak_f / SR)) * (np.abs(np.sin(2 * np.pi * 23 * tt)) ** 4)
    creak = bp(creak, 400, 3000) * env(int(SR * d), 0.1, 0.6) * 0.5
    push = lp(noise(0.2), 400) * env(int(SR * 0.2), 0.001, 0.05)
    bell = sum(np.sin(2 * np.pi * f * tt) for f in (1760, 2217)) * env(int(SR * d), 0.002, 0.4) * 0.12
    return reverb(mix(push, creak, bell), 0.3, 0.3, 1.0)


def item_pop():
    d = 0.2
    return mix(bp(noise(d), 800, 3000) * env(int(SR * d), 0.001, 0.04), blip(900, 0.05, 0.2))


def item_land(i):
    d = 0.15
    f = 1200 + i * 500
    return (np.sin(2 * np.pi * f * t(d)) * 0.4 + bp(noise(d), 500, 2500)) * env(int(SR * d), 0.0005, 0.02)


def pickup():
    d = 0.35
    s = bp(noise(d), 1000, 5000) * env(int(SR * d), 0.005, 0.06)
    tone = np.sin(2 * np.pi * 660 * t(d)) * env(int(SR * d), 0.002, 0.08) * 0.2
    tone2 = np.sin(2 * np.pi * 990 * t(d)) * env(int(SR * d), 0.06, 0.1) * 0.15
    return mix(s * 0.6, tone, tone2)


def bag(open_=True):
    d = 0.45
    zip_ = bp(noise(d), 2000, 7000) * (np.abs(np.sin(2 * np.pi * 45 * t(d))) ** 2) * env(int(SR * d), 0.01, 0.2)
    rustle = bp(noise(d), 600, 3000) * env(int(SR * d), 0.02, 0.15) * 0.5
    return mix(zip_ if open_ else zip_[::-1] * 0.8, rustle)


def tube_buzz():
    d = 0.6
    tt = t(d)
    x = signal.sawtooth(2 * np.pi * 100 * tt) * 0.3 + signal.square(2 * np.pi * 200 * tt) * 0.1
    x = bp(x, 150, 3000) * (rng.random(len(tt)) > 0.02) * env(int(SR * d), 0.01, 0.2)
    return x


def objective():
    d = 1.2
    tt = t(d)
    x = sum(np.sin(2 * np.pi * f * tt) * env(int(SR * d), 0.01 + k * 0.08, 0.35) for k, f in enumerate([392, 523, 659]))
    return reverb(x * 0.3, 0.4, 0.4, 1.2)


def text_tick():
    return blip(1400, 0.018, 0.25) + bp(noise(0.018), 2000, 6000) * env(int(SR * 0.018), 0.0005, 0.004) * 0.3


# ---------------------------------------------------------------------------
# ambience loops (seamless: crossfade end into start)
# ---------------------------------------------------------------------------
def loopify(x, xf=1.0):
    n = int(SR * xf)
    a = x[:n]
    b = x[-n:]
    w = np.linspace(0, 1, n)
    out = x[n:].copy()
    out[-n:] = b * (1 - w) + a * w
    return out


def amb_store():
    d = 24.0
    base = lp(brown(d), 220) * 0.35 + lp(noise(d), 120) * 0.2
    hum = np.sin(2 * np.pi * 50 * t(d)) * 0.02
    buf = mix(base, hum)
    # drips, creaks, distant metal
    for k in range(10):
        at = rng.uniform(0.5, d - 2)
        f = rng.uniform(1500, 3000)
        drip = np.sin(2 * np.pi * f * t(0.1) * (1 + 2 * t(0.1))) * env(int(SR * 0.1), 0.001, 0.02) * 0.12
        place(buf, reverb(drip, 0.3, 0.5, 0.8), at)
    for k in range(3):
        at = rng.uniform(1, d - 3)
        cr = bp(signal.sawtooth(2 * np.pi * rng.uniform(80, 140) * t(1.2)) * np.abs(np.sin(2 * np.pi * 9 * t(1.2))) ** 6, 200, 1500)
        place(buf, cr * env(int(SR * 1.2), 0.2, 0.4) * 0.12, at)
    for k in range(2):
        at = rng.uniform(2, d - 4)
        clang = sum(np.sin(2 * np.pi * f * t(2.0)) for f in (310, 523, 811)) * env(int(SR * 2.0), 0.002, 0.5) * 0.04
        place(buf, lp(reverb(clang, 0.8, 0.8, 2.0), 1500), at)
    return loopify(buf)


def amb_wind(d=20.0, strength=1.0, muffled=True):
    x = brown(d)
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t(d) + 1) * np.sin(2 * np.pi * 0.023 * t(d))
    w = bp(noise(d), 150, 700 if muffled else 1600) * gust * 0.5 + lp(x, 300) * 0.4
    whistle = bp(noise(d), 800, 900) * gust ** 3 * (0.15 if not muffled else 0.05)
    return loopify((w + whistle) * strength)


def amb_street():
    d = 30.0
    buf = amb_wind(d + 1.0, 1.0, False)[: int(SR * d)] * 0.8
    for k in range(4):
        at = rng.uniform(1, d - 3)
        g = groan(k) * 0.08
        place(buf, lp(g, 900), at)
    for k in range(3):
        at = rng.uniform(1, d - 3)
        clang = sum(np.sin(2 * np.pi * f * t(2.0)) for f in (180, 377, 690)) * env(int(SR * 2.0), 0.002, 0.4) * 0.05
        place(buf, lp(reverb(clang, 1.0, 0.9, 2.5), 1200), at)
    for k in range(3):
        at = rng.uniform(1, d - 3)
        crow = bp(signal.sawtooth(2 * np.pi * 700 * t(0.25)), 600, 2500) * env(int(SR * 0.25), 0.01, 0.08) * 0.03
        place(buf, reverb(crow, 0.6, 0.6, 1.5), at)
    return loopify(buf)


def amb_camp():
    d = 24.0
    buf = amb_wind(d + 1.0, 0.5, True)[: int(SR * d)]
    # window rattle + far zombie
    for k in range(4):
        at = rng.uniform(1, d - 2)
        rat = bp(noise(0.4), 300, 1800) * np.abs(np.sin(2 * np.pi * 18 * t(0.4))) ** 8 * 0.12
        place(buf, rat, at)
    place(buf, lp(groan(9), 600) * 0.05, rng.uniform(6, 16))
    # candle/room tone
    buf += lp(brown(d), 200)[: len(buf)] * 0.12
    return loopify(buf)


def amb_menu():
    d = 28.0
    buf = amb_wind(d + 1.0, 0.9, False)[: int(SR * d)]
    for k in range(3):
        at = rng.uniform(1, d - 4)
        clang = sum(np.sin(2 * np.pi * f * t(3.0)) for f in (140, 297, 530)) * env(int(SR * 3.0), 0.002, 0.7) * 0.05
        place(buf, lp(reverb(clang, 1.2, 0.9, 3.0), 1000), at)
    for k in range(2):
        at = rng.uniform(1, d - 4)
        creak = bp(signal.sawtooth(2 * np.pi * rng.uniform(60, 90) * t(2.0)) * np.abs(np.sin(2 * np.pi * 5 * t(2.0))) ** 6, 150, 900)
        place(buf, creak * env(int(SR * 2.0), 0.5, 0.6) * 0.1, at)
    return loopify(buf)


def cough():
    d = 0.9
    buf = np.zeros(int(SR * d))
    for at, a in [(0.0, 1.0), (0.28, 0.7)]:
        ln = 0.22
        burst = bp(noise(ln), 400, 3500) * env(int(SR * ln), 0.005, 0.06) * a
        v = voice(ln, 260, 200, 0.7, ((400, 1400), (1800, 3000))) * env(int(SR * ln), 0.005, 0.05) * 0.4 * a
        place(buf, burst + v, at)
    return reverb(buf, 0.2, 0.25, 0.6)


def heartbeat():
    d = 0.9
    buf = np.zeros(int(SR * d))
    for at, a in [(0.0, 1.0), (0.22, 0.7)]:
        b = np.sin(2 * np.pi * 50 * t(0.15)) * env(int(SR * 0.15), 0.005, 0.04) * a
        place(buf, b, at)
    return lp(buf, 200)


def sting_death():
    d = 4.0
    tt = t(d)
    x = sum(np.sin(2 * np.pi * f * tt) for f in (55, 58.3, 82.4)) * np.minimum(1, tt / 0.5) * np.exp(-tt / 1.8)
    return reverb(x * 0.4, 1.0, 0.6, 3.0)


def main():
    for i in range(1, 5):
        save(f"step_{i}", footstep("walk", i), peak=0.5)
        save(f"step_run_{i}", footstep("run", i), peak=0.65)
    for i in range(1, 4):
        save(f"step_soft_{i}", footstep("soft", i), peak=0.25)
    save("jump", footstep("walk", 2)[: int(SR * 0.12)] * 0.6, peak=0.4)
    for i in range(1, 3):
        save(f"land_{i}", footstep("run", i + 2) * 1.2, peak=0.8)
    for i in range(1, 4):
        save(f"rummage_{i}", rummage(1.9, "shelf"), peak=0.6)
    save("rummage_glass", rummage(1.9, "glass"), peak=0.6)
    save("rummage_box", rummage(1.9, "box"), peak=0.6)
    save("register", register_open(), peak=0.7)
    save("item_pop", item_pop(), peak=0.5)
    for i in range(1, 3):
        save(f"item_land_{i}", item_land(i), peak=0.35)
    save("pickup", pickup(), peak=0.6)
    save("flashlight_click", mix(click(3200, 0.03), pad(click(2100, 0.03, 0.6), 0.02)), peak=0.5)
    save("equip", mix(bp(noise(0.25), 800, 5000) * env(int(SR * 0.25), 0.01, 0.06), pad(np.zeros(int(SR * 0.12)), 0) , ), peak=0.45)
    save("holster", bp(noise(0.3), 500, 3000) * env(int(SR * 0.3), 0.03, 0.08), peak=0.4)
    save("gunshot", gunshot(), peak=0.98)
    save("dry_fire", click(1800, 0.05), peak=0.5)
    save("knife_swing", knife_swing(), peak=0.55)
    save("knife_hit", knife_hit(), peak=0.8)
    save("breath_in", breath("in"), peak=0.35)
    save("breath_out", breath("out"), peak=0.35)
    for i in range(1, 4):
        save(f"gasp_{i}", breath("gasp"), peak=0.55)
    save("wake_breath", breath("wake"), peak=0.4)
    for i in range(1, 3):
        save(f"player_hurt_{i}", hurt(i), peak=0.85)
    save("player_death", death(), peak=0.8)
    for i in range(1, 5):
        save(f"zombie_groan_{i}", groan(i), peak=0.7)
    save("zombie_growl", growl(), peak=0.75)
    save("zombie_alert", alert(), peak=0.8)
    save("zombie_roar", roar(), peak=0.98)
    save("zombie_attack", zombie_attack(), peak=0.85)
    save("zombie_hit", zombie_hit(), peak=0.85)
    save("zombie_death", zombie_death(), peak=0.8)
    save("zombie_eat", eating(), peak=0.7)
    for i in range(1, 4):
        save(f"zombie_step_{i}", zombie_step(i), peak=0.4)
    save("door_open", door_open(), peak=0.7)
    save("tube_buzz", tube_buzz(), peak=0.4)
    save("heartbeat", heartbeat(), peak=0.8)
    save("cough", cough(), peak=0.5)
    save("sting_death", sting_death(), peak=0.8)
    save("hide_enter", bp(noise(0.5), 300, 2500) * env(int(SR * 0.5), 0.02, 0.15), peak=0.5)
    save("hide_exit", bp(noise(0.4), 300, 2500) * env(int(SR * 0.4), 0.01, 0.12), peak=0.5)
    save("bag_open", bag(True), group="ui", peak=0.45)
    save("bag_close", bag(False), group="ui", peak=0.4)
    save("text_tick", text_tick(), group="ui", peak=0.3)
    save("ui_move", blip(700, 0.03, 0.4), group="ui", peak=0.3)
    save("ui_confirm", mix(blip(500, 0.05), pad(blip(750, 0.06), 0.05)), group="ui", peak=0.4)
    save("ui_back", mix(blip(600, 0.05), pad(blip(420, 0.06), 0.05)), group="ui", peak=0.35)
    save("ui_soft", blip(500, 0.02, 0.3), group="ui", peak=0.2)
    save("objective", objective(), group="ui", peak=0.5)
    save("amb_store", amb_store(), group="amb", peak=0.45)
    save("amb_wind_inside", amb_wind(20.0, 1.0, True), group="amb", peak=0.3)
    save("amb_street", amb_street(), group="amb", peak=0.55)
    save("amb_camp", amb_camp(), group="amb", peak=0.4)
    save("amb_menu", amb_menu(), group="amb", peak=0.5)
    print("audio ok")


if __name__ == "__main__":
    main()
