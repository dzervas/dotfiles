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
set foldenable
set foldmethod=syntax		" Code folding
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
set list
set omnifunc=syntaxcomplete#Complete
set completeopt=longest,menuone	" Popup menu doesn't select the first completion item, but rather just inserts the longest common
set scrolloff=3			" 3 Lines around cursor when scrolling
set shortmess=atI		" Error messages are shorter
set encoding=utf-8		" Ability to use Alt in gvim

let mapleader=","

" Syntax highlighting
syntax on
filetype plugin indent on

" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
" Do not insert comments automatically
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

" Basic mappings
" Key accuracy hacks
nnoremap ; :
noremap! <F1> <ESC>

" Unhighlight search
nnoremap <silent> <C-l> :nohl<CR><C-l>

" Don't forget sudo ever again!
cmap w!! w !sudo tee % >/dev/null

" Fix identation
noremap <F4> :%s/    /\t/g
noremap <F8> :%s/        /\t/g

" Map toggleList
map <Leader>ch :set list!<CR>

" Tab and buffer manipulation
nnoremap <Leader>j <C-W>w
nnoremap <Leader>k <C-W>W
map <Leader>tn :tabnext<CR>
map <Leader>tp :tabprevious<CR>
map <Leader>to :tabnew<CR>
map <Leader>tc :tabclose<CR>
map <Leader>ls :ls<CR>
map <Leader>bn :bn<CR>
map <Leader>bp :bp<CR>

" File browser
map <Leader>fe :Vexplore<CR>

" Plugins
" Load pathogen (bundle plugins)
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" Disable mouse
noremap <F3> :call funcs#ToggleMouse()<CR>
inoremap <F3> <Esc>:call funcs#ToggleMouse()<CR>a

" Neocomplete
let g:neocomplete#enable_at_startup = 1
let g:neocomplete#enable_smart_case = 1
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)
if has('conceal')
	set conceallevel=2 concealcursor=i
endif

" Enable heavy omni completion.
if !exists('g:neocomplete#sources#omni#input_patterns')
	let g:neocomplete#sources#omni#input_patterns = {}
endif

" TaskList
let g:tlTokenList = ['BUG', 'FIXME', 'TODO', 'DIRTY', 'NOTSURE']

" Airline settings
" Set airline theme
let g:airline_theme='molokai'
let g:airline_powerline_fonts = 1

" DWM settings
nmap <Leader><Return> <Plug>DWMNew
nmap <Leader>c <Plug>DWMClose
nmap <Leader><Space> <Plug>DWMFocus
nmap <Leader>l <Plug>DWMGrowMaster
nmap <Leader>h <Plug>DWMShrinkMaster
nmap <Leader>. <Plug>DWMRotateClockwise
nmap <Leader>, <Plug>DWMRotateCounterclockwise
