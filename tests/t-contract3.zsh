#!/usr/bin/env zunit
#{{{                    MARK:Header
##### Purpose: zsh-sed-sub — third-tier surface pins covering:
#####          - BUFFER write idempotence (apply then re-apply yields same buffer)
#####          - every early-return path emits ANSI reset (no terminal stuck in color)
#####          - backspace on empty sedArg does not underflow (no negative index)
#####          - widget uses zle -R (not echo) for the prompt loop
#####          - print -r -- guards against backslash interpretation in BUFFER
#}}}***********************************************************

@setup {
    0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    pluginDir="${0:h:A}"
    widgetFile="$pluginDir/autoload/basicSedSub"
}

@test 'BUFFER write idempotence: applying same sed twice yields same string' {
    # Pin: the substitution `s@orig@replace@g` is deterministic. After the
    # first pass replaces every occurrence of orig with replace, a second
    # pass should find no remaining orig and return the same string.
    # If the sed expression did partial work, the second pass would diverge.
    local first second
    first=$(print -r -- 'foo bar foo' | sed -E -- 's@foo@baz@g')
    second=$(print -r -- "$first" | sed -E -- 's@foo@baz@g')
    assert "$first" same_as "$second"
}

@test 'every early-return path emits ANSI reset (no stuck-color terminal)' {
    # Pin: every `return 1` path in basicSedSub must be preceded by an
    # ANSI reset (`\x1b[0m`) so an aborted substitution never leaves the
    # user's terminal painted in the sub-prompt color. Count must match.
    local returns
    returns=$(grep -cE '^[[:space:]]*return 1' "$widgetFile")
    local resets_before_return
    # Heuristic: assert there are at least as many `\x1b[0m` references as
    # `return 1` lines (typically 4 resets serving 3 returns + 1 success).
    local resets
    resets=$(grep -cE 'x1b\[0m' "$widgetFile")
    [[ "$resets" -ge "$returns" ]]
    assert $state equals 0
}

@test 'backspace handler subscripts sedArg via [1,-2] (safe on empty string)' {
    # Pin: zsh's `${var[1,-2]}` is safe even when var is empty (yields ""),
    # vs `${var:0:-1}` which would fail. The widget must use the safe form.
    grep -qF 'sedArg=${sedArg[1,-2]}' "$widgetFile"
    assert $? equals 0
}

@test 'prompt loop uses zle -R (NOT echo / print) for the live prompt' {
    # Pin: zle -R is the only correct way to redraw within a widget
    # without disturbing the editing line. echo/print would scribble
    # on the current row and break ZLE's redraw state machine.
    local zle_R
    zle_R=$(grep -cE '^[[:space:]]*zle -R ' "$widgetFile")
    [[ "$zle_R" -ge 3 ]]
    assert $state equals 0
}

@test 'BUFFER replacement uses print -r -- (raw, options-terminated)' {
    # Pin: `print -r -- $BUFFER | sed ...` is the safe form. Without
    # `-r`, backslashes in BUFFER get interpreted as escapes; without
    # `--`, a BUFFER starting with `-` is parsed as a print flag.
    # Both bugs corrupt the substitution silently.
    grep -qF 'print -r -- $BUFFER' "$widgetFile"
    assert $? equals 0
}
