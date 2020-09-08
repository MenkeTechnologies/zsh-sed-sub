# zsh-sed-sub
# created by MenkeTechnologies


This plugin adds 2 keybindings to do global search and replace on current command line.  Try it out with Ctrl-F Ctrl-P.

```sh
bindkey -M viins '^F^P' basicSedSub
bindkey -M vicmd '^F^P' basicSedSub
```

## Install for Zinit
> `~/.zshrc`
```sh
source "$HOME/.zinit/bin/zinit.zsh"
zinit ice lucid nocompile
zinit load MenkeTechnologies/zsh-sed-sub
```

## Install for Oh My Zsh

```sh
cd "$HOME/.oh-my-zsh/custom/plugins"  && git clone https://github.com/MenkeTechnologies/zsh-sed-sub.git
```

Add `zsh-sed-sub` to plugins array in ~/.zshrc

## General Install

```sh
git clone https://github.com/MenkeTechnologies/zsh-sed-sub.git
```

source zsh-sed-sub.plugin.zsh or add code to zshrc or any startup script

