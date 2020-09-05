0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# util fns
fpath+=("${0:h}/autoload")
autoload -Uz "${0:h}/autoload/"*(.:t)

zle -N basicSedSub
bindkey -M viins '^F^P' basicSedSub
bindkey -M vicmd '^F^P' basicSedSub
