"""Generate the game's original, offline PCM effects. No third-party samples."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "app/FPSPretend/Audio"
RATE = 44100


def write(name, duration, sample):
    rng = random.Random(name)
    count = round(duration * RATE)
    values = []
    for i in range(count):
        t = i / RATE
        fade = min(1, t / 0.002, (duration - t) / 0.012)
        values.append(sample(t, rng) * max(0, fade))
    peak = max(abs(v) for v in values)
    assert peak > 0.01, name
    pcm = [round(v / peak * 0.62 * 32767) for v in values]
    assert sum(v * v for v in pcm) / len(pcm) > 10000, name
    with wave.open(str(OUT / (name + ".wav")), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(struct.pack("<" + "h" * count, *pcm))
    with wave.open(str(OUT / (name + ".wav")), "rb") as audio:
        assert audio.getnframes() == count and audio.getnchannels() == 1


def sine(hz, t):
    return math.sin(math.tau * hz * t)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for variant in range(3):
        pitch = 1 + variant * 0.12
        write(f"shot_pop_{variant}", 0.13, lambda t, r, p=pitch:
              (sine(420 * p - 900 * t, t) + 0.15 * r.uniform(-1, 1)) * math.exp(-35 * t))
        write(f"shot_toy_{variant}", 0.16, lambda t, r, p=pitch:
              (sine(720 * p, t) + 0.3 * sine(1080 * p, t) + 0.12 * r.uniform(-1, 1)) * math.exp(-30 * t))
        write(f"shot_soft_{variant}", 0.15, lambda t, r, p=pitch:
              (sine(180 * p, t) + 0.2 * sine(300 * p, t) + 0.05 * r.uniform(-1, 1)) * math.exp(-28 * t))
    write("hit_gel", 0.15, lambda t, r: sine(350 - 1100 * t, t) * math.exp(-25 * t))
    write("hit_cloth", 0.10, lambda t, r: (0.2 * r.uniform(-1, 1) + sine(95, t)) * math.exp(-45 * t))
    write("hit_digital", 0.12, lambda t, r: sine(880 if t < 0.055 else 1320, t) * math.exp(-20 * t))
    write("hit_rubber", 0.18, lambda t, r: sine(220 + 40 * sine(18, t), t) * math.exp(-23 * t))
    write("hit_paper", 0.11, lambda t, r: r.uniform(-1, 1) * (0.7 + 0.3 * sine(70, t)) * math.exp(-35 * t))
    write("hit_metal", 0.17, lambda t, r: (sine(900, t) + 0.5 * sine(1473, t) + 0.2 * sine(2301, t)) * math.exp(-25 * t))
    write("resolve", 0.36, lambda t, r: sine([523.25, 659.25, 783.99][min(2, int(t / 0.10))], t) * math.exp(-4 * t))
    write("finale", 0.8, lambda t, r: (sine([523.25, 659.25, 783.99, 1046.5][min(3, int(t / 0.16))], t)
          + 0.2 * sine(523.25, t)) * math.exp(-2 * t))
    assert len(list(OUT.glob("*.wav"))) == 17
    print("17 original, non-silent PCM effects generated and checked.")
