if command -v nvim &> /dev/null
    set EDITOR nvim
else if command -v vim &> /dev/null
    set EDITOR vim
end

set PAGER less
