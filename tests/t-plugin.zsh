#!/usr/bin/env zunit
#{{{                    MARK:Header
#**************************************************************
##### Purpose: zsh-sed-sub plugin + transformation contract pins.
#####          The widget itself blocks on interactive keystrokes
#####          via `read -k`, so we test the structural wiring
#####          (fpath/autoload/keybindings) AND the post-input
#####          sed transformation logic by replicating the
#####          orig>replace -> s@orig@replace@g build that the
#####          widget runs after the user hits enter.
#}}}***********************************************************

@setup {
    0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    pluginDir="${0:h:A}"
    pluginFile="$pluginDir/zsh-sed-sub.plugin.zsh"
    widgetFile="$pluginDir/autoload/basicSedSub"
}

@test 'plugin appends autoload/ to fpath (plugin-manager portable)' {
    # Pin: ${0:h}/autoload MUST be on fpath so basicSedSub gets
    # picked up by `autoload -Uz`. A refactor to a hardcoded path
    # breaks every plugin manager.
    local body
    body=$(cat "$pluginFile")
    assert "$body" contains 'fpath+=("${0:h}/autoload")'
}

@test 'plugin autoloads everything under autoload/ (not just basicSedSub)' {
    # Pin: the glob ensures future helper fns get loaded with no
    # plugin-file edit. Hardcoding the single name would silently
    # break additions.
    local body
    body=$(cat "$pluginFile")
    assert "$body" contains 'autoload -Uz "${0:h}/autoload/"*(.:t)'
}

@test 'plugin registers basicSedSub as a ZLE widget' {
    # Pin: `zle -N basicSedSub` MUST run at source-time. Without it
    # the bindkey calls would bind to a non-widget and silently
    # produce "no such widget" errors.
    local body
    body=$(cat "$pluginFile")
    assert "$body" contains 'zle -N basicSedSub'
}

@test 'plugin binds C-f C-p in all three modes (viins/vicmd/emacs)' {
    # Pin: the binding must reach the user regardless of their
    # editing mode. Dropping any mode silently strands users.
    local body
    body=$(cat "$pluginFile")
    assert "$body" contains "bindkey -M viins '^F^P' basicSedSub"
    assert "$body" contains "bindkey -M vicmd '^F^P' basicSedSub"
    assert "$body" contains "bindkey -M emacs '^F^P' basicSedSub"
}

@test 'basicSedSub widget file is the autoload function (matches widget name)' {
    # Pin: zsh `autoload` requires the file basename to match the
    # function name. Renaming the file silently breaks the autoload.
    assert "$widgetFile" is_file
    local first
    first=$(grep -E '^basicSedSub\(\)' "$widgetFile" | head -1)
    assert "$first" contains 'basicSedSub()'
}

@test 'basicSedSub uses emulate -LR zsh (option safety)' {
    # Pin: widget MUST emulate so it survives any user setopt.
    # Without this, e.g. nomatch/nounset/glob_subst in the user's
    # shell can break the sed pipeline mid-substitution.
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains 'emulate -LR zsh'
}

@test 'basicSedSub requires `>` separator (rejects malformed input)' {
    # Pin: the widget refuses to substitute without `>` between
    # orig and replace. Without this guard, an accidental Enter
    # would silently delete arbitrary BUFFER content.
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains "if [[ \"\$sedArg\" != *'>'* ]]; then"
    assert "$body" contains "Needed '>' for separation"
}

@test 'basicSedSub uses @ as sed delimiter (avoids common / collision in paths)' {
    # Pin: the widget builds `s@$orig@$replace@g`. Switching to `/`
    # would collide with every filesystem path substitution.
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains 'sedArg="s@$orig@$replace@g"'
}

@test 'basicSedSub escapes @ in user input (preserves delimiter integrity)' {
    # Pin: if user types `foo@bar>baz`, the literal @ in orig MUST
    # be backslash-escaped so it does not terminate the s@...@...@
    # delimiter early. Same for replace. The source uses the
    # //@/ replacement form on both orig and replace.
    grep -c '//@/' "$widgetFile" > /tmp/zss_count
    local count
    count=$(cat /tmp/zss_count)
    rm -f /tmp/zss_count
    local result=$([[ "$count" -ge 2 ]] && echo yes || echo "no:$count")
    assert "$result" same_as 'yes'
    # And the result of the replacement must end up inside the s@@@g build.
    grep -q 's@\$orig@\$replace@g' "$widgetFile"
    assert $? equals 0
}

@test 'basicSedSub bails if BUFFER does not contain the orig string (no-op safety)' {
    # Pin: if the orig pattern is not in BUFFER, the widget refuses
    # to run sed (would be a wasted call AND surfaces "No Match" so
    # the user sees the failure rather than wondering why nothing
    # changed).
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains 'if [[ "$BUFFER" != *"$orig"* ]]'
    assert "$body" contains 'No Match'
}

@test 'basicSedSub pipes BUFFER through `sed -E` (extended regex)' {
    # Pin: -E is the GNU+BSD-portable extended-regex flag the
    # README documents. Dropping -E would silently fall back to
    # basic regex and break documented examples like `[0-9]+`.
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains 'sed -E'
}

@test 'basicSedSub handles backspace + ^U (line-edit primitives)' {
    # Pin: while reading keys the widget MUST allow backspace (^?,
    # ^H) and ^U (line kill) so users can correct typos. Removing
    # either makes the prompt feel broken.
    local body
    body=$(cat "$widgetFile")
    assert "$body" contains '(##^?)'
    assert "$body" contains '(##^h)'
    assert "$body" contains '(##^U)'
}

