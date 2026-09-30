#!/bin/sh

dir="$HOME/.config/alacritty"
file="$dir/alacritty.toml"
backup="$dir/alacritty.toml.bak"
absent="$dir/alacritty.toml.absent"

mkdir -p "$dir"

# Record whether the user had a config at all. Creating an empty one just to back
# it up would make the antidote restore an empty alacritty.toml instead of
# removing the file, leaving a stray config that overrides the defaults.
# Only on the *first* apply: after that, "$file" is our own config, and
# re-deciding would drop the .absent marker and back up the prank itself.
if [ ! -f "$backup" ] && [ ! -f "$absent" ]; then
    if [ -f "$file" ]; then
        cp "$file" "$backup"
    else
        : > "$absent"
    fi
fi

tmpfile=$(mktemp)
if curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/alacritty-color/config.toml" > "$tmpfile"; then
    chmod 644 "$tmpfile"   # mktemp gives 0600, which would outlive the antidote
    mv "$tmpfile" "$file"
else
    echo "alacritty-color: download failed, keeping existing config" >&2
    rm -f "$tmpfile"
    exit 1
fi
