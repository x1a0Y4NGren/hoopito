"""Regression checks for the three-color mascot export pipeline."""

import importlib.util
import unittest
from pathlib import Path

from PIL import Image


SPEC = importlib.util.spec_from_file_location(
    'launcher_icons', Path(__file__).resolve().parents[1] / 'generate_launcher_icons.py',
)
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)


class MascotExportTest(unittest.TestCase):
    def test_color_normalization_keeps_black_face_and_partial_alpha(self):
        source = Image.new('RGBA', (4, 1))
        source.putdata([
            (17, 18, 19, 255),
            (253, 88, 30, 180),
            (242, 242, 238, 255),
            (255, 90, 31, 0),
        ])
        output = icons._canonicalize_colors(source)
        self.assertEqual(output.getpixel((0, 0)), (*icons.BACKGROUND, 255))
        self.assertEqual(output.getpixel((1, 0)), (*icons.ARENA_ORANGE, 180))
        self.assertEqual(output.getpixel((2, 0)), (*icons.WARM_WHITE, 255))
        self.assertEqual(output.getpixel((3, 0))[3], 0)

    def test_monochrome_keeps_pupil_and_smile_as_negative_spaces(self):
        source = Image.new('RGBA', (5, 1))
        source.putdata([
            (*icons.ARENA_ORANGE, 255),
            (*icons.WARM_WHITE, 255),
            (*icons.BACKGROUND, 255),
            (*icons.ARENA_ORANGE, 128),
            (0, 0, 0, 0),
        ])
        output = icons._monochrome_foreground(source)
        self.assertEqual(list(output.getchannel('A').get_flattened_data()), [255, 255, 0, 128, 0])
        self.assertEqual({pixel[:3] for pixel in output.get_flattened_data()}, {icons.WARM_WHITE})


if __name__ == '__main__':
    unittest.main()