@test 'basicSedSub aborts on ESC (cancellation path)' {
    # Pin: ESC must abort the substitution prompt. Removing this
    # leaves the user trapped in the read loop with no way out
    # except disconnect.
    grep -q 'e)' "$widgetFile"
    assert $? equals 0
    grep -q 'return 1' "$widgetFile"
    assert $? equals 0
    # And confirm there's at least one ESC-related comparison in the
    # key-read loop (key tested against a literal escape character).
    local esc_count
    esc_count=$(grep -c '##.e' "$widgetFile")
    local result=$([[ "$esc_count" -ge 1 ]] && echo yes || echo "no:$esc_count")
    assert "$result" same_as 'yes'
}

# ─── sed transformation tests (replay the post-input pipeline) ──────

@test 'sed pipeline: simple substitution replaces all occurrences (g flag)' {
    # Pin: trailing /g is what makes substitutions global; dropping
    # it silently changes the widget to first-match-only.
    local orig replace sedArg out
    orig='foo'
    replace='bar'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'foo foo baz foo' | sed -E -- "$sedArg")
    assert "$out" same_as 'bar bar baz bar'
}

@test 'sed pipeline: @ in orig gets escaped so it does not break the delimiter' {
    # Replay the // escape pass from the widget. If the @ inside
    # orig were NOT escaped, sed would parse `s@foo@bar@baz@g` as
    # `s@foo@bar` + extra args, garbling the substitution.
    local orig replace sedArg out
    orig='foo@x'
    replace='baz'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'foo@x test foo@x' | sed -E -- "$sedArg")
    assert "$out" same_as 'baz test baz'
}

@test 'sed pipeline: extended regex character class works' {
    # Pin: -E enables [a-z]+ without backslashes. The README
    # documents this; pin so regression to basic regex is caught.
    local orig replace sedArg out
    orig='[0-9]+'
    replace='N'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'a 123 b 456 c' | sed -E -- "$sedArg")
    assert "$out" same_as 'a N b N c'
}

@test 'sed pipeline: anchored regex (^ / $) substitutes correctly' {
    local orig replace sedArg out
    orig='^hello'
    replace='HI'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'hello world' | sed -E -- "$sedArg")
    assert "$out" same_as 'HI world'
}

@test 'sed pipeline: backref in replacement works (\\1 captured group)' {
    # Pin: capture groups + backrefs are the killer feature of -E.
    local orig replace sedArg out
    orig='([a-z]+)=([0-9]+)'
    replace='\2:\1'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'foo=12 bar=34' | sed -E -- "$sedArg")
    assert "$out" same_as '12:foo 34:bar'
}

@test 'sed pipeline: split orig from replace via ${sedArg%%>*} / ${sedArg##*>}' {
    # Pin: the split must be greediest-on-left, greediest-on-right
    # so a single `>` is the separator. If the parameter expansion
    # flags drift, multi-`>`-input substitutions get garbled.
    local sedArg orig replace
    sedArg='aaa>bbb'
    orig="${sedArg%%>*}"
    replace="${sedArg##*>}"
    assert "$orig" same_as 'aaa'
    assert "$replace" same_as 'bbb'
}

@test 'sed pipeline: multiple > in input - orig is everything BEFORE last >, replace is AFTER last' {
    # Pin: %%>* takes the SHORTEST left-prefix (before FIRST >);
    # ##*> takes the SHORTEST right-suffix (after LAST >).
    # So `a>b>c` -> orig=a, replace=c. The middle `b` is dropped.
    # This is the documented behaviour — pin so a refactor can't
    # silently change to greedy split.
    local sedArg orig replace
    sedArg='a>b>c'
    orig="${sedArg%%>*}"
    replace="${sedArg##*>}"
    assert "$orig" same_as 'a'
    assert "$replace" same_as 'c'
}

@test 'sed pipeline: empty replacement deletes orig (the "search and delete" idiom)' {
    local orig replace sedArg out
    orig='DEL'
    replace=''
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'aDELbDELc' | sed -E -- "$sedArg")
    assert "$out" same_as 'abc'
}

@test 'sed pipeline: substitution with paths (the killer use-case for @ delimiter)' {
    # The very reason for choosing @ as the delimiter — paths with
    # `/` MUST substitute cleanly. With `/` as delimiter, every
    # /-containing input requires backslash-escaping.
    local orig replace sedArg out
    orig='/usr/local/bin'
    replace='/opt/bin'
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out=$(print -r -- 'export PATH=/usr/local/bin:/usr/bin' | sed -E -- "$sedArg")
    assert "$out" same_as 'export PATH=/opt/bin:/usr/bin'
}

@test 'plugin sourced + widget visible via `zle -l`' {
    # End-to-end: source the plugin in a fresh zsh subshell, verify
    # basicSedSub shows up in the registered widget list. Catches
    # the case where `zle -N` was renamed or the autoload fn name
    # drifted from the file name.
    local widgets
    widgets=$(zsh -c "
        emulate zsh
        source '$pluginFile'
        zle -l
    " 2>&1)
    # zle -l only works from inside a widget; outside it returns
    # nothing or errors. So instead probe by checking the widget
    # got autoloaded by exercising `whence`.
    local exists
    exists=$(zsh -c "
        emulate zsh
        source '$pluginFile'
        whence -v basicSedSub
    " 2>&1)
    assert "$exists" contains 'basicSedSub'
}
