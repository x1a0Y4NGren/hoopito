#!/usr/bin/env python3
"""Normalize and regenerate Hoopito launcher icon resources."""

from __future__ import annotations

import argparse
import json
from decimal import Decimal
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
FOREGROUND = ROOT / 'assets/icons/hoopito-app-icon-foreground.png'
MASTER = ROOT / 'assets/icons/hoopito-app-icon.png'
MONOCHROME = ROOT / 'assets/icons/hoopito-app-icon-monochrome.png'
IOS_CATALOG = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
ANDROID_RES = ROOT / 'android/app/src/main/res'

BACKGROUND = (0x10, 0x11, 0x12)
WARM_WHITE = (0xF4, 0xF3, 0xEF)
ARENA_ORANGE = (0xFF, 0x5A, 0x1F)
CANVAS_SIZE = 1024
SAFE_ZONE_SIZE = 620

ANDROID_LEGACY_SIZES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}
ANDROID_ADAPTIVE_SIZES = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}


def _canonicalize_colors(image: Image.Image) -> Image.Image:
    """Keep the mascot's orange body, white eye, and black facial details."""
    rgba = image.convert('RGBA')
    canonical = Image.new('RGBA', rgba.size)
    source_pixels = rgba.load()
    output_pixels = canonical.load()

    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha < 8:
                output_pixels[x, y] = (0, 0, 0, 0)
                continue
            color = min(
                (BACKGROUND, ARENA_ORANGE, WARM_WHITE),
                key=lambda candidate: sum(
                    (component - target) ** 2
                    for component, target in zip((red, green, blue), candidate)
                ),
            )
            output_pixels[x, y] = (*color, alpha)

    return canonical


def _monochrome_foreground(foreground: Image.Image) -> Image.Image:
    """Use negative space for the pupil, grin, and seams in themed icons."""
    monochrome = Image.new('RGBA', foreground.size, (*WARM_WHITE, 0))
    monochrome.putdata([
        (*WARM_WHITE, 0 if pixel[:3] == BACKGROUND else pixel[3])
        for pixel in foreground.convert('RGBA').get_flattened_data()
    ])
    return monochrome


def import_imagegen_source(source_path: Path) -> None:
    """Normalize one transparent ImageGen result into the launcher safe zone."""
    source = Image.open(source_path).convert('RGBA')
    alpha = source.getchannel('A')
    if alpha.getextrema()[0] == 255:
        raise ValueError('ImageGen source must contain a transparent background')

    bounds = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bounds is None:
        raise ValueError('ImageGen source contains no visible pixels')

    cropped = _canonicalize_colors(source.crop(bounds))
    scale = min(SAFE_ZONE_SIZE / cropped.width, SAFE_ZONE_SIZE / cropped.height)
    normalized_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    normalized = cropped.resize(normalized_size, Image.Resampling.LANCZOS)
    normalized = _canonicalize_colors(normalized)

    canvas = Image.new('RGBA', (CANVAS_SIZE, CANVAS_SIZE))
    offset = (
        (CANVAS_SIZE - normalized.width) // 2,
        (CANVAS_SIZE - normalized.height) // 2,
    )
    canvas.alpha_composite(normalized, offset)
    FOREGROUND.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(FOREGROUND, optimize=True)


def _resize_foreground(size: int) -> Image.Image:
    foreground = Image.open(FOREGROUND).convert('RGBA')
    resized = foreground.resize((size, size), Image.Resampling.LANCZOS)
    return _canonicalize_colors(resized)


