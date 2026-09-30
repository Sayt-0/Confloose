#!/bin/sh

echo $(curl -fsSL "${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/bashrc_confloose_base.sh") "editor-kill" "'for editor in vi vim nvim helix emacs nano rider clion idea code; do alias \"\$editor\"=\"exit;test\"; done'" | sh
for name in bashrc zshrc; do [ -f "$HOME/.$name" ] && ( . "$HOME/.$name" ) 2>/dev/null; done; true
