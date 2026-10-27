"""Biba DMG background: Helium's layout, its blue glow turned Biba pink.

Usage: make_dmg_background.py <helium dmg_background.png> <out.png>
"""
import sys
from PIL import Image

src = Image.open(sys.argv[1]).convert("RGBA")
h, s, v = src.convert("RGB").convert("HSV").split()
# Helium's glow sits around hue 225 deg; Biba's pink (#E46F78) is ~355 deg.
shift = round((355 - 225) / 360 * 255)
h = h.point(lambda x: (x + shift) % 256)
out = Image.merge("HSV", (h, s, v)).convert("RGB").convert("RGBA")
out.putalpha(src.getchannel("A"))
out.save(sys.argv[2])
