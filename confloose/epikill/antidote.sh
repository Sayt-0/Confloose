#!/bin/sh

base="${AFS_DIR:-$HOME}/.confloose"
lockdir="$base/epikill.lock"

# Recorded pids only (never pkill -f): first the prank loop groups (recorded
# by the daemon), then the daemon. Killing the loops ourselves is robust even
# if the daemon is stuck in a long sleep and has not run its own cleanup yet.
if [ -f "$lockdir/loop_pids" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        kill -- "-$p" 2>/dev/null
        kill "$p" 2>/dev/null
    done < "$lockdir/loop_pids"
fi
pid=$(cat "$lockdir/pid" 2>/dev/null)
if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
fi
rm -rf "$lockdir" "$base/bin/epikill"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "epikill"

# Restore what the chaos loops left behind live: screen rotation, gamma,
# keyboard layout. A literal newline for IFS, not $'\n': that is a bashism.
IFS='
'
for output in $(xrandr 2>/dev/null | sed -nE "s/(^\S+) connected.*$/\1/p"); do
    xrandr --output "$output" --gamma 1:1:1 --rotate normal 2>/dev/null
done
command -v setxkbmap >/dev/null 2>&1 && setxkbmap fr 2>/dev/null
pkill -x i3-nagbar 2>/dev/null
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
