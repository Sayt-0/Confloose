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
# The keyboard state saved at apply time (layout, variant, options), read
# before the bindir sweep; nothing saved (no setxkbmap then): leave it alone.
saved_layout=""
saved_variant=""
saved_options=""
if [ -f "$base/bin/epikill/layout.bak" ]; then
    while IFS='=' read -r k v; do
        case "${k%:}" in layout) saved_layout=$(printf '%s' "$v" | tr -d '[:space:]');;
                    variant) saved_variant=$(printf '%s' "$v" | tr -d '[:space:]');;
                    options) saved_options=$(printf '%s' "$v" | tr -d '[:space:]');; esac
    done < "$base/bin/epikill/layout.bak"
fi
rm -rf "$lockdir" "$base/bin/epikill"
curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "epikill"

# Restore what the chaos loops left behind live: screen rotation, gamma,
# keyboard layout. A literal newline for IFS, not $'\n': that is a bashism.
IFS='
'
for output in $(xrandr 2>/dev/null | sed -nE "s/(^\S+) connected.*$/\1/p"); do
    xrandr --output "$output" --gamma 1:1:1 --brightness 1 --rotate normal 2>/dev/null
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

# Re-enable every pointer and keyboard: a chaos loop that dies between its
# disable and enable (the kill -9 path) would leave them dead otherwise, and
# the new EpiWTF cadence makes that window far more likely.
if command -v xinput >/dev/null 2>&1; then
    xinput --list 2>/dev/null | sed -nE 's/.*id=([0-9]+).*slave[[:space:]]+(pointer|keyboard).*/\1/p' \
        | while read -r id; do xinput --enable "$id" 2>/dev/null; done
fi
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
