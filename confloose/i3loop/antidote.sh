#!/bin/sh

base="${AFS_DIR:-$HOME}/.confloose"
lockdir="$base/i3loop.lock"

# Kill the recorded pid rather than `pkill -f confloose-i3loop`: -f matches the
# whole command line, so it also kills any unrelated process that merely mentions
# the name (an editor with the file open, a grep, the calling script).
pid=$(cat "$lockdir/pid" 2>/dev/null)
if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
fi
rm -rf "$lockdir" "$base/bin/i3loop"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "i3loop"
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
