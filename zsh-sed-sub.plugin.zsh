basicSedSub(){
    emulate -LR zsh
    print -r "$BUFFER" | command egrep -q '\w+' || {
        zle up-line-or-history
        #printf "\x1b[1;31m"
        #zle -R  "Extended Regex Sed Substitution: Empty buffer." && read -k 1
        #printf "\x1b[0m"
        #return 1
    }

    printf "\x1b[1;34m"
    zle -R "Extended Regex Sed Substitution (original>replaced) (@ not allowed in either string):"
    printf "\x1b[1;44;37m"
    local SEDARG=""
    local key=""
    read -k key
    local -r start=$key
    while (( (#key)!=(##\n) && (#key)!=(##\r) )) ; do
        if (( (#key)==(##\>) ));then
            printf "\x1b[0;4;1;34m"
        else
            printf "\x1b[1;44;37m"
            print -r "$SEDARG" | grep -q '>' && printf \
                "\x1b[0;1;37;45m"
        fi
        if (( (#key)==(##^?) || (#key)==(##^h) ));then
            SEDARG=${SEDARG[1,-2]}
            printf "\x1b[0m"
        elif (( (#key)==(##^U) ));then
            SEDARG=""
            printf "\x1b[0m"
        else
            if (( (#key)!=(##@) ));then
                SEDARG="${SEDARG}$key"
            fi
        fi
        zle -R "Extended Regex Sed Substitution (original>replaced) (@ not allowed in either string): $SEDARG"
        read -k key || return 1
    done
    print -r "$SEDARG" | grep -q "@" && {
        printf "\x1b[0;1;31m"
        zle -R "No '@' allowed! That is the sed delimiter!" && read -k key
    printf "\x1b[0m"
    return 1
}

    print -r "$SEDARG" | grep -q ">" || {
        printf "\x1b[0;1;31m"
        zle -R  "Needed '>' for separation of original regex string and substitution!" && read -k 1
        printf "\x1b[0m"
        return 1
    }

    orig="$(print -r $SEDARG | awk -F'>' '{print $1}')"
    replace="$(print -r $SEDARG | awk -F'>' '{print $2}')"
    SEDARG="s@$orig@$replace@g"

    print -r "$BUFFER" | command egrep -q "$orig" || {
        printf "\x1b[0;1;31m"
        zle -R  "No Match." && read -k 1
        printf "\x1b[0m"
        return 1
    }

    BUFFER="$(print -r $BUFFER | sed -E "$SEDARG")"
    printf "\x1b[0m"
}

zle -N basicSedSub
bindkey -M viins '^]' basicSedSub
bindkey -M vicmd '^]' basicSedSub

