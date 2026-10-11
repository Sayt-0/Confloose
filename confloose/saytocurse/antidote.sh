#!/bin/sh

base="${AFS_DIR:-$HOME}/.confloose"
lockdir="$base/saytocurse.lock"
bindir="$base/bin/saytocurse"

# Recorded pids only (never pkill -f): first the prank loop groups (recorded
# by the daemon), then the daemon. Killing the loops ourselves is robust even
# if the daemon is stuck in a long sleep and has not run its own cleanup yet.
kill_loops() {
    [ -f "$1" ] || return 0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        kill -- "-$p" 2>/dev/null      # whole group (setsid case)
        kill "$p" 2>/dev/null          # plain fallback (timeout wrappers)
    done < "$1"
}
kill_loops "$lockdir/loop_pids"
pid=$(cat "$lockdir/pid" 2>/dev/null)
if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
fi
# Second pass: the daemon may have recorded a spawn between the first read and
# its death (the kill -9 path), and those loops would outlive the antidote.
kill_loops "$lockdir/loop_pids"
rm -rf "$lockdir"

# The wallpaper was replaced by the daemon; put back the one saved at apply
# time. No feh-based wallpaper on this machine: try nitrogen's own config,
# and fall back to a neutral black background (the daemon only ever touched
# the live property, never any config file).
if [ -f "$bindir/fehbg.bak" ]; then
    sh "$bindir/fehbg.bak" >/dev/null 2>&1
elif [ -f "$HOME/.config/nitrogen/bg-saved.cfg" ] && command -v nitrogen >/dev/null 2>&1; then
    nitrogen --restore >/dev/null 2>&1
else
    black="$bindir/black.png"
    if command -v python3 >/dev/null 2>&1 && ! [ -f "$black" ]; then
        printf 'from PIL import Image; Image.new("RGB", (16, 16)).save("%s")' "$black" \
            | python3 >/dev/null 2>&1 || :
    fi
    [ -f "$black" ] && feh --bg-scale "$black" >/dev/null 2>&1
fi
rm -rf "$bindir"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "saytocurse"

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
