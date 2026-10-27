#!/usr/bin/env bash
# Runs the dev build of Biba with the test profile, no keychain prompts.
# Quit politely so the session is saved (no "Restore pages?" next time).
if pgrep -x Biba >/dev/null; then
	osascript -e 'tell application id "com.weristvlad.biba" to quit' 2>/dev/null
	for _ in $(seq 40); do pgrep -x Biba >/dev/null || break; sleep 0.25; done
	pkill -x Biba; sleep 1
fi
/Volumes/BibaBuild/biba/helium-macos/build/src/out/Default/Biba.app/Contents/MacOS/Biba \
	--user-data-dir=/Volumes/BibaBuild/biba/profile-test --no-first-run --use-mock-keychain \
	"$@" > /Volumes/BibaBuild/biba/run.log 2>&1 &
disown
