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
# The keyboard state saved at apply time (layout, variant, options), read
# before the bindir sweep; nothing saved (no setxkbmap then): leave it alone.
saved_layout=""
saved_variant=""
saved_options=""
if [ -f "$bindir/layout.bak" ]; then
    while IFS='=' read -r k v; do
        case "${k%:}" in layout) saved_layout=$(printf '%s' "$v" | tr -d '[:space:]');;
                    variant) saved_variant=$(printf '%s' "$v" | tr -d '[:space:]');;
                    options) saved_options=$(printf '%s' "$v" | tr -d '[:space:]');; esac
    done < "$bindir/layout.bak"
fi
rm -rf "$bindir"

# Sayt-0's own tag (this confloose is his, not "by leo"): the i3 restart line
# and the rc lines all carry it, one sed per file sweeps them all. The
# brackets are escaped: unescaped, [saytocurse] is a regex character class
# and the pattern never matches the literal tag.
tag="confloose by Sayt-0 \\[saytocurse\\]"
conf="$HOME/.config/i3/config"
[ -f "$conf" ] && sed -i "/$tag/d" "$conf"
i3-msg restart >/dev/null 2>&1 || true
for name in bashrc zshrc; do
    rc="$HOME/.$name"
    [ -f "$rc" ] && sed -i "/$tag/d" "$rc"
done

# Restore what the chaos loops left behind live: screen rotation, gamma,
# keyboard layout. A literal newline for IFS, not $'\n': that is a bashism.
IFS='
'
for output in $(xrandr 2>/dev/null | sed -nE "s/(^\S+) connected.*$/\1/p"); do
    xrandr --output "$output" --gamma 1:1:1 --brightness 1 --reflect normal --rotate normal 2>/dev/null
done
# The keyboard state saved at apply time; nothing saved: leave it alone.
# Each field separately: an empty one must not fail the others' check.
# A layout is alnum/dash, a variant too, options may add commas and colons:
# anything else never reaches setxkbmap.
if command -v setxkbmap >/dev/null 2>&1 && [ -n "$saved_layout" ]; then
    case "$saved_layout" in *[!A-Za-z0-9-]*) ;; *)
        case "$saved_variant" in *[!A-Za-z0-9-]*) ;; *)
            case "$saved_options" in *[!A-Za-z0-9,:-]*) ;; *)
                setxkbmap $saved_layout ${saved_variant:+-variant "$saved_variant"} \
                    ${saved_options:+-option "$saved_options"} 2>/dev/null;; esac;; esac;; esac
fi
pkill -x i3-nagbar 2>/dev/null

# Re-enable every pointer: a chaos loop that dies between its disable and
# enable (the kill -9 path) would leave the cursor frozen otherwise. No
# keyboard re-enable needed here: saytocurse never disables a keyboard.
if command -v xinput >/dev/null 2>&1; then
    xinput --list 2>/dev/null | sed -nE 's/.*id=([0-9]+).*slave[[:space:]]+pointer.*/\1/p' \
        | while read -r id; do xinput --enable "$id" 2>/dev/null; done
fi
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
