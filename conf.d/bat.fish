if command -v bat &> /dev/null
	# nothing to do
else if command -v batcat &> /dev/null
	alias bat batcat
end
