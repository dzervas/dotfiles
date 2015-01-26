if exists("b:current_syntax")
	finish
endif

syn match todirHigh "^\s*+.*$"
syn match todirMid  "^\s*#.*$"
syn match todirLow  "^\s*-.*$"

let b:current_syntax = "todir"

hi todirHigh ctermfg=Yellow
hi todirMid ctermfg=Cyan
hi todirLow ctermfg=Green
