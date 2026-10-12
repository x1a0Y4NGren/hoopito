#!/usr/bin/env python3
"""Generate Hoopito launch artwork and the original entry swish sound."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FOREGROUND = ROOT / "assets/icons/hoopito-app-icon-foreground.png"
AUDIO = ROOT / "assets/audio/entry_swish.wav"

ANDROID_DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}
IOS_SCALES = {"": 1, "@2x": 2, "@3x": 3}
LAUNCH_CANVAS_POINTS = 288
INITIAL_SCALE = 0.78
SAMPLE_RATE = 44_100
SWISH_SECONDS = 0.18
SWISH_SEED = 0x48545243


def scale_about_center(source: Image.Image, factor: float) -> Image.Image:
    width = round(source.width * factor)
    height = round(source.height * factor)
    resized = source.resize((width, height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.alpha_composite(
        resized,
        dest=((source.width - width) // 2, (source.height - height) // 2),
    )
    return result


def write_launch_artwork() -> None:
    with Image.open(FOREGROUND) as foreground:
        native = scale_about_center(foreground.convert('RGBA'), INITIAL_SCALE)
    for density, scale in ANDROID_DENSITIES.items():
        size = round(LAUNCH_CANVAS_POINTS * scale)
        destination = (
            ROOT
            / f"android/app/src/main/res/drawable-{density}/launch_mark.png"
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        native.resize((size, size), Image.Resampling.LANCZOS).save(destination)

    ios_dir = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for suffix, scale in IOS_SCALES.items():
        size = LAUNCH_CANVAS_POINTS * scale
        native.resize((size, size), Image.Resampling.LANCZOS).save(
            ios_dir / f"LaunchImage{suffix}.png"
        )


def write_swish_audio() -> None:
    rng = random.Random(SWISH_SEED)
    sample_count = round(SAMPLE_RATE * SWISH_SECONDS)
    samples: list[float] = []
    previous_noise = 0.0
    filtered_noise = 0.0
    phase = 0.0

    for index in range(sample_count):
        time = index / SAMPLE_RATE
        normalized = time / SWISH_SECONDS
        attack = min(1.0, time / 0.008)
        release = max(0.0, 1.0 - normalized) ** 1.65
        envelope = attack * release

        noise = rng.uniform(-1.0, 1.0)
        high_pass = noise - previous_noise * 0.88
        previous_noise = noise
        filtered_noise = filtered_noise * 0.58 + high_pass * 0.42

        frequency = 1_850 - 900 * normalized
        phase += 2 * math.pi * frequency / SAMPLE_RATE
        net_texture = filtered_noise * (0.72 + 0.28 * math.sin(phase))

        rim_envelope = math.exp(-time * 72)
        rim_tick = (
            math.sin(2 * math.pi * 2_420 * time)
            + 0.34 * math.sin(2 * math.pi * 3_580 * time)
        ) * rim_envelope
        sample = 0.34 * net_texture * envelope + 0.12 * rim_tick
        samples.append(sample)

    peak = max(abs(sample) for sample in samples)
    target_peak = 0.55
    pcm = [
        struct.pack("<h", round(sample * target_peak / peak * 32_767))
        for sample in samples
    ]
    AUDIO.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(AUDIO), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(b"".join(pcm))


def main() -> None:
    write_launch_artwork()
    write_swish_audio()


if __name__ == "__main__":
    main()
