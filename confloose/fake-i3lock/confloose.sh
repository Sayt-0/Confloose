#!/bin/sh

# A stable directory, not `mktemp -d`: the path is baked into the rc file, so a
# /tmp cleanup or a reboot would otherwise leave a dangling PATH entry, and a
# fresh path on every apply defeats the rc-line deduplication.
dir="${AFS_DIR:-$HOME}/.confloose/bin/fake-i3lock"

# Resolve the real i3lock with our own directory out of PATH, otherwise a
# re-apply makes the new fake wrap the previous fake.
clean_path=""
old_ifs=$IFS
IFS=:
for p in $PATH; do
    [ "$p" = "$dir" ] && continue
    if [ -z "$clean_path" ]; then clean_path="$p"; else clean_path="$clean_path:$p"; fi
done
IFS=$old_ifs

if ! i3lock_bin=$(PATH="$clean_path" command -v i3lock 2>/dev/null); then
    echo "fake-i3lock: real i3lock not found, aborting" >&2
    exit 1
fi

build=$(mktemp -d)
if ! curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/fake-i3lock/i3lock.c" > "$build/i3lock.c"; then
    echo "fake-i3lock: download failed" >&2
    rm -rf "$build"
    exit 1
fi
i3lock_path=$(printf '%s' "$i3lock_bin" | sed "s|/|\\\\/|g")
sed -i "s/I3LOCK_PATH/$i3lock_path/" "$build/i3lock.c"
# Find a compiler that is not fake-gcc's wrapper: it injects -Dmain=... and
# -Dreturn=..., so building with it always fails once fake-gcc is applied.
# Walk every PATH entry instead of `command -v`: that returns only the *first*
# match, which is fake-gcc's wrapper precisely when it is installed, and the
# real compiler sitting further down PATH would never be considered.
cc_bin=""
old_ifs=$IFS
for candidate in gcc cc clang; do
    IFS=:
    for p in $clean_path; do
        IFS=$old_ifs
        [ -x "$p/$candidate" ] || continue
        grep -q "confloose by leo \[fake-gcc\]" "$p/$candidate" 2>/dev/null && continue
        cc_bin="$p/$candidate"
        break
    done
    IFS=$old_ifs
    [ -n "$cc_bin" ] && break
done
if [ -z "$cc_bin" ]; then
    echo "fake-i3lock: no usable compiler (fake-gcc applied?), aborting" >&2
    rm -rf "$build"
    exit 1
fi
if ! "$cc_bin" -o "$build/i3lock" "$build/i3lock.c" -std=c99; then
    echo "fake-i3lock: build failed" >&2
    rm -rf "$build"
    exit 1
fi

mkdir -p "$dir"
mv "$build/i3lock" "$dir/i3lock"
rm -rf "$build"

echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "fake-i3lock" "'export PATH=\"$dir:\$PATH\"'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
