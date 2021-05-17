" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
set clipboard=unnamedplus
set colorcolumn=80		" Where to put the vertical line
set completeopt=menuone,noselect
set copyindent
set cursorline			" Highlight the current line
set encoding=utf-8		" Ability to use Alt in gvim
set foldenable
set foldlevelstart=10
set foldmethod=syntax	" Code folding
set history=100			" Number of commands to remember
set hidden				" Hide instead of closing buffers
set hlsearch
set ignorecase
set incsearch
if exists('&inccommand')
  set inccommand=nosplit
endif
set list
set listchars=tab:>_,trail:•,extends:#,nbsp:¶
set mouse=nvc			" By default mouse is for vim. F2 to cycle between
set nobackup
set noerrorbells		" Don't beep
set noexpandtab
set noshowmode			" Do not show mode in cmdline
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
set spelllang=en_us,el_gr
set tabstop=4
set tags+=~/.vim/systags	" CTags
set title
set undolevels=1000		" Undo states to remember
if !has('nvim')
	set viminfo='10,\"100,:20,%,n~/.viminfo " Store vim data (cursor, marks, etc.)
endif
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar,*.o
set wildmenu			" Autocompletion menu for commands

let mapleader=" "
let highlight_sedtabs = 1

" Python
let g:python_host_prog = "/usr/bin/python2"
let g:python3_host_prog = "/usr/bin/python3"

if empty(glob(g:python3_host_prog))
	let g:python3_host_prog = "/usr/local/bin/python3"
endif

if empty(glob(g:python_host_prog))
	let g:python_host_prog = "/usr/local/bin/python2.7"
endif

let g:markdown_folding = 1

" Load vim-plug
call plug#begin("~/.vim/bundle")
	" Libs
	Plug 'eparreno/vim-l9'
	Plug 'Shougo/vimproc.vim', { 'do': 'make' }

	" Git Helpers
	Plug 'airblade/vim-gitgutter'

	" Buffer view helpers
	Plug 'majutsushi/tagbar'
	Plug 'milkypostman/vim-togglelist'
	Plug 'tpope/vim-repeat'
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	Plug 'RRethy/vim-illuminate'
	if has('nvim')
		Plug 'junegunn/fzf'

		Plug 'nvim-lua/popup.nvim'
		Plug 'nvim-lua/plenary.nvim'
		Plug 'nvim-telescope/telescope.nvim'
	endif

	" The one and the only...
	Plug 'tomasr/molokai'

	" Editing helpers
	Plug 'matze/vim-move'
	Plug 'jiangmiao/auto-pairs'
	Plug 'scrooloose/nerdcommenter'
	Plug 'terryma/vim-multiple-cursors'
	Plug 'tpope/vim-surround'

	" Autocompletion
	if has('python3')
		if has('nvim')
			Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
		else
			Plug 'Shougo/deoplete.nvim'
			Plug 'roxma/nvim-yarp'
			Plug 'roxma/vim-hug-neovim-rpc'
		endif

			Plug 'Shougo/echodoc.vim'
			Plug 'Shougo/neco-syntax'
			Plug 'Shougo/neco-vim', { 'for': 'vim' }
			Plug 'zchee/deoplete-clang', { 'for': ['c', 'c++'] }
			Plug 'zchee/deoplete-jedi', { 'for': 'python' }
	endif

	" Linting, debugging & building
	Plug 'neomake/neomake'
	Plug 'fidian/hexmode'

	" Syntax
	Plug 'editorconfig/editorconfig-vim'
	Plug 'lepture/vim-jinja', { 'for': 'jinja' }
	Plug 'cespare/vim-toml'
	Plug 'hashivim/vim-terraform'

	" Text objects
	Plug 'wellle/targets.vim'
	Plug 'kana/vim-textobj-user'
		Plug 'glts/vim-textobj-comment'
		Plug 'kana/vim-textobj-function'
		Plug 'kana/vim-textobj-indent'

	" Vim8 compatibility
	if !has("nvim")
		Plug 'roxma/nvim-yarp'
		Plug 'roxma/vim-hug-neovim-rpc'
	endif
