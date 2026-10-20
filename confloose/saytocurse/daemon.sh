#!/usr/bin/env bash
# saytocurse daemon - Sayt-0's personal edition of the epikill chaos: Louis
# everywhere (wallpaper, popups, quote typewriter), nags quoting github.com/
# Sayt-0 and sayto.dev, then the full chaos once the target goes idle and
# comes back. Same rules as the rest of the repo: one daemon per machine,
# every loop killed by the antidote, nothing destructive. Needs bash
# ($RANDOM); env bash makes it work whatever /bin/sh points to.
#
# Phase 1 (arm): the wallpaper becomes Louis, one nag and one face while the
# target is around.
# Phase 2 (trigger): wait for the target to be idle ARM_MIN seconds, then
# for them to come back. Needs xprintidle; without it, fall back to a plain
# delay so the confloose still does something.
# Phase 3 (chaos): spawn a random prank loop every few seconds (screen
# rotations, brightness, gamma and mirror flashes, clipboard hijacks, nag
# spam, Louis faces, quote typewriter, Rick rolls, workspace view jumps,
# mouse blips) up to MAX_GROUPS at once, at the original EpiWTF cadence.
# No keyboard prank: the target must stay able to type the antidote.

dir="${AFS_DIR:-$HOME}/.confloose/bin/saytocurse"
img_louis="$dir/louis.jpg"
quotes="$dir/quotes.txt"
# Temp dir shared by the daemon and its --loop children (the colourized faces).
# Assigned before the --loop dispatch: a loop child needs it for its temp
# images, and never competes with the daemon for the lock (mkdir happens in
# daemon mode only).
lockdir="${AFS_DIR:-$HOME}/.confloose/saytocurse.lock"

ARM_MIN=10          # seconds of idleness that arm phase 2
PRE_CHAOS_MIN=25    # seconds after the target comes back before the chaos
PRE_CHAOS_MAX=35    # (the original EpiWTF floods by then)
CHAOS_DELAY=30     # seconds to wait when xprintidle is unavailable
WAIT_MIN=1; WAIT_MAX=3      # seconds between two spawns: the original floods
MAX_GROUPS=14      # every prank type runs at once, like the original

has() { command -v "$1" >/dev/null 2>&1; }

# Screen size for the window positions, like the tchiki daemon does.
SCR_W=1920; SCR_H=1080
if has xrandr; then
    res=$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}')
    case "$res" in [0-9]*x[0-9]*) SCR_W=${res%x*}; SCR_H=${res#*x};; esac
fi
case "$SCR_W" in ''|*[!0-9]*) SCR_W=1920;; esac
case "$SCR_H" in ''|*[!0-9]*) SCR_H=1080;; esac

# The connected outputs, one per line (the loops take the first).
outputs() { xrandr --current 2>/dev/null | sed -nE 's/(^\S+) connected.*$/\1/p'; }
first_output() { outputs | head -n 1; }

# Session-only floating rule (matches only our own title prefix), so our
# windows never barge into the tiling layout. No antidote needed.
float_rule() {
    has i3-msg || return 0
    i3-msg 'for_window [title="^confloose-saytocurse"] floating enable, border none' >/dev/null 2>&1
}

screen_rotate() {
    has xrandr || return 0
    while true; do
        out=$(first_output); [ -n "$out" ] || return 0
        for rot in left inverted right normal; do
            xrandr --output "$out" --rotate "$rot" >/dev/null 2>&1
            sleep 32
        done
        sleep 49
    done
}

# Blackout flashes like the original brightness loop, but restored after each
# flash (the original left the screen at 100: nothing was ever readable again).
brightness_flash() {
    has xrandr || return 0
    while true; do
        out=$(first_output); [ -n "$out" ] || return 0
        for i in 1 2 3; do
            xrandr --output "$out" --brightness 0 >/dev/null 2>&1
            sleep 4
        done
        xrandr --output "$out" --brightness 1 >/dev/null 2>&1
        sleep 10
    done
}

gamma_flash() {
    has xrandr || return 0
    while true; do
        out=$(first_output); [ -n "$out" ] || return 0
        r=$(awk -v min=0.2 -v max=3 'BEGIN{srand(); print min+rand()*(max-min)}')
        g=$(awk -v min=0.2 -v max=3 'BEGIN{srand(); print min+rand()*(max-min)}')
        b=$(awk -v min=0.2 -v max=3 'BEGIN{srand(); print min+rand()*(max-min)}')
        i=0
        while [ "$i" -lt 100 ]; do
            xrandr --output "$out" --gamma "$r:$g:$b" >/dev/null 2>&1
            sleep 0.1
            i=$((i + 1))
        done
        xrandr --output "$out" --gamma 1:1:1 >/dev/null 2>&1
        sleep 16
    done
}

