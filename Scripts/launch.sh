#!/bin/bash
set -euo pipefail
app="$(pwd -P)/${1:-dist/KeyHop.app}"
# Quit only a previous build from this project, so make run picks up changes.
while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    kill -TERM "$pid"
    for ((i=0; i<50; i++)); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "Previous KeyHop process did not quit." >&2
        exit 1
    fi
done < <(pgrep -x KeyHop | while read -r pid; do
    [[ "$(ps -p "$pid" -o comm=)" == "$app/Contents/MacOS/KeyHop" ]] && echo "$pid"
done)
open "$app"
