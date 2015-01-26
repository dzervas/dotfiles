if exists("b:current_syntax")
	finish
endif

syn match todirHigh "^\s*+.*$"
syn match todirMid  "^\s*#.*$"
syn match todirLow  "^\s*-.*$"

let b:current_syntax = "todir"

hi def link todirHigh		StorageClass
hi def link todirMid		Type
hi def link todirLow		PreProc
