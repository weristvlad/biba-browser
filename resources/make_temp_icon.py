"""Generates Biba's temporary app icon (gradient squircle + "B") at 1024px.

Usage: python3 make_temp_icon.py <out.png> [--crop <out_crop.png>]
"""
import argparse
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
TOP = (124, 58, 237)      # violet
BOTTOM = (236, 72, 153)   # pink
FONT_CANDIDATES = [
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        row = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        for x in range(size):
            px[x, y] = row
    return img


def load_font(px):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, px)
        except OSError:
            continue
    return ImageFont.load_default()


def make(inset, radius_ratio):
    """inset: transparent margin (macOS icons sit inside ~10% padding)."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    body = SIZE - 2 * inset
    mask = Image.new("L", (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, body - 1, body - 1), radius=int(body * radius_ratio), fill=255)

    tile = gradient(body).convert("RGBA")
    draw = ImageDraw.Draw(tile)
    font = load_font(int(body * 0.62))
    box = draw.textbbox((0, 0), "B", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    pos = ((body - w) / 2 - box[0], (body - h) / 2 - box[1])
    # soft glow under the letter
    glow = Image.new("RGBA", (body, body), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text(pos, "B", font=font, fill=(255, 255, 255, 140))
    tile.alpha_composite(glow.filter(ImageFilter.GaussianBlur(body * 0.03)))
    draw.text(pos, "B", font=font, fill=(255, 255, 255, 255))

    canvas.paste(tile, (inset, inset), mask)
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--crop", help="full-bleed variant for small sizes")
    args = ap.parse_args()
    make(inset=100, radius_ratio=0.225).save(args.out)
    if args.crop:
        make(inset=0, radius_ratio=0.225).save(args.crop)


if __name__ == "__main__":
    main()
