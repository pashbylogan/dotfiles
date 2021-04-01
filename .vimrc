" ____  _             _
"|  _ \| |_   _  __ _(_)_ __  ___
"| |_) | | | | |/ _` | | '_ \/ __|
"|  __/| | |_| | (_| | | | | \__ \
"|_|   |_|\__,_|\__, |_|_| |_|___/
               "|___/

" Automatically install vim-plug if not available
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugins will be downloaded under the specified directory.
call plug#begin('~/.vim/plugged')

" Declare the list of plugins.
Plug 'morhetz/gruvbox'
"    let g:gruvbox_italic=1

Plug 'itchyny/lightline.vim'
    set laststatus=2

Plug 'sirver/ultisnips'
    let g:UltiSnipsExpandTrigger = '<tab>'
    let g:UltiSnipsJumpForwardTrigger = '<tab>'
    let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'

Plug 'lervag/vimtex'
    let g:tex_flavor='latex'
    let g:vimtex_view_method='zathura'
    let g:vimtex_quickfix_mode=0

Plug 'ctrlpvim/ctrlp.vim'
    let g:ctrlp_map = '<c-p>'
    let g:ctrlp_cmd = 'CtrlP'
    set wildignore+=*/tmp/*,*.so,*.swp,*.zip

Plug 'Yggdroot/indentLine'

Plug 'preservim/nerdtree' |
            \ Plug 'Xuyuanp/nerdtree-git-plugin'

Plug 'dense-analysis/ale'
    let python_highlight_all=1

" Plug 'zxqfl/tabnine-vim'
" Plug 'mhartington/oceanic-next'
" Plug vim-syntastic/syntastic'
" Plug vim-syntastic/syntastic'

" List ends here. Plugins become visible to Vim after this call.
call plug#end()


"  ____            __
" |  _ \ _ __ ___ / _| ___ _ __ ___ _ __   ___ ___  ___
" | |_) | '__/ _ \ |_ / _ \ '__/ _ \ '_ \ / __/ _ \/ __|
" |  __/| | |  __/  _|  __/ | |  __/ | | | (_|  __/\__ \
" |_|   |_|  \___|_|  \___|_|  \___|_| |_|\___\___||___/

" Syntax highlighting
syntax on
filetype on            " enables filetype detection
filetype plugin on     " enables filetype specific plugins
set hlsearch
set ignorecase
set incsearch

" Colorscheme
colors gruvbox 
set bg=dark

" fzf Fuzzy finder
set rtp+=~/.fzf

" Spellchecking
set spell spelllang=en_us
hi clear SpellBad
hi SpellBad cterm=underline
hi SpellBad ctermfg=red

" UTF
set encoding=utf-8

" 4 spaces for tabs
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

" PEP 8 formatting for python
au BufNewFile, BufRead *.py
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=79 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix

set foldmethod=indent
set foldlevel=99

" Formatting for others
au BufNewFile, BufRead *.js, *.html, *.css
    \ set tabstop=2 |
    \ set softtabstop=2 |
    \ set shiftwidth=2

" Show linenumbers
set number

" Command Line Autocomplete
set wildmenu
set wildmode=longest,list,full

" Disable .swp and backup files
set nobackup
set nowritebackup
set noswapfile

" __  __                   _
"|  \/  | __ _ _ __  _ __ (_)_ __   __ _ ___
"| |\/| |/ _` | '_ \| '_ \| | '_ \ / _` / __|
"| |  | | (_| | |_) | |_) | | | | | (_| \__ \
"|_|  |_|\__,_| .__/| .__/|_|_| |_|\__, |___/
"             |_|   |_|            |___/

mapclear

inoremap jk <ESC>

" NERD Tree
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" Enable folding with the spacebar
nnoremap <space> za

" Spellchecking
nnoremap <leader>s :set spell!
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u
