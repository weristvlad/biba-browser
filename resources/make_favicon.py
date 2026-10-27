"""Biba favicon: the pink "b" alone on transparency (no tile behind it).

Usage: make_favicon.py <logo.png> <out_prefix>   -> <prefix>16.png, 32.png, 128.png
"""
import sys
from PIL import Image

src = Image.open(sys.argv[1]).convert("RGB")
# The letter is the saturated pink; the ground is pale peach.
mask = src.split()[1].point(lambda g: 255 if g < 200 else 0)
mask = mask.crop(mask.getbbox())
side = max(mask.size)
sq = Image.new("L", (side, side), 0)
sq.paste(mask, ((side - mask.size[0]) // 2, (side - mask.size[1]) // 2))
for size in (16, 32, 128):
    pad = max(1, size // 16)
    inner = size - 2 * pad
    glyph = Image.new("RGBA", (inner, inner), (0xE4, 0x6F, 0x78, 255))
    glyph.putalpha(sq.resize((inner, inner), Image.LANCZOS))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glyph, (pad, pad))
    out.save(f"{sys.argv[2]}{size}.png")
