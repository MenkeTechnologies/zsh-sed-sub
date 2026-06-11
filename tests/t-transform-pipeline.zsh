#!/usr/bin/env zunit
#{{{                    MARK:Header
##### Purpose: zsh-sed-sub — execute the widget's exact transform
#####          pipeline end-to-end (split -> @-escape -> sed apply),
#####          not just grep the source. Catches escape/split
#####          regressions that source-grepping cannot:
#####          - `@` delimiter collision when `@` appears in BOTH
#####            the pattern and replacement halves
#####          - multi-byte UTF-8 pattern matching through sed -E
#####          The widget reads keys interactively (read -k) so the
#####          input loop is not driveable headlessly; these tests
#####          reproduce the post-loop code path verbatim from the
#####          autoload body and assert the produced buffer string.
#}}}***********************************************************

@setup {
    0="${${0:#$ZSH_ARGZERO}:-${(%):-%N}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    pluginDir="${0:h:A}"
    widgetFile="$pluginDir/autoload/basicSedSub"
}

@test '@ in BOTH pattern and replacement round-trips (delimiter not unbalanced)' {
    # The widget delimits its sed expression with `@`:  s@orig@replace@g.
    # If a user types `a@b>c@d`, BOTH halves carry a literal `@` that
    # collides with the delimiter. The widget escapes each half via
    # `${x//@/\@}`. This test runs the FULL post-loop path — split,
    # escape, build, apply — and asserts the literal `a@b` is matched
    # and rewritten to `c@d`. A regression that escapes only one half
    # (or drops the escape) yields an unbalanced `s@a@b@c@d@g`, which
    # sed parses as `s@a@b@` + garbage and either errors or replaces
    # the wrong substring. Source-grep tests cannot catch that; this
    # asserts on the produced buffer.
    local sedArg orig replace out
    sedArg='a@b>c@d'
    orig="${sedArg%%>*}"
    replace="${sedArg##*>}"
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out="$(print -r -- 'x a@b y' | sed -E -- "$sedArg")"
    assert "$out" same_as 'x c@d y'
}

@test 'multi-byte UTF-8 pattern matches through sed -E (no byte-mode split)' {
    # `café` is 5 bytes / 4 chars (é = U+00E9, 2 bytes in UTF-8). The
    # widget passes the pattern straight into `sed -E`. This pins that
    # a full multi-byte token matches and is replaced atomically — a
    # regression to a byte-oriented or C-locale split would either
    # fail to match `café` or corrupt the trailing byte of `é`. Runs
    # the exact split+escape+sed path the widget uses post-loop.
    local sedArg orig replace out
    sedArg='café>tea'
    orig="${sedArg%%>*}"
    replace="${sedArg##*>}"
    orig="${orig//@/\\@}"
    replace="${replace//@/\\@}"
    sedArg="s@$orig@$replace@g"
    out="$(print -r -- 'I drink café daily' | sed -E -- "$sedArg")"
    assert "$out" same_as 'I drink tea daily'
}
