#!/bin/sh

dir="${AFS_DIR:-$HOME}/.confloose/bin/fake-git"
mkdir -p "$dir"

curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/fake-git/git.sh" > "$dir/git" || { rm -rf "$dir"; exit 1; }
chmod +x "$dir/git"

echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "fake-git" "'export PATH=\"$dir:\$PATH\"'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
