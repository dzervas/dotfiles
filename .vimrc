" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect
set mouse=a			" By default mouse is for vim. F2 to cycle between
set mousefocus			" Hover to change window focus
set tabstop=8
set autoindent
set copyindent
set number			" Show line numbers
set ruler			" Show where are you in the file
set ignorecase
set smartcase			" Ignore case when lowercase used in search
set smarttab			" Helps with backspacing with space indent
set hlsearch			" Highlight search terms
set incsearch
set foldmethod=indent		" Code folding
set foldlevel=99		" Folding level
set history=1000		" Number of commands to remember
set undolevels=1000		" Undo states to remember
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar,*.o
set title
set nobackup
set noswapfile			" Disable the fucking .swp files
set pastetoggle=<F2>		" Toggle paste mode with F2
set showtabline=1		" Always show the tab bar
set cryptmethod=blowfish	" Use (much) stronger blowfish encryption
set showmode			" Show current mode 
set cursorline			" Highlight the current line
set ttyfast			" Improves redrawing for newer computers
set sidescroll=2		" Only scroll horizontally little by little
set laststatus=2		" Makes the status bar always visible"
set hidden			" Hide buffs instead of closing them
set showmatch			" Show matching parentheses
set noerrorbells		" Don't beep
set listchars=tab:→\ ,trail:•,extends:#,nbsp:.
set omnifunc=syntaxcomplete#Complete
set completeopt=longest,menuone	" Popup menu doesn't select the first completion item, but rather just inserts the longest common
set scrolloff=3			" 3 Lines around cursor when scrolling
set shortmess=atI		" Error messages are shorter
set foldmethod=syntax		" Fold blocks according to syntax

let mapleader=","

" Syntax highlighting
syntax on
filetype plugin indent on

" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
" Do not insert comments automatically
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" C++ completion
"au BufNewFile,BufRead,BufEnter *.cpp,*.hpp set omnifunc=omni#cpp#complete#Main

" Basic mappings
" Key accuracy hacks
nnoremap ; :
noremap! <F1> <ESC> 

" Unhighlight search
nnoremap <silent> <C-l> :nohl<CR><C-l>

" Don't forget sudo ever again!
cmap w!! w !sudo tee % >/dev/null

map ls :ls<CR>

" Fix identation
noremap <F4> :%s/    /\t/g
noremap <F8> :%s/        /\t/g

" Map toggleList
noremap <A-i> :set list!<CR>
inoremap <A-i> <ESC>:set list!<CR>a

" Plugins
" Load pathogen (bundle plugins)
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" File browser
" let NERDTreeShowHidden=1
" map <A-f> :NERDTreeToggle<CR>
map <A-f> :Vexplore<CR>

" Disable mouse
noremap <F3> :call funcs#ToggleMouse()<CR>
inoremap <F3> <Esc>:call funcs#ToggleMouse()<CR>a

" Enable neocomplete
let g:neocomplete#enable_at_startup = 1

" TaskList
map <A-t> <Plug>TaskList

" DWM settings
let g:dwm_map_keys = 0
nmap <A-Return> <Plug>DWMNew
nmap <A-c> <Plug>DWMClose
nmap <A-Space> <Plug>DWMFocus
nmap <A-l> <Plug>DWMGrowMaster
nmap <A-h> <Plug>DWMShrinkMaster
nmap <A-.> <Plug>DWMRotateClockwise
nmap <A-,> <Plug>DWMRotateCounterclockwise

nnoremap <A-j> <C-W>w
nnoremap <A-k> <C-W>W
map <A-Right> :tabnext<CR>
map <A-Left> :tabprevious<CR>
map <A-w> :tabnew<CR>
map <A-q> :tabclose<CR>
map <A-Tab> :bn<CR>
