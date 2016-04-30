" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
set colorcolumn=80		" Where to put the vertical line
set completeopt=longest,menuone,preview	" Popup menu doesn't select the first completion item, but rather just inserts the longest common
set copyindent
set cryptmethod=blowfish	" Use (much) stronger blowfish encryption
set cursorline			" Highlight the current line
set encoding=utf-8		" Ability to use Alt in gvim
set foldenable
set foldmethod=syntax		" Code folding
set history=100			" Number of commands to remember
set ignorecase
set incsearch
set list
set listchars=tab:>_,trail:•,extends:#,nbsp:¶
set mouse=nvc			" By default mouse is for vim. F2 to cycle between
set nobackup
set noerrorbells		" Don't beep
set noexpandtab
set noswapfile			" Disable the fucking .swp files
set number			" Show line numbers
set ruler			" Show where are you in the file
set rnu				" Relative line numbers
set scrolloff=3			" 3 Lines around cursor when scrolling
set shortmess=atI		" Error messages are shorter
set showmatch			" Show matching parentheses
set shiftwidth=4
set sidescroll=2		" Only scroll horizontally little by little
set smartcase			" Ignore case when lowercase used in search
set smartindent
set smarttab			" Helps with backspacing with space indent
set tabstop=4
set tags+=~/.vim/systags	" CTags
set title
set ttyfast			" Improves redrawing for newer computers
set undolevels=1000		" Undo states to remember
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar,*.o

let mapleader=","

" Syntax highlighting
syntax on
filetype plugin indent on

" Restore cursor position in files
au BufRead,BufNewFile .todir set filetype=todir
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
" Do not insert comments automatically
autocmd FileType * setlocal formatoptions=tc

" Enable omni completion.
set omnifunc=syntaxcomplete#Complete

" Basic mappings
" Key accuracy hacks
nnoremap ; :
nnoremap q: :
nnoremap q; :

" Unhighlight search
nmap <silent> <C-l> :noh<CR><C-l>

" Don't forget sudo ever again!
cmap W w !sudo tee % >/dev/null

map <A-s> :set spell! spelllang=en_us<CR>
map <A-w> :set list! rnu! number!<CR>

" Tab, buffer and split view manipulation
map <A-c>		:bdelete<CR>
noremap <A-up>		<C-W>l
noremap <A-down>	<C-W>h
map <A-left>		:bp<CR>
map <A-right>		:bn<CR>
map <leader><return>	:vsp<CR>

" Completion
inoremap <expr> <CR> pumvisible() ? '<C-e><CR>' : '<CR>'
inoremap <expr> <Tab> pumvisible() ? '<C-y>' : '<Tab>'

" Commenting blocks of code.
let b:comment_leader = '#'		" Default Comment leader
autocmd FileType c,cpp,java,scala	let b:comment_leader = '//'
autocmd FileType tex			let b:comment_leader = '%'
autocmd FileType mail			let b:comment_leader = '>'
autocmd FileType vim			let b:comment_leader = '"'
noremap <silent> <Leader>/ :<C-B>silent <C-E>s/^/<C-R>=escape(b:comment_leader,'\/')<CR>/<CR>:noh<CR>
noremap <silent> <Leader>? :<C-B>silent <C-E>s/^\V<C-R>=escape(b:comment_leader,'\/')<CR>//e<CR>:noh<CR>

" Plugins
" Load pathogen (bundle plugins)
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" Tab completion
"inoremap <Tab> <C-R>=funcs#TabComplete()<CR>

" TaskList
let g:tlRememberPosition = 1
let g:tlWindowPosition = 1
