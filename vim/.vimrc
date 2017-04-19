" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
set autochdir
set colorcolumn=80		" Where to put the vertical line
set copyindent
set cursorline			" Highlight the current line
set encoding=utf-8		" Ability to use Alt in gvim
set foldenable
set foldlevelstart=10
set foldmethod=indent	" Code folding
set history=100			" Number of commands to remember
set hidden				" Hide instead of closing buffers
set hlsearch
set ignorecase
set incsearch
set list
set listchars=tab:>_,trail:•,extends:#,nbsp:¶
set mouse=nvc			" By default mouse is for vim. F2 to cycle between
set nobackup
set noerrorbells		" Don't beep
set noexpandtab
set nofsync				" Don't sync automatically to disk (FTPFS is a pain...)
set noswapfile			" Disable the fucking .swp files
set nowritebackup
set nowrap
set number				" Show line numbers
set ruler				" Show where are you in the file
set rnu					" Relative line numbers
set scrolloff=3			" 3 Lines around cursor when scrolling
set shortmess=atI		" Error messages are shorter
set showcmd
set showmatch			" Show matching parentheses
set shiftwidth=4
set sidescroll=2		" Only scroll horizontally little by little
set smartcase			" Ignore case when lowercase used in search
set smartindent
set smarttab			" Helps with backspacing with space indent
set tabstop=4
set tags+=~/.vim/systags	" CTags
set title
set undolevels=1000		" Undo states to remember
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar,*.o
set wildmenu			" Autocompletion menu for commands

let mapleader=","

" Python
let g:python_host_prog = "/usr/bin/python2"
let g:python3_host_prog = "/usr/bin/python3"

" Load vim-plug
call plug#begin("~/.vim/bundle")
	" Libs
	Plug 'eparreno/vim-l9'
	Plug 'Shougo/vimproc.vim', { 'do': 'make' }

	" Buffer view helpers
	Plug 'airblade/vim-gitgutter'
	Plug 'majutsushi/tagbar'
	Plug 'milkypostman/vim-togglelist'
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'

	" The one and the only...
	Plug 'tomasr/molokai'

	" Editing helpers
	Plug 'matze/vim-move'
	Plug 'moll/vim-bbye'
	Plug 'jiangmiao/auto-pairs'
	Plug 'scrooloose/nerdcommenter'
	Plug 'terryma/vim-multiple-cursors'
	Plug 'tpope/vim-surround'

	" Autocompletion
	Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
		Plug 'Shougo/neco-syntax'
		Plug 'Shougo/neco-vim'
		Plug 'zchee/deoplete-clang'
		Plug 'zchee/deoplete-go', { 'do': 'make'}
		Plug 'zchee/deoplete-jedi'
		Plug 'padawan-php/deoplete-padawan'

	" Snippets
	Plug 'SirVer/ultisnips'
		Plug 'honza/vim-snippets'

	" Linting, debugging & building
	Plug 'idanarye/vim-vebugger'
	Plug 'neomake/neomake'

	" Syntax
	Plug 'lepture/vim-jinja'

	" Text objects
	Plug 'wellle/targets.vim'
	Plug 'kana/vim-textobj-user'
		Plug 'glts/vim-textobj-comment'
		Plug 'kana/vim-textobj-function'
		Plug 'kana/vim-textobj-indent'
		Plug 'padawan-php/deoplete-padawan'
call plug#end()

" Syntax highlighting
syntax on
filetype plugin indent on

au BufRead,BufNewFile *.cshtml set filetype=html
au BufRead,BufNewFile *.inc set filetype=php

" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Auto-update ctags
au BufReadPost,BufWritePost *.py,*.c,*.cpp,*.h,*.java silent! !eval 'ctags --fields=afmikKlnsStz --extra=fq -R -o tags' &

" Basic mappings
" Key accuracy hacks
nnoremap ; :

" Completion
inoremap <silent><expr> <Tab> pumvisible() ? '<C-n>' : '<Tab>'

" Unhighlight search
noremap <C-l>			:noh<CR>

