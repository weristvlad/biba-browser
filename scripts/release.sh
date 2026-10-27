#!/usr/bin/env bash
# Builds a Biba release for Apple Silicon, packages it as a DMG, signs the
# update for Sparkle, writes the appcast and publishes a GitHub release.
#
# Usage: scripts/release.sh <version> [--build-only|--no-build] [--publish]
#   e.g. scripts/release.sh 0.1.0-beta.1 --publish
#   --build-only  only build out/Release (the hours-long part), then stop
#   --no-build    skip the build, sign/package/publish what's in out/Release
#
# Updates: Biba asks
#   https://github.com/weristvlad/biba-browser/releases/latest/download/appcast-arm64.xml
# (see patches/biba/updates-github.patch), so every release must carry that
# file and must not be marked as a pre-release ("latest" skips those).
#
# Needs: the Helium tree with Biba's patches applied (BIBA_HELIUM), gh CLI
# logged in, and the Sparkle EdDSA key in the login keychain (created on the
# first run by Sparkle's generate_keys; back it up, losing it breaks updates).
set -euo pipefail

version=${1:?version, e.g. 0.1.0-beta.1}
shift
publish= stage=all
for a in "$@"; do
  case $a in
    --publish) publish=--publish ;;
    --build-only) stage=build ;;
    --no-build) stage=package ;;
  esac
done
H=${BIBA_HELIUM:-/Volumes/BibaBuild/biba/helium-macos}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
src="$H/build/src"
out="$src/out/Release"
repo=weristvlad/biba-browser
arch=arm64
dist="$H/../dist/$version"
mkdir -p "$dist"

# Sparkle's command-line tools (generate_keys, sign_update), from the same
# Sparkle release Helium bundles (downloads.ini).
sparkle="${SPARKLE_DIR:-$HOME/.cache/biba/sparkle}/bin"
if [ ! -x "$sparkle/sign_update" ]; then
  mkdir -p "$(dirname "$sparkle")"
  curl -fsSL https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz \
    | tar -xJ -C "$(dirname "$sparkle")"
fi
pubkey=$("$sparkle/generate_keys" -p 2>/dev/null || true)
if [ -z "$pubkey" ]; then
  "$sparkle/generate_keys" >/dev/null
  pubkey=$("$sparkle/generate_keys" -p)
fi

# --- build -------------------------------------------------------------------
if [ "$stage" != package ]; then
mkdir -p "$out"
{
  # Same as Helium's own release args (dev.sh write_gn_args "release").
  cat "$H/helium-chromium/flags.gn" "$H/flags.macos.gn"
  echo 'chrome_pgo_phase=2'
  echo 'is_component_build=false'
  echo 'enable_precompiled_headers=false'
  echo 'target_cpu="arm64"'
  echo 'enable_sparkle=true'
  echo "sparkle_ed_key=\"$pubkey\""
  echo 'sparkle_automatic_checks=true'
  echo 'sparkle_check_interval=21600'
} > "$out/args.gn"
# Helium's dev.sh is zsh and not `set -u` clean; its helium_build runs
# autoninja (siso) on $_out_dir.
(cd "$src" && buildtools/mac/gn gen out/Release)
(cd "$H" && PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH" \
  zsh -c 'source ./dev.sh >/dev/null 2>&1; _out_dir="$_src_dir/out/Release"; helium_build -k 0')
fi
[ "$stage" = build ] && { echo "Built $out"; exit 0; }

# --- sign, notarize, package --------------------------------------------------
# Developer ID signing + notarization, via Chromium's own signing tool (it
# knows the entitlements each helper app needs). The notary credentials are a
# keychain profile created once with:
#   xcrun notarytool store-credentials biba-notary --apple-id … --team-id 2U825JJT77
identity=${BIBA_SIGN_IDENTITY:-"Developer ID Application: Vladislav Sergeev (2U825JJT77)"}
notary_profile=${BIBA_NOTARY_PROFILE:-biba-notary}
# The signing scripts ("Biba Packaging") are their own target, like in
# Helium's build.sh.
(cd "$H" && PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH" \
  zsh -c 'source ./dev.sh >/dev/null 2>&1; _out_dir="$_src_dir/out/Release"; helium_build chrome/installer/mac')
rm -rf "$out/signed"
python3 "$out/Biba Packaging/sign_chrome.py" \
  --input "$out" --output "$out/signed" \
  --identity "$identity" \
  --disable-packaging --notarize \
  --notary-arg=--keychain-profile="$notary_profile"
app=$(find "$out/signed" -maxdepth 3 -name 'Biba.app' -type d | head -1)
[ -d "$app" ] || { echo "signed Biba.app not found" >&2; exit 1; }

dmg="$dist/Biba-$version-$arch.dmg"
rm -f "$dmg"
# Same DMG layout as Helium's sign_and_package_app.sh (drag to Applications).
(cd "$src" && chrome/installer/mac/pkg-dmg \
  --sourcefile --source "$app" \
  --target "$dmg" \
  --volname Biba --format ULMO \
  --icon "$app/Contents/Resources/app.icns" \
  --symlink /Applications:/Applications \
  --mkdir .background \
  --copy "$repo_dir/resources/dmg_background.png:/.background/dmg_background.png" \
  --copy "$H/resources/dmg_dsstore:/.DS_Store")
codesign --sign "$identity" --identifier com.weristvlad.biba --timestamp --force "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$dmg"

# --- sign the update, write the appcast --------------------------------------
sig=$("$sparkle/sign_update" "$dmg")   # sparkle:edSignature="…" length="…"
short=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
url="https://github.com/$repo/releases/download/v$version/$(basename "$dmg")"
cat > "$dist/appcast-$arch.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Biba</title>
    <item>
      <title>Biba $version</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$short</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
      <link>https://github.com/$repo/releases/tag/v$version</link>
      <enclosure url="$url" $sig type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF
echo "Built $dmg"

# --- publish -----------------------------------------------------------------
if [ "$publish" = "--publish" ]; then
  gh release create "v$version" "$dmg" "$dist/appcast-$arch.xml" \
    --repo "$repo" --title "Biba $version (beta)" \
    --notes "Beta build for Macs with Apple Silicon (macOS 12+). Signed and notarized. Biba updates itself from here."
fi
