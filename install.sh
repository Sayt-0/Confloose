#!/usr/bin/env bash
#
# Confloose - curl-friendly installer with a selection menu.
#
# Usage:
#   curl -fsSL <url> | bash                      # interactive menu
#   curl -fsSL <url> | bash -s -- <name> [name..] # apply directly
#   curl -fsSL <url> | bash -s -- -a <name..>    # antidote (undo)
#   curl -fsSL <url> | bash -s -- -l             # list installed confloose
#
# Collection reused from https://github.com/d-002/epita (thanks d-002 / leo).

set -u

# Base URL the confloose are downloaded from. Override it for local testing:
#   CONFLOOSE_BASE=http://127.0.0.1:8000 bash install.sh
CONFLOOSE_BASE="${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}"
export CONFLOOSE_BASE

# With `curl | bash`, stdin is taken by the piped script, so menu answers are read
# straight from the terminal. With no terminal, fall back to stdin (this also lets
# tests pipe the choices in).
# We *open* /dev/tty rather than test -r it: the device node is mode 0666, so
# `[ -r /dev/tty ]` succeeds even for a process with no controlling terminal
# (cron, CI, docker run without -t) and the fallback would never trigger.
if { : < /dev/tty; } 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/stdin; fi

# Track active confloose (uses the EPITA fleet AFS home when present).
CONF_DIR="${AFS_DIR:-$HOME}/.confloose"
LOCK="$CONF_DIR/confloose.lock"

if [ -t 1 ]; then
    c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_bold=$'\033[1m'; c_off=$'\033[0m'
else
    c_red=''; c_grn=''; c_ylw=''; c_bold=''; c_off=''
fi

# --max-time keeps a black-holed network from hanging the installer (and, in
# the menu loop, every subsequent prompt) forever.
fetch() { curl -fsSL --connect-timeout 10 --max-time 60 "$1"; }

lock_add() {
    mkdir -p "$CONF_DIR"; touch "$LOCK"
    grep -qxF -- "$1" "$LOCK" 2>/dev/null || printf '%s\n' "$1" >> "$LOCK"
}
lock_del() {
    [ -f "$LOCK" ] || return 0
    grep -vxF -- "$1" "$LOCK" > "$LOCK.tmp" 2>/dev/null || : > "$LOCK.tmp"
    mv "$LOCK.tmp" "$LOCK"
}
lock_has() {
    [ -f "$LOCK" ] && grep -qxF -- "$1" "$LOCK" 2>/dev/null
}
lock_list() {
    if [ -s "$LOCK" ]; then cat "$LOCK"; else echo "(no confloose installed)"; fi
}

# We check the download (curl -f fails on a 404), then run it. The confloose scripts
# source the rc files in a guarded subshell and end on `true`, so a non-zero exit
# here is a real failure (missing binary, failed build, failed download, refused
# conflict) and we must not record the confloose as installed.
apply() {
    local body rc
    if ! body=$(fetch "$CONFLOOSE_BASE/confloose/$1/confloose.sh"); then
        printf '%s!! confloose not found: %s%s\n' "$c_red" "$1" "$c_off" >&2
        return 1
    fi
    printf '%s>> confloose %s%s\n' "$c_grn" "$1" "$c_off"
    printf '%s\n' "$body" | sh
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%s!! confloose %s failed (exit %d), not recorded%s\n' "$c_red" "$1" "$rc" "$c_off" >&2
        return 1
    fi
    lock_add "$1"
}

antidote() {
    local body rc
    if ! body=$(fetch "$CONFLOOSE_BASE/confloose/$1/antidote.sh"); then
        printf '%s!! antidote not found: %s%s\n' "$c_red" "$1" "$c_off" >&2
        return 1
    fi
    printf '%s<< antidote %s%s\n' "$c_ylw" "$1" "$c_off"
    printf '%s\n' "$body" | sh
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%s!! antidote %s failed (exit %d), still recorded%s\n' "$c_red" "$1" "$rc" "$c_off" >&2
        return 1
    fi
    lock_del "$1"
}

