#!/usr/bin/env bash
# rofi script mode: fuzzy-find files and folders in $HOME (Spotlight-style), open with xdg-open.
# Index is cached and refreshed in the background when older than 15 minutes.
CACHE="$HOME/.cache/rofi-files.txt"
TMP="$CACHE.tmp"

build_index() {
    fd . "$HOME" --hidden --follow --max-depth 9 \
        --exclude .cache --exclude .git --exclude node_modules --exclude .venv --exclude venv \
        --exclude __pycache__ --exclude .npm --exclude .cargo --exclude .rustup --exclude go/pkg \
        --exclude .local/share/Trash --exclude .local/share/flatpak --exclude .var \
        --exclude .config/BraveSoftware --exclude .config/VSCodium --exclude .config/warp-terminal \
        --exclude .mozilla --exclude .thunderbird --exclude .gradle --exclude .m2 --exclude .cache \
        --exclude snap --exclude .steam --exclude .wine --exclude .pyenv --exclude .nvm \
        --exclude lost+found --exclude .Trash-1000 --exclude '*.pyc' --exclude '*.o' \
        2>/dev/null | sed "s|^$HOME|~|" > "$TMP" && mv "$TMP" "$CACHE"
}

if [ -z "$1" ]; then
    # listing phase
    if [ ! -s "$CACHE" ]; then build_index; fi
    if [ -n "$(find "$CACHE" -mmin +15 2>/dev/null)" ]; then ( build_index & ) ; fi
    printf '\0prompt\x1f\n'
    printf '\0markup-rows\x1ffalse\n'
    cat "$CACHE"
else
    # selection phase: open the chosen entry
    path="${1/#\~/$HOME}"
    [ -e "$path" ] && coproc ( xdg-open "$path" >/dev/null 2>&1 )
fi
