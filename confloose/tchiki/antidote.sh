#!/bin/sh

base="${AFS_DIR:-$HOME}/.confloose"
lockdir="$base/tchiki.lock"

# Recorded pids only (never pkill -f); daemon first so it cannot respawn the player.
for pidfile in "$lockdir/pid" "$lockdir/player_pid"; do
    pid=$(cat "$pidfile" 2>/dev/null)
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
done
rm -rf "$lockdir" "$base/bin/tchiki"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "tchiki"
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
