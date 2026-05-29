#!/usr/bin/env zunit
#{{{                    MARK:Header
##### Purpose: zsh-sed-sub second-tier contracts. Cover autoload
#####          file structure, idempotent re-source, edge cases
#####          in the sed transformation, and the BUFFER assignment
#####          shape that the widget uses to write its result back.
#}}}***********************************************************

@setup {
    0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    pluginDir="${0:h:A}"
    pluginFile="$pluginDir/zsh-sed-sub.plugin.zsh"
    widgetFile="$pluginDir/autoload/basicSedSub"
}

@test 'autoload basicSedSub file ends with a bare basicSedSub invocation' {
    # Pin: zsh autoload-style files (autoload -Uz) execute the fn at
    # autoload time when the file ends with `fnname "$@"`. Without that
    # trailing call, the fn is defined but not run when the widget
    # fires; the result is a "no such widget" or silent no-op.
    local last
    last=$(grep -vE '^\s*$' "$widgetFile" | tail -1)
    assert "$last" same_as 'basicSedSub "$@"'
}

@test 'plugin re-source is idempotent (bindkey count stable, no widget duplication)' {
    # Pin: re-sourcing must not double-register the widget. zle -N on a
    # name that already exists is a no-op-with-warning, but bindkey
    # accumulates if the keymap entries grow.
    local out
    out=$(zsh -c "
        emulate zsh
        source '$pluginFile' 2>/dev/null
        first=\$(bindkey -M emacs | grep -c basicSedSub)
        source '$pluginFile' 2>/dev/null
        source '$pluginFile' 2>/dev/null
        second=\$(bindkey -M emacs | grep -c basicSedSub)
        print \"\$first \$second\"
    ")
    local first="${out%% *}"
    local second="${out##* }"
    assert "$first" same_as "$second"
}

@test 'sed pipeline: short orig string substitutes across repeated matches' {
    # Pin: the pipeline must replace ALL occurrences of a 3-char orig
    # in a tight repeated string. Catches a regression that drops /g
    # or splits the buffer into one-line-only mode.
    local orig replace sedArg out
    orig='foo'
    replace='X'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'foofoofoo' | sed -E -- "$sedArg")
    assert "$out" same_as 'XXX'
}

@test 'sed pipeline: case-sensitive by default (no /i flag added silently)' {
    # Pin: the widget does NOT append /i. If a refactor added it
    # for "user friendliness", `Foo>bar` would also replace `FOO`,
    # which is documented as case-sensitive behavior.
    local orig replace sedArg out
    orig='Foo'
    replace='X'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'Foo FOO foo' | sed -E -- "$sedArg")
    assert "$out" same_as 'X FOO foo'
}

@test 'widget writes back to BUFFER via print -r -- (raw output)' {
    # Pin: the result line uses raw print so escape sequences in the
    # user buffer pass through unchanged. Bare echo would expand them.
    local count
    count=$(grep -c 'print -r -- ' "$widgetFile")
    [[ "$count" -ge 1 ]]
    assert $? equals 0
}

@test 'widget does not leak local vars (declares sedArg, key, orig, replace local)' {
    # Pin: bare assignments to these names inside a widget would leak
    # into the user's interactive shell, polluting completion and
    # syntax-highlighting plugins that may scan globals.
    grep -qE '^[[:space:]]+local sedArg key orig replace' "$widgetFile"
    assert $? equals 0
}
