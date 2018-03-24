#############
#  ALIASES  #
#############

compdef dotfiles=git

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'
alias ........='cd ../../../../.././...'

alias :q='exit'

alias pg='ping -c 1 www.google.ch'

alias bcl='bc -l'

alias neofetch='echo "\\n\\n" && neofetch'

alias grep='grep --color=auto --exclude-dir={.git,.svn}'
alias egrep='egrep --color=auto --exclude-dir={.git,.svn}'

alias -g C='| xclip -selection clipboard -rmlastnl'

foreground-job() {
    fg
}
zle     -N   foreground-job
bindkey '^Z' foreground-job

mkcd() {
    [ $# -gt 1 ] && exit 1
    mkdir -p "$1" && cd "$1" || exit 1
}

toilol() {
    toilet -f mono12 -w "$(tput cols)" | lolcat "$@"
}


#########
#  FZF  #
#########

alias fzf="fzf-tmux -d 30% --"


#############
#  RIPGREP  #
#############

# fuzzy rg
frg() {
    rg --line-number \
        --column \
        --no-heading \
        --color=always \
        --colors='match:none' \
        --colors='path:fg:white' \
        --colors='line:fg:white' \
        "$@" . 2> /dev/null \
        | fzf --ansi
}


#######################
# THE SILVER SEARCHER #
#######################

alias ag="ag \
    --hidden \
    --follow \
    --smart-case \
    --numbers \
    --color-match '1;31' \
    --color-path '0;37' \
    --color-line-number '1;33'"

# fuzzy ag
fag() {
    ag --nobreak \
        --noheading \
        --color \
        --color-match '' \
        --color-path '0;37' \
        --color-line-number '0;37' \
        "$@" . 2> /dev/null \
        | fzf --ansi
}


##################
# FUZZY COMMANDS #
##################

# # cd to selected directory (no hidden files)
# cnh() {
#       cd "$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null \
#           | fzf +m -q "$1" -0)"
# }

# cd to selected directory (no hidden files)
cnh() {
    cd "$(fd --follow --type d '.' "${1:-.}" 2> /dev/null \
        | fzf +m -q "$1" -0)" \
        || exit 1
}

# # cnh, but including hidden directories
# c() {
#       cd "$(find -L ${1:-.} -type d 2> /dev/null \
#           | fzf +m -q "$1" -0)"
# }

# cnh, but including hidden directories
c() {
    cd "$(fd --hidden --follow --type d '.' "${1:-.}" 2> /dev/null \
        | fzf +m -q "$1" -0)" \
        || exit 1
}

# # cd to selected directory and open ranger
# fr() {
#       cd "$(find -L ${1:-.} -type d 2> /dev/null \
#           | fzf +m -q "$1" -0)" && ranger
# }

# cd to selected directory and open ranger
fr() {
    cd "$(fd --hidden --follow --type d '.' "${1:-.}" 2> /dev/null \
        | fzf +m -q "$1" -0)" \
        && ranger
}

# open the selected file with the default editor
#       - CTRL-O to open with `open` command,
#       - CTRL-E or Enter key to open with the $EDITOR
fo() {
    local out file key
    IFS=$'\n' out=($(fzf -q "$1" -0 --expect=ctrl-o,ctrl-e))
    key=$(head -1 <<< "$out")
    file=$(head -2 <<< "$out" | tail -1)
    if [ -n "$file" ]; then
        [ "$key" = ctrl-o ] \
            && mimeopen -n "$file" \
            || ${EDITOR:-vim} "$file"
    fi
}

# cd into the directory of the selected file
cdf() {
    local file
    local dir
    file=$(fzf +m -q "$1" -0) \
        && dir=$(dirname "$file") \
        && cd "$dir" \
        || exit 1
}

# browse chrome history
ch() {
    local cols sep google_history open
    cols=$(( COLUMNS / 3 ))
    sep='{::}'

    if [ "$(uname)" = "Darwin" ]; then
        google_history="$HOME/Library/Application Support/Google/Chrome/Default/History"
        open="open"
    else
        google_history="$HOME/.config/chromium/Default/History"
        open="mimeopen -n"
    fi

    cp -f "$google_history" /tmp/h
    sqlite3 -separator $sep /tmp/h \
        "select substr(title, 1, $cols), url
    from urls order by last_visit_time desc" \
        | awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' \
        | fzf --ansi -m \
        | sed 's#.*\(https*://\)#\1#' \
        | xargs "$open" > /dev/null 2> /dev/null
}

# cd to selected parent directory
fdp() {
    local dirs=()

    get_parent_dirs() {
        if [[ -d "${1}" ]]; then
            dirs+=("$1"); else return;
        fi
        if [[ "${1}" == '/' ]]; then
            for _dir in "${dirs[@]}"; do
                echo "$_dir";
            done
        else
            get_parent_dirs "$(dirname "$1")"
        fi
    }

    cd "$(get_parent_dirs "$(realpath "${1:-$PWD}")" | fzf --tac)" \
        || exit 1
}

# kill process
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

    if [ "x$pid" != "x" ]; then
        echo "$pid" | xargs kill -"${1:-9}"
    fi
}

# pacman search
# example usage: pacman -S $(fp)
fp() {
    echo -n "$(pacman --color always "${@:--Ss}" \
        | sed 'N;s/\n//' \
        | fzf -m --ansi \
        | sed 's/ .*//')"
}

# man search
fman() {
    man "$(apropos . | fzf | sed 's/ .*//')"
}
