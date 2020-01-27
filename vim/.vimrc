" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
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
set nofsync				" Don't sync automatically to disk (FTPFS is a pain...)
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
set wildignore=*.swp,*.b,*.pyc,*.class,*.apk,*.jar,*.o
set wildmenu			" Autocompletion menu for commands

let mapleader=","
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

" NetRW
let g:netrw_ftp_options = "-N /home/dzervas/.netrc -i -p"

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
	Plug 'tpope/vim-vinegar'
	Plug 'junegunn/fzf'

	" The one and the only...
	Plug 'tomasr/molokai'

	" Editing helpers
	Plug 'matze/vim-move'
	Plug 'moll/vim-bbye'
	Plug 'jiangmiao/auto-pairs'
	Plug 'scrooloose/nerdcommenter'
	Plug 'terryma/vim-multiple-cursors'
	Plug 'tpope/vim-surround'
	Plug 'mbbill/undotree'

	" Autocompletion
	if has('nvim')
		Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
	else
		Plug 'Shougo/deoplete.nvim'
		Plug 'roxma/nvim-yarp'
		Plug 'roxma/vim-hug-neovim-rpc'
	endif

		Plug 'Shougo/echodoc.vim'
		Plug 'Shougo/neco-syntax'
		Plug 'autozimu/LanguageClient-neovim', {
					\ 'branch': 'next',
					\ 'do': 'bash install.sh',
					\ }
		Plug 'Shougo/neco-vim', { 'for': 'vim' }
		Plug 'zchee/deoplete-clang', { 'for': ['c', 'c++'] }
		Plug 'zchee/deoplete-go', { 'for': 'go', 'do': 'make'}
		Plug 'zchee/deoplete-jedi', { 'for': 'python' }
		Plug 'php-vim/phpcd.vim', { 'for': 'php', 'do': 'composer install' }

	" Snippets
	Plug 'SirVer/ultisnips'
		Plug 'honza/vim-snippets'

	" Linting, debugging & building
	Plug 'idanarye/vim-vebugger'
	Plug 'neomake/neomake'
	Plug 'mattboehm/vim-unstack'
	Plug 'fidian/hexmode'

	" Syntax
	Plug 'editorconfig/editorconfig-vim'
	Plug 'leafgarland/typescript-vim'
	Plug 'lepture/vim-jinja', { 'for': 'jinja' }
	Plug 'fatih/vim-go', { 'for': 'go' }
	Plug 'rust-lang/rust.vim'
	Plug 'dag/vim-fish'
	Plug 'cespare/vim-toml'

	" Text objects
	Plug 'wellle/targets.vim'
	Plug 'kana/vim-textobj-user'
		Plug 'glts/vim-textobj-comment'
		Plug 'kana/vim-textobj-function'
		Plug 'kana/vim-textobj-indent'

	" GUI plugins
	Plug 'equalsraf/neovim-gui-shim'
	Plug 'dzhou121/gonvim-fuzzy'

	" Vim8 compatibility
	if !has("nvim")
		Plug 'roxma/nvim-yarp'
		Plug 'roxma/vim-hug-neovim-rpc'
	endif
call plug#end()

" Syntax highlighting
syntax on
filetype plugin indent on

au BufRead,BufNewFile *.cshtml set filetype=html
au BufRead,BufNewFile *.inc set filetype=php
au BufNewFile,BufRead Jenkinsfile set filetype=groovy
au BufNewFile,BufRead *.gdsl set filetype=groovy

" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Auto-update ctags
au BufReadPost,BufWritePost *.py,*.c,*.cpp,*.h,*.java silent! !eval 'ctags --fields=afmikKlnsStz --extra=fq -R -o tags 2>/dev/null' &
au BufNewFile,BufRead .xonshrc set syntax=python

" Terminal mode config
if has("nvim")
	autocmd TermOpen * setlocal statusline=%{b:term_title}
	autocmd BufWinEnter,WinEnter term://* startinsert | nohlsearch
	autocmd BufLeave term://* stopinsert
endif

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

noremap <A-c>			:Bdelete<CR>
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

"noremap <A-S-c>			"+y
"noremap <A-S-c>			"+p

if has("nvim")
	tmap <A-t>			<C-\><C-n><A-t>
	tmap <A-w>			<C-\><C-n><A-w>
	tmap <A-S-w>		<C-\><C-n><A-S-w>
	tmap <A-S-left>		<C-\><C-n><A-S-left>
	tmap <A-S-right>	<C-\><C-n><A-S-right>

	tmap <A-c>			<C-\><C-n><A-c>
	tmap <A-left>		<C-\><C-n><A-left>
	tmap <A-right>		<C-\><C-n><A-right>

	tmap <A-S-c>		<C-\><C-n><A-S-c>
	tmap <A-Tab>		<C-\><C-n><A-Tab>
	tmap <A-up>			<C-\><C-n><A-up>
	tmap <A-down>		<C-\><C-n><A-down>
	tmap <A-f>			<C-\><C-n><A-f>
	tmap <A-return>		<C-\><C-n><A-return>
	tmap <A-S-return>	<C-\><C-n><A-S-return>

	tmap <A-Esc>		<C-\><C-n>

	"tmap <A-S-c>		<C-\><C-n><C-S-c>
	"tmap <A-S-v>		<C-\><C-n><C-S-v>
endif

noremap <leader>f		:15Lexplore<CR>

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
let g:echodoc_enable_at_startup = 1
autocmd InsertLeave * if !pumvisible() | pclose | endif

let g:deoplete#sources#clang#libclang_path = '/usr/lib/libclang.so'
let g:deoplete#sources#clang#clang_header = '/usr/lib/clang'
call deoplete#custom#source('_', 'converters',
			\ ['converter_auto_paren', 'converter_auto_delimiter'])

let g:jedi#show_docstring = 1
let g:jedi#show_call_signatures = 2
let g:jedi#popup_select_first = 0

let g:UltiSnipsExpandTrigger = "<c-j>"
let g:UltiSnipsListSnippets = "<NUL>"

" NeoMake
autocmd! BufReadPost,BufWritePost * Neomake

" Move
let g:move_map_keys = 0
nmap	<C-up>		<Plug>MoveLineUp
nmap	<C-down>	<Plug>MoveLineDown
vmap	<C-up>		<Plug>MoveBlockUp
vmap	<C-down>	<Plug>MoveBlockDown

" Vebugger
" Mapped: b, B, c, e, E, i, o, O, r, R, t, x, X
" See: help vebugger-keymaps
let g:vebugger_leader = '<leader>d'

function! VBGpyEnv()
	if !empty(glob('~/.pyenv/versions/'.expand('%:p:h:t').'/bin/python'))
		let g:vebugger_path_python = glob('~/.pyenv/versions/'.expand('%:p:h:t').'/bin/python')
	endif
endfunction

autocmd BufEnter *.py call VBGpyEnv()

" Unstack
let g:unstack_showsigns = 0

" UndoTree
nnoremap	<leader>u :UndotreeToggle<CR>

" HexMode
let g:hexmode_patterns = '*.bin,*.exe,*.dat,*.o'
let g:hexmode_autodetect = 1

" GitGutter
if !has("nvim")
	let g:gitgutter_async = 0
endif
