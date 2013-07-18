function! funcs#ToggleMouse()
	if &mouse == "a"
		set mouse=
		set nonumber
		echo "Mouse is for terminal"
	else
		set mouse=a
		set number
		echo "Mouse is for Vim"
	endif
endfunction