call plug#end()

" Syntax highlighting
syntax on
" syntax sync minlines=10000 maxlines=50000
filetype plugin indent on

au FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
au BufRead,BufNewFile *.cshtml set filetype=html
au BufRead,BufNewFile *.inc set filetype=php
au BufNewFile,BufRead Jenkinsfile set filetype=groovy
au BufNewFile,BufRead *.gdsl set filetype=groovy

" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Basic mappings
" Completion
imap <silent><expr> <Tab> pumvisible() ? '<C-n>' : '<Tab>'
inoremap <silent><expr> <C-Tab> pumvisible() ? '<C-p>' : '<Tab>'
inoremap <silent><expr> <CR> pumvisible() ? '<C-y>' : '<CR>'

" Unhighlight search
noremap <C-l>			:nohlsearch<CR>

" Don't forget sudo ever again!
cnoremap w!				w !sudo tee % >/dev/null

noremap <A-s>			:set spell!<CR>

" Tab, buffer and window manipulation
noremap <A-t>			:tabnew<CR>
noremap <A-w>			:tabclose<CR>
noremap <A-S-w>			:tabonly<CR>
noremap <A-S-left>		:tabp<CR>
noremap <A-S-right>		:tabn<CR>

noremap <A-c>			:bdelete<CR>
noremap <A-left>		:bp<CR>
noremap <A-right>		:bn<CR>

noremap <A-backspace>	:close<CR>
noremap <A-Tab>			<C-W><C-W>
noremap <A-up>			<C-W>l
noremap <A-down>		<C-W>h
noremap <A-f>			<C-W>o
noremap <A-return>		:vsp<CR>
noremap <A-S-return>	:sp<CR>

nnoremap <Tab>			==
nnoremap <S-Tab>		>>
nnoremap <A-Tab>		<<
vnoremap <Tab>			==
vnoremap <S-Tab>		>>
vnoremap <A-Tab>		<<

noremap <leader>f		<cmd>Telescope find_files<cr>
noremap <leader>g		<cmd>Telescope live_grep<cr>
noremap <leader>h		<cmd>Telescope help_tags<cr>

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme = "badwolf"
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#hunks#non_zero_only = 0

" Set 256 colors and the theme
set t_Co=256
set t_ut=""  " Disable background color erase
colorscheme molokai
" let g:rehash256 = 1

" Nerd Commenter
let g:NERDSpaceDelims = 1
let g:NERDTrimTrailingWhitespace = 1
" For some reason Ctrl-/ registers as Ctrl-_ in vim???
nmap <C-_>   <Plug>NERDCommenterToggle
vmap <C-_>   <Plug>NERDCommenterToggle<CR>gv

" Tagbar
nnoremap <leader>t :TagbarToggle<CR>

" Deoplete
if has('python3')
	let g:deoplete#enable_at_startup = 1
	let g:echodoc_enable_at_startup = 1
	autocmd InsertLeave * if !pumvisible() | pclose | endif

	let g:deoplete#sources#clang#libclang_path = '/usr/lib/libclang.so'
	let g:deoplete#sources#clang#clang_header = '/usr/lib/clang'
	call deoplete#custom#source('_', 'converters',
				\ ['converter_auto_paren', 'converter_auto_delimiter'])

	let g:jedi#show_docstring = 1
	let g:jedi#show_call_signatures = 2
	let g:jedi#popup_select_first = 0
endif

" NeoMake
autocmd! BufReadPost,BufWritePost * Neomake

" Move
let g:move_map_keys = 0
nmap	<C-up>		<Plug>MoveLineUp
nmap	<C-down>	<Plug>MoveLineDown
vmap	<C-up>		<Plug>MoveBlockUp
vmap	<C-down>	<Plug>MoveBlockDown

" HexMode
let g:hexmode_patterns = '*.bin,*.exe,*.dat,*.o'
let g:hexmode_autodetect = 1

" GitGutter
if !has("nvim")
	let g:gitgutter_async = 0
endif
