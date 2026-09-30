#!/bin/sh

if [ -n "${AFS_DIR:-}" ]; then
    dir="$AFS_DIR/bin"
else
    dir="$HOME/.local/bin"
fi

for name in gcc cc clang; do
    # Only remove a wrapper that is ours: the user may have installed a real
    # compiler at this path since, and deleting that would be destructive.
    if [ -e "$dir/$name" ] && ! grep -q "confloose by leo \[fake-gcc\]" "$dir/$name" 2>/dev/null; then
        rm -f "$dir/$name.confloose.bak"
        continue
    fi
    if [ -e "$dir/$name.confloose.bak" ]; then
        mv "$dir/$name.confloose.bak" "$dir/$name"
    else
        rm -f "$dir/$name"
    fi
done

curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_antidote_base.sh" | sh -s -- "fake-gcc"
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
