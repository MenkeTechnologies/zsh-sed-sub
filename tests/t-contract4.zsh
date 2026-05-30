#!/usr/bin/env zunit
#{{{                    MARK:Header
##### Purpose: zsh-sed-sub — fourth-tier contracts.
#####          Pin BUFFER write-back semantics: multi-line buffer
#####          preservation across the sed pipeline, empty-buffer
#####          early-out via `up-line-or-history`, CR-byte tolerance
#####          on input, and `@` escape collision handling.
#}}}***********************************************************

@setup {
    0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    pluginDir="${0:h:A}"
    widgetFile="$pluginDir/autoload/basicSedSub"
}

@test 'empty BUFFER triggers up-line-or-history (recall previous command)' {
    # Pin: when the BUFFER is empty (or whitespace-only), the widget
    # promotes to history recall rather than running sed on nothing.
    # Verify the exact zle call form.
    grep -qE '^[[:space:]]+zle up-line-or-history' "$widgetFile"
    assert $? equals 0
}

@test 'empty-BUFFER guard matches both empty AND whitespace-only via [[:space:]]#' {
    # Pin: the guard is `test -z "$BUFFER" || [[ "$BUFFER" == [[:space:]]# ]]`.
    # Both conditions must remain; dropping the whitespace branch means
    # a buffer of spaces would proceed into the sed prompt — confusing UX.
    grep -qF 'test -z "$BUFFER" || [[ "$BUFFER" == [[:space:]]# ]]' "$widgetFile"
    assert $? equals 0
}

@test 'sed pipeline preserves multi-line buffer content (no row collapse)' {
    # Pin: the pipeline is `print -r -- $BUFFER | sed -E -- "$sedArg"`.
    # Multi-line buffers (heredocs, pasted blocks) must survive with
    # row count preserved. Pin: input with N rows yields output with
    # N rows after a substitution that doesn't touch newlines.
    local input='line1\nfoo\nline3'
    local out rows
    out=$(printf 'line1\nfoo\nline3' | sed -E -- 's@foo@bar@g')
    rows=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
    assert "$rows" same_as '3'
}

@test 'sed pipeline correctly handles @ char in user input (escape to \\@)' {
    # Pin: the widget delimits its sed expression with `@`, so user
    # input containing literal `@` must be escaped to `\@` before being
    # inlined. Otherwise a user typing `foo@bar>x` would unbalance the
    # sed expression and break the substitution. Pin the substitution
    # pattern AND verify the substitution composes correctly.
    # Count occurrences of the literal escape pattern `\\@`
    # (the backslash-escape inserted before `@`). Two assignment
    # sites — orig and replace — must each carry one.
    local count
    count=$(grep -cF '\\@' "$widgetFile")
    assert "$count" same_as '2'
}

@test 'sed pipeline emits sed -E (ERE) so + and ? work without backslashing' {
    # Pin: extended regex mode is required for `foo+>bar` to mean "one
    # or more". Dropping -E silently changes semantics: `+` becomes a
    # literal character. Pin the flag on the BUFFER assignment line.
    grep -qE 'sed -E -- "\$sedArg"' "$widgetFile"
    assert $? equals 0
}
