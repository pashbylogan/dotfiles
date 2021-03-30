" Syntax highlighting
syntax on
inoremap jk <ESC>
set hlsearch
set ignorecase
set incsearch

" fzf Fuzzy finder
set rtp+=~/.fzf

" Colorscheme
set bg=dark
let g:gruvbox_italic=1
colors gruvbox 

" Spellchecking
set spell spelllang=en_us
nnoremap <leader>s :set spell!
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u
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
let python_highlight_all=1

" Formatting for others
au BufNewFile, BufRead *.js, *.html, *.css
    \ set tabstop=2 |
    \ set softtabstop=2 |
    \ set shiftwidth=2

" Flag whitespace
" au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

"split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Show linenumbers
set number

" Command Line Autocomplete
set wildmenu
set wildmode=longest,list,full

" Disable .swp and backup files
set nobackup
set nowritebackup
set noswapfile

" Plugin Config
set laststatus=2

" Autocomplete window leaves
let g:ycm_autoclose_preview_window_after_completion=1
