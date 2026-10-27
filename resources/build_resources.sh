#!/usr/bin/env bash
# Builds Biba's branding resources (icons) from the 1024px source PNGs.
# Output: biba/resources/out/  (paths listed in biba_resources.txt)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"
src="$here/icon_1024.png"
crop="$here/icon_1024_crop.png"
py=/opt/homebrew/opt/python@3.13/libexec/bin/python3

rm -rf "$out" && mkdir -p "$out/mac" "$out/product_icon" "$out/branding"

# The app icon comes from the logo artwork (biba_logo.svg).
if [ -f "$here/biba_logo.svg" ]; then
	logo_png="$(mktemp -d)/logo.png"
	sips -s format png -z 2048 2048 "$here/biba_logo.svg" --out "$logo_png" >/dev/null
	"$py" -I "$here/make_icon_from_svg.py" "$logo_png" "$src" "$crop"
fi
[ -f "$src" ] || "$py" -I "$here/make_temp_icon.py" "$src" --crop "$crop"

# --- app.icns ---------------------------------------------------------------
iconset="$out/app.iconset"; mkdir -p "$iconset"
for s in 16 32 128 256 512; do
	in="$src"; [ "$s" -le 32 ] && in="$crop"
	sips -z $s $s "$in" --out "$iconset/icon_${s}x${s}.png" >/dev/null
	sips -z $((s * 2)) $((s * 2)) "$in" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$out/mac/app.icns"

# --- Assets.car (Dock/Finder icon on macOS 11+) -----------------------------
xc="$out/Assets.xcassets/AppIcon.appiconset"; mkdir -p "$xc"
images=""
for s in 16 32 128 256 512; do
	for scale in 1 2; do
		px=$((s * scale)); name="icon_${s}x${s}@${scale}x.png"
		in="$src"; [ "$s" -le 32 ] && in="$crop"
		sips -z $px $px "$in" --out "$xc/$name" >/dev/null
		images="$images{\"idiom\":\"mac\",\"size\":\"${s}x${s}\",\"scale\":\"${scale}x\",\"filename\":\"$name\"},"
	done
done
printf '{"images":[%s],"info":{"version":1,"author":"biba"}}\n' "${images%,}" > "$xc/Contents.json"
printf '{"info":{"version":1,"author":"biba"}}\n' > "$out/Assets.xcassets/Contents.json"
xcrun actool "$out/Assets.xcassets" --compile "$out/mac" --platform macosx \
	--minimum-deployment-target 12.0 --app-icon AppIcon \
	--output-partial-info-plist "$out/actool.plist" >/dev/null
rm -f "$out/mac/AppIcon.icns"   # actool also emits an .icns; we ship our own app.icns

# --- generated product icons (same list as Helium's generate_resources.txt) --
for s in 16 24 32 48 64 128 256; do
	sips -z $s $s "$crop" --out "$out/product_icon/${s}x${s}.png" >/dev/null
done
cp "$src" "$out/branding/raw.png"
sips -z 512 512 "$src" --out "$out/branding/file.png" >/dev/null

# --- small monochrome logo (menu bar / tab strip): the "b" silhouette -------
"$py" -I - "${logo_png:-}" "$out/branding/product_logo_22_mono.png" <<'EOF2'
import sys
from PIL import Image
src = Image.open(sys.argv[1]).convert("RGB")
# The letter is the saturated pink; the background is pale.
mask = src.point(lambda v: v).convert("RGB").split()[1].point(lambda g: 255 if g < 200 else 0)
mask = mask.crop(mask.getbbox())
side = max(mask.size)
sq = Image.new("L", (side, side), 0)
sq.paste(mask, ((side - mask.size[0]) // 2, (side - mask.size[1]) // 2))
glyph = Image.new("RGBA", (18, 18), (0, 0, 0, 255))
glyph.putalpha(sq.resize((18, 18), Image.LANCZOS))
out = Image.new("RGBA", (22, 22), (0, 0, 0, 0))
out.alpha_composite(glyph, (2, 2))
out.save(sys.argv[2])
EOF2

# --- favicon (the "b" alone, for the new tab / setup pages) ----------------
mkdir -p "$out/favicon"
[ -n "${logo_png:-}" ] && "$py" -I "$here/make_favicon.py" "$logo_png" "$out/favicon/fav"

echo "Biba resources built in $out"
