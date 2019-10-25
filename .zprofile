export LANG=en_US.UTF-8

# python
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
export PATH="$PYENV_ROOT/versions/anaconda3-5.2.0/bin:$PATH"

# node
export PATH="$HOME/.nodebrew/current/bin:$PATH"

# ruby
eval "$(rbenv init -)"

# golang
eval "$(goenv init -)" 
export GOPATH=$HOME/.go

# direnv
export EDITOR="/usr/bin/vim"
eval "$(direnv hook bash)"

# local bin
export PATH="$HOME/bin:$PATH"

[ -f ~/.zshrc ] &&  . ~/.zshrc
