#!/usr/bin/env bash
# Runs the dev build of Biba with the test profile, no keychain prompts.
pkill -x Biba; sleep 1
/Volumes/BibaBuild/biba/helium-macos/build/src/out/Default/Biba.app/Contents/MacOS/Biba \
	--user-data-dir=/Volumes/BibaBuild/biba/profile-test --no-first-run --use-mock-keychain \
	"$@" > /Volumes/BibaBuild/biba/run.log 2>&1 &
disown
