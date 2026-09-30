#!/bin/sh

dir="${AFS_DIR:-$HOME}/.confloose/bin/daemon-terminal"
file="$dir/confloose-daemon-terminal"
mkdir -p "$dir"

curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/daemon-terminal/daemon.sh" > "$file" || { rm -rf "$dir"; exit 1; }
chmod +x "$file"

echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "daemon-terminal" "'\"$file\" 2>/dev/null 1>&2 &'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
