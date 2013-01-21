" info taken by: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide
" This must be first, because it changes other options as side effect
set nocompatible
set mouse=a			" By default mouse is for vim. F2 to cycle between
set tabstop=8
set autoindent
set copyindent
set number			" Show numbers
set smartcase			" Ignore case when lowercase used in search
set smarttab			" Helps with backspacing with space indent
set hlsearch			" Highlight search terms
set incsearch
set foldmethod=indent		" Code folding
set foldlevel=99		" Folding level
set history=1000		" Number of commands to remember
set undolevels=1000		" Undo states to remember
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar
set title
set nobackup
set noswapfile			" Disable the fucking .swp files
set pastetoggle=<F2>		" Toggle paste mode with F2
set showtabline=1		" Always show the tab bar
set cryptmethod=blowfish	" Use (much) stronger blowfish encryption"
set showmode			" Show current mode 
set cursorline			" Highlight the current line
set ttyfast			" Improves redrawing for newer computers
set sidescroll=2		" Only scroll horizontally little by little
set laststatus=2		" Makes the status bar always visible"

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

" Tab completion and documentation
"au FileType python set omnifunc=pythoncomplete#Complete
"let g:SuperTabDefaultCompletionType = "context"
"set completeopt=menuone,longest,preview
map <A-Tab> :tabN<CR>
map <A-S-Tab> :tabp<CR>

" File browser
let NERDTreeShowHidden=1
map <A-f> :NERDTreeToggle<CR>

" Git integration
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

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

nnoremap <silent> <leader>l
	\ :set nolist!<cr>:set nolist?<cr>
	\ :if exists('w:long_line_match') <bar>
		\ silent! call matchdelete(w:long_line_match) <bar>
		\ unlet w:long_line_match <bar>
	\ elseif &textwidth > 0 <bar>
		\ let w:long_line_match = matchadd('ErrorMsg', '\%>'.&tw.'v.\+', -1) <bar>
	\ else <bar>
		\ let w:long_line_match = matchadd('ErrorMsg', '\%>80v.\+', -1) <bar>
	\ endif<cr>