# No keyboard layout hop and no keyboard disable here, unlike epikill: the
# target has to stay able to type the antidote command.

# Sayt-0's clipboard hijack: a random Louis quote lands in the selection
# clipboard every so often, so whatever the target pastes turns into Louis
# propaganda. No keyboard layout change: the target must stay able to type
# the antidote.
clipboard_hijack() {
    has xclip || return 0
    [ -s "$quotes" ] || return 0
    mapfile -t all < <(grep -v '^[[:space:]]*$' "$quotes")
    [ "${#all[@]}" -gt 0 ] || return 0
    while true; do
        q=${all[$((RANDOM % ${#all[@]}))]}
        printf '%s' "Louis was here. sayto.dev - $q" | xclip -selection clipboard 2>/dev/null
        sleep $((RANDOM % 25 + 15))
    done
}

# Horizontal mirror flashes: the screen flips left/right for a moment then
# comes back, restored by the antidote (and each flash) anyway.
mirror_sides() {
    has xrandr || return 0
    while true; do
        out=$(first_output); [ -n "$out" ] || return 0
        xrandr --output "$out" --reflect x >/dev/null 2>&1
        sleep $((RANDOM % 10 + 5))
        xrandr --output "$out" --reflect normal >/dev/null 2>&1
        sleep $((RANDOM % 35 + 15))
    done
}

# Sayt-0's own nag copy: waves of i3 nags quoting his GitHub and his domain.
# Rotation over the lines below so no two waves look the same.
NAGS=(
"A wild Sayt-0 appeared. Your session is now his. sayto.dev|true"
"This session is now the property of github.com/Sayt-0|true"
"Want your session back? Too bad. Try confloose.sayto.dev|true"
"sayto.dev - one does not simply un-curse this fleet|true"
"Louis was here. sayto.dev|true"
"curl confloose.sayto.dev | bash and you too can confloose someone|true"
)
nag_spam() {
    has i3-nagbar || return 0
    wave=0
    while true; do
        line=${NAGS[$((RANDOM % ${#NAGS[@]}))]}
        msg=${line%%|*}
        btn=${line#*|}
        pids=""
        i=0
        while [ "$i" -lt 8 ]; do
            i3-nagbar -t warning -m "$msg" -B "Yes, exit i3" "$btn" >/dev/null 2>&1 &
            pids="$pids $!"
            i=$((i + 1))
        done
        wave=$((wave + 1))
        sleep 42
        for p in $pids; do kill "$p" 2>/dev/null; done
    done
}

# Recoloured, resized copy of Louis via ImageMagick, like the tchiki daemon;
# echoes the path to display (the recoloured file, or the original).
colorize() {
    im=$(command -v magick 2>/dev/null || command -v convert 2>/dev/null)
    if [ -z "$im" ]; then printf '%s' "$1"; return; fi
    out="$3"
    case $((RANDOM % 6)) in
        0) "$im" "$1" -resize "$2" "$out" 2>/dev/null;;
        1) "$im" "$1" -resize "$2" -negate "$out" 2>/dev/null;;
        2) "$im" "$1" -resize "$2" -colorspace Gray "$out" 2>/dev/null;;
        3) "$im" "$1" -resize "$2" -modulate 100,200,$((RANDOM % 200)) "$out" 2>/dev/null;;
        4) "$im" "$1" -resize "$2" -solarize 50% "$out" 2>/dev/null;;
        5) c1=$(printf '#%02X%02X%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
           c2=$(printf '#%02X%02X%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
           "$im" "$1" -resize "$2" +level-colors "$c1,$c2" "$out" 2>/dev/null;;
    esac
    if [ -s "$out" ]; then printf '%s' "$out"; else printf '%s' "$1"; fi
}

face_pop() {
    has feh || return 0
    while true; do
        pct=$((RANDOM % 26 + 10))                 # 10%..35% of the screen width
        w=$((SCR_W * pct / 100)); [ "$w" -lt 150 ] && w=150
        h=$((w * 3 / 2))
        maxh=$((SCR_H - 20)); [ "$h" -gt "$maxh" ] && { h=$maxh; w=$((h * 2 / 3)); }
        ax=$((SCR_W - w)); [ "$ax" -lt 1 ] && ax=1
        ay=$((SCR_H - h)); [ "$ay" -lt 1 ] && ay=1
        x=$((RANDOM % ax)); y=$((RANDOM % ay))
        dur=$((RANDOM % 5 + 4))

        id="$$-$RANDOM"
        shown=$(colorize "$img_louis" "${w}x${h}" "$lockdir/face-$id.jpg")

        # Self-closing window: no cleanup needed beyond the temp image, which
        # the reaper removes once the window is gone (and the antidote sweeps
        # the lockdir anyway).
        timeout "${dur}s" feh --title "confloose-saytocurse-$id" --borderless \
            --geometry "${w}x${h}+${x}+${y}" --scale-down --auto-zoom \
            --hide-pointer --no-menus --image-bg black "$shown" >/dev/null 2>&1 &
        fpid=$!
        ( while kill -0 "$fpid" 2>/dev/null; do sleep 1; done
          rm -f "$lockdir/face-$id.jpg" ) >/dev/null 2>&1 &
        sleep 4
    done
}

# Louis as wallpaper, re-asserted: even if the target finds the display
# settings, the face comes back. Restored from the apply-time backup by the
# antidote.
wallpaper_patrol() {
    has feh || return 0
    while true; do
        feh --bg-scale "$img_louis" >/dev/null 2>&1
        sleep $((RANDOM % 30 + 45))
    done
}

rick() {
    has alacritty || return 0
    cur=""
    while true; do
        # One Rick window at a time: the previous terminal dies with the loop's
        # process group, never lingers after the antidote.
        [ -n "$cur" ] && kill "$cur" 2>/dev/null
        alacritty -t confloose-saytocurse-rick -e sh -c 'curl -sL ascii.live/rick' >/dev/null 2>&1 &
        cur=$!
        sleep 6
    done
}

# Our own quote typewriter: a random line from quotes.txt (shipped with the
# confloose, no external service) types itself out in a terminal, holds a
# moment, then closes. One window at a time, killed like every other loop.
saytquote() {
    has alacritty || return 0
    [ -s "$quotes" ] || return 0
    mapfile -t all < <(grep -v '^[[:space:]]*$' "$quotes")
    [ "${#all[@]}" -gt 0 ] || return 0
    cur=""
    while true; do
        [ -n "$cur" ] && kill "$cur" 2>/dev/null
        q=${all[$((RANDOM % ${#all[@]}))]}
        QUOTE="$q" alacritty -t confloose-saytocurse-quote -e bash -c '
            printf "\033[2J\033[H"
            printf "\033[1;35m  SAYTQUOTE \033[0m\n\n  "
            i=1
            while [ "$i" -le "${#QUOTE}" ]; do
                printf "%s" "${QUOTE:i-1:1}"
                sleep 0.04
                i=$((i + 1))
            done
            printf "\n\n\033[3m  sayto.dev\033[0m\n"
            sleep 8
        ' >/dev/null 2>&1 &
        cur=$!
        sleep $((RANDOM % 40 + 40))
    done
}

workspace_shuffle() {
    has i3-msg || return 0
    while true; do
        # View switch only: containers stay put, the target gets them back with
        # their own workspace keys. `move container` would scatter their windows
        # with no way for the antidote to put them back.
        i3-msg "workspace number $((RANDOM % 10 + 1))" >/dev/null 2>&1
        sleep $((RANDOM % 30 + 25))
    done
}

input_blip() {
    has xinput || return 0
    while true; do
        ids=$(xinput --list 2>/dev/null | grep -i mouse | cut -d= -f2 | cut -d[ -f1)
        if [ -z "$ids" ]; then sleep 30; continue; fi
        for id in $ids; do xinput disable "$id" >/dev/null 2>&1; done
        sleep 15
        for id in $ids; do xinput enable "$id" >/dev/null 2>&1; done
        sleep 23
    done
}

CHAOS=(screen_rotate brightness_flash gamma_flash mirror_sides clipboard_hijack
       nag_spam face_pop wallpaper_patrol rick saytquote workspace_shuffle
       input_blip)

# --loop mode: re-exec of this very file (see spawn), running one prank until
# its process group is killed. Runs before the lock so a loop child never
# competes with the daemon for it.
if [ "${1:-}" = "--loop" ]; then
    export DISPLAY="${DISPLAY:-:0}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    "$2"
    exit 0
fi

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# One daemon per machine (the rc file starts us from every shell); mkdir is atomic.
mkdir -p "$(dirname "$lockdir")"
mkdir "$lockdir" 2>/dev/null || exit 0
echo $$ > "$lockdir/pid"
loops="$lockdir/loop_pids"
: > "$loops"

# Ignore the terminal's HUP. On stop, kill every prank group we spawned: the
# windows, terminals and nags inside die with their group. INT/TERM must exit
# explicitly or the loop would resume after the handler.
trap '' HUP
cleanup() {
    if [ -f "$loops" ]; then
        while read -r p; do
            [ -n "$p" ] || continue
            kill -- "-$p" 2>/dev/null      # whole group (setsid case)
            kill "$p" 2>/dev/null          # plain fallback
            pkill -P "$p" 2>/dev/null      # and its direct children
        done < "$loops"
    fi
    rm -rf "$lockdir"
}
trap 'cleanup' EXIT
trap 'cleanup; exit 0' INT TERM

xprintidle_bin=""
if has xprintidle; then
    xprintidle_bin=$(command -v xprintidle)
else
    for f in /nix/store/*xprintidle*/bin/xprintidle; do
        [ -x "$f" ] && xprintidle_bin="$f" && break
    done
fi

# Phase 1: the target is still around. Louis takes the wallpaper, one nag
# introduces him, one face pops, and his browser opens sayto.dev and the
# GitHub profile once. Everything self-closes except the wallpaper and the
# tabs (just tabs, the target closes them), restored/untouched by the antidote.
# Bare domains on purpose: the browsers complete them, and the repo bans
# hard-coded URLs outside CONFLOOSE_BASE.
promo_tabs() {
    local urls=(sayto.dev github.com/Sayt-0)
    if has firefox; then
        firefox "${urls[@]}" >/dev/null 2>&1 &
    elif has chromium; then
        chromium "${urls[@]}" >/dev/null 2>&1 &
    elif has xdg-open; then
        for u in "${urls[@]}"; do xdg-open "$u" >/dev/null 2>&1; done
    fi
}

arm() {
    if has feh; then
        feh --bg-scale "$img_louis" >/dev/null 2>&1
    fi
    if has i3-nagbar; then
        timeout 300s i3-nagbar -t error \
            -m "This session is now the property of github.com/Sayt-0" >/dev/null 2>&1 &
    fi
    promo_tabs
    sleep 2
    if has feh; then
        pct=$((RANDOM % 26 + 10))
        w=$((SCR_W * pct / 100)); h=$((w * 3 / 2))
        maxh=$((SCR_H - 20)); [ "$h" -gt "$maxh" ] && h=$maxh
        ax=$((SCR_W - w)); [ "$ax" -lt 1 ] && ax=1
        ay=$((SCR_H - h)); [ "$ay" -lt 1 ] && ay=1
        shown=$(colorize "$img_louis" "${w}x${h}" "$lockdir/face-arm.jpg")
        timeout 30s feh --title "confloose-saytocurse-arm" --borderless \
            --geometry "${w}x${h}+$((RANDOM % ax))+$((RANDOM % ay))" \
            --scale-down --auto-zoom --hide-pointer --image-bg black \
            "$shown" >/dev/null 2>&1 &
    fi
}

# Drop dead pids from the tracking file and echo how many loops are alive.
live_groups() {
    [ -f "$loops" ] || { echo 0; return; }
    tmp="$loops.tmp"; : > "$tmp"; c=0
    while read -r p; do
        [ -n "$p" ] || continue
        if kill -0 "$p" 2>/dev/null; then echo "$p" >> "$tmp"; c=$((c + 1)); fi
    done < "$loops"
    mv -f "$tmp" "$loops" 2>/dev/null
    echo "$c"
}

# One prank per group: its own session, so one kill sweeps the whole tree
# (the alacritty Rick windows, the nags...). $! is the group leader.
spawn() {
    fn=${CHAOS[$((RANDOM % ${#CHAOS[@]}))]}
    if has setsid; then
        setsid "$0" --loop "$fn" >/dev/null 2>&1 &
    else
        "$fn" >/dev/null 2>&1 &
    fi
    echo $! >> "$loops"
}

float_rule
arm

# Phase 2: idle ARM_MIN seconds, then back. An unreadable idle (tool gone
# wild) counts as the trigger rather than the end of the prank. The sleeps
# are jobs and `wait`ed so a trapped TERM runs the cleanup at once.
if [ -n "$xprintidle_bin" ]; then
    armed=0
    while true; do
        ms=$("$xprintidle_bin" 2>/dev/null)
        case "$ms" in ''|*[!0-9]*) armed=1; break;; esac
        if [ "$armed" -eq 0 ] && [ "$ms" -ge $((ARM_MIN * 1000)) ]; then
            armed=1
        elif [ "$armed" -eq 1 ] && [ "$ms" -lt $((ARM_MIN * 1000)) ]; then
            break
        fi
        sleep 1 &
        wait $!
    done
else
    sleep "$CHAOS_DELAY" &
    wait $!
fi

sleep $((RANDOM % (PRE_CHAOS_MAX - PRE_CHAOS_MIN + 1) + PRE_CHAOS_MIN)) &
wait $!
float_rule

# Phase 3: the chaos ramps up, a random prank at a time, capped so the machine
# stays alive and nothing is ever lost. The sleep runs as a job and `wait`ed:
# a trapped signal then runs the handler at once instead of after the sleep.
while true; do
    if [ "$(live_groups)" -lt "$MAX_GROUPS" ]; then
        spawn
    fi
    sleep $((RANDOM % (WAIT_MAX - WAIT_MIN + 1) + WAIT_MIN)) &
    wait $!
done
