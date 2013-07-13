function! funcs#ToggleMouse()
	if &mouse == "a"
		set mouse=
		echo "Mouse is for terminal"
	else
		set mouse=a
		echo "Mouse is for Vim"
	endif
endfunction
