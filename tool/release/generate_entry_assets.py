#!/usr/bin/env python3
"""Generate the approved artwork for the silent Hoopito launch."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FOREGROUND = ROOT / "assets/icons/hoopito-app-icon-foreground.png"

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


def main() -> None:
    write_launch_artwork()


if __name__ == "__main__":
    main()
