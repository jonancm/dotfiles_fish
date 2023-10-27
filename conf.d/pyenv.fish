set -x PYENV_ROOT "$HOME/.pyenv"
fish_add_path "$PYENV_ROOT/bin"
status --is-interactive; and . (pyenv init -|psub)
status --is-interactive; and . (pyenv virtualenv-init -|psub)
