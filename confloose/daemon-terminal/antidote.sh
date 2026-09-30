#!/bin/sh

base="${AFS_DIR:-$HOME}/.confloose"
lockdir="$base/daemon-terminal.lock"

pid=$(cat "$lockdir/pid" 2>/dev/null)
if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
fi
rm -rf "$lockdir" "$base/bin/daemon-terminal"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "daemon-terminal"
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
