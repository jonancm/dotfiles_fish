if command -v nvim &> /dev/null
	set -xg EDITOR nvim
else if command -v vim &> /dev/null
	set -xg EDITOR vim
end

set -xg PAGER less
