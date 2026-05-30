```
 ███████╗███████╗██╗  ██╗
 ╚══███╔╝██╔════╝██║  ██║
   ███╔╝ ███████╗███████║
  ███╔╝  ╚════██║██╔══██║
 ███████╗███████║██║  ██║
 ╚══════╝╚══════╝╚═╝  ╚═╝
       [ s e d   s u b ]
```

[![CI](https://github.com/MenkeTechnologies/zsh-sed-sub/actions/workflows/ci.yml/badge.svg)](https://github.com/MenkeTechnologies/zsh-sed-sub/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![zsh](https://img.shields.io/badge/zsh-plugin-cyan.svg)](https://github.com/MenkeTechnologies/zpwr)

### `[ZLE KEYBINDINGS FOR GLOBAL SEARCH-AND-REPLACE ON THE COMMAND LINE]`

> *"`Ctrl-F Ctrl-P` — rewrite the current line in place."*

This plugin adds a ZLE keybinding (`Ctrl-F Ctrl-P`, registered in viins/vicmd/emacs keymaps) to do global search and replace on the current command line.  Try it out with Ctrl-F Ctrl-P.

### [`strykelang`](https://github.com/MenkeTechnologies/strykelang) &middot; [`zshrs`](https://github.com/MenkeTechnologies/zshrs) · [`MenkeTechnologiesMeta`](https://github.com/MenkeTechnologies/MenkeTechnologiesMeta) · [`zsh-git-acp`](https://github.com/MenkeTechnologies/zsh-git-acp) · [`zsh-sudo`](https://github.com/MenkeTechnologies/zsh-sudo) · [`zsh-more-completions`](https://github.com/MenkeTechnologies/zsh-more-completions) · [`zpwr`](https://github.com/MenkeTechnologies/zpwr)

---

## Table of Contents

- [\[0x00\] Install for Zinit](#0x00-install-for-zinit)
- [\[0x01\] Install for Oh My Zsh](#0x01-install-for-oh-my-zsh)
- [\[0x02\] General Install](#0x02-general-install)

---

## [0x00] Install for Zinit
> `~/.zshrc`
```sh
source "$HOME/.zinit/bin/zinit.zsh"
zinit ice lucid nocompile
zinit load MenkeTechnologies/zsh-sed-sub
```

## [0x01] Install for Oh My Zsh

```sh
cd "$HOME/.oh-my-zsh/custom/plugins"  && git clone https://github.com/MenkeTechnologies/zsh-sed-sub.git
```

Add `zsh-sed-sub` to plugins array in ~/.zshrc

## [0x02] General Install

```sh
git clone https://github.com/MenkeTechnologies/zsh-sed-sub.git
```

source zsh-sed-sub.plugin.zsh or add code to zshrc or any startup script

