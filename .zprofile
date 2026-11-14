# export LANG=en_US.UTF-8

# PATH の重複を自動で取り除く（tmux の入れ子シェルなどで二重に追加されるため）
typeset -U path PATH

# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

# anyenv
eval "$(anyenv init -)"

# java
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# golang
export PATH="$GOENV_ROOT/shims:$PATH"

# local bin
export PATH="$HOME/bin:$PATH"

[ -f ~/.zprofile.local  ] && . ~/.zprofile.local