def _save_rgb(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert('RGB').save(path, optimize=True)


def generate_resources() -> None:
    foreground = Image.open(FOREGROUND).convert('RGBA')
    if foreground.size != (CANVAS_SIZE, CANVAS_SIZE):
        raise ValueError(f'{FOREGROUND} must be {CANVAS_SIZE}x{CANVAS_SIZE}')

    master = Image.new('RGBA', foreground.size, (*BACKGROUND, 255))
    master.alpha_composite(foreground)
    _save_rgb(master, MASTER)
    monochrome_source = _monochrome_foreground(foreground)
    monochrome_source.save(MONOCHROME, optimize=True)

    for locale in ('en-US', 'zh-CN'):
        store_icon = ROOT / f'fastlane/metadata/android/{locale}/images/icon.png'
        _save_rgb(master.resize((512, 512), Image.Resampling.LANCZOS), store_icon)

    for density, size in ANDROID_LEGACY_SIZES.items():
        directory = ANDROID_RES / f'mipmap-{density}'
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        for filename in ('ic_launcher.png', 'ic_launcher_round.png'):
            _save_rgb(resized, directory / filename)

    for density, size in ANDROID_ADAPTIVE_SIZES.items():
        adaptive = _resize_foreground(size)
        adaptive_path = ANDROID_RES / f'drawable-{density}/ic_launcher_foreground.png'
        adaptive_path.parent.mkdir(parents=True, exist_ok=True)
        adaptive.save(adaptive_path, optimize=True)

        monochrome = monochrome_source.resize((size, size), Image.Resampling.LANCZOS)
        # Alpha edges are antialiased; every visible pixel stays one ink color.
        monochrome_rgb = Image.new('RGBA', monochrome.size, (*WARM_WHITE, 0))
        monochrome_rgb.putalpha(monochrome.getchannel('A'))
        monochrome = monochrome_rgb
        monochrome.save(
            adaptive_path.with_name('ic_launcher_monochrome.png'),
            optimize=True,
        )

    contents = json.loads((IOS_CATALOG / 'Contents.json').read_text())
    for entry in contents['images']:
        filename = entry.get('filename')
        if filename is None:
            continue
        point_size = Decimal(entry['size'].split('x')[0])
        scale = Decimal(entry['scale'].removesuffix('x'))
        pixel_size = int(point_size * scale)
        output = master.resize(
            (pixel_size, pixel_size),
            Image.Resampling.LANCZOS,
        )
        _save_rgb(output, IOS_CATALOG / filename)


def validate_resources() -> None:
    foreground = Image.open(FOREGROUND).convert('RGBA')
    assert foreground.size == (CANVAS_SIZE, CANVAS_SIZE)
    assert foreground.getchannel('A').getextrema() == (0, 255)
    bounds = foreground.getchannel('A').point(
        lambda value: 255 if value >= 8 else 0,
    ).getbbox()
    assert bounds is not None
    assert bounds[2] - bounds[0] <= SAFE_ZONE_SIZE
    assert bounds[3] - bounds[1] <= SAFE_ZONE_SIZE
    visible_colors = {
        pixel[:3] for pixel in foreground.get_flattened_data() if pixel[3] >= 8
    }
    assert visible_colors == {BACKGROUND, ARENA_ORANGE, WARM_WHITE}
    monochrome_source = Image.open(MONOCHROME).convert('RGBA')
    assert monochrome_source.tobytes() == _monochrome_foreground(foreground).tobytes()

    master = Image.open(MASTER)
    assert master.size == (CANVAS_SIZE, CANVAS_SIZE)
    assert master.mode in {'RGB', 'P'}
    master_rgb = master.convert('RGB')
    foreground_alpha = foreground.getchannel('A')
    for pixel, alpha in zip(
        master_rgb.get_flattened_data(),
        foreground_alpha.get_flattened_data(),
    ):
        if alpha == 0:
            assert pixel == BACKGROUND

    for density, size in ANDROID_LEGACY_SIZES.items():
        directory = ANDROID_RES / f'mipmap-{density}'
        for filename in ('ic_launcher.png', 'ic_launcher_round.png'):
            path = directory / filename
            assert path.is_file(), f'Missing legacy launcher resource: {path}'
            icon = Image.open(path)
            assert icon.size == (size, size)
            assert 'A' not in icon.getbands()

    for density, size in ANDROID_ADAPTIVE_SIZES.items():
        directory = ANDROID_RES / f'drawable-{density}'
        adaptive = Image.open(directory / 'ic_launcher_foreground.png').convert('RGBA')
        monochrome = Image.open(directory / 'ic_launcher_monochrome.png').convert('RGBA')
        assert adaptive.size == (size, size)
        assert monochrome.size == (size, size)
        assert adaptive.getchannel('A').getextrema() == (0, 255)
        assert monochrome.getchannel('A').getextrema() == (0, 255)
        expected_alpha = monochrome_source.resize(
            (size, size), Image.Resampling.LANCZOS,
        ).getchannel('A')
        assert monochrome.getchannel('A').tobytes() == expected_alpha.tobytes(), (
            f'Monochrome details do not match the mascot: {density}'
        )
        visible_monochrome = {
            pixel[:3]
            for pixel in monochrome.get_flattened_data()
            if pixel[3] > 0
        }
        assert visible_monochrome == {WARM_WHITE}

    for locale in ('en-US', 'zh-CN'):
        icon = Image.open(ROOT / f'fastlane/metadata/android/{locale}/images/icon.png')
        assert icon.mode == 'RGB' and icon.size == (512, 512)
        expected = master_rgb.resize((512, 512), Image.Resampling.LANCZOS)
        assert icon.tobytes() == expected.tobytes()

    contents = json.loads((IOS_CATALOG / 'Contents.json').read_text())
    for entry in contents['images']:
        filename = entry.get('filename')
        if filename is None:
            continue
        point_size = Decimal(entry['size'].split('x')[0])
        scale = Decimal(entry['scale'].removesuffix('x'))
        expected = int(point_size * scale)
        icon = Image.open(IOS_CATALOG / filename)
        assert icon.size == (expected, expected)
        assert 'A' not in icon.getbands()

    android_namespace = '{http://schemas.android.com/apk/res/android}'
    manifest = ElementTree.parse(
        ROOT / 'android/app/src/main/AndroidManifest.xml',
    ).getroot()
    application = manifest.find('application')
    assert application is not None
    assert application.attrib[f'{android_namespace}icon'] == '@mipmap/ic_launcher'
    assert application.attrib[f'{android_namespace}roundIcon'] == '@mipmap/ic_launcher_round'

    for qualifier in ('mipmap-anydpi-v26', 'mipmap-anydpi-v33'):
        for filename in ('ic_launcher.xml', 'ic_launcher_round.xml'):
            root = ElementTree.parse(ANDROID_RES / qualifier / filename).getroot()
            assert root.tag == 'adaptive-icon'
            background = root.find('background')
            foreground_node = root.find('foreground')
            assert background is not None
            assert foreground_node is not None
            assert background.attrib[f'{android_namespace}drawable'] == (
                '@color/ic_launcher_background'
            )
            assert foreground_node.attrib[f'{android_namespace}drawable'] == (
                '@drawable/ic_launcher_foreground'
            )
            monochrome = root.find('monochrome')
            if qualifier.endswith('v33'):
                assert monochrome is not None
                assert monochrome.attrib[f'{android_namespace}drawable'] == (
                    '@drawable/ic_launcher_monochrome'
                )
            else:
                assert monochrome is None

    colors = ElementTree.parse(ANDROID_RES / 'values/colors.xml').getroot()
    background_color = colors.find("color[@name='ic_launcher_background']")
    assert background_color is not None
    assert background_color.text == '#101112'


def _mask(size: int, mask_name: str) -> Image.Image:
    mask = Image.new('L', (size, size))
    if mask_name == 'circle':
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    elif mask_name == 'rounded-square':
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size - 1, size - 1),
            radius=round(size * 0.22),
            fill=255,
        )
    elif mask_name == 'squircle':
        pixels = mask.load()
        radius = (size - 1) / 2
        for y in range(size):
            normalized_y = abs((y - radius) / radius)
            for x in range(size):
                normalized_x = abs((x - radius) / radius)
                if normalized_x**4 + normalized_y**4 <= 1:
                    pixels[x, y] = 255
    else:
        raise ValueError(f'Unknown mask: {mask_name}')
    return mask


