if command -v nvim &> /dev/null
	set -x EDITOR nvim
else if command -v vim &> /dev/null
	set -x EDITOR vim
end

set -x PAGER less
