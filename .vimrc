"info taken by: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide
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
"set spell			" Spell cheking
"set whichwrap=b,s,<,>,[,]	" Traverse line breaks with arrow keys

" Load pathogen
filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" change the mapleader from \ to ,
let mapleader=","


" Restore cursor position in files
if has("autocmd")
	au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif

" TaskList
map <A-t> <Plug>TaskList

" Syntax highlighting
syntax on
filetype on
filetype plugin indent on

map <A-Tab> :bn<CR>
map <A-S-Tab> :bp<CR>
map <A-PageUp> :tabN<CR>
map <A-PageDown> :tabp<CR>
map ls :ls<CR>

" File browser
let NERDTreeShowHidden=1
map <A-f> :NERDTreeToggle<CR>

" Disable mouse
map <F3> <F12>

" Do not insert comments automatically
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" DWM settings
let g:dwm_map_keys = 0
nnoremap <A-J> <C-W>w
nnoremap <A-K> <C-W>W
nmap <A-Return> <Plug>DWMNew
nmap <A-C> <Plug>DWMClose
nmap <A-Space> <Plug>DWMFocus
nmap <A-L> <Plug>DWMGrowMaster
nmap <A-H> <Plug>DWMShrinkMaster
nmap <A-.> <Plug>DWMRotateClockwise
nmap <A-,> <Plug>DWMRotateCounterclockwise

" Test this shortcut...
nnoremap ; :

" Unhighlight search
nnoremap <silent> <C-l> :nohl<CR><C-l>

" Don't forget sudo ever again!
cmap w!! w !sudo tee % >/dev/null

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
