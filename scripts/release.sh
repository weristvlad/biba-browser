#!/usr/bin/env bash
# Builds a Biba release for Apple Silicon, packages it as a DMG, signs the
# update for Sparkle, writes the appcast and publishes a GitHub release.
#
# Usage: scripts/release.sh <version> [--publish]
#   e.g. scripts/release.sh 0.1.0-beta.1 --publish
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
publish=${2:-}
H=${BIBA_HELIUM:-/Volumes/BibaBuild/biba/helium-macos}
src="$H/build/src"
out="$src/out/Release"
repo=weristvlad/biba-browser
arch=arm64
dist="$H/../dist/$version"
mkdir -p "$dist"

# Sparkle's command-line tools (generate_keys, sign_update), from the same
# Sparkle release Helium bundles.
sparkle="${SPARKLE_DIR:-$HOME/.cache/biba/sparkle}/bin"
if [ ! -x "$sparkle/sign_update" ]; then
  mkdir -p "$(dirname "$sparkle")"
  curl -fsSL https://github.com/sparkle-project/Sparkle/releases/download/2.7.1/Sparkle-2.7.1.tar.xz \
    | tar -xJ -C "$(dirname "$sparkle")"
fi
pubkey=$("$sparkle/generate_keys" -p 2>/dev/null || true)
if [ -z "$pubkey" ]; then
  "$sparkle/generate_keys" >/dev/null
  pubkey=$("$sparkle/generate_keys" -p)
fi

# --- build -------------------------------------------------------------------
mkdir -p "$out"
{
  cat "$H/flags.macos.gn"
  echo 'is_component_build=false'
  echo 'enable_precompiled_headers=false'
  echo 'target_cpu="arm64"'
  echo 'enable_sparkle=true'
  echo "sparkle_ed_key=\"$pubkey\""
  echo 'sparkle_automatic_checks=true'
  echo 'sparkle_check_interval=21600'
} > "$out/args.gn"
(cd "$H" && source ./dev.sh >/dev/null 2>&1; cd build/src && gn gen out/Release && autoninja -C out/Release chrome)

# --- package -----------------------------------------------------------------
app="$out/Biba.app"
codesign --force --deep --sign - "$app"   # ad-hoc: no Apple Developer ID yet
dmg="$dist/Biba-$version-$arch.dmg"
rm -f "$dmg"
hdiutil create -volname "Biba" -srcfolder "$app" -ov -format ULFO "$dmg" >/dev/null

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
    --notes "Beta build for Macs with Apple Silicon. Biba is not notarized yet: the first time, right-click Biba in Applications and choose Open."
fi
