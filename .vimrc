" info taken by: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide
" This must be first, because it changes other options as side effect
set nocompatible

" Load pathogen
filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Set 256 colors and the theme
set t_Co=256
colorscheme molokai

" Code Folding
set foldmethod=indent
set foldlevel=99

" change the mapleader from \ to ,
let mapleader=","

" Ctrl+<movement> keys to move around the windows
map <A-j> <c-w>j
map <A-k> <c-w>k
map <A-l> <c-w>l
map <A-h> <c-w>h

" TaskList
map <leader>td <Plug>TaskList

" Syntax highlighting
syntax on
filetype on
filetype plugin indent on
let g:pyflakes_use_quickfix = 0

" Code validation (?)
let g:pep8_map='<leader>8'

" Tab cmpletion and documentation
au FileType python set omnifunc=pythoncomplete#Complete
let g:SuperTabDefaultCompletionType = "context"
set completeopt=menuone,longest,preview

" File browser
map <leader>n :NERDTreeToggle<CR>

" Refactoring and Go to definition
map <leader>j :RopeGotoDefinition<CR>
map <leader>r :RopeRename<CR>

" Searching
nmap <leader>a <Esc>:Ack!

" Git integration
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

map <Leader>mg :call MakeGreen()<cr>

" django nose, more info: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide#test-integration
"map <leader>dt :set makeprg=python\ manage.py\ test\|:call MakeGreen()<CR>

" Execute the py.test tests, more info: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide#test-integration
"nmap <silent><Leader>tf <Esc>:Pytest file<CR>
"nmap <silent><Leader>tc <Esc>:Pytest class<CR>
"nmap <silent><Leader>tm <Esc>:Pytest method<CR>
" Cycle through py.test test errors, more info: http://sontek.net/blog/detail/turning-vim-into-a-modern-python-ide#test-integration
"nmap <silent><Leader>tn <Esc>:Pytest next<CR>
"nmap <silent><Leader>tp <Esc>:Pytest previous<CR>
"nmap <silent><Leader>te <Esc>:Pytest error<CR>

" Add the virtualenv's site-packages to vim path
"py << EOF
"import os.path
"import sys
"import vim
"if 'VIRTUAL_ENV' in os.environ:
"    project_base_dir = os.environ['VIRTUAL_ENV']
"    sys.path.insert(0, project_base_dir)
"    activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
"    execfile(activate_this, dict(__file__=activate_this))
"EOF