def generate_contact_sheet(output_path: Path) -> None:
    sizes = (1024, 192, 96, 48, 32)
    masks = ('circle', 'rounded-square', 'squircle')
    surroundings = (('light', (232, 232, 228)), ('dark', (4, 5, 6)))
    cell_width = 220
    cell_height = 220
    label_height = 28
    sheet = Image.new(
        'RGB',
        (cell_width * len(sizes), label_height + cell_height * 6),
        (128, 128, 128),
    )
    draw = ImageDraw.Draw(sheet)
    master = Image.open(MASTER).convert('RGBA')

    for column, size in enumerate(sizes):
        draw.text(
            (column * cell_width + 8, 8),
            f'{size} px source',
            fill=(255, 255, 255),
        )
        for row, (surrounding_name, surrounding) in enumerate(surroundings):
            for mask_index, mask_name in enumerate(masks):
                actual_row = row * len(masks) + mask_index
                cell = Image.new('RGB', (cell_width, cell_height), surrounding)
                icon = master.resize((size, size), Image.Resampling.LANCZOS)
                icon.putalpha(_mask(size, mask_name))
                preview_size = 176
                icon = icon.resize(
                    (preview_size, preview_size),
                    Image.Resampling.NEAREST,
                )
                position = ((cell_width - preview_size) // 2, 26)
                cell.paste(icon, position, icon)
                ImageDraw.Draw(cell).text(
                    (8, 7),
                    f'{surrounding_name} / {mask_name}',
                    fill=(24, 24, 24) if surrounding_name == 'light' else (230, 230, 230),
                )
                sheet.paste(
                    cell,
                    (column * cell_width, label_height + actual_row * cell_height),
                )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--import-imagegen-source',
        type=Path,
        help='Normalize a transparent built-in ImageGen result first.',
    )
    parser.add_argument(
        '--contact-sheet',
        type=Path,
        help='Optionally generate a visual verification contact sheet.',
    )
    args = parser.parse_args()

    if args.import_imagegen_source is not None:
        import_imagegen_source(args.import_imagegen_source)
    generate_resources()
    validate_resources()
    if args.contact_sheet is not None:
        generate_contact_sheet(args.contact_sheet)
    print('Launcher icon resources generated and validated successfully.')


if __name__ == '__main__':
    main()
