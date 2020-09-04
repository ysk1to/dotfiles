# Prezto + poworlevel9k
POWERLEVEL9K_MODE=nerdfont-complete
[ -f "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"  ] && source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=" \U25B8 "
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=""

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
