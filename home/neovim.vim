source /etc/vimrc
set viminfo&

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme = "badwolf"
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#hunks#non_zero_only = 0

" Nerd Commenter
let g:NERDSpaceDelims = 1
let g:NERDTrimTrailingWhitespace = 1
nmap <C-/> <Plug>NERDCommenterToggle
vmap <C-/> <Plug>NERDCommenterToggle<CR>gv

" Move
let g:move_map_keys = 0
nmap <C-up>   <Plug>MoveLineUp
nmap <C-down> <Plug>MoveLineDown
vmap <C-up>   <Plug>MoveBlockUp
vmap <C-down> <Plug>MoveBlockDown

" Automatically open a file with sudo
let g:suda_smart_edit = 1
cnoremap e! SudaRead
cnoremap w! SudaWrite

" Terminal stuff
autocmd TermOpen * startinsert
command Rebuild belowright 10split term://rebuild
noremap <A-R> <cmd>source ~/.config/nvim/init.lua<cr><cmd>echo "Reloaded!"<cr>

" AI
let g:copilot_enabled = v:false
nnoremap <silent><nowait> <leader>c <cmd>Copilot enable<cr><cmd>echo "Copilot Enabled"<cr>

" COC
inoremap <silent><expr> <Tab> coc#pum#visible() ? coc#pum#confirm() : CheckBackspace() ? '<Tab>' : coc#refresh()
inoremap <silent><expr><S-Tab> coc#pum#visible() ? coc#pum#prev(1) : '<Tab>'
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : '<C-g>u<CR><c-r>=coc#on_enter()<CR>'
" Ctrl-Space to trigger completion
inoremap <silent><expr> <c-space> coc#refresh()
nmap <F2> <Plug>(coc-rename)
nnoremap <C-]> <Plug>(coc-definition)
" nnoremap <C-[> <Plug>(coc-references)

" Telescope
nnoremap <A-f> <cmd>Telescope find_files<CR>
nnoremap <C-F> <cmd>Telescope live_grep<CR>
nnoremap <A-Tab> <cmd>Telescope buffers<CR>
nnoremap <C-}> <cmd>Telescope coc definitions<CR>
nnoremap <C-{> <cmd>Telescope coc references<CR>

" DAP
nmap <leader>b <cmd>DapToggleBreakpoint<CR>
nmap <leader>dd <cmd>lua require("dapui").toggle()<CR>

" DAP styling
function! LightenColor(name, percent)
	echo "LightenColor : " . a:name . " " . a:percent
	let l:color = synIDattr(synIDtrans(hlID(a:name)), "fg#")

	" Convert hex to RGB
	let l:r = str2nr(strcharpart(l:color, 1, 2), 16)
	let l:g = str2nr(strcharpart(l:color, 3, 2), 16)
	let l:b = str2nr(strcharpart(l:color, 5, 2), 16)

	" Lighten by percentage
	let l:r = min([255, float2nr(l:r + (255 - l:r) * a:percent / 100.0)])
	let l:g = min([255, float2nr(l:g + (255 - l:g) * a:percent / 100.0)])
	let l:b = min([255, float2nr(l:b + (255 - l:b) * a:percent / 100.0)])

	" Convert back to hex
	return printf("#%02x%02x%02x", l:r, l:g, l:b)
endfunction

highlight DapBreakpoint guifg=LightenColor("String", 25) guibg=LightenColor("String", 25)
highlight DapLogPoint guifg=LightenColor("Function", 25)
highlight DapStopped guifg=LightenColor("Identifier", 25)

sign define DapBreakpoint linehl=DapBreakpoint text=⬤
sign define DapLogPoint linehl=DapLogPoint text=ⓘ
sign define DapStopped linehl=DapStopped text=⏸
