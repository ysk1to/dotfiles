# export LANG=en_US.UTF-8

# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

# python
#export PYENV_ROOT="$HOME/.pyenv"
#export PATH="$PYENV_ROOT/bin:$PATH"
#eval "$(pyenv init -)"
#export PATH="$PYENV_ROOT/versions/anaconda3-5.2.0/bin:$PATH"

# node
#eval "$(nodenv init -)"

# ruby
#eval "$(rbenv init -)"

# golang
#eval "$(goenv init -)" 
#export GOPATH=$HOME/.go

# direnv
#export EDITOR="/usr/bin/vim"
#eval "$(direnv hook bash)"

# local bin
export PATH="$HOME/bin:$PATH"

[ -f ~/.zprofile.local  ] && . ~/.zprofile.local

[ -f ~/.zshrc ] &&  . ~/.zshrc
