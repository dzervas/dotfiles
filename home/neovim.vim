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
noremap <A-R> <cmd>source ~/.config/nvim/init.lua<cr><cmd>lua print("Reloaded!")<cr>

" AI
let g:copilot_enabled = v:false
nnoremap <leader>c <cmd>Copilot enable<cr><cmd>lua print("Copilot Enabled")<cr>

" COC
inoremap <silent><expr> <Tab> coc#pum#visible() ? coc#pum#confirm() : CheckBackspace() ? '<Tab>' : coc#refresh()
inoremap <silent><expr><S-Tab> coc#pum#visible() ? coc#pum#prev(1) : '<Tab>'
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : '<C-g>u<CR><c-r>=coc#on_enter()<CR>'
" Ctrl-Space to trigger completion
inoremap <silent><expr> <c-space> coc#refresh()
