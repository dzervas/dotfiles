" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
set autochdir
set colorcolumn=80		" Where to put the vertical line
set completeopt=longest,menuone,preview	" Popup menu doesn't select the first completion item, but rather just inserts the longest common
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

" Plugins
let g:python_host_prog = "/usr/bin/python2"
let g:python3_host_prog = "/usr/bin/python3"

" Load vim-plug
call plug#begin("~/.vim/bundle")
Plug 'eparreno/vim-l9'
Plug 'Shougo/vimproc.vim', { 'do': 'make' }

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'airblade/vim-gitgutter'

Plug 'tomasr/molokai'

Plug 'jiangmiao/auto-pairs'
Plug 'scrooloose/nerdcommenter'
Plug 'moll/vim-bbye'
Plug 'terryma/vim-multiple-cursors'
Plug 'osyo-manga/vim-over'
Plug 'tpope/vim-surround'

Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'zchee/deoplete-jedi'
"Plug 'carlitux/deoplete-ternjs'
Plug 'zchee/deoplete-zsh'

Plug 'neomake/neomake'

Plug 'idanarye/vim-vebugger'
Plug 'lepture/vim-jinja'

Plug 'majutsushi/tagbar'
Plug 'milkypostman/vim-togglelist'
call plug#end()