" Don't forget sudo ever again!
cnoremap w!				w !sudo tee % >/dev/null

noremap <A-s>			:set spell! spelllang=en_us<CR>
noremap <A-y>			:set list! rnu! number!<CR>

" Tab, buffer and window manipulation
noremap <A-t>			:tabnew<CR>
noremap <A-w>			:tabclose<CR>
noremap <A-S-w>			:tabonly<CR>
noremap <A-S-left>		:tabp<CR>
noremap <A-S-right>		:tabn<CR>

noremap <A-c>			:Bdelete<CR>
noremap <A-left>		:bp<CR>
noremap <A-right>		:bn<CR>

noremap <A-S-c>			:close<CR>
noremap <A-Tab>			<C-W><C-W>
noremap <A-up>			<C-W>l
noremap <A-down>		<C-W>h
noremap <A-f>			<C-W>o
noremap <A-return>		:vsp<CR>
noremap <A-S-return>	:sp<CR>

tmap <A-t>				<C-\><C-n><A-t>
tmap <A-w>				<C-\><C-n><A-w>
tmap <A-S-w>			<C-\><C-n><A-S-w>
tmap <A-S-left>			<C-\><C-n><A-S-left>
tmap <A-S-right>		<C-\><C-n><A-S-right>

tmap <A-c>				<C-\><C-n><A-c>
tmap <A-left>			<C-\><C-n><A-left>
tmap <A-right>			<C-\><C-n><A-right>

tmap <A-S-c>			<C-\><C-n><A-S-c>
tmap <A-Tab>			<C-\><C-n><A-Tab>
tmap <A-up>				<C-\><C-n><A-up>
tmap <A-down>			<C-\><C-n><A-down>
tmap <A-f>				<C-\><C-n><A-f>
tmap <A-return>			<C-\><C-n><A-return>
tmap <A-S-return>		<C-\><C-n><A-S-return>

noremap <leader>f		:Lexplore<CR>

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme = "badwolf"
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#hunks#non_zero_only = 0

" Set 256 colors and the theme
colorscheme molokai
let g:rehash256 = 1

" Nerd Commenter
map //		<leader>c<space>

" Tagbar
nnoremap <leader>t :TagbarToggle<CR>

" Deoplete
let g:deoplete#enable_at_startup = 1
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | pclose | endif

let g:deoplete#sources#clang#libclang_path = '/usr/lib/libclang.so'
let g:deoplete#sources#clang#clang_header = '/usr/lib/clang'

let g:jedi#show_docstring = 1
let g:jedi#show_call_signatures = 2

let g:deoplete#sources = {}
let g:deoplete#sources._ = ['tag', 'syntax', 'omni', 'buffer', 'member', 'file']
let g:deoplete#sources.c = ['tag', 'clang', 'ultisnips', 'syntax', 'omni', 'buffer', 'member', 'file']
let g:deoplete#sources.cpp = ['tag', 'clang', 'ultisnips', 'syntax', 'omni', 'buffer', 'member', 'file']
let g:deoplete#sources.php = ['tag', 'padawan', 'ultisnips', 'syntax', 'omni', 'buffer', 'member', 'file']
let g:deoplete#sources.python = ['tag', 'jedi', 'ultisnips', 'syntax', 'omni', 'buffer', 'member', 'file']
let g:deoplete#sources.vim = ['tag', 'vim', 'ultisnips', 'syntax', 'omni', 'buffer', 'member', 'file']

" NeoMake
autocmd! BufWritePost * Neomake
autocmd! BufReadPost * Neomake

" Move
let g:move_map_keys = 0
nmap	<C-up>		<Plug>MoveLineUp
nmap	<C-down>	<Plug>MoveLineDown
vmap	<C-up>		<Plug>MoveBlockUp
vmap	<C-down>	<Plug>MoveBlockDown

" Vebugger
" Mapped: b, B, c, e, E, i, o, O, r, R, t, x, X
" See: help vebugger-keymaps
"let g:vebugger_leader = <C>
"nnoremap <C-s>	:VBGstartPDB %
"nnoremap <C-k>	:VBGkill<CR>
