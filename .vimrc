" info taken by: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide
" This must be first, because it changes other options as side effect
set nocompatible
set mouse=a
set tabstop=8
set autoindent
set copyindent
set number
set smartcase
set smarttab
" set hlsearch		" Highlight search terms
set incsearch
set foldmethod=indent	" Code folding
set foldlevel=99
set history=1000
set undolevels=1000
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk
set title
set nobackup
set noswapfile
set pastetoggle=<F2>

" Load pathogen
filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" change the mapleader from \ to ,
let mapleader=","

" Alt+<movement> keys to move around the windows
map <A-down> <C-w>j
map <A-up> <C-w>k
map <A-right> <C-w>l
map <A-left> <C-w>h

" TaskList
map <A-t> <Plug>TaskList

" Syntax highlighting
syntax on
filetype on
filetype plugin indent on
let g:pyflakes_use_quickfix = 0

" Code validation (?)
let g:pep8_map='<leader>8'

" Tab cmpletion and documentation
au FileType python set omnifunc=pythoncomplete#Complete
let g:SuperTabDefaultCompletionType = "context"
set completeopt=menuone,longest,preview

" File browser
let NERDTreeShowHidden=1
map <A-f> :NERDTreeToggle<CR>

" Git integration
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" Tab Bar
let g:Tb_cTabSwitchBufs = 1
map <A-Tab> <C-w>k<Tab><CR>
map <A-S-Tab> <C-w>k<Tab><CR>

" Disable mouse
map <F3> <F12>

" Do not insert comments automatically
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" Test this shortcut...
nnoremap ; :

" Don't forget sudo ever again!
cmap w!! w !sudo tee % >/dev/null

" Execute the py.test tests, more info: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide#test-integration
"nmap <silent><Leader>tf <Esc>:Pytest file<CR>
"nmap <silent><Leader>tc <Esc>:Pytest class<CR>
"nmap <silent><Leader>tm <Esc>:Pytest method<CR>
" Cycle through py.test test errors, more info: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide#test-integration
"nmap <silent><Leader>tn <Esc>:Pytest next<CR>
"nmap <silent><Leader>tp <Esc>:Pytest previous<CR>
"nmap <silent><Leader>te <Esc>:Pytest error<CR>
