#!/usr/bin/env bash
# Launches Biba with the Spaces self-test and saves in-app window snapshots.
# Usage: shoot.sh <out_dir> [url ...]
# Needs biba/debug-spaces-selftest.patch. Captures via the app itself, so it
# works without macOS Screen Recording permission.
OUT=${1:?out dir}; shift
URLS=("$@"); [ ${#URLS[@]} -eq 0 ] && URLS=(https://example.com https://en.wikipedia.org/wiki/Web_browser https://github.com)
APP=/Volumes/BibaBuild/biba/helium-macos/build/src/out/Default/Biba.app
PROFILE=/Volumes/BibaBuild/biba/profile-test
LOG=/Volumes/BibaBuild/biba/selftest.log
mkdir -p "$OUT"
pkill -x Biba; sleep 2
"$APP/Contents/MacOS/Biba" --user-data-dir="$PROFILE" --no-first-run --use-mock-keychain \
	--window-size=1400,900 --biba-spaces-selftest="$OUT" "${URLS[@]}" > "$LOG" 2>&1 &
disown
end=$((SECONDS + 60))
until [ $SECONDS -ge $end ] || [ "$(grep -c '\] saved' "$LOG")" -ge 5 ]; do sleep 2; done
grep -E '\] (saved|snapshot failed|step)' "$LOG" | sed -E 's/^.*\[biba-selftest\] //'
