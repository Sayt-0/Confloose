#!/usr/bin/env bash
#
# End-to-end check, run by CI on every pull request. The repo is served locally
# and, in a throwaway HOME, each confloose is applied through install.sh and then
# undone by its antidote, which must leave the HOME exactly as it was.
#
# It is safe to run on your own machine: the environment is emptied (no display,
# no audio, no AFS), there is no terminal, and the X11/i3 tools are stubbed out.

set -u
cd "$(dirname "$0")/.." || exit 1
umask 022

# These start a background daemon, which would outlive the throwaway HOME.
SKIP=(daemon-terminal i3loop tchiki)

work=$(mktemp -d)
server=
cleanup() {
    [ -n "$server" ] && kill "$server" 2>/dev/null
    rm -rf "$work"
}
trap cleanup EXIT

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }

bin="$work/bin"
mkdir -p "$bin"
# The fleet runs sh as bash (see How it works in the README).
ln -s "$(command -v bash)" "$bin/sh"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$bin/$1" && chmod +x "$bin/$1"; }
for cmd in i3-msg i3lock setxkbmap xkill; do stub "$cmd" 'exit 0'; done
# One screen and one pointer, so the confloose that loop over them have
# something to act on.
# shellcheck disable=SC2016
stub xrandr '[ "$#" -eq 0 ] && echo "HDMI-1 connected primary 1920x1080+0+0"; exit 0'
# shellcheck disable=SC2016
stub xinput '[ "$1" = --list ] && printf "  Test Mouse\tid=10\t[slave  pointer  (2)]\n"; exit 0'

port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
server=$!
base="http://127.0.0.1:$port"
for _ in $(seq 50); do
    curl -fs -o /dev/null "$base/install.sh" && break
    sleep 0.1
done
curl -fs -o /dev/null "$base/install.sh" || { echo "FAIL: the local server did not start" >&2; exit 1; }

# A HOME with the user's own config, which every antidote has to leave intact.
home=
seed() {
    home=$(mktemp -d "$work/home.XXXXXX")
    mkdir -p "$home/.config/i3" "$home/.config/alacritty" "$home/.local/bin"
    printf '%s\n' '# my bashrc' "alias ll='ls -l'" > "$home/.bashrc"
    cat > "$home/.config/i3/config" <<'EOF'
set $mod Mod4
bindsym $mod+Return exec i3-sensible-terminal
bindsym $mod+d exec dmenu_run
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down
bindsym Mod1+Tab workspace next
EOF
    printf '[font]\nsize = 11\n' > "$home/.config/alacritty/alacritty.toml"
    printf '#!/bin/sh\nexec /usr/bin/gcc "$@"\n' > "$home/.local/bin/gcc"
    chmod +x "$home/.local/bin/gcc"
}

# Mode, content hash and path of every file, minus the lock install.sh keeps.
snapshot() {
    (cd "$home" && find . -type f ! -path ./.confloose/confloose.lock | sort |
        while IFS= read -r f; do
            printf '%s %s %s\n' "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -c1-16)" "$f"
        done)
}

# New session, so no terminal: the menu reads its answers from stdin.
run() {
    env -i HOME="$home" PATH="$bin:$PATH" CONFLOOSE_BASE="$base" \
        setsid -w bash install.sh "$@"
}

mapfile -t names < <(grep -vE '^(#|$)' confloose/manifest.txt | cut -f1)

seed
pristine=$(snapshot)

run -h < /dev/null | grep -qF "(${#names[@]} available)" \
    || fail "the menu does not list the ${#names[@]} confloose"

# The interactive menu, by number: apply the first confloose, then undo it.
printf '1\nq\n' | run > /dev/null 2>&1
run -l < /dev/null | grep -qxF "${names[0]}" || fail "menu: '1' did not apply ${names[0]}"
printf 'a 1\nq\n' | run > /dev/null 2>&1
[ "$(snapshot)" = "$pristine" ] || fail "menu: 'a 1' did not undo ${names[0]}"

checked=0
for name in "${names[@]}"; do
    [[ " ${SKIP[*]} " == *" $name "* ]] && continue
    checked=$((checked + 1))
    seed
    if ! run "$name" < /dev/null > "$work/log" 2>&1; then
        fail "$name: apply failed"
        cat "$work/log" >&2
        continue
    fi
    run -l < /dev/null | grep -qxF "$name" || fail "$name: not recorded as installed"
    [ "$(snapshot)" != "$pristine" ] || fail "$name: apply changed nothing in HOME"
    if ! run -a "$name" < /dev/null > "$work/log" 2>&1; then
        fail "$name: antidote failed"
        cat "$work/log" >&2
        continue
    fi
    run -l < /dev/null | grep -qxF "$name" && fail "$name: still recorded after its antidote"
    after=$(snapshot)
    if [ "$after" != "$pristine" ]; then
        fail "$name: the antidote did not restore HOME"
        diff <(printf '%s\n' "$pristine") <(printf '%s\n' "$after") >&2
    fi
done

echo "smoke: $checked confloose applied and undone, skipped: ${SKIP[*]}"
[ "$failures" -eq 0 ] || { echo "smoke: $failures failure(s)" >&2; exit 1; }
