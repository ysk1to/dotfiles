# Prezto + poworlevel10k
[ -f "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"  ] && source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
source "${ZDOTDIR:-$HOME}/.p10k.zsh"

# solve ctrl+a command does not work issue.
bindkey -e

# zsh-completions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

    autoload -Uz compinit
    compinit
fi

# alias

## ls
alias ls='ls -FG'
alias ll='ls -aFlG'

## cd
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

## git
alias g='git'
alias ga='git add'
alias gd='git diff'
alias gs='git status'
alias gp='git push'
alias gpo='git push origin HEAD'
alias gb='git branch'
alias gst='git stash'
alias gco='git checkout'
alias gf='git fetch'
alias gm='git merge'
alias gc='git commit'

# terraform
alias tf='terraform'

## program
alias n='node'
alias p='python'
alias r='ruby'
alias v='vim'
