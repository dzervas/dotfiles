" Basic settings
set nocompatible		" This must be first, because it changes other options as side effect

set autoindent
set colorcolumn=80		" Where to put the vertical line
set completeopt=longest,menuone,preview	" Popup menu doesn't select the first completion item, but rather just inserts the longest common
set copyindent
set cursorline			" Highlight the current line
set encoding=utf-8		" Ability to use Alt in gvim
set foldenable
set foldlevelstart=10
set foldmethod=indent	" Code folding
set history=100			" Number of commands to remember
set hlsearch
set ignorecase
set incsearch
set list
set listchars=tab:>_,trail:•,extends:#,nbsp:¶
set mouse=nvc			" By default mouse is for vim. F2 to cycle between
set nobackup
set noerrorbells		" Don't beep
set noexpandtab
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

" Syntax highlighting
syntax on
filetype plugin indent on

au BufRead,BufNewFile .todir set filetype=todir
au BufRead,BufNewFile *.cshtml set filetype=html
" Restore cursor position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
" Auto-update ctags
au BufReadPost,BufWritePost *.py,*.c,*.cpp,*.h,*.java silent! !eval 'ctags --fields=afmikKlnsStz --extra=fq -R -o tags' &
" Session auto-handling
"autocmd VimLeave * mksession! %:p:h/.session.vim
"autocmd VimEnter * source %:p:h/.session.vim

" Basic mappings
" Key accuracy hacks
nnoremap ' :OverCommandLine<CR>
nnoremap ; :
nnoremap q: :
nnoremap q; :

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
noremap <A-s>			<C-W>o
noremap <A-return>		:vsp<CR>
noremap <A-S-return>	:sp<CR>

noremap <leader>f	:Lexplore<CR>

" Completion
inoremap <expr> <Tab> pumvisible() ? '<C-y>' : '<Tab>'

" Commenting blocks of code.
map //			<leader>c<space>

" Plugins
let g:python_host_prog = "/usr/bin/python"
let g:python3_host_prog = "/usr/bin/python3"

" Load pathogen (bundle plugins)
execute pathogen#infect()
execute pathogen#helptags()

" Set 256 colors and the theme
colorscheme molokai
let g:rehash256 = 1

" Deoplete
let g:deoplete#enable_at_startup = 1
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | pclose | endif

" NeoMake
autocmd! BufWritePost * Neomake
autocmd! BufReadPost * Neomake

" Over
let g:over_enable_auto_nohlsearch = 1

" Vebugger
" Mapped: b, B, c, e, E, i, o, O, r, R, t, x, X
" See: help vebugger-keymaps
let g:vebugger_leader = mapleader
nnoremap <leader>s	:VBGstartPDB %
nnoremap <leader>k	:VBGkill<CR>

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme = "molokai"
