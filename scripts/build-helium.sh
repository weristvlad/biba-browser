#!/usr/bin/env bash
# Starts the Helium build fully detached from the calling terminal/Claude session.
# Usage: build-helium.sh [jobs] [nice]   e.g. build-helium.sh 6 15   or   build-helium.sh 10 0
JOBS=${1:-6}; NICE=${2:-15}
SRC=${BIBA_HELIUM:-/Volumes/BibaBuild/biba/helium-macos}
LOG=${BIBA_BUILD_LOG:-$(dirname "$SRC")/build.log}
pkill -f autoninja; pkill -f 'cipd/siso'; sleep 3
[ -f "$LOG" ] && mv "$LOG" "${LOG%.log}.$(date +%H%M%S).log"
echo "$JOBS" > /Volumes/BibaBuild/biba/build.jobs
cd "$SRC" || exit 1
PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH" \
/opt/homebrew/opt/python@3.13/libexec/bin/python3 -c '
import os, sys
os.setsid()                      # new session: survives the parent terminal / Claude restart
os.execvp("nice", ["nice", "-n", sys.argv[1], "zsh", "-c",
  "source ./dev.sh >/dev/null 2>&1; cd build/src; helium_build -k 0 -j " + sys.argv[2] + "; echo \"exit $?\""])
' "$NICE" "$JOBS" > "$LOG" 2>&1 < /dev/null &
disown
echo "started: jobs=$JOBS nice=$NICE"
