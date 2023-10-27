set -x PYENV_ROOT "$HOME/.pyenv"
fish_add_path "$PYENV_ROOT/bin"
if command -v pyenv &> /dev/null
	status --is-interactive; and . (pyenv init -|psub)
	status --is-interactive; and . (pyenv virtualenv-init -|psub)
end
