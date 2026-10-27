#!/usr/bin/env bash
# Runs the dev build of Biba with the test profile, no keychain prompts.
# Quit politely (Apple "quit" event to this profile's Biba only) so the
# session is saved and there's no "Restore pages?" next time.
here=$(cd "$(dirname "$0")" && pwd)
pid=$(pgrep -f 'MacOS/Biba --user-data-dir=/Volumes/BibaBuild/biba/profile-test' | head -1)
if [ -n "$pid" ]; then
	"$here/quitpid" "$pid" >/dev/null
	for _ in $(seq 60); do kill -0 "$pid" 2>/dev/null || break; sleep 0.25; done
	kill "$pid" 2>/dev/null; sleep 1
fi
/Volumes/BibaBuild/biba/helium-macos/build/src/out/Default/Biba.app/Contents/MacOS/Biba \
	--user-data-dir=/Volumes/BibaBuild/biba/profile-test --no-first-run --use-mock-keychain \
	"$@" > /Volumes/BibaBuild/biba/run.log 2>&1 &
disown
