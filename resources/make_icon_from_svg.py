"""Builds Biba's macOS app icon from the logo artwork.

Usage: make_icon_from_svg.py <logo.png 2048px> <icon_1024.png> <icon_1024_crop.png>

icon_1024.png follows Apple's icon grid (824px squircle-ish rounded rect on a
1024 canvas, soft drop shadow); icon_1024_crop.png is the full-bleed artwork
for tiny sizes (16/32) where the margin would waste pixels.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

src = Image.open(sys.argv[1]).convert("RGBA")
S = 1024
BODY = 824
RADIUS = 185  # Apple's macOS icon template corner radius at 824px

art = src.resize((BODY, BODY), Image.LANCZOS)
mask = Image.new("L", (BODY * 4, BODY * 4), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, BODY * 4 - 1, BODY * 4 - 1), radius=RADIUS * 4, fill=255)
mask = mask.resize((BODY, BODY), Image.LANCZOS)
body = Image.new("RGBA", (BODY, BODY), (0, 0, 0, 0))
body.paste(art, (0, 0), mask)

off = (S - BODY) // 2
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sm = Image.new("L", (S, S), 0)
sm.paste(mask, (off, off + 10))
shadow.putalpha(sm.point(lambda a: int(a * 0.30)))
shadow = shadow.filter(ImageFilter.GaussianBlur(14))
icon = Image.alpha_composite(icon, shadow)
icon.alpha_composite(body, (off, off))
icon.save(sys.argv[2])

crop = src.resize((S, S), Image.LANCZOS)
cm = Image.new("L", (S * 4, S * 4), 0)
ImageDraw.Draw(cm).rounded_rectangle((0, 0, S * 4 - 1, S * 4 - 1),
                                     radius=int(S * 0.225) * 4, fill=255)
cm = cm.resize((S, S), Image.LANCZOS)
out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
out.paste(crop, (0, 0), cm)
out.save(sys.argv[3])