NAMES=(); DESCS=()
load_manifest() {
    local name desc
    while IFS=$'\t' read -r name desc; do
        [ -z "${name:-}" ] && continue
        case "$name" in \#*) continue;; esac
        NAMES+=("$name"); DESCS+=("$desc")
    done < <(fetch "$CONFLOOSE_BASE/confloose/manifest.txt")
}

valid_name() {
    local n="$1" x
    for x in "${NAMES[@]:-}"; do [ "$x" = "$n" ] && return 0; done
    return 1
}

print_menu() {
    if [ "${#NAMES[@]}" -eq 0 ]; then echo "(manifest empty or unreachable)"; return; fi
    printf '\n%s=== Confloose ===%s  (%d available)\n' "$c_bold" "$c_off" "${#NAMES[@]}"
    local i
    for i in "${!NAMES[@]}"; do
        printf '  %2d) %s%-18s%s %s\n' "$((i+1))" "$c_bold" "${NAMES[$i]}" "$c_off" "${DESCS[$i]}"
    done
    printf '\nNumbers to apply (e.g. "1 4 7").  '
    printf 'Prefix with %sa%s to undo (e.g. "a 4").  %sl%s=installed  %sq%s=quit\n' \
        "$c_bold" "$c_off" "$c_bold" "$c_off" "$c_bold" "$c_off"
}

# Turn numbers and/or names into valid names (one per line).
resolve() {
    local tok idx out=()
    for tok in "$@"; do
        if printf '%s' "$tok" | grep -qE '^[0-9]{1,4}$'; then
            idx=$((10#$tok - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#NAMES[@]}" ]; then
                out+=("${NAMES[$idx]}")
            else
                printf '%sout of range (1-%d): %s%s\n' "$c_red" "${#NAMES[@]}" "$tok" "$c_off" >&2
            fi
        elif valid_name "$tok"; then
            out+=("$tok")
        else
            printf '%sunknown: %s%s\n' "$c_red" "$tok" "$c_off" >&2
        fi
    done
    [ "${#out[@]}" -eq 0 ] && return 0
    printf '%s\n' "${out[@]}"
}

menu_loop() {
    while true; do
        print_menu
        printf '%s> %s' "$c_bold" "$c_off"
        local sel n
        IFS= read -r sel < "$TTY" || break
        # Disable glob expansion: input like "*" must not expand to files.
        # shellcheck disable=SC2086
        set -f; set -- $sel; set +f
        [ "$#" -eq 0 ] && continue
        case "$1" in
            q|Q) break;;
            l|L) echo; lock_list;;
            a|A) shift; for n in $(resolve "$@"); do antidote "$n"; done;;
            *)   for n in $(resolve "$@"); do apply "$n"; done;;
        esac
    done
}

main() {
    if [ "$#" -gt 0 ]; then
        case "$1" in
            -a|--antidote) shift; load_manifest
               for n in "$@"; do
                   if valid_name "$n" || lock_has "$n"; then
                       antidote "$n"
                   else
                       printf '%sunknown: %s%s\n' "$c_red" "$n" "$c_off" >&2
                   fi
               done;;
            -l|--list)     lock_list;;
            -h|--help)     load_manifest; print_menu;;
            *) load_manifest
               for n in "$@"; do
                   if valid_name "$n"; then apply "$n"; else printf '%sunknown: %s%s\n' "$c_red" "$n" "$c_off" >&2; fi
               done;;
        esac
        return
    fi
    load_manifest
    if [ "${#NAMES[@]}" -eq 0 ]; then
        echo "Confloose: manifest unreachable ($CONFLOOSE_BASE). Retry, or pass a name as an argument." >&2
        exit 1
    fi
    menu_loop
}

main "$@"
