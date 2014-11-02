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
set cryptmethod=blowfish	" Use (much) stronger blowfish encryption
set cursorline			" Highlight the current line
set ttyfast			" Improves redrawing for newer computers
set sidescroll=2		" Only scroll horizontally little by little
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
noremap! <F1> <ESC><Right>

" Unhighlight search
nnoremap <silent> <C-l> :nohl<CR><C-l>

" Don't forget sudo ever again!
cmap w!! w !sudo tee % >/dev/null

" Fix identation
noremap <F4> :%s/    /\t/g
noremap <F8> :%s/        /\t/g

" Map toggleList
map <Leader>ch :set list!<CR>

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

" TaskList
let g:tlTokenList = ['BUG', 'FIXME', 'TODO', 'DIRTY']


" Tab and buffer manipulation
map <Leader>t<Return> :tabnew<CR>
map <Leader>tc :tabclose<CR>
map <Leader>tk :tabnext<CR>
map <Leader>tj :tabprevious<CR>
map <Leader>. :bn<CR>
map <Leader>m :bp<CR>
map <Leader><Return> :vsp<CR>
nnoremap <Leader><S-Return> <C-W>r
nnoremap <Leader>c <C-W>q
nnoremap <Leader>h <C-W>-
nnoremap <Leader>j <C-W>h
nnoremap <Leader>k <C-W>l
nnoremap <Leader>l <C-W>+
nnoremap <Leader>, <C-W><C-W>
